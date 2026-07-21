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
│   └── blocked.md
└── changes/archive/<story-slug>/
```

Slug rules for initiatives and stories: lowercase letters, digits, and single
hyphens only (`^[a-z0-9]+(?:-[a-z0-9]+)*$`). Commands must validate slugs before
constructing paths from operator input, feedback, URLs, or inferred text.

`<openspec_root>` is an invocation-local resolver variable, not a durable field.
The `/openspec-story-review` packet producer and `/openspec-feedback` packet
consumer support an explicit contained `WORKTREE=` path for their exact
initiative/story pair even when that path is unregistered; only their fallback
branch discovery requires a registered `refs/heads/<initiative>/<story>`
worktree. This is a scoped producer/consumer contract, not a promise for every
command accepting `WORKTREE=`. Ordinary feedback and next-action retain their
own launch-root/registered-worktree boundaries, and other commands follow their
individual resolver contracts. Recompute all coordination paths after selection
and never merge evidence across roots.

A feedback batch separately resolves one root containing the selected initiative
and every targeted active story before acknowledgement or writes; every item
and receipt uses that root's one initiative ledger. For an initiative-only batch,
a unique explicit qualifying checkout wins; otherwise exactly one registered
worktree on `refs/heads/<initiative>/*` containing the initiative wins over the
launch checkout. Multiple qualifying explicit or initiative-branch worktrees
halt; launch is fallback only when no branch qualifies and it contains the
initiative. No qualifying root also halts. A batch never splits ledgers. Never
persist an `OpenSpec root:` or other absolute artifact-root field in
`initiative.md`, `story.md`, `progress.md`, `blocked.md`, or a receipt. Per-repo worktree paths in
`progress.md → ## Current Claim` remain execution bindings, not artifact
authority.

Archive discovery follows the same unique active-root preference, but the
rootless `/opsx:archive` adapter redesign is deferred. When archive discovers
that the active pair is outside its launch checkout, it halts and tells the
operator to rerun `/openspec-archive` from that active checkout; it does not
mutate a remote root.

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

Operational sections are created on first use by `/openspec-feedback`; initial
initiative planning does not seed them:

- `## Feedback-Derived Story Candidates`
- `## Feedback-Derived Decisions`
- `## Feedback Receipts`

`## Feedback Receipts` is the portable append-only deduplication and routing
ledger for **ordinary non-review feedback mode**. Every acknowledged ordinary
mode disposition, including defer/reject, gets exactly one compact entry keyed
by deterministic `Source ID` plus `Source hash`. Review packet triage is a
separate receiptless mode: it creates no feedback receipt, review cycle,
identity digest, or review history. GitHub
objects use their stable object identity. For a manual/file item, decode valid
UTF-8, convert CRLF to LF, trim only outer Unicode whitespace, preserve all
remaining content, and hash the complete normalized UTF-8 bytes with SHA-256
(no added delimiter or terminal LF). Both `Source hash` and
`Source ID: manual:sha256:<full-hex>` use that full content hash—never an ordinal,
path, label, timestamp, truncation, or runtime value. Identical normalized
content intentionally deduplicates to one identity regardless of input order:

```md
## Feedback Receipts

### FB-### — <short summary>
- Source ID: <stable source id>
- Source hash: sha256:<hex>
- Disposition: <queue-planning-feedback | amend-existing-story | resume-current-story | new-story-candidate | initiative-level-decision | defer-or-reject>
- Target: <story:<story-slug> | candidate:<initiative>/feedback:<FB-###> | initiative:<initiative>>
- Acknowledged reason / rationale: <why the operator accepted this routing>
- Changed artifacts: <OpenSpec-relative paths; receipt-only for defer/reject>
- Next owner: <owning command, operator action, wait, or None>
```

Only ordinary mode in `/openspec-feedback` creates or appends this section. One
ordinary-mode invocation reads, allocates IDs from, deduplicates against, and
writes exactly one selected initiative ledger, even when the batch targets
several stories. With no story
target, it resolves the unique active initiative worktree using the explicit,
initiative-branch-over-launch precedence before touching the ledger; ambiguity
halts. For each item, feedback applies its acknowledged owned edits before publishing the receipt. An
interruption therefore cannot advertise unapplied edits: a retry reuses the
same deterministic source identity, does not repeat an already completed owned
edit, and may append the one missing receipt after acknowledgement. Notebook
mirrors may be used for orientation when a runtime supports them, but the
workflow never requires or invokes notebook APIs; mirrors never replace this
ledger or participate in deduplication/lifecycle authority. Deprecated implementation-review receipts are separate inert migration input;
ordinary-feedback receipt handling never rewrites or normalizes them.

External resources are links or anchors. Do not paste long ticket, PR, or design
bodies into the initiative file.

## Change workspace planning artifacts

`/openspec-story-plan` creates planning artifacts only. It does not create
`progress.md` or `blocked.md`.

### `proposal.md`

OpenSpec proposal for the change: why the change exists, what behavior/specs it
will affect, and the high-level scope. Created by `/openspec-story-plan` and
repaired or completed by `/openspec-story-plan-resume`.

### `story.md`

The story is the operator/reviewer contract. Every new story has exactly one
initiative binding and both lifecycle fields as top-level header fields, never
`##` sections:

```md
# <Story Title>

Plan: 🟡 PLAN DRAFT
Status: ⚪ TODO
Initiative: <initiative-slug>
Review Focus: |
  <optional reviewer guidance on indented lines>
```

`Initiative:` must match `^[a-z0-9]+(?:-[a-z0-9]+)*$` and the selected existing
`openspec/initiatives/<initiative-slug>/initiative.md`. `Status:` is the only
canonical implementation-status header; an `## Status` section is not an
equivalent. `Review Focus: |` occurs exactly once. Its body consists only of the
immediately following indented lines and ends at the next top-level header. A
blank block means full review. A nonblank block permits a focused review of its
named surfaces and evidence, subject to reviewer widening when scope, risk, or
evidence requires a full review. Implementation owns Review Focus:
`/openspec-story-claim` and `/openspec-story-resume` overwrite it before every
handoff to `🟣 IN REVIEW`, using a blank block when no focus is needed. Review
reads but never writes it; outside IN REVIEW it is inert. `## Acceptance` is the
canonical contract heading; do not rename it `## Acceptance Criteria`.

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
| `## Plan Review Log` | Seeded as an empty section by the story template and `/openspec-story-plan`; entries are created/appended only by plan review, planning feedback, or plan-resume addressed-entry repair. |

The valid top-level `Initiative:` header is authoritative for story discovery,
menus, and routing. Parsers inventory the full top-level header region before
consuming a value. Legacy absence means zero unindented `Initiative` or
Initiative-like field lines. Exactly one whole-line canonical header is valid;
duplicates, `Initiative :`, an empty value, a non-canonical value, or any other
present malformed Initiative-like field halt. A malformed present line never
counts as absence. Commands enumerate active change workspaces by the exact
binding; `initiative.md → ## Story Candidates` is not the primary index for new
stories.

Legacy stories without an `Initiative:` header are compatibility inputs, not a
second schema—but only when the inventory also contains zero Initiative-like
lines. The inventory count must be zero; a malformed present field never counts
as absence. Use one bounded rule everywhere. Accept an absent binding only when
either:

1. the operator explicitly supplies or selects the initiative **and the story as
   a pair**, the initiative exists, and no exact `## Story Candidates` evidence
   associates that story with a different or multiple initiatives; or
2. discovery finds exactly one initiative whose `## Story Candidates` section
   exactly associates the story slug, and that existing initiative becomes the
   resolved binding.

An auto-defaulted initiative or an initiative-only menu choice is not an
operator-explicit initiative/story pair. Until the story is also explicitly
selected, a zero-association legacy story cannot use that fallback; discovery
requires the unique exact association in rule 2. Every accepted legacy case
warns that the durable binding is absent, and no discovery, routing, review,
claim, resume, feedback, PR, or archive command backfills it.

Duplicate top-level `Initiative:` headers—or one empty, malformed, or mismatched
Initiative-like field—are hard conflicts, never legacy input. Presence is decided
before validity, so malformed syntax cannot fall through to the zero-line legacy
case. A different or multiple exact candidate association is conflicting evidence
and halts. Zero candidate evidence also halts whenever neither an explicit pair
nor rule 2 applies. Never guess from general prose.

Legacy or malformed stories missing `Plan:`, `Status:`, or the empty
`## Plan Review Log` anchor are normalized by `/openspec-story-plan-resume`; it
may add missing `Plan: 🟡 PLAN DRAFT`, add missing `Status: ⚪ TODO`, normalize
exact legacy `Status: ⬜ TODO` to `Status: ⚪ TODO`, and add the empty log
section, but it must not rewrite active, in-review, done, blocked, blank, or
unknown status values. `/openspec-story-claim` owns the ready TODO-to-IN-PROGRESS
Status write. `/openspec-story-resume` owns authorized implementation continuation
Status writes, including return to IN REVIEW. In ordinary mode,
`/openspec-feedback` owns only an acknowledged reopen to IN PROGRESS. In review
packet triage it may publish confirmed Status-last `🔄 IN PROGRESS`, `✅ DONE`,
or `⛔ BLOCKED` outcomes after all bounded canonical postconditions are verified;
`NOT REVIEWABLE` cannot publish DONE. `/openspec-story-review` is a readonly
packet producer and owns no Status write.

#### Prerequisite qualification

Resolve an active prerequisite before an archived fallback; an existing active
copy always wins. It must have exactly one unambiguous `Status: ✅ DONE` and no
sibling `blocked.md`. Receipt presence, absence, or stale legacy content does not
qualify or disqualify a prerequisite. Readers use current lifecycle artifacts
and never treat an implementation-review receipt as approval authority.

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
traceability that would bloat `story.md`. It is created by
`/openspec-story-plan`, repaired/completed by `/openspec-story-plan-resume`, and
may receive acknowledged contract-changing edits from `/openspec-feedback`. If
a design source is normative, the story/design pair must include durable anchors
and a trace from source elements to Scenario, Acceptance, and Verification proof.

### `tasks.md`

Tasks are the execution checklist. They are created by `/openspec-story-plan`,
repaired/completed by `/openspec-story-plan-resume`, maintained during
implementation by `/openspec-story-claim` and `/openspec-story-resume`, and may
receive acknowledged task/proof-alignment edits from `/openspec-feedback`.
`/openspec-story-review` and `/openspec-archive` expect completed in-scope tasks
before approval/archive. Keep tasks tied to acceptance/proof rather than generic
activity.

### `specs/**/*.md`

Delta specs follow OpenSpec conventions for the project. They are created by
`/openspec-story-plan` and repaired/completed by
`/openspec-story-plan-resume`. `/openspec-archive` delegates spec synchronization
and the workspace move to OpenSpec's built-in `/opsx:archive <story-slug>`
command after completion gates pass.

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
- implementation review: reads artifacts and emits one portable readonly review
  packet; confirmed `/openspec-feedback` packet triage records the resulting
  bounded canonical decision and publishes any eligible lifecycle Status last.
  Existing implementation-review receipt shapes are inert legacy data pending
  the explicit migration command.

## Runtime artifacts

### `progress.md`

Created on the first runtime write by an artifact-writing owner, normally
`/openspec-story-claim` or `/openspec-story-resume`. Readonly
`/openspec-story-review` never creates or changes it. Standard sections:

- `## Current Claim` — current implementation owner, scope, write surfaces,
  worktree bindings, and status.
- `## Progress Timeline` — append-only concise implementation, handoff,
  red-first, proof, Debt Friction, ordinary-feedback checkpoint, and PR delivery
  milestones. It is written by `/openspec-story-claim`,
  `/openspec-story-resume`, ordinary `/openspec-feedback`, and `/openspec-pr`.
  Review packet triage records no receipt, review cycle, digest, review timeline,
  or publication log.
- `## Implementation Review Receipt` — deprecated, inert legacy data. It has no
  lifecycle authority and receives no new writes. `/openspec-migrate` is the
  sole removal owner for a uniquely recognized legacy receipt; duplicate,
  malformed, or ambiguous
  bodies fail closed for operator repair.
- `## Session Handoff` — latest exit state and next action for a fresh session.
- `## PR State` — sole durable PR metadata/evidence location, owned by
  `/openspec-pr`. Before every PR route, the complete bounded Current Claim
  Worktrees/Primary write surfaces map must resolve exactly one product
  repository and the live PR head repository must match it. Its `Delivery head:`
  is the clean current Git HEAD recorded only after a fresh isolated readonly
  delivery audit and exact equality with the live PR `headRefOid`; archive
  rechecks the live merged head against it. A no-PR archive resolves the same
  bounded map and audits every resolved product repository; missing or ambiguous
  mappings fail closed.
  It is non-review delivery evidence and never a packet, receipt, digest, or
  identity. It does not own implementation status transitions. An explicitly
  confirmed no-PR archive runs a fresh isolated readonly delivery audit
  immediately before archive instead of inventing this field.

`story.md → Status:` controls lifecycle routing, including ordinary bound
receiptless DONE. A stale legacy implementation-review receipt is inert: it does
not qualify a prerequisite, block PR/archive, override Status, or supply current
review authority. `/openspec-migrate` previews and, after explicit confirmation,
removes one uniquely recognized legacy receipt only from explicitly bound active
changes while preserving non-review progress content. `/openspec-migrate`
excludes unbound pre-v3 stories and leaves them untouched because there is no
safe initiative inference for migration. It never synthesizes approval.
Duplicate, malformed, or ambiguous
legacy bodies fail closed for operator repair rather than being selected or
normalized.

Readonly review validates the implementation and emits one transient portable
packet without changing `progress.md`, `story.md`, `blocked.md`, or notebook
state. Confirmed `/openspec-feedback` packet triage applies bounded canonical
postconditions and publishes Status last. Immediately before DONE it launches
one isolated fresh replay over current implementation evidence using the same
readonly evaluator semantics. The result must be semantically equivalent to the
submitted packet; mismatch or drift is rejected, must not publish DONE, and
creates no persisted packet, receipt, review timeline, cycle, digest, identity,
or publication history.

Legacy implementation-review receipt maintenance belongs only to
`/openspec-migrate`, which may remove one matching its bounded legacy shape;
malformed or ambiguous state requires operator repair.

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

### `blocked.md`

Existence means the story is blocked. `/openspec-story-claim` and
`/openspec-story-resume` may create or update it. Confirmed review-packet triage
in `/openspec-feedback` may create it before publishing top-level
`Status: ⛔ BLOCKED`; exact existing final bytes are already satisfied, while a
conflicting existing file is preserved and blocks publication. Readonly
`/openspec-story-review` only reads it. Commands otherwise halt on the file and
report its contents. The sole existing-file exception is a confirmed
`/openspec-feedback` packet-triage rerun: when the existing bytes exactly equal
the already-confirmed planned final bytes, it verifies the postcondition without
rewriting and may continue to Status-last BLOCKED publication. After the operator
removes any other blocker file, `/openspec-story-resume` may normalize stale
blocked status and record history in `progress.md`; the hard gate is the file.

## Argument and selection rules

- Creation, review, feedback, and converger commands require operator-explicit
  targets through arguments or menus. A menu choice is explicit for the value it
  selects, but an initiative-only menu choice or auto-default is not an explicit
  initiative/story pair for the missing-`Initiative:` legacy fallback.
- Story discovery and menus enumerate active workspaces by their valid exact
  top-level `Initiative:` binding. They consult exact `## Story Candidates`
  references only for the bounded missing-header legacy rule above.
- Claim/resume/PR commands may discover eligible work when that is their job,
  but explicit arguments always win and do not override a conflicting binding.
- Loopers (`/openspec-story-plan-converge`, `/openspec-story-converge`) target
  exactly one operator-selected story and delegate normal writes to lifecycle
  commands. Implementation convergence delegates only claim/resume passes and
  stops at `🟣 IN REVIEW` instead of launching review. Explicitly documented
  safety-normalization writes are allowed; for example,
  `/openspec-story-plan-converge` may downgrade an orphaned `🟢 PLAN APPROVED`
  that lacks an independent approve log.
- Commands should print resolved context before high-blast-radius writes.

## Suggested next action output

Every active OpenSpec workflow response contains exactly one of these forms:

```text
Suggested next action: <exact command | operator action | wait | None>
```

```text
Suggested next action:
- Converge wrapper: <exact command | operator action | wait | None>
- Non-looped pass: <exact command | operator action | wait | None>
Choose one; do not run both.
```

Use the scalar form when there is one valid route. Use the dual block only when
the current state permits either the iterative wrapper or one state-owning
direct pass. The two routes delegate the same owner commands, so they are
alternatives for the same transition, not sequential instructions. Use an exact
command with resolved arguments when possible, an explicit operator action when
human choice or intervention is required, `wait` for an external dependency, or
`None` when the workflow is complete. Do not emit a competing `Next Action` or
`Suggested next step` field.

Planning convergence runs fresh plan-review/plan-resume passes until approval or
a documented stop. A non-looped planning pass runs only the state-correct direct
command; plan-resume cannot approve its own repair, so repaired plans still need
a fresh plan review. Implementation convergence runs fresh claim/resume passes
until `🟣 IN REVIEW` or a documented stop and never launches implementation
review. A non-looped implementation pass runs one claim or resume and may leave
the story `🔄 IN PROGRESS`. Once it reaches `🟣 IN REVIEW`, the only review route
is `/openspec-story-review` in a completely fresh, oblivious session without
implementation-loop notebook, summary, operational-note, or prior-chat context.

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
live files before it drives an edit or status transition. Implementation review
is the exception: `/openspec-story-review` must run from a fresh, oblivious
session and must not receive parent/converger notebook entries, implementation
summaries, operational notes, or prior chat context.

## What active commands should not do

- Mutate product code from plan review, implementation review, feedback, PR, or
  archive commands.
- Create runtime files during `/openspec-story-plan`.
- Approve a plan from `/openspec-story-plan-resume` or `/openspec-feedback`.
- Advance or approve implementation status from ordinary `/openspec-feedback`,
  or derive status transitions from PR metadata refreshes. Ordinary mode may
  only reopen to `🔄 IN PROGRESS` after an acknowledged `resume-current-story`
  disposition. Review packet triage separately owns only its confirmed,
  Status-last `IN PROGRESS`/`DONE`/`BLOCKED` outcomes and never publishes DONE
  for `NOT REVIEWABLE`.
- Treat an unmerged PR as authority to reopen or downgrade a locally DONE story;
  route actionable PR feedback through `/openspec-feedback` for classification.
- Let an old implementation-review receipt override authoritative Status or
  current artifacts; receipt presence and absence are inert for prerequisite,
  delivery, and archive routing.
- Ask any workflow other than `/openspec-migrate` to maintain or remove a legacy
  implementation-review receipt.
- Accept a prerequisite that has `blocked.md` or lacks exact DONE Status.
- Archive a story with `blocked.md`, incomplete tasks, non-DONE Status, or
  unresolved PR/no-PR evidence.
- Treat notebook pages, chat summaries, or old handoffs as stronger authority
  than current OpenSpec artifacts and live repo evidence.
