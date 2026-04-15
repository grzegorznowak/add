---
description: Claim one ready epic step and execute it
argument-hint: [EPIC="<epic_name>"] [WORKTREE="<path>"]
---

Implementation: $EPIC

Treat `$EPIC` as the exact directory name of an epic under the agent's current
working directory at:
`agent_coordination/epics`

`$WORKTREE` is an optional explicit opt-in. When non-empty, the `## Worktree preflight` section creates a linked git worktree at `$WORKTREE` regardless of whether the main tree is dirty. When empty, the preflight only triggers if `git status --porcelain` is non-empty.

Your job is to pick exactly one ready and unclaimed step from that epic,
claim it in the coordination docs, execute it, and leave behind a clean handoff.


Do **not** try to rediscover or redefine the epic from scratch.
The workflow is:
1. read the epic master
2. pick one ready step
3. claim it
4. work only that step plus required dependencies
5. move it to `IN REVIEW` after implementation is complete
6. leave the step file in a state that the next fresh session can continue

## Resolution
1. Resolve `<epic>` = `<cwd>/agent_coordination/epics/$EPIC`. This is the **initial** anchor; the `## Worktree preflight` section may re-anchor `<epic>` to a worktree path after step selection.
2. If `<epic>` does not exist, stop and report the exact missing path.
3. Read first (from `<cwd>` at this point):
   - the main repo `AGENTS.md` for the repo you will touch
   - `<epic>/MASTER.md`

## Source-of-truth hierarchy
1. `<epic>/MASTER.md`
2. the claimed step file
3. dependency step files listed in the master table
4. repo code and tests

Anything else is background only unless the claimed step explicitly requires it.

## Step selection
From `<epic>/MASTER.md`, select the first step that is all of:
- unclaimed:
  - status is `⬜ TODO`, `TODO`, or otherwise clearly unclaimed
- ready:
  - every dependency listed in `Depends` is marked `✅ DONE` or `DONE`
- concrete:
  - the referenced step file exists

If no such step exists:
- do not guess
- stop after a concise report listing:
  - no-ready-step reason
  - blocked steps
  - next step that must complete first

## Worktree preflight

After picking a step but before writing any claim, decide whether to continue from `<cwd>` (the main tree) or from a linked git worktree on a story-specific branch. Implementation work then happens in a clean branch isolated from whatever else was in the main tree.

1. **Not a git repo**. Run `git -C <cwd> rev-parse --is-inside-work-tree`. If non-zero, set `<project_root>` = `<cwd>` and skip the rest of this section.

2. **Compute `<story-slug>`**. Strip the `.md` extension from the selected step's spec file. Example: `story-03-bootstrap-and-docs-rewrite.md` → `story-03-bootstrap-and-docs-rewrite`.

3. **Compute default path**:
   - `<repo-root>` = `git -C <cwd> rev-parse --show-toplevel`
   - `<repo-basename>` = `basename <repo-root>`
   - `<default-path>` = `/tmp/add-worktrees/<repo-basename>-$EPIC-<story-slug>`

4. **Dirtiness check**. Run `git -C <cwd> status --porcelain`. `<dirty>` = output non-empty.

5. **Trigger decision**:
   - If `$WORKTREE` is non-empty, `<wt-path>` = `$WORKTREE`. Proceed to step 6.
   - Else if `<dirty>` is true, show the operator:

     ```
     Main tree has uncommitted changes:
       <indented git status --porcelain output>
     Create a worktree for this story?
       Default path: <default-path>
     Reply with a path, `default`, or `no`.
     ```

     On `no`: `<project_root>` = `<cwd>`, warn "proceeding on dirty main tree", skip to step 10. On `default`: `<wt-path>` = `<default-path>`. On a path: `<wt-path>` = that path (normalized absolute). Proceed to step 6.
   - Else (clean tree, no opt-in): `<project_root>` = `<cwd>`, skip to step 10.

6. **Create parent dir**: `mkdir -p "$(dirname <wt-path>)"`.

7. **Create the worktree**:
   ```
   git -C <cwd> worktree add -b $EPIC/<story-slug> <wt-path>
   ```
   - If it fails because the branch `$EPIC/<story-slug>` already exists, abort with: "story branch `$EPIC/<story-slug>` already exists; this looks like a resumable story — run `$epic_resume EPIC=\"$EPIC\"` instead". No `MASTER.md` or story-file writes have happened yet in this session, so aborting is safe.
   - If it fails for any other reason, report the git error verbatim and abort.

8. **Set `<project_root>`**. `<project_root>` = `<wt-path>`. Update `<epic>` to `<project_root>/agent_coordination/epics/$EPIC`.

9. **Sanity checks** (worktree mode only):
   - Run `git -C <project_root> ls-files --error-unmatch agent_coordination/epics/$EPIC/MASTER.md`. Failure means `agent_coordination/` is gitignored or not committed on main. Abort with: "agent_coordination/ appears to be ignored or uncommitted on main; commit the epic files first, then re-run `$epic_claim`".
   - Re-read `<epic>/MASTER.md` and the selected step file from `<project_root>` so subsequent edits use the worktree copies.
   - If any files under `agent_coordination/` appeared in the step 4 output, warn: "pending changes to `agent_coordination/` on main will NOT be in the worktree — commit them on main and rerun, or proceed knowing they are stranded".

10. **Done**. `<project_root>` is set. All downstream file reads/writes use `<project_root>/...` (or `<epic>/...` derived from it). Git commands in later sections run with `git -C <project_root> ...`.

## Claim protocol
Before deep implementation work:
1. Update the selected row in `MASTER.md` to:
   - `🔄 IN PROGRESS`
2. Update the selected step file by adding or refreshing these sections:

```md
## Active Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: Codex fresh session
- Scope: <one sentence>
- Worktree: <project_root>  (omit this bullet when <project_root> == <cwd>)
- Primary write surfaces: <paths>

## Progress Log
- <UTC ISO timestamp> Claimed step and started implementation.
```

3. Do not claim more than one step in a single session.
4. Do not silently switch to a different step once work has started.

## Execution rules
- Treat `MASTER.md` plus the claimed step file as the source of truth.
- Read dependency step files for context, but do not widen scope unless required
  to finish the claimed step correctly.
- Implement the claimed step end-to-end when feasible.
- Prefer code changes over restating plans.
- If you discover an epic-wide architectural contradiction, update `MASTER.md`
  minimally and note it in the step file.
- If the claimed step turns out to be blocked by an unmet dependency or hard
  contradiction, stop broadening scope and mark it clearly as blocked.

## Progress tracking
While working, keep the claimed step file updated.

Append concise timestamped bullets under `## Progress Log` after meaningful
milestones, for example:
- design change locked
- files patched
- tests added/updated
- blocker discovered
- epic-wide finding recorded in `MASTER.md`

Do not wait until the very end to record progress.

## Parallelism guard
Assume other fresh sessions may work on nearby steps.
- Avoid touching files outside the claimed step's primary write surfaces unless
  required to finish the step correctly.
- If you must cross that boundary, record it immediately in the progress log.

## Finish protocol
At the end of the session, update the claimed step file with:

```md
## Session Handoff
- Status: done | blocked | in progress | in review
- What changed: <short bullets>
- Files touched: <paths>
- Tests run: <commands/results or not run>
- Remaining work: <short bullets>
- Blockers / risks: <short bullets>
- Exact next step: <one concrete recommendation>
```

Then update `MASTER.md` status for the claimed row using this lifecycle:
- `🔄 IN PROGRESS`
  - implementation is still actively underway
- `🟣 IN REVIEW`
  - implementation is done enough for review
  - run final verification, review the touched files, and tighten any rough edges
  - do not mark `DONE` before this pass
- `🔵 IN PR` (optional)
  - local review passed and the changes are in a GitHub pull request awaiting
    remote review and merge
  - do not set this status from `epic_claim`; use the `epic_pr` flow to record
    PR metadata on the step file
- `✅ DONE`
  - implementation and review are complete, and if a PR stage was used the PR
    is merged
- `⛔ BLOCKED`
  - an external blocker prevents completion or review

Default rule:
1. claim as `🔄 IN PROGRESS`
2. once implementation is complete, move to `🟣 IN REVIEW`
3. then either:
   - move straight to `✅ DONE` if no GitHub PR stage is needed, or
   - use `epic_pr` to transition to `🔵 IN PR` and move to `✅ DONE` only
     after the PR is merged
4. if the session ends before review is complete, leave it at `🟣 IN REVIEW`
5. if the session ends before implementation is complete, leave it at `🔄 IN PROGRESS`

If the epic's `MASTER.md` `Legend` section does not list `🔵 IN PR`, add it
immediately after the `🟣 IN REVIEW` line:

```md
- `🔵 IN PR` — local review passed, PR opened, awaiting GitHub review + merge
```

## Final response
In your final response, state:
- which step you claimed
- its final status
- files changed
- whether the epic master was updated
- the exact next action for the next fresh session
