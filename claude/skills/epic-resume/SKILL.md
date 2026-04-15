---
name: epic-resume
description: Pick up one already in-progress epic step and continue it. Use when a fresh session needs to resume ongoing work on a specific story.
disable-model-invocation: true
argument-hint: "<epic-name> [story-number-or-spec-file]"
allowed-tools: Read Edit Write Grep Glob Bash
---

# Epic Resume

Continue exactly one already-ongoing epic step, following the existing handoff / review guidance, and leave the coordination docs in a state the next fresh session can trust.

Argument: `$ARGUMENTS` — `<epic_name> [<story_number_or_spec_file>] [WORKTREE="<path>"]`. The epic name is required. The story selector is optional; when omitted and there is exactly one in-progress step, it is selected automatically. `WORKTREE="<path>"` is an optional opt-in that overrides the preflight's default decision (see `## Worktree preflight`). When absent, the preflight auto-reads any `Worktree:` bullet recorded in the story's `## Active Claim`.

Do **not** claim a new step. Do **not** rediscover or redefine the epic from scratch.

## Workflow
1. Read the epic master
2. Locate the already in-progress step
3. Refresh the claim / progress state for this continuation session
4. Carry the step forward using the latest concrete CTA
5. Leave it in `🔄 IN PROGRESS`, `🟣 IN REVIEW`, or `⛔ BLOCKED`
6. Leave a clean handoff for the next fresh session

## Resolution

1. Parse `$ARGUMENTS`:
   - `<epic-name>`: required, the first positional token
   - `<story>`: optional, the second positional token (story number or spec file)
   - `<explicit_wt_path>`: optional, from `WORKTREE="<path>"` if present
2. Resolve `<epic>` = `<cwd>/agent_coordination/epics/<epic-name>`. This is the **initial** anchor; the `## Worktree preflight` section may re-anchor `<epic>` to a worktree path after the Active Claim is read.
3. If `<epic>` does not exist, stop and report the exact missing path.
4. Read first (from `<cwd>` at this point):
   - the main repo `AGENTS.md` for the repo you will touch
   - `<epic>/MASTER.md`

## Step selection

**If `<story>` was provided:**
- use `<epic>/MASTER.md` as the only lookup table
- first try to match exactly one row whose `Step` value equals the selector
- if no row matches by `Step`, try to match exactly one row whose `Spec` value equals the selector
- if neither lookup finds a row, stop and report the unresolved selector plus the available `Step` and `Spec` values from `MASTER.md`
- if the `Step` lookup and `Spec` lookup both match but point to different rows, stop and report the ambiguity
- resolve the selected step file from the matched row's `Spec` value
- if that file does not exist under `<epic>/`, stop and report the exact missing path
- if the resolved row is not `🔄 IN PROGRESS` or `🔵 IN PR` with PR changes requested, stop and report the actual status

**If `<story>` was not provided:**
- collect every row in `MASTER.md` marked `🔄 IN PROGRESS`
- also collect rows marked `🔵 IN PR` **only if** the PR is currently requesting code changes (check the step file's `## PR Tracking` section `PR status` field; `changes_requested` is a resumable signal)
- if there are none, stop and recommend `/epic-claim` instead
- if there is exactly one, select it
- if there are multiple, stop and list each candidate; do not guess

## Read before implementing

After the step is resolved, read:
1. the selected step file
2. dependency step files listed for it in `MASTER.md`
3. the latest relevant sections inside the step file:
   - `## Active Claim`
   - `## Progress Log`
   - `## Session Handoff`
   - `## Review Log`
   - `## PR Tracking` (only present on steps that went through `/epic-pr`)

If the step is `🔵 IN PR` and the PR is requesting code changes, treat the PR review comments as the authoritative CTA for this continuation and move the step back to `🔄 IN PROGRESS` for the duration of the session.

## Worktree preflight

After reading the story file's `## Active Claim`, decide whether to continue from `<cwd>` or from an existing / newly-created linked git worktree on the story's branch.

1. **Not a git repo**. Run `git -C <cwd> rev-parse --is-inside-work-tree`. If non-zero, set `<project_root>` = `<cwd>` and skip the rest of this section.

2. **Read `Worktree:` from the story's `## Active Claim`**. If there is a bullet of the form `- Worktree: <path>`, store it as `<active_wt_path>`. Else `<active_wt_path>` is unset.

3. **Compute `<story-slug>`**. Strip the `.md` extension from the resolved step's spec file. Example: `story-03-bootstrap-and-docs-rewrite.md` → `story-03-bootstrap-and-docs-rewrite`.

4. **Compute default path**:
   - `<repo-root>` = `git -C <cwd> rev-parse --show-toplevel`
   - `<repo-basename>` = `basename <repo-root>`
   - `<default-path>` = `/tmp/add-worktrees/<repo-basename>-<epic-name>-<story-slug>`

5. **Dirtiness check**. `git -C <cwd> status --porcelain`. `<dirty>` = output non-empty.

6. **Decision**:

   a. **`<active_wt_path>` is set**:
      - Verify it with `git -C <cwd> worktree list --porcelain`. If there is a `worktree <active_wt_path>` line AND that path exists on disk, set `<wt-path>` = `<active_wt_path>` and go to step 8 (reattach skipped — worktree already exists and is registered).
      - Otherwise the recorded worktree is stale. If `<explicit_wt_path>` is set, use it (`<wt-path>` = `<explicit_wt_path>`, go to step 7). Else prompt the operator:

        ```
        Recorded Worktree: <active_wt_path> is missing or not a registered git worktree.
        Recreate for this story?
          Default path: <default-path>  (recorded path: <active_wt_path>)
        Reply with a path, `default`, `recorded`, or `no`.
        ```

        - On `no`: warn, set `<project_root>` = `<cwd>`, skip to step 10.
        - On `default`: `<wt-path>` = `<default-path>`.
        - On `recorded`: `<wt-path>` = `<active_wt_path>`.
        - On a path: `<wt-path>` = that path (normalized absolute).
        - Proceed to step 7.

   b. **`<active_wt_path>` is unset, `<explicit_wt_path>` is set**:
      - `<wt-path>` = `<explicit_wt_path>`. Go to step 7.

   c. **`<active_wt_path>` and `<explicit_wt_path>` both unset, `<dirty>` is true**:
      - Prompt the operator (same shape as `/epic-claim`):

        ```
        Main tree has uncommitted changes:
          <indented git status --porcelain output>
        This story has no recorded Worktree. Create one?
          Default path: <default-path>
        Reply with a path, `default`, or `no`.
        ```

        - On `no`: warn, set `<project_root>` = `<cwd>`, skip to step 10.
        - Else: `<wt-path>` = resolved path. Proceed to step 7.

   d. **All unset, `<dirty>` is false**:
      - Set `<project_root>` = `<cwd>`, skip to step 10.

7. **Create or reattach the worktree**:
   - `mkdir -p "$(dirname <wt-path>)"`.
   - Try reattach first (the branch likely already exists from the original `/epic-claim`): `git -C <cwd> worktree add <wt-path> <epic-name>/<story-slug>`
   - If that fails because the branch `<epic-name>/<story-slug>` does not exist, fall back to create: `git -C <cwd> worktree add -b <epic-name>/<story-slug> <wt-path>`.
   - If either succeeds, continue. If both fail, report the git error verbatim and abort.

8. **Set `<project_root>`**. `<project_root>` = `<wt-path>`. Update `<epic>` to `<project_root>/agent_coordination/epics/<epic-name>`.

9. **Re-read the story's current state from `<project_root>`**. Re-read `<epic>/MASTER.md` and the step file. The worktree's branch may have newer `## Progress Log`, `## Review Log`, or `## Session Handoff` entries than main — those are the ones that matter for this continuation. Subsequent "Resume intent" prioritization (below) operates on the worktree's copy.

10. **Pending coordination edits warning**. If `<project_root>` != `<cwd>` AND step 5 showed modified or staged files under `agent_coordination/` on main, warn: "pending changes to `agent_coordination/` on main will NOT be in the worktree — commit them on main and rerun, or proceed knowing they are stranded".

At the end of this section, `<project_root>` is set. All downstream file reads/writes use `<project_root>/...` (or `<epic>/...` derived from it). Git commands in later sections run with `git -C <project_root> ...`.

## Source-of-truth hierarchy

1. `<epic>/MASTER.md`
2. the selected step file
3. dependency step files listed in the master table
4. repo code and tests

## Resume intent

Treat this as continuation work, not a new claim.

Use the latest concrete guidance in this order:
1. newest `Review Log` entry with blocking findings or a concrete next action
2. latest `Session Handoff`
3. latest `Progress Log` milestone
4. the step `Goal` / `Acceptance`

If these conflict, prefer the higher source in the list above and record the conflict in the progress log.

## Claim refresh protocol

Before deep implementation work:

1. Refresh the existing `## Active Claim` section:

```md
## Active Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: Claude continuation session
- Scope: <one sentence for this pickup chunk>
- Worktree: <project_root>  (preserve / refresh this bullet when <project_root> != <cwd>; omit it otherwise)
- Primary write surfaces: <paths>
```

The `Worktree:` bullet must reflect the current `<project_root>`: if the preflight reused an existing worktree, keep the recorded path as-is; if it recreated a stale one at a new location, update the path; if `<project_root>` == `<cwd>`, omit the bullet entirely. Never delete a `Worktree:` bullet when `<project_root>` points at a worktree — other sessions depend on it for reattachment.

2. Append a new timestamped bullet under `## Progress Log`:

```md
- <UTC ISO timestamp> Picked up existing in-progress step and resumed work from the latest handoff/review CTA.
```

3. Do not create a second `Active Claim` section.
4. Do not silently switch to a different step once work has started.

## Execution rules

- Treat `MASTER.md` plus the selected step file as the source of truth
- Respect the latest review/handoff CTA before widening scope
- Continue only this step plus required dependencies
- Prefer code changes over restating plans
- If the step is in progress because of review feedback, address that feedback first
- If you discover an epic-wide architectural contradiction, update `MASTER.md` minimally and note it in the step file
- If the step is blocked by a hard external dependency or contradiction, stop broadening scope and mark it `⛔ BLOCKED`

## Progress tracking

Append concise timestamped bullets under `## Progress Log` after meaningful milestones. Do not wait until the end to record progress.

## Parallelism guard

Avoid touching files outside the selected step's primary write surfaces unless required. Record any boundary crossing in the progress log.

## Finish protocol

At the end of the session:

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

Update `MASTER.md` status using this lifecycle:
- `🔄 IN PROGRESS` — implementation or requested-change work still underway
- `🟣 IN REVIEW` — outstanding implementation work complete, ready for a fresh review pass
- `🔵 IN PR` (optional) — local review passed, PR awaiting GitHub review + merge. **Do not set this status from `/epic-resume`**; use `/epic-pr` to record PR metadata.
- `✅ DONE` — only if a real review pass completes and passes in this session AND any PR stage is merged
- `⛔ BLOCKED` — external blocker prevents completion or review

**Default rule:**
1. Resume at `🔄 IN PROGRESS`
2. Once outstanding implementation is complete, move to `🟣 IN REVIEW`
3. Then either move straight to `✅ DONE` if no PR stage is needed, or hand off to `/epic-pr` which transitions to `🔵 IN PR`
4. If resuming a `🔵 IN PR` step that is requesting changes, move to `🔄 IN PROGRESS` while working, then back to `🔵 IN PR` via `/epic-pr` once the new push is ready for another review round
5. If the session ends before review is complete, leave at `🟣 IN REVIEW`
6. If the session ends before implementation is complete, leave at `🔄 IN PROGRESS`

If the epic's `MASTER.md` Legend does not list `🔵 IN PR`, add it after the `🟣 IN REVIEW` line:

```md
- `🔵 IN PR` — local review passed, PR opened, awaiting GitHub review + merge
```

## Final response

State:
- which step was resumed (number and spec file)
- final status
- files changed
- whether the epic master was updated
- the exact next action for the next fresh session
