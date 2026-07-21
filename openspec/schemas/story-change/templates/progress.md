# Progress: <change-slug>

## Current Claim
<!-- Exactly one Active Claim section per session.
     Written by /openspec-story-claim and /openspec-story-resume.
     Do not add a persisted OpenSpec artifact-root field. Worktrees below are
     execution bindings for individual repositories, not artifact authority.
     Delivery derives repository roots from the complete bounded Worktrees and
     Primary write surfaces map: labels/absolute roots must be unique, every
     surface must map to exactly one listed root without escape, and missing or
     ambiguous mappings fail closed. PR requires exactly one resolved product
     repo; explicit no-PR archive audits every resolved product repo. -->
- Claimed at:
- Claimed by: <fresh / continuation> session
- Model: <model name>
- Scope: <one sentence for this work chunk>
- Worktrees:
  - <repo-basename>: <absolute path>
- Main-tree targets: <repo-basename>, <repo-basename>
- Primary write surfaces: <paths>
- Status: 🔄 IN PROGRESS | 🟣 IN REVIEW | ✅ DONE | ⛔ BLOCKED

## Progress Timeline
<!-- Append-only timestamped bullets recording meaningful milestones.
     Written by `/openspec-story-claim`, `/openspec-story-resume`,
     `/openspec-feedback`, and `/openspec-pr`. Readonly implementation review
     does not own this timeline. -->

## Session Handoff
<!-- Refreshed at the end of every session. Only the most recent entry is authoritative. -->
- Status: ⚪ TODO | 🔄 IN PROGRESS | 🟣 IN REVIEW | ✅ DONE | ⛔ BLOCKED
- What changed: <short bullets>
- Files touched: <paths>
- Red-first path: <focused seam + red/green outcome, or explicit exception + alternative proof path>
- Tests run: <commands/results or not run>
- Acceptance proof coverage: <all acceptance ids and named variants covered | gaps/exclusions listed>
- Risk-lens self-check: <activated lenses checked, exclusions, or none material>
- Finding closure: <review/feedback findings fixed with proof and regression check, or none>
- Remaining work: <short bullets>
- Unresolved Debt Friction: <split-story / defer-explicitly / block / unfinished fix-now entries, or none>
- Blockers / risks: <short bullets>
- Exact next step: <one concrete recommendation>

## PR State
<!-- Written by `/openspec-pr`. There is exactly one PR State section. -->
- PR URL:
- Number:
- Title:
- Branch:
- Delivery head: <sha from clean current Git HEAD equal to live PR headRefOid>
- Opened at:
- PR status: open | changes_requested | approved | merged | closed
- Review decision: <APPROVED | CHANGES_REQUESTED | REVIEW_REQUIRED | blank | unavailable>
- Merge commit: <sha or "—">
- Merged at: <UTC ISO timestamp or "—">
- Last synced:

## Unresolved Debt Friction
<!-- Carried forward entries: split-story, defer-explicitly, block, or unfinished fix-now. -->
- None.
