---
name: epic-claim
description: Claim one ready epic step and execute it end-to-end, leaving a clean handoff. Use when starting a fresh session on a new story from an epic's MASTER.md tracker.
disable-model-invocation: true
argument-hint: "<epic-name>"
allowed-tools: Read Edit Write Grep Glob Bash
---

# Epic Claim

Pick exactly one ready, unclaimed step from an epic, claim it, execute it, and leave a clean handoff for the next session.

Argument: `$ARGUMENTS` — the epic directory name (e.g. `cure-core-review-pipeline`). Resolves to `agent_coordination/epics/$ARGUMENTS`. If omitted and there is exactly one active epic under `agent_coordination/epics/`, default to that one.

Do **not** try to rediscover or redefine the epic from scratch. Do **not** claim more than one step in a single session.

## Workflow
1. Read the epic `MASTER.md`
2. Pick one ready step
3. Claim it
4. Work only that step plus required dependencies
5. Move it to `🟣 IN REVIEW` after implementation is complete
6. Leave the step file in a state the next fresh session can continue

## Resolution

1. Resolve the epic directory as `<cwd>/agent_coordination/epics/$ARGUMENTS`
2. If that directory does not exist, stop and report the exact missing path
3. Read first:
   - the main repo `AGENTS.md` for the repo you will touch
   - `<epic>/MASTER.md`

## Source-of-truth hierarchy

1. `<epic>/MASTER.md`
2. the claimed step file
3. dependency step files listed in the master table
4. repo code and tests

## Step selection

From `<epic>/MASTER.md`, select the first step that is all of:
- **unclaimed**: status is `⬜ TODO`, `⚪ TODO`, or otherwise clearly unclaimed
- **ready**: every dependency listed in `Depends` is `✅ DONE`
- **concrete**: the referenced step file exists

If no such step exists:
- do not guess
- stop after a concise report listing: no-ready-step reason, blocked steps, and the next step that must complete first

## Claim protocol

Before deep implementation work:
1. Update the selected row in `MASTER.md` to `🔄 IN PROGRESS`
2. Add or refresh these sections in the step file:

```md
## Active Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: Claude fresh session
- Scope: <one sentence>
- Primary write surfaces: <paths>

## Progress Log
- <UTC ISO timestamp> Claimed step and started implementation.
```

3. Do not silently switch to a different step once work has started.

## Execution rules

- Treat `MASTER.md` plus the claimed step file as the source of truth
- Read dependency step files for context; do not widen scope unless required to finish the claimed step correctly
- Implement the claimed step end-to-end when feasible
- Prefer code changes over restating plans
- If you discover an epic-wide architectural contradiction, update `MASTER.md` minimally and note it in the step file
- If the claimed step is blocked by an unmet dependency or hard contradiction, stop broadening scope and mark it `⛔ BLOCKED`

## Progress tracking

Append concise timestamped bullets under `## Progress Log` after meaningful milestones:
- design change locked
- files patched
- tests added/updated
- blocker discovered
- epic-wide finding recorded in `MASTER.md`

Do not wait until the very end to record progress.

## Parallelism guard

Assume other fresh sessions may work on nearby steps. Avoid touching files outside the claimed step's primary write surfaces unless required. If you must cross that boundary, record it immediately in the progress log.

## Finish protocol

At the end of the session, update the step file:

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

Then update `MASTER.md` status using this lifecycle:
- `🔄 IN PROGRESS` — implementation still actively underway
- `🟣 IN REVIEW` — implementation done enough for review; run final verification, review the touched files, tighten rough edges
- `🔵 IN PR` (optional) — local review passed and changes are in a GitHub PR awaiting remote review and merge. **Do not set this status from `/epic-claim`**; use `/epic-pr` to record PR metadata.
- `✅ DONE` — implementation and review complete; if a PR stage was used, the PR is merged
- `⛔ BLOCKED` — an external blocker prevents completion or review

**Default rule:**
1. Claim as `🔄 IN PROGRESS`
2. Once implementation is complete, move to `🟣 IN REVIEW`
3. Then either:
   - move straight to `✅ DONE` if no GitHub PR stage is needed, or
   - use `/epic-pr` to transition to `🔵 IN PR` and move to `✅ DONE` only after the PR is merged
4. If the session ends before review is complete, leave at `🟣 IN REVIEW`
5. If the session ends before implementation is complete, leave at `🔄 IN PROGRESS`

If the epic's `MASTER.md` Legend section does not list `🔵 IN PR`, add it immediately after the `🟣 IN REVIEW` line:

```md
- `🔵 IN PR` — local review passed, PR opened, awaiting GitHub review + merge
```

## Final response

State:
- which step you claimed
- its final status
- files changed
- whether the epic master was updated
- the exact next action for the next fresh session
