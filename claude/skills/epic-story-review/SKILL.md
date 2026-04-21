---
name: epic-story-review
description: Review the plan for a ⚪ TODO story before implementation begins — validate Purpose / Acceptance / Verification / Critical Files / Locked Decisions against the live repo and record a Plan Review verdict. Use when a story has been scaffolded by /epic-story-save and you want a fresh-session sanity check before /epic-claim.
disable-model-invocation: true
argument-hint: "<epic-name> <story-number-or-spec-file>"
allowed-tools: Read Edit Grep Glob Bash(git status:*) Bash(git log:*)
---

# Epic Story Review

Review one `⚪ TODO` story's **plan** against the live repository, before any implementation work begins. This is the planning-side analog of `/epic-review`: read-only for code, read-only for the story's spec sections, and writes only to a new `## Plan Review Log` entry on the story file. The highest-leverage part of this review is the acceptance/proof contract: atomic acceptance ids plus a reviewer-facing proof matrix that is credible enough to drive red-first implementation without drifting into fake seams.

Argument: `$ARGUMENTS` — `<epic_name> <story_number_or_spec_file>`. Both required.

## Important

This command only edits the resolved story file's `## Plan Review Log` section. On a `blocked` verdict it additionally edits the `Status:` header line of the story file and the matched `MASTER.md` tracker row. It **never** touches:

- source code (product files, tests, configs)
- the files listed in the story's `## Critical Files`
- any spec section of the story file (`## Purpose`, `## Triggering Need`, `## Expected Prerequisites`, `## Scope`, `## Out of Scope`, `## Acceptance`, `## Verification`, `## Discovery Notes`, `## Critical Files`, `## Implementation Notes`, `## Locked Decisions`)
- any other runtime section (`## Active Claim`, `## Progress Log`, `## Session Handoff`, `## Review Log`, `## PR Tracking`)

If you find the plan is wrong, say so in the log's `Key findings` and recommend the operator edit the spec sections themselves. Do not rewrite the plan inside the log.

## Why operator-explicit (arg or menu) selection

`/epic-story-review` never auto-infers the epic or the story. The operator explicitly chooses — either by passing `<epic> <story>` as arguments or by picking from the menu this skill shows when either is absent. The menu is **not** inference: it lists the legal candidates (filtered to `⚪ TODO`) and asks the operator to pick.

The reasoning: plan review must come from a fresh, independent perspective. The same session that just wrote the plan will rationalize it, not scrutinize it — it will read every section as evidence for the conclusions it already reached during planning. Auto-inferring "the current story" would silently pick whatever the session was last planning — exactly the coupling we want to avoid.

A gentle nudge: if you find yourself picking from the menu in the same session that wrote the plan, consider opening a fresh session for the review. The menu still makes it possible to run plan review from the planning session, but the friction is intentional and any future change that adds silent auto-inference here must be rejected.

## Resolution

1. Parse `$ARGUMENTS` as `<epic> <story>` (both optional).
2. **EPIC resolution (menu fallback):**
   - If `<epic>` was passed, resolve `<cwd>/agent_coordination/epics/<epic>`.
   - If `<epic>` was not passed, list every directory under `<cwd>/agent_coordination/epics/` whose `MASTER.md` has at least one row with status `⚪ TODO`. For each, print: `<slug> — <N stories TODO, last-touched YYYY-MM-DD>`. If the filtered list is empty, abort with: `no epics have stories ready for plan review (nothing at ⚪ TODO)`. Otherwise ask the operator to pick (number or slug).
3. **STORY resolution (menu fallback):**
   - If `<story>` was passed, continue to resolution step 4.
   - If `<story>` was not passed, list every row in `<epic>/MASTER.md` whose status is `⚪ TODO`. For each, print: `<Step> — <Deliverable>`. If the filtered list is empty, abort with: `no stories at ⚪ TODO in <epic>`. Otherwise ask the operator to pick (number or slug).
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

- the story's status in `MASTER.md` (or its `Status:` header line) is not `⚪ TODO` — say "this story is past plan review; use `/epic-review` instead"
- the story file has no `> **Plan source**:` header line — say "story was not scaffolded by `/epic-story-save`; plan review assumes that shape"
- the story file is missing `## Purpose`, `## Acceptance`, or `## Verification` — say which section is missing
- any runtime section already exists on the story file (`## Active Claim`, `## Progress Log`, `## Session Handoff`, `## Review Log`, `## PR Tracking`) — say "story has already been claimed or reviewed; plan review runs before implementation begins"

## Source-of-truth hierarchy

1. the main repo `AGENTS.md`
2. `<epic>/MASTER.md`
3. the resolved story file
4. dependency story files
5. actual code referenced by the story's `## Critical Files` (read-only probes only)

Do not infer identity from filename shape or naming conventions that are not explicitly recorded in `MASTER.md`.

## Plan review process

1. Read every spec section of the story file. Treat each one as a claim that must hold against the live repo.
2. Use `Read`, `Grep`, and `Glob` to probe the repository — confirm `## Critical Files` paths resolve, confirm the domain the plan covers does not already have reusable implementations the plan missed, confirm `## Locked Decisions` do not contradict `AGENTS.md` or established patterns.
3. Treat `## Verification` plus `## Implementation Notes` as the proof-design and implementation-method contract, not as proof that the implementation already exists. Do not run the planned tests expecting them to pass at this phase. Instead, validate whether the commands, seams, owning surfaces, branch decomposition, routing proofs, and fail-open checks are concrete, plausible, aimed at the real acceptance behavior rather than a mocked caricature of it, and specific enough to support red-first implementation after source inspection.
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
6. **`Acceptance` criteria are observable, atomic, and stable.** Each bullet must begin with `A<n>`, be checkable by a command, a file read, or a UI observation, and cover exactly one independently provable behavior. Fails on vague thresholds or compound bullets that could fail independently.
7. **`Verification` has the required shape.** It must contain exact `### Verification Commands` and `### Acceptance Proof Matrix` subsections, plus any required `### Surface / Branch Proof Matrix` and `### Fail-open Checks` subsections when the story's risk surface calls for them.
8. **Every acceptance id is covered by the matrix.** Missing rows are a `request_changes` finding, even when the prose acceptance section looks reasonable.
9. **Matrix rows are structurally valid.** `Proof Maturity` must be `final` or `provisional`; `provisional` rows require non-blank `Open Detail`; shared rows are valid only when the same proof action and failure signal genuinely cover all listed acceptance ids.
10. **Multi-surface stories expand into branch-aware proof.** If the story spans multiple supported surfaces, variants, modes, or orchestration branches, `## Verification` must include `### Surface / Branch Proof Matrix` with rows for each in-scope combination or an explicit exclusion.
11. **Helper proof is not routing proof.** When multiple supported callsites or orchestration paths exist, the surface / branch matrix must explicitly distinguish `helper`, `routing`, and `behavior` proof classes. Helper-only proof is insufficient; at least one routing proof must show that the supported callsites actually invoke the intended helper or branch logic.
12. **Fail-open prompt risks are covered when relevant.** Prompt-, template-, or placeholder-driven stories must include `### Fail-open Checks` proving supported renders leave no unresolved placeholders or raw tokens, enabled supported paths actually activate the feature, and an appropriate disabled/default path remains unchanged.
13. **Proof seams are credible and focused.** Reject rows that mainly validate mocked helpers or otherwise disconnected seams instead of the real acceptance surface. Provisional rows are allowed if they still anchor to the right owning surface and are concrete enough to guide implementation toward a smallest focused red seam after source inspection.
14. **`Verification Commands` are real reviewer actions.** Fails if the story says "run the tests" with no command, or claims an existing test file that does not exist.
15. **`Implementation Notes` make red-first the default implementation method.** The plan must clearly say implementation inspects sources first, chooses the smallest focused seam it can make fail, turns it green, then broadens verification. If the plan anticipates a reason red-first may be infeasible, it must require an explicit written exception before deviating.
16. **`Critical Files` exist.** Resolve every path with `Read` or `Glob`. Missing or renamed files are plan-staleness signals.
17. **`Critical Files` are the right surfaces.** Grep the plan's domain keywords; if obvious owners of that domain are missing from the list, flag it.
18. **`Discovery Notes` mentions reusable existing code.** Search the repo for 2–3 domain terms from the plan and cross-reference against `## Discovery Notes`. If the plan invents something that clearly exists already, that is a `request_changes` finding.
19. **`Locked Decisions` don't contradict `AGENTS.md` or established patterns.** Read `AGENTS.md` and spot-check each decision.
20. **No hidden gotchas in `Critical Files`.** Skim each Critical File for things the plan didn't mention but should have: migrations, public APIs, existing tests that would break, cross-module coupling.
21. **`Implementation Notes` are internally consistent** with `## Acceptance` and `## Scope` (the plan's own self-consistency).
22. **No `<TODO: missing from plan — ...>` placeholders** left by `/epic-story-save`. If any remain, verdict is at minimum `request_changes`.
23. **Debt Friction is surfaced when it affects proof or scope.** If current story planning is made harder by debt, the finding must use the `docs/epic-conventions.md` shape in `## Plan Review Log`. A plan may be blocked for Debt Friction only when meaningful acceptance or proof planning is not possible.

## Status transitions

You may update `MASTER.md` and the story file's `Status:` header as part of this review, but only within a narrow policy:

- `approve` → leave status at `⚪ TODO`. Tell the operator the next action is `/epic-claim <epic>` from a fresh session.
- `request_changes` → leave status at `⚪ TODO`. Tell the operator to edit the specific spec sections you named in the findings and re-run `/epic-story-review <epic> <story>` from a fresh session. For a ground-up rewrite, recommend deleting the story file and re-running `/epic-story-save`.
- `blocked` → move to `⛔ BLOCKED` in both `MASTER.md` and the story file's `Status:` header. Use this only when the plan is unsalvageable as written and the operator needs to pause on this story (e.g., the plan depends on an upstream story that does not exist, or a `## Locked Decision` directly contradicts the architecture and the plan cannot be minimally amended).
- `not_reviewable` → leave status at `⚪ TODO`. Say what context is missing (e.g., `AGENTS.md` unreadable, dependency story files missing) and recommend how to unblock.

**Explicit prohibitions:** never move a story into `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `🔵 IN PR`, or `✅ DONE` from this command. Those transitions are owned by `/epic-claim`, `/epic-resume`, `/epic-review`, and `/epic-pr`.

## Plan review log write-back

Append or create a `## Plan Review Log` section on the story file with a new entry:

```md
- <UTC ISO timestamp> Plan review run by fresh maintainer session
  - Verdict: approve | request_changes | blocked | not_reviewable
  - Status transition: <from> -> <to>
  - Sections reviewed: Purpose, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, Discovery Notes, Expected Prerequisites, Scope
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

**Findings**
- [Severity] [section] issue

**Summary**
- [2–4 short bullets]

**Status Transition**
- [⚪ TODO -> ⚪ TODO | ⚪ TODO -> ⛔ BLOCKED]

**Next Action**
- [single concrete next step, e.g. "/epic-claim <epic>" or "edit <sections> in <story file> and re-run /epic-story-review from a fresh session"]
```

If there are no findings, say that explicitly.
