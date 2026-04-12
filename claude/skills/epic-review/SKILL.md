---
name: epic-review
description: Review one implemented epic step against its story spec, current repo state, and recorded handoff context. Read-only for code; updates only the step's coordination file.
disable-model-invocation: true
argument-hint: "<epic-name> <story-number-or-spec-file>"
allowed-tools: Read Edit Grep Glob Bash(git status:*) Bash(git diff:*) Bash(git log:*)
---

# Epic Review

Review one epic story implementation against its step spec, current repo state, and recorded handoff context. Record the verdict back into the coordination file.

Argument: `$ARGUMENTS` — `<epic_name> <story_number_or_spec_file>`. Both required.

## Important

You can only change the coordination files in the epic, **never** the source code of the app. Review is inherently a read-only process.

## Why this command requires explicit args

`/epic-review` deliberately requires both `<epic>` and `<story>` to be passed explicitly. Unlike `/epic-pr` — which is mostly mechanical PR-body rephrasing and infers the active story from the session context — review must come from a fresh, independent perspective. The same session that just implemented a story will rationalize its own work, not scrutinize it.

The arg requirement is a **forcing function**: if you find yourself typing the epic and story numbers manually, you have just been nudged to consider opening a fresh session for the review. **Do that.** Auto-inference here would defeat the entire purpose of separating implementer from reviewer.

Users who insist on running review from the implementation session can still do so — the args make it possible — but the friction is intentional and any future change that adds inference here must be rejected.

## Resolution

1. Parse `$ARGUMENTS` as `<epic> <story>`
2. Resolve the epic directory as `<cwd>/agent_coordination/epics/<epic>`
3. If `<story>` is empty, abort fast and ask for it as either a `Step` value or a `Spec` value from `<epic>/MASTER.md`
4. Use `<epic>/MASTER.md` as the only lookup table
5. First try to match exactly one row whose `Step` value equals `<story>`
6. If no row matches by `Step`, try to match exactly one row whose `Spec` value equals `<story>`
7. If neither lookup finds a row, abort fast and report the unresolved selector plus the available `Step` and `Spec` values from `MASTER.md`
8. If the `Step` lookup and `Spec` lookup both match but point to different rows, abort fast and report the ambiguity
9. Resolve the step file as `<epic>/<matched row Spec value>`
10. If that path does not exist, abort fast and report the exact missing path

## Read first

1. the main repo `AGENTS.md` for the repo you will touch
2. `<epic>/MASTER.md`
3. the resolved step file
4. dependency step files listed for the resolved step in `MASTER.md`

## Review intent

Do **not** rediscover the epic from scratch. Your job is to:
1. Understand the story spec in the resolved step file
2. Inspect the actual implementation and current worktree
3. Review the implementation against the step spec and surrounding architecture
4. Record the review result back into the coordination file

## Review readiness check

Before doing a full review:
- inspect the row for the resolved step in `MASTER.md`
- inspect any `Active Claim`, `Progress Log`, `Session Handoff`, and `PR Tracking` sections in the step file

If the story is clearly not reviewable yet, abort fast with a concise reason. Examples:
- step is still `TODO` and there is no implementation / handoff evidence
- step is blocked by an unmet dependency and the code cannot be sensibly judged
- no credible mapping from the step spec to any code or tests yet

## Source-of-truth hierarchy

1. `<epic>/MASTER.md`
2. the resolved step file
3. dependency step files
4. actual code, tests, and worktree diff

Do not infer identity from filename shape or naming conventions that are not explicitly recorded in `MASTER.md`.

## Review process

1. Use code search and direct reading to understand the story's implementation and impacted surfaces
2. Use `git status`, `git diff`, and targeted file reads to inspect what was actually changed
3. Never speculate about code you haven't read
4. Break the reviewed implementation into logical groups; explain the grouping briefly
5. Review each group sequentially
6. Prioritize:
   - correctness
   - regressions
   - architectural consistency
   - duplication / missed reuse
   - status / progress drift from the step spec
   - missing tests
   - rollout / operational risks where relevant

## Critical checks

Before approving, verify:
- Does the implementation actually satisfy the step spec?
- Were any epic-wide architectural decisions violated?
- Can existing code have been extended instead of creating new duplication?
- Do the changes respect module boundaries and current patterns?
- Are there security implications in the implementation or operational model?
- Are there performance or scalability regressions in the changed path?
- Are follow-on status transitions accurate in `MASTER.md` and the step file?
- Are there adequate tests for the change?
- Are there hidden packaging / runtime / ops implications not captured in the step?

## Status transitions

You may update `MASTER.md` as part of the review. Use this policy:

- if review starts on a step marked `🔄 IN PROGRESS` but implementation is clearly ready for review, move it to `🟣 IN REVIEW`
- if review passes with no blocking findings AND the epic does not use the optional GitHub PR stage for this story, mark it `✅ DONE`
- if review passes with no blocking findings AND the story is expected to go through a GitHub PR review, leave it at `🟣 IN REVIEW` and tell the user to run `/epic-pr` to transition to `🔵 IN PR`
- if review finds issues that require more implementation work, move it to `🔄 IN PROGRESS`
- if review cannot complete because of an external blocker, mark it `⛔ BLOCKED`
- if the step is currently `🔵 IN PR`, treat this as a pre-merge sanity review only; **do not transition the status from `🔵 IN PR` yourself**. Any merge-state change belongs to `/epic-pr`. Record findings in the `Review Log` as normal.

## Review log write-back

Append or update a `## Review Log` section in the step file with a new entry:

```md
- <UTC ISO timestamp> Review run by Claude fresh session
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
