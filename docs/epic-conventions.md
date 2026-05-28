# Epic / Story File Conventions

Every command in this repo reads and writes a small set of well-defined
files inside an epic directory. This document is the schema. Stick to it
and the commands will work; deviate and they will misread your epic.

## Directory layout

```
agent_coordination/epics/<epic-name>/
├── MASTER.md             # tracker + status source of truth (required)
├── CONTRACT.md           # merged authoritative contract (created by /epic-squash, optional until first squash)
├── story-NN-<slug>.md    # one file per active story (the working surface)
├── archive/              # archived stories (created by /epic-squash if missing)
│   └── story-NN-<slug>.md
└── (anything else, untouched by these commands)
```

## `MASTER.md`

The tracker file. The commands treat this as the single lookup table for
which stories exist, what their statuses are, and where their spec files
live. There is exactly one `MASTER.md` per epic.

### Required sections

1. **Header** — at minimum the epic title.
2. **Goal / Context** — free-form prose describing why the epic exists. Read
   by `/epic-pr` as epic-level PR framing.
3. **Legend** — the status values used by the tracker (see
   [`epic-lifecycle.md`](epic-lifecycle.md) for the canonical legend).
4. **Story tracker** — a Markdown table. This is the only section the
   commands actually parse for status changes.

Optional epic-level operational sections may follow the tracker. The current
standard ones are `## Feedback Absorption Log`,
`## Feedback-Derived Story Candidates`, `## Feedback-Derived Decisions`, and
`## Epic PR Tracking`.

### Story tracker table

The current standard columns are `Step | Plan | Status | Deliverable | Depends | Spec`.
Older epics may still have `Step | Status | Spec` plus optional `Deliverable`
and `Depends`; commands must read the header row before editing and preserve
the existing shape unless a migration explicitly adds `Plan`.

```md
## Story tracker

| Step | Plan | Status | Deliverable | Depends | Spec |
|-----:|------|--------|------------|---------|------|
| 01 | 🟢 PLAN APPROVED | ✅ DONE | First public package release | none | `archive/story-01-public-package-contract.md` |
| 02 | 🟢 PLAN APPROVED | ✅ DONE | TestPyPI/PyPI publishing workflow | `01` | `archive/story-02-pypi-trusted-publishing.md` |
| 16 | 🟡 PLAN DRAFT | ⚪ TODO | Repo-owned multi-agent release command | `05`, `15` | `story-16-repo-owned-release-command-and-changelog.md` |
```

Rules:
- The `Step` value (e.g. `01`, `16`) is the canonical story identifier. Use
  zero-padded integers consistent with the rest of the epic.
- The `Spec` cell links to the story file. While the story is active, the
  link points at the epic root (`story-NN-<slug>.md`). After
  `/epic-squash`, it points into `archive/`.
- The `Plan` cell uses one planning-lane value from the Legend exactly. It is
  independent from implementation `Status`.
- The `Status` cell uses one implementation status value from the Legend,
  exactly. The commands match on the leading emoji.
- The `Depends` cell is comma-separated story numbers. Cross-epic
  dependencies use `<epic> <number>` (e.g. `core 06`).

### Feedback absorption sections

`/epic-feedback` owns these sections in `MASTER.md`. They are epic-scoped
because a single PR review or CURe feedback block can route to several stories.

#### `## Feedback Absorption Log`

Canonical append-only index of feedback sources and where each item went. This
log is a receipt, not the durable story contract. When feedback changes an
existing story, the story body is edited and this log records why.

```md
## Feedback Absorption Log

| ID | Source Type | Source ID | Source URL | Created | Updated | Disposition | Target | Changed | Status |
|---|---|---|---|---|---|---|---|---|---|
| FB-001 | github_pr_review_comment | PRRC_... | https://github.com/org/repo/pull/42#discussion_r123 | 2026-04-28T10:40:00Z | 2026-04-28T11:05:00Z | resume-current-story | story-05 | Review Log | absorbed |
```

`Source ID` is the idempotency key for PR pointer mode. `/epic-feedback --pr
<url> --latest` skips sources already listed here.

#### `## Feedback-Derived Story Candidates`

Holding area for feedback that should become future work but has not yet been
planned into a full story. `/epic-feedback` may append candidates here;
`/epic-story-plan` remains the only command that creates real story files.

```md
## Feedback-Derived Story Candidates

### FB-002 - Failed import audit logging
- Source: https://github.com/org/repo/pull/42#issuecomment-987
- Origin: story-03
- Reason: Adds a new auditability outcome outside story-03's acceptance boundary.
- Proposed story: Failed imports emit operator-visible audit entries.
- Acceptance sketch:
  - Failed imports record actor, timestamp, file identifier, and failure reason.
- Recommended next command: `/epic-story-plan EPIC="<epic>"` and reference `FB-002` during the interview
```

#### `## Feedback-Derived Decisions`

Epic-level decision notes created from feedback when the feedback changes a
cross-story rule, architectural policy, or delivery constraint rather than one
story's acceptance contract.

```md
## Feedback-Derived Decisions

### FB-003 - Import errors use operator-facing wording
- Source: https://github.com/org/repo/pull/42#discussion_r456
- Decision: Import validation errors must be phrased for operators, not parser authors.
- Rationale: The rule affects several import stories and should not be duplicated in each story.
- Applies to: story-03, story-07, future import stories
```

## Story files (`story-NN-<slug>.md`)

One file per story. The commands read and append specific named sections.
The list below is the union of every section any command in this repo will
read or write.

### Header

```md
# Story <NN> — <Title>

Status: `todo`

> Story scaffolded directly by `/epic-story-plan` after interactive planning.
```

`Status:` is the file's local copy of the tracker implementation status. It
does not mirror the `Plan` lane. It can drift from `MASTER.md` and
`/epic-squash` will reconcile.

### Spec sections (created by `/epic-story-plan`)

These are the planning surfaces. They are written once at story creation
time by `/epic-story-plan`, and they are read by every other command.

| Section | Purpose |
|---|---|
| `## Purpose` | One paragraph: what user-visible outcome this story delivers. |
| `## Actors` | Role-based participants affected by or involved in the story, such as operator, reviewer, implementation agent, system, or external service. |
| `## Triggering Need` | Why now, what prompted this story. |
| `## Expected Prerequisites` | Bulleted list of dependency story numbers and titles. |
| `## Scope` | What is in scope. |
| `## Out of Scope` | What is deliberately not in scope. |
| `## Scenarios / Behavior Examples` | Concrete examples that funnel into acceptance. Normative scenarios use exactly one `Covers: A<n>` link; orientation-only scenarios must say `Orientation only`. |
| `## Acceptance` | Observable criteria a reviewer can verify. Every bullet uses a stable `A<n>` id and covers exactly one independently provable behavior. |
| `## Verification` | Reviewer-facing proof contract. Must always contain `### Verification Commands` and `### Acceptance Proof Matrix`, and must add `### Surface / Branch Proof Matrix` and/or `### Fail-open Checks` when the story's risk surface requires them. Rows reference acceptance IDs instead of restating full acceptance prose. |
| `## Discovery Notes` | Source-derived facts that prevent rediscovery: reusable code, gotchas, hidden coupling, test seams, operational constraints, or Debt Friction. Not a transcript. |
| `## Critical Files` | File paths and each path's role. |
| `## Implementation Notes` | Execution brief: source-inspection focus, red-first seam guidance, phases, constraints, and known exceptions. |
| `## Locked Decisions` | What was decided during planning, plus the alternatives considered and rejected. |

`## Actors` and `## Scenarios / Behavior Examples` are part of the modern story shape for new `/epic-story-plan` drafts. Legacy stories remain reviewable when either section is absent; absence alone is not a blocker. When either section is present, every planning and implementation review must validate it for correctness and consistency with the rest of the story.

#### `## Actors`

- Use lightweight role bullets, not personas.
- Include at least one `Primary:` actor when the section is present.
- Add `Secondary:`, `Reviewer:`, `System:`, or external-service roles only when they clarify behavior or review responsibility.
- Actor claims must stay consistent with `## Purpose`, `## Scope`, `## Acceptance`, and `## Verification`.

Example:

```md
## Actors
- Primary: epic operator
- Secondary: implementation agent
- Reviewer: plan-review agent
- System: story planning workflow
```

#### `## Scenarios / Behavior Examples`

Scenarios are a funnel into acceptance, not a parallel requirements list:

```text
Scenario -> Acceptance -> Verification
```

- Use lightweight `S<n>` bullets. Prefer Given/When/Then phrasing when the behavior is procedural.
- Every normative scenario must end with exactly one `Covers: A<n>` link.
- If one example appears to span multiple acceptance ids, split it into multiple scenarios or reshape the acceptance items before review.
- Every orientation-only scenario must explicitly say `Orientation only` and must not create implementation or proof obligations unless the same behavior is also present in `## Acceptance`.
- A scenario that describes required behavior but does not map to acceptance is invalid.
- A linked scenario is review-blocking when its linked acceptance item or verification row does not cover the scenario's concrete behavior.
- Scenarios do not get their own proof matrix. Proof still flows through `## Acceptance` and `## Verification`.

Example:

```md
## Scenarios / Behavior Examples
- S1: Given a legacy story has no `## Actors`, when plan-review runs, then absence alone is not a blocker. Covers: A2.
- S2: Background: older approved stories may predate this template. Orientation only.
```

#### `## Acceptance`

- Every acceptance bullet must start with a stable id: `A1`, `A2`, ...
- Each bullet must be atomic. If two parts could fail independently, split them.
- Every bullet must remain observable by command, file read, or direct reviewer observation.
- `/epic-story-review` uses this list as the source of truth for multipass
  review scope. When `## Acceptance` contains 6 or more concrete top-level
  items, review must run a focused multipass pass plan before approval. Prose,
  examples, nested explanatory bullets, notes, and out-of-scope bullets do not
  count toward the trigger.

Example:

```md
## Acceptance
- A1: `/epic-story-plan` writes a TODO story only after every acceptance id has proof coverage.
- A2: `/epic-story-review` rejects approval when any acceptance id has no proof row.
```

#### `## Verification`

`## Verification` is no longer a loose list of checks. It is the story's
reviewer-facing proof contract. It must always contain these core
subsections:

```md
## Verification

### Verification Commands
- <exact command or exact manual/file-read action>

### Acceptance Proof Matrix
| Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail |
|---|---|---|---|---|---|---|
| A1 | final | file-read | <exact reviewer action> | <exact expected evidence> | <paths / commands / surfaces> | |
| A2 | provisional | automated | <exact reviewer action> | <red/green or equivalent evidence> | <paths / commands / surfaces> | <what is still undecided> |
```

Rules:

- Every acceptance id must appear in the matrix at least once. Missing rows are
  invalid.
- A matrix row may reference multiple acceptance ids only as an exception, and
  only when the same proof action and failure signal genuinely cover all listed
  ids without reducing clarity.
- `Proof Maturity` uses only `final` or `provisional`.
- `Open Detail` may be blank for `final` rows.
- `Open Detail` is required for `provisional` rows and must state what remains
  undecided about the proof path.
- All rows may be `provisional` during planning if they are still anchored to
  the real owning surface and concrete enough to guide implementation.
- By `/epic-story-review`, every row must be `final`.
- Planning is proof-first, not guess-first. The plan must anchor the real
  owning surfaces and the focused test/proof area the implementer should
  inspect first, but it must not invent a fake exact first failing command when
  the repo facts do not support that level of precision.
- Implementation is red-first by default. After source inspection, the
  implementer chooses the smallest focused seam they can make fail, turns it
  green, and only then broadens verification.

Add this subsection whenever the story spans multiple user-visible surfaces,
supported variants/profiles/modes, or internal orchestration branches:

```md
### Surface / Branch Proof Matrix
| Surface | Supported Variant | Internal Execution Branch | Proof Class | Owning Proof Seam | Why This Seam Is Sufficient | Out of Scope Notes |
|---|---|---|---|---|---|---|
| <surface> | <variant / profile / mode> | <branch / callsite / orchestration path> | <helper | routing | behavior> | <test / command / file-read seam> | <why this proves the branch> | |
| <surface> | <variant / profile / mode> | <intentionally excluded branch> | behavior | <n/a or explicit proof seam> | <why exclusion is safe> | <explicit exclusion reason> |
```

Rules for `### Surface / Branch Proof Matrix`:

- Every in-scope surface / variant / internal branch combination must appear at
  least once.
- A row may mark a branch as intentionally excluded only when the exclusion is
  explicit in the story contract.
- `Proof Class` must distinguish `helper`, `routing`, and `behavior` proofs.
- Helper proof alone is insufficient when multiple supported callsites or
  orchestration branches exist. At least one `routing` proof must show that the
  supported callsites actually invoke the shared helper or branch logic.
- The matrix must be specific enough that a reviewer can tell which supported
  branches are covered, and which are intentionally out of scope, from the
  story alone.

Add this proof obligation whenever raw persisted, external, framework, or
generated input crosses into stricter application assumptions such as parsing,
validation, classification, normalization, migration, aggregation, routing,
import/export, or schema construction. Keep the approval proof in the
`Acceptance Proof Matrix`; add the subsection below only when multiple
boundaries, variants, or mitigations would be hard to audit from acceptance rows
alone:

```md
### Input Boundary Shape Risk
| Boundary | Raw Input Source | Strict Assumption | Variant / Case | Evidence | Mitigation / Exclusion |
|---|---|---|---|---|---|
| <adapter / caller / parser> | <db / API / queue / file / event / ORM / request / cache / CLI / import> | <shape assumed by stricter code> | <in-scope variant or explicit exclusion> | <test / probe / schema / contract / canary / reviewer action> | <normalize / reject / fallback / flag / explicit exclusion> |
```

Rules for `### Input Boundary Shape Risk`:

- Every in-scope boundary and shape variant must appear once, or be explicitly
  excluded with a reason. Use product-neutral variant labels from the story's
  actual risk surface rather than copying canned examples.
- Evidence must start at the named raw input boundary. A helper-level proof with
  already-normalized intermediate data is insufficient unless the story
  explicitly narrows the proof row and records why that is safe.
- Acceptable evidence includes automated tests, schema/contract validation,
  read-only data probes, sanitized or synthetic fixtures that preserve the raw
  shape, property/fuzz checks, canary evidence, or exact reviewer actions.
- `unknown` evidence is allowed only when the row records why evidence is
  unavailable, what mitigation reduces release risk, and what follow-up would
  close the gap. Unknown evidence without mitigation is not approval-ready.

Add this subsection whenever the feature depends on prompt placeholders,
template variables, string substitution, or other fail-open prompt assembly:

```md
### Fail-open Checks
- Supported renders leave no unresolved feature placeholders or raw tokens.
- Enabled supported paths prove the feature is active, not silently ignored.
- At least one disabled or default path proves baseline behavior stays intact.
- Any supported profile or mode that intentionally excludes the feature is
  called out explicitly.
```

### Debt Friction

`Debt Friction` is a story-local awareness protocol, not a generic cleanup
backlog. It applies when the current story is made harder or riskier by
codebase debt, such as unclear ownership, duplicated behavior, weak or mocked
tests, missing seams, hidden behavior, or unsafe structure.

Every entry must show this causal link:

```text
current story action -> concrete evidence -> delivery impact -> explicit decision
```

Generic cleanup findings do not qualify unless they affect the current story's
planning, implementation, proof, review, scope, correctness, testability,
reviewability, or safe maintainability.

Write `Debt Friction` in the section owned by the command that found it:

- `/epic-story-plan`: use `## Discovery Notes`; if proof is affected, encode it
  in `## Verification`; if a tradeoff is locked, use `## Locked Decisions`.
- `/epic-story-plan-review`: use `## Plan Review Log`.
- `/epic-story-claim` and `/epic-story-resume`: use `## Progress Log`.
- `/epic-story-review`: use `## Review Log`.

Use this minimum entry shape:

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

- `fix-now` requires `**Scope Justification**`. Use it only for enabling cleanup
  directly required to make the current story correct, testable, reviewable, or
  safely maintainable. It is not permission for broad or opportunistic
  refactoring.
- `split-story` requires `**Follow-up Recommendation**`. Use it for real debt
  that is non-enabling, too large, or too non-local for the current story. Do
  not auto-create the follow-up story from this entry.
- `defer-explicitly` requires `**Deferral Reason**`.
- `block` requires `**Blocker Condition**`.

During planning, a story may be treated as not ready only when debt friction
prevents meaningful acceptance or proof planning. During review, every
`fix-now` entry must be audited against its scope justification and
verification.

Carry unresolved or decision-relevant entries into `## Session Handoff` when the
decision is `split-story`, `defer-explicitly`, `block`, or an unfinished
`fix-now`. Do not carry forward completed `fix-now` or `not-debt` entries.

### Runtime sections (created by `/epic-story-claim`, `/epic-story-resume`, `/epic-story-review`, `/epic-story-pr`)

These are written by the runtime commands as work progresses. They must
**never** be seeded by `/epic-story-plan` — they are owned by the flows
that create them.

#### `## Active Claim`

Written by `/epic-story-claim` (creation) and `/epic-story-resume` (refresh). Exactly
one `Active Claim` section per file.

```md
## Active Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: <Claude or Codex> <fresh|continuation> session
- Scope: <one sentence for this work chunk>
- Worktrees:
  - <repo-basename>: </absolute/path/to/linked/worktree>
  - <repo-basename>: </absolute/path/to/linked/worktree>
- Main-tree targets: <repo-basename>, <repo-basename>
- Primary write surfaces: <paths>
```

The `- Worktrees:` parent bullet is **optional and plural**. It is
present only when the story is being implemented in one or more linked
`git worktrees` — typically because one or more target repos were dirty
at claim time, or because the operator passed
`WORKTREE="<basename>=<path>"` explicitly for that repo. Each child
bullet has the form `- <repo-basename>: <absolute path>` and records
where work for that specific repo is happening so `/epic-story-resume` and
`/epic-story-review` can reattach to the same checkouts in future sessions.

The discovery rule for which repos appear here lives in the
`## Worktree preflight` section of `/epic-story-claim` and `/epic-story-resume`: a
repo is included if it is named in the story's `## Scope` (via a
`projects/<name>/` token) AND has uncommitted changes at claim time.
Repos that are clean at claim time are written to directly and do NOT
appear in this list — their absence implies main-tree mode. When
**no** repos have worktrees (every target was clean, the story has no
target repos, or the operator declined the prompt for every dirty
repo), the entire `- Worktrees:` parent bullet must be omitted. Never
write the parent bullet with no children.

Multi-project workspaces (where `<cwd>` is not itself a git repo but
contains `projects/<name>/.git` sub-repos) are first-class: the
preflight discovers each dirty target sub-repo and creates one worktree
per repo. A story that touches two dirty sub-repos produces two child
bullets, each pointing at a different `<repo-basename>` and worktree
path. Coordination files under `agent_coordination/` always anchor at
`<cwd>` (the workspace root) regardless of any sub-repo worktrees, so
`MASTER.md` and the story file itself never live inside a worktree.

Once written, child bullets must not be deleted by subsequent runs of
`/epic-story-resume` or `/epic-story-review` — other sessions depend on them to
find the worktrees. `/epic-story-resume` may refresh a child bullet's path
if the recorded worktree is stale and the operator chooses to recreate
it at a new location, and may add new children if the operator passes
`WORKTREE="<basename>=<path>"` for a previously-unrecorded repo.

**Back-compat read**: stories claimed before the multi-worktree format
have a singular `- Worktree: <path>` bullet (no parent). `/epic-story-resume`
and `/epic-story-review` accept this legacy form by reading it as a single
implicit entry whose basename is `basename(<path>)`. The next
`/epic-story-resume` refresh on such a story rewrites the legacy bullet as a
`- Worktrees:` list — that is the one place legacy stories migrate
forward. New claims (`/epic-story-claim`) never write the singular form.

#### `## Progress Log`

Append-only timestamped bullets recording meaningful milestones during
implementation. Written by `/epic-story-claim`, `/epic-story-resume`, and `/epic-story-pr`.

```md
## Progress Log
- 2026-04-12T10:32:00Z Claimed step and started implementation.
- 2026-04-12T10:41:00Z Chose `tests/auth/test_refresh.py -k expired_token_rejected` as the focused red seam after source inspection.
- 2026-04-12T11:14:00Z Focused red seam turned green; broadening verification to the surrounding auth suite.
- 2026-04-12T11:48:00Z Patched core module and added tests.
- 2026-04-12T12:01:00Z Moved step to `🔵 IN PR` — https://github.com/.../pull/42
- 2026-04-12T12:09:00Z Refined proof matrix for `A2` after implementation moved the real assertion seam.
- 2026-04-12T12:16:00Z Recorded replanning checkpoint: original acceptance contract for `A3` bundled two independently failing behaviors and was split before implementation continued.
- 2026-04-12T12:21:00Z Recorded explicit red-first exception: fixture bootstrap cannot go red-first safely; using smoke command `uv run pytest tests/bootstrap/test_install.py` as the alternative proof path.
- 2026-04-12T12:27:00Z Recorded Debt Friction: duplicated branch predicate would make `A2` inconsistent without enabling cleanup; decision `fix-now` with scope justification.
```

When implementation discovers contract drift:

- **Non-material proof drift**: update `## Verification` immediately and log
  what changed and why.
- **Material contract drift**: pause normal feature work, record a replanning
  checkpoint in `## Progress Log`, refresh the story contract, then continue.
- **Red-first infeasible**: record an explicit written exception in
  `## Progress Log` before proceeding. Name the reason, the alternative proof
  seam, and the verification path that will be used instead.

When local review finds a mismatch between the implementation and epic-level
commitments in `MASTER.md`, `CONTRACT.md`, dependencies, or relevant sibling
stories, record that explicitly as `Epic contract drift` in `## Review Log`.

#### `## Session Handoff`

Refreshed at the end of every session. There may be multiple handoff
entries over a story's lifetime; only the most recent one is authoritative.

```md
## Session Handoff
- Status: done | blocked | in progress | in review
- What changed: <short bullets>
- Files touched: <paths>
- Red-first path: <focused seam + red/green outcome, or explicit exception + alternative proof path>
- Tests run: <commands/results or not run>
- Remaining work: <short bullets>
- Unresolved Debt Friction: <split-story / defer-explicitly / block / unfinished fix-now entries, or none>
- Blockers / risks: <short bullets>
- Exact next step: <one concrete recommendation>
```

#### `## Review Log`

Append-only entries written by `/epic-story-review`. `/epic-feedback` may also
append this same schema when absorbing PR/CURe feedback that is specifically an
implementation-review finding for one story and should drive immediate
resume/rework. This is the canonical write-back schema for implementation
review logs.

```md
## Review Log
- 2026-04-12T13:05:00Z Review run by fresh maintainer session
  - Decision: approve | request_changes | blocked | not_reviewable
  - Approval gate: pass | fail
  - Product verdict: approve | request_changes | reject | not_assessed
  - Technical verdict: approve | request_changes | reject | not_assessed
  - Multipass review: not_triggered | completed | incomplete
  - Prior review concerns: none | resolved | still_open | superseded | not_assessable
  - Epic contract drift: none | present
  - Status transition: 🟣 IN REVIEW -> ✅ DONE
  - Files reviewed: <paths>
  - Hypothesis triage:
    - suspicious surface: <file/API/flow>; tentative issue: <possible failure>; next proof target: <source/test/proof to check>
  - Key findings:
    - <finding summary> Sources: `<path:line>`

      <details open>
      <summary><b>SEVERITY_LABEL</b> severity · <b>LIKELIHOOD_LABEL</b> likelihood</summary>

      **Why:** <operator-facing reason>

      **Assumptions / Preconditions:** <required conditions, or `None.`>

      **Downgrade Factors:** <confidence/impact reducers, or `None.`>

      **Code Trail:** <grounded path from cited evidence to conclusion>

      **Reproduction:** <brief reproduction narrative, or `Not applicable.`>

      </details>
  - Debt Friction: none | <decision + short title>
  - Next action: <one concrete recommendation>
```

`/epic-story-review` records compact hypothesis triage for inspected candidate
issue threads and uses detailed finding cards for concrete issues in both the
final review output and `## Review Log`. Finding summaries must carry
`Sources: path:line`; the expanded card explains why the issue matters,
assumptions, downgrade factors, code trail, and reproduction when applicable.
When a story already has review-log findings, the next review records whether
those concerns are resolved, still open, superseded, or not assessable from the
current evidence before approving.

#### `## Plan Review Log`

Append-only entries written by `/epic-story-plan-review`, and by
`/epic-feedback` only when routing planning feedback into the established
plan-resume cycle. Parallel in shape to `## Review Log` but records
plan-quality verdicts at any implementation lifecycle point. Never seeded by
`/epic-story-plan`. Each re-run of `/epic-story-plan-review` after operator
edits appends a new entry — the log is the story's plan revision history.

```md
## Plan Review Log
- 2026-04-15T09:30:00Z Plan review run by fresh maintainer session
  - Verdict: approve | request_changes | blocked | not_reviewable
  - Plan lane transition: 🟡 PLAN DRAFT -> 🟢 PLAN APPROVED
  - Status transition: ⚪ TODO -> ⚪ TODO
  - Sections reviewed: Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, Discovery Notes
  - Original intent checked: <issues/PRs/Jira/tickets/epic sources or none found/inaccessible>
  - Traceability: forward <complete|gaps>; backward <complete|gaps>
  - Code surfaces searched: <paths/patterns/entrypoints or none beyond Critical Files>
  - Evidence quality: confirmed <short>; inferred <short|none>; unknown <short|none>; provisional <short|none>
  - Key findings:
    - <short bullet>
  - Hypothesis triage: none | <material suspicious surface + proof target summary>
  - Debt Friction: none | <decision + short title>
  - Next action: <one concrete recommendation — typically "/epic-story-claim <epic>" or "edit <sections> and re-run">
```

The traceability fields above are part of the `/epic-story-plan-review` entry
schema. They make review evidence durable: which original intent sources were
checked, whether forward/backward traceability is complete, which code surfaces
were searched, and what evidence remains inferred, unknown, or provisional.
Planning feedback entries routed by `/epic-feedback` may use their feedback
receipt shape, but independent plan-review verdicts should include the full
traceability shape.

#### `## Feedback Absorption Log` (story-local receipt)

Optional tiny receipt written by `/epic-feedback` when it edits the story body.
The epic-level `MASTER.md` log is canonical; the story-local receipt only helps
future readers understand why nearby story sections changed.

```md
## Feedback Absorption Log
- FB-001: amended `Acceptance` and `Verification` from PR #42 review comment. See epic log.
```

#### `## PR Tracking`

Written by `/epic-story-pr` only. There is exactly one `PR Tracking` section per
file; refreshing the metadata updates the existing section in place.

```md
## PR Tracking
- PR URL: https://github.com/<org>/<repo>/pull/<n>
- Number: <n>
- Title: <pr title>
- Branch: <head ref>
- Opened at: 2026-04-12T12:01:00Z
- PR status: open | changes_requested | approved | merged | closed
- Merge commit: <sha or "—">
- Last synced: 2026-04-12T13:42:00Z
```

### Epic runtime sections

These sections live in `MASTER.md`, not individual story files.

#### `## Epic PR Tracking`

Written by `/epic-pr` only. There is exactly one `Epic PR Tracking` section per
epic; refreshing the metadata updates the existing section in place. This is
epic-level PR metadata and must not be confused with story-level `## PR Tracking`.

```md
## Epic PR Tracking
- PR URL: https://github.com/<org>/<repo>/pull/<n>
- Number: <n>
- Title: <pr title>
- Branch: <head ref>
- Opened at: 2026-04-28T12:01:00Z
- PR status: open | changes_requested | approved | merged | closed
- Merge commit: <sha or "—">
- Last synced: 2026-04-28T13:42:00Z
- Included contract: CONTRACT.md | none
- Included DONE stories: <story numbers or "none">
- Original tickets:
  - <optional label>: <url>
```

`/epic-pr` uses `CONTRACT.md` for already-squashed or archived scope and never
reads archived story files directly. It may read non-archived `✅ DONE` stories
as current completed scope that has not yet been squashed. It never transitions
story statuses and never writes story-level `## PR Tracking`.

Original ticket/card context in PR bodies is link-only. `/epic-story-pr` and
`/epic-pr` may include detected links near the top of the generated PR body,
but they must never summarize or quote ticket text. If labels can be fetched or
strictly inferred from local link text, include them; otherwise include only the
link.

## `CONTRACT.md`

The merged, authoritative contract for the epic. Created and maintained by
`/epic-squash`. When `CONTRACT.md` and a story disagree, `CONTRACT.md`
wins (it has been verified against the codebase). When `CONTRACT.md` and
the codebase disagree, the **codebase** wins — the contract is wrong and
`/epic-squash` should be re-run to fix it.

### Required sections

1. **Header** — epic title, story count, consolidation date.
2. **Domain sections** — one section per coherent product domain (e.g.
   "Configuration Surface", "Runtime Architecture", "Lifecycle"). Grouped
   by domain, not by story number.
3. **Appendix A: Resolved Contradictions** — append-only entries recording
   contradictions resolved during a squash.
4. **Appendix B: Resolved Gaps** — append-only entries recording gaps
   resolved during a squash.
5. **Appendix C: Discrepancies Resolved During Consolidation** —
   append-only entries recording code-level discrepancies found and
   (optionally) fixed during a squash.

`/epic-squash` never renumbers existing appendix entries; it only appends.

## `archive/`

Created by `/epic-squash` on first use (bootstrap mode). Contains the
original story files of every story that has been folded into
`CONTRACT.md`. The `MASTER.md` tracker links for those rows are updated
to point into `archive/` so the trail back to the original story prose is
preserved.

## Argument resolution rules

Each command in this repo has a defined resolution strategy for its
epic/story arguments. Three strategies exist:

- **Auto-inferred from running context** — for commands that continue
  running work (`/epic-story-claim`, `/epic-story-resume`, `/epic-story-pr`, `/epic-pr`, `/epic-squash`).
  These operate on whatever is already active; guessing the context is
  the whole point.
- **Operator-explicit (arg or menu)** — for commands that *create*, *review*,
  or route feedback (`/epic-plan`, `/epic-story-plan`, `/epic-story-review`,
  `/epic-story-plan-review`, `/epic-feedback`). These never auto-infer. The
  operator must make the decision — either by passing the arg or by
  picking from a filtered menu the skill shows when the arg is absent.
  The menu lists only legal candidates (filtered to each command's
  eligible-status set) and asks the operator to pick. Nothing is ever
  selected silently.
- **Operator-explicit looper** — for orchestration commands that repeatedly
  launch fresh lifecycle sessions for one operator-selected story
  (`/epic-story-plan-converge`, `/epic-story-converge`). These never silently
  infer the target story and never own status transitions themselves.

| Command | Resolution strategy | Eligible-status filter | Notes |
|---|---|---|---|
| `/epic-plan` | operator-explicit (optional NAME arg) | n/a — creates a new epic | If `NAME` is omitted, the interview asks for the slug. Never overwrites an existing epic. |
| `/epic-story-plan` | operator-explicit (arg or menu) | any epic with a `MASTER.md` | EPIC menu lists all epics under `agent_coordination/epics/`. Creates one `🟡 PLAN DRAFT` / `⚪ TODO` story after checkpoint confirmation. |
| `/epic-story-review` | operator-explicit (arg or menu) | `🟣 IN REVIEW` with `🟢 PLAN APPROVED` | Review must come from a fresh, independent perspective. The menu lists only stories at `🟣 IN REVIEW`. |
| `/epic-story-plan-review` | operator-explicit (arg or menu) | any non-DONE story contract | Plan review must come from a fresh, independent perspective. It can run as pre-implementation review or implementation-cycle contract review. |
| `/epic-story-plan-resume` | operator-explicit (required epic + story) | non-DONE stories whose `Plan` needs contract repair | Edits story planning sections and may set `Plan` to `🟡 PLAN DRAFT` after repair. Never changes implementation status or approves the plan. |
| `/epic-story-plan-converge` | operator-explicit looper (required epic + story) | non-DONE stories whose `Plan` is not approved, plus explicit re-review targets | Loops fresh plan-review and plan-resume sessions. Accepts optional `MAX_CYCLES`; rejects `WORKTREE`. Delegates all writes to the underlying commands. |
| `/epic-story-converge` | operator-explicit looper (required epic + story) | `🟢 PLAN APPROVED` plus `⚪ TODO`, `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `🔵 IN PR (changes_requested)`, or immediate-stop `✅ DONE` | Loops fresh claim/resume/review sessions. Accepts optional `MAX_CYCLES` and pass-through `WORKTREE`. Delegates all writes to the underlying commands. |
| `/epic-feedback` | operator-explicit (arg or menu) | any epic with `MASTER.md` | Epic-scoped feedback routing. PR mode can select the latest unabsorbed PR comment, review body, or inline review comment. Never transitions implementation statuses; may downgrade or invalidate `Plan` and never approves it. |
| `/epic-story-claim` | auto-inferred (running context), or explicit story selector | `🟢 PLAN APPROVED` + `⚪ TODO` | Standard "single active epic + first ready unclaimed story" inference when no selector is passed. An explicit story selector targets exactly that ready unclaimed row and never falls back to another row. |
| `/epic-story-resume` | auto-inferred (running context) | `🟢 PLAN APPROVED` + `🔄 IN PROGRESS`, `🔵 IN PR (changes_requested)` | Standard. |
| `/epic-story-pr` | auto-inferred (running context); explicit story required for DONE injection | `🟣 IN REVIEW`, `🔵 IN PR`, explicit non-archived `✅ DONE` | Also infers PR URL via the chain: existing `## PR Tracking` section → `gh pr list --head <current branch>` → fall through to `OPEN` mode. For explicit `✅ DONE` stories, `OPEN=true` is implicit after existing PR detection fails. |
| `/epic-pr` | auto-inferred (running context) | epic has `CONTRACT.md` and/or non-archived `✅ DONE` stories | Opens or refreshes an epic-level PR from `CONTRACT.md` plus current DONE stories. Blocks on misleading gaps/conflicts, never reads archived stories directly, and never changes story statuses. |
| `/epic-squash` | auto-inferred (running context) | `✅ DONE` | The "story" axis doesn't apply — the command consumes every done story in one pass. |

**Rules for the "auto-inferred" rows**:

1. **Active epic**: an epic is active if its `MASTER.md` tracker has at
   least one row whose status is not `✅ DONE` and whose `Spec` link does
   not point into `archive/`. Exactly one active epic → infer it. Zero
   or many → abort with a specific message.
2. **Eligible story**: only rows whose status is in the per-command
   eligible-status filter qualify. Exactly one eligible row → infer it.
   Zero or many → abort with a specific message that names the next
   concrete action (e.g. "story X is in progress; run `/epic-story-review` first").
   `/epic-story-pr` never silently infers a `✅ DONE` row; late PR injection
   from local DONE requires the story to be explicit and non-archived.
3. **Explicit args always win**: passing `EPIC=...` / `STORY=...` (Codex)
   or the equivalent positional args (Claude) skips the corresponding
   inference pass entirely. Inference can never override explicit values.
4. **Inference summary**: every command that runs inference must print a
   single resolved-context block before any destructive step, so the
   operator can verify what was inferred.

**Rules for the "operator-explicit (arg or menu)" rows**:

1. **Arg takes priority**: if the operator passes the arg, use it
   directly (after validating it resolves to something real).
2. **Menu fallback**: if the arg is missing, the skill lists the legal
   candidates filtered by the command's eligible-status column, formats
   each row with a short summary (step / deliverable / status / last-
   touched), and asks the operator to pick by number or slug.
3. **Zero-row abort**: if the filtered menu is empty, abort fast with a
   pointer to the next concrete action (e.g. "no epics found; run
   `/epic-plan` to bootstrap one first", "no stories at ⚪ TODO; run
   `/epic-story-plan` to create one").
4. **Never silent**: the menu never pre-selects a row the operator
   hasn't confirmed, even if there is only one eligible candidate.
   Picking is always an explicit operator action. Auto-inference for
   these commands must continue to be rejected — the menu pattern
   replaces typing friction with menu friction, it does not replace
   operator-explicit choice with silent guessing.

**Rules for the "operator-explicit looper" rows**:

1. **Target is always explicit**: pass both epic and story. Loopers do not use
   menu fallback or single-row auto-selection because they may launch several
   fresh sessions.
2. **Delegated writes only**: loopers may choose the next lifecycle command,
   but any write must come from that command's normal authority window.
3. **Neutral memory plus sourced research only**: loopers may pass later fresh
   sessions operational notes about blockers, hotspots, repeated command
   failures, or expensive operations. They may also keep a session-only
   Research Board whose entries all have exact source anchors such as
   `path:line`, symbols, command/output excerpts, or tool/query/path.
   Research Board facts are orientation only and must be verified against live
   source before editing or approving. The looper owns keeping the board
   relevant to later passes; executor agents only decide whether the needed
   fact is present in the provided board. When it is present, they verify it
   with direct reads/search against the cited anchors instead of rerunning
   expensive research. If direct verification shows a provided entry no longer
   supports its claim, the executor reports a board-refresh signal with the
   entry id and live-source anchors; the looper decides whether to update,
   replace, retire, or ask about that board entry. Loopers pass the full board
   to fresh lifecycle sessions and must ask the operator before compacting or
   excluding entries. Loopers must not pass persuasive verdict framing such as
   "the prior reviewer was wrong" or "approval is expected".
4. **Research Events return path**: lifecycle skills launched by a converger
   must return `Research Events` with reused board entries, newly sourced
   research, board-refresh signals, or `- None.` when no research was used or
   produced. Reused entries should name the board entry and the
   direct-read/search anchors used to verify it. Board-refresh signals should
   name the board entry or absent needed fact, describe the verification miss,
   and cite the direct-read/search anchors proving the miss or replacement fact.
   Newly sourced research and board-refresh signals require exact anchors.
5. **Final reports are not thinking logs**: loopers must return only their
   required report sections. They must not include `Thinking:` blocks, private
   deliberation, or comments about tentative next actions outside the structured
   `Next Action` and `Operator Nice-To-Haves` sections.

## What the commands will NOT do

- Rename or renumber existing stories
- Delete `Progress Log`, `Active Claim`, `Session Handoff`, `Review Log`,
  `Plan Review Log`, or `Feedback Absorption Log` entries
- Touch product code from `/epic-story-pr` or `/epic-squash` (except optional
  per-fix approval in `/epic-squash` Phase 6, and the optional `gh pr
  create` call in `/epic-story-pr` or `/epic-pr` open mode)
- Mark a story `✅ DONE` while its PR is open
- Leave a local-DONE story as `✅ DONE` after `/epic-story-pr` successfully
  opens or attaches an unmerged PR
- Read archived story files from `/epic-pr`; archived scope is represented by
  `CONTRACT.md`
- Transition story statuses from `/epic-pr`
- Transition implementation statuses from `/epic-feedback`, or set `Plan` to
  `🟢 PLAN APPROVED` from `/epic-feedback`
- Directly write coordination files, source files, tests, or commits from
  `/epic-story-plan-converge` or `/epic-story-converge`; loopers keep only
  in-memory babysitting notes and session Research Board entries, then delegate
  writes to underlying lifecycle skills
- Create full story files from `/epic-feedback`; feedback-derived future work
  must remain a candidate until `/epic-story-plan` turns it into a story
- Archive a `🔵 IN PR` story
- Auto-infer arguments for any command in the "operator-explicit (arg or
  menu)" rows of the Argument resolution rules table. The menu pattern
  replaces the old "required explicit" friction but preserves the rule
  that the operator — not the skill — is the one making the choice.
- Overwrite an existing `MASTER.md` from `/epic-plan`. The epic directory
  must not already exist; collisions abort fast.
- Create a story from `/epic-story-plan` without an explicit checkpoint
  previewing the story file and tracker row.
- Delete or silently relocate an existing linked worktree from
  `/epic-story-claim`, `/epic-story-resume`, or `/epic-story-review`. The `- Worktrees:`
  list in `## Active Claim` (or the legacy singular `- Worktree:`
  bullet for back-compat) is the authoritative record of where the
  story's implementation lives. The only command that may change a
  recorded entry is `/epic-story-resume`, and only when the operator
  explicitly chooses to recreate a stale worktree at a new location.
  `/epic-story-review` may **never** create a worktree — it only reuses
  what the implementer recorded or a `WORKTREE="<basename>=<path>"`
  override. On partial worktree creation failure (one repo's worktree
  succeeds and another fails), no command auto-cleans the successful
  worktrees; the operator decides whether to keep them.
- Create a worktree branch `<epic>/<story-slug>` that already exists
  from `/epic-story-claim`. If the branch is present in any target repo,
  `/epic-story-claim` aborts fast and redirects the operator to
  `/epic-story-resume`.
