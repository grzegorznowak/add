---
name: epic_pr
description: Open or refresh a GitHub PR for an entire epic, using CONTRACT.md and current DONE stories to produce an epic-level reviewer body.
---

Epic PR: $EPIC / $PR_URL

Treat `$EPIC` as either:
- the exact directory name of an epic under `agent_coordination/epics/`
- a direct path to an epic directory containing `MASTER.md`

Treat `$PR_URL` as an optional GitHub pull request URL. If it is empty, infer
an existing PR first, then ask before opening a new one. `OPEN=true` is
accepted but not required.

## Phase 0 — Resolve epic and PR intent

1. Resolve the epic directory:
   - If `$EPIC` is a path containing `MASTER.md`, use it.
   - Otherwise treat it as a directory name under `<cwd>/agent_coordination/epics/`.
   - If omitted and exactly one epic has `MASTER.md`, infer it; otherwise ask the operator to pass the epic explicitly.
2. Read `MASTER.md` fully. It is the status source of truth.
3. Resolve the PR operation:
   - If `$PR_URL` was passed, use attach mode.
   - Else if `MASTER.md` has `## Epic PR Tracking` with `PR URL: <url>`, use that URL in refresh mode.
   - Else detect the current git branch, skip branch lookup if it is the default branch, and run `gh pr list --head <branch> --state open --json url,number,headRefName,title`.
   - If exactly one branch PR is found, ask before attaching it.
   - If none is found, ask before opening a new PR via `gh pr create`.
4. Print resolved context before any write:

```text
Resolved context:
- epic: <name/path>
- operation: attach | refresh | open
- PR: <url or new via gh>
```

## Phase 1 — Gather source material

Use only allowed epic sources:

- `CONTRACT.md`, when present, represents already-squashed and archived scope.
- Non-archived `✅ DONE` story files represent completed scope not yet squashed.
- `MASTER.md` Goal / Context, Scope, constraints, and tracker rows provide epic framing and source labels.

Never read archived story files directly. If `MASTER.md` has archived DONE
story links and `CONTRACT.md` is missing, block early before drafting: archived
scope has no allowed contract source.

Abort if there is no included source at all: no `CONTRACT.md` and no
non-archived `✅ DONE` stories.

Read only product-facing sections from non-archived DONE stories:

- `## Purpose`
- `## Actors` when role context is product-facing
- normative `## Scenarios / Behavior Examples` linked with exactly one `Covers: A<n>`
- `## Triggering Need`
- `## Scope`
- `## Out of Scope`
- `## Acceptance`
- ticket/card links from any visible product-facing prose

Do not read or use `## Verification`, `## Active Claim`, `## Progress Log`,
`## Session Handoff`, `## Review Log`, or implementation diary sections. A
`✅ DONE` story is trusted as already reviewed.

## Phase 2 — Original ticket link pass

Find explicit original ticket/card links or stable ticket identifiers in
`MASTER.md`, `CONTRACT.md`, and included non-archived DONE story prose.

Rules:

- Include links only; never summarize or quote the original ticket.
- Detect explicit URLs and stable identifiers only. Do not infer a ticket from vague prose.
- When multiple links are found, keep a unique compact list.
- Try to fetch or infer short labels when reasonably available from the link target or local markdown link text. If a label is unavailable, include only the link.
- If no ticket/card link is found, report that in the Phase 4 check-in. It is not a blocker.

## Phase 3 — Draft epic PR body

Draft a product-focused PR body from the included sources. Merge story inputs
into one epic-level narrative; do not create story-by-story sections.

Template:

```md
## Summary
<one concise paragraph describing the delivered epic-level outcome>

## Original tickets
- <optional label>: <url>

## Delivered scope
<coherent product/contract narrative from CONTRACT.md plus current DONE stories>

## Requirements
<synthesized epic-level requirements; do not copy raw A1/A2 acceptance bullets>

## Contract changes
<external contract/interface changes only: CLI, config, API, file format, env vars, persisted metadata, user-visible defaults>

## Out of scope
<only explicit out-of-scope terms relevant to the delivered scope>

## Epic reference
- Epic: <epic name>
- Contract: <relative path or "not present">
- Additional DONE stories: <story numbers or "none">
```

Omit `## Original tickets` if there are no links. Do not include verification
commands, proof matrices, unfinished story details, or implementation diary
content. Mention unfinished stories only in the check-in and final response,
not in the PR body.

## Phase 4 — Secondary epic check-in

Before creating or editing the PR, run a lightweight coordination-doc
consistency check. This is not codebase verification and not `epic_squash`.

Blockers are issues that would make the epic PR body misleading:

- `CONTRACT.md` missing while archived DONE stories exist.
- `CONTRACT.md` contradicts non-archived DONE story scope or requirements.
- A non-archived DONE story is missing core product sections needed for the epic narrative: `Purpose`, `Scope`, or `Acceptance`.
- Two included sources claim incompatible external contract names, defaults, flags, APIs, file formats, or user-visible behavior.
- Ticket/card context is contradictory, such as multiple different parent epic tickets claiming ownership.

Non-blockers:

- No ticket link found.
- Unfinished stories exist; they are excluded.
- Story verification details are not inspected.
- Archived story details are not read when `CONTRACT.md` exists.

Print a check-in packet:

```text
Epic PR check-in:
- Included contract source: <CONTRACT.md | none>
- Included non-archived DONE stories: <list>
- Excluded unfinished stories: <list>
- Archived scope source: <CONTRACT.md | blocked because missing>
- Original tickets: <count/list or none>
- Blockers: <none | list>
```

If blockers exist, do not create or edit the PR and do not update
`## Epic PR Tracking`. Enter Phase 5.

If no blockers exist, ask the operator to publish the drafted body. If the
operator declines, abort without PR or `MASTER.md` write-back.

## Phase 5 — Operator-led repair loop

When blockers exist, let the operator decide what happens next. Do not
recommend `epic_squash` as the default fix and do not invoke other skills.

Allowed after explicit operator direction:

- Targeted edits to `MASTER.md` epic framing or ticket links.
- Targeted edits to non-archived DONE story product sections.
- Targeted edits to existing `CONTRACT.md` wording when the operator says the contract is stale.

Forbidden:

- Product source or test edits.
- Story status transitions.
- Reading archived story files.
- Moving files into or out of `archive/`.
- Rewriting `CONTRACT.md` from scratch.
- Adding squash appendices or performing archive consolidation.

After each approved repair batch:

1. Re-read changed coordination files.
2. Validate the touched epic files still have the expected shape.
3. Re-run the Phase 4 check-in.
4. Continue until blockers are cleared or the operator says stop.

Publish only when blockers are cleared.

## Phase 6 — Create or refresh PR

Generate the final PR body into a tempfile.

Attach/refresh mode:

- Validate the PR URL shape.
- Run `gh pr view <url> --json number,title,headRefName,state,url,body`.
- If the existing PR body is empty or clearly autogenerated, replace it.
- If the existing body contains substantial operator-authored content, show the generated body or a diff and ask whether to replace, prepend, append, or abort.
- Apply the selected mode with `gh pr edit <url> --body-file <tmpfile>`.

Open mode:

- Verify the current branch is not the default branch.
- Use title `Epic: <epic title>`.
- Call `gh pr create --title "Epic: <epic title>" --body-file <tmpfile>`.
- Rely on `gh pr create` defaults for the base branch. If a custom base is needed, the operator should open the PR manually and rerun in attach mode.

If `gh` fails, abort without `MASTER.md` write-back unless a PR URL is already
known and metadata was refreshed successfully.

## Phase 7 — MASTER.md write-back

Add or refresh exactly one `## Epic PR Tracking` section in `MASTER.md`:

```md
## Epic PR Tracking
- PR URL: <url>
- Number: <n>
- Title: <pr title>
- Branch: <head ref>
- Opened at: <UTC ISO timestamp>
- PR status: open | changes_requested | approved | merged | closed
- Merge commit: <sha or "—">
- Last synced: <UTC ISO timestamp>
- Included contract: CONTRACT.md | none
- Included DONE stories: <story numbers or "none">
- Original tickets:
  - <optional label>: <url>
```

Do not write story-level `## PR Tracking`. Do not transition story statuses.

## Rules

1. **Never read archived story files.** Archived scope is represented only through `CONTRACT.md`.
2. **Never publish with blockers.** Blockers prevent both PR creation and PR refresh.
3. **Never mutate product code.** This is coordination-doc and PR-body work only.
4. **Never transition story statuses.** `epic_story_pr` owns story PR state.
5. **Never include unfinished story scope in the PR body.** Report it only in check-in/final response.
6. **Never include verification commands or proof matrices in the epic PR body.**
7. **Never summarize or quote original tickets.** Include links only.
8. **Never overwrite a substantial existing PR body without operator choice.**

## Final response

State:

- epic resolved
- PR URL, number, title, and branch
- included sources
- excluded unfinished stories, if any
- original ticket links included, if any
- blockers resolved during the repair loop, if any
- whether `MASTER.md` `## Epic PR Tracking` was written
- next action for the operator
