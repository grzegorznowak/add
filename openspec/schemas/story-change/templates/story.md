# Story <XX> — <Slug>

Plan: 🟡 PLAN DRAFT
Status: ⚪ TODO
Review Focus: |
Initiative: <initiative-slug>

<!-- Plan, Status, Review Focus, and Initiative are top-level header fields, not `##` sections.
     Every present Initiative header must occur exactly once. It is required for
     every newly planned story and binds this change workspace to one initiative.
     Legacy absence means zero Initiative or Initiative-like lines in the
     top-level header region. Any malformed present Initiative-like field,
     including whitespace-before-colon or an empty/non-canonical value, is a
     hard conflict; duplicates also halt; routing never backfills the field.
     `/openspec-story-plan-resume` repairs planning/scaffold content.
     `/openspec-story-claim` and `/openspec-story-resume` write authorized
     implementation Status transitions and exclusively overwrite Review Focus
     on every handoff to IN REVIEW, including with a blank block. The literal
     `Review Focus: |` field occurs exactly once; its content is only immediately following indented
     lines and the next top-level header terminates it. No indented non-whitespace
     content is blank. Nonblank guidance is capped at 1,000 whitespace-delimited
     units; malformed, duplicate, conflicting, or over-budget forms fail closed.
     Review Focus is inert outside IN REVIEW. Ordinary `/openspec-feedback` may
     reopen Status after acknowledgement; confirmed review-packet triage may
     publish its bounded IN PROGRESS, DONE, or BLOCKED outcome Status last after
     all canonical postconditions. Immediately before DONE, feedback launches
     one isolated fresh replay over current implementation evidence with the
     same readonly evaluator semantics. The result must be semantically
     equivalent to the submitted packet; mismatch or drift is rejected, must
     not publish DONE, and persists no packet receipt, digest, identity, or
     history. The readonly implementation evaluator only
     reads this artifact and emits a transient packet; it never writes Status,
     receipts, blockers, or timelines. -->

> Story scaffolded by `/openspec-story-plan` after interactive planning.

## Purpose
<!-- One paragraph: what user-visible outcome this story delivers. -->

## Actors
<!-- Role-based participants. At least one Primary: actor when this section is present. -->
- Primary:
- Secondary:
- Reviewer:
- System:

## Triggering Need
<!-- Why now, what prompted this story. -->

## Expected Prerequisites
<!-- Bulleted dependency story slugs. A bound or accepted legacy prerequisite
     requires exact DONE Status, no blocked.md, valid path/binding resolution,
     and all required current task/proof checks. Receipt presence or absence
     does not qualify or disqualify a prerequisite. Legacy receipt shape,
     verdict, identity, duplication, and staleness are inert; never synthesize
     or normalize receipt material. -->

## Scope
<!-- What is in scope. -->

## Out of Scope
<!-- What is deliberately not in scope. -->

## Scenarios / Behavior Examples
<!-- Lightweight S<n> bullets funneling into acceptance. Every normative scenario
     must end with exactly one `Covers: A<n>`. Orientation-only scenarios must
     explicitly say `Orientation only`. -->

## Acceptance
<!-- This exact heading is canonical; do not rename it `## Acceptance Criteria`.
     Observable criteria a reviewer can verify. Every bullet uses a stable A<n>
     id and covers exactly one independently provable behavior. -->

## Verification

### Verification Commands
<!-- Exact commands or manual/file-read actions a reviewer runs. -->

### Test Architecture Plan
| Row ID | Layer / Scope | Behavior / Acceptance Slice | Owning Suite / File(s) | Boundary Exercised | Assertions / Observability | Fixture / Test Data Strategy | CI Lane / Command | Fallback Plan | Split / Merge Rationale |
|---|---|---|---|---|---|---|---|---|---|
| TAP-1 | | | | | | | | | |

### Acceptance Proof Matrix
| Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail |
|---|---|---|---|---|---|---|
| | | | | | | |

<!-- Conditional subsections — add only when the story's risk surface requires them: -->

<!-- ### Surface / Branch Proof Matrix -->
<!-- ### Design Sources -->
<!-- ### Design Element Trace -->
<!-- ### Input Boundary Shape Risk -->
<!-- ### Fail-open Checks -->
<!-- ### Risk Lens Inventory -->

## Discovery Notes
<!-- Source-derived facts that prevent rediscovery: reusable code, gotchas,
     hidden coupling, test seams, operational constraints, or Debt Friction.
     Not a transcript. -->

## Critical Files
<!-- File paths and each path's role, or search patterns. -->

## Implementation Notes
<!-- Execution brief: source-inspection focus, red-first seam guidance,
     phases, constraints, and known exceptions. -->

## Locked Decisions
<!-- What was decided during planning, plus alternatives considered and rejected. -->

## Plan Review Log
<!-- Append-only planning review entries written by `/openspec-story-plan-review`, `/openspec-feedback`;
     addressed-entry repairs are written by `/openspec-story-plan-resume`.
     Initial planning seeds only this empty anchor. -->
