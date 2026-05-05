---
name: epic_story_plan_resume
description: Pick up a ⚪ TODO story and continue its planning phase — incorporate plan review feedback, complete unfinished spec sections, or both. Leaves the story at ⚪ TODO ready for /epic-story-claim.
---

# Epic Story Plan Resume: $EPIC $STORY

Pick up a `⚪ TODO` story and continue its planning phase — either to incorporate plan review feedback, complete unfinished spec sections, or both. Leaves the story at `⚪ TODO` ready for `/epic-story-claim`.

Arguments: `$EPIC` (epic slug, required) and `$STORY` (story number or spec filename, required).

## Important

This command may edit the story file's spec sections and `## Plan Review Log`. It never touches:
- Source code, tests, configs
- `MASTER.md` tracker status (the story stays at `⚪ TODO`)
- Runtime sections (`## Active Claim`, `## Progress Log`, `## Session Handoff`, `## Review Log`, `## PR Tracking`)
- Any file outside the resolved story in `<epic>/`

## Why explicit selection (never auto-infer)

Plan resume must come from an explicit operator choice. Auto-inferring resumes planning of "whatever was last reviewed" would silently couple planning and review in the same session — exactly the coupling plan review was designed to prevent. The operator always passes both `$EPIC` and `$STORY`.

## Resolution

1. Treat `$EPIC` as the epic slug and `$STORY` as the story selector.
2. Resolve `<epic>` = `<cwd>/agent_coordination/epics/$EPIC`.
3. If `<epic>` does not exist, abort with the exact missing path.
4. Read `<epic>/MASTER.md`.
5. Match `$STORY` against `MASTER.md`:
   - First try exact match on `Step` value.
   - If no match, try exact match on `Spec` value.
   - If neither matches, abort listing available `Step` and `Spec` values.
   - If both match different rows, abort with ambiguity.
6. Resolve the story file as `<epic>/<matched Spec value>`.
7. If the file does not exist, abort with the exact missing path.
8. If the story's status in `MASTER.md` (or its `Status:` header) is NOT `⚪ TODO`, abort: "this story is past the planning phase; use `/epic-story-resume` or `/epic-story-review` instead".

## Plan readiness check

Before entering the assessment, abort fast if:

- The story file contains a `## Session Handoff` section — say "this story file has a `## Session Handoff` section but its status is `⚪ TODO`. This suggests implementation work may have been started and interrupted. If the story was previously claimed, use `/epic-story-resume` instead. To proceed with plan-resume, manually remove the `## Session Handoff` section first."
- The story file has runtime sections (`## Active Claim`, `## Progress Log`, etc.) — say "this story has moved past planning; use `/epic-story-resume` instead".
- The story file has no scaffold marker from `/epic-story-plan` — say "story was not scaffolded by `/epic-story-plan`; cannot resume planning".
- The story file has no `## Plan Review Log` AND every required spec section exists and is structurally complete (defined below) — say "this story is fully planned and approved; no plan-resume work is needed. Run `/epic-story-claim $EPIC <story>` to start implementation."

A required spec section is structurally complete when:
- `## Purpose` — exists, non-empty, describes an observable user-visible outcome (not vague improvement or activity).
- `## Triggering Need` — exists, non-empty, names a concrete pain or prompt (not tautological).
- `## Expected Prerequisites` — exists, lists deps that resolve to `MASTER.md` rows, or explicitly "none".
- `## Scope` — exists, non-empty, describes atomic work.
- `## Out of Scope` — exists (if missing: warning, not blocker).
- `## Acceptance` — exists, has at least one `A<n>:` bullet, each bullet is atomic.
- `## Verification` — exists, has both `### Verification Commands` and `### Acceptance Proof Matrix` subsections; the matrix covers every `A<n>` id.

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

## Assessment

After reading, determine which mode applies:

- **Mode A — Feedback absorption**: Required when any entry in `## Plan Review Log` has verdict `request_changes` or `not_reviewable` AND no subsequent "addressed" entry follows it. Process pending entries in chronological order (oldest first). After Mode A completes, stop. If planning continuation is still needed, the operator re-runs `/epic-story-plan-resume`.
- **Mode B — Planning continuation**: Required when Mode A does not apply (no pending entries) AND one or more required spec sections are missing or structurally incomplete.

If neither mode applies, abort with the "fully planned and approved" message from the readiness check.

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
2. **Map** each finding to the spec section it targets. If the finding does not name a section explicitly, ask the operator which section it relates to.
3. **Propose** a concrete edit to address each finding. Use the story's existing conventions and phrasing style. Show a before/after of the proposed change. For acceptance or verification changes, re-check atomicity and proof coverage.
4. **Confirm**: "Apply this change? (y/n/edit)". On `y`, apply the edit. On `n`, ask the operator for an alternative. On `edit`, ask the operator to state the replacement and apply it.
5. **Record** after all findings in the entry are addressed. Append a new timestamped bullet under `## Plan Review Log`:

```md
- <UTC ISO timestamp> Plan feedback addressed by `/epic-story-plan-resume`
  - Original plan review entry: <UTC ISO timestamp of the addressed entry>
  - Sections edited: <list>
  - Changes: <concise summary>
  - Unresolved: <finding reason> — <operator's stated reason>
```

The `Unresolved:` bullet is included only when at least one finding was rejected by the operator with a stated reason. Omit it when all findings were resolved.

6. Repeat for the next pending entry.

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

After cleanup, stop. Re-run `/epic-story-plan-resume $EPIC <story>` for Mode B (planning continuation) if needed.

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
6. **Acceptance** — if missing or structurally incomplete. Interview as question 6. Every bullet must be `A<n>:`, atomic, observable. Reject compound bullets.
7. **Verification** — if missing or structurally incomplete. Interview as question 7. Must produce `### Verification Commands` and `### Acceptance Proof Matrix` with full coverage. Add `### Surface / Branch Proof Matrix` when multi-surface, and `### Fail-open Checks` when prompt-driven.

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

### Locked Decisions probing

If `## Locked Decisions` is missing:
1. Cross-check decisions mentioned across other sections against `AGENTS.md`.
2. Ask: "any decisions made that should be locked? any alternatives considered and rejected?"
3. If none: write `None identified.`

### Debt Friction check (Mode B)

After all sections have been edited, run a separate Debt Friction check. Evaluate whether planning completion is being made harder by debt discovered during continuation planning. Only write when there is a story-local causal link.
- **No debt friction identified**: skip, record nothing.
- **Clear debt friction found**: auto-record as a separate `## Plan Review Log` entry with a `- Debt Friction:` bullet. Do not ask for confirmation.
- **Uncertain**: ask the operator whether to record it.

## Re-validation

After all mode work completes, validate the full story:

1. Every required spec section exists and is structurally complete (as defined in readiness check).
2. Every acceptance bullet begins with `A<n>:`, covers exactly one behavior, and has at least one proof matrix row.
3. Proof matrix has the required columns: `Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail`.
4. Every `Proof Maturity` value is `final` or `provisional`. Every `provisional` row has non-blank `Open Detail`.
5. When the story spans multiple surfaces, variants, or orchestration branches: `### Surface / Branch Proof Matrix` is present.
6. When the feature depends on prompt placeholders or template variables: `### Fail-open Checks` is present.
7. No `<TODO: ...>` placeholders exist in any spec section.
8. Dependency refs in `## Expected Prerequisites` resolve to `MASTER.md` rows (cross-epic deps flagged but not failed).

If validation fails, report the specific issue and propose a fix. Keep iterating — the operator decides when to stop. Do not write invalid state.

## Status and output

**Status transition**: None. The story stays at `⚪ TODO` in both `MASTER.md` and its `Status:` header. This skill never transitions a story beyond `⚪ TODO`.

**Final response**: State:
- which story was resumed (number and spec file)
- which modes were entered (feedback absorption, planning continuation, or both)
- sections edited
- whether re-validation passed
- the exact next action: `/epic-story-plan-review $EPIC <NN>` for a fresh review, or `/epic-story-claim $EPIC <NN>` to start implementation
