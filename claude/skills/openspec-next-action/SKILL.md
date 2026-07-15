---
name: openspec-next-action
description: Inspect the current or selected OpenSpec initiative, change, or spec state and recommend the single next workflow action with concise reasoning. Use when you need lightweight lifecycle routing before choosing a planning, implementation, PR, feedback, or archive command.
disable-model-invocation: true
argument-hint: "[INITIATIVE=<slug>|<initiative-slug>] [STORY=<slug>|<story-slug>] [SPEC=<spec-or-path>] [--all]"
allowed-tools: Read Grep Glob
---

# OpenSpec Next Action

Inspect OpenSpec coordination artifacts and recommend the next command or operator decision. This is a read-only router: it never edits files, never changes lifecycle fields, never launches subagents, and never invokes another slash command on behalf of the operator.

Argument: `$ARGUMENTS` — optional selectors: `[INITIATIVE=<slug>|<initiative-slug>] [STORY=<slug>|<story-slug>] [SPEC=<spec-or-path>] [--all]`. With no selectors, infer only from the current working directory or from a single unambiguous OpenSpec candidate. Use `--all` to summarize every active change in the selected initiative or workspace instead of choosing one story.

## Resolution Model

- `<workspace_root>` = `<cwd>`.
- `<initiative_file>` = `<workspace_root>/openspec/initiatives/<initiative>/initiative.md`.
- `<change_dir>` = `<workspace_root>/openspec/changes/<story-slug>`.
- `<archive_dir>` = `<workspace_root>/openspec/changes/archive/<story-slug>`.
- `<story_file>` = `<change_dir>/story.md`.
- `<progress_file>` = `<change_dir>/progress.md`.
- The `Status:` header in `story.md` is the authoritative next-action signal.
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
2. Reject unknown flags except the selectors above.
3. Validate explicit slugs before path construction. If invalid, stop with `invalid slug; use lowercase hyphenated slug characters only`.
4. If no selector is supplied, infer current context conservatively:
   - If `<cwd>` is inside `openspec/changes/<story-slug>/`, select that story.
   - If `<cwd>` is inside `openspec/changes/archive/<story-slug>/`, select that archived story.
   - If `<cwd>` is inside `openspec/initiatives/<initiative-slug>/`, select that initiative.
   - Otherwise inspect `openspec/initiatives/*/initiative.md` and `openspec/changes/*/story.md`. If exactly one active change exists, select it. If exactly one initiative exists and no active changes exist, select the initiative. If multiple candidates exist, stop and ask for `INITIATIVE=<slug>`, `STORY=<slug>`, `SPEC=<path>`, or `--all`.
5. If a story is selected but no initiative is explicit:
   - Use the initiative when exactly one active initiative exists.
   - Otherwise search initiative files for the story slug. If exactly one initiative mentions it, use that initiative with `confidence: medium` and cite the file evidence.
   - If still ambiguous, report the story state but make the next action an operator decision to rerun with `INITIATIVE=<slug> STORY=<story-slug>` because most workflow commands require the initiative argument.
6. If only an initiative is selected, read its `initiative.md` and list active change workspaces that plausibly belong to it by explicit story slug mentions in the initiative file. If none are identifiable, recommend `/openspec-story-plan INITIATIVE=<initiative>` as the next action unless the initiative file itself is missing.
7. If a spec selector is supplied:
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
- Whether the story contract and `Status:` header indicate approved (story review passes via `Status: ✅ DONE`).
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

After the archived/missing/`blocked.md` gates above, inspect bounded readiness evidence before routing an active story at `Status: 🟣 IN REVIEW`:

- If the named deficiency is implementation or proof incompleteness (for example unchecked in-scope tasks, provisional/missing proof rows, missing implementation mapping, or an incomplete handoff), recommend only `/openspec-story-resume <initiative> <story-slug>` to repair it. State that a completely fresh, oblivious review happens only after implementation/proof repair is complete.
- If the named deficiency is a missing anchor, incomplete/non-reviewable planning scaffold, or other contract shape that plan-converge rejects, recommend only `/openspec-story-plan-resume <initiative> <story-slug>`. If the workspace itself is absent, use only `/openspec-story-plan INITIATIVE=<initiative>`. State that fresh implementation review happens only after contract repair and any resulting implementation repair.
- If the scaffold is complete/reviewable and durable evidence identifies an unresolved contract finding that `/openspec-story-plan-converge` can actually orchestrate, offer the planning wrapper plus state-correct Non-looped plan-resume/review choice.
- If the named missing evidence is external and neither implementation nor planning can produce it, give one concrete operator action to obtain, attach, or explicitly resolve that evidence; then rerun this router. Fresh review happens only after that action.
- Only when no repair condition is present, review has not yet run against the current ready evidence, and all review prerequisites are satisfied, recommend one action: open a completely fresh, oblivious session and run `/openspec-story-review <initiative> <story-slug>`.

Do not blindly self-loop IN REVIEW back to review merely because the status was preserved by an aborted review.

### DONE planning-contradiction gate

After the review-handoff precedence, check `Status:` before offering planning repair. If authoritative `Status: ✅ DONE` is paired with any `Plan:` value other than `🟢 PLAN APPROVED` (including missing, malformed, or ambiguous Plan state), do not recommend a planning command: plan review/resume reject completed stories. Preserve PR/archive safety with exactly one scalar route: `Operator action: investigate and reconcile the contradictory durable Status: ✅ DONE and Plan: <value> state before PR delivery or archive; then rerun /openspec-next-action <initiative> <story-slug>.` Do not name or invent a lifecycle owner for that reconciliation.

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

Plan-approved means exactly `Plan: 🟢 PLAN APPROVED`.

| Status | Recommendation |
|---|---|
| `⚪ TODO` after scaffold normalization | Operator decision — choose one workflow: **Converge wrapper:** `/openspec-story-converge <initiative> <story-slug>`; **Non-looped pass:** `/openspec-story-claim <initiative> <story-slug>` |
| `🔄 IN PROGRESS` | Operator decision — choose one workflow: **Converge wrapper:** `/openspec-story-converge <initiative> <story-slug>`; **Non-looped pass:** `/openspec-story-resume <initiative> <story-slug>` |
| `🟣 IN REVIEW` | Use the repair-or-review precedence above; fresh review is singular only when no repair condition exists and prerequisites are satisfied |
| `✅ DONE` with no `blocked.md` | `/openspec-archive <initiative> <story-slug>` when quick archive gates look satisfied; otherwise use the singular evidence-owner route below |
| Unknown status value | Operator decision: inspect `story.md` and normalize through the owning command; do not guess |

Quick archive-gate routing for `✅ DONE`:

- If `## PR State` shows requested changes or actionable unabsorbed PR feedback, recommend `/openspec-feedback <initiative> --pr <pr-url>`.
- If `## PR State` shows an open PR without requested changes and the evidence is fresh/complete, recommend waiting for PR review. If that evidence is stale or incomplete, recommend only `/openspec-pr <initiative> <story-slug>` to refresh it.
- If latest implementation review approval is missing or unclear, recommend a completely fresh `/openspec-story-review <initiative> <story-slug>` session.
- If `Status: ✅ DONE` contradicts unchecked tasks or incomplete/stale implementation evidence, recommend only a completely fresh `/openspec-story-review <initiative> <story-slug>` session so review owns reconciliation. Never route this contradiction to claim or resume.
- Otherwise recommend `/openspec-archive <initiative> <story-slug>` and note that archive performs the authoritative preflight and may ask for no-PR confirmation.

## Phase 4 — Multi-Story Output

When `--all` is supplied:

1. Resolve the initiative or all active changes under `openspec/changes/`.
2. Apply the same routing rules independently to each active, non-archived story.
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

For a scalar route, put the selected value on the `Suggested next action:` line and omit the three dual-route lines. For a planning or implementation workflow decision, leave that label empty and render immediately `- Converge wrapper: <command>`, `- Non-looped pass: <state-correct command>`, and `Choose one; do not run both.` The Converge wrapper delegates the direct review/resume or claim/resume passes. Never offer that choice for blocked, malformed/ambiguous, incomplete/non-reviewable scaffold, missing-workspace, PR, archive, wait, or terminal routes. For IN REVIEW, use a scalar repair owner when a named deficiency exists; use the planning dual route only for a complete/reviewable scaffold and a change plan-converge can orchestrate. Recommend a fresh oblivious `/openspec-story-review` only when review has not yet run against the current evidence and all prerequisites are satisfied; the wrapper never launches implementation review.

For other operator decisions, make the prompt concrete, for example: `rerun with INITIATIVE=<slug> STORY=<story-slug>` or `resolve/remove openspec/changes/<story>/blocked.md`. Select PR, archive, wait, and terminal suggestions from current evidence rather than presenting them as a multi-route choice.
