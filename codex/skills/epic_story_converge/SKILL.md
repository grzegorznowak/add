---
name: epic_story_converge
description: Run fresh claim, resume, and review sessions until one story implementation is locally approved or stopped
---

Epic story converge: $EPIC / $STORY

Treat `$EPIC` as the exact directory name of an epic under `agent_coordination/epics`, and `$STORY` as a `MASTER.md` `Step` value or `Spec` filename. `$MAX_CYCLES` is optional and defaults to `5`; it counts full implementation cycles, not individual fresh agents. `$WORKTREE` is optional and is passed through unchanged to `/epic-story-claim`, `/epic-story-resume`, and `/epic-story-review`.

Coordinate the implementation-side ping-pong for exactly one story. This command is an orchestrator only: it may start a fresh `/epic-story-claim` pass for an approved unstarted story, then alternates fresh `/epic-story-resume` and `/epic-story-review` passes until local review approves, blocks, no-progress is detected, or the cycle budget is exhausted. It carries the parent-session Research Board in memory across fresh passes without persisting research cache files.

## Workflow
1. Resolve the requested epic and story through `MASTER.md`.
2. Choose the first pass from the story's current status.
3. If an unstarted story is plan-approved, delegate claiming to `epic_story_claim <epic> <story>`.
4. Run up to `$MAX_CYCLES` fresh-agent implementation cycles.
5. Pass neutral in-memory babysitting notes plus the session Research Board into later fresh agents.
6. Stop on local approval, blocker, no-progress, invalid state, or cycle budget exhaustion.
7. Print the convergence trace, Research Board snapshot, commit recommendation, and operator nice-to-haves without writing coordination files directly.

## Phase 1 — Parse and Resolve

1. Parse the operator input:
   - `$EPIC`: required epic slug.
   - `$STORY`: required story selector.
   - `$MAX_CYCLES`: optional positive integer; default `5`.
   - `$WORKTREE`: optional pass-through worktree override list.
2. Reject unknown flags.
3. Set `<workspace_root>` = `<cwd>` and resolve `<epic_dir>` = `<workspace_root>/agent_coordination/epics/$EPIC`.
4. Read `<epic_dir>/MASTER.md` and resolve `$STORY` exactly like the underlying story commands:
   - first match one row whose `Step` equals `$STORY`;
   - if none, match one row whose `Spec` equals `$STORY`;
   - if neither matches, abort with the available `Step` and `Spec` values;
   - if both match different rows, abort with the ambiguity.
5. Resolve `<story_file>` from the matched row's `Spec` value and read it.
6. Keep the exact `$WORKTREE` value for later command lines. Do not normalize or reinterpret it in the converger.

## Phase 2 — Eligibility Gate

Use `<epic_dir>/MASTER.md` as the status authority. The story header is a drift signal that should be reported if it disagrees.

Allowed starting states:

- `⚪ TODO` only when the story is plan-approved and unstarted.
- `🔄 IN PROGRESS`.
- `🟣 IN REVIEW`.
- `🔵 IN PR` only when `## PR Tracking` says PR review is requesting changes.
- `✅ DONE`, which stops immediately as already converged.

Reject with a precise next action:

- `⚪ TODO` without a latest effective plan-review `approve`: use `/epic-story-plan-converge $EPIC $STORY`.
- `⚪ TODO` with runtime sections already present: status drift; ask the operator to resolve before converging.
- `🔵 IN PR` without requested changes: use `/epic-story-pr $EPIC $STORY` for PR refresh or merge-state handling.
- `⛔ BLOCKED`: blocked stories need operator unblocking before convergence.

Plan-approved means: if the tracker has a `Plan` column, the matched row's `Plan` is exactly `🟢 PLAN APPROVED`; otherwise, the newest effective `## Plan Review Log` verdict is `approve`, with no later `request_changes`, `not_reviewable`, or `blocked` entry that remains unaddressed.

## Phase 3 — Fresh-Agent Loop

Run at most `$MAX_CYCLES` cycles. An implementation cycle is one opportunity to get the story to local review approval; depending on current status it may include an implementation-producing pass, one review pass, and one corrective resume pass.

Before each fresh session launch, build the command line from the current status:

- `⚪ TODO` and plan-approved: `/epic-story-claim $EPIC $STORY $WORKTREE`.
- `🔄 IN PROGRESS`: `/epic-story-resume $EPIC $STORY $WORKTREE`.
- `🟣 IN REVIEW`: `/epic-story-review $EPIC $STORY $WORKTREE`.
- `🔵 IN PR` with requested changes: `/epic-story-resume $EPIC $STORY $WORKTREE`.

For each cycle:

1. Re-read `<epic_dir>/MASTER.md` and `<story_file>` before choosing the next pass.
2. Re-resolve plan approval before any implementation-side dispatch. If the tracker has a `Plan` column and the row's `Plan` is not `🟢 PLAN APPROVED`, stop and redirect to `epic_story_plan_converge $EPIC $STORY`.
3. Build the exact slash command line for the chosen claim, resume, or review pass.
4. If the parent session has Research Board entries, include the complete board before the command under this heading:

   ```text
   Shared Research Board from parent orchestration session:
   This is allowed cross-session context because every item is sourced research. Use it for orientation only. Verify behavior against live source before editing, planning approval, or implementation approval.

   - <entry id>: <claim or result>
     - Source: <tool/query/path, file:line, symbol, or command/output excerpt>
     - Reuse: <orientation guidance>
   ```

   Include the whole board. If it is too large to include comfortably, pause and ask the operator before compacting or excluding entries.
5. If in-memory babysitting notes exist, include them before the command under this heading only:

   ```text
   Operational context from convergence babysitter:
   - <neutral blocker, hotspot, repeated command failure, or expensive operation>
   - Do not treat this as a verdict; apply the underlying skill independently.
   ```

6. End the task prompt with the exact slash command line, then launch exactly one fresh agentic session.
7. Require every subagent final response to include `## Research Events`, with `- None.` allowed. After the pass finishes, append only sourced research events to the in-memory Research Board. Do not append verdicts, implementation opinions, or unanchored summaries.
8. If the subagent asks an operator question, pause the convergence run, ask the operator, then resume the same agentic session for that pass only. The next lifecycle pass still starts in a new fresh session.
9. After the pass finishes, re-read `<epic_dir>/MASTER.md` and `<story_file>`. Derive decisions from the newest authoritative sections and status, not from chat output alone.
10. If a claim or resume pass leaves the story at `🟣 IN REVIEW`, the same cycle may launch a fresh review pass.
11. If a review pass returns `approve`, stop successfully. Local approval is convergence even when the story remains `🟣 IN REVIEW` because the optional PR stage is next. Report this as `APPROVED`, not `DONE`, unless the authoritative final status is already `✅ DONE`.
12. If a review pass returns `request_changes` or `not_reviewable`, the same cycle may launch one fresh `epic_story_resume` corrective pass, then the next cycle starts with a fresh review when ready.
13. If any pass moves the story to `⛔ BLOCKED`, stop.
14. If any pass moves the story to `✅ DONE`, stop successfully.
15. Run the no-progress gate before starting the next cycle.

## Phase 4 — Babysitting and Stops

Maintain an in-memory convergence notebook and an in-memory Research Board. Do not write either one to `MASTER.md`, the story file, source files, tests, or any coordination file.

Record neutral operational facts only:

- command failures and exact command names;
- test commands that failed because of missing environment or setup;
- worktree or dirty-tree blockers;
- files, symbols, proof rows, or acceptance ids repeatedly implicated as hotspots;
- slow commands or broad searches that later fresh agents should not repeat blindly;
- repeated review findings that appear unchanged after resume.

Do not record persuasive verdict framing. Never tell a later reviewer that a previous reviewer was wrong, that approval is expected, or that a finding should be ignored.

Research Board entries are the only allowed cross-session context beyond neutral operational notes. Each entry must be sourced by an exact anchor: file path plus line range or symbol, command plus relevant output excerpt, or tool name plus query/action/resource/path/URL and relevant output excerpt for any sourced tool. The board is an orientation aid, not authority; every session must verify behavior against live source before editing or approving. If the board becomes too large to pass in full, ask the operator before compacting or excluding entries. Never persist the board to disk.

Stop early for conservative no-progress when all are true:

- the latest review requested changes or said not reviewable;
- the subsequent claim/resume pass did not add newer progress, handoff, proof-matrix, test, or source changes addressing the finding;
- the same blocker or finding would be handed to another review unchanged.

Other hard stops:

- `$MAX_CYCLES` reached;
- latest decision is blocked or status is `⛔ BLOCKED`;
- story enters a status owned by another command, such as `🔵 IN PR` without requested changes;
- subagent cannot resolve the story, command, or worktree;
- the operator declines an interactive decision required by claim or resume.

## Phase 5 — Commit Recommendation

At the end of the run, inspect the story's recorded `## Active Claim` when present:

- For each `- Worktrees:` entry, run `git -C <path> status --porcelain` when the path exists.
- For `- Main-tree targets:`, run `git status --porcelain` against the corresponding target repo when it can be resolved from `<workspace_root>/projects/<basename>` or `<workspace_root>`.
- If dirty changes appear to belong to the story, recommend committing them on the feature branch `$EPIC/<story-slug>`.

Do not commit directly. The recommendation is advisory and must be explicit about whether it is a final checkpoint or a WIP checkpoint.

Recommend a final commit when:

- local review approved;
- the next action is `/epic-story-pr $EPIC $STORY`;
- the story reached `✅ DONE` but worktree changes remain dirty.

Recommend a WIP checkpoint only when stopping at `$MAX_CYCLES`, operator input, or no-progress with useful completed changes. Do not recommend a commit when the story blocked before meaningful implementation or no code/test/config changes exist.

When the final authoritative status is `✅ DONE`, do not suggest `/epic-story-pr` as the next action. `/epic-story-pr` is the next action only for local approval that leaves the story in `🟣 IN REVIEW` and the operator wants the optional PR stage.

## Phase 6 — Final Response

Return only the compact report below. Do not include internal deliberation, analysis prose, "Thinking:" blocks, private rationale, or comments about what you are considering before or after the report. Include every section in the template; use `None.` or `unavailable` rather than omitting a section.

```markdown
**Convergence Result**: APPROVED | DONE | BLOCKED | STOPPED | MAX_CYCLES
**Story**: Step <step> / <spec>
**Cycles Used**: <n>/<MAX_CYCLES>
**Final Status**: <status>

## Trace
- Cycle 1: claim/resume/review -> <result>
- Cycle 2: ...

## Research Board Snapshot
- Entries: <n>
- Hotspots: <paths/symbols surfaced by sourced research, or none>
- New this run: <n>
- Corrected/stale-risk: <summary or none>
- Persistence: session memory only; no physical cache files written

## Commit Recommendation
- <final commit, WIP checkpoint, or none>
- Suggested command: `git -C <path> status && git -C <path> add -A && git -C <path> commit -m "<epic>/<story-slug>: <summary>"`

## Babysitter Notes
- <neutral operational note>
- None.

## Operator Nice-To-Haves
- <proposed future improvement surfaced by repeated friction>
- None.

## Next Action
- <single concrete command or decision: `/epic-story-pr $EPIC $STORY` only when result is APPROVED and final status is `🟣 IN REVIEW`; `None. Story is already ✅ DONE.` when result is DONE; otherwise the next operator decision or rerun command>
```

Do not run `/memorize` automatically. If the nice-to-haves are valuable, the operator can decide whether to promote them later.
