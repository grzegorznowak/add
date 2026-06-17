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
- `<reviews_file>` = `<change_dir>/reviews.md`.
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
- Story mode: `story.md` headers, `blocked.md` existence, and bounded evidence from `progress.md`, `reviews.md`, and `tasks.md` only when relevant to feedback, PR delivery evidence, DONE, or archive routing.
- Spec mode: the resolved path and its containing workspace or stable spec location.

Evidence to extract:

- `Plan:` from `story.md`.
- `Status:` from `story.md`.
- Whether `blocked.md` exists.
- Whether the story is active, archived, or missing.
- Whether `progress.md → ## PR State` indicates open, merged, or requested-changes PR feedback that affects archive or feedback routing.
- Whether the latest relevant `reviews.md` entry appears to record `Decision: approve` and `Approval gate: pass`.
- Whether `tasks.md` has obviously unchecked in-scope tasks when considering archive.
- Whether required planning scaffold files (`proposal.md`, `story.md`, `design.md`, `tasks.md`) exist when the plan is not approved.

Do not perform deep review. If the quick evidence is missing, stale, or conflicting, route to the owner command rather than trying to settle the verdict here.

## Phase 3 — Choose the Next Action

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
| Story is under `openspec/changes/archive/` | `None` for active lifecycle; use `/openspec-feedback <initiative>` for new input or plan a new story |
| `blocked.md` exists | Operator decision: resolve/remove `blocked.md`; then rerun `/openspec-next-action` |
| `Status: ⛔ BLOCKED` and no `blocked.md` | `/openspec-story-resume <initiative> <story-slug>` |
| `Plan: ⛔ PLAN BLOCKED` | Operator decision: resolve planning blocker, then `/openspec-story-plan-converge <initiative> <story-slug>` |

### Planning lane before implementation

If `Status:` is not `✅ DONE` and `Plan:` is not `🟢 PLAN APPROVED`, planning owns the next action.

| Plan lane / scaffold | Recommendation |
|---|---|
| Missing core planning files or malformed scaffold | `/openspec-story-plan-resume <initiative> <story-slug>` |
| `Plan:` absent, unset, or `🟡 PLAN DRAFT` | `/openspec-story-plan-review <initiative> <story-slug>` when scaffold exists; otherwise `/openspec-story-plan-resume <initiative> <story-slug>` |
| `Plan: 🟣 PLAN IN REVIEW` | `/openspec-story-plan-review <initiative> <story-slug>` |
| `Plan: 🟠 PLAN CHANGES REQUESTED` | `/openspec-story-plan-resume <initiative> <story-slug>` |
| Repeated plan review/resume uncertainty | `/openspec-story-plan-converge <initiative> <story-slug>` |

### Implementation, PR delivery, and archive after plan approval

Plan-approved means exactly `Plan: 🟢 PLAN APPROVED`.

| Status | Recommendation |
|---|---|
| Missing, unset, `⬜ TODO`, or `⚪ TODO` | `/openspec-story-claim <initiative> <story-slug>` |
| `🔄 IN PROGRESS` | `/openspec-story-resume <initiative> <story-slug>` |
| `🟣 IN REVIEW` | `/openspec-story-review <initiative> <story-slug>` |
| `✅ DONE` with no `blocked.md` | `/openspec-archive <initiative> <story-slug>` when quick archive gates look satisfied; otherwise route to the owner command named in the missing gate |
| Unknown status value | Operator decision: inspect `story.md` and normalize through the owning command; do not guess |

Quick archive-gate routing for `✅ DONE`:

- If `## PR State` shows requested changes or actionable unabsorbed PR feedback, recommend `/openspec-feedback <initiative> --pr <pr-url>`.
- If `## PR State` shows an unmerged PR without requested changes, recommend `/openspec-pr <initiative> <story-slug>` to refresh delivery evidence, or wait for PR review before archiving.
- If latest implementation review approval is missing or unclear, recommend `/openspec-story-review <initiative> <story-slug>`.
- If tasks are obviously unchecked, recommend `/openspec-story-resume <initiative> <story-slug>` or `/openspec-story-review <initiative> <story-slug>` depending on whether the gap is implementation work or review/status drift.
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
**Next Action**: <single exact command, operator decision, wait decision, or None>
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
| Story | Plan | Status | Gate | Recommended Next Action |
|---|---|---|---|---|
| <only when --all or ambiguity requires listing> |
```

When the next action is an operator decision, make the decision prompt concrete, for example: `rerun with INITIATIVE=<slug> STORY=<story-slug>`, `resolve/remove openspec/changes/<story>/blocked.md`, or `choose whether this locally DONE story needs PR delivery evidence before archive`.
