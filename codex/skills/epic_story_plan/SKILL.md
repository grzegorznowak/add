---
name: epic_story_plan
description: Interview-driven creation of a new TODO story for an existing epic — writes story-NN-<slug>.md and appends the MASTER.md tracker row after proof-contract validation.
---

# Epic Story Plan: $EPIC

Create a new story for an existing epic by interviewing the operator through the story spec sections, validating the proof contract, and publishing the story directly into `agent_coordination/epics/<epic>/`. This command writes the official story file and appends the `⚪ TODO` tracker row to `MASTER.md`; it does not create a separate draft plan file.

Treat `$EPIC` as optional. If present, resolve that epic directly. If absent, list the available epics under `<cwd>/agent_coordination/epics/` and ask the operator to pick one.

## Important

This command may write exactly two tracked coordination surfaces, after an explicit checkpoint confirmation:

- `<epic>/story-<NN>-<slug>.md`
- `<epic>/MASTER.md`

It never touches product source code, tests, configs, `CONTRACT.md`, archived stories, or runtime sections such as `## Active Claim`, `## Progress Log`, `## Session Handoff`, `## Review Log`, `## Plan Review Log`, or `## PR Tracking`.

## Why operator-explicit selection

`$epic_story_plan` does not auto-infer which epic a new story should live under. The operator explicitly chooses — either by passing `EPIC=<slug>` or by picking from the menu this skill shows when the arg is absent. The menu is not inference: it lists every legal epic and asks the operator to select.

Creating a story mutates `MASTER.md`, so the epic choice must never be guessed. A wrong guess silently creates coordination state in the wrong epic.

## Resolution

1. Parse `$EPIC` — if present, use it; otherwise fall through to the menu.
2. If `$EPIC` was provided:
   - Resolve the epic directory as `<cwd>/agent_coordination/epics/<epic>/`.
   - Verify `<epic>/MASTER.md` exists.
   - If missing, abort with: `epic dir not found at <path>; run $epic_plan NAME="<epic>" first to bootstrap it`.
3. If `$EPIC` was not provided:
   - List every directory under `<cwd>/agent_coordination/epics/` that contains a `MASTER.md`.
   - For each, show one line: `<slug> — <N stories, M done, last-touched YYYY-MM-DD>`.
   - If the list is empty, abort with: `no epics found under <cwd>/agent_coordination/epics/; run $epic_plan first to bootstrap one`.
   - Ask the operator: `Pick an epic for this story (number or slug):`.
   - Read their choice and set `$EPIC` accordingly. Loop until the input resolves to a valid epic.

## Read first

Once the epic is resolved, read the following before the interview starts:

1. The project's `AGENTS.md` first, then `CLAUDE.md` as a fallback. If neither exists, note it: `no AGENTS.md / CLAUDE.md found; recommendations will be generic`.
2. `<epic>/MASTER.md` — the tracker, so the interview can surface existing stories as prerequisite candidates and compute the next story number.
3. The most recent existing story file in the epic (highest `Step` number; prefer non-archived). Read it to learn the epic's conventions and tone.
4. `<epic>/CONTRACT.md` if present — anything locked in by the squash step overrides contradictory planning assumptions.

## Source-of-truth hierarchy

1. The project's `AGENTS.md` / `CLAUDE.md` — load-bearing project conventions.
2. `<epic>/CONTRACT.md` — epic-level locked facts, if present.
3. `<epic>/MASTER.md` — tracker state, prerequisite resolution, numbering.
4. The conversation with the operator — their stated intent for this specific story.
5. The live codebase — feasibility, collision detection, and locating Critical Files.

Do not infer identity from filename shape or naming conventions that are not explicitly recorded in `MASTER.md` or the project's conventions file.

## Lean story rule

Each material fact should have one canonical home:

- `## Acceptance` owns required behavior.
- `## Verification` owns proof actions, proof status, and reviewer evidence.
- `## Scope` owns boundaries, not implementation steps.
- `## Critical Files` owns paths and each path's role.
- `## Implementation Notes` owns the execution brief: source-inspection focus, red-first seam guidance, phases, constraints, and known exceptions.
- `## Locked Decisions` owns decisions and rejected alternatives.
- `## Discovery Notes` owns source-derived facts that prevent rediscovery.

Do not repeat the same fact across sections. Later sections should reference acceptance IDs, proof rows, decision labels, files, or section names instead of restating full prose.

## Interview loop

Walk the operator through each question below in order. For every question:

- Propose a recommended answer with a brief plain-language explanation of the trade-off.
- Include a concrete example, short snippet, or small ASCII diagram when it clarifies the choice.
- Probe the codebase before asking if the answer can be derived from it.
- Every question offers two escape hatches except for `Acceptance` and `Verification`:
  - `skip` — perform a bounded scan from the known Purpose/Scope terms, then either use a terse inferred answer or omit the optional section. If skipping would weaken Acceptance, Verification, Critical Files, or Debt Friction, do deeper inference before moving on.
  - `draft now` — stop asking and jump to story drafting. Never draft while `Acceptance` or `Verification` is incomplete.
- `## Acceptance` and `## Verification` are load-bearing contract sections. Keep interviewing until they are structurally complete.

### Question 1 — Story slug and one-line title

Ask for the story's short hyphenated slug, for example `refresh-token-issuance`, and a one-line human title.

Probe `MASTER.md` for the highest existing and archived story number and report the next number that would be assigned if the story is published now. Do not write anything yet; final numbering is confirmed at checkpoint.

### Question 2 — Purpose

Ask: "what user-visible outcome does this story deliver?" Push back on vague phrasing. "Improve X", "refactor Y", and "clean up Z" describe activity, not outcome.

Propose a one-paragraph draft back to the operator and iterate until the answer names a concrete observable.

### Question 3 — Triggering Need

Ask: "why now? what prompted this story?" If the answer is thin, probe `git log` for the last ~50 commits and look for related work, bug fixes, or incident-like commit messages. Offer concrete triggers you found and let the operator confirm or correct.

### Question 4 — Expected Prerequisites

Walk the `MASTER.md` tracker. For each existing row, ask yourself whether this story could legitimately depend on it. Propose candidate prerequisites based on fuzzy keyword matches between the Purpose terms and tracker row titles.

Format: `DEPENDS = 03, 05 (if either: explain why you think so)`. The operator confirms or corrects. If a prerequisite is not yet `✅ DONE`, flag it but do not reject it; TODO stories can legitimately depend on TODO stories.

### Question 5 — Scope and Out of Scope

Ask what is in scope for this story — the work the implementer will actually do. Drive toward atomic scope. If the answer reads like multiple independent stories, push back with a split proposal.

Also ask what is deliberately out of scope. A non-empty Out of Scope section is a signal of clear thinking; a missing one is a warning.

### Question 6 — Acceptance criteria

Ask: "how will a reviewer know this story is done?" Every acceptance bullet must be checkable by a command, file read, or direct observation. Every bullet must start with a stable id (`A1`, `A2`, ...) and cover exactly one independently provable behavior.

Reject vague or compound criteria such as:

- "works correctly"
- "is performant"
- "is clean"
- "tests pass"
- bullets whose parts could fail independently

Propose observable rewrites and iterate until every bullet names a concrete check, uses an `A<n>` id, and stays atomic.

### Question 7 — Verification contract

Build `## Verification` around two required parts and any conditional proof sections the story needs:

1. `### Verification Commands`
   - Ask for exact commands or exact manual/file-read actions a reviewer can run.
   - Confirm existing test files or named surfaces actually exist when claimed as current seams.
   - Anchor the real owning test/proof surfaces and the focused area the implementer should inspect first.
2. `### Acceptance Proof Matrix`
   - Every acceptance id must have at least one row before the story can be created.
   - Required columns: `Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail`
   - `Proof Maturity` must be `final` or `provisional`.
   - `Open Detail` may be blank for `final` rows and is required for `provisional` rows.
   - A row may cover multiple acceptance ids only when the same proof action and failure signal genuinely cover all of them.
   - Proof rows should reference acceptance IDs and expected evidence without restating the full acceptance text.
3. `### Surface / Branch Proof Matrix` when the story spans multiple user-visible surfaces, supported variants/profiles/modes, or internal orchestration branches.
   - Required columns: `Surface | Supported Variant | Internal Execution Branch | Proof Class | Owning Proof Seam | Why This Seam Is Sufficient | Out of Scope Notes`
   - Every in-scope surface / variant / branch combination must appear.
   - `Proof Class` must be one of `helper`, `routing`, or `behavior`.
   - Helper proof alone is insufficient when multiple supported callsites or orchestration paths exist; require at least one routing proof.
4. `Input Boundary Shape Risk` proof when raw persisted, external, framework, or generated input crosses into stricter application assumptions such as parsing, validation, classification, normalization, migration, aggregation, routing, import/export, or schema construction.
   - Keep approval evidence in the `Acceptance Proof Matrix` and make it start at the named raw input boundary.
   - Add a `### Input Boundary Shape Risk` mini-matrix only when multiple boundaries, variants, or mitigations would be hard to audit from acceptance rows alone.
   - Required mini-matrix columns: `Boundary | Raw Input Source | Strict Assumption | Variant / Case | Evidence | Mitigation / Exclusion`.
   - Every in-scope boundary and shape case must appear once, or be explicitly excluded with a reason.
   - `unknown` evidence is allowed only with a recorded reason, mitigation, and follow-up path; unknown evidence without mitigation is not approval-ready.
5. `### Fail-open Checks` when the feature depends on prompt placeholders, template variables, string substitution, or other fail-open prompt assembly.
   - Require a negative proof that supported renders leave no unresolved placeholders or raw feature tokens.
   - Require a proof that enabled supported paths activate the feature.
   - Require at least one disabled/default path proof showing baseline behavior is unchanged.

Do not accept vague proof like "run the relevant tests" or fake seams that only validate heavily mocked helpers. Provisional rows are allowed, but every acceptance id still needs a row and every provisional row must state what remains undecided. For input-boundary shape risks, helper-level proof with already-normalized intermediate data is insufficient unless the story explicitly narrows the proof row and records why that is safe.

Debt Friction check: actively ask whether proof planning is being made harder by unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure. Only record a `Debt Friction` entry when there is a story-local causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.

### Question 8 — Critical Files

Actively probe the codebase:

1. Extract 3-5 domain keywords from Purpose and Scope.
2. Search for those keywords across the project.
3. Propose candidate files with line refs and a short role, for example `src/auth/session.ts:142 — session refresh owner`.
4. Let the operator confirm, correct, or add.

Do not ask the operator to list Critical Files from memory. Critical Files should be a terse path-and-role list, not a second implementation plan. For files that need to be created, mark them explicitly: `src/auth/refresh.ts (new, does not yet exist)`.

### Question 9 — Implementation Notes

Ask for only the execution context that changes implementation:

- source-inspection focus
- smallest likely red-first seam or seam family
- phases if sequencing matters
- known constraints or live/manual exceptions
- required written exception if red-first may be infeasible

Move decisions and rejected alternatives to `## Locked Decisions`; do not duplicate them here.

### Question 10 — Locked Decisions

Ask: "what has been decided, and what alternatives were considered and rejected?" Cross-check each decision against `AGENTS.md` / `CLAUDE.md`. If a decision contradicts a stated convention, flag it and ask whether the operator wants to revise the decision or handle the convention change separately.

### Question 11 — Discovery Notes

Discovery Notes are not a transcript. Record only source-derived facts that would otherwise need rediscovery: reusable code, gotchas, hidden coupling, test seams, operational constraints, or Debt Friction. Prefer short bullets with path/symbol provenance.

If no material source-derived facts are found and sibling-story convention requires a `## Discovery Notes` section, write `None identified.`

## Story draft

Assemble the story file with this header:

```md
# Story <NN> — <TITLE>

Status: `todo`

> Story scaffolded directly by `/epic-story-plan` after interactive planning.
```

Then add the spec sections. Required sections:

- `## Purpose`
- `## Triggering Need`
- `## Expected Prerequisites`
- `## Scope`
- `## Out of Scope`
- `## Acceptance`
- `## Verification`

Optional narrative sections:

- `## Discovery Notes`
- `## Critical Files`
- `## Implementation Notes`
- `## Locked Decisions`

Include optional narrative sections when they have material content or when sibling-story convention includes them. If sibling convention forces an optional section with no material content, write `None identified.`

Do not create `<TODO: ...>` placeholders in any section. If `## Acceptance` or `## Verification` is incomplete, keep interviewing instead of drafting.

## Validation and numbering

Before the checkpoint:

1. Determine `next_n` = max(active tracker numbers, archived story numbers) + 1.
2. Resolve filename: `story-<NN>-<slug>.md`, zero-padded to match the epic's existing convention; default to two digits.
3. If the filename already exists in the epic root or `archive/`, abort with the conflict path.
4. Validate dependencies:
   - Same-epic refs must exist in `MASTER.md`; abort if missing.
   - Same-epic refs not yet `✅ DONE` produce a soft warning.
   - Cross-epic refs pass through and are flagged as unverified.
5. Validate the proof contract:
   - every acceptance bullet begins with `A<n>:`
   - `## Verification` contains `### Verification Commands` and `### Acceptance Proof Matrix`
   - the proof matrix uses the required columns
   - every acceptance id appears in at least one proof row
   - every `Proof Maturity` value is `final` or `provisional`
   - every `provisional` row has non-blank `Open Detail`
   - required surface/branch and fail-open sections are present when the story risk surface calls for them
   - no `<TODO: ...>` placeholders exist in `## Acceptance` or `## Verification`

Abort or continue the interview if validation fails. Do not write malformed story state.

## Checkpoint

Show the operator:

- Resolved story number and filename, including numbering basis.
- Dependency validation report.
- Section list, including which optional narrative sections were included, omitted, or forced by sibling convention.
- Acceptance/proof validation summary.
- Surface/branch and fail-open coverage summaries when present.
- The full drafted story file content.
- The exact `MASTER.md` row to append.

**CHECKPOINT**: explicit y/n before writing. If the operator rejects, return to the interview loop at the question they want to revisit. If they accept, continue to write.

## Write

1. Write the new story file at `<epic>/story-<NN>-<slug>.md`.
2. Edit `MASTER.md` to append a new tracker row:

   ```md
   | <NN> | 🟡 PLAN DRAFT | ⚪ TODO | <TITLE> | <DEPENDS or "none"> | `story-<NN>-<slug>.md` |
   ```

3. Match the existing tracker table column count and ordering. Read the header row to determine whether the epic uses 3, 4, 5, or 6 columns. When the header has a `Plan` column, write `🟡 PLAN DRAFT` and keep implementation `Status` at `⚪ TODO`.
4. Escape markdown table delimiters in the title before writing the row.
5. Never seed runtime sections.

## Final response

State clearly:

- filename created
- story number assigned
- dependency report
- optional section summary
- suggested next action: `epic_story_plan_review $EPIC <NN>` from a fresh session

Keep it short — three or four sentences is enough.
