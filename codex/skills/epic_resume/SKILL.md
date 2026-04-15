---
name: epic_resume
description: Pick up one already in-progress epic step and continue it
legacy-argument-hint: '[EPIC="<epic_name>"] [STORY="<story_number_or_spec_file>"] [WORKTREE="<path>"]'
---

This skill was migrated one-to-one from the former custom prompt `epic_resume.md`.
Invoke it explicitly with `$epic_resume`.

Original argument hint: `[EPIC="<epic_name>"] [STORY="<story_number_or_spec_file>"] [WORKTREE="<path>"]`

If the user supplies text alongside the explicit skill invocation, treat that text as additional context for the instructions below.

Resume: $EPIC / $STORY

Treat `$EPIC` as the exact directory name of an epic under the agent's current
working directory at:
`agent_coordination/epics/`

Treat `$STORY` as an optional selector. When provided, it may be either:
- the exact story number from the `Step` column in `<epic>/MASTER.md`, for
  example `03`
- the exact spec file name from the `Spec` column in `<epic>/MASTER.md`, for
  example `story-03-bootstrap-and-docs-rewrite.md`

`$WORKTREE` is an optional override. When non-empty, the `## Worktree preflight` section uses `$WORKTREE` as the resolved worktree path without prompting. When empty, the preflight auto-reads any `Worktree:` bullet recorded in the story's `## Active Claim`; if none is recorded and the main tree is dirty, it prompts.

Your job is to continue exactly one already ongoing epic step, follow the
existing handoff/review guidance, execute the next concrete chunk, and leave the
coordination docs in a state that the next fresh session can trust.

Do **not** claim a new step here.
Do **not** rediscover or redefine the epic from scratch.

The workflow is:
1. read the epic master
2. locate the already in-progress step
3. refresh the claim/progress state for this continuation session
4. carry the step forward using the latest concrete CTA
5. leave it in `🔄 IN PROGRESS`, `🟣 IN REVIEW`, or `⛔ BLOCKED`
6. leave a clean handoff for the next fresh session

## Resolution
1. Resolve `<epic>` = `<cwd>/agent_coordination/epics/$EPIC`. This is the **initial** anchor; the `## Worktree preflight` section may re-anchor `<epic>` to a worktree path after the Active Claim is read.
2. If `<epic>` does not exist, stop and report the exact missing path.
3. Read first (from `<cwd>` at this point):
   - the main repo `AGENTS.md` for the repo you will touch
   - `<epic>/MASTER.md`

## Step selection
Use this selection policy:

1. If `$STORY` was provided:
   - use `<epic>/MASTER.md` as the only lookup table
   - first try to match exactly one row whose `Step` value equals `$STORY`
   - if no row matches by `Step`, try to match exactly one row whose `Spec`
     value equals `$STORY`
   - if neither lookup finds a row, stop and report the unresolved selector plus
     the available `Step` and `Spec` values from `MASTER.md`
   - if the `Step` lookup and `Spec` lookup both match but point to different
     rows, stop and report the ambiguity
   - resolve the selected step file from the matched row's `Spec` value
   - if that file does not exist under `<epic>/`, stop and report the exact
     missing path
   - inspect the resolved step row in `MASTER.md`
   - if it is not `🔄 IN PROGRESS`, stop and report the actual status
2. If `$STORY` was not provided:
   - collect every row in `MASTER.md` marked `🔄 IN PROGRESS`
   - also collect rows marked `🔵 IN PR` **only if** the PR is currently
     requesting code changes (check the step file's `## PR Tracking` section
     `PR status` field; treat `changes_requested` as a resumable signal)
   - if there are none:
     - stop after a concise report saying there is no active step to resume
     - recommend using the claim prompt instead
   - if there is exactly one:
     - select it
     - resolve the selected step file from that row's `Spec` value
     - if that file does not exist under `<epic>/`, stop and report the exact
       missing path
   - if there are multiple:
     - stop after a concise report listing each candidate story number and spec
       file
     - do not guess which ongoing step to continue
     - recommend rerunning with `STORY="<story_number>"` or
       `STORY="<exact_spec_file.md>"`

## Read before implementing
After the step is resolved, read:
1. the selected step file
2. dependency step files listed for it in `MASTER.md`
3. the latest relevant sections inside the step file:
   - `## Active Claim`
   - `## Progress Log`
   - `## Session Handoff`
   - `## Review Log`
   - `## PR Tracking` (only present on steps that went through `epic_pr`)

If the step is `🔵 IN PR` and the PR is requesting code changes, treat the
PR review comments as the authoritative CTA for this continuation and move
the step back to `🔄 IN PROGRESS` for the duration of the session.

## Worktree preflight

After reading the story file's `## Active Claim`, decide whether to continue from `<cwd>` or from an existing / newly-created linked git worktree on the story's branch.

1. **Not a git repo**. Run `git -C <cwd> rev-parse --is-inside-work-tree`. If non-zero, set `<project_root>` = `<cwd>` and skip the rest of this section.

2. **Read `Worktree:` from the story's `## Active Claim`**. If there is a bullet of the form `- Worktree: <path>`, store it as `<active_wt_path>`. Else `<active_wt_path>` is unset.

3. **Compute `<story-slug>`**. Strip the `.md` extension from the resolved step's spec file.

4. **Compute default path**:
   - `<repo-root>` = `git -C <cwd> rev-parse --show-toplevel`
   - `<repo-basename>` = `basename <repo-root>`
   - `<default-path>` = `/tmp/add-worktrees/<repo-basename>-$EPIC-<story-slug>`

5. **Dirtiness check**. `git -C <cwd> status --porcelain`. `<dirty>` = output non-empty.

6. **Decision**:

   a. **`<active_wt_path>` is set**:
      - Verify it with `git -C <cwd> worktree list --porcelain`. If there is a `worktree <active_wt_path>` line AND that path exists on disk, `<project_root>` = `<active_wt_path>` and skip to step 9 (no recreate needed).
      - Otherwise the recorded worktree is stale. If `$WORKTREE` is non-empty, use it (`<wt-path>` = `$WORKTREE`, go to step 7). Else prompt the operator:

        ```
        Recorded Worktree: <active_wt_path> is missing or not a registered git worktree.
        Recreate for this story?
          Default path: <default-path>  (recorded path: <active_wt_path>)
        Reply with a path, `default`, `recorded`, or `no`.
        ```

        - On `no`: warn, `<project_root>` = `<cwd>`, skip to step 10.
        - On `default`: `<wt-path>` = `<default-path>`.
        - On `recorded`: `<wt-path>` = `<active_wt_path>`.
        - On a path: `<wt-path>` = that path.
        - Proceed to step 7.

   b. **`<active_wt_path>` unset, `$WORKTREE` non-empty**:
      - `<wt-path>` = `$WORKTREE`. Proceed to step 7.

   c. **Both unset, `<dirty>` is true**:
      - Prompt the operator (same shape as `$epic_claim`):

        ```
        Main tree has uncommitted changes:
          <indented git status --porcelain output>
        This story has no recorded Worktree. Create one?
          Default path: <default-path>
        Reply with a path, `default`, or `no`.
        ```

        - On `no`: warn, `<project_root>` = `<cwd>`, skip to step 10.
        - Else: `<wt-path>` = resolved path. Proceed to step 7.

   d. **All unset, `<dirty>` is false**:
      - `<project_root>` = `<cwd>`. Skip to step 10.

7. **Create or reattach the worktree**:
   - `mkdir -p "$(dirname <wt-path>)"`.
   - Try reattach first (the branch likely already exists from the original `$epic_claim`): `git -C <cwd> worktree add <wt-path> $EPIC/<story-slug>`
   - If that fails because the branch `$EPIC/<story-slug>` does not exist, fall back to create: `git -C <cwd> worktree add -b $EPIC/<story-slug> <wt-path>`.
   - If either succeeds, continue. If both fail, report the git error verbatim and abort.

8. **Set `<project_root>`**. `<project_root>` = `<wt-path>`. Update `<epic>` to `<project_root>/agent_coordination/epics/$EPIC`.

9. **Re-read the story's current state from `<project_root>`**. Re-read `<epic>/MASTER.md` and the step file. The worktree's branch may have newer `## Progress Log`, `## Review Log`, or `## Session Handoff` entries than main — those are the ones that matter for this continuation.

10. **Pending coordination edits warning**. If `<project_root>` != `<cwd>` AND step 5 showed modified / staged files under `agent_coordination/` on main, warn: "pending changes to `agent_coordination/` on main will NOT be in the worktree — commit them on main and rerun, or proceed knowing they are stranded".

At the end of this section, `<project_root>` is set. All downstream file reads/writes use `<project_root>/...` (or `<epic>/...` derived from it). Git commands in later sections use `git -C <project_root> ...`.

## Source-of-truth hierarchy
1. `<epic>/MASTER.md`
2. the selected step file
3. dependency step files listed in the master table
4. repo code and tests

Anything else is background only unless the selected step explicitly requires it.
Do not infer identity from filename shape or naming conventions that are not
explicitly recorded in `MASTER.md`.

## Resume intent
Treat this as continuation work, not a new claim.

Use the latest concrete guidance in this order:
1. newest `Review Log` entry that contains blocking findings or a concrete next action
2. latest `Session Handoff`
3. latest `Progress Log` milestone
4. the step `Goal` / `Acceptance`

If these conflict, prefer the higher source in the list above and record the
conflict in the progress log.

## Claim refresh protocol
Before deep implementation work:
1. Refresh the existing `## Active Claim` section for the continuation session:

```md
## Active Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: Codex continuation session
- Scope: <one sentence for this pickup chunk>
- Worktree: <project_root>  (preserve / refresh this bullet when <project_root> != <cwd>; omit it otherwise)
- Primary write surfaces: <paths>
```

The `Worktree:` bullet must reflect the current `<project_root>`: if the preflight reused an existing worktree, keep the recorded path as-is; if it recreated a stale one at a new location, update the path; if `<project_root>` == `<cwd>`, omit the bullet entirely. Never delete a `Worktree:` bullet when `<project_root>` points at a worktree — other sessions depend on it for reattachment.

2. Append a new timestamped bullet under `## Progress Log`, for example:

```md
- <UTC ISO timestamp> Picked up existing in-progress step and resumed work from the latest handoff/review CTA.
```

3. Do not create a second `Active Claim` section.
4. Do not silently switch to a different step once work has started.

## Execution rules
- Treat `MASTER.md` plus the selected step file as the source of truth.
- Respect the latest review/handoff CTA before widening scope.
- Continue only this step plus required dependencies.
- Prefer code changes over restating plans.
- If the step is in progress because of review feedback, address that feedback
  first unless the source of truth now clearly supersedes it.
- If you discover an epic-wide architectural contradiction, update `MASTER.md`
  minimally and note it in the step file.
- If the step turns out to be blocked by a hard external dependency or
  contradiction, stop broadening scope and mark it clearly as blocked.

## Progress tracking
While working, keep the selected step file updated.

Append concise timestamped bullets under `## Progress Log` after meaningful
milestones, for example:
- design change locked
- files patched
- tests added/updated
- blocker discovered
- epic-wide finding recorded in `MASTER.md`
- review feedback addressed

Do not wait until the very end to record progress.

## Parallelism guard
Assume other fresh sessions may work on nearby steps.
- Avoid touching files outside the selected step's primary write surfaces unless
  required to finish the step correctly.
- If you must cross that boundary, record it immediately in the progress log.

## Finish protocol
At the end of the session, update the selected step file with:

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

Then update `MASTER.md` status for the selected row using this lifecycle:
- `🔄 IN PROGRESS`
  - implementation or requested-change work is still underway
- `🟣 IN REVIEW`
  - the outstanding implementation work is complete
  - the step is ready for a fresh review pass
- `🔵 IN PR` (optional)
  - local review passed and changes are in a GitHub PR awaiting remote review
    and merge
  - do not set this status from `epic_resume`; use the `epic_pr` flow to
    record PR metadata on the step file
- `✅ DONE`
  - only use this if a real review pass is completed and passes in this
    session AND any GitHub PR stage is merged
- `⛔ BLOCKED`
  - an external blocker prevents completion or review

Default rule:
1. resume at `🔄 IN PROGRESS`
2. once the outstanding implementation/requested-change work is complete, move
   to `🟣 IN REVIEW`
3. then either:
   - move straight to `✅ DONE` if no GitHub PR stage is needed, or
   - hand off to `epic_pr` which will transition to `🔵 IN PR`
4. if resuming a `🔵 IN PR` step that is requesting code changes, move it to
   `🔄 IN PROGRESS` while working, then back to `🔵 IN PR` via `epic_pr`
   (passing the same `PR_URL`) once the new push is ready for another PR
   review round
5. if the session ends before review is complete, leave it at `🟣 IN REVIEW`
6. if the session ends before implementation is complete, leave it at `🔄 IN PROGRESS`

If the epic's `MASTER.md` `Legend` section does not list `🔵 IN PR`, add it
immediately after the `🟣 IN REVIEW` line:

```md
- `🔵 IN PR` — local review passed, PR opened, awaiting GitHub review + merge
```

## Final response
In your final response, state:
- which step you resumed
- which story number and spec file you resumed
- its final status
- files changed
- whether the epic master was updated
- the exact next action for the next fresh session
