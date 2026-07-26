---
name: openspec-next-action
description: Inspect the current or selected OpenSpec initiative, change, or spec state and recommend the single next workflow action with concise reasoning. Use when you need lightweight lifecycle routing before choosing a planning, implementation, PR, feedback, or archive command.
disable-model-invocation: true
argument-hint: "[INITIATIVE=<slug>|<initiative-slug>] [STORY=<slug>|<story-slug>] [SPEC=<spec-or-path>] [--all] [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Grep Glob Bash(git worktree:*) Bash(git status:*) Bash(git diff:*) Bash(git rev-parse:*) Bash(git ls-files:*) Bash(git hash-object:*) Bash(sha256sum:*) Bash(shasum:*)
---

# OpenSpec Next Action

Inspect OpenSpec coordination artifacts and recommend the next command or operator decision. This is a read-only router: it never edits files, never changes lifecycle fields, never launches subagents, and never invokes another slash command on behalf of the operator.

Argument: `$ARGUMENTS` — optional selectors: `[INITIATIVE=<slug>|<initiative-slug>] [STORY=<slug>|<story-slug>] [SPEC=<spec-or-path>] [--all] [WORKTREE="<basename>=<path>"]...`. With no selectors, infer only from the current working directory or from a single unambiguous OpenSpec candidate. Use `--all` to summarize every active change in the selected initiative or workspace instead of choosing one story. `WORKTREE=` is an optional repeatable checkout selector; for OpenSpec-root resolution, only a listed/launch git checkout containing the selected initiative and story artifacts qualifies, while target-repo overrides lacking those artifacts are ignored.

## Resolution Model

- `<workspace_root>` = `<cwd>` and is the worktree-discovery base.
- `<candidate_roots>` = deduplicated checkout paths from `<workspace_root>` plus `git worktree list --porcelain`.
- `<openspec_root>` = the transient root for a selected story, or the per-story root during broad scans; never persist it.
- `<initiative_file>` = `<openspec_root>/openspec/initiatives/<initiative>/initiative.md`.
- `<change_dir>` = `<openspec_root>/openspec/changes/<story-slug>`.
- `<archive_dir>` = `<openspec_root>/openspec/changes/archive/<story-slug>`.
- `<story_file>` = `<change_dir>/story.md`.
- `<progress_file>` = `<change_dir>/progress.md`.
- `story.md → Initiative:` is the authoritative initiative association for a story. Inventory the top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line. Exactly one present line is valid only when its whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`; duplicate, empty, whitespace-before-colon, non-canonical, or otherwise malformed Initiative-like lines are hard conflicts, never legacy absence.
- The `Status:` header in `story.md` is the authoritative lifecycle signal; for a modern bound story, `progress.md → ## Implementation Review Receipt` is required durable review-verdict evidence that qualifies DONE routing.
- `<tasks_file>` = `<change_dir>/tasks.md`.
- `<blocked_file>` = `<change_dir>/blocked.md`.

There is no central tracker table. Treat `story.md → Plan:` and `story.md → Status:` as the authoritative lifecycle fields, and treat `blocked.md` as the explicit blocker gate.

## Hard Boundaries

- Read-only only. Do not edit, create, delete, move, archive, claim, review, open PRs, or update notebook pages.
- Recommend one next action; do not perform it.
- Validate any operator-provided initiative or story slug against `^[a-z0-9]+(?:-[a-z0-9]+)*$` before constructing paths.
- Never read or write archived change workspaces as active stories. Archived work may receive new input only through a new story or `/openspec-feedback`.
- Do not approve lifecycle state yourself. When evidence is ambiguous, recommend the owner command that can make the authoritative decision.
- Prefer exact command lines, but if the initiative is ambiguous do not invent one; ask the operator to rerun with `INITIATIVE=<slug>`.

## Phase 1 — Parse and Resolve Selectors

1. Parse `$ARGUMENTS`:
   - `INITIATIVE=<slug>` or the first positional token that matches an initiative directory selects an initiative.
   - `STORY=<slug>` or a positional token that matches an active or archived change workspace selects a story.
   - `SPEC=<spec-or-path>` selects a spec path, spec slug, or spec file basename.
   - `--all` requests a compact recommendation table for all resolved active stories.
   - Preserve every `WORKTREE="<basename>=<path>"` occurrence. Validate that each value supplies a non-empty basename and absolute checkout path; reject malformed selectors. They select an existing checkout only and never authorize mutation.
   - Record `<explicit_pair>` as true only when the operator supplied both initiative and story selectors in this invocation. Directory inference, a default, or an initiative-only selection does not make an explicit pair.
2. Reject unknown flags except the selectors above.
3. Validate explicit slugs before path construction. If invalid, stop with `invalid slug; use lowercase hyphenated slug characters only`.
4. Build `<candidate_roots>` before declaring any target missing. When a story is known, resolve roots in this order:
   - First inspect explicit `WORKTREE=` paths that are `<workspace_root>` or registered worktrees and contain the selected story plus its bound/associated initiative file. Exactly one qualifying explicit path wins; multiple qualifying explicit paths halt for operator selection. Overrides lacking both coordination artifacts remain unrelated target-repo selectors and do not qualify.
   - Only when no explicit path qualifies, inspect registered worktrees other than `<workspace_root>` on `refs/heads/<initiative>/<story-slug>` with both artifacts. Exactly one qualifying branch worktree outranks launch; multiple qualifying branch worktrees halt for operator selection; no qualifying branch worktree proceeds to launch fallback.
   - Only when neither explicit nor branch candidates qualify, fall back to `<workspace_root>` and require both artifacts there. Ignore unrelated/non-branch copies instead of choosing an arbitrary matching root.
   Recompute all paths after selection. Check archive locations with the same precedence when resolving terminal state. Report a story or initiative missing only after discovery and launch fallback are exhausted.
5. If no selector is supplied, infer conservatively:
   - If `<cwd>` is inside an active/archive story or initiative directory, treat that as launch context, then still apply step 4 after a story is known.
   - Otherwise aggregate active `openspec/changes/*/story.md` workspaces across `<candidate_roots>`, deduplicating each slug with step 4's branch-over-launch precedence. Different story slugs may be summarized together; multiple qualifying branch copies of the same slug halt. If exactly one eligible active story exists, select it. If no active story exists and exactly one distinct initiative exists across roots, select it. Otherwise ask for `INITIATIVE=<slug>`, `STORY=<slug>`, `SPEC=<path>`, or `--all`.
6. Resolve every selected story's initiative binding before lifecycle routing:
   - Inventory the complete top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line. Exactly one present line is valid only when its whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`. Duplicate canonical headers, an empty value, whitespace before the colon (for example `Initiative : foo`), a non-canonical value, or any other malformed Initiative-like line halts and reports every offending line. Never reinterpret malformed present input as a zero-header legacy story. A selected initiative mismatch also halts and reports both values; do not reinterpret membership from prose.
   - If no initiative was explicit, use the one valid bound value and require its same-root `initiative.md`.
   - Only zero Initiative or Initiative-like lines is legacy. For that case, scan same-root initiative files for exact story-slug associations in `## Story Candidates`. Exactly one association may drive discovery and must equal any selected initiative. A different or multiple association halts. No association is accepted only when `<explicit_pair>` is true and the selected same-root initiative file exists; otherwise halt because an inferred/defaulted or initiative-only selection is not an explicit pair. Mark accepted legacy resolution `confidence: medium`, warn, and never backfill the header.
7. If only an initiative is selected or `--all` requests a broad scan, aggregate active story workspaces with step 4's root precedence and group them by authoritative `Initiative:` binding. Menus and broad results include only bound stories plus zero-Initiative-line legacy stories with exactly one same-root `## Story Candidates` association. Warn and do not backfill accepted legacy stories. Exclude zero-reference legacy workspaces because initiative-only/menu/default selection is not an explicit pair, and exclude well-formed stories bound to other initiatives. Any duplicate/malformed Initiative-like line, multiple legacy associations, or multiple qualifying branch copies of one slug halts the broad result rather than guessing. If no story is associated with a selected initiative, recommend `/openspec-story-plan INITIATIVE=<initiative>` unless its initiative file is missing.
8. If a spec selector is supplied:
   - If it resolves under `openspec/changes/<story-slug>/specs/`, route by that story.
   - If it resolves under `openspec/specs/`, treat it as durable archived/current spec context, not an active change. Recommend planning a story for any desired spec change, or `/openspec-feedback <initiative>` if the selector came from feedback.
   - If it matches specs in multiple active changes, stop unless `--all` was requested.

## Phase 2 — Collect Minimal Evidence

Read only the artifacts needed for routing:

- Initiative mode: `initiative.md`, plus a directory listing of `openspec/changes/*/story.md`.
- Story mode: `story.md` headers, `blocked.md` existence, and bounded evidence from `progress.md` and `tasks.md` only when relevant to feedback, PR delivery evidence, DONE, or archive routing.
- Spec mode: the resolved path and its containing workspace or stable spec location.

Evidence to extract:

- `Plan:` from `story.md`.
- `Status:` from `story.md`, including whether it is missing or exact legacy `⬜ TODO`.
- Whether `## Plan Review Log` exists in `story.md`.
- Whether `blocked.md` exists.
- Whether the story is active, archived, or missing.
- Whether `progress.md → ## PR State` indicates open, merged, or requested-changes PR feedback that affects archive or feedback routing.
- Every `progress.md → ## Implementation Review Receipt` heading/body. A modern DONE receipt qualifies only when exactly one section contains every canonical field exactly once (`Reviewed at`, `Decision`, `Approval gate`, `Status transition`, `Evidence reviewed`, `Identity method`, `Identity digest`, `Identity bases`, `Identity paths`, `Findings`, `Proof`, `Next owner`), with APPROVE/PASS, a transition ending in `✅ DONE`, and well-formed `review-identity-v1` evidence.
- Before recommending PR delivery or archive, whether canonical `review-identity-v1` recomputes from the receipt-recorded bases/path list to exactly its `Identity digest`. The story's OpenSpec coordination artifacts, including PR State and timeline, are outside identity scope.
- When a PR URL exists, whether the sole `## PR State` has exactly one non-placeholder `Verified implementation digest` equal to the receipt digest and one non-placeholder `Verified at` timestamp. Missing/stale PR verification belongs to `/openspec-pr`; archive verifies live merge state.
- Whether `tasks.md` has obviously unchecked in-scope tasks when considering archive.
- Whether required planning scaffold files (`proposal.md`, `story.md`, `design.md`, `tasks.md`) and scaffold anchors (`Plan:`, `Status:`, `## Plan Review Log`) exist when the plan is not approved.

Do not perform deep review. If the quick evidence is missing, stale, or conflicting, route to the owner command rather than trying to settle the verdict here.

## Phase 3 — Choose the Route

Apply these rules in order.

### Missing or initiative-only context

| State | Recommendation |
|---|---|
| `openspec/initiatives/<initiative>/initiative.md` is missing | `/openspec-initiative-plan` or `/openspec-initiative-plan SLUG=<initiative>` |
| Initiative exists and no active story is selected | `/openspec-story-plan INITIATIVE=<initiative>` |
| Multiple plausible stories and no `--all` | Operator decision: rerun with `STORY=<slug>` or `--all` |
| Stable spec under `openspec/specs/` selected for a desired behavior change | `/openspec-story-plan INITIATIVE=<initiative>` |
| Stable spec selected as feedback or correction input | `/openspec-feedback <initiative>` |

### Archived, missing, or blocked story

| State | Recommendation |
|---|---|
| Story workspace missing | `/openspec-story-plan INITIATIVE=<initiative>` |
| Story is under `openspec/changes/archive/` | `None` for the selected terminal lifecycle; mention new feedback/planning only as a caveat, not as a competing suggestion |
| `blocked.md` exists | Operator decision: resolve/remove `blocked.md`; then rerun `/openspec-next-action` |
| `Status: ⛔ BLOCKED` and no `blocked.md` | `/openspec-story-resume <initiative> <story-slug>` |
| `Plan: ⛔ PLAN BLOCKED` | Operator decision: resolve the planning blocker; then rerun `/openspec-next-action <initiative> <story-slug>` |

### IN REVIEW repair-or-review precedence

After the archived/missing/`blocked.md` gates above, inspect current bounded readiness evidence before routing an active story at `Status: 🟣 IN REVIEW`. The current Status owns this route; an older receipt may explain history but cannot override it.

- If the named deficiency is implementation or proof incompleteness (for example unchecked in-scope tasks, provisional/missing proof rows, missing implementation mapping, or an incomplete handoff), offer the implementation workflow choice: Converge wrapper `/openspec-story-converge <initiative> <story-slug>` or Non-looped pass `/openspec-story-resume <initiative> <story-slug>`. State that fresh review follows repair.
- If the named deficiency is a planning/contract anchor or incomplete/non-reviewable scaffold, give one explicit operator repair action to reconcile the aborted-review IN REVIEW state and named artifact defect before invoking planning. Do not route immediately to plan-converge, plan-resume, or plan-review because those planning owners reject IN REVIEW. If the workspace itself is absent, use only `/openspec-story-plan INITIATIVE=<initiative>` after relocation is ruled out.
- If the named missing evidence is external, give one concrete operator action to obtain, attach, or explicitly resolve it; then rerun this router.
- Only when no repair condition is present, review has not yet run against the current ready evidence, and all review prerequisites are satisfied, recommend one action: open a completely fresh, oblivious session and run `/openspec-story-review <initiative> <story-slug>`.

Do not blindly self-loop IN REVIEW back to review or route it into a planning owner that rejects it.

### DONE review-receipt and planning-contradiction gates

```openspec-contract
contract: done-delivery-v1
owner: openspec-next-action
mode: deep
order: blocker>receipt-or-pre-v3>plan>identity>task-proof>feedback-stop>delivery
receipt: bound-modern:exactly-one-approve-pass|pre-v3:unbound+zero-initiative-like+zero-receipt+no-identity
plan: approved-only
identity: modern:recompute|pre-v3:none
task-proof: tasks:missing|whitespace-only|malformed-checkbox-like|no-valid-checkbox|unchecked=>contradiction;valid-task-lines:- [ ] <nonempty>|- [x] <nonempty>|- [X] <nonempty>;apm:missing-table|malformed-table|missing-required-A<n>-row|missing-proof-method|missing-reviewer-action|missing-expected-evidence|missing-relevant-surfaces|missing-proof-maturity|invalid-proof-maturity|provisional-regardless-of-open-detail|final-open-detail-neither-blank-nor-explicitly-closed=>contradiction
feedback: ordinary-feedback+preserve-receipt+no-delivery-write
delivery: all-prior-pass
routes: receipt-invalid=>feedback|plan-invalid=>operator-stop|identity-invalid=>feedback|task-proof-invalid=>feedback|all-prior-pass=>delivery
```

For a bound modern `Status: ✅ DONE`, a missing, duplicate, malformed, or non-approving Implementation Review Receipt routes exclusively to ordinary `/openspec-feedback <initiative-slug>` with an operator-acknowledged `resume-current-story` disposition.

Ordinary feedback preserves existing receipt bytes while it reopens the story to `🔄 IN PROGRESS`; then `/openspec-story-resume` repairs and returns it to `🟣 IN REVIEW`, a fresh `/openspec-story-review` authors a completed-review handoff, and `/openspec-feedback` validates and publishes it.

The only no-receipt exception is an unbound pre-v3 DONE story with zero Initiative or Initiative-like header lines and zero receipt sections; warn and backfill neither binding nor receipt.

After blocker and receipt-shape precedence, when a bound modern `Status: ✅ DONE` has exactly one valid `APPROVE`/`PASS` receipt but a current `review-identity-v1` mismatch or unverifiable identity, or bounded task/proof evidence contradicting DONE, route exclusively to ordinary `/openspec-feedback <initiative-slug>` with an operator-acknowledged `resume-current-story` disposition while preserving the existing receipt bytes.
Only after this router detects a DONE contradiction and before routing it to the operator-acknowledged feedback step, it must not mutate DONE Status, PR State, archive state, convergence state, Plan, implementation artifacts, or external state, as applicable; normal delivery behavior for a consistent DONE story remains allowed.


After the review-handoff precedence, qualify `Status: ✅ DONE` against `progress.md → ## Implementation Review Receipt` before offering PR or archive:

- Inventory every receipt heading/body. If any is present, DONE is review-approved only when exactly one section contains exactly one of each canonical field: `Reviewed at`, `Decision`, `Approval gate`, `Status transition`, `Evidence reviewed`, `Identity method`, `Identity digest`, `Identity bases`, `Identity paths`, `Findings`, `Proof`, and `Next owner`. Require `Decision: APPROVE`, `Approval gate: PASS`, a `Status transition` ending in `✅ DONE`, `Identity method: review-identity-v1`, a canonical digest, and reproducible bases/path lists. Invalid receipt evidence uses the ordinary-feedback reopen route stated in this skill. Never search for an older approval; after reopen and repair, fresh substantive review authors the handoff and feedback owns normalization during publication.
- A true pre-v3 legacy DONE without a receipt is compatible only when the story has zero Initiative or Initiative-like header lines, zero receipt sections, and every other gate passes. Warn that both binding and receipt evidence are absent, use the already-defined explicit/unique-association compatibility rules to resolve the story, skip identity recomputation because no identity exists, and use the documented `—` digest and `—` verification-timestamp placeholders; never backfill either artifact. A bound modern DONE with absent receipt evidence uses that ordinary-feedback reopen route.
Then check `Status:` before offering planning repair. If authoritative `Status: ✅ DONE` is paired with any `Plan:` value other than `🟢 PLAN APPROVED` (including missing, malformed, or ambiguous Plan state), do not recommend a planning command: plan review/resume reject completed stories. Preserve PR/archive safety with exactly one scalar route: `Operator action: investigate and reconcile the contradictory durable Status: ✅ DONE and Plan: <value> state before PR delivery or archive; then rerun /openspec-next-action <initiative> <story-slug>.` Do not name or invent a lifecycle owner for that reconciliation.

- For a modern receipt-bearing `Status: ✅ DONE` only, immediately before recommending PR delivery or archive, recompute canonical `review-identity-v1` from exactly the receipt-recorded `Identity bases` and `Identity paths` and require the result to equal `Identity digest`. Missing/unavailable inputs, malformed method/value, unsupported computation, or mismatch uses only the ordinary-feedback reconciliation route above; never rewrite the receipt. The story's OpenSpec coordination artifacts are excluded from this identity, so PR State/timeline publication does not cause drift.

Run the concrete task/proof gate before any delivery recommendation. Require `tasks.md` to exist and contain non-whitespace content. A valid task line is exactly `- [ ] <nonempty description>`, `- [x] <nonempty description>`, or `- [X] <nonempty description>`. Treat `- []`, a checked marker with no description, every marker other than space/`x`/`X`, no valid checkbox line, and every valid unchecked line as a DONE contradiction. Also inspect the current `story.md → ## Verification → ### Acceptance Proof Matrix`: reject a missing or malformed table, any missing required `A<n>` row, or any row missing `Proof Method`, `Reviewer Action`, `Expected Evidence`, `Relevant Surfaces`, or `Proof Maturity`. `Proof Maturity` must be exactly `final` or `provisional`; any provisional row contradicts DONE regardless of `Open Detail`; a final/non-provisional row contradicts DONE when `Open Detail` is unresolved or otherwise non-empty rather than blank or explicitly closed. Missing, invalid, incomplete, or stale task/proof evidence stops only through the ordinary-feedback reconciliation route above, preserving receipt bytes and making no PR, progress, wait, archive, or external write/recommendation. Only after this gate passes may delivery routing continue.
- For non-DONE stories, authoritative `Status:` owns routing. A receipt from an earlier review may be historical context but never overrides the current lane or forces its old `Next owner`.

### Story scaffold normalization

For other active, non-DONE stories, scaffold normalization runs before planning or implementation routing so malformed anchors are repaired before claim/resume decisions.

| State | Recommendation |
|---|---|
| Repairable incomplete scaffold (for example an unambiguous absent `Plan:`, `Status:`, or `## Plan Review Log` anchor, missing planning artifacts/sections, or legacy `Status: ⬜ TODO`) where `/openspec-story-plan-resume` can safely identify and restore the contract shape | `/openspec-story-plan-resume <initiative> <story-slug>` only; plan-converge rejects a non-reviewable scaffold |
| Duplicated, conflicting, malformed, or ambiguous lifecycle anchors, or scaffold damage that is not safely repairable/resolvable by plan-resume | Singular operator repair/selection action; do not offer the wrapper |

### Planning lane before implementation, PR, or archive

For any other active, non-DONE story, a non-approved `Plan:` lane is repaired before claim or resume routing. A scaffold is **structurally reviewable** only when all required planning artifacts and sections exist, the Plan/Status/log anchors are unambiguous, and no unresolved plan-review finding remains.

| Plan lane / scaffold | Recommendation |
|---|---|
| Repairable missing core planning files or structurally incomplete/non-reviewable contract that plan-resume can safely restore | `/openspec-story-plan-resume <initiative> <story-slug>` only; do not offer plan-converge until the scaffold is complete/reviewable |
| Unresolvable or malformed/ambiguous planning state | Singular operator repair/selection action; do not offer the wrapper |
| `Plan: 🟡 PLAN DRAFT` or `Plan: 🟣 PLAN IN REVIEW`, structurally reviewable | Planning workflow choice: Converge wrapper `/openspec-story-plan-converge <initiative> <story-slug>`; Non-looped pass `/openspec-story-plan-review <initiative> <story-slug>` |
| `Plan: 🟡 PLAN DRAFT` or `Plan: 🟣 PLAN IN REVIEW`, repairably incomplete/non-reviewable | `/openspec-story-plan-resume <initiative> <story-slug>` only |
| `Plan: 🟠 PLAN CHANGES REQUESTED` with unresolved findings | Planning workflow choice: Converge wrapper `/openspec-story-plan-converge <initiative> <story-slug>`; Non-looped pass `/openspec-story-plan-resume <initiative> <story-slug>` |
| `Plan: 🟠 PLAN CHANGES REQUESTED`, all findings addressed/blended and structurally reviewable | Planning workflow choice: Converge wrapper `/openspec-story-plan-converge <initiative> <story-slug>`; Non-looped pass `/openspec-story-plan-review <initiative> <story-slug>` |
| Repeated plan review/resume uncertainty in a valid planning lane | The same state-correct wrapper/Non-looped workflow choice; identify the wrapper as iterative, not as an additional pass |

### Implementation, PR delivery, and archive after plan approval

### DONE contract checkpoint: pre-delivery-recommendation
```openspec-contract
contract: done-invocation-v1
owner: openspec-next-action
name: pre-delivery-recommendation
invokes: done-delivery-v1
checkpoint: pre-delivery-recommendation
before: delivery-recommendation
```

Plan-approved means exactly `Plan: 🟢 PLAN APPROVED`.

| Status | Recommendation |
|---|---|
| `⚪ TODO` after scaffold normalization | Operator decision — choose one workflow: **Converge wrapper:** `/openspec-story-converge <initiative> <story-slug>`; **Non-looped pass:** `/openspec-story-claim <initiative> <story-slug>` |
| `🔄 IN PROGRESS` | Operator decision — choose one workflow: **Converge wrapper:** `/openspec-story-converge <initiative> <story-slug>`; **Non-looped pass:** `/openspec-story-resume <initiative> <story-slug>` |
| `🟣 IN REVIEW` | Use the repair-or-review precedence above; fresh review is singular only when no repair condition exists and prerequisites are satisfied |
| `✅ DONE` with no `blocked.md` | `/openspec-archive <initiative> <story-slug>` when quick archive gates look satisfied; otherwise use the singular evidence-owner route below |
| Unknown status value | Operator decision: inspect `story.md` and normalize through the owning command; do not guess |

Quick archive-gate routing for `✅ DONE`:

- First apply the full receipt/identity gate above. Missing, duplicate, malformed, or non-approving receipt evidence on a bound modern DONE story uses the ordinary-feedback reopen route above; only the exact zero-Initiative-like/zero-receipt pre-v3 exception is compatible without a receipt. After a receipt passes those structural and verdict checks, stale, mismatched, or unverifiable identity evidence uses only the ordinary-feedback reconciliation route above.
- If a PR URL exists, require one `Verified implementation digest` in the sole PR State that exactly equals the current receipt's `Identity digest`, plus one non-placeholder `Verified at`. Missing, duplicate, stale, or mismatched PR identity verification recommends only `/openspec-pr <initiative> <story-slug> <pr-url>` so PR recomputes and persists the checkpoint. The pre-v3 no-receipt exception has no digest to compare and remains warning-only.
- If `## PR State` shows requested changes or actionable unabsorbed PR feedback after the identity checkpoint passes, recommend `/openspec-feedback <initiative> --pr <pr-url>`.
- If `## PR State` shows an open PR without requested changes and the metadata/identity evidence is fresh and complete, recommend waiting for PR review. If delivery metadata is stale or incomplete, recommend only `/openspec-pr <initiative> <story-slug> <pr-url>` to refresh it.
- If `## PR State` shows merged with complete merge metadata and the verified digest equals the receipt digest, recommend `/openspec-archive <initiative> <story-slug>`; archive performs live GitHub merge verification and must not recompute after its own PR State refresh.
- If no PR URL exists, recommend `/openspec-archive <initiative> <story-slug>` when all other gates pass; archive asks for explicit no-PR confirmation and recomputes `review-identity-v1` immediately before mutation.
- If `Status: ✅ DONE` contradicts unchecked tasks or incomplete/stale implementation evidence, recommend only ordinary `/openspec-feedback <initiative>` with an operator-acknowledged plan naming the story target, the contradiction reason, and `resume-current-story`. Preserve the receipt bytes and keep ordinary feedback as the exclusive reconciliation route.
- Otherwise recommend `/openspec-archive <initiative> <story-slug>` and note that archive performs the authoritative preflight and may ask for no-PR confirmation.

## Phase 4 — Multi-Story Output

When `--all` is supplied:

1. Resolve the initiative or aggregate all active changes across `<candidate_roots>`; do not limit the scan to the launch checkout.
2. Apply the same routing rules independently to each active, non-archived story. Deduplicate repeated story slugs with explicit-valid-WORKTREE, then unique-branch-worktree, then launch-fallback precedence. Halt only for multiple qualifying explicit/branch candidates or an ambiguous association; never let a stale launch duplicate defeat one unique qualifying branch worktree.
3. Return a compact table sorted by recommendation class:
   - blocked/operator decision first;
   - planning actions;
   - implementation actions;
   - PR delivery/archive actions;
   - no action.
4. Do not choose a single story unless exactly one entry is actionable and unambiguous.

## Phase 5 — Final Response

Return only this compact report. Include every section; use `None.` or `unavailable` when a field does not apply.

```markdown
Suggested next action: <scalar route, or leave empty only for a dual route>
- Converge wrapper: <command; dual routes only>
- Non-looped pass: <state-correct command; dual routes only>
Choose one; do not run both.
**Confidence**: high | medium | low
**Context**: initiative=<slug|unavailable>; story=<slug|unavailable>; spec=<path|unavailable>
**State**: Plan=<value|unavailable>; Status=<value|unavailable>; Blocked=<yes|no|unavailable>; Location=<active|archived|missing|initiative|spec>

## Reasoning
- <evidence-backed reason with file path and field/section>
- <why this command owns the next transition>

## Alternatives / Caveats
- <optional PR/no-PR choice, ambiguity, stale evidence, or archive preflight caveat>
- None.

## All Candidates
| Story | Plan | Status | Gate | Suggested Action |
|---|---|---|---|---|
| <only when --all or ambiguity requires listing> |
```

For a scalar route, put the selected value on the `Suggested next action:` line and omit the three dual-route lines. For a planning or implementation workflow decision, leave that label empty and render immediately `- Converge wrapper: <command>`, `- Non-looped pass: <state-correct command>`, and `Choose one; do not run both.` The Converge wrapper delegates the direct review/resume or claim/resume passes. Never offer that choice for blocked, malformed/ambiguous, incomplete/non-reviewable scaffold, missing-workspace, PR, archive, wait, or terminal routes. For IN REVIEW, use the implementation converge/resume choice only for named implementation/proof rework; contract/scaffold and external-evidence defects use one explicit operator repair action because planning owners reject IN REVIEW. Recommend a fresh oblivious `/openspec-story-review` only when review has not yet run against the current evidence and all prerequisites are satisfied; the wrapper never launches implementation review.

For other operator decisions, make the prompt concrete, for example: `rerun with INITIATIVE=<slug> STORY=<story-slug>` or `resolve/remove openspec/changes/<story>/blocked.md`. Select PR, archive, wait, and terminal suggestions from current evidence rather than presenting them as a multi-route choice.
