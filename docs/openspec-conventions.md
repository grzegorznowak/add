# OpenSpec Artifact Conventions

This document describes the active `add` OpenSpec file conventions. The skill
bodies are the executable command contracts; this document is the shared schema
reference they point at for artifact shape, proof quality, and runtime logs.

## Directory layout

```text
openspec/
├── initiatives/<initiative-slug>/
│   └── initiative.md
├── changes/<story-slug>/
│   ├── proposal.md
│   ├── story.md
│   ├── design.md
│   ├── tasks.md
│   ├── specs/**/*.md
│   ├── progress.md
│   ├── reviews.md
│   └── blocked.md
└── changes/archive/<story-slug>/
```

Slug rules for initiatives and stories: lowercase letters, digits, and single
hyphens only (`^[a-z0-9]+(?:-[a-z0-9]+)*$`). Commands must validate slugs before
constructing paths from operator input, feedback, URLs, or inferred text.

## `initiative.md`

Created by `/openspec-initiative-plan`. Minimum shape:

```md
# <Human Title>

source_of_truth: internal | external

## Goal / Context
<initiative purpose, done definition, risks / unknowns>

## Story Candidates
<informal candidate list; each real story is later created by /openspec-story-plan>

## Decisions & Constraints
<initiative-level commitments inherited by stories>

## External Resources
- <label>: <url>
```

Operational sections are created on first use by `/openspec-feedback`:

- `## Feedback Absorption Log`
- `## Feedback-Derived Story Candidates`
- `## Feedback-Derived Decisions`

External resources are links or anchors. Do not paste long ticket, PR, or design
bodies into the initiative file.

## Change workspace planning artifacts

`/openspec-story-plan` creates planning artifacts only. It does not create
`progress.md`, `reviews.md`, or `blocked.md`.

### `proposal.md`

OpenSpec proposal for the change: why the change exists, what behavior/specs it
will affect, and the high-level scope.

### `story.md`

The story is the operator/reviewer contract. The header contains both lifecycle
lanes:

```md
# <Story Title>

Plan: 🟡 PLAN DRAFT
Status: ⬜ TODO
```

The planning body should contain these sections when applicable:

| Section | Purpose |
|---|---|
| `## Purpose` | One paragraph describing the user/system outcome. |
| `## Actors` | Lightweight role bullets; include at least one `Primary:` actor when present. |
| `## Triggering Need` | Why this story exists now. |
| `## Expected Prerequisites` | Required completed stories or external prerequisites. |
| `## Scope` | In-scope behavior and surfaces. |
| `## Out of Scope` | Explicit exclusions. |
| `## Scenarios / Behavior Examples` | Concrete behavior examples that funnel into acceptance. |
| `## Acceptance` | Stable, atomic, observable acceptance IDs (`A1:`, `A2:`, ...). |
| `## Verification` | Reviewer-facing proof contract. |
| `## Discovery Notes` | Durable source-derived facts, gotchas, seams, or constraints. |
| `## Critical Files` | Paths and roles the implementer/reviewer should inspect. |
| `## Implementation Notes` | Execution brief, red-first guidance, phases, and known exceptions. |
| `## Locked Decisions` | Decisions made during planning and rejected alternatives. |
| `## Plan Review Log` | Created/appended by plan review or planning feedback, never by initial planning. |
| `## Feedback Absorption Log` | Optional story-local receipt for feedback edits. |

#### Actors

- Use role bullets, not personas.
- Include at least one `Primary:` role when the section exists.
- Add `Secondary:`, `Reviewer:`, `System:`, or named external-service roles only
  when they clarify behavior or review responsibility.
- Actor claims must stay consistent with Purpose, Scope, Acceptance, and
  Verification.

#### Scenarios / Behavior Examples

Scenarios are a funnel, not a parallel requirements list:

```text
Scenario -> Acceptance -> Verification
```

Rules:

- Use stable `S<n>` labels.
- Every normative scenario must have exactly one `Covers: A<n>` link.
- Orientation-only examples must explicitly say `Orientation only`.
- If one scenario spans multiple acceptance IDs, split the scenario or reshape
  acceptance before review.
- A scenario that describes required behavior but does not map to acceptance is
  a planning-contract gap.

#### Acceptance

- Every top-level item starts with a stable `A<n>:` id.
- Each item is atomic: split behaviors that can fail independently.
- Each item is observable by command, file read, UI observation, API response,
  log/event, or other reviewer-visible evidence.
- Acceptance must not hide implementation choreography unless that choreography
  is explicitly contractual.

### `design.md`

Use `design.md` for design context, UI/UX sources, architecture notes, and
traceability that would bloat `story.md`. If a design source is normative, the
story/design pair must include durable anchors and a trace from source elements
to Scenario, Acceptance, and Verification proof.

### `tasks.md`

Tasks are the execution checklist. `/openspec-story-review` and
`/openspec-archive` expect completed in-scope tasks before approval/archive.
Keep tasks tied to acceptance/proof rather than generic activity.

### `specs/**/*.md`

Delta specs follow OpenSpec conventions for the project. `/openspec-archive`
delegates spec synchronization and the workspace move to OpenSpec's built-in
`/opsx:archive <story-slug>` command after completion gates pass.

## Verification contract

`## Verification` is the proof contract, not a loose checklist. It must include
these core subsections:

```md
## Verification

### Verification Commands
- <exact command or exact manual/file-read action>

### Test Architecture Plan
| Row ID | Layer / Scope | Behavior / Acceptance Slice | Owning Suite / File(s) | Boundary Exercised | Assertions / Observability | Fixture / Test Data Strategy | CI Lane / Command | Fallback Plan | Split / Merge Rationale |
|---|---|---|---|---|---|---|---|---|---|
| TAP-1 | <repo-supported layer> | A1 | <planned proof owner> | <real boundary/seam> | <observable assertion> | <fixtures/data/live-dependency policy> | <focused command or CI lane> | <fallback if seam is wrong> | <why this row is split/merged> |

### Acceptance Proof Matrix
| Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail |
|---|---|---|---|---|---|---|
| A1 | final | automated | <exact reviewer action referencing TAP-1 when relevant> | <expected evidence> | <paths / commands / surfaces> | |
```

### TAP quality gate

Every Test Architecture Plan row must have:

- stable `TAP-*` row id;
- cheapest reliable real boundary, not a fake seam;
- exact owner path/suite when knowable;
- behavior-facing assertion or reviewer-visible signal;
- fixture, data, and live-dependency policy;
- focused command or CI lane;
- fallback plan if the preferred seam/layer/fixture is wrong or impractical;
- split/merge rationale tied to repository convention.

Broad E2E/manual proof is valid only when the row explains why lower-layer
deterministic seams cannot provide equivalent confidence. Convenience-only
grab-bag placement, hidden live dependencies, private call-order assertions, and
named variants without proof or explicit exclusion are invalid.

### Acceptance Proof Matrix rules

- Every `A<n>` appears at least once.
- Rows may reference multiple acceptance IDs only when one proof action and one
  failure signal genuinely cover all listed IDs without reducing clarity.
- `Proof Maturity` is `final` or `provisional` only.
- `Open Detail` is required for provisional rows and blank/explicitly closed for
  final rows.
- Planning may contain provisional rows if they are concrete enough to guide
  implementation. Implementation review cannot approve while proof remains
  provisional.
- Rows should reference relevant `TAP-*` IDs when tests or proof surfaces change.

### Conditional proof sections

Add these when the story's risk surface requires them.

#### Surface / Branch Proof Matrix

Use when behavior spans multiple surfaces, variants, profiles, modes, callsites,
or internal orchestration branches.

```md
### Surface / Branch Proof Matrix
| Surface | Supported Variant | Internal Execution Branch | Proof Class | Owning Proof Seam | Why This Seam Is Sufficient | Out of Scope Notes |
|---|---|---|---|---|---|---|
```

Rules:

- Cover every in-scope surface / variant / branch combination or record an
  explicit exclusion.
- `Proof Class` distinguishes `helper`, `routing`, and `behavior` proof.
- Helper proof alone is insufficient when supported callsites or orchestration
  branches must route through the helper.

#### Design Sources and Design Element Trace

Add `### Design Sources` whenever the story references a mockup, wireframe,
screenshot, Figma frame, presentation blueprint, prior design discussion, or
other design artifact. Mark each source as `normative` or `orientation only`.

When any source is normative, add `### Design Element Trace` in `story.md` or
`design.md`:

```md
### Design Element Trace
| Source Anchor | Visible Element / State | Obligation | Bounds / Required Behavior | Scenario | Acceptance ID | Proof Row / Reviewer Action |
|---|---|---|---|---|---|---|
```

Rules:

- `Obligation` is only `required` or bounded `flexible`.
- Every normative visible element/state maps through Scenario → Acceptance →
  Verification.
- Visibility, placement, navigation, copy, responsive behavior, and interaction
  states require rendered-surface proof unless an explicit exception is recorded.
- Orientation-only sources create no obligation unless the same behavior appears
  in Acceptance.

#### Input Boundary Shape Risk

Use when raw persisted, external, framework, generated, imported, or API input
crosses into stricter assumptions such as parsing, validation, classification,
normalization, migration, aggregation, routing, import/export, or schema
construction.

```md
### Input Boundary Shape Risk
| Boundary | Raw Input Source | Strict Assumption | Variant / Case | Evidence | Mitigation / Exclusion |
|---|---|---|---|---|---|
```

Evidence must start at the named raw boundary. Helper-level proof with already
normalized data is insufficient unless the story narrows the proof row and says
why that is safe.

#### Fail-open Checks

Use when prompt placeholders, template variables, string substitution, or other
prompt/template assembly can silently no-op:

```md
### Fail-open Checks
- Supported renders leave no unresolved feature placeholders or raw tokens.
- Enabled supported paths prove the feature is active, not silently ignored.
- At least one disabled or default path proves baseline behavior stays intact.
- Intentionally excluded profiles/modes are called out explicitly.
```

#### Risk Lens Inventory

Use when activated risks are not already covered by the matrices above. Common
lenses include async/event-loop behavior, concurrency, process/resource
lifecycle, platform/OS APIs, filesystem/network/subprocess I/O,
permissions/security, persistence, retries/timeouts, generated artifacts,
external services, and naming-sensitive invariants.

## Debt Friction

Debt Friction is story-local, not a generic cleanup backlog. It applies only
when the current story is made harder or riskier by concrete debt.

Every entry must show:

```text
current story action -> concrete evidence -> delivery impact -> explicit decision
```

Minimum shape:

```md
### Debt Friction: <short title>

**Current Story Action**
<what was being planned, implemented, tested, or reviewed>

**Friction Evidence**
<files, symbols, tests, behaviors, or concrete unknowns>

**Delivery Impact**
<effect on correctness, testability, reviewability, scope, or safe maintainability>

**Decision**
fix-now | split-story | defer-explicitly | block | not-debt

**Guardrail**
<what prevents silent amplification>
```

Decision-specific fields:

- `fix-now` requires `**Scope Justification**`; use it only for enabling cleanup
  directly required to make this story correct, testable, reviewable, or safely
  maintainable.
- `split-story` requires `**Follow-up Recommendation**`; do not auto-create the
  follow-up story from the entry.
- `defer-explicitly` requires `**Deferral Reason**`.
- `block` requires `**Blocker Condition**`.

Where to write it:

- planning: `story.md → ## Discovery Notes`, `## Verification`, or
  `## Locked Decisions` as appropriate;
- plan review: `story.md → ## Plan Review Log`;
- implementation: `progress.md → ## Progress Timeline`;
- implementation review: `reviews.md`.

## Runtime artifacts

### `progress.md`

Created by `/openspec-story-claim` or `/openspec-story-resume`. Standard
sections:

- `## Current Claim` — current implementation owner, scope, write surfaces,
  worktree bindings, and status.
- `## Progress Timeline` — concise timestamped milestones, red-first evidence,
  proof updates, replanning checkpoints, Debt Friction, and PR transitions.
- `## Session Handoff` — latest exit state and next action for a fresh session.
- `## PR State` — sole durable PR metadata location, owned by
  `/openspec-story-pr`.

`## Current Claim` uses plural worktree bindings when needed:

```md
## Current Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: <runtime/session>
- Scope: <one sentence>
- Worktrees:
  - <repo-basename>: </absolute/path/to/worktree>
- Main-tree targets: <repo-basename>, <repo-basename>
- Primary write surfaces: <paths>
- Status: 🔄 IN PROGRESS
```

Omit `- Worktrees:` entirely when no worktrees are used. New claims should not
write singular `- Worktree:`; review/resume may still read the older shape for
compatibility.

### `reviews.md`

Append-only implementation review history. `/openspec-story-review` owns normal
entries; `/openspec-feedback` may append schema-compatible feedback entries when
external feedback should drive implementation rework.

A useful review entry records:

- decision and approval gate;
- product and technical verdicts;
- prior finding closure;
- Plan lane at review time;
- traceability and evidence quality;
- code surfaces searched;
- risk lenses reviewed;
- finding cards with source anchors;
- next action.

### `blocked.md`

Existence means the story is blocked. Commands should halt on the file, report
its contents, and avoid treating stale status text as a blocker after the file
has been removed. A resolved blocker may leave historical notes in
`progress.md`; the hard gate is the file.

## Argument and selection rules

- Creation, review, feedback, and converger commands require operator-explicit
  targets through arguments or menus. A menu is an explicit choice, not silent
  inference.
- Claim/resume/PR commands may discover eligible work when that is their job,
  but explicit arguments always win.
- Loopers (`/openspec-story-plan-converge`, `/openspec-story-converge`) target
  exactly one operator-selected story and delegate normal writes to lifecycle
  commands. Explicitly documented safety-normalization writes are allowed; for
  example, `/openspec-story-plan-converge` may downgrade an orphaned
  `🟢 PLAN APPROVED` that lacks an independent approve log.
- Commands should print resolved context before high-blast-radius writes.

## Pi notebook conventions

Pi fragments may use `spawn` and notebook pages to carry sourced research or
neutral operational notes across fresh sessions. Notebook pages are orientation,
not lifecycle authority.

Recommended page families:

- `openspec-research-<initiative>-<story>`
- `openspec-ops-<initiative>-<story>`
- `openspec-plan-research-<initiative>-<story>`
- `openspec-plan-ops-<initiative>-<story>`

Every material notebook claim must be verified with direct reads/search against
live files before it drives an edit, review verdict, or status transition.

## What active commands should not do

- Mutate product code from plan review, implementation review, feedback, PR, or
  archive commands.
- Create runtime files during `/openspec-story-plan`.
- Approve a plan from `/openspec-story-plan-resume` or `/openspec-feedback`.
- Transition implementation status from `/openspec-feedback`.
- Mark a story `✅ DONE` while an active PR is unmerged.
- Archive a story with `blocked.md`, incomplete tasks, missing review approval,
  or unresolved PR/no-PR evidence.
- Treat notebook pages, chat summaries, or old handoffs as stronger authority
  than current OpenSpec artifacts and live repo evidence.
