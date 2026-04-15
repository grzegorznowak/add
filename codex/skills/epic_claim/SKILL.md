---
name: epic_claim
description: Claim one ready epic step and execute it
legacy-argument-hint: '[EPIC="<epic_name>"]'
---

This skill was migrated one-to-one from the former custom prompt `epic_claim.md`.
Invoke it explicitly with `$epic_claim`.

Original argument hint: `[EPIC="<epic_name>"]`

If the user supplies text alongside the explicit skill invocation, treat that text as additional context for the instructions below.

Implementation: $EPIC

Treat `$EPIC` as the exact directory name of an epic under the agent's current
working directory at:
`agent_coordination/epics`

Your job is to pick exactly one ready and unclaimed step from that epic,
claim it in the coordination docs, execute it, and leave behind a clean handoff.


Do **not** try to rediscover or redefine the epic from scratch.
The workflow is:
1. read the epic master
2. pick one ready step
3. claim it
4. work only that step plus required dependencies
5. move it to `IN REVIEW` after implementation is complete
6. leave the step file in a state that the next fresh session can continue

## Resolution
1. Resolve the epic directory as:
   - `<cwd>/agent_coordination/epics/$EPIC`
2. If that directory does not exist, stop and report the exact missing path.
3. Read first:
   - the main repo `AGENTS.md` for the repo you will touch
   - `<epic>/MASTER.md`

## Source-of-truth hierarchy
1. `<epic>/MASTER.md`
2. the claimed step file
3. dependency step files listed in the master table
4. repo code and tests

Anything else is background only unless the claimed step explicitly requires it.

## Step selection
From `<epic>/MASTER.md`, select the first step that is all of:
- unclaimed:
  - status is `⬜ TODO`, `TODO`, or otherwise clearly unclaimed
- ready:
  - every dependency listed in `Depends` is marked `✅ DONE` or `DONE`
- concrete:
  - the referenced step file exists

If no such step exists:
- do not guess
- stop after a concise report listing:
  - no-ready-step reason
  - blocked steps
  - next step that must complete first

## Claim protocol
Before deep implementation work:
1. Update the selected row in `MASTER.md` to:
   - `🔄 IN PROGRESS`
2. Update the selected step file by adding or refreshing these sections:

```md
## Active Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: Codex fresh session
- Scope: <one sentence>
- Primary write surfaces: <paths>

## Progress Log
- <UTC ISO timestamp> Claimed step and started implementation.
```

3. Do not claim more than one step in a single session.
4. Do not silently switch to a different step once work has started.

## Execution rules
- Treat `MASTER.md` plus the claimed step file as the source of truth.
- Read dependency step files for context, but do not widen scope unless required
  to finish the claimed step correctly.
- Implement the claimed step end-to-end when feasible.
- Prefer code changes over restating plans.
- If you discover an epic-wide architectural contradiction, update `MASTER.md`
  minimally and note it in the step file.
- If the claimed step turns out to be blocked by an unmet dependency or hard
  contradiction, stop broadening scope and mark it clearly as blocked.

## Progress tracking
While working, keep the claimed step file updated.

Append concise timestamped bullets under `## Progress Log` after meaningful
milestones, for example:
- design change locked
- files patched
- tests added/updated
- blocker discovered
- epic-wide finding recorded in `MASTER.md`

Do not wait until the very end to record progress.

## Parallelism guard
Assume other fresh sessions may work on nearby steps.
- Avoid touching files outside the claimed step's primary write surfaces unless
  required to finish the step correctly.
- If you must cross that boundary, record it immediately in the progress log.

## Finish protocol
At the end of the session, update the claimed step file with:

```md
## Session Handoff
- Status: done | blocked | in progress | in review
- What changed: <short bullets>
- Files touched: <paths>
- Tests run: <commands/results or not run>
- Remaining work: <short bullets>
- Blockers / risks: <short bullets>
- Exact next step: <one concrete recommendation>
```

Then update `MASTER.md` status for the claimed row using this lifecycle:
- `🔄 IN PROGRESS`
  - implementation is still actively underway
- `🟣 IN REVIEW`
  - implementation is done enough for review
  - run final verification, review the touched files, and tighten any rough edges
  - do not mark `DONE` before this pass
- `🔵 IN PR` (optional)
  - local review passed and the changes are in a GitHub pull request awaiting
    remote review and merge
  - do not set this status from `epic_claim`; use the `epic_pr` flow to record
    PR metadata on the step file
- `✅ DONE`
  - implementation and review are complete, and if a PR stage was used the PR
    is merged
- `⛔ BLOCKED`
  - an external blocker prevents completion or review

Default rule:
1. claim as `🔄 IN PROGRESS`
2. once implementation is complete, move to `🟣 IN REVIEW`
3. then either:
   - move straight to `✅ DONE` if no GitHub PR stage is needed, or
   - use `epic_pr` to transition to `🔵 IN PR` and move to `✅ DONE` only
     after the PR is merged
4. if the session ends before review is complete, leave it at `🟣 IN REVIEW`
5. if the session ends before implementation is complete, leave it at `🔄 IN PROGRESS`

If the epic's `MASTER.md` `Legend` section does not list `🔵 IN PR`, add it
immediately after the `🟣 IN REVIEW` line:

```md
- `🔵 IN PR` — local review passed, PR opened, awaiting GitHub review + merge
```

## Final response
In your final response, state:
- which step you claimed
- its final status
- files changed
- whether the epic master was updated
- the exact next action for the next fresh session
