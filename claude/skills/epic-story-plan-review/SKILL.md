---
name: epic-story-plan-review
description: Review a story's planning contract at any lifecycle point — validate Purpose / Actors / Scenarios / Acceptance / Verification / Critical Files / Locked Decisions against original intent, the live repo, and traceability gaps, then record a Plan Review verdict in the Plan lane.
disable-model-invocation: true
argument-hint: "<epic-name> <story-number-or-spec-file>"
allowed-tools: Read Edit Grep Glob Bash(git status:*) Bash(git log:*) Bash(git show:*) Bash(gh issue view:*) Bash(gh pr view:*) Bash(gh api:*) Bash(jira issue view:*)
---

# Epic Story Plan Review

Review one story's **planning contract** against the live repository at any lifecycle point. This is the planning-side analog of `/epic-story-review`: read-only for code, read-only for the story's spec sections, and writes only to a new `## Plan Review Log` entry on the story file plus the `Plan` lane in `MASTER.md`. The highest-leverage part of this review is the acceptance/proof contract: atomic acceptance ids plus a reviewer-facing Test Architecture Plan and proof matrix that are credible enough to drive red-first implementation without drifting into fake seams or disorganized tests.

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

You are the reviewer-of-record and orchestration layer: you resolve the story, decide source-of-truth conflicts, own the final verdict, write the Plan Review Log, and perform any Plan lane transition. Do not outsource final judgment. When useful, delegate self-contained evidence-gathering probes to subagents (or the platform's spawn equivalent) while keeping them read-only: original intent/ticket archaeology, broad codebase owner discovery beyond `## Critical Files`, dependency/sibling/`CONTRACT.md` drift checks, verification/proof-surface audits, and traceability or hypothesis probes. Subagent outputs must cite inspected anchors and be verified enough before they support findings, evidence gaps, or approval.

1. Read every spec section of the story file. Treat each one as a claim that must hold against `CONTRACT.md` when present, original intent, sibling contracts, and the live repo.
2. Build an **intent and traceability map** before approving anything:
   - forward trace: `CONTRACT.md`/original issue/ticket/epic intent -> Purpose/Scope/Scenarios/Acceptance -> Test Architecture Plan -> Verification proof rows -> owning code/test surfaces
   - backward trace: every planned code/test surface, helper, command, test-architecture row, and proof row -> Acceptance id -> story scope -> `CONTRACT.md`/original issue/ticket/epic intent or explicit in-story rationale
   - design trace when applicable: normative design source anchor -> visible element/state -> `required` or bounded `flexible` trace row -> Scenario -> Acceptance -> Verification -> rendered proof action
   Missing links are not automatically blockers when no original ticket exists, but unmapped normative design elements are blockers and must be visible in findings.
3. Mine original intent aggressively but only from explicit anchors: ticket/PR URLs, Jira keys, issue numbers, branch names, commit messages, `MASTER.md`, dependency stories, PR bodies, or story prose. Use `gh issue view`, `gh pr view`, `gh api`, `jira issue view`, `git log`, and `git show` when available and relevant. If an external source cannot be accessed, record the exact missing source and do not invent its content. If external intent conflicts with `CONTRACT.md`, treat that as a contract conflict requiring an explicit decision rather than as a reason to override the contract.
4. Use `Read`, `Grep`, and `Glob` to probe the repository beyond `## Critical Files` — confirm paths resolve, search for 2–4 domain terms, inspect existing tests, test layout/markers/fixtures/CI lanes, public APIs, similar helpers, deprecated duplicate owners, routing/callsite surfaces, and sibling story contracts. Confirm the domain the plan covers does not already have reusable implementations the plan missed, and confirm `## Locked Decisions` do not contradict `AGENTS.md`, `CONTRACT.md`, ticket intent, or established patterns.
5. Treat `## Scenarios / Behavior Examples`, `## Verification`, and `## Implementation Notes` as the behavior-funnel, test-architecture/proof-design, and implementation-method contract, not as proof that the implementation already exists. Do not run the planned tests expecting them to pass at this phase. Instead, validate whether scenarios funnel into acceptance, whether commands, Test Architecture Plan rows, seams, owning surfaces, branch decomposition, design traces, routing proofs, and fail-open checks are concrete, plausible, aimed at the real acceptance behavior rather than a mocked caricature of it, and specific enough to support red-first implementation after source inspection.
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

Before approving, verify every item:

1. **`Purpose` is concrete and user-visible.** Fails on vague phrasing ("improve X", "refactor Y") with no observable outcome.
2. **`Triggering Need` is real.** Fails if tautological ("because we need it") or missing a concrete pain link.
3. **`Expected Prerequisites` match `MASTER.md`.** For every dependency story number listed: the row exists; its status is `✅ DONE` or realistically close; cross-epic deps are flagged but not failed.
4. **`Scope` is atomic.** Fails if the scope reads like multiple independent stories.
5. **`Out of Scope` is non-empty and meaningful.** A missing `## Out of Scope` is a warning, not a failure.
6. **`Actors` are concrete when present.** Legacy absence is not a failure. If present, the section must use role bullets and stay consistent with Purpose, Scope, Acceptance, and Verification.
7. **`Scenarios / Behavior Examples` funnel into acceptance when present.** Legacy absence is not a failure. Every normative `S<n>` scenario must include exactly one `Covers: A<n>` link; multiple `Covers` ids in one scenario are a `request_changes` finding and should be split or reshaped. Every orientation-only scenario must say `Orientation only`. A scenario that describes required behavior without acceptance coverage is a `request_changes` finding.
8. **Linked scenarios are covered.** For every `S<n> Covers: A<n>` mapping, the linked acceptance item must include the scenario's expected behavior and `## Verification` must prove the scenario-relevant case through that acceptance id. Drift at either hop blocks approval.
9. **`Acceptance` criteria are observable, atomic, and stable.** Each bullet must begin with `A<n>`, be checkable by a command, a file read, or a UI observation, and cover exactly one independently provable behavior. Fails on vague thresholds or compound bullets that could fail independently.
10. **`Verification` has the required shape.** It must contain exact `### Verification Commands`, `### Test Architecture Plan`, and `### Acceptance Proof Matrix` subsections, plus any required `### Surface / Branch Proof Matrix`, `### Design Sources`, `### Design Element Trace`, `### Input Boundary Shape Risk`, and `### Fail-open Checks` subsections when the story's risk surface calls for them.
11. **Every acceptance id is covered by the Acceptance Proof Matrix.** Missing rows are a `request_changes` finding, even when the prose acceptance section looks reasonable.
12. **Named acceptance variants are covered.** If an acceptance item names variants, modes, branches, fallback paths, error cases, or examples, the plan must either split them into separate acceptance ids or list each named case as a separate proof obligation in the Acceptance Proof Matrix. A row that proves only one variant does not cover sibling variants unless the plan records an explicit exclusion with rationale.
13. **Acceptance Proof Matrix rows are structurally valid.** `Proof Maturity` must be `final` or `provisional`; `provisional` rows require non-blank `Open Detail`; shared rows are valid only when the same proof action and failure signal genuinely cover all listed acceptance ids and named variants.
14. **Multi-surface stories expand into branch-aware proof.** If the story spans multiple supported surfaces, variants, modes, or orchestration branches, `## Verification` must include `### Surface / Branch Proof Matrix` with rows for each in-scope combination or an explicit exclusion.
15. **Helper proof is not routing proof.** When multiple supported callsites or orchestration paths exist, the surface / branch matrix must explicitly distinguish `helper`, `routing`, and `behavior` proof classes. Helper-only proof is insufficient; at least one routing proof must show that the supported callsites actually invoke the intended helper or branch logic.
16. **Fail-open prompt risks are covered when relevant.** Prompt-, template-, or placeholder-driven stories must include `### Fail-open Checks` proving supported renders leave no unresolved placeholders or raw tokens, enabled supported paths actually activate the feature, and an appropriate disabled/default path remains unchanged.
17. **Input boundary shape risks are covered when relevant.** If raw persisted, external, framework, or generated input crosses into stricter application assumptions, the proof contract must cover every in-scope boundary and shape case at the real raw-input boundary, or explicitly exclude it with a reason. A `### Input Boundary Shape Risk` mini-matrix is required when multiple boundaries, variants, or mitigations would be hard to audit from acceptance rows alone. Unknown evidence must include the reason evidence is unavailable, a mitigation, and a follow-up path.
18. **Test Architecture Plan is present and credible.** `### Test Architecture Plan` must use stable `TAP-*` row ids and identify layer/scope, owning suite/file, behavior slice, boundary exercised, fixture/data strategy, CI lane/command, and split/merge rationale for every planned added/changed test or proof surface. Legacy stories without test changes may use static/manual/file-read rows, but new or reworked test plans cannot omit this section.
19. **Test portfolio uses the cheapest reliable layers.** Request changes when the plan defaults to broad E2E/manual proof for behavior that has an obvious lower-layer deterministic seam, unless the story records why lower-level proof is insufficient.
20. **Test placement is organized.** Request changes when unrelated unit, functional, integration, acceptance, contract, or static proof behaviors are collapsed into one new or existing test file without a repo-convention rationale in `Split / Merge Rationale`.
21. **Fixtures and isolation are planned.** Request changes when planned tests depend on hidden live network/db/filesystem state, ordering, global mutable state, slow/flaky timing, or broad shared fixtures without explicit isolation/cleanup strategy.
22. **Proof seams are credible and focused.** Reject rows that mainly validate mocked helpers or otherwise disconnected seams instead of the real acceptance surface. Provisional rows are allowed if they still anchor to the right owning surface and are concrete enough to guide implementation toward a smallest focused red seam after source inspection.
23. **`Verification Commands` are real reviewer actions.** Fails if the story says "run the tests" with no command, or claims an existing test file that does not exist. When new tests are expected, the plan should name the planned file and test function/class names when knowable, or mark the names provisional and state the RED assertion each test must prove.
24. **`Implementation Notes` make red-first the default implementation method.** The plan must clearly say implementation inspects sources first, chooses the smallest focused seam it can make fail, turns it green, then broadens verification. If the plan anticipates a reason red-first may be infeasible, it must require an explicit written exception before deviating.
25. **`Critical Files` exist.** Resolve every path with `Read` or `Glob`. Missing or renamed files are plan-staleness signals.
26. **`Critical Files` are the right surfaces.** Grep the plan's domain keywords; if obvious owners of that domain are missing from the list, flag it.
27. **`Discovery Notes` mentions reusable existing code.** Search the repo for 2–3 domain terms from the plan and cross-reference against `## Discovery Notes`. If the plan invents something that clearly exists already, that is a `request_changes` finding.
28. **`Locked Decisions` don't contradict `AGENTS.md` or established patterns.** Read `AGENTS.md` and spot-check each decision.
29. **No hidden gotchas in `Critical Files`.** Skim each Critical File for things the plan didn't mention but should have: migrations, public APIs, existing tests that would break, cross-module coupling.
30. **`Implementation Notes` are internally consistent** with `## Acceptance` and `## Scope` (the plan's own self-consistency).
31. **No `<TODO: ...>` placeholders** left in spec sections. If any remain, verdict is at minimum `request_changes`.
32. **Debt Friction is surfaced when it affects proof or scope.** If current story planning is made harder by debt, the finding must use the `docs/epic-conventions.md` shape in `## Plan Review Log`. A plan may be blocked for Debt Friction only when meaningful acceptance or proof planning is not possible.
33. **Interface-contract completeness.** If the story modifies an existing function signature, verify the new signature is recorded in Locked Decisions or Implementation Notes with exact parameter names, types, and defaults. If the plan wires parameters through to a callee function, verify each omission has a stated reason. Signature changes or wiring contracts recorded only in advisory sections (Implementation Notes, Discovery Notes) without a corresponding Locked Decision are a `request_changes` finding: the implementer treats advisory prose as non-binding. Acceptable forms: a Locked Decision with the exact Python signature, or Implementation Notes with a before/after diff excerpt AND a Locked Decision cross-reference.
34. **Original-intent traceability.** If an original issue, PR, Jira ticket, parent epic, or stable card id is available, every Purpose/Scope/Acceptance claim must map to that source, to `CONTRACT.md` when the contract has superseded the source, or to an explicit scoped deviation. If no original source is found, record `none found` and verify the plan is still coherent against `MASTER.md`, `CONTRACT.md` when present, dependency stories, and live code.
35. **Ticket/contract/code conflict resolution.** If grounded ticket intent, `CONTRACT.md`, and current code shape point in different directions, the plan must name the conflict and choose a resolution with rationale that respects the convention: codebase wins over stale `CONTRACT.md`, and `CONTRACT.md` wins over stale story or ticket intent unless the operator records an explicit reopen/scope-deviation decision. Do not approve a plan that silently lets existing code shape erase ticket-backed behavior or silently lets stale ticket text override the merged contract.
36. **Backward traceability / orphan scope.** Every planned helper, API change, test file, Test Architecture Plan row, proof row, command, config change, or implementation branch must map back to an acceptance id and in-scope rationale. Orphan work, gold-plating, and proof rows that validate unrequested behavior are `request_changes` findings unless explicitly marked out-of-scope follow-up.
37. **Existing owner discovery is broad enough.** Approval requires searching beyond the listed Critical Files for domain owners, similar implementations, tests, routes/callsites, fixtures, CLI/API entrypoints, generated artifacts, and deprecation paths. If ownership remains ambiguous, require the plan to state how implementation will resolve it before changing code.
38. **Alternatives and consequences for locked decisions.** Major `Locked Decisions` must capture context, rejected alternatives, consequences, and fit with established architecture or ticket constraints. A decision that just says what to do without why is insufficient when multiple plausible implementations exist.
39. **Sibling/contract drift.** If `<epic>/CONTRACT.md`, dependency stories, sibling stories, or prior review logs define a shared actor, interface, verification convention, or locked decision, the plan must align with it or explicitly exclude/defer the drift with rationale.
40. **Operational and lifecycle risks are named.** Plans touching migrations, persistence, auth, external I/O, prompts/templates, config/defaults, background jobs, CLI/API contracts, concurrency, or generated files must include rollback/default/fail-open/fail-closed behavior and verification at the owning boundary.
41. **Evidence quality is explicit.** Approval findings and log entries must distinguish `confirmed`, `inferred`, `unknown`, and `provisional` evidence. Unknowns that affect acceptance, route ownership, ticket intent, or proof credibility block approval unless the plan explicitly scopes them out with a safe follow-up.
42. **Activated risk lenses are identified.** Plans should name material domain risks triggered by the work, such as async/event-loop behavior, concurrency, platform/OS APIs, external I/O, permissions/security, persistence, resource lifecycle, retries/timeouts, generated artifacts, prompt/template fail-open behavior, or naming-sensitive invariants. Missing a material lens is a `request_changes` finding unless the risk is already fully covered by another required matrix.
43. **Risk-lens proof is behavior-centered.** Planned proof should prefer caller-observable outcomes and contract signals. Assertions on private retry counts, sleeps, helper call order, temporary names, or implementation choreography are acceptable only when the story explicitly makes those mechanics contractual.
44. **Failure-mode breadth is explicit for external reality.** For platform APIs, process/filesystem/network/subprocess work, permissions, cleanup, retries, or resource lifecycle, the plan must cover common sibling failures such as stale/not-found, permission/access denied, already completed, timeout/cancellation, unsupported platform, and partial failure, or record explicit exclusions.
45. **Existing-idiom comparison is planned for risky areas.** When the plan chooses a pattern in an activated risk lens, it should direct implementers to inspect established repo idioms for that risk class before finalizing code. Unexplained deviation from obvious existing patterns is a review finding.
46. **Sensitive invariant terminology is truthful.** For lifecycle, ownership, identity, security, persistence, or concurrency-sensitive work, names and locked terminology must not imply stronger guarantees than the plan can prove.
47. **Design sources are durable and classified.** If the story references a mockup, wireframe, screenshot, Figma frame, prior `/grillme` discussion, or other design source, `## Verification` must include `### Design Sources` with durable/reviewable anchors and `normative` or `orientation only` status. Chat-only references are not sufficient unless converted into a self-contained operator-approved summary.
48. **Normative design elements are fully traced.** Every visible element/state in a normative design source must appear in `### Design Element Trace` as `required` or bounded `flexible`, map to a scenario when scenarios are present, map to an acceptance id, and map to a proof row or reviewer action. Missing rows, `omitted` classes, or unbounded `flexible` rows are `request_changes` findings.
49. **Design proof uses rendered surfaces when needed.** For visibility, placement, navigation, copy, responsive behavior, or interaction-state obligations, planned proof must inspect the rendered surface (browser/manual UI observation, screenshot, rendered DOM/output, or equivalent) unless the story records an explicit exception or narrower proof boundary. Code-only proof is insufficient for those obligations.

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
  - Test architecture: complete|gaps|not applicable; TAP rows <covered|missing|misplaced>
  - Design trace: complete|gaps|not applicable
  - Code surfaces searched: <paths/patterns/entrypoints or none beyond Critical Files>
  - Risk lenses reviewed: <activated lenses and exclusions, or none material>
  - Evidence quality: confirmed <short>; inferred <short|none>; unknown <short|none>; provisional <short|none>
  - Key findings:
    - <short bullet>
    - <short bullet>
  - Hypothesis triage: none | <material suspicious surface + proof target summary>
  - Debt Friction: none | <decision + short title>
  - Next action: <one concrete recommendation>
```

If a `Plan Review Log` section does not exist on the story file, create it at the end of the file. Never delete or rewrite previous entries — the log is append-only and records the plan's revision history across re-runs.

## Output format

Start with findings, ordered by severity, with section references.

```markdown
**Decision**: [APPROVE | REQUEST CHANGES | BLOCKED | NOT REVIEWABLE]
**Reviewed Story**: [Step <resolved_step_number> / <resolved_spec_file>]
**Plan coverage**: [sections present / missing / thin]
**Mode**: [pre-implementation plan review | contract review]
**Original Intent Used**: [issues/PRs/Jira/tickets/epic sources inspected, none found, or inaccessible]
**Traceability**: [forward complete/gaps; backward complete/gaps]
**Test Architecture**: [complete | gaps | not applicable; TAP rows covered/missing/misplaced]
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
