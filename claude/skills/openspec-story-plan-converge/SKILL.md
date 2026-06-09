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
5. Pass compact notebook references for sourced research, plus neutral operational notes, into later fresh agents.
6. Stop on approval, blocker, no-progress, invalid state, or cycle budget exhaustion.
7. Print the convergence trace, notebook context summary, and optional operator follow-ups without writing coordination files directly.

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

6. If notebook-backed context is available, do not inline entire notebook pages or broad notebook dumps. Pass only compact notebook references, selectors, and the reason/scope for consulting them before the command under this heading:

   ```text
   Notebook references from parent orchestration session:
   This is allowed cross-session orientation because every reference points to sourced research or neutral operational context. Use it for orientation only. The converger owns keeping notebook references relevant; executor subagents only decide whether the needed fact is reachable from the referenced selector or compact fallback excerpt. When runtime notebook tools are available, read only the referenced page/entry on demand and verify behavior with direct reads/search against the cited anchors before editing, planning approval, or implementation approval instead of rerunning expensive research. When notebook tools are unavailable, use only compact curated excerpts supplied here. If a referenced entry or excerpt does not verify, mention the mismatch with exact anchors in the relevant final-response section.

   - Ref: <notebook page name, entry id, or narrow selector>
     - Purpose: <why this may matter for the pass>
     - Expected anchors: <tool/query/path, file:line, symbol, or command/output excerpt>
     - Lookup: <specific page/entry to read or narrow search to run>
     - Fallback excerpt: <optional compact sourced excerpt only when notebook tools are unavailable>
   ```

   If the useful context cannot be represented as narrow references plus optional compact excerpts, pause and ask the operator before omitting or summarizing it.
7. If in-memory operational notes exist for any subagent launch, include them before the command under this heading only:

   ```text
   Operational context from convergence coordinator:
   - <neutral blocker, hotspot, repeated command failure, or expensive operation>
   - Do not treat this as a verdict; apply the underlying skill independently.
   ```

8. Require subagents to write new sourced research directly to the named planning research notebook page when runtime notebook tools are available. If notebook tools are unavailable, allow compact sourced fallback notes in normal final reporting instead. Require subagents to mention any referenced notebook entry or fallback excerpt that failed verification with exact anchors in their relevant blocker, finding, or notes section. After the pass finishes, inspect the named planning research notebook page or child-reported entries as needed, then use mismatch notes to update, replace, retire, or ask about affected entries. Do not append verdicts, implementation opinions, or unanchored summaries.
9. After the review agent finishes, treat its final response as the provisional decision. Before routing, perform a minimal authority spot-check against `<story_file>`: for example, use `rg -n '^(Plan:|## Plan Review Log|### |Verdict:)' <story_file>` to fetch the `Plan:` header, log anchors, and verdict markers, then use a bounded read only for the newest log entry body if needed. If the spot-check agrees with the agent's report, continue from those decision-bearing fields. If the anchors are missing, stale, ambiguous, or conflicting, broaden to a targeted story read or launch a focused repair/review pass.
10. If the decision is `approve` or `Plan:` is `🟢 PLAN APPROVED`, confirm the latest story `## Plan Review Log` records activated risk lenses or explicit `none material` with the same minimal spot-check/bounded-read approach before stopping. If approval lacks that evidence, launch one fresh plan-review child focused on risk-lens coverage rather than accepting chat output alone. Then stop successfully. Do not claim or resume the story. Recommend `/openspec-story-claim <initiative> <story-slug>` or `/openspec-story-resume <initiative> <story-slug>` to begin implementation.
11. If the decision is `blocked` or `Plan:` is `⛔ PLAN BLOCKED`, stop with blocked planning status.
12. If the decision is `request_changes` or `not_reviewable`, prepare and launch a different fresh subagent whose task prompt ends with:

    ```text
    /openspec-story-plan-resume <initiative> <story-slug>
    ```

13. If the resume agent asks an operator question, pause the convergence run, ask the operator, then resume the same subagent for that resume pass only. The next review still starts in a new fresh subagent.
14. After the resume agent finishes, trust its report provisionally and run a minimal `Plan:` header spot-check, for example `rg -n '^Plan:' <story_file>`. Broaden to a targeted story read only if the header is missing, unexpected, ambiguous, or conflicts with the agent's report.
15. Run the no-progress gate before starting the next cycle.

## Phase 4 — Operational Notes and Stops

Maintain a convergence notebook containing neutral operational notes and sourced research entries. Do not write notebook content to `story.md`, `initiative.md`, `progress.md`, or any coordination file as a duplicate source of lifecycle, proof, or review authority.

Record neutral operational facts only:

- command failures and their exact command names;
- missing environment or worktree prerequisites;
- story sections or proof rows that repeatedly block progress;
- files or concepts that multiple agents identify as hotspots;
- time-consuming operations that later fresh agents should avoid repeating blindly.

Do not record persuasive verdict framing. Never tell a later reviewer that a previous reviewer was wrong, that approval is expected, or that a finding should be ignored.

Sourced notebook references and compact fallback excerpts are the allowed cross-subagent research orientation. Each referenced entry or excerpt must be sourced by an exact anchor: file path plus line range or symbol, command plus relevant output excerpt, or tool name plus query/action/resource/path/URL and relevant output excerpt for any sourced tool. Notebook entries are an orientation aid, not authority. The converger owns keeping references relevant for later passes; executor subagents only decide whether the needed fact is reachable from the referenced selector or compact excerpt. If present, the executor reads only the relevant notebook page/entry on demand when available and verifies behavior with direct reads/search against the cited anchors before editing or approving instead of rerunning expensive research. If absent, the executor follows the underlying skill's normal research rules. If a referenced entry or fallback excerpt does not verify, the executor mentions the mismatch with exact anchors in the relevant final-response section; the converger decides how to update, replace, retire, or ask about that reference. Do not pass broad notebook dumps; if needed context cannot be represented by narrow selectors and compact excerpts, ask the operator before omitting or summarizing it.

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

## Notebook Context
- References passed: <n>
- Hotspots: <paths/symbols surfaced by sourced research, or none>
- Research notebook updates: <entries added/updated/retired this run, or none>
- Referenced entries verified: <summary or none>
- Stale reference handling: <referenced entries/excerpts not verified, needed facts absent from referenced notebook selectors, or none>
- Persistence: <notebook page references, compact excerpt fallback, runtime-specific notebook pages, or none>; no coordination-file cache written

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
