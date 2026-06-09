---
name: openspec-story-plan-resume
description: Pick up an OpenSpec change's planning contract — incorporate plan review feedback, complete unfinished spec sections, or both. Leaves implementation status unchanged and the Plan lane ready for review.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug>"
allowed-tools: Read Edit Write Grep Glob Bash(git status:*) Bash(git log:*)
---

# OpenSpec Story Plan Resume

Pick up an OpenSpec change workspace's planning contract — either to incorporate plan review feedback, complete unfinished spec sections, or both. Leaves implementation `Status` unchanged and moves the change's `Plan:` lane toward fresh review.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug>`. Pass both positional arguments; this command has no menu fallback.

## Important

This command may edit the change workspace's spec sections in `story.md`, the `story.md` file's `## Plan Review Log`, `proposal.md`, `design.md`, `tasks.md`, and delta spec files under `specs/`. It never touches:
- Source code, tests, configs
- `story.md` implementation `Status:` header field (the story stays in its current implementation lifecycle state)
- Runtime sections in `progress.md` (`## Current Claim`, `## Progress Timeline`, `## Session Handoff`, `## PR State`, `## Unresolved Debt Friction`)
- Runtime artifact `reviews.md` (implementation review log)
- Runtime artifact `blocked.md` (no write; reads to abort when it exists)
- Completed `Status: ✅ DONE` stories (no in-place contract rework; route new feedback through `/openspec-feedback` as a new candidate, initiative-level decision, defer/reject entry, or an explicit lifecycle reopen decision)
- Any file outside the resolved change workspace at `openspec/changes/<story-slug>/`

## Why explicit selection (never auto-infer)

Plan resume must come from an explicit operator choice. Auto-inferring resumes planning of "whatever was last reviewed" would silently couple planning and review in the same session — exactly the coupling plan review was designed to prevent. The operator always passes both `<initiative-slug>` and `<story-slug>`.

## Resolution

1. Parse `$ARGUMENTS` into `<initiative-slug>` and `<story-slug>` (both positional, in that order).
2. Validate both slugs before resolving paths. Each must match `^[a-z0-9]+(?:-[a-z0-9]+)*$`; if either fails, abort with: `invalid slug; use lowercase hyphenated slug characters only`.
3. Set `<workspace_root>` = `<cwd>`.
4. Resolve `<initiative_dir>` = `<workspace_root>/openspec/initiatives/<initiative-slug>`.
   - If `<initiative_dir>` does not exist, abort with: `initiative not found: openspec/initiatives/<initiative-slug>/ — run /openspec-epic-plan first`.
5. Read `<initiative_dir>/initiative.md` for context.
6. Resolve `<change_dir>` = `<workspace_root>/openspec/changes/<story-slug>/`.
   - If `<change_dir>` does not exist, check `<workspace_root>/openspec/changes/archive/<story-slug>/`.
   - If archived, abort with: `story is archived under openspec/changes/archive/; move it back to openspec/changes/ first`.
   - If missing in both locations, abort with: `change workspace not found: openspec/changes/<story-slug>/ — run /openspec-story-plan first`.
7. Resolve `<story_file>` = `<change_dir>/story.md`.
   - If the file does not exist, abort with the exact missing path.
8. Derive the implementation lifecycle status from the `Status:` header field in `<story_file>`.
   - If it is `✅ DONE`, abort with: "completed stories are not contract-reworked in place; route new feedback through `/openspec-feedback` as a candidate, initiative-level decision, defer/reject entry, or explicit lifecycle reopen decision."
9. Derive the planning lane from the `Plan:` header field in `<story_file>`.
   - If the `Plan:` header field is missing, infer legacy planning state from the latest effective `## Plan Review Log` entry: the last appended review entry after applying any later addressed-entry references. Map `approve` → `🟢 PLAN APPROVED`; unresolved `request_changes` or `not_reviewable` → `🟠 PLAN CHANGES REQUESTED`; `blocked` → `⛔ PLAN BLOCKED`; no entry → `🟡 PLAN DRAFT`. If no `## Plan Review Log` exists, default to `🟡 PLAN DRAFT`.
10. If the planning lane is `🟢 PLAN APPROVED` and every required spec section is structurally complete, abort: "this story's plan is already approved; no plan-resume work is needed."
11. If the planning lane is `⛔ PLAN BLOCKED`, abort: "this story's plan is blocked; the operator must decide how to unblock before plan-resume can continue."
12. If `blocked.md` exists at `<change_dir>/blocked.md`, abort: "blocked.md gate file exists; the operator may edit it to record resolution notes, but must remove it before plan-resume can continue."

## Plan readiness check

Before entering the assessment, abort fast if:

- The `story.md` file contains a `## Session Handoff` equivalent section (in a runtime section it shouldn't contain; the canonical session handoff is in `progress.md`) while the implementation `Status:` header is still `⚪ TODO` — say "this story file appears to contain session handoff state but its status is ⚪ TODO. This suggests implementation work may have been started and interrupted. Fix the implementation status or remove the stale runtime section before plan-resume."
- The change workspace has no scaffold marker from `/openspec-story-plan` — say "this change workspace was not scaffolded by /openspec-story-plan; cannot resume planning. Required artifacts: proposal.md, story.md, design.md, tasks.md."
- The story file has no `## Plan Review Log`, every required spec section exists and is structurally complete (defined below), and the planning lane is `🟢 PLAN APPROVED` — say "this story is fully planned and approved; no plan-resume work is needed."

Runtime sections do not block this command. When runtime artifacts exist (`progress.md`, `reviews.md`), operate in **contract rework mode**: edit only planning spec sections and `## Plan Review Log` in `story.md`, never `progress.md`, `reviews.md`, source, tests, PR tracking, or implementation `Status:`.

A required spec section is structurally complete when:
- `## Purpose` — exists, non-empty, describes an observable user-visible outcome (not vague improvement or activity).
- `## Actors` — legacy absence is not a blocker. If present, uses role bullets with at least one `Primary:` actor and stays consistent with Purpose, Scope, Acceptance, and Verification.
- `## Triggering Need` — exists, non-empty, names a concrete pain or prompt (not tautological).
- `## Expected Prerequisites` — exists, lists deps that resolve to other `openspec/changes/<slug>/` workspaces, or explicitly "none".
- `## Scope` — exists, non-empty, describes atomic work.
- `## Out of Scope` — exists (if missing: warning, not blocker).
- `## Scenarios / Behavior Examples` — legacy absence is not a blocker. If present, every normative `S<n>` scenario maps to exactly one acceptance id with `Covers: A<n>` and every orientation-only scenario says `Orientation only`.
- `## Acceptance` — exists, has at least one `A<n>:` bullet, each bullet is atomic. If a bullet names variants, modes, branches, fallback paths, or failure cases, those variants are either split into separate acceptance ids or clearly treated as separate proof obligations.
- `## Verification` — exists, has `### Verification Commands`, `### Test Architecture Plan`, and `### Acceptance Proof Matrix` subsections; the Test Architecture Plan uses columns `Row ID | Layer / Scope | Behavior / Acceptance Slice | Owning Suite / File(s) | Boundary Exercised | Assertions / Observability | Fixture / Test Data Strategy | CI Lane / Command | Fallback Plan | Split / Merge Rationale`, stable `TAP-*` row ids, covers every added/changed test or proof surface, and satisfies the TAP quality gate; the proof matrix uses columns `Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail`, covers every `A<n>` id and every named variant/failure mode inside an id, and references relevant `TAP-*` rows when tests or proof surfaces change; activated risk lenses are covered by existing matrices or a `### Risk Lens Inventory` with explicit exclusions; when the story references design sources, `### Design Sources` is present, and every normative source has a complete `### Design Element Trace`.

## Read first

1. The project's `AGENTS.md` / `CLAUDE.md`.
2. `<initiative_dir>/initiative.md` — for story candidates, decisions, constraints, and external resources.
3. The resolved `<story_file>` — every section.
4. If present, every entry in `## Plan Review Log`.
5. Dependency change workspaces listed in the story's `## Expected Prerequisites`.
6. `<change_dir>/proposal.md` — for Goal/Context and decisions.
7. `<change_dir>/design.md` — for technical design context.
8. `<change_dir>/tasks.md` — for task structure context.
9. Delta spec files under `<change_dir>/specs/` — for spec-level obligations.

## Source-of-truth hierarchy

1. `AGENTS.md` / `CLAUDE.md` — load-bearing conventions.
2. `<initiative_dir>/initiative.md` — initiative-level decisions and constraints.
3. `<story_file>` — spec sections are the plan; `## Plan Review Log` entries are pending feedback.
4. Dependency change workspaces — for prerequisite context.
5. The live codebase — for probing `## Critical Files` paths and `## Discovery Notes` claims.
6. `proposal.md`, `design.md`, `tasks.md`, `specs/*.md` — supporting planning artifacts.

## Notebook Input

When launched by a converger, you may receive a `Shared notebook context from parent orchestration session` block before the slash command. This is the only allowed cross-session context beyond neutral operational notes. Use it as sourced orientation only. The converger owns keeping notebook entries relevant; you only decide whether the needed fact is present in the provided notebook context. If present, verify it with direct reads/search against the cited anchors before it affects a story edit instead of rerunning expensive research. If a provided notebook entry does not verify, report a notebook-refresh signal with exact anchors; do not decide how to curate the notebook. If absent, follow this skill's normal research rules. Ignore any notebook item that lacks an exact source anchor such as `path:line`, symbol, command/output excerpt, or tool/query/path.

## Assessment

After reading, determine which mode applies:

- **Mode A — Feedback absorption**: Required when any entry in `## Plan Review Log` has verdict `request_changes` or `not_reviewable` AND no subsequent "addressed" entry follows it. Entries may come from `/openspec-story-plan-review` or planning feedback routed by `/openspec-feedback`. Process pending entries in chronological order (oldest first). After Mode A completes, stop. If planning continuation is still needed, the operator re-runs `/openspec-story-plan-resume <initiative-slug> <story-slug>`.
- **Mode B — Planning continuation**: Required when Mode A does not apply (no pending entries) AND one or more required spec sections are missing or structurally incomplete.

If neither mode applies and the `Plan:` header field is `🟢 PLAN APPROVED`, abort with the "fully planned and approved" message from the readiness check. If neither mode applies and the `Plan:` header field is `🟡 PLAN DRAFT` or `🟣 PLAN IN REVIEW`, stop with: "the story contract is structurally complete; run `/openspec-story-plan-review <initiative-slug> <story-slug>` for the next planning step." If neither mode applies and the `Plan:` header field is `🟠 PLAN CHANGES REQUESTED`, stop with the unresolved plan-review finding that still needs an addressed entry, or ask the operator to run `/openspec-story-plan-review <initiative-slug> <story-slug>` if no such finding exists.

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
2. **Map** each finding to the spec section or planning artifact it targets. If the finding does not name a section explicitly, ask the operator which section it relates to. Findings about function signatures, data flow between components, or parameter wiring contracts map to `## Locked Decisions`, not `## Implementation Notes` — propose a `D-XX` entry with the exact signature or contract. Findings about design decisions or architecture map to `design.md`. Findings about spec-level behavior map to `specs/` delta files.
3. **Propose** a concrete edit for each finding.
   - Map the finding to its owning section first. Findings about who is affected map to `## Actors`; concrete flows/examples map to `## Scenarios / Behavior Examples` and then through the funnel into `## Acceptance` and `## Verification` when normative; function signatures, data flow, or parameter-wiring contracts map to `## Locked Decisions`; architecture or design rationale map to `design.md`; spec-level behavior changes map to `specs/`; task decomposition issues map to `tasks.md`.
   - Use the change workspace's existing conventions and phrasing style. Show before/after text for the proposed change.
   - If the edit changes actors, flows, acceptance, verification, TAP, design, input-boundary, fail-open, or risk-lens obligations, update every affected section or artifact in the same proposal instead of hiding contract repair in `## Implementation Notes`.
   - Re-check acceptance atomicity, variant/failure-mode proof coverage, and the `### Test Architecture Plan` whenever test layers, owning files, assertions/observability, fixtures, proof surfaces, fallback plans, split/merge rationale, or CI commands change.
   - Preserve behavior-first proof: internal retry counts, sleeps, helper call order, timing, or implementation choreography are contractual only when the story explicitly locks them.
   - When the edit affects delta specs, ensure `specs/` files are updated to stay consistent with the reviewed change.
4. **Confirm**: "Apply this change? (y/n/edit)". On `y`, apply the edit. On `n`, ask the operator for an alternative. On `edit`, ask the operator to state the replacement and apply it.
5. **Record** after all findings in the entry are addressed. Append a new timestamped bullet under `## Plan Review Log`:

```md
- <UTC ISO timestamp> Plan feedback addressed by `/openspec-story-plan-resume`
  - Original plan review entry: <UTC ISO timestamp of the addressed entry>
  - Sections edited: <list>
  - Plan lane transition: <from> -> 🟡 PLAN DRAFT
  - Changes: <concise summary>
  - Unresolved: <finding reason> — <operator's stated reason>
```

The `Unresolved:` bullet is included only when at least one finding was rejected by the operator with a stated reason. Omit it when all findings were resolved.

6. Repeat for the next pending entry.

After all accepted edits are applied, set the `Plan:` header field in `story.md` to `🟡 PLAN DRAFT`. This records that the contract has been revised and needs a fresh `/openspec-story-plan-review` before implementation should proceed.

### Debt Friction check (Mode A)

After all pending entries have been absorbed, run a Debt Friction check. Evaluate whether meaningfully completing this plan's acceptance or proof is being made harder by unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure — specifically revealed during feedback absorption. Only write a `Debt Friction` entry when there is a story-local causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.
- **No debt friction identified**: skip, record nothing.
- **Clear debt friction found**: auto-record as a new `## Plan Review Log` entry with a `- Debt Friction:` bullet using the `docs/epic-conventions.md` shape. Do not ask for confirmation.
- **Uncertain**: ask the operator whether to record it.

### Log cleanup

After absorption and Debt Friction check, squash stale plan-review history into the current actionable state:

- Scan for stale entries: addressed `request_changes`/`not_reviewable` entries, superseded `approve` entries, and old addressed receipts whose details no longer change the next action.
- If zero or one stale entries exist: skip compression, leave the log as-is.
- If two or more stale entries exist: auto-compress without asking. Read the full `## Plan Review Log` section into memory and replace stale detail with a compact summary that preserves unresolved blockers, operator decisions, the latest disposition/lane transition, Debt Friction, material evidence anchors, and addressed-entry references needed to understand what changed.
- Do not erase unresolved findings or evidence anchors. If full historical detail is required, create or preserve an explicit archive note instead of leaving verbose addressed history in the active log.
- If compression leaves no actionable history, write a single placeholder: `<UTC ISO timestamp> All plan review feedback addressed and log compressed; no unresolved blockers remain.`

### Mode A stop

After cleanup, stop. Re-run `/openspec-story-plan-resume <initiative-slug> <story-slug>` for Mode B (planning continuation) if needed.

## Mode B — Planning continuation

Walk the operator through each incomplete section in order. For each:

- State what is missing or incomplete, referencing the structural-completeness definitions above.
- Propose a draft based on existing content in other spec sections, `## Discovery Notes`, codebase probes, dependency change workspaces, `design.md`, and `proposal.md`. Shape the draft to the initiative's conventions.
- Include a concrete example when helpful.
- Ask: accept the draft, provide an alternative, or skip (only for optional narrative sections; never skip `## Acceptance` or `## Verification`).
- Apply the edit on agreement.
- Re-read the section after editing to confirm correctness.

### Section order

1. **Purpose** — if missing or vague. Interview as question 2 (push for observable user-visible outcome).
2. **Actors** — if present but incomplete, or if this repair changes actor identity, scope, acceptance, or verification and the section is missing. Interview as question 3. Use role bullets with at least one `Primary:` actor.
3. **Triggering Need** — if missing or tautological. Probe `git log` for recent related work. Interview as question 4.
4. **Expected Prerequisites** — if missing or unresolved. Walk `openspec/changes/` for candidate deps. Interview as question 5.
5. **Scope** — if missing or non-atomic. Push back on multi-story scope. Interview as question 6.
6. **Out of Scope** — if missing, propose a best-guess draft from Scope boundaries and confirm.
7. **Scenarios / Behavior Examples** — if present but incomplete, or if this repair changes concrete flows, scope, acceptance, or verification and the section is missing. Interview as question 7. Normative scenarios must use exactly one `Covers: A<n>`; orientation-only scenarios must say `Orientation only`.
8. **Acceptance** — if missing or structurally incomplete. Interview as question 8. Every bullet must be `A<n>:`, atomic, observable. Reject compound bullets. If a bullet names variants, modes, fallback paths, or failure cases, split it or require variant-level proof obligations in Verification. Every normative scenario must map to an acceptance id whose wording covers the scenario's behavior.
9. **Verification** — if missing or structurally incomplete. Interview as question 9. Must produce `### Verification Commands`, `### Test Architecture Plan`, and `### Acceptance Proof Matrix` with full coverage for every acceptance id, every named variant/failure mode inside an id, and every linked scenario case. The Test Architecture Plan must use columns `Row ID | Layer / Scope | Behavior / Acceptance Slice | Owning Suite / File(s) | Boundary Exercised | Assertions / Observability | Fixture / Test Data Strategy | CI Lane / Command | Fallback Plan | Split / Merge Rationale`, stable `TAP-*` row ids, cover every added/changed test or proof surface, and satisfy the TAP quality gate from `docs/epic-conventions.md`; proof matrix rows use columns `Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail` and reference relevant `TAP-*` rows when tests or proof surfaces change. Add `### Surface / Branch Proof Matrix` when multi-surface, `### Design Sources` whenever the story references design sources, `### Design Element Trace` when any design source is normative, `Input Boundary Shape Risk` proof when raw input crosses into stricter assumptions, `### Fail-open Checks` when prompt-driven, and `### Risk Lens Inventory` when activated risks are not already fully covered. Design trace rows use only `required` or bounded `flexible` and must map through Scenario -> Acceptance -> Verification, with rendered-surface proof for visibility, placement, navigation, copy, responsive, and interaction-state obligations unless an explicit exception is recorded. Activated risk lenses include async/event-loop behavior, concurrency, process/resource lifecycle, platform/OS APIs, filesystem/network/subprocess I/O, permissions/security, persistence, retries/timeouts, generated artifacts, external services, and naming-sensitive invariants. When tests must be added or changed, include planned test seams at variant granularity: TAP row id, layer/scope, file path, test function/class name when knowable, boundary exercised, assertion/observable signal, fixture/data strategy, CI command/lane, fallback plan, and split/merge rationale; prefer observable behavior over private mechanics unless the mechanic is explicitly contractual.

For sections 1-7 and 9, consult existing `## Discovery Notes`, `## Critical Files`, `## Implementation Notes`, and `## Locked Decisions` for hints — do not duplicate material across sections.

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

### Design synchronization

If `proposal.md`, `design.md`, or `tasks.md` is stale or inconsistent after Mode B edits:

1. **proposal.md** — if Purpose or Scope changed, update `## Goal / Context` and `## Decisions & Constraints` to stay consistent.
2. **design.md** — if architecture decisions, component boundaries, or data flow changed, update `design.md` to reflect the new picture.
3. **tasks.md** — if acceptance, verification, or implementation notes changed, walk through `tasks.md` and flag tasks that need updating. Propose concrete checkbox edits.
4. **specs/** — if acceptance or verification changed, check whether delta specs need ADDED/MODIFIED/REMOVED updates.
5. Confirm each artifact edit with the operator before applying.

### Debt Friction check (Mode B)

After all sections have been edited, run a separate Debt Friction check. Evaluate whether planning completion is being made harder by debt discovered during continuation planning. Only write when there is a story-local causal link.
- **No debt friction identified**: skip, record nothing.
- **Clear debt friction found**: auto-record as a separate `## Plan Review Log` entry with a `- Debt Friction:` bullet. Do not ask for confirmation.
- **Uncertain**: ask the operator whether to record it.

## Re-validation

After all mode work completes, validate the full story:

1. Every required spec section exists and is structurally complete (as defined in readiness check).
2. If `## Actors` is present, it has role bullets and at least one `Primary:` actor.
3. If `## Scenarios / Behavior Examples` is present, every normative `S<n>` scenario has exactly one `Covers: A<n>` and every orientation-only scenario says `Orientation only`.
4. Every linked scenario is covered by its acceptance id and by that id's proof row(s); drift at either hop is invalid.
5. Every acceptance bullet begins with `A<n>:`, covers exactly one behavior, and has at least one proof matrix row. Any named variants, modes, fallback paths, or failure cases inside the bullet are split into separate acceptance ids or represented as separate proof obligations.
6. Test Architecture Plan has the required columns: `Row ID | Layer / Scope | Behavior / Acceptance Slice | Owning Suite / File(s) | Boundary Exercised | Assertions / Observability | Fixture / Test Data Strategy | CI Lane / Command | Fallback Plan | Split / Merge Rationale`, uses stable `TAP-*` row ids, covers every added/changed test or proof surface, and satisfies the TAP quality gate: cheapest reliable real boundary, exact seam, behavior-facing assertion/observable signal, fixture/data isolation and live-dependency policy, focused command/CI lane, fallback plan, and split/merge rationale.
7. Proof matrix has the required columns: `Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail`, covers every named variant/failure mode or records an explicit exclusion, and references relevant `TAP-*` row ids when tests or proof surfaces change.
8. Every `Proof Maturity` value is `final` or `provisional`. Every `provisional` row has non-blank `Open Detail`.
9. When the story spans multiple surfaces, variants, or orchestration branches: `### Surface / Branch Proof Matrix` is present.
10. When the story references design sources: `### Design Sources` is present with durable anchors and `normative` or `orientation only` status.
11. When any design source is normative: `### Design Element Trace` is present, every visible element/state is mapped as `required` or bounded `flexible`, and every traced row maps through Scenario -> Acceptance -> Verification with rendered-surface proof where required.
12. When raw persisted, external, framework, or generated input crosses stricter application assumptions: `### Input Boundary Shape Risk` is present and covers every in-scope boundary/shape case or records an explicit exclusion/unknown with mitigation.
13. When the feature depends on prompt placeholders or template variables: `### Fail-open Checks` is present.
14. When the story activates material risk lenses not fully covered elsewhere: `### Risk Lens Inventory` is present and lists proof obligations or explicit exclusions.
15. Planned assertions separate caller-observable behavior from implementation mechanics unless the mechanics are explicitly locked as contract.
16. No `<TODO: ...>` placeholders exist in any spec section.
17. Dependency refs in `## Expected Prerequisites` resolve to existing `openspec/changes/<slug>/` workspaces (cross-initiative deps flagged but not failed).
18. Supporting artifacts are consistent: `proposal.md` Goal/Context matches Purpose, `design.md` reflects current architecture decisions, `tasks.md` checklist covers current acceptance and verification, `specs/` delta files match current story scope.

If validation fails, report the specific issue and propose a fix. Keep iterating — the operator decides when to stop. Do not write invalid state.

If validation passes and any spec or proof section changed, set the `Plan:` header field in `story.md` to `🟡 PLAN DRAFT`. Do not mark the plan approved from this command; `/openspec-story-plan-review` owns `🟢 PLAN APPROVED`.

## Status and output

**Status transition**: None. The implementation `Status:` header field in `story.md` stays unchanged. This skill may update only the `Plan:` header field in `story.md`: set it to `🟡 PLAN DRAFT` after edits, or leave it unchanged when no edits were needed.

**Final response**: State:
- which story was resumed (slug and path)
- which modes were entered (feedback absorption, planning continuation, or both)
- sections edited (across all changed artifacts: story.md, proposal.md, design.md, tasks.md, specs/)
- whether re-validation passed
- `## Research Events` with reused notebook entries, notebook-refresh signals, and newly sourced research; for reused entries, name the notebook entry plus the direct-read/search anchors used to verify it; for notebook-refresh signals, name the notebook entry or absent needed fact plus anchors proving the miss or replacement fact; for new research, include exact anchors; use `- None.` when no research was used or produced
- the exact next action: `/openspec-story-plan-review <initiative-slug> <story-slug>` for a fresh contract review; after `Plan:` becomes `🟢 PLAN APPROVED`, use `/openspec-story-claim <initiative-slug> <story-slug>` if implementation `Status:` is `⚪ TODO`, or `/openspec-story-resume <initiative-slug> <story-slug>` if implementation has already started
