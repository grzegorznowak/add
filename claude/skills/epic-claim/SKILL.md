---
name: epic-claim
description: Claim one ready epic step and execute it end-to-end, leaving a clean handoff. Use when starting a fresh session on a new story from an epic's MASTER.md tracker.
disable-model-invocation: true
argument-hint: "<epic-name>"
allowed-tools: Read Edit Write Grep Glob Bash
---

# Epic Claim

Pick exactly one ready, unclaimed step from an epic, claim it, execute it, and leave a clean handoff for the next session.

Argument: `$ARGUMENTS` — `<epic-name> [WORKTREE="<path>"]`. The epic name is the first bare positional token (e.g. `cure-core-review-pipeline`) and resolves to `agent_coordination/epics/<epic-name>`; if omitted and there is exactly one active epic under `agent_coordination/epics/`, default to that one. `WORKTREE="<path>"` is an optional opt-in: when present, the `## Worktree preflight` section creates a linked git worktree at `<path>` regardless of whether the main tree is dirty. When absent, the preflight only triggers if `git status --porcelain` is non-empty.

Do **not** try to rediscover or redefine the epic from scratch. Do **not** claim more than one step in a single session.

## Workflow
1. Read the epic `MASTER.md`
2. Pick one ready step
3. Claim it
4. Work only that step plus required dependencies
5. Move it to `🟣 IN REVIEW` after implementation is complete
6. Leave the step file in a state the next fresh session can continue

## Resolution

1. Parse `$ARGUMENTS` into:
   - `<epic-name>`: the first bare positional token (falls back to the single active epic under `agent_coordination/epics/` if omitted)
   - `<explicit_wt_path>`: extracted from `WORKTREE="<path>"` if present, else unset
2. Resolve `<epic>` = `<cwd>/agent_coordination/epics/<epic-name>`. This is the **initial** anchor; the `## Worktree preflight` section may re-anchor `<epic>` to a worktree path after step selection.
3. If `<epic>` does not exist, stop and report the exact missing path.
4. Read first (from `<cwd>` at this point):
   - the main repo `AGENTS.md` for the repo you will touch
   - `<epic>/MASTER.md`

## Source-of-truth hierarchy

1. `<epic>/MASTER.md`
2. the claimed step file
3. dependency step files listed in the master table
4. repo code and tests

## Step selection

From `<epic>/MASTER.md`, select the first step that is all of:
- **unclaimed**: status is `⬜ TODO`, `⚪ TODO`, or otherwise clearly unclaimed
- **ready**: every dependency listed in `Depends` is `✅ DONE`
- **concrete**: the referenced step file exists

If no such step exists:
- do not guess
- stop after a concise report listing: no-ready-step reason, blocked steps, and the next step that must complete first

## Worktree preflight

After picking a step but before writing any claim, decide whether to continue from `<cwd>` (the main tree) or from a linked git worktree on a story-specific branch. Implementation work happens in a clean branch isolated from whatever else was in the main tree.

1. **Not a git repo**. Run `git -C <cwd> rev-parse --is-inside-work-tree`. If it exits non-zero, set `<project_root>` = `<cwd>` and skip the rest of this section. The feature is inert for non-git projects.

2. **Compute `<story-slug>`**. Strip the `.md` extension from the selected step's spec file. Example: `story-03-bootstrap-and-docs-rewrite.md` → `story-03-bootstrap-and-docs-rewrite`.

3. **Compute default path**:
   - `<repo-root>` = `git -C <cwd> rev-parse --show-toplevel`
   - `<repo-basename>` = `basename <repo-root>`
   - `<default-path>` = `/tmp/add-worktrees/<repo-basename>-<epic-name>-<story-slug>`

4. **Dirtiness check**. Run `git -C <cwd> status --porcelain`. `<dirty>` = output non-empty.

5. **Trigger decision**:
   - If `<explicit_wt_path>` is set, proceed to step 6 with `<wt-path>` = `<explicit_wt_path>`.
   - Else if `<dirty>` is true, show the operator:

     ```
     Main tree has uncommitted changes:
       <indented git status --porcelain output>
     Create a worktree for this story?
       Default path: <default-path>
     Reply with a path, `default`, or `no`.
     ```

     On `no`: set `<project_root>` = `<cwd>`, warn "proceeding on dirty main tree", skip to step 10. On `default`: `<wt-path>` = `<default-path>`. On a path: `<wt-path>` = that path (normalized absolute). Then proceed to step 6.
   - Else (clean tree, no opt-in): set `<project_root>` = `<cwd>` and skip to step 10.

6. **Create parent dir**. `mkdir -p "$(dirname <wt-path>)"`.

7. **Create the worktree**:
   ```
   git -C <cwd> worktree add -b <epic-name>/<story-slug> <wt-path>
   ```
   - If it fails because the branch `<epic-name>/<story-slug>` already exists, abort with: "story branch `<epic-name>/<story-slug>` already exists; this looks like a resumable story — run `/epic-resume <epic-name> <story>` instead". No `MASTER.md` or story-file writes have happened yet, so aborting is safe.
   - If it fails for any other reason (path exists, ref conflict, …), report the git error verbatim and abort.

8. **Set `<project_root>`**. `<project_root>` = `<wt-path>`. Update `<epic>` to `<project_root>/agent_coordination/epics/<epic-name>`.

9. **Sanity checks** (worktree mode only):
   - Run `git -C <project_root> ls-files --error-unmatch agent_coordination/epics/<epic-name>/MASTER.md`. If it fails, `agent_coordination/` is gitignored or `MASTER.md` is not committed. Abort with: "agent_coordination/ appears to be ignored or uncommitted on main; commit the epic files first, then re-run /epic-claim".
   - Re-read `<epic>/MASTER.md` and the selected step file from `<project_root>` so subsequent edits use the worktree copies.
   - If any files under `agent_coordination/` appeared in the step 4 output, warn: "pending changes to `agent_coordination/` on main will NOT be in the worktree — commit them on main and rerun, or proceed knowing they are stranded".

10. **Done**. `<project_root>` is set. All downstream file reads and writes use `<project_root>/...` (or `<epic>/...` derived from it). Git commands in later sections run with `git -C <project_root> ...`.

## Claim protocol

Before deep implementation work:
1. Update the selected row in `MASTER.md` to `🔄 IN PROGRESS`
2. Add or refresh these sections in the step file:

```md
## Active Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: Claude fresh session
- Scope: <one sentence>
- Worktree: <project_root>  (omit this bullet when <project_root> == <cwd>)
- Primary write surfaces: <paths>

## Progress Log
- <UTC ISO timestamp> Claimed step and started implementation.
```

3. Do not silently switch to a different step once work has started.

## Execution rules

- Treat `MASTER.md` plus the claimed step file as the source of truth
- Read dependency step files for context; do not widen scope unless required to finish the claimed step correctly
- Implement the claimed step end-to-end when feasible
- Prefer code changes over restating plans
- If you discover an epic-wide architectural contradiction, update `MASTER.md` minimally and note it in the step file
- If the claimed step is blocked by an unmet dependency or hard contradiction, stop broadening scope and mark it `⛔ BLOCKED`

## Progress tracking

Append concise timestamped bullets under `## Progress Log` after meaningful milestones:
- design change locked
- files patched
- tests added/updated
- blocker discovered
- epic-wide finding recorded in `MASTER.md`

Do not wait until the very end to record progress.

## Parallelism guard

Assume other fresh sessions may work on nearby steps. Avoid touching files outside the claimed step's primary write surfaces unless required. If you must cross that boundary, record it immediately in the progress log.

## Finish protocol

At the end of the session, update the step file:

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

Then update `MASTER.md` status using this lifecycle:
- `🔄 IN PROGRESS` — implementation still actively underway
- `🟣 IN REVIEW` — implementation done enough for review; run final verification, review the touched files, tighten rough edges
- `🔵 IN PR` (optional) — local review passed and changes are in a GitHub PR awaiting remote review and merge. **Do not set this status from `/epic-claim`**; use `/epic-pr` to record PR metadata.
- `✅ DONE` — implementation and review complete; if a PR stage was used, the PR is merged
- `⛔ BLOCKED` — an external blocker prevents completion or review

**Default rule:**
1. Claim as `🔄 IN PROGRESS`
2. Once implementation is complete, move to `🟣 IN REVIEW`
3. Then either:
   - move straight to `✅ DONE` if no GitHub PR stage is needed, or
   - use `/epic-pr` to transition to `🔵 IN PR` and move to `✅ DONE` only after the PR is merged
4. If the session ends before review is complete, leave at `🟣 IN REVIEW`
5. If the session ends before implementation is complete, leave at `🔄 IN PROGRESS`

If the epic's `MASTER.md` Legend section does not list `🔵 IN PR`, add it immediately after the `🟣 IN REVIEW` line:

```md
- `🔵 IN PR` — local review passed, PR opened, awaiting GitHub review + merge
```

## Final response

State:
- which step you claimed
- its final status
- files changed
- whether the epic master was updated
- the exact next action for the next fresh session
