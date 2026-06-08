---
name: openspec-story-pr
description: Move one OpenSpec change from local review or local DONE into a GitHub PR, recording PR metadata on progress.md. Optional stage between IN REVIEW and DONE.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug> [pr-url|OPEN=true]"
allowed-tools: Read Edit Write Grep Glob Bash(git status:*) Bash(git log:*) Bash(git branch:*) Bash(gh pr list:*) Bash(gh pr view:*) Bash(gh pr edit:*) Bash(gh pr create:*) Bash(curl:*)
---

# OpenSpec Story PR

Transition a story from `🟣 IN REVIEW` to `🔵 IN PR`, recording GitHub PR metadata on the change workspace's `progress.md`. This is the **optional** stage between local review acceptance and merged-to-main (`✅ DONE`). It can also inject a PR into an explicitly selected, non-archived `✅ DONE` story when that DONE meant local completion and the remote PR stage is being added late.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug> [<pr_url_or_OPEN=true>]`. Initiative and story may be inferred for active `🟣 IN REVIEW` / `🔵 IN PR` work. `✅ DONE` PR injection requires the story to be explicit. The third arg is either a full GitHub PR URL (attach mode) or the literal `OPEN=true` to have this flow open the PR via `gh` (open mode). For an explicitly selected `✅ DONE` story, omitting the third arg implies open mode after existing PR detection fails.

## Intent

This flow applies when a story has passed local review and the changes need to go through the normal GitHub PR review and merge process before the story can be marked `✅ DONE`. It is **not** required. Stories that do not need a separate GitHub PR stage skip straight from `🟣 IN REVIEW` to `✅ DONE`.

Sometimes a story was already marked `✅ DONE` because the team treated it as locally complete, then later decides to open a GitHub PR for the same implementation. In that case, run `/openspec-story-pr <initiative> <story>`. If the PR is unmerged, this flow records PR metadata and moves the story back to `🔵 IN PR` until remote review finishes. If the PR is already merged, it records PR metadata and keeps the story `✅ DONE`.

## Resolution Model

- `<workspace_root>` = `<cwd>`.
- `<initiative_dir>` = `<workspace_root>/openspec/initiatives/<initiative>`.
- `<initiative_file>` = `<initiative_dir>/initiative.md`.
- `<change_dir>` = `<workspace_root>/openspec/changes/<story-slug>`.
- `<story_file>` = `<change_dir>/story.md`.
- `<progress_file>` = `<change_dir>/progress.md`.
- `<proposal_file>` = `<change_dir>/proposal.md`.

There is no `MASTER.md`, no tracker table, and no step/number row. All status is self-contained in the change workspace artifacts:

- The `Status:` header field in `<story_file>` is the authoritative implementation status.
- The `Plan:` header field in `<story_file>` is the authoritative planning lane.
- The `## Current Claim` section in `<progress_file>` records active implementation state and worktree bindings.
- The `## PR State` section in `<progress_file>` is the sole PR metadata location.
- The `## Progress Timeline` section in `<progress_file>` records milestone bullets.

## Status lifecycle (reference)

- `⬜ TODO` — not started
- `🔄 IN PROGRESS` — actively being worked
- `🟣 IN REVIEW` — local review pass ready
- `🔵 IN PR` — **this flow** — local review passed, PR opened, awaiting GitHub review + merge
- `✅ DONE` — PR merged, or local-only review accepted when no PR stage was known
- `⛔ BLOCKED` — external blocker

## Phase 0 — Resolution and inference

This flow accepts three positional inputs in `$ARGUMENTS` — `<initiative>`, `<story>`, and `<pr_url_or_OPEN=true>` — and runs three independent inference passes for any of them that is missing. **Explicit values always win and skip their corresponding inference pass.** The goal is that an operator who has just claimed or resumed exactly one story can run `/openspec-story-pr` with no arguments at all.

Parse `$ARGUMENTS` first. Treat any of the three slots that is empty as a request to infer.

### Pass 1 — Initiative inference (when `<initiative>` is empty)

1. List `<workspace_root>/openspec/initiatives/*/` directories that contain an `initiative.md`.
2. An initiative is **active** if its `initiative.md` exists and at least one corresponding change workspace exists under `<workspace_root>/openspec/changes/<change-slug>/` whose `<story_file>` has a `Status:` that is not `✅ DONE` and the change workspace is not under `openspec/changes/archive/`.
3. If exactly one active initiative exists, use it. Print: `inferred initiative: <slug> (single active initiative)`.
4. If zero active initiatives exist, abort with: `no active initiative found under openspec/initiatives/. Pass <initiative> explicitly, or create one first.`
5. If multiple active initiatives exist, abort with the list and: `multiple active initiatives; pass <initiative> explicitly to disambiguate.`

### Pass 2 — Story inference (when `<story>` is empty)

After the initiative is known, list all change workspace directories under `<workspace_root>/openspec/changes/` (excluding `archive/`). For each, read the `Status:` header field in `<story_file>` and collect every story whose status is one of:

- `🟣 IN REVIEW` — the canonical entry condition for this flow
- `🔵 IN PR` — included so re-running this flow for refresh works without args

Do **not** auto-infer `✅ DONE` stories. DONE PR injection requires the story argument because DONE rows are completed history, not active work. If `<story>` was passed explicitly and the story is non-archived `✅ DONE`, accept it for the late PR injection path.

1. If exactly one story matches, use it. Print: `inferred story: <story-slug> — <title> (status: <emoji>)`.
2. If zero stories match, do not just abort — emit a specific recovery hint based on the initiative's change workspaces:
   - if exactly one story is `🔄 IN PROGRESS`, say: `no story is in review yet. Story <story-slug> — <title> is still in progress; finish implementation and run /openspec-story-review <initiative> <story-slug> first.`
   - if multiple stories are `🔄 IN PROGRESS`, list them and recommend `/openspec-story-review` for the one the operator means.
   - if no stories are in progress either, say: `no story is in review or in progress. Run /openspec-story-claim <initiative> <story-slug> to start one.`
3. If multiple stories match the eligible set, list each candidate as `<story-slug> | <status> | <title>` and abort with: `multiple stories are eligible; pass <story> explicitly to disambiguate.`

### Pass 3 — PR inference (when `<pr_url_or_OPEN=true>` is empty)

After the story is resolved, decide whether this is an attach (existing PR) or open (new PR) operation. Walk the inference chain in order:

1. **PR State section.** Read `<progress_file>` and look for a `## PR State` section. If it exists and has a `- PR URL:` line with a non-empty URL, that is the existing PR. Use attach mode in refresh form. Print: `inferred PR (from PR State): <url>`. Skip the rest of the chain.
   - If the story is `✅ DONE` and PR State points to an unmerged PR, report the status drift and ask what to do before changing files. Recommend moving the story back to `🔵 IN PR` and refreshing PR metadata. If the user declines, abort without changing `story.md`, `progress.md`, or the PR.

2. **Project repo detection.** Read `<progress_file>` for the `## Current Claim` section and parse the `- Primary write surfaces:` field. Take the first path. Walk up the directory tree until you find a `.git/` directory; that is the project repo. If no `.git/` is found, fall back to the workspace `.git/` if one exists. If still none, skip directly to step 4.

3. **Branch-based PR lookup.**
   - Inside the detected project repo, run `git rev-parse --abbrev-ref HEAD` to get the current branch.
   - If the branch is the repo's default branch, skip to step 4 (operating directly on `main`/`master` is not how PRs are opened).
   - Otherwise run `gh pr list --head <branch> --state open --json url,number,headRefName,title` from inside the project repo.
   - If exactly one open PR is returned, print `inferred PR (from current branch <branch>): <url>` and **ask the user to confirm** before attaching. The branch may legitimately host work unrelated to this story.
   - If multiple are returned, list each as `<number> | <title> | <url>` and ask which to attach.
   - If zero are returned, fall through to step 4.

4. **Fall through to OPEN mode.** If no existing PR was found by any previous step:
   - For an explicitly selected `✅ DONE` story, treat `OPEN=true` as implicit and proceed to open mode without an extra confirmation.
   - For all other stories, ask the user: `no existing PR found for branch <branch>. Open a new one via gh? [Y/n]`
   - If yes, proceed exactly as the existing `OPEN=true` path in "PR creation mode".
   - If no, abort with: `pass <pr_url> explicitly when one exists, or rerun with OPEN=true to open a fresh PR.`

### Inference summary printout

Before doing any work that affects `story.md`, `progress.md`, or the PR, print a single resolved-context block so the user can verify what was inferred:

```
Resolved context:
- initiative: <slug>          (explicit | inferred from single active initiative)
- story: <story-slug> — <title>  (explicit | inferred from single eligible story)
- status: <emoji>
- PR:    <url>           (explicit | from PR State | from current branch | new via OPEN)
```

Print this even when everything was passed explicitly — the printout is the contract the user approves before any destructive step runs.

### Entry-condition check

Once the story is resolved, abort fast unless its current status is one of `🟣 IN REVIEW`, `🔵 IN PR`, or `✅ DONE`.

- `🟣 IN REVIEW` is the canonical entry condition for opening or attaching a PR.
- `🔵 IN PR` is refresh/resync mode per "Refresh existing PR metadata" below.
- `✅ DONE` is allowed only when the story was explicitly selected and the change workspace is not in `openspec/changes/archive/`. Treat it as late PR injection from local DONE. Do not require a second confirmation after explicit initiative + story selection, but still ask before attaching a branch-inferred PR and before overwriting a substantial PR body.
- Archived `✅ DONE` stories are ineligible. Abort with: `Story <story-slug> is archived. PR injection only works for non-archived DONE stories.`

Also abort when the story's `Plan:` header field is not `🟢 PLAN APPROVED`. Recovery hint: run `/openspec-story-plan-converge <initiative> <story-slug>` before opening, refreshing, or merging PR state.

Abort for `IN PROGRESS`, `BLOCKED`, `TODO`, or any unknown status with a recovery hint naming the correct preceding command.

### Known limitations

- **Cross-repo PR detection is not supported.** The PR inference looks at the project repo derived from the story's `Primary write surfaces` in `progress.md → ## Current Claim`. If a story's surfaces span multiple repos, pass the PR URL explicitly.
- **Stories without a `## Current Claim` section in progress.md cannot have their project repo inferred.** This usually means the story has never been claimed via `/openspec-story-claim` / `/openspec-story-resume`. Pass the PR URL explicitly in that case.

## PR description — product-focused, NOT implementation-focused

**This is the most important rule of this flow.** The PR body is a spec-vs-code verification contract for the GitHub reviewer, not a developer diary. The reviewer must be able to answer one question from the PR body alone: *does this code deliver what the story promised?*

### What belongs in the PR body

Extract **only** product-facing content from the change workspace artifacts (`proposal.md`, `story.md`, and delta specs under `specs/`):

- the story **Purpose** / **Goal** (what outcome the user gets)
- role-based **Actors** when they clarify who the PR affects
- normative **Scenarios / Behavior Examples** only when they are linked to a single acceptance id with `Covers: A<n>` and help the reviewer understand expected behavior
- explicit **original ticket/card links** from `Triggering Need`, `Purpose`, `Scope`, `Goal / Context`, `External Resources`, or other product-facing prose, when present
- the **Acceptance criteria** (observable behavior the code must satisfy)
- the **Out of Scope** section (what this PR deliberately does not deliver)
- **Contract / interface changes** — if and only if they affect external behavior (config keys, CLI surface, API shape, file formats, env vars, persisted metadata schema, user-visible defaults, migration requirements). These live in the PR body because they change what the code promises to the outside world.
- **User-facing verification** — how a reviewer can manually confirm the outcome without reading the code (CLI commands, config snippets, expected UI/log output)
- **Delta spec summaries** — summary-level behavioral changes described in `specs/` delta specs, when they clarify the user-visible behavioral contract and fit the inclusion boundary

### What does NOT belong in the PR body

Suppress anything that describes *how* the code was implemented rather than *what* it delivers:
- `## Current Claim` (session-local metadata)
- `## Progress Timeline` (implementation diary with timestamps)
- `## Session Handoff` (inter-session handoff notes)
- `## Review Log` / `reviews.md` (prior review round notes)
- `design.md` content (architecture decisions, rationale, internal module structure)
- `tasks.md` content (task checklists, implementation ordering)
- `progress.md` content (runtime tracking)
- file paths, function names, class names, internal module names — unless they ARE the contract (e.g. a public API endpoint, a documented config key)
- internal refactoring decisions, helper extractions, private naming choices
- test file paths, fixture paths, parameterization notes
- "why we chose X over Y" architecture rationale, unless the choice is user-visible
- `## Discovery Notes`, `## Locked Decisions`, `## Implementation Notes`, `## Critical Files` from story.md (implementation-facing sections)
- any content that would go stale if the implementation were rewritten without changing the contract

**Test the inclusion boundary**: if a reviewer could hypothetically accept a completely different implementation that still passes the Acceptance criteria and preserves the Contract changes, then the piece you're considering does not belong in the PR body.

### PR body template

Generate the body using this structure. Omit any section that has no content rather than writing "N/A".

```md
## Summary
<one short paragraph in product language — the user-visible outcome this PR delivers>

## Original tickets
- <optional label>: <url>

## Requirements
<bulleted list extracted from the story's Purpose / Goal>

## Acceptance criteria
<bulleted list extracted from the story's Acceptance section, rephrased in reviewer-verifiable terms>

## Contract changes
<only if the story changes external contracts: config keys added/removed/renamed, CLI flag changes, API/file-format changes, migration requirements, user-visible defaults>

## Out of scope
<bulleted list from the story's Out of Scope section>

## How to verify
<user-facing verification steps a reviewer can run or inspect without reading the code>

## Initiative reference
- Initiative: <initiative-slug>
- Story: <story-slug> — <story title>
- Change workspace: openspec/changes/<story-slug>/
```

### Sourcing the content

Read the following artifacts in the change workspace and map them to the PR body. Source order below; skip any missing artifact silently.

1. `proposal.md → ## Goal / Context` → Summary
2. `proposal.md → ## External Resources` → Original tickets (extract only explicit URLs; omit narrative descriptions)
3. `story.md → ## Purpose` → Summary + Requirements
4. `story.md → ## Triggering Need`, `## Purpose`, `## Scope` → Original tickets (extract only explicit URLs not already found)
5. `story.md → ## Actors` → Requirements only when role context is product-facing
6. `story.md → ## Scenarios / Behavior Examples` → Acceptance criteria only for normative scenarios linked with exactly one `Covers: A<n>`; omit orientation-only examples
7. `story.md → ## Acceptance` → Acceptance criteria
8. `story.md → ## Scope` → filter for contract-affecting parts only → Contract changes
9. `story.md → ## Out of Scope` → Out of scope
10. `story.md → ## Verification → ## Verification Commands` → filter for user-facing checks only → How to verify
11. `specs/*.md` → Contract changes (only where behavioral deltas describe external contract surface changes; summarize in contract language, not implementation language)

For original ticket/card links:
- Include links only; never summarize or quote original ticket text.
- Detect explicit URLs and stable identifiers only. Do not infer from vague prose.
- When multiple links are found, keep a unique compact list.
- Try to fetch or infer short labels when reasonably available from the link target or local markdown link text. If a label is unavailable, include only the link.
- Missing ticket links are not a prompt and not a blocker for this story flow.

Do not paste sections verbatim if they contain internal terminology. Rephrase into reviewer-facing language. A reviewer who has never seen the change workspace should understand the PR body.

**Exclusion enforcement**: never read or include content from `design.md`, `tasks.md`, `progress.md`, or `reviews.md`. These files are explicitly out of scope per decision #6. If a section of `story.md` is implementation-facing (`## Discovery Notes`, `## Locked Decisions`, `## Implementation Notes`, `## Critical Files`, `## Acceptance Proof Matrix`, `## Test Architecture Plan`), exclude it from the PR body.

## PR creation mode

**Attach mode (default)** — a PR URL is provided:
- The user has already opened the PR
- Verify the URL is well-formed (`https://github.com/<org>/<repo>/pull/<n>`)
- Call `gh pr view <PR_URL> --json number,title,headRefName,state,url,body,reviewDecision,latestReviews,mergedAt,mergeCommit,closedAt,updatedAt` to enrich metadata and read the current body, review decision, merged state, and merge commit.
- **Update the PR body to the generated product description** via `gh pr edit <PR_URL> --body-file <tmpfile>`
  - If the existing body already contains substantial content authored by the user, show a diff and ask confirmation before overwriting. Offer to prepend/append instead of replacing.
  - If the existing body is empty or auto-generated (e.g. commit messages), replace silently.
- If `gh` is unavailable, skip enrichment and the body edit, record only what the user provided, and tell the user the PR body was not updated

**Open mode** — user passes `OPEN=true` with no URL, or explicitly selects a `✅ DONE` story with no URL and no existing PR was found:
- Verify `git status` is clean or only contains intended changes
- Verify the current branch is not the default branch
- Generate the PR body (see template above) and write it to a tempfile
- Call `gh pr create --title "<story title>" --body-file <tmpfile>`
- Capture the returned URL
- Immediately call `gh pr view <returned-url> --json number,title,headRefName,state,url,body,reviewDecision,latestReviews,mergedAt,mergeCommit,closedAt,updatedAt` to populate the same durable metadata fields used by attach/refresh mode.
- If the current branch is the default branch, abort. For a `✅ DONE` story, leave `story.md`, `progress.md`, and `## PR State` untouched.
- If `gh` fails or is unavailable, abort fast and ask the user to open the PR manually and rerun in attach mode. For a `✅ DONE` story, leave `story.md`, `progress.md`, and `## PR State` untouched.

In both modes, **never** force-push, **never** bypass hooks, **never** rewrite history without explicit user confirmation.

## Write-back to progress.md

### PR State section

Add or refresh a `## PR State` section in `<progress_file>`:

```md
## PR State
- PR URL: <url>
- Number: <n>
- Title: <pr title>
- Branch: <head ref>
- Opened at: <UTC ISO timestamp>
- PR status: open | changes_requested | approved | merged | closed
- Review decision: <APPROVED | CHANGES_REQUESTED | REVIEW_REQUIRED | blank | unavailable>
- Merge commit: <sha or "—">
- Merged at: <UTC ISO timestamp or "—">
- Last synced: <UTC ISO timestamp>
```

Do **not** create a duplicate `## PR State` section. If one already exists, update its fields in place. When refreshing an older section, add the `Review decision:` and `Merged at:` fields rather than dropping them.

### PR status derivation

When `gh pr view` is available, derive the progress `PR status` from the enriched JSON fields, not from the URL alone:

1. If `state` is `MERGED` or `mergedAt` is non-empty, set `PR status: merged`, set `Merged at:` to `mergedAt` when available, and set `Merge commit:` to `mergeCommit.oid` (or the user-provided merge commit if `gh` lacks it).
2. Else if `state` is `CLOSED`, set `PR status: closed`.
3. Else if `reviewDecision` is `CHANGES_REQUESTED`, or the latest effective review state in `latestReviews` is `CHANGES_REQUESTED`, set `PR status: changes_requested`.
4. Else if `reviewDecision` is `APPROVED`, set `PR status: approved`.
5. Else set `PR status: open`.

If `gh` is unavailable in attach mode, record the supplied URL and any user-provided fields, set unavailable fields to `unavailable` or `—`, and do not transition to `✅ DONE` unless the operator explicitly supplies merged-state evidence, a merge commit, **and** a merged-at timestamp. When any of these three is missing, leave the story at its current status and tell the operator to provide the missing evidence or rerun with `gh` available.

### Progress Timeline entry

Append a timestamped bullet under `## Progress Timeline` in `<progress_file>`. Use the entry that matches the transition:

```md
- <UTC ISO timestamp> Moved step to `🔵 IN PR` — <PR URL>
- <UTC ISO timestamp> Reopened remote review from local `✅ DONE`; moved step to `🔵 IN PR` — <PR URL>
- <UTC ISO timestamp> Attached merged PR to local `✅ DONE` story — <PR URL>
```

### story.md Status header update

Update the `Status:` header field in `<story_file>` with the same status being written:

| From | Action |
|------|--------|
| `🟣 IN REVIEW` | set `Status:` to `🔵 IN PR` |
| `🔵 IN PR` (refresh, PR still open) | leave `Status:` at `🔵 IN PR` |
| `🔵 IN PR` (PR merged) | set `Status:` to `✅ DONE` |
| `🔵 IN PR` (PR requests code changes) | set `Status:` to `🔄 IN PROGRESS` |
| `✅ DONE` (explicit, non-archived, PR still open) | set `Status:` to `🔵 IN PR` |
| `✅ DONE` (explicit, non-archived, PR merged) | leave `Status:` at `✅ DONE` |

If the `Status:` header field is missing or ambiguous, abort with: `story.md has no parseable Status: header. Cannot update status.`

## Refresh existing PR metadata

If the story is already `🔵 IN PR` and the user reinvokes this flow, treat it as a refresh:
- Re-query `gh pr view --json number,title,headRefName,state,url,body,reviewDecision,latestReviews,mergedAt,mergeCommit,closedAt,updatedAt` if available and update `## PR State → PR status`, `Review decision`, `Merge commit`, `Merged at`, and `Last synced`
- If `PR status` is now `merged`, transition the story to `✅ DONE`
- If `PR status` is `changes_requested` or the reviewer requested code changes, transition the story back to `🔄 IN PROGRESS` and record the reason in `## Progress Timeline`. Tell the user to rerun `/openspec-story-resume` to address the feedback.
- Otherwise leave the story at `🔵 IN PR` and update `Last synced`

If the story is `✅ DONE` and already has `## PR State` for an unmerged PR, report the DONE/PR drift and ask what to do. Recommend moving the story back to `🔵 IN PR` and refreshing metadata. If the user declines, abort without write-back.

## Pre-transition worktree check

Before transitioning to `✅ DONE`, read `<progress_file> → ## Current Claim → - Worktrees:` for uncommitted changes. If any worktree is dirty (e.g., local metadata or post-PR adjustments), offer to commit before marking done. If `<progress_file>` has no `## Current Claim` section, skip.

## No MASTER.md update

There is no `MASTER.md` and no tracker table in this flow. All status updates go to `<story_file> → Status:` header field and `<progress_file> → ## Progress Timeline`. No centralized board is consulted or written.

## Rules

1. **Use the PR description inclusion boundary above.** The PR body is a product contract for reviewers, not an implementation diary.
2. **Never mark a story `✅ DONE` from this flow unless the PR is actually merged and durable evidence is complete.** Merged means enriched `gh pr view` data has `state: MERGED` or a non-empty `mergedAt`, **plus** a populated merge commit and merged-at timestamp. When `gh` is unavailable, the operator must supply merged-state evidence, a merge commit, and a merged-at timestamp — all three.
3. **Never touch product code in this flow.** It is a coordination-only transition (except for the optional `gh pr create` call in open mode).
4. **Never archive a `🔵 IN PR` story.** `/openspec-archive` requires DONE.
5. **Never skip the progress.md write-back.** The PR URL is the only durable link between the change workspace and the GitHub review.
6. **Never leave `Last synced` stale across transitions.**
7. **Never paste `## Current Claim`, `## Progress Timeline`, `## Session Handoff`, `design.md`, `tasks.md`, `reviews.md`, or `progress.md` content into the PR body.** Those sections are implementation diary, not product contract.
8. **Never silently infer a DONE story.** Late PR injection from `✅ DONE` requires explicit story selection.
9. **Never leave an unmerged PR represented as `✅ DONE` after the operator chooses to proceed.** Move both `story.md → Status:` and `progress.md → ## PR State` accordingly.
10. **Never summarize or quote original tickets.** Include detected links only, and omit the section when no link is found.

## Final response

State:
- which initiative and change workspace were transitioned
- the PR URL, number, and branch
- the new status in `story.md → Status:`
- whether `gh` enrichment was used
- exactly what the user should do next:
  - wait on PR review
  - rerun `/openspec-story-resume` to address PR feedback
  - rerun `/openspec-story-pr` with the same PR URL to resync PR state
  - rerun `/openspec-archive` once the story is `✅ DONE` and stable
