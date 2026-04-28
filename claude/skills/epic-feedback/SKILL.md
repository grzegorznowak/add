---
name: epic-feedback
description: Absorb CURe, PR, or reviewer feedback into an epic by routing it to story edits, review rework, story candidates, or epic notes. Use when feedback needs to be incorporated without bloating or drifting stories.
disable-model-invocation: true
argument-hint: "<epic-name-or-path> [--pr <pr-url>] [--latest|--all] [--since <source-id>] [feedback-or-file]"
allowed-tools: Read Edit Grep Glob Bash(gh pr view:*) Bash(gh api:*) Bash(date -u:*)
---

# Epic Feedback

Absorb structured feedback into one epic without turning PR reviews or CURe output into messy story prose. This command classifies each feedback item first, shows a lightweight acknowledgement plan, then applies the smallest coordination-doc edits needed to preserve story intent and feedback provenance.

Argument: `$ARGUMENTS` - `<epic_name_or_path> [--pr <pr_url>] [--latest|--all] [--since <source_id>] [feedback_or_file]`. The epic is required by argument or explicit menu selection. PR mode defaults to the latest unabsorbed actionable feedback item.

## Important

This command may edit coordination documents only:

- `<epic>/MASTER.md`
- non-archived story files under `<epic>/story-*.md`

It never touches product source code, tests, configs, archived story files, `CONTRACT.md`, worktrees, branches, or GitHub PR bodies. It never creates a full story file. New work discovered from feedback becomes a feedback-derived story candidate in the epic; `/epic-story-plan` owns full story planning.

There is no dry-run mode. Normal operation is:

```text
classify feedback -> show absorption plan -> operator acknowledgement -> apply edits
```

## Why epic-scoped

Feedback often spans several stories. Selecting a story before classification recreates the failure mode this command exists to avoid. The epic is the routing boundary; each feedback item is then classified into the right destination.

`## Feedback Absorption Log` answers: "where did this feedback go and why?"

`## Review Log` answers: "what is wrong with this story implementation and what must be fixed?"

## Phase 0 — Resolve epic and intake

1. Parse `$ARGUMENTS`.
   - Accept an epic directory name under `<cwd>/agent_coordination/epics/`.
   - Accept a direct path to an epic directory containing `MASTER.md`.
   - Accept `EPIC=<slug>` as an equivalent epic selector.
   - Accept `--pr <url>`, `PR_URL=<url>`, or a bare GitHub PR URL as PR pointer mode.
   - Accept `--latest` (default), `--all`, and `--since <source_id>`.
   - Treat remaining text as feedback payload unless it resolves to a readable file path.
2. Resolve the epic:
   - If an epic selector was provided, validate that `<epic>/MASTER.md` exists.
   - If omitted, list every directory under `<cwd>/agent_coordination/epics/` with a `MASTER.md`, then ask the operator to pick by number or slug. This is explicit menu selection, not inference.
   - If no epics exist, stop and tell the operator to run `/epic-plan` first.
3. Read the project guidance before making recommendations:
   - `AGENTS.md`, then `CLAUDE.md` as fallback when present.
   - `<epic>/MASTER.md`.
   - Existing `## Feedback Absorption Log`, if present, to collect already-absorbed source IDs.
4. Determine intake mode:
   - **PR pointer mode** when a PR URL is present.
   - **Payload mode** when pasted feedback or a feedback file is present.
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
   - PR conversation comments -> `github_issue_comment`
   - submitted review bodies -> `github_pr_review`
   - inline review comments -> `github_pr_review_comment`
4. For every source, keep:
   - stable source id: prefer `node_id`; fallback to `<type>:<id>`
   - source URL: `html_url` when available
   - author
   - created timestamp
   - updated timestamp
   - body text
   - review state, path, line, and diff hunk when available
5. Exclude:
   - sources already present in the epic `Feedback Absorption Log`
   - empty comments and empty review bodies, unless the review state itself is the only signal and it requests changes
   - non-actionable acknowledgements such as "thanks", "LGTM", "done", or "rebase only"
6. Select feedback:
   - `--latest`: choose the newest unabsorbed actionable item by `updated_at`, using `created_at` as a tie-breaker.
   - `--all`: process every unabsorbed actionable item.
   - `--since <source_id>`: find that source in the absorption log, then process unabsorbed actionable items updated after that source's recorded updated timestamp. Stop if the source ID is unknown.

If `gh` is unavailable or the PR cannot be queried, stop and ask the operator to paste the relevant feedback. Do not scrape GitHub with ad-hoc unauthenticated requests.

In payload mode:

1. If the remaining argument is a readable file path, read that file.
2. Otherwise treat the remaining argument or pasted text as the feedback payload.
3. Split the payload into feedback items by explicit IDs, headings, bullets, review comments, or clear topic boundaries.
4. Use a synthetic source id of `manual:<timestamp>:<ordinal>` unless the payload already includes a stable source URL or ID.

## Phase 2 — Normalize feedback items

Allocate feedback IDs from the epic namespace:

```text
FB-001, FB-002, ...
```

Continue after the highest existing `FB-###` in the epic `Feedback Absorption Log`. For each item, build this working record:

```md
- Feedback ID: FB-###
- Source type: github_issue_comment | github_pr_review | github_pr_review_comment | manual
- Source ID: <stable source id>
- Source URL: <url or n/a>
- Created: <timestamp or n/a>
- Updated: <timestamp or n/a>
- Summary: <one sentence>
- Evidence: <short excerpt or source-local fact, not a long paste>
- Affected paths: <paths mentioned by the feedback, if any>
- Candidate stories: <story numbers that may be affected>
- Actionability: actionable | non_actionable | ambiguous
```

When a feedback item is ambiguous, ask one focused question before classification. Do not guess a target story just because it is the most recent story in the epic.

## Phase 3 — Classify targets and draft absorption plan

Use the story intent test before editing any story. A feedback item may amend an existing story only when all are true:

1. Same user or system outcome.
2. Same acceptance boundary.
3. Same implementation ownership area.
4. Can be completed without changing the story's core scope.

Classify each actionable feedback item into exactly one disposition:

| Disposition | Use when | Target |
|---|---|---|
| `amend-existing-story` | Feedback clarifies the same story contract. | Story body plus absorption logs. |
| `resume-current-story` | Implemented work misses the current story or PR review requests rework for it. | Story `Review Log` plus epic absorption log. |
| `new-story-candidate` | Feedback introduces a new outcome, dependency, rollout concern, or hardening task. | Epic candidate section plus absorption log. |
| `epic-level-decision` | Feedback changes an epic policy, architectural choice, or cross-story rule. | Epic decision notes plus absorption log. |
| `defer-or-reject` | Feedback is out of scope, duplicate, non-actionable, or intentionally declined. | Epic absorption log only. |

Read only the story files needed to classify plausible targets. Prefer explicit evidence from:

- source links or story numbers in the feedback
- `MASTER.md` tracker rows
- `## PR Tracking` URLs
- matching acceptance IDs, paths, or scope language
- existing `Review Log` / `Plan Review Log` entries when they directly mention the same issue

Status rules:

- Do not edit archived story files.
- Do not rewrite a `✅ DONE` story's product contract. Convert feedback to a candidate, epic-level decision, or defer/reject entry unless the operator explicitly decides the completed story must be reopened through the normal lifecycle.
- Do not transition story statuses from this command.
- Do not write `## Plan Review Log`; that remains owned only by `/epic-story-plan-review`.
- Write `## Review Log` only for schema-compatible implementation-review feedback that should drive immediate story resume or PR rework.

Draft the acknowledgement plan:

```md
## Proposed Feedback Absorption

| Feedback ID | Source | Disposition | Target | Planned edit | Rationale |
|---|---|---|---|---|---|
| FB-001 | PR #42 comment IC_... | amend-existing-story | story-03 | Acceptance + Verification | Same acceptance boundary. |
| FB-002 | PR #42 review PRRC_... | resume-current-story | story-05 | Review Log | Implementation misses existing A2. |
| FB-003 | PR #42 comment IC_... | new-story-candidate | MASTER.md | Candidate only | New audit logging outcome. |
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

Apply the acknowledged plan with minimal edits.

For `amend-existing-story`, edit only these story sections:

- `## Acceptance`
- `## Verification`
- `## Scope`
- `## Out of Scope`
- `## Critical Files`
- `## Implementation Notes`
- `## Discovery Notes`
- `## Locked Decisions`

Keep story-body edits as the durable contract change. Then add a tiny story-local receipt:

```md
## Feedback Absorption Log
- FB-001: amended `Acceptance` and `Verification` from <source>. See epic log.
```

For `resume-current-story`, append to the story's `## Review Log` using the implementation-review schema:

```md
- <UTC ISO timestamp> Review feedback absorbed from PR
  - Source: <source URL or source ID>
  - Feedback ID: FB-###
  - Decision: request_changes
  - Approval gate: fail
  - Product verdict: approve | request_changes | reject | not_assessed
  - Technical verdict: approve | request_changes | reject | not_assessed
  - Epic contract drift: none | present
  - Status transition: <current status> -> <current status>
  - Files reviewed: <paths or n/a>
  - Key findings:
    - <short finding>
  - Debt Friction: none | <decision + short title>
  - Next action: <one concrete resume/rework action>
```

Do not delete or rewrite older `Review Log` entries. If the story is `🔵 IN PR`, do not update `## PR Tracking` here; recommend `/epic-story-pr` refresh when the PR status itself must move the story back to `🔄 IN PROGRESS`.

For `new-story-candidate`, append or create this epic-level section in `MASTER.md`:

```md
## Feedback-Derived Story Candidates

### FB-### - <short title>
- Source: <source URL or source ID>
- Origin: <story number or PR URL>
- Reason: <why this is separate from existing stories>
- Proposed story: <one-sentence user/system outcome>
- Acceptance sketch:
  - <one or two objective outcomes>
- Recommended next command: `/epic-story-plan EPIC="<epic>"` and reference `FB-###` during the interview
```

For `epic-level-decision`, append to an existing epic decision section if one exists. Otherwise create:

```md
## Feedback-Derived Decisions

### FB-### - <short title>
- Source: <source URL or source ID>
- Decision: <pithy decision>
- Rationale: <why this belongs at epic level>
- Applies to: <stories or epic-wide>
```

For every disposition, append one canonical row to `<epic>/MASTER.md` under `## Feedback Absorption Log`:

```md
## Feedback Absorption Log

| ID | Source Type | Source ID | Source URL | Created | Updated | Disposition | Target | Changed | Status |
|---|---|---|---|---|---|---|---|---|---|
| FB-001 | github_pr_review_comment | PRRC_... | https://... | 2026-04-28T10:40:00Z | 2026-04-28T11:05:00Z | resume-current-story | story-05 | Review Log | absorbed |
```

Preserve existing rows. If the section does not exist, add it after the story tracker unless a local epic convention clearly places operational logs elsewhere.

## Phase 6 — Final response

Report:

- feedback IDs processed
- files changed
- disposition and target for each item
- any items skipped or left ambiguous
- exact next command when relevant, such as `/epic-story-resume`, `/epic-story-pr`, or `/epic-story-plan`

Keep the response short. Do not paste long feedback bodies; link or cite source IDs instead.
