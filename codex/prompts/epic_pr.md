---
description: Move one epic step from local review into a GitHub PR, recording PR metadata on the step file. Optional stage between IN REVIEW and DONE.
argument-hint: [EPIC="<epic_name>"] [STORY="<story_number_or_spec_file>"] [PR_URL="<github_pr_url>"]
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
flow open the PR for you (see "PR creation mode" below).

## Intent

This is the **optional** `IN REVIEW` → `IN PR` transition. It applies when a
story has passed local review and the changes need to go through the normal
GitHub PR review and merge process before the story can be marked `DONE`.

It is **not** required. Stories that do not need a separate GitHub PR review
stage skip straight from `🟣 IN REVIEW` to `✅ DONE` via the normal review or
claim flow.

## Status lifecycle (reference)

- `⬜ TODO` — not started
- `🔄 IN PROGRESS` — actively being worked
- `🟣 IN REVIEW` — local review pass ready
- `🔵 IN PR` — **this flow** — local review passed, PR opened, awaiting GitHub
  review + merge
- `✅ DONE` — PR merged (or local-only review accepted if the PR stage was
  skipped)
- `⛔ BLOCKED` — external blocker

## Resolution

1. Resolve the epic directory as:
   - `<cwd>/agent_coordination/epics/$EPIC`
2. Read `<epic>/MASTER.md` and resolve the story row by `$STORY` (same rules
   as `epic_resume` / `epic_review`).
3. Read the resolved step file.
4. Abort fast if the resolved step is not currently `🟣 IN REVIEW`. This flow
   only transitions from `IN REVIEW` — not from `IN PROGRESS`, `DONE`, or
   `BLOCKED`. If the step is already `🔵 IN PR`, refer the operator to the
   "Update existing PR metadata" section below and proceed only if they
   confirm.

## PR description — product-focused, NOT implementation-focused

**This is the most important rule of this flow.** The PR body is a
spec-vs-code verification contract for the GitHub reviewer, not a developer
diary. The reviewer must be able to answer one question from the PR body
alone: *does this code deliver what the story promised?*

### What belongs in the PR body

Extract **only** product-facing content from the resolved step file:
- the story **Purpose** / **Goal** (what outcome the user gets)
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

**Open mode** — operator passes `OPEN=true` and no `$PR_URL`:
- Verify `git status` is clean or only contains intended changes
- Verify the current branch is not the default branch
- Generate the PR body (see template above) and write it to a tempfile
- Call `gh pr create --title "<story title>" --body-file <tmpfile>` to open
  the PR
- Capture the returned URL
- If `gh` fails or is unavailable, abort fast and ask the operator to open
  the PR manually and rerun in attach mode

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

Append a timestamped bullet under `## Progress Log`:

```md
- <UTC ISO timestamp> Moved step to `🔵 IN PR` — <PR URL>
```

Do **not** create a duplicate `PR Tracking` section. If one already exists
(e.g. on a subsequent sync), update its fields in place.

## Update existing PR metadata

If the step is already `🔵 IN PR` and the operator invokes this flow again,
treat it as a refresh:
- Re-query `gh pr view` if available and update `PR status`, `Merge commit`,
  and `Last synced` fields.
- If `PR status` is now `merged`, transition the step to `✅ DONE` (see next
  section).
- If `PR status` is `changes_requested` or the PR reviewer requested code
  changes, transition the step back to `🔄 IN PROGRESS` and record the
  reason under `## Progress Log`. Tell the operator to rerun `epic_resume`
  to address the feedback.
- Otherwise leave the step at `🔵 IN PR` and update `Last synced`.

## MASTER.md update

Update the selected row in `<epic>/MASTER.md`:

| From | Action |
|------|--------|
| `🟣 IN REVIEW` | set to `🔵 IN PR` |
| `🔵 IN PR` (refresh, PR still open) | leave at `🔵 IN PR` |
| `🔵 IN PR` (PR merged) | set to `✅ DONE` |
| `🔵 IN PR` (PR requests code changes) | set to `🔄 IN PROGRESS` |

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

## Final response

State:
- which epic and step were transitioned
- the PR URL, number, and branch
- the new status in `MASTER.md`
- whether `gh` enrichment was used
- exactly what the operator should do next:
  - wait on PR review
  - rerun `epic_resume` to address PR feedback
  - rerun `epic_pr` with the same `$PR_URL` to resync PR state
  - rerun `epic_squash` once the story is `✅ DONE` and stable
