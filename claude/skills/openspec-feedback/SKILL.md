---
name: openspec-feedback
description: Absorb structured review/tool, PR, or reviewer feedback into an OpenSpec initiative by routing it to story edits, review rework, story candidates, or initiative-level decisions. Use when feedback needs to be incorporated without bloating or drifting stories.
disable-model-invocation: true
argument-hint: "<initiative-slug> [--pr <pr-url>] [--latest|--all] [--since <source-id>] [feedback-or-file]"
allowed-tools: Read Edit Grep Glob Bash(gh pr view:*) Bash(gh api:*) Bash(date -u:*) Bash(printf:*) Bash(sha256sum:*) Bash(shasum:*)
---

# OpenSpec Feedback

Absorb structured feedback into one OpenSpec initiative without turning PR reviews or tool output into messy story prose. This command classifies each feedback item first, shows a lightweight acknowledgement plan, then applies the smallest coordination-doc edits needed to preserve story intent, feedback provenance, and the story's planning lane.

Argument: `$ARGUMENTS` — `<initiative_slug> [--pr <pr_url>] [--latest|--all] [--since <source_id>] [feedback_or_file]`. The initiative slug is required by argument or explicit menu selection. PR mode defaults to the latest unabsorbed actionable feedback item.

## Important

This command may edit coordination documents only:

- `<initiative>/initiative.md` (Feedback Absorption Log, Feedback-Derived Story Candidates, Feedback-Derived Decisions)
- non-archived change workspace artifacts under `openspec/changes/<story-slug>/`:
  - `story.md` (contract sections, Plan lane, story-local receipt, Plan Review Log)
  - `design.md` (when design sources or element trace are affected)
  - `reviews.md` (implementation review entries)
  - `progress.md` (replanning checkpoints when contract changes during resume)

It never touches product source code, tests, configs, archived change workspaces, `CONTRACT.md`, worktrees, branches, or GitHub PR bodies. It never creates a full new change workspace. New work discovered from feedback becomes a feedback-derived story candidate in the initiative; `/openspec-story-plan` owns full story planning.

There is no dry-run mode. Normal operation is:

```text
classify feedback -> show absorption plan -> operator acknowledgement -> apply edits
```

## Why initiative-scoped

Feedback often spans several stories. Selecting a story before classification recreates the failure mode this command exists to avoid. The initiative is the routing boundary; each feedback item is then classified into the right destination.

`## Feedback Absorption Log` in `initiative.md` answers: "where did this feedback go and why?"

`reviews.md` answers: "what is wrong with this story implementation and what must be fixed?" (standalone artifact, same schema as existing ADD Review Log).

`## Plan Review Log` in `story.md` answers: "what planning contract concerns must be resolved before implementation continues?"

`Plan:` header in `story.md` answers: "is the story contract ready to implement, or does it need planning rework?"

## Phase 0 — Resolve initiative and intake

1. Parse `$ARGUMENTS`.
   - Accept an initiative slug matching a directory under `<cwd>/openspec/initiatives/`.
   - Accept `INITIATIVE=<slug>` as an equivalent selector.
   - Accept `--pr <url>`, `PR_URL=<url>`, or a bare GitHub PR URL as PR pointer mode.
   - Accept `--latest` (default), `--all`, and `--since <source_id>`.
   - Treat remaining text as feedback payload unless it resolves to a readable file path.
2. Resolve the initiative:
   - If an initiative slug was provided, validate it matches `^[a-z0-9]+(?:-[a-z0-9]+)*$` before resolving any path. If it fails, abort with: `invalid initiative slug; use lowercase hyphenated slug characters only`.
   - Then validate that `<cwd>/openspec/initiatives/<slug>/initiative.md` exists.
   - If omitted, list every directory under `<cwd>/openspec/initiatives/` with an `initiative.md`, then ask the operator to pick by number or slug. This is explicit menu selection, not inference. Validate the selected slug against the same canonical slug rule before resolving any path.
   - If no initiatives exist, stop and tell the operator to run `/openspec-epic-plan` first.
3. Read the project guidance before making recommendations:
   - `AGENTS.md`, then `CLAUDE.md` as fallback when present.
   - `<initiative>/initiative.md`.
   - Existing `## Feedback Absorption Log`, if present, to collect already-absorbed source IDs.
4. Determine intake mode:
   - **PR pointer mode** when a PR URL is present.
   - **Payload mode** when pasted feedback or a feedback file is present.
     If the remaining argument resolves to a readable file path, ask the operator: `Read <path> as feedback source? [y/N]` before reading. If declined, treat the path as literal feedback text instead.
   - If neither is present, ask the operator to paste feedback or pass `--pr <pr-url>`.

## Phase 1 — Gather feedback sources

In PR pointer mode:

1. Parse the PR URL into `<owner>`, `<repo>`, and `<number>`.
2. Query GitHub with `gh`:
   - `gh pr view <url> --json number,title,url,state,reviewDecision,updatedAt`
   - `gh api repos/<owner>/<repo>/issues/<number>/comments --paginate`
   - `gh api repos/<owner>/<repo>/pulls/<number>/reviews --paginate`
   - `gh api repos/<owner>/<repo>/pulls/<number>/comments --paginate`
3. Normalize all human-visible feedback sources into one timeline:
   - PR conversation comments → `github_issue_comment`
   - submitted review bodies → `github_pr_review`
   - inline review comments → `github_pr_review_comment`
4. For every source, keep:
   - stable source id: prefer `node_id`; fallback to `<type>:<id>`
   - source URL: `html_url` when available
   - author
   - created timestamp
   - updated timestamp
   - body text
   - review state, path, line, and diff hunk when available
5. Exclude:
   - sources already present in the initiative `Feedback Absorption Log`
   - empty comments and empty review bodies, unless the review state itself is the only signal and it requests changes
   - non-actionable acknowledgements such as "thanks", "LGTM", "done", or "rebase only"
6. Select feedback:
   - `--latest`: choose the newest unabsorbed actionable item by `updated_at`, using `created_at` as a tie-breaker.
   - `--all`: process every unabsorbed actionable item.
   - `--since <source_id>`: find that source in the absorption log, then process unabsorbed actionable items updated after that source's recorded updated timestamp. Stop if the source ID is unknown.

If `gh` is unavailable or the PR cannot be queried, stop and ask the operator to paste the relevant feedback. Do not scrape GitHub with ad-hoc unauthenticated requests.

In payload mode:

1. If the remaining argument is a readable file path, read that file and record its path as `Source path`.
2. Otherwise treat the remaining argument or pasted text as the feedback payload and set `Source path` to `manual-paste`.
3. Split the payload into feedback items by explicit IDs, headings, bullets, review comments, or clear topic boundaries.
4. For each item, compute a stable `Content hash` as `sha256:<hex>` over the item's normalized text (trim surrounding whitespace, normalize CRLF to LF, preserve internal wording). Use an allowed hash command such as `printf %s '<normalized-item-text>' | sha256sum` (or `shasum -a 256`) so the hash is reproducible. Use a synthetic source id of `manual:<hash-prefix>:<ordinal>` (for example `manual:sha256-1a2b3c4d5e6f:1`) unless the payload already includes a stable source URL or ID. Do not use timestamps as the only manual/file source identity.
5. Preserve a short, safe excerpt from the item as `Evidence` and in the initiative absorption log so dedupe/audit can reconstruct what was absorbed without pasting the full payload.

## Phase 2 — Normalize feedback items

Allocate feedback IDs from the initiative namespace:

```text
FB-001, FB-002, ...
```

Continue after the highest existing `FB-###` in the initiative `Feedback Absorption Log`. For each item, build this working record:

```md
- Feedback ID: FB-###
- Source type: github_issue_comment | github_pr_review | github_pr_review_comment | manual
- Source ID: <stable source id>
- Source URL: <url or n/a>
- Source path: <file path | manual-paste | n/a>
- Content hash: <sha256:... for manual/file payloads, or n/a for GitHub items unless useful>
- Created: <timestamp or n/a>
- Updated: <timestamp or n/a>
- Summary: <one sentence>
- Evidence: <short excerpt or source-local fact, not a long paste>
- Affected paths: <paths mentioned by the feedback, if any>
- Candidate stories: <change workspace slugs that may be affected>
- Risk / miss category: <async/event-loop | platform/API failure | behavior-vs-mechanics proof | design trace extraction | semantic invariant naming | security | persistence | resource lifecycle | other | none>
- Actionability: actionable | non_actionable | ambiguous
```

When a feedback item is ambiguous, ask one focused question before classification. Do not guess a target story just because it is the most recent story in the initiative. When feedback exposes an escaped miss, classify the recurring miss category so the initiative log can feed future planning, review, tests, lint/static checks, and skill updates without bloating the target story with process-retrospective detail.

## Phase 3 — Classify targets and draft absorption plan

Story identification is by change workspace slug under `openspec/changes/<slug>/`. There is no MASTER.md tracker table — discover candidate stories from initiative.md sections (Story Candidates, resources), existing change workspace directories, and explicit links in the feedback.

### Canonical slug and containment gate

Before reading or writing any story workspace from discovered feedback, initiative text, PR metadata, or operator correction:

1. Validate every candidate `<story-slug>` against `^[a-z0-9]+(?:-[a-z0-9]+)*$`. Reject slugs with path separators, whitespace, `..`, absolute paths, URL fragments, or any other non-canonical shape.
2. Resolve only `<workspace_root>/openspec/changes/<story-slug>/`; never concatenate raw feedback text or corrected target text into a path before validation.
3. Confirm the resolved directory exists, contains `story.md`, is not under `openspec/changes/archive/`, and remains contained under `<workspace_root>/openspec/changes/` after resolution.
4. If an acknowledged operator redirect names an invalid, missing, archived, or non-contained target, stop and ask for a canonical non-archived story slug or choose a non-story disposition (`new-story-candidate`, `initiative-level-decision`, or `defer-or-reject`).

Use the story intent test before editing any story. A feedback item may amend an existing story only when all are true:

1. Same user or system outcome.
2. Same acceptance boundary.
3. Same implementation ownership area.
4. Can be completed without changing the story's core scope.

Classify each actionable feedback item into exactly one disposition:

| Disposition | Use when | Target |
|---|---|---|
| `queue-planning-feedback` | Feedback clarifies a story that is still in planning, or should re-enter planning review before implementation continues. | `story.md` → `## Plan Review Log`, `Plan:` lane, plus initiative absorption log. |
| `amend-existing-story` | Rare direct amendment explicitly acknowledged by the operator outside a planning or implementation feedback cycle. | `story.md` contract sections (+ `design.md` when needed), `Plan:` lane invalidation when the contract changes, story-local receipt, initiative absorption log. |
| `resume-current-story` | Implemented work misses the current story or PR review requests rework for it. | `reviews.md` (implementation review entry), `story.md` contract edits when needed, `progress.md` replanning checkpoint when contract changes, `Plan:` lane invalidation when the contract changes, story-local receipt, initiative absorption log. |
| `new-story-candidate` | Feedback introduces a new outcome, dependency, rollout concern, or hardening task. | Initiative candidate section plus absorption log. |
| `initiative-level-decision` | Feedback changes an initiative policy, architectural choice, or cross-story rule. | Initiative decision notes plus absorption log. |
| `defer-or-reject` | Feedback is out of scope, duplicate, non-actionable, or intentionally declined. | Initiative absorption log only. |

Read only the change workspace artifacts needed to classify plausible targets. Prefer explicit evidence from:

- source links or story slugs in the feedback
- initiative.md story candidates and external resources
- `## PR State` URLs in `progress.md` (when present)
- matching acceptance IDs, paths, or scope language in `story.md`
- existing `reviews.md` or `## Plan Review Log` entries when they directly mention the same issue

Status and lane rules:

- Do not edit archived change workspaces under `openspec/changes/archive/`.
- Do not route to, read as writable, or create paths for a story target that failed the canonical slug and containment gate.
- Do not rewrite a `✅ DONE` story's product contract. Convert feedback to a candidate, initiative-level decision, or defer/reject entry unless the operator explicitly decides the completed story must be reopened through the normal lifecycle.
- Do not transition implementation `Status` in `story.md` from this command.
- You may downgrade or invalidate the `Plan:` header field in `story.md`, but this command must never set `Plan:` to `🟢 PLAN APPROVED`:
  - `queue-planning-feedback` sets `Plan:` to `🟠 PLAN CHANGES REQUESTED`.
  - contract-changing `amend-existing-story` sets `Plan:` to `🟠 PLAN CHANGES REQUESTED` after the contract edits are blended and validation passes, because fresh `/openspec-story-plan-review` must independently approve the changed contract before implementation resumes.
  - contract-changing `resume-current-story` sets `Plan:` to `🟠 PLAN CHANGES REQUESTED` after the contract edits are blended and validation passes, because fresh `/openspec-story-plan-review` must independently approve the changed contract before implementation resumes.
  - if contract feedback cannot be fully blended, set `Plan:` to `🟠 PLAN CHANGES REQUESTED` and make `/openspec-story-plan-resume` the next action.
- Write `## Plan Review Log` in `story.md` only for `queue-planning-feedback`; `/openspec-story-plan-review` remains the owner of independent review verdicts and the only command that may set `Plan:` to `🟢 PLAN APPROVED`.
- Write to `reviews.md` (standalone artifact) only for schema-compatible implementation-review feedback that should drive immediate story resume or PR rework.

Draft the acknowledgement plan:

```md
## Proposed Feedback Absorption

| Feedback ID | Source | Disposition | Target | Planned edit | Rationale |
|---|---|---|---|---|---|
| FB-001 | PR #42 comment IC_... | queue-planning-feedback | <story-slug> | Plan Review Log + Plan lane | Same story, planning contract needs rework. |
| FB-002 | PR #42 review PRRC_... | resume-current-story | <story-slug> | reviews.md | Implementation misses existing A2. |
| FB-003 | PR #42 comment IC_... | new-story-candidate | initiative.md | Candidate only | New audit logging outcome. |
```

## Phase 4 — Acknowledgement checkpoint

Show the proposed absorption plan and ask for acknowledgement:

```text
Acknowledge this absorption plan, or list target/disposition corrections.
```

This is not a broad confirmation ritual and not a dry-run mode. The operator may:

- acknowledge the plan
- skip specific feedback IDs
- redirect a feedback ID to another story or disposition
- ask one clarifying question

Do not edit files before acknowledgement. If the operator changes routing, revise the plan once and ask for acknowledgement again.

## Phase 5 — Apply coordination edits

Apply the acknowledged plan with minimal edits. Construct all edits in memory first. Run the validation gate below for every disposition that edits story spec/proof sections (`amend-existing-story` and contract-changing `resume-current-story`) before writing to disk. Dispositions that only append logs write directly without validation.

### Validation gate (story spec/proof edits only)

After constructing story spec/proof edits and before writing, run these phases in order. Read the story's original sections so the before/after diff is available. Phase A is the same story-plan validation gate used by `/openspec-story-plan-resume` for Acceptance, Verification, TAP, scenarios, actors, design trace, input-boundary, fail-open, and risk-lens edits; Phases B and C add feedback-specific preservation and red-first checks.

**Phase A — Structural checks.** Verify:
1. Every acceptance bullet starts with `A<n>:`.
2. `## Verification` contains `### Verification Commands`, `### Test Architecture Plan`, and `### Acceptance Proof Matrix` subsections.
3. The Test Architecture Plan uses stable `TAP-*` row ids and required columns: `Row ID | Layer / Scope | Behavior / Acceptance Slice | Owning Suite / File(s) | Boundary Exercised | Assertions / Observability | Fixture / Test Data Strategy | CI Lane / Command | Fallback Plan | Split / Merge Rationale`.
4. The Test Architecture Plan covers every added/changed test or proof surface introduced or affected by the feedback and satisfies the TAP quality gate: stable `TAP-*` ids, cheapest reliable real boundary, exact seam, behavior-facing assertion/observable signal, fixture/data isolation and live-dependency policy, focused command/CI lane, fallback plan, and split/merge rationale.
5. The proof matrix uses the required columns: `Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail`, and references relevant `TAP-*` row ids when tests or proof surfaces change.
6. Every `A<n>` appears in at least one proof row.
7. `Proof Maturity` is `final` or `provisional` only.
8. Every `provisional` row has non-blank `Open Detail`.
9. No `<TODO: ...>` placeholders in `## Acceptance` or `## Verification`.
10. If `## Actors` is present, it uses role bullets with at least one `Primary:` actor and stays consistent with Purpose, Scope, Scenarios, Acceptance, and Verification.
11. If feedback changes who initiates, participates in, reviews, or is affected by the behavior, the edit updates `## Actors` in `story.md` or records an explicit non-change rationale before writing.
12. If feedback changes concrete flows or examples, the edit updates `## Scenarios / Behavior Examples` in `story.md` or records an explicit non-change rationale before writing.
13. If `## Scenarios / Behavior Examples` is present, every normative `S<n>` scenario has exactly one `Covers: A<n>` and every orientation-only scenario says `Orientation only`.
14. Every normative scenario funnels through Acceptance and Verification: the covered `A<n>` wording includes the scenario behavior, and that acceptance id has proof row(s) covering the scenario, including named variants, modes, branches, fallback paths, and failure cases or explicit exclusions.
15. If the story spans surfaces, supported variants, modes, or internal orchestration branches, `### Surface / Branch Proof Matrix` exists and covers every in-scope combination or records an explicit exclusion.
16. If feedback introduces, changes, or exposes a design source, `### Design Sources` exists with durable/reviewable anchors and every source is marked `normative` or `orientation only`. Updates to design sources go into `design.md` when that artifact exists alongside `story.md`.
17. If any design source is `normative`, `### Design Element Trace` exists; every feedback-mentioned or obvious visible element/state from the normative source is mapped as `required` or bounded `flexible`; every trace row maps through Scenario → Acceptance → Verification/proof row; and visibility, placement, navigation, copy, responsive, or interaction-state obligations name rendered-surface proof or an explicit exception.
18. If raw persisted, external, framework, or generated input crosses stricter application assumptions, `### Input Boundary Shape Risk` exists when needed and covers every in-scope boundary/shape case or records an explicit exclusion/unknown with mitigation.
19. If prompt placeholders, template variables, or string substitution can fail open, `### Fail-open Checks` exists and covers enabled and disabled/default paths.
20. If feedback introduces or exposes an activated risk lens, the amended contract covers it through existing matrices or `### Risk Lens Inventory` with proof obligations or explicit exclusions.
21. Planned proof remains behavior-centered: private retry counts, sleeps, helper call order, timing, or implementation choreography are contractual only when explicitly locked.

**Phase B — Contract-preservation diff.** Compare the edited sections against the originals:
- Every pre-existing `A<n>` still appears in at least one proof row in the edited version (coverage match — row shape may change).
- Pre-existing `## Out of Scope` items have not been silently pulled into `## Scope` without explicit override.
- Pre-existing `### Design Sources` anchors/statuses and `### Design Element Trace` rows in `design.md` or `story.md` have not been silently removed, downgraded, or loosened unless the feedback explicitly overrides them and the operator confirms.
- Pre-existing `## Locked Decisions` in `story.md` have not been removed unless the feedback explicitly overrides them and the operator confirms.

**Phase C — Red-first seam alignment.** When `## Acceptance` or `## Scope` was edited and `## Implementation Notes` mentions a red-first seam:
- Show the planned seam and the amended acceptance criteria.
- Ask the operator: "Does this seam still cover the amended criteria?"
- Yes → proceed. No → block; operator must update `## Implementation Notes` before retrying.

**On failure:**
- Phase A → HARD BLOCK. Show the specific violation. Do not write. Operator revises the absorption plan or story edits before retrying.
- Phase B → SOFT BLOCK. Show the pre-existing commitment being removed. Operator may override with explicit acknowledgement, or revise the edits to restore the commitment.
- Phase C → HARD BLOCK. Operator must update `## Implementation Notes` with a corrected seam, then retry.

After all phases pass, proceed to write the edits to disk. Then add the story-local receipt and initiative-level entry.

For contract-changing `resume-current-story`, also append a concise replanning checkpoint to `progress.md → ## Progress Timeline` before `/openspec-story-resume` runs:

```md
- <UTC ISO timestamp> Replanning checkpoint from feedback absorption
  - Feedback ID: FB-###
  - Contract sections updated: <Actors, Scenarios / Behavior Examples, Acceptance, Verification, Surface / Branch Proof Matrix, Design Sources, Design Element Trace, Input Boundary Shape Risk, Risk Lens Inventory, etc.>
  - Risk / miss category: <category or none>
  - Plan lane: <from> → <to>
  - Required next action: `/openspec-story-plan-review <initiative> <story-slug>`
```

For `queue-planning-feedback`, append or create `## Plan Review Log` in `story.md` with a request-changes entry and update the `Plan:` header field to `🟠 PLAN CHANGES REQUESTED`. Do not edit story spec sections in this disposition.

```md
- <UTC ISO timestamp> Planning feedback routed by `/openspec-feedback`
  - Source: <source URL or source ID>
  - Feedback ID: FB-###
  - Verdict: request_changes
  - Plan lane transition: <from> → 🟠 PLAN CHANGES REQUESTED
  - Status transition: <current status> → <current status>
  - Sections reviewed: <Actors, Scenarios / Behavior Examples, Acceptance, Verification, Design Sources, Design Element Trace, Scope, Locked Decisions, etc.>
  - Key findings:
    - <finding, including required matrix/proof updates when relevant>
  - Debt Friction: none | <decision + short title>
  - Next action: `/openspec-story-plan-resume <initiative> <story-slug>`
```

For `amend-existing-story`, edit only these story sections inside `story.md`:

- `## Acceptance`
- `## Verification` (including conditional subsections such as `### Design Sources` and `### Design Element Trace` — note that design sources and element trace may also live in `design.md`, so also edit `design.md` when needed)
- `## Actors`
- `## Scenarios / Behavior Examples`
- `## Scope`
- `## Out of Scope`
- `## Critical Files`
- `## Implementation Notes`
- `## Discovery Notes`
- `## Locked Decisions`

Also edit `design.md` when the amendment changes `### Design Sources` anchors/statuses or `### Design Element Trace` rows that live there rather than in `story.md`.

Keep story-body edits as the durable contract change. If the amendment changes any contract/proof section, update the `Plan:` header field in `story.md` to `🟠 PLAN CHANGES REQUESTED` and make `/openspec-story-plan-review` the next action. Then add a tiny story-local receipt in `story.md`:

```md
## Feedback Absorption Log
- FB-001: amended `Acceptance`, `Verification`, and affected `Design Element Trace` rows from <source>. See initiative log.
```

For `resume-current-story`, append to `reviews.md` (the standalone review artifact in the change workspace) using the implementation-review schema. Keep the feedback provenance fields and include the canonical traceability/evidence fields so later resume and review sessions can reconstruct what was checked:

```md
- <UTC ISO timestamp> Review feedback absorbed from PR
  - Source: <source URL or source ID>
  - Feedback ID: FB-###
  - Decision: request_changes
  - Approval gate: fail
  - Product verdict: approve | request_changes | reject | not_assessed
  - Technical verdict: approve | request_changes | reject | not_assessed
  - Multipass review: not_triggered
  - Prior review concerns: not_assessable
  - Plan lane at review time: <value or absent>
  - Initiative contract drift: none | present
  - Status transition: <current status> → <current status>
  - Sections reviewed: <story sections checked against the feedback, or n/a>
  - Original intent checked: <issues/PRs/Jira/tickets/initiative sources or none found/inaccessible>
  - Traceability: forward <complete|gaps>; backward <complete|gaps>
  - Design trace: complete|gaps|not applicable; rendered evidence: complete|gaps|not applicable
  - Code surfaces searched: <paths/patterns/entrypoints or none beyond feedback scope>
  - Risk / miss category: <category or none>
  - Risk lenses reviewed: <activated lenses and exclusions, or none material>
  - Finding closure required: <disposition + fix proof + regression/side-effect check>
  - Evidence quality: confirmed <short>; inferred <short|none>; unknown <short|none>; provisional <short|none>
  - Files reviewed: <paths or n/a>
  - Hypothesis triage:
    - suspicious surface: <feedback source/code/API/flow>; tentative issue: <possible failure from the feedback>; next proof target: <source/test/proof to check>
  - Key findings:
    - <finding summary> Sources: `<source URL, source ID, or path:line>`

      <details open>
      <summary><b>SEVERITY_LABEL</b> severity · <b>LIKELIHOOD_LABEL</b> likelihood</summary>

      **Why:** <operator-facing reason>

      **Assumptions / Preconditions:** <required conditions, or `None.`>

      **Downgrade Factors:** <confidence/impact reducers, or `None.`>

      **Code Trail:** <grounded path from cited evidence to conclusion>

      **Reproduction:** <brief reproduction narrative, or `Not applicable.`>

      </details>
  - Debt Friction: none | <decision + short title>
  - Next action: <one concrete resume/rework action>
```

If feedback changes actors, scenarios, acceptance boundaries, proof surfaces, design sources, design element obligations, supported branches, input-boundary shape assumptions, fail-open risks, or activated risk lenses, fully blend those changes before recommending `/openspec-story-resume`:

- update `## Actors` in `story.md` when feedback changes who initiates, participates in, reviews, or is affected by the behavior
- update `## Scenarios / Behavior Examples` in `story.md` when feedback changes concrete flows or examples; every normative scenario must use exactly one `Covers: A<n>` and funnel into Acceptance and Verification
- update `## Acceptance` and `## Verification` in `story.md` together
- update `### Acceptance Proof Matrix` for every acceptance id and named variant/failure mode
- update `### Surface / Branch Proof Matrix` when surfaces, variants, modes, or orchestration branches are introduced or changed
- update `### Design Sources` in `design.md` (or `story.md` when it lives there) when feedback introduces, changes, supersedes, or reclassifies a design artifact; anchors must be durable/reviewable and every source must be marked `normative` or `orientation only`
- update `### Design Element Trace` when feedback exposes unmapped or changed normative visible elements/states; use only `required` or bounded `flexible`, do not add an `omitted`/`ignored` class for accepted normative designs, map every row through Scenario → Acceptance → Verification/proof row, and require rendered-surface proof for visibility, placement, navigation, copy, responsive behavior, and interaction-state obligations unless an explicit exception is recorded
- update `### Input Boundary Shape Risk` when raw input shape assumptions are introduced or changed
- update `### Fail-open Checks` when prompt/template fail-open risks are introduced or changed
- update or add `### Risk Lens Inventory` when feedback exposes async/event-loop, platform/API, external I/O, permissions/security, resource lifecycle, retries/timeouts, semantic invariant, or other domain risks not already covered
- append the replanning checkpoint to `progress.md → ## Progress Timeline`
- set `Plan:` header field in `story.md` to `🟠 PLAN CHANGES REQUESTED` after the validation gate passes and make `/openspec-story-plan-review` the next action; this command cannot approve its own contract edits

When contract/proof edits are fully blended, `/openspec-story-plan-review <initiative> <story-slug>` is mandatory before `/openspec-story-resume`. If plan review requests changes, the story re-enters the plan-converge loop through `/openspec-story-plan-resume` until `Plan:` returns to `🟢 PLAN APPROVED`.

Do not delete or rewrite older `reviews.md` entries. If the story is `🔵 IN PR`, do not update `## PR State` in `progress.md` here; recommend `/openspec-story-pr` refresh when the PR status itself must move the story back to `🔄 IN PROGRESS`.

For `new-story-candidate`, append or create this initiative-level section in `initiative.md`:

```md
## Feedback-Derived Story Candidates

### FB-### — <short title>
- Source: <source URL or source ID>
- Origin: <story slug or PR URL>
- Reason: <why this is separate from existing stories>
- Proposed story: <one-sentence user/system outcome>
- Acceptance sketch:
  - <one or two objective outcomes>
- Recommended next command: `/openspec-story-plan INITIATIVE="<slug>"` and reference `FB-###` during the interview
```

For `initiative-level-decision`, append to an existing initiative decision section if one exists. Otherwise create in `initiative.md`:

```md
## Feedback-Derived Decisions

### FB-### — <short title>
- Source: <source URL or source ID>
- Decision: <pithy decision>
- Rationale: <why this belongs at initiative level>
- Applies to: <stories or initiative-wide>
```

For every disposition, append one canonical row to `<initiative>/initiative.md` under `## Feedback Absorption Log`:

```md
## Feedback Absorption Log

| ID | Source Type | Source ID | Source URL | Source Path | Content Hash | Created | Updated | Excerpt | Disposition | Target | Changed | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| FB-001 | github_pr_review_comment | PRRC_... | https://... | n/a | n/a | 2026-04-28T10:40:00Z | 2026-04-28T11:05:00Z | "short excerpt" | resume-current-story | <story-slug> | reviews.md; miss-category=platform/API failure | absorbed |
| FB-002 | manual | manual:sha256-1a2b3c4d5e6f:1 | n/a | docs/review-notes.md | sha256:1a2b3c4d5e6f... | n/a | n/a | "short excerpt" | queue-planning-feedback | <story-slug> | Plan Review Log | absorbed |
```

Preserve existing rows, including older 10-column rows. When the section already has the older column shape, either extend the header once before adding new rows or append a clearly marked v2 table below the existing rows. If the section does not exist, add it after `## External Resources` unless a local initiative convention clearly places operational logs elsewhere.

## Phase 6 — Final response

Report:

- feedback IDs processed
- files changed (with full paths under `openspec/`)
- disposition and target for each item
- any items skipped or left ambiguous
- recurring risk / miss categories observed, or none
- exact next command when relevant, such as `/openspec-story-resume`, `/openspec-story-pr`, or `/openspec-story-plan`

When `amend-existing-story` touched any contract/proof section, include in the response:
"Required next: run `/openspec-story-plan-review <initiative> <story-slug>` from a fresh session to re-validate the amended plan."

Keep the response short. Do not paste long feedback bodies; link or cite source IDs instead.
