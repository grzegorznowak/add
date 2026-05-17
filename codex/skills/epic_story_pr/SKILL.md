---
name: epic_story_pr
description: Move one story from local review or local DONE into a GitHub PR, recording PR metadata on the story file. Optional stage between IN REVIEW and DONE.
---

Open PR: $EPIC / $STORY

Treat `$EPIC` as the exact directory name of an epic under the agent's current
working directory at:
`agent_coordination/epics/`

Treat `$STORY` as either:
- the exact story number from the `Step` column in `<epic>/MASTER.md`
- the exact spec file name from the `Spec` column in `<epic>/MASTER.md`

Treat `$PR_URL` as the GitHub pull request URL for this story's implementation
branch. Required unless the operator explicitly passes `OPEN=true` to have this
flow open the PR for you (see "PR creation mode" below). For an explicitly
selected `✅ DONE` story, omitting `$PR_URL` implies open mode after existing PR
detection fails.

## Intent

This is the **optional** `IN REVIEW` → `IN PR` transition. It applies when a
story has passed local review and the changes need to go through the normal
GitHub PR review and merge process before the story can be marked `DONE`.

It is **not** required. Stories that do not need a separate GitHub PR review
stage skip straight from `🟣 IN REVIEW` to `✅ DONE` via the normal review or
claim flow.

Sometimes a story was already marked `✅ DONE` because the team treated it as
locally complete, then later decides to open a GitHub PR for the same
implementation. In that case, run `epic_story_pr EPIC=<epic> STORY=<story>`.
If the PR is unmerged, this flow records PR metadata and moves the story back
to `🔵 IN PR` until remote review finishes. If the PR is already merged, it
records PR metadata and keeps the story `✅ DONE`.

## Status lifecycle (reference)

- `⬜ TODO` — not started
- `🔄 IN PROGRESS` — actively being worked
- `🟣 IN REVIEW` — local review pass ready
- `🔵 IN PR` — **this flow** — local review passed, PR opened, awaiting GitHub
  review + merge
- `✅ DONE` — PR merged, or local-only review accepted when no PR stage was
  known
- `⛔ BLOCKED` — external blocker

## Phase 0 — Resolution and inference

This flow accepts three arguments — `EPIC`, `STORY`, and `PR_URL` (or
`OPEN=true`) — and runs three independent inference passes for any of them
that is missing. **Explicit values always win and skip their corresponding
inference pass.** The goal is that an operator who has just claimed or
resumed exactly one story can run `epic_story_pr` with no arguments at all.
DONE PR injection is the exception: it requires explicit story selection
because DONE rows are completed history, not active work.

### Pass 1 — Epic inference (when `$EPIC` is empty)

1. List `<cwd>/agent_coordination/epics/*/` directories that contain a
   `MASTER.md`.
2. An epic is **active** if its `MASTER.md` story tracker has at least one
   row whose status is not `✅ DONE` and whose `Spec` link does not point
   into `archive/`.
3. If exactly one active epic exists, use it. Print:
   `inferred epic: <name> (single active epic)`.
4. If zero active epics exist, abort with:
   `no active epic found under agent_coordination/epics/. Pass EPIC=<name> explicitly, or create one first.`
5. If multiple active epics exist, abort with the list and:
   `multiple active epics; pass EPIC=<name> to disambiguate.`

### Pass 2 — Story inference (when `$STORY` is empty)

After the epic is known, read `<epic>/MASTER.md` and collect every story
row whose status is one of:

- `🟣 IN REVIEW` — the canonical entry condition for this flow
- `🔵 IN PR` — included so re-running this flow for refresh works without args

Do **not** auto-infer `✅ DONE` stories. If `$STORY` was passed explicitly and
the row is non-archived `✅ DONE`, accept it for the late PR injection path.

1. If exactly one row matches, use it. Print:
   `inferred story: <NN> — <title> (status: <emoji>)`.
2. If zero rows match, do not just abort — emit a specific recovery hint
   based on the rest of the tracker:
   - if exactly one row is `🔄 IN PROGRESS`, say:
     `no story is in review yet. Story <NN> — <title> is still in progress; finish implementation and run epic_story_review EPIC=<epic> STORY=<NN> first.`
   - if multiple rows are `🔄 IN PROGRESS`, list them and recommend
     `epic_story_review` for the one the operator means.
   - if no rows are in progress either, say:
     `no story is in review or in progress. Run epic_story_claim EPIC=<epic> to start one.`
3. If multiple rows match the eligible set, list each candidate as
   `<step> | <status> | <title>` and abort with:
   `multiple stories are eligible; pass STORY=<NN> to disambiguate.`

### Pass 3 — PR inference (when `$PR_URL` is empty AND `OPEN` is not set)

After the story is resolved, decide whether this is an attach (existing PR)
or open (new PR) operation. Walk the inference chain in order:

1. **PR Tracking section.** Read the resolved step file and look for a
   `## PR Tracking` section. If it exists and has a `PR URL: <url>` line,
   that is the existing PR. Use attach mode in refresh form. Print:
   `inferred PR (from PR Tracking): <url>`. Skip the rest of the chain.
   - If the story is `✅ DONE` and PR Tracking points to an unmerged PR,
     report the status drift and ask what to do before changing files.
     Recommend moving the story back to `🔵 IN PR` and refreshing PR metadata.
     If the operator declines, abort without changing `MASTER.md`, the story
     file, or the PR.

2. **Project repo detection.** Parse the story's `## Active Claim` section
   for the `Primary write surfaces:` field. Take the first path. Walk up
   the directory tree until you find a `.git/` directory; that is the
   project repo. If no `.git/` is found, fall back to the workspace `.git/`
   if one exists. If still none, skip directly to step 4.

3. **Branch-based PR lookup.**
   - Inside the detected project repo, run
     `git rev-parse --abbrev-ref HEAD` to get the current branch.
   - If the branch is the repo's default branch, skip to step 4 (operating
     directly on `main`/`master` is not how PRs are opened).
   - Otherwise run
     `gh pr list --head <branch> --state open --json url,number,headRefName,title`
     from inside the project repo.
   - If exactly one open PR is returned, print
     `inferred PR (from current branch <branch>): <url>` and **ask the
     operator to confirm** before attaching. The branch may legitimately
     host work unrelated to this story.
   - If multiple are returned, list each as `<number> | <title> | <url>`
     and ask which to attach.
   - If zero are returned, fall through to step 4.

4. **Fall through to OPEN mode.** If no existing PR was found by any
   previous step:
   - For an explicitly selected `✅ DONE` story, treat `OPEN=true` as implicit
     and proceed to open mode without an extra confirmation.
   - For all other stories, ask the operator:
     `no existing PR found for branch <branch>. Open a new one via gh? [Y/n]`
   - If yes, proceed exactly as the existing `OPEN=true` path in
     "PR creation mode".
   - If no, abort with:
     `pass PR_URL=<url> when one exists, or rerun with OPEN=true to open a fresh PR.`

### Inference summary printout

Before doing any work that affects `MASTER.md`, the PR, or the step file,
print a single resolved-context block so the operator can verify what was
inferred:

```
Resolved context:
- epic:  <name>          (explicit | inferred from single active epic)
- story: <NN> — <title>  (explicit | inferred from single eligible row)
- status: <emoji>
- PR:    <url>           (explicit | from PR Tracking | from current branch | new via OPEN)
```

Print this even when everything was passed explicitly — the printout is
the contract the operator approves before any destructive step runs.

### Entry-condition check

Once the story is resolved, abort fast unless its current status is one of
`🟣 IN REVIEW`, `🔵 IN PR`, or `✅ DONE`.

If the tracker has a `Plan` column, abort unless the matched row's `Plan` is exactly `🟢 PLAN APPROVED`. PR opening, refresh, and late PR injection cannot proceed against a stale or unapproved contract; run `epic_story_plan_converge $EPIC $STORY` first.

- `🟣 IN REVIEW` is the canonical entry condition for opening or attaching a
  PR.
- `🔵 IN PR` is refresh/resync mode per "Update existing PR metadata" below.
- `✅ DONE` is allowed only when the story was explicitly selected and the
  `Spec` link is not in `archive/`. Treat it as late PR injection from local
  DONE. Do not require a second confirmation after explicit epic + story
  selection, but still ask before attaching a branch-inferred PR and before
  overwriting a substantial PR body.
- Archived `✅ DONE` stories are ineligible. Abort with:
  `Story <NN> is archived. PR injection only works for non-archived DONE stories.`

Abort for `IN PROGRESS`, `BLOCKED`, `TODO`, or any unknown status with a
recovery hint naming the correct preceding command.

### Known limitations

- **Cross-repo PR detection is not supported.** The PR inference looks at
  the project repo derived from the story's `Primary write surfaces`. If a
  story's surfaces span multiple repos, pass `PR_URL` explicitly.
- **Stories without an `Active Claim` section cannot have their project
  repo inferred.** This usually means the story has never been claimed
  via `epic_story_claim` / `epic_story_resume`. Pass `PR_URL` explicitly in that case.

## PR description — product-focused, NOT implementation-focused

**This is the most important rule of this flow.** The PR body is a
spec-vs-code verification contract for the GitHub reviewer, not a developer
diary. The reviewer must be able to answer one question from the PR body
alone: *does this code deliver what the story promised?*

### What belongs in the PR body

Extract **only** product-facing content from the resolved step file:
- the story **Purpose** / **Goal** (what outcome the user gets)
- explicit **original ticket/card links** from `Triggering Need`, `Purpose`,
  `Scope`, or other product-facing prose, when present
- the **Acceptance criteria** (observable behavior the code must satisfy)
- the **Out of Scope** section (what this PR deliberately does not deliver)
- **Contract / interface changes** — if and only if they affect external
  behavior (config keys, CLI surface, API shape, file formats, env vars,
  persisted metadata schema, user-visible defaults, migration requirements).
  These live in the PR body because they change what the code promises to
  the outside world.
- **User-facing verification** — how a reviewer can manually confirm the
  outcome without reading the code (CLI commands, config snippets, expected
  UI/log output)

### What does NOT belong in the PR body

Suppress anything that describes *how* the code was implemented rather than
*what* it delivers:
- `## Active Claim` (session-local metadata)
- `## Progress Log` (implementation diary with timestamps)
- `## Session Handoff` (inter-session handoff notes)
- `## Review Log` (prior review round notes)
- file paths, function names, class names, internal module names — unless
  they ARE the contract (e.g. a public API endpoint, a documented config key)
- internal refactoring decisions, helper extractions, private naming choices
- test file paths, fixture paths, parameterization notes
- "why we chose X over Y" architecture rationale, unless the choice is
  user-visible
- any content that would go stale if the implementation were rewritten
  without changing the contract

**Test the inclusion boundary**: if a reviewer could hypothetically accept a
completely different implementation that still passes the Acceptance criteria
and preserves the Contract changes, then the piece you're considering does
not belong in the PR body.

### PR body template

Generate the body using this structure. Omit any section that has no content
rather than writing "N/A".

```md
## Summary
<one short paragraph in product language — the user-visible outcome this PR delivers>

## Original tickets
- <optional label>: <url>

## Requirements
<bulleted list extracted from the step file's Purpose / Goal>

## Acceptance criteria
<bulleted list extracted from the step file's Acceptance section, rephrased in reviewer-verifiable terms>

## Contract changes
<only if the story changes external contracts: config keys added/removed/renamed, CLI flag changes, API/file-format changes, migration requirements, user-visible defaults>

## Out of scope
<bulleted list from the step file's Out of Scope section>

## How to verify
<user-facing verification steps a reviewer can run or inspect without reading the code>

## Epic reference
- Epic: <epic name>
- Story: <story number> — <story title>
- Step file: <relative path to step file>
```

### Sourcing the content

Read these sections of the step file in order and map them to the body:
1. `## Purpose` / `## Goal` → Summary + Requirements
2. `## Triggering Need`, `## Purpose`, `## Scope`, and any visible
   product-facing prose → explicit original ticket/card links only. Include
   links near the top when found; omit `## Original tickets` silently when no
   link is found.
3. `## Acceptance` / `## Acceptance criteria` → Acceptance criteria
4. `## Scope` → filter for contract-affecting parts only → Contract changes
5. `## Out of Scope` → Out of scope
6. `## Verification` → filter for user-facing checks only → How to verify

For original ticket/card links:
- Include links only; never summarize or quote original ticket text.
- Detect explicit URLs and stable identifiers only. Do not infer from vague
  prose.
- When multiple links are found, keep a unique compact list.
- Try to fetch or infer short labels when reasonably available from the link
  target or local markdown link text. If a label is unavailable, include only
  the link.
- Missing ticket links are not a prompt and not a blocker for this story flow.

Do not paste sections verbatim if they contain internal terminology.
Rephrase into reviewer-facing language. A reviewer who has never seen the
step file should understand the PR body.

## PR creation mode

Two modes are supported:

**Attach mode (default)** — `$PR_URL` is provided:
- The operator has already opened the PR themselves
- Verify the PR URL is well-formed (`https://github.com/<org>/<repo>/pull/<n>`)
- Call `gh pr view <PR_URL> --json number,title,headRefName,state,url,body`
  to enrich metadata and read the current body
- **Update the PR body to the generated product description** via
  `gh pr edit <PR_URL> --body-file <tmpfile>`
  - If the existing body already contains substantial content authored by
    the operator, show a diff and ask confirmation before overwriting. Offer
    to prepend/append instead of replacing.
  - If the existing body is empty or auto-generated (e.g. commit messages),
    replace silently.
- If `gh` is unavailable, skip enrichment and the body edit, record only
  what the operator provided, and report that the PR body was not updated

**Open mode** — operator passes `OPEN=true` and no `$PR_URL`, or explicitly
selects a `✅ DONE` story with no URL and no existing PR was found:
- Verify `git status` is clean or only contains intended changes
- Verify the current branch is not the default branch
- Generate the PR body (see template above) and write it to a tempfile
- Call `gh pr create --title "<story title>" --body-file <tmpfile>` to open
  the PR
- Capture the returned URL
- If the current branch is the default branch, abort. For a `✅ DONE` story,
  leave `MASTER.md`, the story header, and `## PR Tracking` untouched.
- If `gh` fails or is unavailable, abort fast and ask the operator to open
  the PR manually and rerun in attach mode. For a `✅ DONE` story, leave
  `MASTER.md`, the story header, and `## PR Tracking` untouched.

In both modes, never force-push, never bypass hooks, never rewrite history
without explicit operator confirmation.

## Write-back to the step file

Add or refresh a `## PR Tracking` section in the resolved step file:

```md
## PR Tracking
- PR URL: <url>
- Number: <n>
- Title: <pr title>
- Branch: <head ref>
- Opened at: <UTC ISO timestamp>
- PR status: open | changes_requested | approved | merged | closed
- Merge commit: <sha or "—">
- Last synced: <UTC ISO timestamp>
```

Append a timestamped bullet under `## Progress Log`. Use the entry that
matches the transition:

```md
- <UTC ISO timestamp> Moved step to `🔵 IN PR` — <PR URL>
- <UTC ISO timestamp> Reopened remote review from local `✅ DONE`; moved step to `🔵 IN PR` — <PR URL>
- <UTC ISO timestamp> Attached merged PR to local `✅ DONE` story — <PR URL>
```

Do **not** create a duplicate `PR Tracking` section. If one already exists
(e.g. on a subsequent sync), update its fields in place.

When the story file has a recognizable header status, update it with the same
status written to `MASTER.md`. If the header is missing or ambiguous, leave it
unchanged and report that `MASTER.md` remains authoritative.

## Update existing PR metadata

If the step is already `🔵 IN PR` and the operator invokes this flow again,
treat it as a refresh:
- Re-query `gh pr view` if available and update `PR status`, `Merge commit`,
  and `Last synced` fields.
- If `PR status` is now `merged`, transition the step to `✅ DONE` (see next
  section).
- If `PR status` is `changes_requested` or the PR reviewer requested code
  changes, transition the step back to `🔄 IN PROGRESS` and record the
  reason under `## Progress Log`. Tell the operator to rerun `epic_story_resume`
  to address the feedback.
- Otherwise leave the step at `🔵 IN PR` and update `Last synced`.

If the step is `✅ DONE` and already has `## PR Tracking` for an unmerged PR,
report the DONE/PR drift and ask what to do. Recommend moving the story back to
`🔵 IN PR` and refreshing metadata. If the operator declines, abort without
write-back.

## MASTER.md update

Before transitioning to `✅ DONE`, check `## Active Claim` -> `- Worktrees:` for uncommitted changes. If any worktree is dirty (e.g., local metadata or post-PR adjustments), offer to commit before marking done. If the step has no `## Active Claim` section, skip.

Update the selected row in `<epic>/MASTER.md`:

| From | Action |
|------|--------|
| `🟣 IN REVIEW` | set to `🔵 IN PR` |
| `🔵 IN PR` (refresh, PR still open) | leave at `🔵 IN PR` |
| `🔵 IN PR` (PR merged) | set to `✅ DONE` |
| `🔵 IN PR` (PR requests code changes) | set to `🔄 IN PROGRESS` |
| `✅ DONE` (explicit, non-archived, PR still open) | set to `🔵 IN PR` |
| `✅ DONE` (explicit, non-archived, PR merged) | leave at `✅ DONE` |

If the epic's `MASTER.md` `Legend` section does not list `🔵 IN PR`, add it
immediately after the `🟣 IN REVIEW` line:

```md
- `🔵 IN PR` — local review passed, PR opened, awaiting GitHub review + merge
```

## Rules

1. **The PR body is product-focused, not implementation-focused.** If a
   reviewer could accept an entirely different implementation that still
   meets the Acceptance criteria and Contract changes, the suppressed
   content was correct to suppress.
2. **Never mark a story `✅ DONE` from this flow unless the PR is actually
   merged.** Merged means `gh pr view --json state` returns `MERGED`, or the
   operator explicitly states so with a merge commit.
3. **Never touch product code in this flow.** It is a coordination-only
   transition (except for the optional `gh pr create` call in open mode).
4. **Never archive a `🔵 IN PR` story.** `epic_squash` skips them by design.
5. **Never skip the step file write-back.** The PR URL is the only durable
   link between the step and the GitHub review.
6. **Never leave `Last synced` stale across transitions.**
7. **Never paste `Progress Log`, `Active Claim`, `Session Handoff`, or
   `Review Log` content into the PR body.** Those sections are
   implementation diary, not product contract.
8. **Never silently infer a DONE story.** Late PR injection from `✅ DONE`
   requires explicit story selection.
9. **Never leave an unmerged PR represented as `✅ DONE` after the operator
   chooses to proceed.** Move both `MASTER.md` and a parseable story header to
   `🔵 IN PR`.
10. **Never summarize or quote original tickets.** Include detected links only,
   and omit the section when no link is found.

## Final response

State:
- which epic and step were transitioned
- the PR URL, number, and branch
- the new status in `MASTER.md`
- whether the story file header was updated or left unchanged
- whether `gh` enrichment was used
- exactly what the operator should do next:
  - wait on PR review
  - rerun `epic_story_resume` to address PR feedback
  - rerun `epic_story_pr` with the same `$PR_URL` to resync PR state
  - rerun `epic_squash` once the story is `✅ DONE` and stable
