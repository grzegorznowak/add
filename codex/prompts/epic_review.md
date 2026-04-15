---
description: Review one implemented epic step against its story spec
argument-hint: [EPIC="<epic_name>"] [STORY="<story_number_or_spec_file>"] [WORKTREE="<path>"]
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

`$WORKTREE` is an optional override. When non-empty, the `## Worktree preflight` section uses `$WORKTREE` as the resolved worktree path without checking the story's `## Active Claim`. When empty, the preflight auto-reads any `Worktree:` bullet recorded in the story's `## Active Claim`; review **never** creates a new worktree from this command — it only reuses.

You are a maintainer reviewing one epic story implementation against its step
spec, current repo state, and recorded handoff context.

This prompt is intended to work well from a fresh session. It can also be run
multiple times on the same step when review context already exists.

# Important 
You can only change the coordination files in the epic, never actual sourcecodes of the app
Review is inherently a read-only process

## Why operator-explicit (arg or menu) selection

`epic_review` never auto-infers the epic or the story. The operator
explicitly chooses — either by passing `$EPIC` and `$STORY` as arguments
or by picking from the menu this skill shows when either is absent. The
menu is **not** inference: it lists the legal candidates (filtered to
`🟣 IN REVIEW`) and asks the operator to pick.

The reasoning: review must come from a fresh, independent perspective.
The same session that just implemented a story will rationalize its own
work, not scrutinize it. Auto-inferring "the current story" would
silently pick whatever the session was last working on — exactly the
coupling we want to avoid.

A gentle nudge: if you find yourself picking from the menu in the same
Codex session that just wrote the implementation, consider opening a
Codex fresh session for the review. The menu still makes it possible
to run review from the implementation session, but the friction is
intentional and any future change that adds silent auto-inference here
must be rejected.

## Resolution
1. **EPIC resolution (menu fallback):**
   - If `$EPIC` was passed, resolve `<cwd>/agent_coordination/epics/$EPIC`.
   - If `$EPIC` was not passed, list every directory under
     `<cwd>/agent_coordination/epics/` whose `MASTER.md` has at least one
     row with status `🟣 IN REVIEW`. For each, print:
     `<slug> — <N stories IN REVIEW, last-touched YYYY-MM-DD>`. If the
     filtered list is empty, abort with:
     `no epics have stories ready for review (nothing at 🟣 IN REVIEW)`.
     Otherwise ask the operator to pick (number or slug).
2. **STORY resolution (menu fallback):**
   - If `$STORY` was passed, continue to step 3.
   - If `$STORY` was not passed, list every row in `<epic>/MASTER.md`
     whose status is `🟣 IN REVIEW`. For each, print: `<Step> — <Deliverable>`.
     If the filtered list is empty, abort with: `no stories at 🟣 IN REVIEW in <epic>`.
     Otherwise ask the operator to pick (number or slug).
3. Use `<epic>/MASTER.md` as the only lookup table.
4. First try to match exactly one row whose `Step` value equals `$STORY`.
5. If no row matches by `Step`, try to match exactly one row whose `Spec`
   value equals `$STORY`.
6. If neither lookup finds a row, abort fast and report the unresolved
   selector plus the available `Step` and `Spec` values from `MASTER.md`.
7. If the `Step` lookup and `Spec` lookup both match but point to different
   rows, abort fast and report the ambiguity.
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

## Worktree preflight

After reading the story's `## Active Claim`, decide whether the review runs from `<cwd>` (the main tree) or from the implementer's linked worktree. This command **never creates** a worktree; it only reuses the one the implementer recorded or a path the operator passed explicitly.

1. **Not a git repo**. Run `git -C <cwd> rev-parse --is-inside-work-tree`. If non-zero, `<project_root>` = `<cwd>` and skip the rest of this section.

2. **Read `Worktree:` from the story's `## Active Claim`**. If a bullet of the form `- Worktree: <path>` is present, store it as `<active_wt_path>`. Else `<active_wt_path>` is unset.

3. **Dirtiness check**. `git -C <cwd> status --porcelain`. `<dirty>` = output non-empty.

4. **Decision**:

   a. **`$WORKTREE` is non-empty**: verify the directory exists and appears in `git -C <cwd> worktree list --porcelain`. If valid, `<project_root>` = `$WORKTREE`. If not, abort with the verbatim verification failure and suggest unsetting `$WORKTREE` or pointing at a valid worktree.

   b. **`$WORKTREE` empty, `<active_wt_path>` set**: verify `<active_wt_path>` the same way. If valid, `<project_root>` = `<active_wt_path>`. If stale (directory missing or not in `git worktree list`), abort with: "recorded Worktree: `<active_wt_path>` is missing or unregistered; clean the main tree and retry, ask the implementer to `$epic_resume` (which will recreate it), or pass `WORKTREE=<path>` explicitly".

   c. **Both unset, `<dirty>` is false**: `<project_root>` = `<cwd>`. Review runs on the main tree as today.

   d. **Both unset, `<dirty>` is true**: abort with: "can't review on a dirty main tree without a recorded `Worktree:` in the story's `## Active Claim`. Clean `<cwd>`, have the implementer `$epic_resume` (which records a Worktree: bullet), or pass `WORKTREE=<path>` explicitly pointing at a worktree with the story's branch checked out".

5. **Update `<epic>` if switched**. If `<project_root>` != `<cwd>`, update `<epic>` to `<project_root>/agent_coordination/epics/$EPIC` and re-read `<epic>/MASTER.md` and the resolved step file from there. The worktree's branch may have newer `## Progress Log`, `## Session Handoff`, or `## Review Log` entries than main — the review verdict is written back to the worktree's copy.

6. **Done**. `<project_root>` is set. All git commands in `## Review process` (below) run as `git -C <project_root> ...`. Every file read/write uses `<project_root>/...` as its anchor.

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
2. Use `git -C <project_root> status`, `git -C <project_root> diff`, and
   targeted file reads to inspect what was actually changed (all git commands
   run against `<project_root>`, which the preflight set to either `<cwd>` or
   the implementer's worktree).
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
