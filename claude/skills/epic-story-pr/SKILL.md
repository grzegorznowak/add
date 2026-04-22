---
name: epic-story-pr
description: Move one story from local review into a GitHub PR, recording PR metadata on the story file. Optional stage between IN REVIEW and DONE.
disable-model-invocation: true
argument-hint: "<epic-name> <story-number-or-spec-file> [pr-url|OPEN=true]"
allowed-tools: Read Edit Write Grep Glob Bash(git status:*) Bash(git log:*) Bash(git branch:*) Bash(gh pr view:*) Bash(gh pr edit:*) Bash(gh pr create:*)
---

# Epic Story PR

Transition a story from `🟣 IN REVIEW` to `🔵 IN PR`, recording GitHub PR metadata on the step file. This is the **optional** stage between local review acceptance and merged-to-main (`✅ DONE`).

Argument: `$ARGUMENTS` — `<epic_name> <story_number_or_spec_file> [<pr_url_or_OPEN=true>]`. Epic and story are required. The third arg is either a full GitHub PR URL (attach mode) or the literal `OPEN=true` to have this flow open the PR via `gh` (open mode).

## Intent

This flow applies when a story has passed local review and the changes need to go through the normal GitHub PR review and merge process before the story can be marked `✅ DONE`. It is **not** required. Stories that do not need a separate GitHub PR stage skip straight from `🟣 IN REVIEW` to `✅ DONE`.

## Status lifecycle (reference)

- `⬜ TODO` — not started
- `🔄 IN PROGRESS` — actively being worked
- `🟣 IN REVIEW` — local review pass ready
- `🔵 IN PR` — **this flow** — local review passed, PR opened, awaiting GitHub review + merge
- `✅ DONE` — PR merged (or local-only review accepted if the PR stage was skipped)
- `⛔ BLOCKED` — external blocker

## Phase 0 — Resolution and inference

This flow accepts three positional inputs in `$ARGUMENTS` — `<epic>`, `<story>`, and `<pr_url_or_OPEN=true>` — and runs three independent inference passes for any of them that is missing. **Explicit values always win and skip their corresponding inference pass.** The goal is that an operator who has just claimed or resumed exactly one story can run `/epic-story-pr` with no arguments at all.

Parse `$ARGUMENTS` first. Treat any of the three slots that is empty as a request to infer.

### Pass 1 — Epic inference (when `<epic>` is empty)

1. List `<cwd>/agent_coordination/epics/*/` directories that contain a `MASTER.md`.
2. An epic is **active** if its `MASTER.md` story tracker has at least one row whose status is not `✅ DONE` and whose `Spec` link does not point into `archive/`.
3. If exactly one active epic exists, use it. Print: `inferred epic: <name> (single active epic)`.
4. If zero active epics exist, abort with: `no active epic found under agent_coordination/epics/. Pass <epic> explicitly, or create one first.`
5. If multiple active epics exist, abort with the list and: `multiple active epics; pass <epic> explicitly to disambiguate.`

### Pass 2 — Story inference (when `<story>` is empty)

After the epic is known, read `<epic>/MASTER.md` and collect every story row whose status is one of:

- `🟣 IN REVIEW` — the canonical entry condition for this flow
- `🔵 IN PR` — included so re-running this flow for refresh works without args

1. If exactly one row matches, use it. Print: `inferred story: <NN> — <title> (status: <emoji>)`.
2. If zero rows match, do not just abort — emit a specific recovery hint based on the rest of the tracker:
   - if exactly one row is `🔄 IN PROGRESS`, say: `no story is in review yet. Story <NN> — <title> is still in progress; finish implementation and run /epic-story-review <epic> <NN> first.`
   - if multiple rows are `🔄 IN PROGRESS`, list them and recommend `/epic-story-review` for the one the operator means.
   - if no rows are in progress either, say: `no story is in review or in progress. Run /epic-story-claim <epic> to start one.`
3. If multiple rows match the eligible set, list each candidate as `<step> | <status> | <title>` and abort with: `multiple stories are eligible; pass <story> explicitly to disambiguate.`

### Pass 3 — PR inference (when `<pr_url_or_OPEN=true>` is empty)

After the story is resolved, decide whether this is an attach (existing PR) or open (new PR) operation. Walk the inference chain in order:

1. **PR Tracking section.** Read the resolved step file and look for a `## PR Tracking` section. If it exists and has a `PR URL: <url>` line, that is the existing PR. Use attach mode in refresh form. Print: `inferred PR (from PR Tracking): <url>`. Skip the rest of the chain.

2. **Project repo detection.** Parse the story's `## Active Claim` section for the `Primary write surfaces:` field. Take the first path. Walk up the directory tree until you find a `.git/` directory; that is the project repo. If no `.git/` is found, fall back to the workspace `.git/` if one exists. If still none, skip directly to step 4.

3. **Branch-based PR lookup.**
   - Inside the detected project repo, run `git rev-parse --abbrev-ref HEAD` to get the current branch.
   - If the branch is the repo's default branch, skip to step 4 (operating directly on `main`/`master` is not how PRs are opened).
   - Otherwise run `gh pr list --head <branch> --state open --json url,number,headRefName,title` from inside the project repo.
   - If exactly one open PR is returned, print `inferred PR (from current branch <branch>): <url>` and **ask the user to confirm** before attaching. The branch may legitimately host work unrelated to this story.
   - If multiple are returned, list each as `<number> | <title> | <url>` and ask which to attach.
   - If zero are returned, fall through to step 4.

4. **Fall through to OPEN mode.** If no existing PR was found by any previous step, ask the user: `no existing PR found for branch <branch>. Open a new one via gh? [Y/n]`
   - If yes, proceed exactly as the existing `OPEN=true` path in "PR creation mode".
   - If no, abort with: `pass <pr_url> explicitly when one exists, or rerun with OPEN=true to open a fresh PR.`

### Inference summary printout

Before doing any work that affects `MASTER.md`, the PR, or the step file, print a single resolved-context block so the user can verify what was inferred:

```
Resolved context:
- epic:  <name>          (explicit | inferred from single active epic)
- story: <NN> — <title>  (explicit | inferred from single eligible row)
- PR:    <url>           (explicit | from PR Tracking | from current branch | new via OPEN)
```

Print this even when everything was passed explicitly — the printout is the contract the user approves before any destructive step runs.

### Entry-condition check

Once the story is resolved, abort fast if its current status is not `🟣 IN REVIEW`. This flow only transitions from `IN REVIEW` — not from `IN PROGRESS`, `DONE`, or `BLOCKED`. If the step is already `🔵 IN PR`, treat the invocation as a refresh per "Refresh existing PR metadata" below and proceed only after user confirmation.

### Known limitations

- **Cross-repo PR detection is not supported.** The PR inference looks at the project repo derived from the story's `Primary write surfaces`. If a story's surfaces span multiple repos, pass the PR URL explicitly.
- **Stories without an `Active Claim` section cannot have their project repo inferred.** This usually means the story has never been claimed via `/epic-story-claim` / `/epic-story-resume`. Pass the PR URL explicitly in that case.

## PR description — product-focused, NOT implementation-focused

**This is the most important rule of this flow.** The PR body is a spec-vs-code verification contract for the GitHub reviewer, not a developer diary. The reviewer must be able to answer one question from the PR body alone: *does this code deliver what the story promised?*

### What belongs in the PR body

Extract **only** product-facing content from the resolved step file:
- the story **Purpose** / **Goal** (what outcome the user gets)
- the **Acceptance criteria** (observable behavior the code must satisfy)
- the **Out of Scope** section (what this PR deliberately does not deliver)
- **Contract / interface changes** — if and only if they affect external behavior (config keys, CLI surface, API shape, file formats, env vars, persisted metadata schema, user-visible defaults, migration requirements). These live in the PR body because they change what the code promises to the outside world.
- **User-facing verification** — how a reviewer can manually confirm the outcome without reading the code (CLI commands, config snippets, expected UI/log output)

### What does NOT belong in the PR body

Suppress anything that describes *how* the code was implemented rather than *what* it delivers:
- `## Active Claim` (session-local metadata)
- `## Progress Log` (implementation diary with timestamps)
- `## Session Handoff` (inter-session handoff notes)
- `## Review Log` (prior review round notes)
- file paths, function names, class names, internal module names — unless they ARE the contract (e.g. a public API endpoint, a documented config key)
- internal refactoring decisions, helper extractions, private naming choices
- test file paths, fixture paths, parameterization notes
- "why we chose X over Y" architecture rationale, unless the choice is user-visible
- any content that would go stale if the implementation were rewritten without changing the contract

**Test the inclusion boundary**: if a reviewer could hypothetically accept a completely different implementation that still passes the Acceptance criteria and preserves the Contract changes, then the piece you're considering does not belong in the PR body.

### PR body template

Generate the body using this structure. Omit any section that has no content rather than writing "N/A".

```md
## Summary
<one short paragraph in product language — the user-visible outcome this PR delivers>

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
2. `## Acceptance` / `## Acceptance criteria` → Acceptance criteria
3. `## Scope` → filter for contract-affecting parts only → Contract changes
4. `## Out of Scope` → Out of scope
5. `## Verification` → filter for user-facing checks only → How to verify

Do not paste sections verbatim if they contain internal terminology. Rephrase into reviewer-facing language. A reviewer who has never seen the step file should understand the PR body.

## PR creation mode

**Attach mode (default)** — a PR URL is provided:
- The user has already opened the PR
- Verify the URL is well-formed (`https://github.com/<org>/<repo>/pull/<n>`)
- Call `gh pr view <PR_URL> --json number,title,headRefName,state,url,body` to enrich metadata and read the current body
- **Update the PR body to the generated product description** via `gh pr edit <PR_URL> --body-file <tmpfile>`
  - If the existing body already contains substantial content authored by the user, show a diff and ask confirmation before overwriting. Offer to prepend/append instead of replacing.
  - If the existing body is empty or auto-generated (e.g. commit messages), replace silently.
- If `gh` is unavailable, skip enrichment and the body edit, record only what the user provided, and tell the user the PR body was not updated

**Open mode** — user passes `OPEN=true` with no URL:
- Verify `git status` is clean or only contains intended changes
- Verify the current branch is not the default branch
- Generate the PR body (see template above) and write it to a tempfile
- Call `gh pr create --title "<story title>" --body-file <tmpfile>`
- Capture the returned URL
- If `gh` fails or is unavailable, abort fast and ask the user to open the PR manually and rerun in attach mode

In both modes, **never** force-push, **never** bypass hooks, **never** rewrite history without explicit user confirmation.

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

Append a timestamped bullet under `## Progress Log`:

```md
- <UTC ISO timestamp> Moved step to `🔵 IN PR` — <PR URL>
```

Do **not** create a duplicate `PR Tracking` section. If one already exists, update its fields in place.

## Refresh existing PR metadata

If the step is already `🔵 IN PR` and the user reinvokes this flow, treat it as a refresh:
- Re-query `gh pr view` if available and update `PR status`, `Merge commit`, and `Last synced`
- If `PR status` is now `merged`, transition the step to `✅ DONE`
- If `PR status` is `changes_requested` or the reviewer requested code changes, transition the step back to `🔄 IN PROGRESS` and record the reason under `## Progress Log`. Tell the user to rerun `/epic-story-resume` to address the feedback.
- Otherwise leave the step at `🔵 IN PR` and update `Last synced`

## MASTER.md update

Update the selected row in `<epic>/MASTER.md`:

| From | Action |
|------|--------|
| `🟣 IN REVIEW` | set to `🔵 IN PR` |
| `🔵 IN PR` (refresh, PR still open) | leave at `🔵 IN PR` |
| `🔵 IN PR` (PR merged) | set to `✅ DONE` |
| `🔵 IN PR` (PR requests code changes) | set to `🔄 IN PROGRESS` |

If the epic's `MASTER.md` Legend section does not list `🔵 IN PR`, add it immediately after the `🟣 IN REVIEW` line:

```md
- `🔵 IN PR` — local review passed, PR opened, awaiting GitHub review + merge
```

## Rules

1. **The PR body is product-focused, not implementation-focused.** If a reviewer could accept an entirely different implementation that still meets the Acceptance criteria and Contract changes, the suppressed content was correct to suppress.
2. **Never mark a story `✅ DONE` from this flow unless the PR is actually merged.** Merged means `gh pr view --json state` returns `MERGED`, or the user explicitly states so with a merge commit.
3. **Never touch product code in this flow.** It is a coordination-only transition (except for the optional `gh pr create` call in open mode).
4. **Never archive a `🔵 IN PR` story.** `/epic-squash` skips them by design.
5. **Never skip the step file write-back.** The PR URL is the only durable link between the step and the GitHub review.
6. **Never leave `Last synced` stale across transitions.**
7. **Never paste `Progress Log`, `Active Claim`, `Session Handoff`, or `Review Log` content into the PR body.** Those sections are implementation diary, not product contract.

## Final response

State:
- which epic and step were transitioned
- the PR URL, number, and branch
- the new status in `MASTER.md`
- whether `gh` enrichment was used
- exactly what the user should do next:
  - wait on PR review
  - rerun `/epic-story-resume` to address PR feedback
  - rerun `/epic-story-pr` with the same PR URL to resync PR state
  - rerun `/epic-squash` once the story is `✅ DONE` and stable
