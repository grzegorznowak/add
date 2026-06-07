---
name: epic-story-plan
description: Interview-driven creation of a new story for an existing epic — writes story-NN-<slug>.md and appends the MASTER.md tracker row with a draft planning lane after proof-contract validation.
disable-model-invocation: true
argument-hint: '[EPIC="<epic_name>"]'
allowed-tools: Read Grep Glob Write Edit Bash(git status:*) Bash(git log:*)
---

# Epic Story Plan

Create a new story for an existing epic by interviewing the operator through the story spec sections, validating the proof contract, and publishing the story directly into `agent_coordination/epics/<epic>/`. This command writes the official story file and appends a tracker row with `Plan` = `🟡 PLAN DRAFT` and `Status` = `⚪ TODO`; it does not create a separate draft plan file.

Argument: `$ARGUMENTS` — optional `[EPIC="<epic_name>"]`. If provided, the skill resolves that epic directly. If omitted, the skill lists the available epics under `<cwd>/agent_coordination/epics/` and asks the operator to pick one.

## Important

This command may write exactly two tracked coordination surfaces, after an explicit checkpoint confirmation:

- `<epic>/story-<NN>-<slug>.md`
- `<epic>/MASTER.md`

It never touches product source code, tests, configs, `CONTRACT.md`, archived stories, or runtime sections such as `## Active Claim`, `## Progress Log`, `## Session Handoff`, `## Review Log`, `## Plan Review Log`, or `## PR Tracking`.

## Why operator-explicit selection

`/epic-story-plan` does not auto-infer which epic a new story should live under. The operator explicitly chooses — either by passing `EPIC=<slug>` as an argument or by picking from the menu this skill shows when the arg is absent. The menu is not inference: it lists every legal epic and asks the operator to select.

Creating a story mutates `MASTER.md`, so the epic choice must never be guessed. A wrong guess silently creates coordination state in the wrong epic.

## Resolution

1. Parse `$ARGUMENTS` — extract `EPIC` if present.
2. If `EPIC` was provided:
   - Resolve the epic directory as `<cwd>/agent_coordination/epics/<epic>/`.
   - Verify `<epic>/MASTER.md` exists.
   - If missing, abort with: `epic dir not found at <path>; run /epic-plan NAME="<epic>" first to bootstrap it`.
3. If `EPIC` was not provided:
   - List every directory under `<cwd>/agent_coordination/epics/` that contains a `MASTER.md`.
   - For each, show one line: `<slug> — <N stories, M done, last-touched YYYY-MM-DD>`.
   - If the list is empty, abort with: `no epics found under <cwd>/agent_coordination/epics/; run /epic-plan first to bootstrap one`.
   - Ask the operator: `Pick an epic for this story (number or slug):`.
   - Read their choice and set `EPIC` accordingly. Loop until the input resolves to a valid epic.

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
- `## Verification` owns proof actions, proof status, reviewer evidence, and risk-lens obligations.
- `## Actors` owns role-based participants and responsibility context.
- `## Scenarios / Behavior Examples` owns concrete examples that funnel into acceptance: `Scenario -> Acceptance -> Verification`.
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
- Every question offers two escape hatches except for load-bearing contract sections (`Actors`, `Scenarios / Behavior Examples`, `Acceptance`, and `Verification`):
  - `skip` — for optional sections only, perform a bounded scan from the known Purpose/Scope terms, then either use a terse inferred answer or omit the section. If skipping would weaken Critical Files or Debt Friction, do deeper inference before moving on.
  - `draft now` — stop asking optional questions and jump to story drafting only after all load-bearing contract sections are structurally complete.
- `## Actors`, `## Scenarios / Behavior Examples`, `## Acceptance`, and `## Verification` are load-bearing for new drafts. Keep interviewing, probing, or proposing inferred text until they are structurally complete; do not bypass them with an escape hatch.

### Question 1 — Story slug and one-line title

Ask for the story's short hyphenated slug, for example `refresh-token-issuance`, and a one-line human title.

Probe `MASTER.md` for the highest existing and archived story number and report the next number that would be assigned if the story is published now. Do not write anything yet; final numbering is confirmed at checkpoint.

### Question 2 — Purpose

Ask: "what user-visible outcome does this story deliver?" Push back on vague phrasing. "Improve X", "refactor Y", and "clean up Z" describe activity, not outcome.

Propose a one-paragraph draft back to the operator and iterate until the answer names a concrete observable.

### Question 3 — Actors

Ask: "who initiates, participates in, reviews, or is affected by this story?" Use role bullets, not personas. Require at least one `Primary:` actor. Add `Secondary:`, `Reviewer:`, `System:`, or external-service roles only when they clarify behavior or review responsibility.

Example:

```md
## Actors
- Primary: epic operator
- Secondary: implementation agent
- Reviewer: plan-review agent
- System: story planning workflow
```

### Question 4 — Triggering Need

Ask: "why now? what prompted this story?" If the answer is thin, probe `git log` for the last ~50 commits and look for related work, bug fixes, or incident-like commit messages. Offer concrete triggers you found and let the operator confirm or correct.

### Question 5 — Expected Prerequisites

Walk the `MASTER.md` tracker. For each existing row, ask yourself whether this story could legitimately depend on it. Propose candidate prerequisites based on fuzzy keyword matches between the Purpose terms and tracker row titles.

Format: `DEPENDS = 03, 05 (if either: explain why you think so)`. The operator confirms or corrects. If a prerequisite is not yet `✅ DONE`, flag it but do not reject it; TODO stories can legitimately depend on TODO stories.

### Question 6 — Scope and Out of Scope

Ask what is in scope for this story — the work the implementer will actually do. Drive toward atomic scope. If the answer reads like multiple independent stories, push back with a split proposal.

Also ask what is deliberately out of scope. A non-empty Out of Scope section is a signal of clear thinking; a missing one is a warning.

### Question 7 — Scenarios / Behavior Examples

Ask for concrete examples that should shape acceptance. Use lightweight `S<n>` bullets. Prefer Given/When/Then phrasing when behavior is procedural.

Also ask whether any scenario or expectation comes from a mockup, wireframe, screenshot, Figma frame, presentation blueprint, prior `/grillme` discussion, or other design source. Capture the source anchor for Question 9 and ask whether each source is `normative` or `orientation only`; the operator controls which sources/elements enter the normative story contract by classifying sources, superseding or re-scoping them, or marking them orientation-only. Once a source is normative, every visible element/state must be traced.

Scenarios are a funnel into acceptance, not a parallel requirements list:

```text
Scenario -> Acceptance -> Verification
```

- Normative scenarios must end with exactly one `Covers: A<n>` once the acceptance ids exist. If acceptance ids are not finalized yet, draft the expected mapping and reconcile it during Question 8.
- Orientation-only scenarios must explicitly say `Orientation only` and must not create implementation or proof obligations unless the same behavior is also present in Acceptance.
- If a scenario describes required behavior, make sure Question 8 creates or updates an acceptance id for it.

Example:

```md
## Scenarios / Behavior Examples
- S1: Given a legacy story has no `## Actors`, when plan-review runs, then absence alone is not a blocker. Covers: A2.
- S2: Background: older approved stories may predate this template. Orientation only.
```

### Question 8 — Acceptance criteria

Ask: "how will a reviewer know this story is done?" Every acceptance bullet must be checkable by a command, file read, or direct observation. Every bullet must start with a stable id (`A1`, `A2`, ...) and cover exactly one independently provable behavior.

Reject vague or compound criteria such as:

- "works correctly"
- "is performant"
- "is clean"
- "tests pass"
- "matches the mockup" or "follows the design" without enumerated visible obligations
- bullets whose parts could fail independently

For UI/design-heavy stories, convert accepted visible elements, copy, placement, navigation, responsive behavior, and interaction states into atomic acceptance criteria. Orientation-only design sources create no acceptance obligation unless the behavior is repeated here.

If an acceptance bullet names variants, modes, branches, fallback paths, error cases, or examples such as "missing, empty, malformed, or failed", treat those as separate proof obligations. Prefer splitting them into separate `A<n>` bullets when each variant can fail independently. If keeping them under one acceptance id is genuinely clearer, require the `## Verification` proof matrix to list each named variant explicitly; a single proof row or test does not cover the parent acceptance id unless it covers every named variant or records an explicit exclusion with rationale.

Propose observable rewrites and iterate until every bullet names a concrete check, uses an `A<n>` id, and stays atomic.

Reconcile `## Scenarios / Behavior Examples` before leaving this question: every normative `S<n>` scenario must map to exactly one acceptance id with `Covers: A<n>`, and that linked acceptance item must include the scenario's concrete behavior. If one example appears to span multiple acceptance ids, split it into multiple scenarios or reshape the acceptance items. If a scenario is useful context but not required behavior, label it `Orientation only` instead of forcing acceptance coverage.

### Question 9 — Verification contract

Build `## Verification` as a reviewer-runnable proof contract, not a vague test note. It must contain three required subsections and any conditional proof sections the story's surfaces require:

1. `### Verification Commands`
   - Ask for exact commands or exact manual/file-read actions a reviewer can run.
   - Group commands by lanes the repository actually supports: focused unit/domain, functional/component/API, integration/routing/filesystem/network, contract, acceptance/E2E/manual/golden, static/packaging, broad regression, or the repo's own names. Do not invent CI lanes; mark unknown lanes provisional and state what source inspection must confirm.
   - When tests must be added or changed, name the planned file and test function/class when knowable, plus the expected failing assertion, RED signal, or reviewer-visible output. If the exact name is unknowable before source inspection, mark it provisional and state the naming decision to resolve.
2. `### Test Architecture Plan`
   - Required columns: `Row ID | Layer / Scope | Behavior / Acceptance Slice | Owning Suite / File(s) | Boundary Exercised | Assertions / Observability | Fixture / Test Data Strategy | CI Lane / Command | Fallback Plan | Split / Merge Rationale`.
   - Discover and follow the repository's existing test layout, markers, fixtures, and CI lanes before using fallback layers such as `unit/domain`, `functional/component/API`, `integration/routing/filesystem/network`, `contract`, `acceptance/E2E/manual/golden`, or `static/packaging`.
   - Apply the TAP quality gate from `docs/epic-conventions.md`: stable `TAP-*` row ids; cheapest reliable real boundary; exact seam; behavior-facing assertion or reviewer-visible signal in `Assertions / Observability`; fixture/data isolation and live-dependency policy; focused command/CI lane; fallback plan when the preferred seam/layer/file/fixture/CI lane is wrong or impractical; and split/merge rationale tied to repo convention when unrelated behavior shares a file.
   - Broad E2E/manual proof is valid only when the row explains why lower-layer deterministic seams cannot provide equivalent confidence. Hidden live dependencies, private choreography assertions unless explicitly contractual, named variants without proof or explicit exclusion, and convenience-only grab-bag test placement are invalid.
   - Every added or changed test/proof surface must appear in the TAP, and `Acceptance Proof Matrix` rows should reference relevant `TAP-*` rows when tests or proof surfaces change.
3. `### Acceptance Proof Matrix`
   - Required columns: `Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail`.
   - Every `A<n>` id must have at least one row. `Proof Maturity` is only `final` or `provisional`; provisional rows require non-blank `Open Detail`.
   - If an acceptance id names variants, modes, branches, fallback paths, failure cases, or examples, split them into separate acceptance ids or decompose them into separate proof obligations such as `A6/missing`, `A6/empty`, or `A6/malformed`. Each named case needs evidence or an explicit exclusion.
   - A proof row may cover multiple ids only when the same proof action and failure signal genuinely cover all listed ids and named variants.

Before locking rows, ask whether the story relies on any design source (mockup, wireframe, screenshot, Figma frame, presentation blueprint, prior `/grillme` discussion, or operator-approved design summary). Require durable/reviewable anchors and classify each source as `normative` or `orientation only`. Orientation-only sources create no implementation or proof obligation unless the same behavior appears in `## Acceptance`.

Before locking rows, classify activated risk lenses using story-specific evidence, not a generic checklist. Common lenses include async/event-loop behavior, concurrency, process/resource lifecycle, retries/timeouts, platform/OS APIs, filesystem/network/subprocess I/O, permissions/security, persistence/migrations, generated artifacts, prompt/template fail-open behavior, external services, and naming-sensitive invariants. Add proof obligations, a `### Risk Lens Inventory`, or explicit exclusions; if none are material, record that.

Add conditional subsections when relevant:

- `### Surface / Branch Proof Matrix` for multiple user-visible surfaces, supported variants/profiles/modes, or internal orchestration branches. Include rows for every in-scope combination or an explicit exclusion; distinguish `helper`, `routing`, and `behavior` proof classes, and require routing proof when multiple supported callsites exist.
- `### Design Sources` whenever design artifacts are referenced; `Status` must be `normative` or `orientation only`.
- `### Design Element Trace` when any design source is normative. Map every visible element/state as `required` or bounded `flexible` through `Scenario -> Acceptance -> Verification`, and require rendered-surface proof for visibility, placement, navigation, copy, responsive behavior, and interaction-state obligations unless an explicit narrower proof boundary is recorded.
- `### Input Boundary Shape Risk` when raw persisted, external, framework, or generated input crosses into stricter assumptions. Proof starts at the named raw input boundary, or the story records an exclusion/unknown with mitigation.
- `### Fail-open Checks` for prompt/template/placeholder/string-substitution features. Prove supported renders leave no unresolved placeholders/raw tokens, enabled paths activate the feature, and disabled/default paths remain unchanged.
- `### Risk Lens Inventory` when activated risks are not fully covered by the other matrices.

Do not accept vague proof like "run the relevant tests" or fake seams that only validate heavily mocked helpers. Planned assertions should prefer caller-observable behavior and contract outcomes; private retry counts, sleeps, helper call order, temporary names, or implementation choreography are contractual only when the story explicitly locks them. Validate the scenario funnel before leaving this question: every normative scenario with `Covers: A<n>` must be covered by the linked acceptance item's proof row(s).

Debt Friction check: actively ask whether proof planning is being made harder by unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure. Only record a `Debt Friction` entry when there is a story-local causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.

### Question 10 — Critical Files

Actively probe the codebase:

1. Extract 3-5 domain keywords from Purpose and Scope.
2. Search for those keywords across the project.
3. Propose candidate files with line refs and a short role, for example `src/auth/session.ts:142 — session refresh owner`.
4. Let the operator confirm, correct, or add.

Do not ask the operator to list Critical Files from memory. Critical Files should be a terse path-and-role list, not a second implementation plan. For files that need to be created, mark them explicitly: `src/auth/refresh.ts (new, does not yet exist)`.

### Question 11 — Implementation Notes

Ask for only the execution context that changes implementation:

- source-inspection focus
- smallest likely red-first seam or seam family
- phases if sequencing matters
- known constraints or live/manual exceptions
- activated risk lenses and existing project idioms the implementer should compare against
- required written exception if red-first may be infeasible

Move decisions and rejected alternatives to `## Locked Decisions`; do not duplicate them here.

If the implementation plan involves changing existing function signatures or adding new parameter-wiring contracts, ask the operator to record those as interface-contract decisions before closing this question. For each function whose signature changes, lock the exact new parameter name, type, and default value (or the exact dict-key contract if reading from a policy dict). For each callee parameter the plan intentionally does not wire, ask for an omission reason. These decisions are strong candidates for `D-XX` entries in Locked Decisions.

### Question 12 — Locked Decisions

Ask: "what has been decided, and what alternatives were considered and rejected?" Cross-check each decision against `AGENTS.md` / `CLAUDE.md`. If a decision contradicts a stated convention, flag it and ask whether the operator wants to revise the decision or handle the convention change separately.

Also probe at the implementation-interface grain: "What connected-function interface contracts should be locked?" Ask which existing functions are getting new parameters, how those parameters reach the function (passed explicitly vs. read from enclosing data structures), which callee parameters are intentionally not wired and why, and what output/report schemas the implementation must produce. Any signature change, wiring contract, or schema requirement that would cause the implementer to guess should become a `D-XX` entry.

### Question 13 — Discovery Notes

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
- `## Actors`
- `## Triggering Need`
- `## Expected Prerequisites`
- `## Scope`
- `## Out of Scope`
- `## Scenarios / Behavior Examples`
- `## Acceptance`
- `## Verification`

Optional narrative sections:

- `## Discovery Notes`
- `## Critical Files`
- `## Implementation Notes`
- `## Locked Decisions`

Include optional narrative sections when they have material content or when sibling-story convention includes them. If sibling convention forces an optional section with no material content, write `None identified.`

Do not create `<TODO: ...>` placeholders in any section. If `## Actors`, `## Scenarios / Behavior Examples`, `## Acceptance`, or `## Verification` is incomplete, keep interviewing instead of drafting.

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
   - `## Actors` exists, uses role bullets, and includes at least one `Primary:` actor
   - `## Scenarios / Behavior Examples` exists, every normative `S<n>` scenario has exactly one `Covers: A<n>`, and every orientation-only scenario says `Orientation only`
   - every linked scenario is covered by its acceptance id and by that id's proof row(s)
   - every acceptance bullet begins with `A<n>:`
   - `## Verification` contains `### Verification Commands` and `### Acceptance Proof Matrix`
   - the proof matrix uses the required columns
   - every acceptance id appears in at least one proof row
   - every `Proof Maturity` value is `final` or `provisional`
   - every `provisional` row has non-blank `Open Detail`
   - required surface/branch, design-source/element-trace, input-boundary, fail-open, and risk-lens sections are present when the story risk surface calls for them
   - every normative design source has a durable anchor, every visible element/state is mapped as `required` or bounded `flexible`, and design obligations that require rendered-surface proof name a rendered reviewer action or an explicit exception
   - proof rows separate observable behavior from implementation mechanics unless the mechanics are explicitly contractual
   - no `<TODO: ...>` placeholders exist in any required spec section

Abort or continue the interview if validation fails. Do not write malformed story state.

## Checkpoint

Show the operator:

- Resolved story number and filename, including numbering basis.
- Dependency validation report.
- Section list, including which optional narrative sections were included, omitted, or forced by sibling convention.
- Acceptance/proof validation summary.
- Surface/branch, design trace, fail-open, and risk-lens coverage summaries when present.
- The full drafted story file content.
- The exact `MASTER.md` row to append.

**CHECKPOINT**: explicit y/n before writing. If the operator rejects, return to the interview loop at the question they want to revisit. If they accept, continue to write.

## Write

1. Write the new story file at `<epic>/story-<NN>-<slug>.md`.
2. Edit `MASTER.md` to append a new tracker row:

   ```md
   | <NN> | 🟡 PLAN DRAFT | ⚪ TODO | <TITLE> | <DEPENDS or "none"> | `story-<NN>-<slug>.md` |
   ```

3. Match the existing tracker table column count and ordering. Read the header row to determine whether the epic uses the current six-column `Step | Plan | Status | Deliverable | Depends | Spec` shape or an older 3-, 4-, or 5-column shape. For older trackers without `Plan`, do not invent an extra column in a single story append; use the existing shape and mention that `/epic-plan` now creates a first-class `Plan` lane for new epics.
4. Escape markdown table delimiters in the title before writing the row.
5. Never seed runtime sections.

## Final response

State clearly:

- filename created
- story number assigned
- dependency report
- optional section summary
- suggested next action: `/epic-story-plan-review <epic> <NN>` from a fresh session

Keep it short — three or four sentences is enough.
