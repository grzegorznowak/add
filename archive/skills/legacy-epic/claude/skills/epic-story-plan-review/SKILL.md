---
name: epic-story-plan-review
description: Review a story's planning contract at any lifecycle point — validate Purpose / Actors / Scenarios / Acceptance / Verification / Critical Files / Locked Decisions against original intent, the live repo, and traceability gaps, then record a Plan Review verdict in the Plan lane.
disable-model-invocation: true
argument-hint: "<epic-name> <story-number-or-spec-file>"
allowed-tools: Read Edit Grep Glob Bash(git status:*) Bash(git log:*) Bash(git show:*) Bash(gh issue view:*) Bash(gh pr view:*) Bash(jira issue view:*)
---

# Epic Story Plan Review

Review one story's **planning contract** against the live repository at any lifecycle point. This is the planning-side analog of `/epic-story-review`: read-only for code, read-only for the story's spec sections, and writes only to a new `## Plan Review Log` entry on the story file plus the `Plan` lane in `MASTER.md`. The highest-leverage part of this review is the acceptance/proof contract: atomic acceptance ids plus a reviewer-facing proof matrix that is credible enough to drive red-first implementation without drifting into fake seams.

Argument: `$ARGUMENTS` — `<epic_name> <story_number_or_spec_file>`. Both are recommended; if either is omitted, this command uses the explicit menu fallback in `## Resolution`.

## Important

This command only edits the resolved story file's `## Plan Review Log` section and the matched row's `Plan` lane in `MASTER.md` when that column exists. It **never** touches:

- source code (product files, tests, configs)
- the files listed in the story's `## Critical Files`
- any spec section of the story file (`## Purpose`, `## Actors`, `## Triggering Need`, `## Expected Prerequisites`, `## Scope`, `## Out of Scope`, `## Scenarios / Behavior Examples`, `## Acceptance`, `## Verification`, `## Discovery Notes`, `## Critical Files`, `## Implementation Notes`, `## Locked Decisions`)
- any runtime section (`## Active Claim`, `## Progress Log`, `## Session Handoff`, `## Review Log`, `## PR Tracking`)
- the implementation `Status` lane (`⚪ TODO`, `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `🔵 IN PR`, `✅ DONE`, `⛔ BLOCKED`)

If you find the plan is wrong, say so in the log's `Key findings` and recommend the operator edit the spec sections themselves. Do not rewrite the plan inside the log.

## Why operator-explicit (arg or menu) selection

`/epic-story-plan-review` never auto-infers the epic or the story. The operator explicitly chooses — either by passing `<epic> <story>` as arguments or by picking from the menu this skill shows when either is absent. The menu is **not** inference: it lists legal candidates and asks the operator to pick.

The reasoning: plan review must come from a fresh, independent perspective. The same session that just wrote the plan will rationalize it, not scrutinize it — it will read every section as evidence for the conclusions it already reached during planning. Auto-inferring "the current story" would silently pick whatever the session was last planning — exactly the coupling we want to avoid.

A gentle nudge: if you find yourself picking from the menu in the same session that wrote the plan, consider opening a fresh session for the review. The menu still makes it possible to run plan review from the planning session, but the friction is intentional and any future change that adds silent auto-inference here must be rejected.

## Resolution

1. Parse `$ARGUMENTS` as `<epic> <story>` (both optional).
2. **EPIC resolution (menu fallback):**
   - If `<epic>` was passed, resolve `<cwd>/agent_coordination/epics/<epic>`.
   - If `<epic>` was not passed, list every directory under `<cwd>/agent_coordination/epics/` whose `MASTER.md` has at least one non-archived row whose planning lane is not `🟢 PLAN APPROVED`, plus any legacy row at `⚪ TODO`. For each, print: `<slug> — <N stories needing plan review, last-touched YYYY-MM-DD>`. If the filtered list is empty, abort with: `no epics have stories needing plan review; pass an explicit epic and story to re-review an approved plan`. Otherwise ask the operator to pick (number or slug).
3. **STORY resolution (menu fallback):**
   - If `<story>` was passed, continue to resolution step 4.
   - If `<story>` was not passed, list every row in `<epic>/MASTER.md` whose planning lane is not `🟢 PLAN APPROVED`, plus any legacy row at `⚪ TODO`. For each, print: `<Step> — <Plan> — <Status> — <Deliverable>`. If the filtered list is empty, abort with: `no stories needing plan review in <epic>; pass a story explicitly to re-review an approved plan`. Otherwise ask the operator to pick (number or slug).
4. Use `<epic>/MASTER.md` as the only lookup table.
5. First try to match exactly one row whose `Step` value equals `<story>`.
6. If no row matches by `Step`, try to match exactly one row whose `Spec` value equals `<story>`.
7. If neither lookup finds a row, abort fast and report the unresolved selector plus the available `Step` and `Spec` values from `MASTER.md`.
8. If the `Step` lookup and `Spec` lookup both match but point to different rows, abort fast and report the ambiguity.
9. Resolve the story file as `<epic>/<matched row Spec value>`.
10. If that path does not exist, abort fast and report the exact missing path.

## Read first

1. the main repo `AGENTS.md` for the repo the plan will touch
2. `<epic>/MASTER.md`
3. `<epic>/CONTRACT.md` if present
4. the resolved story file
5. original intent artifacts explicitly linked or keyed from `MASTER.md`, the story file, dependency stories, branch names, commit messages, or existing PR text: GitHub issues, GitHub PRs, Jira tickets, or stable ticket/card ids
6. design sources explicitly listed in `## Verification` (`### Design Sources`) when present; inspect only durable/reviewable anchors and treat orientation-only sources as context
7. dependency story files listed for the resolved row in `MASTER.md` and in the story's `## Expected Prerequisites`
8. materially relevant sibling stories when they define the same shared interface, proof surface, actor flow, or locked decision

## Plan readiness check

Before doing the full plan review, abort fast with a concise reason if any of these hold:

- the matched row is archived or the implementation `Status` is `✅ DONE` — say "completed stories are not contract-reviewed in place; route new feedback through `/epic-feedback` as a candidate or explicit reopen decision"
- the story file has no scaffold marker for `/epic-story-plan` — say "story was not scaffolded by `/epic-story-plan`; plan review assumes that shape"
- the story file is missing `## Purpose`, `## Acceptance`, or `## Verification` — say which section is missing

Legacy compatibility: if `## Actors` and/or `## Scenarios / Behavior Examples` are fully absent, do not fail solely for that absence. If either section is present, review it for correctness and consistency with the full plan.

Resolve the planning lane before review:

- If `MASTER.md` has a `Plan` column, use that value as the planning-lane authority.
- If `MASTER.md` has no `Plan` column, infer legacy planning state from the newest effective `## Plan Review Log` entry: `approve` -> `🟢 PLAN APPROVED`; unresolved `request_changes` or `not_reviewable` -> `🟠 PLAN CHANGES REQUESTED`; `blocked` -> `⛔ PLAN BLOCKED`; no entry -> `🟡 PLAN DRAFT`.
- If runtime sections exist, enter **contract-review mode**. In this mode, validate only the story contract and proof plan; do not assess implementation completeness, do not read `## Progress Log` as proof that the contract is correct, and do not change implementation `Status`.
- If runtime sections do not exist, enter normal pre-implementation plan-review mode.

When `MASTER.md` has a `Plan` column, remember the pre-review `Plan` value, then set the matched row to `🟣 PLAN IN REVIEW` before the full review begins. The final verdict in this command must overwrite it with `🟢 PLAN APPROVED`, `🟠 PLAN CHANGES REQUESTED`, `⛔ PLAN BLOCKED`, or the remembered pre-review value for an unrecoverable `not_reviewable` verdict unless the command aborts before write-back.

## Source-of-truth hierarchy

1. the main repo `AGENTS.md`
2. `<epic>/MASTER.md` for story identity, tracker state, and dependency rows
3. actual code and tests for already-implemented behavior, including but not limited to the files referenced by the story's `## Critical Files` (read-only probes only)
4. `<epic>/CONTRACT.md` if present, for merged authoritative epic product contract
5. original issue/ticket/PR intent and acceptance criteria, when explicitly linkable and not superseded by `CONTRACT.md` or code
6. durable design sources explicitly listed as `normative` in the resolved story's `### Design Sources`; orientation-only design sources are context only
7. the resolved story file
8. dependency story files and materially relevant sibling stories

`CONTRACT.md` is authoritative for already-squashed epic scope. If original ticket/PR/Jira intent conflicts with `CONTRACT.md`, do not silently prefer the ticket; the plan is not approvable unless it records an explicit reopen, scope-deviation, or contract-staleness decision. If `CONTRACT.md` conflicts with the live codebase, the codebase wins and the finding should say the contract is stale and `/epic-squash` or equivalent contract repair is needed. Never invent linkage: if ticket/PR/Jira evidence is absent, inaccessible, weak, or contradictory, say so explicitly and review against the remaining epic/story sources.

Do not infer identity from filename shape or naming conventions that are not explicitly recorded in `MASTER.md`.

## Shared Research Board Input

When launched by a converger, you may receive `Shared Research Board from parent orchestration session` before the slash command. This is the only allowed cross-session context beyond neutral operational notes. Use it as sourced orientation only. The converger owns keeping it relevant; you only decide whether the needed fact is present in the provided board. If present, verify it with direct reads/search against the cited anchors before it affects a finding, approval, or write-back instead of rerunning expensive research. If a provided entry does not verify, report a board-refresh signal with exact anchors; do not decide how to curate the board. If absent, follow this skill's normal research rules. Ignore any board item that lacks an exact source anchor such as `path:line`, symbol, command/output excerpt, or tool/query/path.

## Plan review process

You are the reviewer-of-record and orchestration layer: you resolve the story, decide source-of-truth conflicts, own the final verdict, write the Plan Review Log, and perform any Plan lane transition. Do not outsource final judgment. When useful, split your own read/search work into focused evidence probes: original intent/ticket archaeology, broad codebase owner discovery beyond `## Critical Files`, dependency/sibling/`CONTRACT.md` drift checks, verification/proof-surface audits, and traceability or hypothesis probes. Evidence must cite inspected anchors before it supports findings, evidence gaps, or approval. Do not assume unavailable delegation tools; runtime-specific child-agent guidance belongs in runtime-specific fragments.

1. Read every spec section of the story file. Treat each one as a claim that must hold against `CONTRACT.md` when present, original intent, sibling contracts, and the live repo.
2. Build an **intent and traceability map** before approving anything:
   - forward trace: `CONTRACT.md`/original issue/ticket/epic intent -> Purpose/Scope/Scenarios/Acceptance -> Verification proof rows -> owning code/test surfaces
   - backward trace: every planned code/test surface, helper, command, and proof row -> Acceptance id -> story scope -> `CONTRACT.md`/original issue/ticket/epic intent or explicit in-story rationale
   - design trace when applicable: normative design source anchor -> visible element/state -> `required` or bounded `flexible` trace row -> Scenario -> Acceptance -> Verification -> rendered proof action
   Missing links are not automatically blockers when no original ticket exists, but unmapped normative design elements are blockers and must be visible in findings.
3. Mine original intent aggressively but only from explicit anchors: ticket/PR URLs, Jira keys, issue numbers, branch names, commit messages, `MASTER.md`, dependency stories, PR bodies, or story prose. Use `gh issue view`, `gh pr view`, `jira issue view`, `git log`, and `git show` when available and relevant. If an external source cannot be accessed, record the exact missing source and do not invent its content. If external intent conflicts with `CONTRACT.md`, treat that as a contract conflict requiring an explicit decision rather than as a reason to override the contract.
4. Use `Read`, `Grep`, and `Glob` to probe the repository beyond `## Critical Files` — confirm paths resolve, search for 2–4 domain terms, inspect existing tests, public APIs, similar helpers, deprecated duplicate owners, routing/callsite surfaces, and sibling story contracts. Confirm the domain the plan covers does not already have reusable implementations the plan missed, and confirm `## Locked Decisions` do not contradict `AGENTS.md`, `CONTRACT.md`, ticket intent, or established patterns.
5. Treat `## Scenarios / Behavior Examples`, `## Verification`, and `## Implementation Notes` as the behavior-funnel, proof-design, and implementation-method contract, not as proof that the implementation already exists. Do not run the planned tests expecting them to pass at this phase. Instead, validate whether scenarios funnel into acceptance, whether commands, seams, owning surfaces, branch decomposition, design traces, routing proofs, and fail-open checks are concrete, plausible, aimed at the real acceptance behavior rather than a mocked caricature of it, and specific enough to support red-first implementation after source inspection.
6. Use `git status` to confirm the worktree is not mid-implementation (if there are large pending changes, note it — plan review on a dirty worktree is a warning signal).
7. Use `git log` and, when useful, `git show` to skim recent related history for code movement, prior fixes, reverted approaches, hidden tests, or ticket references the plan should have referenced but did not.
8. Run adversarial lenses explicitly: requirements completeness, UI/design-source extraction, code-owner discovery, negative-space/missing cases, variant and branch coverage, activated risk lenses, behavior-vs-mechanics proof quality, rendered-surface proof quality, fail-open/default behavior, data-shape boundaries, migration/config/runtime impact, backward traceability, and alternatives to each major locked decision.
9. Never speculate about code, tests, tickets, or PRs you haven't read. If a claim in the plan can be checked, check it. If it cannot be checked, classify it as confirmed, inferred, unknown, or provisional.
10. Run a risk-lens plan check: identify which domain risks the story activates (for example async/event-loop, concurrency, platform/OS APIs, external I/O, permissions/security, persistence, resource lifecycle, retries/timeouts, generated artifacts, or naming-sensitive invariants) and verify the plan either proves each activated risk at the owning boundary or explicitly excludes it with rationale.
11. Run a Debt Friction check: ask whether the plan hides story-local friction from unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure. Only record a `Debt Friction` finding when there is a causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.
12. If the plan looks structurally wrong, verdict is `request_changes` with a pointer to which sections to edit. Do not rewrite the plan inside the log.
13. Walk the full validation checklist below before settling on a verdict.

## Hypothesis triage and evidence grounding

Before final verdict, write a short private triage list and then carry only material items into findings or evidence gaps:

```md
- suspicious surface: <file/API/flow/ticket/plan section>; tentative issue: <possible plan failure>; next proof target: <source/ticket/test/code to check>
```

Every concrete finding must cite at least one inspected anchor: story section, ticket/PR/Jira anchor, `path:line` when available, command output excerpt, or exact missing source. Separate confirmed requirements from reviewer inference. A plan can be approved with known unknowns only when each unknown is explicitly bounded, does not undermine acceptance/proof, and has a follow-up path.

## Critical checks

Before approving, walk the grouped gate below. Treat blocker bullets as `request_changes` unless they are explicitly scoped out with safe rationale; warnings must still be named in the Plan Review Log when material.

### 1. Core planning contract

Blockers:
- `Purpose` is not concrete and user-visible, or `Triggering Need` lacks a real pain/source.
- `Scope` is not atomic, reads like multiple independent stories, or pulls in work not justified by the story.
- `Acceptance` bullets are missing stable `A<n>` ids, are vague, unobservable, or combine behaviors that can fail independently.
- Required spec sections contain `<TODO: ...>` placeholders.
- `Implementation Notes` do not make source inspection, smallest credible red seam, green implementation, and broadened verification the default path, or they permit red-first bypass without requiring a written exception.

Warnings unless they distort scope/proof:
- `Out of Scope` is missing or thin.
- Legacy `Actors` or `Scenarios / Behavior Examples` sections are absent. If present, they must be structurally valid and consistent with Purpose, Scope, Acceptance, and Verification.

### 2. Scenario, acceptance, and traceability funnel

Blockers:
- Any normative `S<n>` scenario lacks exactly one `Covers: A<n>` link, maps to acceptance wording that does not contain the scenario behavior, or lacks proof through the linked acceptance id.
- Orientation-only scenarios create implementation/proof obligations, or contradict required behavior.
- Named variants, modes, branches, fallback paths, examples, or failure cases inside an acceptance item are neither split into separate acceptance ids nor listed as separate proof obligations with evidence or explicit exclusions.
- Forward trace from `CONTRACT.md`/original intent/epic source to Purpose/Scope/Scenarios/Acceptance/Verification is missing where a source exists and matters.
- Backward trace leaves planned helpers, APIs, test files, commands, config changes, TAP rows, proof rows, or implementation branches orphaned from acceptance ids and in-scope rationale.

### 3. Verification and TAP proof gate

Blockers:
- `## Verification` lacks exact `### Verification Commands`, `### Test Architecture Plan`, or `### Acceptance Proof Matrix` subsections.
- Verification commands are vague (`run the tests`), claim non-existent files, or fail to name reviewer-runnable commands/manual/file-read actions.
- `### Test Architecture Plan` lacks required columns: `Row ID | Layer / Scope | Behavior / Acceptance Slice | Owning Suite / File(s) | Boundary Exercised | Assertions / Observability | Fixture / Test Data Strategy | CI Lane / Command | Fallback Plan | Split / Merge Rationale`.
- TAP rows fail the TAP quality gate from `docs/epic-conventions.md`: stable `TAP-*` ids; cheapest reliable real boundary; exact seam; behavior-facing assertion or reviewer-visible signal; fixture/data isolation and live-dependency policy; focused command/CI lane; fallback plan; and repo-convention split/merge rationale when behavior shares a file.
- Broad E2E/manual proof is used when an obvious lower-layer deterministic seam would provide equivalent confidence without an explicit rationale.
- Hidden live dependencies, slow/flaky/order-coupled fixtures, private-choreography assertions unless contractual, fake mocked-helper seams, or grab-bag test placement would make proof unreliable.
- `Acceptance Proof Matrix` omits any `A<n>` id, uses proof maturity outside `final|provisional`, leaves `Open Detail` blank for a provisional row, or combines ids/variants whose failure signal is not genuinely shared.
- Rows for changed tests/proof surfaces do not reference relevant `TAP-*` ownership when tests or proof surfaces change.

### 4. Conditional proof sections and risk lenses

Blockers when the condition applies:
- Multi-surface, variant, mode, or orchestration-branch stories lack `### Surface / Branch Proof Matrix`, omit an in-scope combination, or rely on helper proof when routing proof is required for supported callsites.
- Prompt/template/placeholder/string-substitution work lacks `### Fail-open Checks` proving no unresolved placeholders/raw tokens, enabled-path activation, and disabled/default-path baseline behavior.
- Raw persisted, external, framework, or generated input crosses stricter assumptions without proof at the raw boundary, an `### Input Boundary Shape Risk` matrix when needed, or explicit exclusions/unknowns with mitigation.
- Normative design sources lack durable anchors, `### Design Sources`, or complete `### Design Element Trace` rows using only `required` or bounded `flexible` obligations mapped through Scenario -> Acceptance -> Verification.
- Visibility, placement, navigation, copy, responsive, or interaction-state design obligations lack rendered-surface proof or an explicit narrower proof boundary.
- Material activated risk lenses (async/event-loop, concurrency, platform/OS APIs, external I/O, permissions/security, persistence, resource lifecycle, retries/timeouts, generated artifacts, prompt/template fail-open behavior, naming-sensitive invariants, etc.) are not proven at the owning boundary or explicitly excluded.
- External reality failure modes such as stale/not-found, permission/access denied, already-complete, timeout/cancellation, unsupported platform, or partial failure are omitted for platform/process/filesystem/network/subprocess/resource-lifecycle work without an exclusion.

### 5. Repo/source fit and ownership

Blockers:
- `Critical Files` paths do not resolve, omit obvious domain owners, or hide migrations/public APIs/existing tests/coupling that should affect the plan.
- Existing reusable code, tests, routes/callsites, fixtures, CLI/API entrypoints, generated artifacts, deprecated duplicate owners, or config/runtime surfaces are missed after domain-term search.
- Planned ownership remains ambiguous without a source-inspection step that will resolve it before code changes.
- `Locked Decisions` contradict `AGENTS.md`, `CONTRACT.md`, ticket intent, or established patterns; major decisions omit context, rejected alternatives, consequences, or architecture fit.
- Signature changes, parameter-wiring contracts, or output/report schemas are recorded only as advisory prose when a locked interface decision is required.
- Dependency/sibling stories or `<epic>/CONTRACT.md` define shared actors, interfaces, verification conventions, or decisions that the plan silently drifts from.
- Ticket/contract/code conflicts are not named with an explicit resolution. Respect the convention: codebase facts expose stale contracts; `CONTRACT.md` supersedes stale story/ticket intent unless the operator records a reopen or scoped deviation.

### 6. Evidence quality, debt, and findings

Blockers:
- Review evidence speculates about code, tests, tickets, PRs, or Jira sources that were not inspected or explicitly classified as inaccessible/unknown.
- Unknown or provisional evidence affects acceptance, route ownership, ticket intent, proof credibility, or contract drift without safe bounds and a follow-up path.
- Debt Friction that affects proof or scope is hidden instead of recorded with the `docs/epic-conventions.md` shape. A plan is `blocked` for Debt Friction only when meaningful acceptance or proof planning is not possible.

Warnings:
- Non-blocking evidence gaps, repo-fit concerns, or optional follow-ups should be logged with severity and next action instead of silently ignored.

## Plan lane transitions

You may update the matched `MASTER.md` row's `Plan` column as part of this review. Never change the implementation `Status` column or the story file's `Status:` header from this command.

- `approve` → set `Plan` to `🟢 PLAN APPROVED`. If implementation `Status` is `⬜ TODO` or `⚪ TODO`, tell the operator the next action is `/epic-story-claim <epic> <story>` from a fresh session. If implementation has already started, tell the operator the next action is `/epic-story-resume <epic> <story>` or the appropriate implementation command.
- `request_changes` → set `Plan` to `🟠 PLAN CHANGES REQUESTED`. Tell the operator to run `/epic-story-plan-resume <epic> <story>` to edit the specific spec sections you named, then re-run `/epic-story-plan-review <epic> <story>` from a fresh session. For a ground-up rewrite before implementation starts, recommend deleting the story file and tracker row, then re-running `/epic-story-plan`.
- `blocked` → set `Plan` to `⛔ PLAN BLOCKED`. Use this only when the plan is unsalvageable as written and the operator needs to pause on this story (e.g., the plan depends on an upstream story that does not exist, or a `## Locked Decision` directly contradicts the architecture and the plan cannot be minimally amended).
- `not_reviewable` → set `Plan` to `🟠 PLAN CHANGES REQUESTED` if missing context can be repaired in the story contract. If missing context cannot be repaired in the story contract, restore the pre-review `Plan` value from before this command wrote `🟣 PLAN IN REVIEW` and say what context is missing. Never leave the final lane at `🟣 PLAN IN REVIEW` for a completed `not_reviewable` verdict.

**Explicit prohibitions:** never move a story into `⚪ TODO`, `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `🔵 IN PR`, `✅ DONE`, or implementation `⛔ BLOCKED` from this command. Those transitions are owned by `/epic-story-claim`, `/epic-story-resume`, `/epic-story-review`, and `/epic-story-pr`.

## Plan review log write-back

Append or create a `## Plan Review Log` section on the story file with a new entry:

```md
- <UTC ISO timestamp> Plan review run by fresh maintainer session
  - Verdict: approve | request_changes | blocked | not_reviewable
  - Plan lane transition: <from> -> <to>
  - Status transition: unchanged: <status> -> <status>
  - Sections reviewed: Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, Discovery Notes
  - Original intent checked: <issues/PRs/Jira/tickets/epic sources or none found/inaccessible>
  - Traceability: forward <complete|gaps>; backward <complete|gaps>
  - Design trace: complete|gaps|not applicable
  - Code surfaces searched: <paths/patterns/entrypoints or none beyond Critical Files>
  - Risk lenses reviewed: <activated lenses and exclusions, or none material>
  - Evidence quality: confirmed <short>; inferred <short|none>; unknown <short|none>; provisional <short|none>
  - Finding closure: <disposition + fix proof + regression/side-effect check, or none>
  - Key findings:
    - <short bullet>
    - <short bullet>
  - Hypothesis triage: none | <material suspicious surface + proof target summary>
  - Debt Friction: none | <decision + short title>
  - Next action: <one concrete recommendation>
```

If a `Plan Review Log` section does not exist on the story file, create it at the end of the file. Append the new review entry during this command. Later `/epic-story-plan-resume` may squash stale addressed history, but unresolved blockers, operator decisions, the latest disposition, Debt Friction, and material evidence anchors must remain recoverable.

## Output format

Start with findings, ordered by severity, with section references.

```markdown
**Decision**: [APPROVE | REQUEST CHANGES | BLOCKED | NOT REVIEWABLE]
**Reviewed Story**: [Step <resolved_step_number> / <resolved_spec_file>]
**Plan coverage**: [sections present / missing / thin]
**Mode**: [pre-implementation plan review | contract review]
**Original Intent Used**: [issues/PRs/Jira/tickets/epic sources inspected, none found, or inaccessible]
**Traceability**: [forward complete/gaps; backward complete/gaps]
**Design Trace**: [complete | gaps | not applicable]
**Risk Lenses**: [activated lenses reviewed, proof/exclusion gaps, or none material]

## Hypothesis Triage
- [suspicious surface -> tentative issue -> next proof target, or None]

## Evidence Gaps
- [unknown/inaccessible/weak evidence that matters, or None]

**Findings**
- [Severity] [section] issue with inspected anchor

**Summary**
- [2–4 short bullets]

**Plan Lane Transition**
- [🟡 PLAN DRAFT -> 🟢 PLAN APPROVED | 🟢 PLAN APPROVED -> 🟠 PLAN CHANGES REQUESTED | ...]

**Status Transition**
- [unchanged: <status> -> <status>]

## Research Events
- reused: <board entries verified by direct reads/search with anchors, or none>
- board-refresh: <provided entries not verified or needed facts absent, with anchors, or none>
- added: <new sourced research facts with anchors, or none>

**Next Action**
- [single concrete next step, e.g. "/epic-story-claim <epic>" or "edit <sections> in <story file> and re-run /epic-story-plan-review from a fresh session"]
```

If there are no findings, say that explicitly.
