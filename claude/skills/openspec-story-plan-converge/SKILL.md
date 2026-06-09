---
name: openspec-story-plan-converge
description: Run fresh plan-review and plan-resume sessions against one OpenSpec change until its Plan lane is approved, blocked, or the loop reaches a hard stop. Use when a story needs repeated independent plan feedback and feedback absorption before implementation or rework continues.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug> [MAX_CYCLES=5]"
allowed-tools: Read Grep Glob Task Bash(git status:*)
---

# OpenSpec Story Plan Converge

Coordinate the planning-side iteration loop for exactly one OpenSpec change workspace, independent of implementation status. This command is an orchestrator only: it starts fresh subagent sessions for `/openspec-story-plan-review` and `/openspec-story-plan-resume`, preserves their ownership boundaries, keeps parent-session notebook context with sourced research plus neutral operational notes, and stops when the Plan lane is approved, blocked, no longer eligible, or out of cycle budget.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug> [MAX_CYCLES=5]`. The initiative slug and story slug are required. `MAX_CYCLES` is optional and defaults to `5`; it counts full review/resume cycles, not individual subagents.

## Workflow
1. Resolve the requested initiative and change workspace through `openspec/initiatives/<slug>/initiative.md` and `openspec/changes/<story-slug>/story.md`.
2. Confirm the story is non-archived and has a planning contract that can be reviewed or resumed.
3. Choose the first planning pass from the story shape: resume first for incomplete specs, otherwise review first.
4. Run up to `MAX_CYCLES` fresh-agent planning cycles.
5. Pass neutral notebook context, including sourced research entries and operational notes, into later fresh agents.
6. Stop on approval, blocker, no-progress, invalid state, or cycle budget exhaustion.
7. Print the convergence trace, notebook snapshot, and optional operator follow-ups without writing coordination files directly.

## Resolution Model

- `<workspace_root>` = `<cwd>`.
- `<initiative_dir>` = `<workspace_root>/openspec/initiatives/<initiative>`.
- `<initiative_file>` = `<initiative_dir>/initiative.md`.
- `<change_dir>` = `<workspace_root>/openspec/changes/<story-slug>`.
- `<story_file>` = `<change_dir>/story.md`.
- The `Plan:` header field in `<story_file>` is the authoritative planning lane.
- The `## Plan Review Log` section in `<story_file>` is the authoritative review history.

There is no `MASTER.md`, no tracker table, no step/number row, and no implementation Status column in this flow. The change workspace is self-contained under `openspec/changes/<story-slug>/`.

## Phase 1 — Parse and Resolve

1. Parse `$ARGUMENTS`:
   - `<initiative>`: required first positional token.
   - `<story-slug>`: required second positional token.
   - `MAX_CYCLES=<n>`: optional positive integer; default `5`.
2. Reject unknown flags. This command does not accept `WORKTREE=` because planning may read source code for evidence but never writes source code.
3. Validate `<initiative>` and `<story-slug>` before resolving paths. Each must match `^[a-z0-9]+(?:-[a-z0-9]+)*$`; if either fails, abort with: `invalid slug; use lowercase hyphenated slug characters only`.
4. Resolve `<initiative_file>` = `<workspace_root>/openspec/initiatives/<initiative>/initiative.md`.
   - If missing, abort with: `initiative not found — run /openspec-epic-plan first`.
5. Resolve `<change_dir>` = `<workspace_root>/openspec/changes/<story-slug>/`.
   - If missing, check `<workspace_root>/openspec/changes/archive/<story-slug>/`.
   - If archived, abort with: `story is archived; move it back to openspec/changes/ first`.
   - If missing in both, abort with: `change workspace not found — run /openspec-story-plan first`.
6. Read `<story_file>` and confirm the `Plan:` header field and `## Plan Review Log` section are present (they may be empty or default-valued).
   - If `story.md` is missing or unreadable, abort with: `story.md is missing from change workspace`.

## Phase 2 — Eligibility Gate

Before starting the loop, abort with a clear next action if any condition is true:

- The implementation `Status:` header field in `story.md` is `✅ DONE`: completed stories are not contract-reviewed or contract-reworked in place. Route new feedback through `/openspec-feedback` as a candidate, initiative-level decision, defer/reject entry, or explicit lifecycle reopen decision.
- The `Plan:` header field is `🟢 PLAN APPROVED` and there are no unresolved `## Plan Review Log` findings **and** the `## Plan Review Log` contains at least one entry with `Verdict: approve` (or a legacy equivalent) from an independent `/openspec-story-plan-review` pass: stop successfully; planning is already complete.
- The `Plan:` header field is `🟢 PLAN APPROVED` but `## Plan Review Log` is empty or lacks an approve entry: treat as orphaned approval. Set `Plan:` to `🟠 PLAN CHANGES REQUESTED` and route through the normal review cycle.
- The `Plan:` header field is `⛔ PLAN BLOCKED`: stop with blocked status. The operator must resolve the blocker before convergence can proceed.
- A `blocked.md` file exists at `<change_dir>/blocked.md`: stop immediately. Convergence is refused while an explicit gate file exists. The operator may edit it to record resolution notes, but must remove `blocked.md` to unblock.
- The story is missing the `/openspec-story-plan` scaffold shape expected by `/openspec-story-plan-review` (no `proposal.md`, no `story.md` with required spec sections, or no `design.md` / `tasks.md`).
- The story is so malformed that `/openspec-story-plan-resume` cannot identify spec sections to continue.

The planning-lane authority is the `Plan:` header field in `story.md`. No other source is consulted for the plan state.

## Phase 3 — Fresh-Agent Loop

Run at most `MAX_CYCLES` cycles. A planning cycle is one opportunity to get the plan approved; depending on current story shape it may include one fresh `/openspec-story-plan-resume` pass and one fresh `/openspec-story-plan-review` pass.

For each cycle:

1. Re-read `<initiative_file>` and `<story_file>` before choosing the next pass.
2. Before any fresh subagent launch in this phase, build the task prompt in this order: notebook context when present, operational context when present, then the exact slash command as the final line.
3. If a newer unaddressed plan-review finding exists (a `request_changes` or `not_reviewable` entry in `## Plan Review Log` without a matching addressed entry), prepare and launch a fresh subagent whose task prompt ends with:

   ```text
   /openspec-story-plan-resume <initiative> <story-slug>
   ```

   The resume child routes to Mode A (unresolved-review-entry absorption) automatically. If this resume pass asks an operator question, pause the convergence run, ask the operator, then resume the same subagent for that pass only.
4. Else if required spec sections are missing or structurally incomplete and there is no newer unaddressed plan-review finding, prepare and launch a fresh resume subagent the same way (Mode B — missing-section completion).
5. When no unaddressed findings remain and the story is ready for review, prepare and launch a fresh subagent whose task prompt ends with the exact slash command:

   ```text
   /openspec-story-plan-review <initiative> <story-slug>
   ```

5. If notebook context is available, include the complete inline notebook snapshot before the command under this heading:

   ```text
   Shared notebook context from parent orchestration session:
   This is allowed cross-session context because every item is sourced research or neutral operational context. Use it for orientation only. The converger owns keeping notebook entries relevant; executor subagents only decide whether the needed fact is present. If present, verify behavior with direct reads/search against the cited anchors before editing, planning approval, or implementation approval instead of rerunning expensive research. If a provided entry does not verify, report a notebook-refresh signal with exact anchors.

   - <entry id>: <claim, result, or neutral operational note>
     - Source: <tool/query/path, file:line, symbol, or command/output excerpt>
     - Reuse: <orientation guidance>
   ```

   Include the whole relevant notebook context. If it is too large to include comfortably, pause and ask the operator before compacting or excluding entries.
6. If in-memory operational notes exist for any subagent launch, include them before the command under this heading only:

   ```text
   Operational context from convergence coordinator:
   - <neutral blocker, hotspot, repeated command failure, or expensive operation>
   - Do not treat this as a verdict; apply the underlying skill independently.
   ```

7. Require every subagent final response to include `## Research Events`, with `- None.` allowed. Reused notebook entries must name the entry and direct-read/search anchors used to verify it. Notebook-refresh signals must name the notebook entry or absent needed fact, describe the verification miss, and cite the direct-read/search anchors proving the miss or replacement fact. After the pass finishes, append newly sourced research events and use notebook-refresh signals to update, replace, retire, or ask about affected notebook entries. Do not append verdicts, implementation opinions, or unanchored summaries.
8. After the review agent finishes, re-read `<story_file>`. Derive the review decision from the newest `## Plan Review Log` entry and current `Plan:` header field, not from chat output alone.
9. If the decision is `approve` or `Plan:` is `🟢 PLAN APPROVED`, confirm the latest story `## Plan Review Log` records activated risk lenses or explicit `none material` before stopping. If approval lacks that evidence, launch one fresh plan-review child focused on risk-lens coverage rather than accepting chat output alone. Then stop successfully. Do not claim or resume the story. Recommend `/openspec-story-claim <initiative> <story-slug>` or `/openspec-story-resume <initiative> <story-slug>` to begin implementation.
10. If the decision is `blocked` or `Plan:` is `⛔ PLAN BLOCKED`, stop with blocked planning status.
11. If the decision is `request_changes` or `not_reviewable`, prepare and launch a different fresh subagent whose task prompt ends with:

    ```text
    /openspec-story-plan-resume <initiative> <story-slug>
    ```

12. If the resume agent asks an operator question, pause the convergence run, ask the operator, then resume the same subagent for that resume pass only. The next review still starts in a new fresh subagent.
13. After the resume agent finishes, re-read `<story_file>`. Confirm the `Plan:` header field has not been set to an unexpected value by the resume subagent.
14. Run the no-progress gate before starting the next cycle.

## Phase 4 — Operational Notes and Stops

Maintain a convergence notebook containing neutral operational notes and sourced research entries. Do not write notebook content to `story.md`, `initiative.md`, `progress.md`, or any coordination file as a duplicate source of lifecycle, proof, or review authority.

Record neutral operational facts only:

- command failures and their exact command names;
- missing environment or worktree prerequisites;
- story sections or proof rows that repeatedly block progress;
- files or concepts that multiple agents identify as hotspots;
- time-consuming operations that later fresh agents should avoid repeating blindly.

Do not record persuasive verdict framing. Never tell a later reviewer that a previous reviewer was wrong, that approval is expected, or that a finding should be ignored.

Sourced notebook entries are the allowed cross-subagent research context. Each entry must be sourced by an exact anchor: file path plus line range or symbol, command plus relevant output excerpt, or tool name plus query/action/resource/path/URL and relevant output excerpt for any sourced tool. Notebook entries are an orientation aid, not authority. The converger owns keeping them relevant for later passes; executor subagents only decide whether the needed fact is present in the provided notebook context. If present, the executor verifies behavior with direct reads/search against the cited anchors before editing or approving instead of rerunning expensive research. If absent, the executor follows the underlying skill's normal research rules. If a provided entry does not verify, the executor reports a notebook-refresh signal with exact anchors; the converger decides how to update, replace, retire, or ask about that entry. If the notebook context becomes too large to pass in full, ask the operator before compacting or excluding entries.

Stop early for conservative no-progress when all are true:

- the latest review requested changes or said not reviewable;
- the subsequent resume pass did not add a newer addressed-feedback entry or materially edit the targeted spec sections;
- the same blocker or finding would be handed to another review unchanged.

Do not use repeated cycles to paper over an under-specified or over-large story; newly discovered risk-lens or proof-contract gaps must be edited into the story contract or explicitly excluded.

Other hard stops:

- `MAX_CYCLES` reached;
- latest decision is `blocked`;
- `blocked.md` appears in `<change_dir>` during the convergence run;
- subagent cannot resolve the story or command;
- the operator declines an interactive decision required by resume.

## Phase 5 — Final Response

Return only the compact report below. Do not include internal deliberation, analysis prose, "Thinking:" blocks, private rationale, or comments about what you are considering before or after the report. Include every section in the template; use `None.` or `unavailable` rather than omitting a section.

```markdown
**Convergence Result**: APPROVED | BLOCKED | STOPPED | MAX_CYCLES
**Initiative**: <initiative-slug>
**Story**: <story-slug>
**Cycles Used**: <n>/<MAX_CYCLES>
**Final Plan Lane**: <plan>
**Change Workspace**: openspec/changes/<story-slug>/

## Trace
- Cycle 1: plan-review -> <decision>; plan-resume -> <completed/skipped>
- Cycle 2: ...

## Notebook Snapshot
- Entries: <n>
- Hotspots: <paths/symbols surfaced by sourced research, or none>
- New this run: <n>
- Reused and directly verified: <summary or none>
- Notebook-refresh signals: <provided entries not verified, needed facts absent from provided notebook context, or none>
- Persistence: <parent-session notebook context, runtime-specific notebook pages, or none>; no coordination-file cache written

## Operational Notes
- <neutral operational note>
- None.

## Optional Operator Follow-Ups
- <proposed future improvement surfaced by repeated friction, including recurring risk/miss category worth automating or adding to future planning>
- None.

## Next Action
- <single concrete command or decision>
```

Do not run `/memorize` automatically. If the nice-to-haves are valuable, the operator can decide whether to promote them later.
