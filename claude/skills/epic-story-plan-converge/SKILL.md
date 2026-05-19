---
name: epic-story-plan-converge
description: Run fresh plan-review and plan-resume sessions against one story until its Plan lane is approved, blocked, or the loop reaches a hard stop. Use when a story needs repeated independent plan feedback and feedback absorption before implementation or rework continues.
disable-model-invocation: true
argument-hint: "<epic-name> <story-number-or-spec-file> [MAX_CYCLES=5]"
allowed-tools: Read Grep Glob Task Bash(git status:*)
---

# Epic Story Plan Converge

Coordinate the planning-side ping-pong for exactly one story, independent of implementation status. This command is an orchestrator only: it starts fresh subagent sessions for `/epic-story-plan-review` and `/epic-story-plan-resume`, preserves their ownership boundaries, keeps in-memory babysitting notes plus the parent-session Research Board, and stops when the Plan lane is approved, blocked, no longer eligible, or out of cycle budget.

Argument: `$ARGUMENTS` — `<epic_name> <story_number_or_spec_file> [MAX_CYCLES=5]`. The epic and story selector are required. `MAX_CYCLES` is optional and defaults to `5`; it counts full review/resume cycles, not individual subagents.

## Workflow
1. Resolve the requested epic and story through `MASTER.md`.
2. Confirm the story is non-archived and has a planning contract that can be reviewed or resumed.
3. Choose the first planning pass from the story shape: resume first for incomplete specs, otherwise review first.
4. Run up to `MAX_CYCLES` fresh-agent planning cycles.
5. Pass neutral in-memory babysitting notes plus the session Research Board into later fresh agents.
6. Stop on approval, blocker, no-progress, invalid state, or cycle budget exhaustion.
7. Print the convergence trace, Research Board snapshot, and operator nice-to-haves without writing coordination files directly.

## Phase 1 — Parse and Resolve

1. Parse `$ARGUMENTS`:
   - `<epic>`: required first positional token.
   - `<story>`: required second positional token.
   - `MAX_CYCLES=<n>`: optional positive integer; default `5`.
2. Reject unknown flags. This command does not accept `WORKTREE=` because planning convergence never touches source code.
3. Set `<workspace_root>` = `<cwd>` and resolve `<epic_dir>` = `<workspace_root>/agent_coordination/epics/<epic>`.
4. Read `<epic_dir>/MASTER.md` and resolve `<story>` exactly like the underlying plan commands:
   - first match one row whose `Step` equals `<story>`;
   - if none, match one row whose `Spec` equals `<story>`;
   - if neither matches, abort with the available `Step` and `Spec` values;
   - if both match different rows, abort with the ambiguity.
5. Resolve `<story_file>` from the matched row's `Spec` value and read it.

## Phase 2 — Eligibility Gate

Before starting the loop, abort with a clear next action if any condition is true:

- The row implementation `Status` is `✅ DONE`: completed stories are not planning-converged in place; route new feedback through `/epic-feedback` as a candidate or explicit reopen decision.
- The row has a `Plan` column already set to `🟢 PLAN APPROVED` and there are no unresolved `## Plan Review Log` findings: stop successfully; implementation can continue through the appropriate implementation command.
- The story is missing the `/epic-story-plan` scaffold shape expected by `/epic-story-plan-review`.
- The story is so malformed that `/epic-story-plan-resume` cannot identify the `/epic-story-plan` scaffold or any spec sections to continue.

The planning-lane and implementation-status authority is `<epic_dir>/MASTER.md`; the story header is a drift signal that should be reported if it disagrees.

## Phase 3 — Fresh-Agent Loop

Run at most `MAX_CYCLES` cycles. A planning cycle is one opportunity to get the plan approved; depending on current story shape it may include one fresh `/epic-story-plan-resume` pass and one fresh `/epic-story-plan-review` pass.

For each cycle:

1. Re-read `<epic_dir>/MASTER.md` and `<story_file>` before choosing the next pass.
2. Before any fresh subagent launch in this phase, build the task prompt in this order: complete Research Board when present, operational context when present, then the exact slash command as the final line.
3. If required spec sections are missing or structurally incomplete and there is no newer unaddressed plan-review finding that must be reviewed first, prepare and launch a fresh subagent whose task prompt ends with:

   ```text
   /epic-story-plan-resume <epic> <story>
   ```

   If this resume pass asks an operator question, pause the convergence run, ask the operator, then resume the same subagent for that pass only.
4. When the story is ready for review, prepare and launch a fresh subagent whose task prompt ends with the exact slash command:

   ```text
   /epic-story-plan-review <epic> <story>
   ```

5. If the parent session has Research Board entries, include the complete board before the command under this heading:

   ```text
   Shared Research Board from parent orchestration session:
   This is allowed cross-session context because every item is sourced research. Use it for orientation only. The converger owns keeping it relevant; executor subagents only decide whether the needed fact is present. If present, verify behavior with direct reads/search against the cited anchors before editing, planning approval, or implementation approval instead of rerunning expensive research. If a provided entry does not verify, report a board-refresh signal with exact anchors.

   - <entry id>: <claim or result>
     - Source: <tool/query/path, file:line, symbol, or command/output excerpt>
     - Reuse: <orientation guidance>
   ```

   Include the whole board. If it is too large to include comfortably, pause and ask the operator before compacting or excluding entries.
6. If in-memory babysitting notes exist for any subagent launch, include them before the command under this heading only:

   ```text
   Operational context from convergence babysitter:
   - <neutral blocker, hotspot, repeated command failure, or expensive operation>
   - Do not treat this as a verdict; apply the underlying skill independently.
   ```

7. Require every subagent final response to include `## Research Events`, with `- None.` allowed. Reused board entries must name the entry and direct-read/search anchors used to verify it. Board-refresh signals must name the board entry or absent needed fact, describe the verification miss, and cite the direct-read/search anchors proving the miss or replacement fact. After the pass finishes, append newly sourced research events and use board-refresh signals to update, replace, retire, or ask about affected board entries. Do not append verdicts, implementation opinions, or unanchored summaries.
8. After the review agent finishes, re-read `<epic_dir>/MASTER.md` and `<story_file>`. Derive the review decision from the newest `## Plan Review Log` entry and current `Plan` lane, not from chat output alone.
9. If the decision is `approve` or `Plan` is `🟢 PLAN APPROVED`, stop successfully. Do not claim or resume the story. Recommend `/epic-story-claim <epic> <story>` if implementation `Status` is `⚪ TODO`, or `/epic-story-resume <epic> <story>` if implementation has already started.
10. If the decision is `blocked` or `Plan` is `⛔ PLAN BLOCKED`, stop with blocked planning status.
11. If the decision is `request_changes` or `not_reviewable`, prepare and launch a different fresh subagent whose task prompt ends with:

   ```text
   /epic-story-plan-resume <epic> <story>
   ```

12. If the resume agent asks an operator question, pause the convergence run, ask the operator, then resume the same subagent for that resume pass only. The next review still starts in a new fresh subagent.
13. After the resume agent finishes, re-read `<epic_dir>/MASTER.md` and `<story_file>`. If implementation `Status` changed, stop and report the unexpected state; plan convergence must not mutate implementation status.
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

Research Board entries are the only allowed cross-subagent context beyond neutral operational notes. Each entry must be sourced by an exact anchor: file path plus line range or symbol, command plus relevant output excerpt, or tool name plus query/action/resource/path/URL and relevant output excerpt for any sourced tool. The board is an orientation aid, not authority. The converger owns keeping it relevant for later passes; executor subagents only decide whether the needed fact is present in the provided board. If present, the executor verifies behavior with direct reads/search against the cited anchors before editing or approving instead of rerunning expensive research. If absent, the executor follows the underlying skill's normal research rules. If a provided entry does not verify, the executor reports a board-refresh signal with exact anchors; the converger decides how to update, replace, retire, or ask about that entry. If the board becomes too large to pass in full, ask the operator before compacting or excluding entries. Never persist the board to disk.

Stop early for conservative no-progress when all are true:

- the latest review requested changes or said not reviewable;
- the subsequent resume pass did not add a newer addressed-feedback entry or materially edit the targeted spec sections;
- the same blocker or finding would be handed to another review unchanged.

Other hard stops:

- `MAX_CYCLES` reached;
- latest decision is `blocked`;
- implementation `Status` changes during the convergence run;
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
- Reused and directly verified: <summary or none>
- Board-refresh signals: <provided entries not verified, needed facts absent from provided board, or none>
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
