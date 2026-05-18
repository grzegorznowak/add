---
name: epic-story-plan-resume
description: Pick up a story's planning contract — incorporate plan review feedback, complete unfinished spec sections, or both. Leaves implementation status unchanged and the Plan lane ready for review.
disable-model-invocation: true
argument-hint: "<epic-name> <story-number-or-spec-file>"
allowed-tools: Read Edit Write Grep Glob Bash
---

# Epic Story Plan Resume

Pick up a story's planning contract — either to incorporate plan review feedback, complete unfinished spec sections, or both. Leaves implementation `Status` unchanged and moves the story's `Plan` lane toward fresh review.

Argument: `$ARGUMENTS` — `<epic_name> <story_number_or_spec_file>`. Both required.

## Important

This command may edit the story file's spec sections, the story file's `## Plan Review Log`, and the matched `MASTER.md` row's `Plan` lane when that column exists. It never touches:
- Source code, tests, configs
- `MASTER.md` implementation `Status` (the story stays in its current implementation lifecycle state)
- Runtime sections (`## Active Claim`, `## Progress Log`, `## Session Handoff`, `## Review Log`, `## PR Tracking`)
- Any file outside the resolved story in `<epic>/`, except `<epic>/MASTER.md` for the `Plan` lane write-back only

## Why explicit selection (never auto-infer)

Plan resume must come from an explicit operator choice. Auto-inferring resumes planning of "whatever was last reviewed" would silently couple planning and review in the same session — exactly the coupling plan review was designed to prevent. The operator always passes both `<epic>` and `<story>`.

## Resolution

1. Parse `$ARGUMENTS` into `<epic>` and `<story>` (both positional, in that order).
2. Resolve `<epic>` = `<cwd>/agent_coordination/epics/<epic>`.
3. If `<epic>` does not exist, abort with the exact missing path.
4. Read `<epic>/MASTER.md`.
5. Match `<story>` against `MASTER.md`:
   - First try exact match on `Step` value.
   - If no match, try exact match on `Spec` value.
   - If neither matches, abort listing available `Step` and `Spec` values.
   - If both match different rows, abort with ambiguity.
6. Resolve the story file as `<epic>/<matched Spec value>`.
7. If the file does not exist, abort with the exact missing path.
8. Resolve the planning lane from the matched `MASTER.md` row. If a `Plan` column exists, use it as authoritative. If no `Plan` column exists, infer legacy planning state from the newest effective `## Plan Review Log` entry: `approve` -> `🟢 PLAN APPROVED`; unresolved `request_changes` or `not_reviewable` -> `🟠 PLAN CHANGES REQUESTED`; `blocked` -> `⛔ PLAN BLOCKED`; no entry -> `🟡 PLAN DRAFT`.
9. If the planning lane is `🟢 PLAN APPROVED` and every required spec section is structurally complete, abort: "this story's plan is already approved; no plan-resume work is needed."
10. If the planning lane is `⛔ PLAN BLOCKED`, abort: "this story's plan is blocked; the operator must decide how to unblock before plan-resume can continue."

## Plan readiness check

Before entering the assessment, abort fast if:

- The story file contains a `## Session Handoff` section while the implementation `Status` is still `⚪ TODO` — say "this story file has a `## Session Handoff` section but its status is `⚪ TODO`. This suggests implementation work may have been started and interrupted. Fix the implementation status or remove the stale runtime section before plan-resume."
- The story file has no scaffold marker from `/epic-story-plan` — say "story was not scaffolded by `/epic-story-plan`; cannot resume planning".
- The story file has no `## Plan Review Log`, every required spec section exists and is structurally complete (defined below), and the planning lane is `🟢 PLAN APPROVED` — say "this story is fully planned and approved; no plan-resume work is needed."

Runtime sections do not block this command. When runtime sections exist, operate in **contract rework mode**: edit only planning spec sections and `## Plan Review Log`, never implementation diary sections, source, tests, PR tracking, or implementation `Status`.

A required spec section is structurally complete when:
- `## Purpose` — exists, non-empty, describes an observable user-visible outcome (not vague improvement or activity).
- `## Triggering Need` — exists, non-empty, names a concrete pain or prompt (not tautological).
- `## Expected Prerequisites` — exists, lists deps that resolve to `MASTER.md` rows, or explicitly "none".
- `## Scope` — exists, non-empty, describes atomic work.
- `## Out of Scope` — exists (if missing: warning, not blocker).
- `## Acceptance` — exists, has at least one `A<n>:` bullet, each bullet is atomic. If a bullet names variants, modes, branches, fallback paths, or failure cases, those variants are either split into separate acceptance ids or clearly treated as separate proof obligations.
- `## Verification` — exists, has both `### Verification Commands` and `### Acceptance Proof Matrix` subsections; the matrix covers every `A<n>` id and every named variant/failure mode inside an id.

## Read first

1. The project's `AGENTS.md` / `CLAUDE.md`.
2. `<epic>/MASTER.md`.
3. The resolved story file — every section.
4. If present, every entry in `## Plan Review Log`.
5. Dependency story files listed in `MASTER.md` and in the story's `## Expected Prerequisites`.

## Source-of-truth hierarchy

1. `AGENTS.md` / `CLAUDE.md` — load-bearing conventions.
2. `<epic>/MASTER.md` — tracker state.
3. The story file — spec sections are the plan; review log entries are pending feedback.
4. Dependency story files — for prerequisite context.
5. The live codebase — for probing `## Critical Files` paths and `## Discovery Notes` claims.

## Shared Research Board Input

When launched by a converger, you may receive `Shared Research Board from parent orchestration session` before the slash command. This is the only allowed cross-session context beyond neutral operational notes. Use it as sourced orientation only; every board fact must still be verified against live source before it affects a story edit. Ignore any board item that lacks an exact source anchor such as `path:line`, symbol, command/output excerpt, or tool/query/path.

## Assessment

After reading, determine which mode applies:

- **Mode A — Feedback absorption**: Required when any entry in `## Plan Review Log` has verdict `request_changes` or `not_reviewable` AND no subsequent "addressed" entry follows it. Entries may come from `/epic-story-plan-review` or planning feedback routed by `/epic-feedback`. Process pending entries in chronological order (oldest first). After Mode A completes, stop. If planning continuation is still needed, the operator re-runs `/epic-story-plan-resume`.
- **Mode B — Planning continuation**: Required when Mode A does not apply (no pending entries) AND one or more required spec sections are missing or structurally incomplete.

If neither mode applies and the `Plan` lane is `🟢 PLAN APPROVED`, abort with the "fully planned and approved" message from the readiness check. If neither mode applies and the `Plan` lane is `🟡 PLAN DRAFT` or `🟣 PLAN IN REVIEW`, stop with: "the story contract is structurally complete; run `/epic-story-plan-review <epic> <story>` for the next planning step." If neither mode applies and the `Plan` lane is `🟠 PLAN CHANGES REQUESTED`, stop with the unresolved plan-review finding that still needs an addressed entry, or ask the operator to run `/epic-story-plan-review <epic> <story>` if no such finding exists.

## Mode A — Feedback absorption

### Entry classification

Scan every entry in `## Plan Review Log`. Classify each as:

- **blocked** — verdict is `blocked`. Abort immediately: "This story is blocked by the following findings from plan review: <findings>. The operator must decide how to unblock before plan-resume can continue."
- **pending** — verdict is `request_changes` or `not_reviewable`, and no subsequent entry of type "addressed" with a matching `Original plan review entry` timestamp exists. Absorption work is needed.
- **stale** — verdict is `request_changes`, `not_reviewable`, or `approve`, and either:
  - an "addressed" entry already references it (for `request_changes`/`not_reviewable`), OR
  - it is an `approve` entry (no absorption was ever needed, but it's resolved history).

If all entries are stale, show: "All plan review entries have already been addressed. Proceed to log cleanup (step below) or Mode B."

### Absorption (pending entries only)

For every chronologically-ordered pending entry:

1. **Present** the entry's verdict and full key findings to the operator. Show the exact text as it appears in the log, including the `Sections reviewed` list.
2. **Map** each finding to the spec section it targets. If the finding does not name a section explicitly, ask the operator which section it relates to. Findings about function signatures, data flow between components, or parameter wiring contracts map to `## Locked Decisions`, not `## Implementation Notes` — propose a `D-XX` entry with the exact signature or contract.
3. **Propose** a concrete edit to address each finding. Use the story's existing conventions and phrasing style. Show a before/after of the proposed change. For acceptance or verification changes, re-check atomicity and proof coverage. If an acceptance item names variants, modes, fallback paths, or failure cases, ensure each named case has its own proof row or explicit exclusion. If the finding introduces or changes surfaces, orchestration branches, raw input shape assumptions, or fail-open prompt/template risks, update the corresponding `### Surface / Branch Proof Matrix`, `### Input Boundary Shape Risk`, or `### Fail-open Checks` section in the same pass.
4. **Confirm**: "Apply this change? (y/n/edit)". On `y`, apply the edit. On `n`, ask the operator for an alternative. On `edit`, ask the operator to state the replacement and apply it.
5. **Record** after all findings in the entry are addressed. Append a new timestamped bullet under `## Plan Review Log`:

```md
- <UTC ISO timestamp> Plan feedback addressed by `/epic-story-plan-resume`
  - Original plan review entry: <UTC ISO timestamp of the addressed entry>
  - Sections edited: <list>
  - Plan lane transition: <from> -> 🟡 PLAN DRAFT
  - Changes: <concise summary>
  - Unresolved: <finding reason> — <operator's stated reason>
```

The `Unresolved:` bullet is included only when at least one finding was rejected by the operator with a stated reason. Omit it when all findings were resolved.

6. Repeat for the next pending entry.

After all accepted edits are applied, set the `Plan` lane to `🟡 PLAN DRAFT` when the column exists. This records that the contract has been revised and needs a fresh `/epic-story-plan-review` before implementation should proceed.

### Debt Friction check (Mode A)

After all pending entries have been absorbed, run a Debt Friction check. Evaluate whether meaningfully completing this plan's acceptance or proof is being made harder by unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure — specifically revealed during feedback absorption. Only write a `Debt Friction` entry when there is a story-local causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.
- **No debt friction identified**: skip, record nothing.
- **Clear debt friction found**: auto-record as a new `## Plan Review Log` entry with a `- Debt Friction:` bullet using the `docs/epic-conventions.md` shape. Do not ask for confirmation.
- **Uncertain**: ask the operator whether to record it.

### Log cleanup

After absorption and Debt Friction check, auto-compress the log:

- Scan for stale entries (both stale `request_changes`/`not_reviewable` entries with addressed follow-ups, and `approve` entries). Count them.
- If zero or one stale entries exist: skip compression, leave the log as-is.
- If two or more stale entries exist: auto-compress without asking. Read the full `## Plan Review Log` section into memory, remove each stale entry (the original `request_changes`/`not_reviewable`/`approve` entry) while keeping the "addressed" entries that reference them. Preserve chronological order of remaining entries. Atomically replace the entire `## Plan Review Log` section with the compressed version. If this leaves the section empty, write a single placeholder: `<UTC ISO timestamp> All plan review feedback addressed and log compressed.`

### Mode A stop

After cleanup, stop. Re-run `/epic-story-plan-resume <epic> <story>` for Mode B (planning continuation) if needed.

## Mode B — Planning continuation

Walk the operator through each incomplete section in order. For each:

- State what is missing or incomplete, referencing the structural-completeness definitions above.
- Propose a draft based on existing content in other spec sections, `## Discovery Notes`, codebase probes, and dependency story files. Shape the draft to the epic's conventions.
- Include a concrete example when helpful.
- Ask: accept the draft, provide an alternative, or skip (only for optional narrative sections; never skip `## Acceptance` or `## Verification`).
- Apply the edit on agreement.
- Re-read the section after editing to confirm correctness.

### Section order

1. **Purpose** — if missing or vague. Interview as question 2 (push for observable user-visible outcome).
2. **Triggering Need** — if missing or tautological. Probe `git log` for recent related work. Interview as question 3.
3. **Expected Prerequisites** — if missing or unresolved. Walk `MASTER.md` for candidate deps. Interview as question 4.
4. **Scope** — if missing or non-atomic. Push back on multi-story scope. Interview as question 5.
5. **Out of Scope** — if missing, propose a best-guess draft from Scope boundaries and confirm.
6. **Acceptance** — if missing or structurally incomplete. Interview as question 6. Every bullet must be `A<n>:`, atomic, observable. Reject compound bullets. If a bullet names variants, modes, fallback paths, or failure cases, split it or require variant-level proof obligations in Verification.
7. **Verification** — if missing or structurally incomplete. Interview as question 7. Must produce `### Verification Commands` and `### Acceptance Proof Matrix` with full coverage for every acceptance id and every named variant/failure mode inside an id. Add `### Surface / Branch Proof Matrix` when multi-surface, `Input Boundary Shape Risk` proof when raw input crosses into stricter assumptions, and `### Fail-open Checks` when prompt-driven. When tests must be added or changed, include planned test seams at variant granularity: file path, test function/class name when knowable, and the expected failing assertion or RED signal.

For sections 1-5 and 7, consult existing `## Discovery Notes`, `## Critical Files`, `## Implementation Notes`, and `## Locked Decisions` for hints — do not duplicate material across sections.

### Critical Files probing

If `## Critical Files` is missing or stale:
1. Extract 3-5 domain keywords from Purpose and Scope.
2. Search the codebase for those keywords.
3. Propose candidate files with paths and roles.
4. Let the operator confirm, correct, or add. Mark files to be created as `(new)`.

### Discovery Notes probing

If `## Discovery Notes` is missing:
1. Search the codebase for 2-3 domain terms from Purpose and Scope.
2. Cross-reference against material in other spec sections.
3. Propose reusable code, gotchas, or hidden coupling found.
4. If nothing material found: write `None identified.`

### Implementation Notes probing

If `## Implementation Notes` is missing:
1. Propose a minimal execution brief: source-inspection focus, smallest likely red-first seam, phases if relevant, known constraints.
2. Let the operator confirm or correct.

If you discover a function signature change or parameter wiring contract while writing Implementation Notes, promote it to a Locked Decision (`D-XX`) with the exact signature. Do not leave interface contracts only in Implementation Notes, where the implementer treats them as advisory.

### Locked Decisions probing

If `## Locked Decisions` is missing:
1. Cross-check decisions mentioned across other sections against `AGENTS.md`.
2. Ask: "any decisions made that should be locked? any alternatives considered and rejected?"
3. Also ask about implementation-interface decisions: which existing functions are getting new parameters, how those parameters reach the function (passed explicitly vs. read from enclosing data structures), which callee parameters are intentionally not wired and why, and what output/report schemas the implementation must produce. Any contract that would cause the implementer to guess should be a `D-XX` entry.
4. If none: write `None identified.`

### Debt Friction check (Mode B)

After all sections have been edited, run a separate Debt Friction check. Evaluate whether planning completion is being made harder by debt discovered during continuation planning. Only write when there is a story-local causal link.
- **No debt friction identified**: skip, record nothing.
- **Clear debt friction found**: auto-record as a separate `## Plan Review Log` entry with a `- Debt Friction:` bullet. Do not ask for confirmation.
- **Uncertain**: ask the operator whether to record it.

## Re-validation

After all mode work completes, validate the full story:

1. Every required spec section exists and is structurally complete (as defined in readiness check).
2. Every acceptance bullet begins with `A<n>:`, covers exactly one behavior, and has at least one proof matrix row. Any named variants, modes, fallback paths, or failure cases inside the bullet are split into separate acceptance ids or represented as separate proof obligations.
3. Proof matrix has the required columns: `Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail`, and covers every named variant/failure mode or records an explicit exclusion.
4. Every `Proof Maturity` value is `final` or `provisional`. Every `provisional` row has non-blank `Open Detail`.
5. When the story spans multiple surfaces, variants, or orchestration branches: `### Surface / Branch Proof Matrix` is present.
6. When raw persisted, external, framework, or generated input crosses stricter application assumptions: `### Input Boundary Shape Risk` is present and covers every in-scope boundary/shape case or records an explicit exclusion/unknown with mitigation.
7. When the feature depends on prompt placeholders or template variables: `### Fail-open Checks` is present.
8. No `<TODO: ...>` placeholders exist in any spec section.
9. Dependency refs in `## Expected Prerequisites` resolve to `MASTER.md` rows (cross-epic deps flagged but not failed).

If validation fails, report the specific issue and propose a fix. Keep iterating — the operator decides when to stop. Do not write invalid state.

If validation passes and any spec or proof section changed, set the `Plan` lane to `🟡 PLAN DRAFT` when the column exists. Do not mark the plan approved from this command; `/epic-story-plan-review` owns `🟢 PLAN APPROVED`.

## Status and output

**Status transition**: None. The implementation `Status` stays unchanged in both `MASTER.md` and its `Status:` header. This skill may update only the `Plan` lane: set it to `🟡 PLAN DRAFT` after edits, or leave it unchanged when no edits were needed.

**Final response**: State:
- which story was resumed (number and spec file)
- which modes were entered (feedback absorption, planning continuation, or both)
- sections edited
- whether re-validation passed
- `## Research Events` with reused, added, corrected, and stale-risk bullets; include exact anchors for added, corrected, and stale-risk entries, and use `- None.` when no research was used or produced
- the exact next action: `/epic-story-plan-review <epic> <NN>` for a fresh contract review; after `Plan` becomes `🟢 PLAN APPROVED`, use `/epic-story-claim <epic> <NN>` if implementation `Status` is `⚪ TODO`, or `/epic-story-resume <epic> <NN>` if implementation has already started
