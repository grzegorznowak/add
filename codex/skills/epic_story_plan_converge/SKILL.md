---
name: epic_story_plan_converge
description: Run fresh plan-review and plan-resume sessions until one TODO story plan is approved or stopped
---

Epic story plan converge: $EPIC / $STORY

Treat `$EPIC` as the exact directory name of an epic under `agent_coordination/epics`, and `$STORY` as a `MASTER.md` `Step` value or `Spec` filename. `$MAX_CYCLES` is optional and defaults to `5`; it counts full review/resume cycles, not individual fresh agents.

Coordinate the planning-side ping-pong for exactly one `⚪ TODO` story. This command is an orchestrator only: it starts fresh agentic sessions for `/epic-story-plan-review` and `/epic-story-plan-resume`, preserves their ownership boundaries, keeps in-memory babysitting notes plus the parent-session Research Board, and stops when the plan is approved, blocked, no longer eligible, or out of cycle budget.

## Workflow
1. Resolve the requested epic and story through `MASTER.md`.
2. Confirm the story is still `⚪ TODO` and in the planning phase.
3. Choose the first planning pass from the story shape: resume first for incomplete specs, otherwise review first.
4. Run up to `$MAX_CYCLES` fresh-agent planning cycles.
5. Pass neutral in-memory babysitting notes plus the session Research Board into later fresh agents.
6. Stop on approval, blocker, no-progress, invalid state, or cycle budget exhaustion.
7. Print the convergence trace, Research Board snapshot, and operator nice-to-haves without writing coordination files directly.

## Phase 1 — Parse and Resolve

1. Parse the operator input:
   - `$EPIC`: required epic slug.
   - `$STORY`: required story selector.
   - `$MAX_CYCLES`: optional positive integer; default `5`.
2. Reject unknown flags. This command does not accept `$WORKTREE` because planning convergence never touches source code.
3. Set `<workspace_root>` = `<cwd>` and resolve `<epic_dir>` = `<workspace_root>/agent_coordination/epics/$EPIC`.
4. Read `<epic_dir>/MASTER.md` and resolve `$STORY` exactly like the underlying plan commands:
   - first match one row whose `Step` equals `$STORY`;
   - if none, match one row whose `Spec` equals `$STORY`;
   - if neither matches, abort with the available `Step` and `Spec` values;
   - if both match different rows, abort with the ambiguity.
5. Resolve `<story_file>` from the matched row's `Spec` value and read it.

## Phase 2 — Eligibility Gate

Before starting the loop, abort with a clear next action if any condition is true:

- The row status or story header is not `⚪ TODO`: this is not a planning convergence target.
- The story contains runtime sections such as `## Active Claim`, `## Progress Log`, `## Session Handoff`, `## Review Log`, or `## PR Tracking`: use `/epic-story-converge` if implementation has started.
- The story is missing the `/epic-story-plan` scaffold shape expected by `/epic-story-plan-review`.
- The story is so malformed that `/epic-story-plan-resume` cannot identify the `/epic-story-plan` scaffold or any spec sections to continue.

The status authority is `<epic_dir>/MASTER.md`; the story header is a drift signal that should be reported if it disagrees.

## Phase 3 — Fresh-Agent Loop

Run at most `$MAX_CYCLES` cycles. A planning cycle is one opportunity to get the plan approved; depending on current story shape it may include one fresh `/epic-story-plan-resume` pass and one fresh `/epic-story-plan-review` pass.

For each cycle:

1. Re-read `<epic_dir>/MASTER.md` and `<story_file>` before choosing the next pass.
2. Before any fresh session launch in this phase, build the task prompt in this order: complete Research Board when present, operational context when present, then the exact slash command as the final line.
3. If required spec sections are missing or structurally incomplete and there is no newer unaddressed plan-review finding that must be reviewed first, prepare and launch a fresh agentic session whose task prompt ends with:

   ```text
   /epic-story-plan-resume $EPIC $STORY
   ```

   If this resume pass asks an operator question, pause the convergence run, ask the operator, then resume the same agentic session for that pass only.
4. When the story is ready for review, prepare and launch a fresh agentic session whose task prompt ends with the exact slash command:

   ```text
   /epic-story-plan-review $EPIC $STORY
   ```

5. If the parent session has Research Board entries, include the complete board before the command under this heading:

   ```text
   Shared Research Board from parent orchestration session:
   This is allowed cross-session context because every item is sourced research. Use it for orientation only. Verify behavior against live source before editing, planning approval, or implementation approval.

   - <entry id>: <claim or result>
     - Source: <tool/query/path, file:line, symbol, or command/output excerpt>
     - Reuse: <orientation guidance>
   ```

   Include the whole board. If it is too large to include comfortably, pause and ask the operator before compacting or excluding entries.
6. If in-memory babysitting notes exist for any session launch, include them before the command under this heading only:

   ```text
   Operational context from convergence babysitter:
   - <neutral blocker, hotspot, repeated command failure, or expensive operation>
   - Do not treat this as a verdict; apply the underlying skill independently.
   ```

7. Require every subagent final response to include `## Research Events`, with `- None.` allowed. After the pass finishes, append only sourced research events to the in-memory Research Board. Do not append verdicts, implementation opinions, or unanchored summaries.
8. After the review agent finishes, re-read `<epic_dir>/MASTER.md` and `<story_file>`. Derive the review decision from the newest `## Plan Review Log` entry and current status, not from chat output alone.
9. If the decision is `approve`, stop successfully. Do not claim the story. Recommend `/epic-story-claim $EPIC $STORY` from a fresh session.
10. If the decision is `blocked` or the status is `⛔ BLOCKED`, stop with blocked status.
11. If the decision is `request_changes` or `not_reviewable`, prepare and launch a different fresh agentic session whose task prompt ends with:

   ```text
   /epic-story-plan-resume $EPIC $STORY
   ```

12. If the resume agent asks an operator question, pause the convergence run, ask the operator, then resume the same agentic session for that resume pass only. The next review still starts in a new fresh session.
13. After the resume agent finishes, re-read `<epic_dir>/MASTER.md` and `<story_file>`. If the story is no longer `⚪ TODO`, stop and report the unexpected state.
14. Run the no-progress gate before starting the next cycle.

## Phase 4 — Babysitting and Stops

Maintain an in-memory convergence notebook and an in-memory Research Board. Do not write either one to `MASTER.md`, the story file, or any coordination file.

Record neutral operational facts only:

- command failures and their exact command names;
- missing environment or worktree prerequisites;
- story sections or proof rows that repeatedly block progress;
- files or concepts that multiple agents identify as hotspots;
- time-consuming operations that later fresh agents should avoid repeating blindly.

Do not record persuasive verdict framing. Never tell a later reviewer that a previous reviewer was wrong, that approval is expected, or that a finding should be ignored.

Research Board entries are the only allowed cross-session context beyond neutral operational notes. Each entry must be sourced by an exact anchor: file path plus line range or symbol, command plus relevant output excerpt, or tool name plus query/action/resource/path/URL and relevant output excerpt for any sourced tool. The board is an orientation aid, not authority; every session must verify behavior against live source before editing or approving. If the board becomes too large to pass in full, ask the operator before compacting or excluding entries. Never persist the board to disk.

Stop early for conservative no-progress when all are true:

- the latest review requested changes or said not reviewable;
- the subsequent resume pass did not add a newer addressed-feedback entry or materially edit the targeted spec sections;
- the same blocker or finding would be handed to another review unchanged.

Other hard stops:

- `$MAX_CYCLES` reached;
- latest decision is `blocked`;
- story status changes away from `⚪ TODO`;
- subagent cannot resolve the story or command;
- the operator declines an interactive decision required by resume.

## Phase 5 — Final Response

Return only the compact report below. Do not include internal deliberation, analysis prose, "Thinking:" blocks, private rationale, or comments about what you are considering before or after the report. Include every section in the template; use `None.` or `unavailable` rather than omitting a section.

```markdown
**Convergence Result**: APPROVED | BLOCKED | STOPPED | MAX_CYCLES
**Story**: Step <step> / <spec>
**Cycles Used**: <n>/<MAX_CYCLES>
**Final Status**: <status>

## Trace
- Cycle 1: plan-review -> <decision>; plan-resume -> <completed/skipped>
- Cycle 2: ...

## Research Board Snapshot
- Entries: <n>
- Hotspots: <paths/symbols surfaced by sourced research, or none>
- New this run: <n>
- Corrected/stale-risk: <summary or none>
- Persistence: session memory only; no physical cache files written

## Babysitter Notes
- <neutral operational note>
- None.

## Operator Nice-To-Haves
- <proposed future improvement surfaced by repeated friction>
- None.

## Next Action
- <single concrete command or decision>
```

Do not run `/memorize` automatically. If the nice-to-haves are valuable, the operator can decide whether to promote them later.
