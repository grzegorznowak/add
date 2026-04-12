---
name: epic-resume
description: Pick up one already in-progress epic step and continue it. Use when a fresh session needs to resume ongoing work on a specific story.
disable-model-invocation: true
argument-hint: "<epic-name> [story-number-or-spec-file]"
allowed-tools: Read Edit Write Grep Glob Bash
---

# Epic Resume

Continue exactly one already-ongoing epic step, following the existing handoff / review guidance, and leave the coordination docs in a state the next fresh session can trust.

Argument: `$ARGUMENTS` — `<epic_name> [<story_number_or_spec_file>]`. The epic name is required. The story selector is optional; when omitted and there is exactly one in-progress step, it is selected automatically.

Do **not** claim a new step. Do **not** rediscover or redefine the epic from scratch.

## Workflow
1. Read the epic master
2. Locate the already in-progress step
3. Refresh the claim / progress state for this continuation session
4. Carry the step forward using the latest concrete CTA
5. Leave it in `🔄 IN PROGRESS`, `🟣 IN REVIEW`, or `⛔ BLOCKED`
6. Leave a clean handoff for the next fresh session

## Resolution

1. Parse `$ARGUMENTS` as `<epic> [<story>]`
2. Resolve the epic directory as `<cwd>/agent_coordination/epics/<epic>`
3. If that directory does not exist, stop and report the exact missing path
4. Read first:
   - the main repo `AGENTS.md` for the repo you will touch
   - `<epic>/MASTER.md`

## Step selection

**If `<story>` was provided:**
- use `<epic>/MASTER.md` as the only lookup table
- first try to match exactly one row whose `Step` value equals the selector
- if no row matches by `Step`, try to match exactly one row whose `Spec` value equals the selector
- if neither lookup finds a row, stop and report the unresolved selector plus the available `Step` and `Spec` values from `MASTER.md`
- if the `Step` lookup and `Spec` lookup both match but point to different rows, stop and report the ambiguity
- resolve the selected step file from the matched row's `Spec` value
- if that file does not exist under `<epic>/`, stop and report the exact missing path
- if the resolved row is not `🔄 IN PROGRESS` or `🔵 IN PR` with PR changes requested, stop and report the actual status

**If `<story>` was not provided:**
- collect every row in `MASTER.md` marked `🔄 IN PROGRESS`
- also collect rows marked `🔵 IN PR` **only if** the PR is currently requesting code changes (check the step file's `## PR Tracking` section `PR status` field; `changes_requested` is a resumable signal)
- if there are none, stop and recommend `/epic-claim` instead
- if there is exactly one, select it
- if there are multiple, stop and list each candidate; do not guess

## Read before implementing

After the step is resolved, read:
1. the selected step file
2. dependency step files listed for it in `MASTER.md`
3. the latest relevant sections inside the step file:
   - `## Active Claim`
   - `## Progress Log`
   - `## Session Handoff`
   - `## Review Log`
   - `## PR Tracking` (only present on steps that went through `/epic-pr`)

If the step is `🔵 IN PR` and the PR is requesting code changes, treat the PR review comments as the authoritative CTA for this continuation and move the step back to `🔄 IN PROGRESS` for the duration of the session.

## Source-of-truth hierarchy

1. `<epic>/MASTER.md`
2. the selected step file
3. dependency step files listed in the master table
4. repo code and tests

## Resume intent

Treat this as continuation work, not a new claim.

Use the latest concrete guidance in this order:
1. newest `Review Log` entry with blocking findings or a concrete next action
2. latest `Session Handoff`
3. latest `Progress Log` milestone
4. the step `Goal` / `Acceptance`

If these conflict, prefer the higher source in the list above and record the conflict in the progress log.

## Claim refresh protocol

Before deep implementation work:

1. Refresh the existing `## Active Claim` section:

```md
## Active Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: Claude continuation session
- Scope: <one sentence for this pickup chunk>
- Primary write surfaces: <paths>
```

2. Append a new timestamped bullet under `## Progress Log`:

```md
- <UTC ISO timestamp> Picked up existing in-progress step and resumed work from the latest handoff/review CTA.
```

3. Do not create a second `Active Claim` section.
4. Do not silently switch to a different step once work has started.

## Execution rules

- Treat `MASTER.md` plus the selected step file as the source of truth
- Respect the latest review/handoff CTA before widening scope
- Continue only this step plus required dependencies
- Prefer code changes over restating plans
- If the step is in progress because of review feedback, address that feedback first
- If you discover an epic-wide architectural contradiction, update `MASTER.md` minimally and note it in the step file
- If the step is blocked by a hard external dependency or contradiction, stop broadening scope and mark it `⛔ BLOCKED`

## Progress tracking

Append concise timestamped bullets under `## Progress Log` after meaningful milestones. Do not wait until the end to record progress.

## Parallelism guard

Avoid touching files outside the selected step's primary write surfaces unless required. Record any boundary crossing in the progress log.

## Finish protocol

At the end of the session:

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

Update `MASTER.md` status using this lifecycle:
- `🔄 IN PROGRESS` — implementation or requested-change work still underway
- `🟣 IN REVIEW` — outstanding implementation work complete, ready for a fresh review pass
- `🔵 IN PR` (optional) — local review passed, PR awaiting GitHub review + merge. **Do not set this status from `/epic-resume`**; use `/epic-pr` to record PR metadata.
- `✅ DONE` — only if a real review pass completes and passes in this session AND any PR stage is merged
- `⛔ BLOCKED` — external blocker prevents completion or review

**Default rule:**
1. Resume at `🔄 IN PROGRESS`
2. Once outstanding implementation is complete, move to `🟣 IN REVIEW`
3. Then either move straight to `✅ DONE` if no PR stage is needed, or hand off to `/epic-pr` which transitions to `🔵 IN PR`
4. If resuming a `🔵 IN PR` step that is requesting changes, move to `🔄 IN PROGRESS` while working, then back to `🔵 IN PR` via `/epic-pr` once the new push is ready for another review round
5. If the session ends before review is complete, leave at `🟣 IN REVIEW`
6. If the session ends before implementation is complete, leave at `🔄 IN PROGRESS`

If the epic's `MASTER.md` Legend does not list `🔵 IN PR`, add it after the `🟣 IN REVIEW` line:

```md
- `🔵 IN PR` — local review passed, PR opened, awaiting GitHub review + merge
```

## Final response

State:
- which step was resumed (number and spec file)
- final status
- files changed
- whether the epic master was updated
- the exact next action for the next fresh session
