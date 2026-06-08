---
name: openspec-story-converge
description: Run fresh claim, resume, and review sessions against one OpenSpec change until implementation is locally approved, blocked, or the loop reaches a hard stop. Use when an implementation story in an OpenSpec change workspace needs repeated independent review and continuation passes to converge.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug> [MAX_CYCLES=5] [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Grep Glob Task Bash(git status:*) Bash(git worktree:*)
---

# OpenSpec Story Converge

Coordinate the implementation-side iteration loop for exactly one OpenSpec change workspace. This command is an orchestrator only: it may start a fresh `/openspec-story-claim` pass for an approved unstarted story, then alternates fresh `/openspec-story-resume` and `/openspec-story-review` passes until local review approves, blocks, no-progress is detected, or the cycle budget is exhausted. It carries the parent-session Research Board in memory across fresh passes without persisting research cache files.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug> [MAX_CYCLES=5] [WORKTREE="<basename>=<path>"]...`. The initiative slug and story slug are required. `MAX_CYCLES` is optional and defaults to `5`; it counts full implementation cycles, not individual subagents. `WORKTREE=` values are passed through unchanged to `/openspec-story-claim`, `/openspec-story-resume`, and `/openspec-story-review`.

## Resolution Model

- `<workspace_root>` = `<cwd>`.
- `<initiative_dir>` = `<workspace_root>/openspec/initiatives/<initiative>`.
- `<initiative_file>` = `<initiative_dir>/initiative.md`.
- `<change_dir>` = `<workspace_root>/openspec/changes/<story-slug>`.
- `<story_file>` = `<change_dir>/story.md`.
- `<reviews_file>` = `<change_dir>/reviews.md`.
- `<progress_file>` = `<change_dir>/progress.md`.
- `<blocked_file>` = `<change_dir>/blocked.md`.

There is no `MASTER.md` and no tracker table. All status is self-contained in the change workspace artifacts:

- The `Status:` header field in `<story_file>` is the authoritative implementation status.
- The `Plan:` header field in `<story_file>` is the authoritative planning lane.
- The `## Current Claim` section in `<progress_file>` records active implementation state and worktree bindings.
- The `## Review Log` equivalent for implementation reviews is the standalone `<reviews_file>` artifact.

## Workflow
1. Resolve the requested initiative and change workspace through `openspec/initiatives/<slug>/initiative.md` and `openspec/changes/<story-slug>/story.md`.
2. Choose the first pass from the story's current status.
3. If an unstarted story is plan-approved, delegate claiming to `/openspec-story-claim <initiative> <story-slug>`.
4. Run up to `MAX_CYCLES` fresh-agent implementation cycles.
5. Pass neutral in-memory operational notes plus the session Research Board into later fresh agents.
6. Stop on local approval, blocker, no-progress, invalid state, or cycle budget exhaustion.
7. Print the convergence trace, Research Board snapshot, commit recommendation, and optional operator follow-ups without writing coordination files directly.

## Phase 1 — Parse and Resolve

1. Parse `$ARGUMENTS`:
   - `<initiative>`: required first positional token.
   - `<story-slug>`: required second positional token.
   - `MAX_CYCLES=<n>`: optional positive integer; default `5`.
   - `WORKTREE="<value>"`: optional, repeatable, passed through unchanged.
2. Reject unknown flags.
3. Set `<workspace_root>` = `<cwd>` and resolve `<initiative_dir>` = `<workspace_root>/openspec/initiatives/<initiative>`.
4. Read `<initiative_dir>/initiative.md`. If missing, abort with: `initiative not found — run /openspec-epic-plan first`.
5. Resolve `<change_dir>` = `<workspace_root>/openspec/changes/<story-slug>/`.
   - If missing, check `<workspace_root>/openspec/changes/archive/<story-slug>/`.
   - If archived, abort with: `story is archived; move it back to openspec/changes/ first`.
   - If missing in both, abort with: `change workspace not found — run /openspec-story-plan first`.
6. Read `<story_file>` and confirm the `Status:` header field is present (it may be default-valued or unset).
   - If `story.md` is missing or unreadable, abort with: `story.md is missing from change workspace`.
7. Keep the exact `WORKTREE=` fragments for later command lines. Do not normalize or reinterpret them in the converger.

## Phase 2 — Eligibility Gate

Use the `Status:` and `Plan:` header fields in `<story_file>` as the authoritative implementation status and planning lane. Check for `blocked.md` as an explicit gate file.

Allowed starting states:

- `Status:` is absent, unset, `⬜ TODO`, or `⚪ TODO` only when the story is plan-approved and the `## Current Claim` section in `<progress_file>` does not exist or is empty.
- `Status: 🔄 IN PROGRESS` only when `Plan:` is `🟢 PLAN APPROVED`.
- `Status: 🟣 IN REVIEW` only when `Plan:` is `🟢 PLAN APPROVED`.
- `Status: 🔵 IN PR` only when `<progress_file> → ## PR State` shows PR review is requesting changes and `Plan:` is `🟢 PLAN APPROVED`.
- `Status: ✅ DONE` only when durable evidence shows independent completion authority: either the latest relevant `<reviews_file>` entry approves with risk-lens/finding-closure evidence, or `<progress_file> → ## PR State` shows `PR status: merged` with both a populated merge commit and a populated merged-at timestamp.

Reject with a precise next action:

- Any non-DONE story whose `Plan:` header field exists and is not `🟢 PLAN APPROVED`: use `/openspec-story-plan-converge <initiative> <story-slug>`.
- `Status:` absent, `⬜ TODO`, or `⚪ TODO` with `## Current Claim` already present in `<progress_file>`: status drift; ask the operator to resolve before converging.
- `Status: ✅ DONE` without durable review approval or merged-PR evidence: status drift; ask the operator to restore `Status: 🟣 IN REVIEW` and run `/openspec-story-review <initiative> <story-slug>`, or refresh merged PR metadata with `/openspec-story-pr <initiative> <story-slug>`.
- `Status: 🔵 IN PR` without requested changes in `<progress_file> → ## PR State`: use `/openspec-story-pr <initiative> <story-slug>` for PR refresh or merge-state handling.
- `Status: ⛔ BLOCKED`: blocked stories need operator unblocking before convergence.
- `<blocked_file>` exists at `<change_dir>/blocked.md`: convergence is refused while an explicit gate file exists. The operator must remove or annotate `blocked.md` to unblock.

Plan-approved means `Plan:` is `🟢 PLAN APPROVED`. No other source is consulted for the plan state.

## Phase 3 — Fresh-Agent Loop

Run at most `MAX_CYCLES` cycles. An implementation cycle is one opportunity to get the story to local review approval; depending on current status it may include an implementation-producing pass, one review pass, and one corrective resume pass.

Before each subagent launch, build the command line from the current status:

- `Status:` absent/unset, `⬜ TODO`, or `⚪ TODO` and plan-approved: `/openspec-story-claim <initiative> <story-slug> [WORKTREE=...]`.
- `Status: 🔄 IN PROGRESS`: `/openspec-story-resume <initiative> <story-slug> [WORKTREE=...]`.
- `Status: 🟣 IN REVIEW`: `/openspec-story-review <initiative> <story-slug> [WORKTREE=...]`.
- `Status: 🔵 IN PR` with requested changes: `/openspec-story-resume <initiative> <story-slug> [WORKTREE=...]`.

For each cycle:

1. Re-read `<story_file>` and `<progress_file>` before choosing the next pass.
2. Build the exact slash command line for the chosen claim, resume, or review pass.
3. If the parent session has Research Board entries, include the complete board before the command under this heading:

   ```text
   Shared Research Board from parent orchestration session:
   This is allowed cross-session context because every item is sourced research. Use it for orientation only. The converger owns keeping it relevant; executor subagents only decide whether the needed fact is present. If present, verify behavior with direct reads/search against the cited anchors before editing, planning approval, or implementation approval instead of rerunning expensive research. If a provided entry does not verify, report a board-refresh signal with exact anchors.

   - <entry id>: <claim or result>
     - Source: <tool/query/path, file:line, symbol, or command/output excerpt>
     - Reuse: <orientation guidance>
   ```

   Include the whole board. If it is too large to include comfortably, pause and ask the operator before compacting or excluding entries.
4. If in-memory operational notes exist, include them before the command under this heading only:

   ```text
   Operational context from convergence coordinator:
   - <neutral blocker, hotspot, repeated command failure, or expensive operation>
   - Do not treat this as a verdict; apply the underlying skill independently.
   ```

5. End the task prompt with the exact slash command line, then launch exactly one fresh subagent.
6. Require every subagent final response to include `## Research Events`, with `- None.` allowed. Reused board entries must name the entry and direct-read/search anchors used to verify it. Board-refresh signals must name the board entry or absent needed fact, describe the verification miss, and cite the direct-read/search anchors proving the miss or replacement fact. After the pass finishes, append newly sourced research events and use board-refresh signals to update, replace, retire, or ask about affected board entries. Do not append verdicts, implementation opinions, or unanchored summaries.
7. If the subagent asks an operator question, pause the convergence run, ask the operator, then resume the same subagent for that pass only. The next lifecycle pass still starts in a new fresh subagent.
8. After the pass finishes, re-read `<story_file>`, `<progress_file>`, and `<reviews_file>` (if it exists). Derive decisions from the newest authoritative sections and status, not from chat output alone.
9. If a claim or resume pass leaves the story at `Status: 🟣 IN REVIEW`, the same cycle may launch a fresh review pass.
10. If a review pass returns `approve`, confirm the latest entry in `<reviews_file>` records risk-lens review and finding closure (or explicit `none material`) before stopping successfully. If approval lacks that evidence, launch one fresh review child focused on risk-lens closure instead of accepting chat output alone. Local approval is convergence even when the story remains `Status: 🟣 IN REVIEW` because the optional PR stage is next. Report this as `APPROVED`, not `DONE`, unless the authoritative final status is already `✅ DONE`.
11. If a review pass returns `request_changes` or `not_reviewable`, the same cycle may launch one fresh `/openspec-story-resume` corrective pass, then the next cycle starts with a fresh review when ready. If the finding exposes a new risk lens, ensure the resume child treats that lens as part of the acceptance/proof closure or routes back to planning.
12. If any pass moves the story to `Status: ⛔ BLOCKED`, stop.
13. If any pass moves the story to `Status: ✅ DONE`, stop successfully only after re-checking durable authority in `<reviews_file>` or merged `<progress_file> → ## PR State` as described in the eligibility gate. If DONE lacks that evidence, treat it as status drift, stop, and route to `/openspec-story-review` or `/openspec-story-pr` refresh instead of accepting subagent chat output.
14. If `<blocked_file>` appears in `<change_dir>` at any point during the convergence run, stop immediately.
15. Run the no-progress gate before starting the next cycle.

### Worktree Discovery

When preparing a subagent command line, discover worktrees from `<progress_file> → ## Current Claim → - Worktrees:` (plural form with parent bullet). The legacy singular `- Worktree:` form is accepted by the subagent commands; this converger passes `WORKTREE=` values through unchanged and does not reinterpret them. If no `## Current Claim` exists yet (pre-claim), only explicit `WORKTREE=` arguments from the invocation are passed through.

## Phase 4 — Operational Notes and Stops

Maintain an in-memory convergence notebook and an in-memory Research Board. Do not write either one to `initiative.md`, `story.md`, `progress.md`, `reviews.md`, `blocked.md`, or any coordination file.

Record neutral operational facts only:

- command failures and exact command names;
- test commands that failed because of missing environment or setup;
- worktree or dirty-tree blockers;
- files, symbols, tasks, or acceptance ids repeatedly implicated as hotspots;
- slow commands or broad searches that later fresh agents should not repeat blindly;
- repeated review findings that appear unchanged after resume.

Do not record persuasive verdict framing. Never tell a later reviewer that a previous reviewer was wrong, that approval is expected, or that a finding should be ignored.

Research Board entries are the only allowed cross-subagent context beyond neutral operational notes. Each entry must be sourced by an exact anchor: file path plus line range or symbol, command plus relevant output excerpt, or tool name plus query/action/resource/path/URL and relevant output excerpt for any sourced tool. The board is an orientation aid, not authority. The converger owns keeping it relevant for later passes; executor subagents only decide whether the needed fact is present in the provided board. If present, the executor verifies behavior with direct reads/search against the cited anchors before editing or approving instead of rerunning expensive research. If absent, the executor follows the underlying skill's normal research rules. If a provided entry does not verify, the executor reports a board-refresh signal with exact anchors; the converger decides how to update, replace, retire, or ask about that entry. If the board becomes too large to pass in full, ask the operator before compacting or excluding entries. Never persist the board to disk.

Stop early for conservative no-progress when all are true:

- the latest review requested changes or said not reviewable;
- the subsequent claim/resume pass did not add newer progress, handoff, proof-matrix, test, or source changes addressing the finding;
- the same blocker or finding would be handed to another review unchanged.

Do not use another broad cycle to compensate for an oversized or under-specified story; route newly discovered contract/risk-lens gaps back to planning.

Other hard stops:

- `MAX_CYCLES` reached;
- latest decision is blocked or `Status:` is `⛔ BLOCKED`;
- `blocked.md` appears in `<change_dir>`;
- story enters a status owned by another command, such as `Status: 🔵 IN PR` without requested changes;
- subagent cannot resolve the story, command, or worktree;
- the operator declines an interactive decision required by claim or resume.

## Phase 5 — Commit Recommendation

At the end of the run, inspect `<progress_file> → ## Current Claim` when present:

- For each `- Worktrees:` child bullet (`- <repo-basename>: <absolute path>`), run `git -C <path> status --porcelain` when the path exists.
- For `- Main-tree targets:`, run `git status --porcelain` against the corresponding target repo when it can be resolved from `<workspace_root>/projects/<basename>` or `<workspace_root>`.
- If dirty changes appear to belong to the story, recommend committing them on the feature branch `<initiative>/<story-slug>`.

Do not commit directly. The recommendation is advisory and must be explicit about whether it is a final checkpoint or a WIP checkpoint.

Recommend a final commit when:

- local review approved;
- the next action is `/openspec-story-pr <initiative> <story-slug>`;
- the story reached `Status: ✅ DONE` but worktree changes remain dirty.

Recommend a WIP checkpoint only when stopping at `MAX_CYCLES`, operator input, or no-progress with useful completed changes. Do not recommend a commit when the story blocked before meaningful implementation or no code/test/config changes exist.

When the final authoritative status is `✅ DONE`, do not suggest `/openspec-story-pr` as the next action. `/openspec-story-pr` is the next action only for local approval that leaves the story in `Status: 🟣 IN REVIEW` and the operator wants the optional PR stage.

## Phase 6 — Final Response

Return only the compact report below. Do not include internal deliberation, analysis prose, "Thinking:" blocks, private rationale, or comments about what you are considering before or after the report. Include every section in the template; use `None.` or `unavailable` rather than omitting a section.

```markdown
**Convergence Result**: APPROVED | DONE | BLOCKED | STOPPED | MAX_CYCLES
**Initiative**: <initiative-slug>
**Story**: <story-slug>
**Cycles Used**: <n>/<MAX_CYCLES>
**Final Status**: <status>
**Change Workspace**: openspec/changes/<story-slug>/

## Trace
- Cycle 1: claim/resume/review -> <result>
- Cycle 2: ...

## Research Board Snapshot
- Entries: <n>
- Hotspots: <paths/symbols surfaced by sourced research, or none>
- New this run: <n>
- Reused and directly verified: <summary or none>
- Board-refresh signals: <provided entries not verified, needed facts absent from provided board, or none>
- Persistence: session memory only; no physical cache files written

## Commit Recommendation
- <final commit, WIP checkpoint, or none>
- Suggested command: `git -C <path> status && git -C <path> add -A && git -C <path> commit -m "<initiative>/<story-slug>: <summary>"`

## Operational Notes
- <neutral operational note>
- None.

## Optional Operator Follow-Ups
- <proposed future improvement surfaced by repeated friction, including recurring risk/miss category worth automating or adding to future planning>
- None.

## Next Action
- <single concrete command or decision: `/openspec-story-pr <initiative> <story-slug>` only when result is APPROVED and final status is `🟣 IN REVIEW`; `None. Story is already ✅ DONE.` when result is DONE; otherwise the next operator decision or rerun command>
```

Do not run `/memorize` automatically. If the nice-to-haves are valuable, the operator can decide whether to promote them later.
