---
name: epic-story-plan-review
description: Review a story's planning contract at any lifecycle point — validate Purpose / Actors / Scenarios / Acceptance / Verification / Critical Files / Locked Decisions against the live repo and record a Plan Review verdict in the Plan lane.
disable-model-invocation: true
argument-hint: "<epic-name> <story-number-or-spec-file>"
allowed-tools: Read Edit Grep Glob Bash(git status:*) Bash(git log:*)
---

# Epic Story Plan Review

Review one story's **planning contract** against the live repository at any lifecycle point. This is the planning-side analog of `/epic-story-review`: read-only for code, read-only for the story's spec sections, and writes only to a new `## Plan Review Log` entry on the story file plus the `Plan` lane in `MASTER.md`. The highest-leverage part of this review is the acceptance/proof contract: atomic acceptance ids plus a reviewer-facing proof matrix that is credible enough to drive red-first implementation without drifting into fake seams.

Argument: `$ARGUMENTS` — `<epic_name> <story_number_or_spec_file>`. Both required.

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
3. the resolved story file
4. dependency story files listed for the resolved row in `MASTER.md` and in the story's `## Expected Prerequisites`

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
2. `<epic>/MASTER.md`
3. the resolved story file
4. dependency story files
5. actual code referenced by the story's `## Critical Files` (read-only probes only)

Do not infer identity from filename shape or naming conventions that are not explicitly recorded in `MASTER.md`.

## Shared Research Board Input

When launched by a converger, you may receive `Shared Research Board from parent orchestration session` before the slash command. This is the only allowed cross-session context beyond neutral operational notes. Use it as sourced orientation only. The converger owns keeping it relevant; you only decide whether the needed fact is present in the provided board. If present, verify it with direct reads/search against the cited anchors before it affects a finding, approval, or write-back instead of rerunning expensive research. If a provided entry does not verify, report a board-refresh signal with exact anchors; do not decide how to curate the board. If absent, follow this skill's normal research rules. Ignore any board item that lacks an exact source anchor such as `path:line`, symbol, command/output excerpt, or tool/query/path.

## Plan review process

1. Read every spec section of the story file. Treat each one as a claim that must hold against the live repo.
2. Use `Read`, `Grep`, and `Glob` to probe the repository — confirm `## Critical Files` paths resolve, confirm the domain the plan covers does not already have reusable implementations the plan missed, confirm `## Locked Decisions` do not contradict `AGENTS.md` or established patterns.
3. Treat `## Scenarios / Behavior Examples`, `## Verification`, and `## Implementation Notes` as the behavior-funnel, proof-design, and implementation-method contract, not as proof that the implementation already exists. Do not run the planned tests expecting them to pass at this phase. Instead, validate whether scenarios funnel into acceptance, whether commands, seams, owning surfaces, branch decomposition, routing proofs, and fail-open checks are concrete, plausible, aimed at the real acceptance behavior rather than a mocked caricature of it, and specific enough to support red-first implementation after source inspection.
4. Use `git status` to confirm the worktree is not mid-implementation (if there are large pending changes, note it — plan review on a dirty worktree is a warning signal).
5. Use `git log` to skim recent history for related work the plan should have referenced but did not.
6. Never speculate about code you haven't read. If a claim in the plan can be checked, check it.
7. Run a Debt Friction check: ask whether the plan hides story-local friction from unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure. Only record a `Debt Friction` finding when there is a causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.
8. If the plan looks structurally wrong, verdict is `request_changes` with a pointer to which sections to edit. Do not rewrite the plan inside the log.
9. Walk the full validation checklist below before settling on a verdict.

## Critical checks

Before approving, verify every item:

1. **`Purpose` is concrete and user-visible.** Fails on vague phrasing ("improve X", "refactor Y") with no observable outcome.
2. **`Triggering Need` is real.** Fails if tautological ("because we need it") or missing a concrete pain link.
3. **`Expected Prerequisites` match `MASTER.md`.** For every dependency story number listed: the row exists; its status is `✅ DONE` or realistically close; cross-epic deps are flagged but not failed.
4. **`Scope` is atomic.** Fails if the scope reads like multiple independent stories.
5. **`Out of Scope` is non-empty and meaningful.** A missing `## Out of Scope` is a warning, not a failure.
6. **`Actors` are concrete when present.** Legacy absence is not a failure. If present, the section must use role bullets and stay consistent with Purpose, Scope, Acceptance, and Verification.
7. **`Scenarios / Behavior Examples` funnel into acceptance when present.** Legacy absence is not a failure. Every normative `S<n>` scenario must include `Covers: A<n>`; every orientation-only scenario must say `Orientation only`. A scenario that describes required behavior without acceptance coverage is a `request_changes` finding.
8. **Linked scenarios are covered.** For every `S<n> Covers: A<n>` mapping, the linked acceptance item must include the scenario's expected behavior and `## Verification` must prove the scenario-relevant case through that acceptance id. Drift at either hop blocks approval.
9. **`Acceptance` criteria are observable, atomic, and stable.** Each bullet must begin with `A<n>`, be checkable by a command, a file read, or a UI observation, and cover exactly one independently provable behavior. Fails on vague thresholds or compound bullets that could fail independently.
10. **`Verification` has the required shape.** It must contain exact `### Verification Commands` and `### Acceptance Proof Matrix` subsections, plus any required `### Surface / Branch Proof Matrix`, `### Input Boundary Shape Risk`, and `### Fail-open Checks` subsections when the story's risk surface calls for them.
11. **Every acceptance id is covered by the matrix.** Missing rows are a `request_changes` finding, even when the prose acceptance section looks reasonable.
12. **Named acceptance variants are covered.** If an acceptance item names variants, modes, branches, fallback paths, error cases, or examples, the plan must either split them into separate acceptance ids or list each named case as a separate proof obligation in the matrix. A row that proves only one variant does not cover sibling variants unless the plan records an explicit exclusion with rationale.
13. **Matrix rows are structurally valid.** `Proof Maturity` must be `final` or `provisional`; `provisional` rows require non-blank `Open Detail`; shared rows are valid only when the same proof action and failure signal genuinely cover all listed acceptance ids and named variants.
14. **Multi-surface stories expand into branch-aware proof.** If the story spans multiple supported surfaces, variants, modes, or orchestration branches, `## Verification` must include `### Surface / Branch Proof Matrix` with rows for each in-scope combination or an explicit exclusion.
15. **Helper proof is not routing proof.** When multiple supported callsites or orchestration paths exist, the surface / branch matrix must explicitly distinguish `helper`, `routing`, and `behavior` proof classes. Helper-only proof is insufficient; at least one routing proof must show that the supported callsites actually invoke the intended helper or branch logic.
16. **Fail-open prompt risks are covered when relevant.** Prompt-, template-, or placeholder-driven stories must include `### Fail-open Checks` proving supported renders leave no unresolved placeholders or raw tokens, enabled supported paths actually activate the feature, and an appropriate disabled/default path remains unchanged.
17. **Input boundary shape risks are covered when relevant.** If raw persisted, external, framework, or generated input crosses into stricter application assumptions, the proof contract must cover every in-scope boundary and shape case at the real raw-input boundary, or explicitly exclude it with a reason. A `### Input Boundary Shape Risk` mini-matrix is required when multiple boundaries, variants, or mitigations would be hard to audit from acceptance rows alone. Unknown evidence must include the reason evidence is unavailable, a mitigation, and a follow-up path.
18. **Proof seams are credible and focused.** Reject rows that mainly validate mocked helpers or otherwise disconnected seams instead of the real acceptance surface. Provisional rows are allowed if they still anchor to the right owning surface and are concrete enough to guide implementation toward a smallest focused red seam after source inspection.
19. **`Verification Commands` are real reviewer actions.** Fails if the story says "run the tests" with no command, or claims an existing test file that does not exist. When new tests are expected, the plan should name the planned file and test function/class names when knowable, or mark the names provisional and state the RED assertion each test must prove.
20. **`Implementation Notes` make red-first the default implementation method.** The plan must clearly say implementation inspects sources first, chooses the smallest focused seam it can make fail, turns it green, then broadens verification. If the plan anticipates a reason red-first may be infeasible, it must require an explicit written exception before deviating.
21. **`Critical Files` exist.** Resolve every path with `Read` or `Glob`. Missing or renamed files are plan-staleness signals.
22. **`Critical Files` are the right surfaces.** Grep the plan's domain keywords; if obvious owners of that domain are missing from the list, flag it.
23. **`Discovery Notes` mentions reusable existing code.** Search the repo for 2–3 domain terms from the plan and cross-reference against `## Discovery Notes`. If the plan invents something that clearly exists already, that is a `request_changes` finding.
24. **`Locked Decisions` don't contradict `AGENTS.md` or established patterns.** Read `AGENTS.md` and spot-check each decision.
25. **No hidden gotchas in `Critical Files`.** Skim each Critical File for things the plan didn't mention but should have: migrations, public APIs, existing tests that would break, cross-module coupling.
26. **`Implementation Notes` are internally consistent** with `## Acceptance` and `## Scope` (the plan's own self-consistency).
27. **No `<TODO: ...>` placeholders** left in spec sections. If any remain, verdict is at minimum `request_changes`.
28. **Debt Friction is surfaced when it affects proof or scope.** If current story planning is made harder by debt, the finding must use the `docs/epic-conventions.md` shape in `## Plan Review Log`. A plan may be blocked for Debt Friction only when meaningful acceptance or proof planning is not possible.
29. **Interface-contract completeness.** If the story modifies an existing function signature, verify the new signature is recorded in Locked Decisions or Implementation Notes with exact parameter names, types, and defaults. If the plan wires parameters through to a callee function, verify each omission has a stated reason. Signature changes or wiring contracts recorded only in advisory sections (Implementation Notes, Discovery Notes) without a corresponding Locked Decision are a `request_changes` finding: the implementer treats advisory prose as non-binding. Acceptable forms: a Locked Decision with the exact Python signature, or Implementation Notes with a before/after diff excerpt AND a Locked Decision cross-reference.

## Plan lane transitions

You may update the matched `MASTER.md` row's `Plan` column as part of this review. Never change the implementation `Status` column or the story file's `Status:` header from this command.

- `approve` → set `Plan` to `🟢 PLAN APPROVED`. If implementation `Status` is `⚪ TODO`, tell the operator the next action is `/epic-story-claim <epic>` from a fresh session. If implementation has already started, tell the operator the next action is `/epic-story-resume <epic> <story>` or the appropriate implementation command.
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
  - Status transition: <from> -> <to>
  - Sections reviewed: Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, Discovery Notes
  - Key findings:
    - <short bullet>
    - <short bullet>
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

**Findings**
- [Severity] [section] issue

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
