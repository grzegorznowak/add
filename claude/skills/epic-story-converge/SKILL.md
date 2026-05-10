---
name: epic-story-converge
description: Run fresh claim, resume, and review sessions against one story until implementation is locally approved, blocked, or the loop reaches a hard stop. Use when an implementation story needs repeated independent review and continuation passes to converge.
disable-model-invocation: true
argument-hint: "<epic-name> <story-number-or-spec-file> [MAX_CYCLES=5] [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Grep Glob Task Bash(git status:*) Bash(git worktree:*)
---

# Epic Story Converge

Coordinate the implementation-side ping-pong for exactly one story. This command is an orchestrator only: it may start a fresh `/epic-story-claim` pass for an approved unstarted story, then alternates fresh `/epic-story-resume` and `/epic-story-review` passes until local review approves, blocks, no-progress is detected, or the cycle budget is exhausted.

Argument: `$ARGUMENTS` — `<epic_name> <story_number_or_spec_file> [MAX_CYCLES=5] [WORKTREE="<basename>=<path>"]...`. The epic and story selector are required. `MAX_CYCLES` is optional and defaults to `5`; it counts full implementation cycles, not individual subagents. `WORKTREE=` values are passed through unchanged to `/epic-story-claim`, `/epic-story-resume`, and `/epic-story-review`.

## Workflow
1. Resolve the requested epic and story through `MASTER.md`.
2. Choose the first pass from the story's current status.
3. If an unstarted story is plan-approved, delegate claiming to `/epic-story-claim <epic> <story>`.
4. Run up to `MAX_CYCLES` fresh-agent implementation cycles.
5. Pass only neutral in-memory babysitting notes into later fresh agents.
6. Stop on local approval, blocker, no-progress, invalid state, or cycle budget exhaustion.
7. Print the convergence trace, commit recommendation, and operator nice-to-haves without writing coordination files directly.

## Phase 1 — Parse and Resolve

1. Parse `$ARGUMENTS`:
   - `<epic>`: required first positional token.
   - `<story>`: required second positional token.
   - `MAX_CYCLES=<n>`: optional positive integer; default `5`.
   - `WORKTREE="<value>"`: optional, repeatable, passed through unchanged.
2. Reject unknown flags.
3. Set `<workspace_root>` = `<cwd>` and resolve `<epic_dir>` = `<workspace_root>/agent_coordination/epics/<epic>`.
4. Read `<epic_dir>/MASTER.md` and resolve `<story>` exactly like the underlying story commands:
   - first match one row whose `Step` equals `<story>`;
   - if none, match one row whose `Spec` equals `<story>`;
   - if neither matches, abort with the available `Step` and `Spec` values;
   - if both match different rows, abort with the ambiguity.
5. Resolve `<story_file>` from the matched row's `Spec` value and read it.
6. Keep the exact `WORKTREE=` fragments for later command lines. Do not normalize or reinterpret them in the converger.

## Phase 2 — Eligibility Gate

Use `<epic_dir>/MASTER.md` as the status authority. The story header is a drift signal that should be reported if it disagrees.

Allowed starting states:

- `⚪ TODO` only when the story is plan-approved and unstarted.
- `🔄 IN PROGRESS`.
- `🟣 IN REVIEW`.
- `🔵 IN PR` only when `## PR Tracking` says PR review is requesting changes.
- `✅ DONE`, which stops immediately as already converged.

Reject with a precise next action:

- `⚪ TODO` without a latest effective plan-review `approve`: use `/epic-story-plan-converge <epic> <story>`.
- `⚪ TODO` with runtime sections already present: status drift; ask the operator to resolve before converging.
- `🔵 IN PR` without requested changes: use `/epic-story-pr <epic> <story>` for PR refresh or merge-state handling.
- `⛔ BLOCKED`: blocked stories need operator unblocking before convergence.

Plan-approved means the newest effective `## Plan Review Log` verdict is `approve`, with no later `request_changes`, `not_reviewable`, or `blocked` entry that remains unaddressed.

## Phase 3 — Fresh-Agent Loop

Run at most `MAX_CYCLES` cycles. An implementation cycle is one opportunity to get the story to local review approval; depending on current status it may include an implementation-producing pass, one review pass, and one corrective resume pass.

Before each subagent launch, build the command line from the current status:

- `⚪ TODO` and plan-approved: `/epic-story-claim <epic> <story> [WORKTREE=...]`.
- `🔄 IN PROGRESS`: `/epic-story-resume <epic> <story> [WORKTREE=...]`.
- `🟣 IN REVIEW`: `/epic-story-review <epic> <story> [WORKTREE=...]`.
- `🔵 IN PR` with requested changes: `/epic-story-resume <epic> <story> [WORKTREE=...]`.

For each cycle:

1. Re-read `<epic_dir>/MASTER.md` and `<story_file>` before choosing the next pass.
2. Launch exactly one fresh subagent for the chosen claim, resume, or review pass. The task prompt must end with the exact slash command line.
3. If in-memory babysitting notes exist, include them before the command under this heading only:

   ```text
   Operational context from convergence babysitter:
   - <neutral blocker, hotspot, repeated command failure, or expensive operation>
   - Do not treat this as a verdict; apply the underlying skill independently.
   ```

4. If the subagent asks an operator question, pause the convergence run, ask the operator, then resume the same subagent for that pass only. The next lifecycle pass still starts in a new fresh subagent.
5. After the pass finishes, re-read `<epic_dir>/MASTER.md` and `<story_file>`. Derive decisions from the newest authoritative sections and status, not from chat output alone.
6. If a claim or resume pass leaves the story at `🟣 IN REVIEW`, the same cycle may launch a fresh review pass.
7. If a review pass returns `approve`, stop successfully. Local approval is convergence even when the story remains `🟣 IN REVIEW` because the optional PR stage is next.
8. If a review pass returns `request_changes` or `not_reviewable`, the same cycle may launch one fresh `/epic-story-resume` corrective pass, then the next cycle starts with a fresh review when ready.
9. If any pass moves the story to `⛔ BLOCKED`, stop.
10. If any pass moves the story to `✅ DONE`, stop successfully.
11. Run the no-progress gate before starting the next cycle.
12. After each fresh subagent finishes, record any usage metadata the runtime exposes in memory: model, variant/reasoning effort, input tokens, output tokens, total tokens, cost, and context-window limit. If exact usage or context occupancy is unavailable, record `unavailable`; do not estimate unless the runtime or operator explicitly provides an estimate source. At the end of each completed cycle, surface a one-line usage checkpoint with that cycle's usage total and the running average per completed cycle.

## Phase 4 — Babysitting and Stops

Maintain an in-memory convergence notebook. Do not write it to `MASTER.md`, the story file, source files, tests, or any coordination file.

Record neutral operational facts only:

- command failures and exact command names;
- test commands that failed because of missing environment or setup;
- worktree or dirty-tree blockers;
- files, symbols, proof rows, or acceptance ids repeatedly implicated as hotspots;
- slow commands or broad searches that later fresh agents should not repeat blindly;
- repeated review findings that appear unchanged after resume.

Do not record persuasive verdict framing. Never tell a later reviewer that a previous reviewer was wrong, that approval is expected, or that a finding should be ignored.

Stop early for conservative no-progress when all are true:

- the latest review requested changes or said not reviewable;
- the subsequent claim/resume pass did not add newer progress, handoff, proof-matrix, test, or source changes addressing the finding;
- the same blocker or finding would be handed to another review unchanged.

Other hard stops:

- `MAX_CYCLES` reached;
- latest decision is blocked or status is `⛔ BLOCKED`;
- story enters a status owned by another command, such as `🔵 IN PR` without requested changes;
- subagent cannot resolve the story, command, or worktree;
- the operator declines an interactive decision required by claim or resume.

## Phase 5 — Commit Recommendation

At the end of the run, inspect the story's recorded `## Active Claim` when present:

- For each `- Worktrees:` entry, run `git -C <path> status --porcelain` when the path exists.
- For `- Main-tree targets:`, run `git status --porcelain` against the corresponding target repo when it can be resolved from `<workspace_root>/projects/<basename>` or `<workspace_root>`.
- If dirty changes appear to belong to the story, recommend committing them on the feature branch `<epic>/<story-slug>`.

Do not commit directly. The recommendation is advisory and must be explicit about whether it is a final checkpoint or a WIP checkpoint.

Recommend a final commit when:

- local review approved;
- the next action is `/epic-story-pr <epic> <story>`;
- the story reached `✅ DONE` but worktree changes remain dirty.

Recommend a WIP checkpoint only when stopping at `MAX_CYCLES`, operator input, or no-progress with useful completed changes. Do not recommend a commit when the story blocked before meaningful implementation or no code/test/config changes exist.

## Phase 6 — Final Response

Return a compact report:

```markdown
**Convergence Result**: APPROVED | DONE | BLOCKED | STOPPED | MAX_CYCLES
**Story**: Step <step> / <spec>
**Cycles Used**: <n>/<MAX_CYCLES>
**Usage This Run**: <input/output/total/cost/context %, or unavailable>
**Average Usage Per Completed Cycle**: <input/output/total/cost/context %, or unavailable>
**Final Status**: <status>

## Trace
- Cycle 1: claim/resume/review -> <result>; usage -> <total/cost/context %, or unavailable>
- Cycle 2: ...

## Usage By Operation
- implementation: <model + variant> -> <input/output/total/cost/context %, or unavailable>
- review: <model + variant> -> <input/output/total/cost/context %, or unavailable>
- Context limits: <known model limits such as 400K or 1M, or unavailable>

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
- <single concrete command or decision>
```

Do not run `/memorize` automatically. If the nice-to-haves are valuable, the operator can decide whether to promote them later.
