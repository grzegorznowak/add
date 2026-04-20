---
name: epic_story_review
description: Review a ⚪ TODO story's plan before implementation.
---

Plan review: $EPIC / $STORY

Treat `$EPIC` as the exact epic directory name under the agent's current
working directory at:
`agent_coordination/epics/`

Treat `$STORY` as the story selector. It may be either:
- the exact story number from the `Step` column in `<epic>/MASTER.md`, for
  example `03`
- the exact spec file name from the `Spec` column in `<epic>/MASTER.md`, for
  example `story-03-bootstrap-and-docs-rewrite.md`

You are a maintainer reviewing one `⚪ TODO` story's **plan** — its Purpose,
Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, and surrounding
spec sections — against the live repository, before any implementation has
started. The highest-leverage part of this review is the acceptance/proof
contract: atomic acceptance ids plus a reviewer-facing proof matrix that is
credible enough to drive red-first implementation without drifting into fake
seams.

This prompt is intended to work well from a fresh session. It can also be
run multiple times on the same story after the operator edits the spec
sections in response to a `request_changes` verdict.

## Important

This command only edits the resolved story file's `## Plan Review Log`
section. On a `blocked` verdict it additionally edits the `Status:` header
line of the story file and the matched `MASTER.md` tracker row. It **never**
touches:

- source code (product files, tests, configs)
- the files listed in the story's `## Critical Files`
- any spec section of the story file (`## Purpose`, `## Triggering Need`,
  `## Expected Prerequisites`, `## Scope`, `## Out of Scope`,
  `## Acceptance`, `## Verification`, `## Discovery Notes`,
  `## Critical Files`, `## Implementation Notes`, `## Locked Decisions`)
- any other runtime section (`## Active Claim`, `## Progress Log`,
  `## Session Handoff`, `## Review Log`, `## PR Tracking`)

If the plan is wrong, say so in the log's `Key findings` and recommend the
operator edit the spec sections themselves. Do not rewrite the plan inside
the log.

## Why operator-explicit (arg or menu) selection

`epic_story_review` never auto-infers the epic or the story. The operator
explicitly chooses — either by passing `$EPIC` and `$STORY` as arguments or
by picking from the menu this skill shows when either is absent. The menu
is **not** inference: it lists the legal candidates (filtered to `⚪ TODO`)
and asks the operator to pick.

The reasoning: plan review must come from a fresh, independent perspective.
The same session that just wrote the plan will rationalize it, not
scrutinize it — it will read every section as evidence for the
conclusions it already reached during planning. Auto-inferring "the
current story" would silently pick whatever the session was last
planning — exactly the coupling we want to avoid.

A gentle nudge: if you find yourself picking from the menu in the same
Codex session that wrote the plan, consider opening a Codex fresh session
for the review. The menu still makes it possible to run plan review from
the planning session, but the friction is intentional and any future
change that adds silent auto-inference here must be rejected.

## Resolution

1. **EPIC resolution (menu fallback):**
   - If `$EPIC` was passed, resolve `<cwd>/agent_coordination/epics/$EPIC`.
   - If `$EPIC` was not passed, list every directory under
     `<cwd>/agent_coordination/epics/` whose `MASTER.md` has at least one
     row with status `⚪ TODO`. For each, print:
     `<slug> — <N stories TODO, last-touched YYYY-MM-DD>`. If the
     filtered list is empty, abort with:
     `no epics have stories ready for plan review (nothing at ⚪ TODO)`.
     Otherwise ask the operator to pick (number or slug).
2. **STORY resolution (menu fallback):**
   - If `$STORY` was passed, continue to step 3.
   - If `$STORY` was not passed, list every row in `<epic>/MASTER.md`
     whose status is `⚪ TODO`. For each, print: `<Step> — <Deliverable>`.
     If the filtered list is empty, abort with: `no stories at ⚪ TODO in <epic>`.
     Otherwise ask the operator to pick (number or slug).
3. Use `<epic>/MASTER.md` as the only lookup table.
4. First try to match exactly one row whose `Step` value equals `$STORY`.
5. If no row matches by `Step`, try to match exactly one row whose `Spec`
   value equals `$STORY`.
6. If neither lookup finds a row, abort fast and report the unresolved
   selector plus the available `Step` and `Spec` values from `MASTER.md`.
7. If the `Step` lookup and `Spec` lookup both match but point to different
   rows, abort fast and report the ambiguity.
8. Resolve the story file as:
   - `<epic>/<matched row Spec value>`
9. If that path does not exist, abort fast and report the exact missing
   path.

## Read first

1. the main repo `AGENTS.md` for the repo the plan will touch
2. `<epic>/MASTER.md`
3. the resolved story file
4. dependency story files listed for the resolved row in `MASTER.md` and in
   the story's `## Expected Prerequisites`

## Plan readiness check

Before doing the full plan review, abort fast with a concise reason if any
of these hold:

- the story's status in `MASTER.md` (or its `Status:` header line) is not
  `⚪ TODO` — say "this story is past plan review; use `epic_review`
  instead"
- the story file has no `> **Plan source**:` header line — say "story was
  not scaffolded by `epic_story_save`; plan review assumes that shape"
- the story file is missing `## Purpose`, `## Acceptance`, or
  `## Verification` — say which
  section is missing
- any runtime section already exists on the story file (`## Active Claim`,
  `## Progress Log`, `## Session Handoff`, `## Review Log`,
  `## PR Tracking`) — say "story has already been claimed or reviewed;
  plan review runs before implementation begins"

## Source-of-truth hierarchy

1. the main repo `AGENTS.md`
2. `<epic>/MASTER.md`
3. the resolved story file
4. dependency story files
5. actual code referenced by the story's `## Critical Files` (read-only
   probes only)

Do not infer identity from filename shape or naming conventions that are not
explicitly recorded in `MASTER.md`.

## Plan review process

1. Read every spec section of the story file. Treat each one as a claim
   that must hold against the live repo.
2. Use code search and direct reading to probe the repository — confirm
   `## Critical Files` paths resolve, confirm the domain the plan covers
   does not already have reusable implementations the plan missed, confirm
   `## Locked Decisions` do not contradict `AGENTS.md` or established
   patterns.
3. Treat `## Verification` plus `## Implementation Notes` as the
   proof-design and implementation-method contract, not as proof that the
   implementation already exists. Do not run the planned tests expecting them
   to pass at this phase. Instead, validate whether the commands, seams, and
   owning surfaces are concrete, plausible, aimed at the real acceptance
   behavior rather than a mocked caricature of it, and specific enough to
   support red-first implementation after source inspection.
4. Use `git status` to confirm the worktree is not mid-implementation (if
   there are large pending changes, note it — plan review on a dirty
   worktree is a warning signal).
5. Use `git log` to skim recent history for related work the plan should
   have referenced but did not.
6. Never speculate about code you haven't read. If a claim in the plan can
   be checked, check it.
7. If the plan looks structurally wrong, verdict is `request_changes` with
   a pointer to which sections to edit. Do not rewrite the plan inside the
   log.
8. Walk the full validation checklist below before settling on a verdict.

## Critical checks

Before approving, verify every item:

1. **`Purpose` is concrete and user-visible.** Fails on vague phrasing
   ("improve X", "refactor Y") with no observable outcome.
2. **`Triggering Need` is real.** Fails if tautological ("because we need
   it") or missing a concrete pain link.
3. **`Expected Prerequisites` match `MASTER.md`.** For every dependency
   story number listed: the row exists; its status is `✅ DONE` or
   realistically close; cross-epic deps are flagged but not failed.
4. **`Scope` is atomic.** Fails if the scope reads like multiple independent
   stories.
5. **`Out of Scope` is non-empty and meaningful.** A missing `## Out of
   Scope` is a warning, not a failure.
6. **`Acceptance` criteria are observable.** Each bullet must be checkable
   by a command, a file read, or a UI observation. Fails on "works
   correctly" / "is clean" / "is performant" with no measurable threshold.
7. **`Acceptance` ids are stable and atomic.** Every bullet must start with
   `A<n>:` and cover one independently provable behavior. Split any bullet
   whose parts could fail independently.
8. **`Verification` uses the required proof-contract shape.** `## Verification`
   must contain exact `### Verification Commands` and
   `### Acceptance Proof Matrix` subsections, plus any required
   `### Surface / Branch Proof Matrix` and `### Fail-open Checks` subsections
   when the story's risk surface calls for them.
9. **The proof matrix covers every acceptance id.** Every acceptance id must
   appear in at least one matrix row. Shared rows are allowed only when the
   same proof action and failure signal genuinely cover all listed ids.
10. **Proof-matrix rows are concrete.** Every row must have a real proof
    method, reviewer action, expected evidence, and relevant surfaces. Fails
    on vague instructions like "run the relevant tests" or "check manually".
11. **`Proof Maturity` is valid.** Only `final` or `provisional` are allowed.
    `provisional` rows are acceptable during story review, even if all rows
    are provisional, but every provisional row must state its unresolved part
    in `Open Detail`.
12. **Multi-surface stories expand into branch-aware proof.** If the story
    spans multiple supported surfaces, variants, modes, or orchestration
    branches, `## Verification` must include `### Surface / Branch Proof
    Matrix` with rows for each in-scope combination or an explicit exclusion.
13. **Helper proof is not routing proof.** When multiple supported callsites or
    orchestration paths exist, the surface / branch matrix must explicitly
    distinguish `helper`, `routing`, and `behavior` proof classes. Helper-only
    proof is insufficient; at least one routing proof must show that the
    supported callsites actually invoke the intended helper or branch logic.
14. **Fail-open prompt risks are covered when relevant.** Prompt-, template-,
    or placeholder-driven stories must include `### Fail-open Checks` proving
    supported renders leave no unresolved placeholders or raw tokens, enabled
    supported paths actually activate the feature, and an appropriate
    disabled/default path remains unchanged.
15. **Proof seams target the real contract and are focused enough for
    red-first execution.** Reject rows that mainly validate mocked helpers,
    monkeypatched internals, or synthetic seams that would not meaningfully
    exercise the promised acceptance behavior. The plan must still leave room
    for the implementer to choose the smallest focused seam after reading
    sources.
16. **Feasibility is grounded when possible.** Probe referenced commands,
    files, and surfaces against the live repo. Existing seams should exist;
    planned seams should still point at the right owning surface.
17. **`Implementation Notes` make red-first the default implementation
    method.** The plan must clearly say implementation inspects sources first,
    chooses the smallest focused seam it can make fail, turns it green, then
    broadens verification. If the plan anticipates a reason red-first may be
    infeasible, it must require an explicit written exception before deviating.
18. **`Critical Files` exist.** Resolve every path. Missing or renamed files
    are plan-staleness signals.
19. **`Critical Files` are the right surfaces.** Grep the plan's domain
    keywords; if obvious owners of that domain are missing from the list,
    flag it.
20. **`Discovery Notes` mentions reusable existing code.** Search the repo
    for 2–3 domain terms from the plan and cross-reference against
    `## Discovery Notes`. If the plan invents something that clearly exists
    already, that is a `request_changes` finding.
21. **`Locked Decisions` don't contradict `AGENTS.md` or established
    patterns.** Read `AGENTS.md` and spot-check each decision.
22. **No hidden gotchas in `Critical Files`.** Skim each Critical File for
    things the plan didn't mention but should have: migrations, public
    APIs, existing tests that would break, cross-module coupling.
23. **`Implementation Notes` are internally consistent** with `## Acceptance`
    and `## Scope` (the plan's own self-consistency).
24. **No `<TODO: missing from plan — ...>` placeholders** left by
    `epic_story_save`. If any remain, verdict is at minimum `request_changes`.

## Status transitions

You may update `MASTER.md` and the story file's `Status:` header as part of
this review, but only within a narrow policy:

- `approve` → leave status at `⚪ TODO`. Tell the operator the next action
  is `epic_claim $EPIC` from a fresh session.
- `request_changes` → leave status at `⚪ TODO`. Tell the operator to edit
  the specific spec sections you named in the findings and re-run
  `epic_story_review` from a fresh session. For a ground-up rewrite,
  recommend deleting the story file and re-running `epic_story_save`.
- `blocked` → move to `⛔ BLOCKED` in both `MASTER.md` and the story file's
  `Status:` header. Use this only when the plan is unsalvageable as written
  and the operator needs to pause on this story (e.g., the plan depends on
  an upstream story that does not exist, or a `## Locked Decision` directly
  contradicts the architecture and the plan cannot be minimally amended).
- `not_reviewable` → leave status at `⚪ TODO`. Say what context is missing
  (e.g., `AGENTS.md` unreadable, dependency story files missing) and
  recommend how to unblock.

**Explicit prohibitions:** never move a story into `🔄 IN PROGRESS`,
`🟣 IN REVIEW`, `🔵 IN PR`, or `✅ DONE` from this command. Those transitions
are owned by `epic_claim`, `epic_resume`, `epic_review`, and `epic_pr`.

## Plan review log write-back

Append or create a `## Plan Review Log` section on the story file with a new
entry:

```md
- <UTC ISO timestamp> Plan review run by fresh maintainer session
  - Verdict: approve | request_changes | blocked | not_reviewable
  - Status transition: <from> -> <to>
  - Sections reviewed: Purpose, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, Discovery Notes, Expected Prerequisites, Scope
  - Key findings:
    - <short bullet>
    - <short bullet>
  - Next action: <one concrete recommendation>
```

If a `Plan Review Log` section does not exist on the story file, create it
at the end of the file. Never delete or rewrite previous entries — the log
is append-only and records the plan's revision history across re-runs.

## Output format

Start with findings, ordered by severity, with section references.

Use:

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
- [single concrete next step, e.g. "epic_claim $EPIC" or "edit <sections> in <story file> and re-run epic_story_review from a fresh session"]
```

If there are no findings, say that explicitly.
