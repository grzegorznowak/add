---
description: Review one implemented epic step against its story spec
argument-hint: [EPIC="<epic_name>"] [STORY="<story_number_or_spec_file>"]
---

Review: $EPIC / $STORY

Treat `$EPIC` as the exact epic directory name under the agent's current
working directory at:
`agent_coordination/epics/`

Treat `$STORY` as the story selector. It may be either:
- the exact story number from the `Step` column in `<epic>/MASTER.md`, for
  example `03`
- the exact spec file name from the `Spec` column in `<epic>/MASTER.md`, for
  example `story-03-bootstrap-and-docs-rewrite.md`

You are a maintainer reviewing one epic story implementation against its step
spec, current repo state, and recorded handoff context.

This prompt is intended to work well from a fresh session. It can also be run
multiple times on the same step when review context already exists.

# Important 
You can only change the coordination files in the epic, never actual sourcecodes of the app
Review is inherently a read-only process

## Resolution
1. Resolve the epic directory as:
   - `<cwd>/agent_coordination/epics/$EPIC`
2. If `$STORY` is empty, abort fast and ask for `STORY` as either a `Step`
   value or a `Spec` value from `<epic>/MASTER.md`
3. Use `<epic>/MASTER.md` as the only lookup table
4. First try to match exactly one row whose `Step` value equals `$STORY`
5. If no row matches by `Step`, try to match exactly one row whose `Spec`
   value equals `$STORY`
6. If neither lookup finds a row, abort fast and report the unresolved selector
   plus the available `Step` and `Spec` values from `MASTER.md`
7. If the `Step` lookup and `Spec` lookup both match but point to different
   rows, abort fast and report the ambiguity
8. Resolve the step file as:
   - `<epic>/<matched row Spec value>`
9. If that path does not exist, abort fast and report the exact missing path.

## Read first
1. the main repo `AGENTS.md` for the repo you will touch
2. `<epic>/MASTER.md`
3. the resolved step file
4. dependency step files listed for the resolved step in `MASTER.md`

## Review intent
Do **not** rediscover the epic from scratch.

Your job is to:
1. understand the story spec in the resolved step file for `$STORY`
2. inspect the actual implementation and current worktree
3. review the implementation against the step spec and surrounding architecture
4. record the review result back into the coordination file

## Review readiness check
Before doing a full review:
- inspect the row for the resolved step in `MASTER.md`
- inspect any `Active Claim`, `Progress Log`, and `Session Handoff` sections in
  the step file

If the story is clearly not reviewable yet, abort fast with a concise reason.

Examples of not-reviewable:
- step is still `TODO` and there is no implementation/handoff evidence
- step is blocked by an unmet dependency and the code cannot be sensibly judged
- there is no credible mapping from the step spec to any code or tests yet

## Source-of-truth hierarchy
1. `<epic>/MASTER.md`
2. the resolved step file
3. dependency step files
4. actual code, tests, and worktree diff

Do not infer identity from filename shape or naming conventions that are not
explicitly recorded in `MASTER.md`.

## Review process
1. Use code research/search and direct code reading to understand the story's
   implementation and impacted surfaces.
2. Use `git status`, `git diff`, and targeted file reads to inspect what was
   actually changed.
3. Never speculate about code you haven't read.
4. Break the reviewed implementation into logical groups and explain the
   grouping briefly.
5. Review each group sequentially.
6. Prioritize:
   - correctness
   - regressions
   - architectural consistency
   - duplication / missed reuse
   - status/progress drift from the step spec
   - missing tests
   - rollout / operational risks where relevant

## Critical checks
Before approving, verify:
- Does the implementation actually satisfy the step spec?
- Were any epic-wide architectural decisions violated?
- Can existing code have been extended instead of creating new duplication?
- Do the changes respect module boundaries and current patterns?
- Are there any security implications in the implementation or operational model?
- Are there any performance or scalability regressions in the changed path?
- Are follow-on status transitions accurate in `MASTER.md` and the step file?
- Are there adequate tests for the change?
- Are there hidden packaging/runtime/ops implications not captured in the step?

## Status transitions
You may update `MASTER.md` as part of the review.

Use this policy:
- if review starts on a step still marked `🔄 IN PROGRESS` but the
  implementation is clearly ready for review, move it to `🟣 IN REVIEW`
- if the review passes with no blocking findings AND the epic does not use the
  optional GitHub PR stage for this story, mark it `✅ DONE`
- if the review passes with no blocking findings AND the story is expected to
  go through a GitHub PR review, leave it at `🟣 IN REVIEW` and tell the
  operator to run `epic_pr` to transition to `🔵 IN PR`
- if the review finds issues that require more implementation work, move it to
  `🔄 IN PROGRESS`
- if the review cannot complete because of an external blocker, mark it
  `⛔ BLOCKED`
- if the step is currently `🔵 IN PR`, treat this as a pre-merge sanity review
  only; do not transition the status from `🔵 IN PR` yourself. Any merge-state
  change belongs to `epic_pr` (for merged/changes_requested transitions).
  Record findings in the `Review Log` as normal.

## Review log write-back
Append or update a `## Review Log` section in the step file.

Add a new entry like:

```md
- <UTC ISO timestamp> Review run by Codex fresh session
  - Verdict: approve | request_changes | blocked | not_reviewable
  - Status transition: <from> -> <to>
  - Files reviewed: <paths>
  - Key findings:
    - <short bullet>
    - <short bullet>
  - Next action: <one concrete recommendation>
```

If a `Review Log` section does not exist, create it.

## Output format
Start with findings, ordered by severity, with file references.

Use:

```markdown
**Decision**: [APPROVE | REQUEST CHANGES | BLOCKED | NOT REVIEWABLE]
**Reviewed Story**: [Step <resolved_step_number> / <resolved_spec_file>]
**Grouping**: [brief grouping logic]

**Findings**
- [Severity] [file:line] issue

**Summary**
- [2-4 short bullets]

**Status Transition**
- [old -> new]

**Next Action**
- [single concrete next step]
```

If there are no findings, say that explicitly.
