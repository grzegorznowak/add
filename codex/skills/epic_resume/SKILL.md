---
name: epic_resume
description: Pick up one already in-progress epic step and continue it
---

Resume: $EPIC / $STORY

Treat `$EPIC` as the exact directory name of an epic under the agent's current
working directory at:
`agent_coordination/epics/`

Treat `$STORY` as an optional selector. When provided, it may be either:
- the exact story number from the `Step` column in `<epic>/MASTER.md`, for
  example `03`
- the exact spec file name from the `Spec` column in `<epic>/MASTER.md`, for
  example `story-03-bootstrap-and-docs-rewrite.md`

`$WORKTREE` is an optional override for forcing worktree paths per target repo. Two value forms are accepted: `WORKTREE="<basename>=<path>"` for a single repo override (preferred), or comma-separated `WORKTREE="<basename1>=<path1>,<basename2>=<path2>"` for multiple repos. The legacy bare-path form `WORKTREE="<path>"` is still accepted but only when the story has exactly one target repo. When `$WORKTREE` is empty, the `## Worktree preflight` section reads any `- Worktrees:` list recorded in the story's `## Active Claim`, falls back to a legacy `- Worktree:` singular bullet for stories claimed before the multi-worktree format, and creates new worktrees on demand for any dirty target repo without a recorded entry.

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
1. Set `<workspace_root>` = `<cwd>` and resolve `<epic>` = `<workspace_root>/agent_coordination/epics/$EPIC`. `<workspace_root>` and `<epic>` are never re-anchored; coordination files always live here.
2. If `<epic>` does not exist, stop and report the exact missing path.
3. Read first (from `<workspace_root>`):
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

After reading the story file's `## Active Claim`, build `<project_root_map>` for this continuation session: reuse worktrees the original claim recorded, recreate stale ones, and fall back to on-the-fly creation for legacy stories that predate the multi-worktree format.

**Invariant**: `<workspace_root>` = `<cwd>`, always. All reads and writes under `agent_coordination/...` anchor at `<workspace_root>` unconditionally, regardless of any worktrees built below. Worktrees only redirect writes to `projects/<name>/...` paths and `git -C` commands for the corresponding sub-repo.

1. **Read `Worktrees:` from `## Active Claim`**. Parse the story file for a `- Worktrees:` bullet under `## Active Claim`. For each child bullet of the form `- <basename>: <path>`, record `<recorded_worktree_map>[<basename>]` = `<path>` (normalized absolute). If no `- Worktrees:` bullet exists, `<recorded_worktree_map>` is empty.

2. **Back-compat read for legacy single-form**. If `<recorded_worktree_map>` is empty, look for a legacy `- Worktree: <path>` (singular) bullet. If present, set `<recorded_worktree_map>[basename(<path>)]` = `<path>` and note the session is in back-compat mode (the next claim refresh in step 9 of `## Claim refresh protocol` will rewrite it as a `- Worktrees:` list).

3. **Parse `$WORKTREE` into `<explicit_worktree_map>`**. If `$WORKTREE` is empty, `<explicit_worktree_map>` is empty and `<legacy_worktree>` is unset. Otherwise:
   - Split `$WORKTREE` on commas into one or more entries.
   - For each entry: if it contains `=`, split on the FIRST `=` into `<basename>` and `<path>`, normalize `<path>` to an absolute path, and record as `<explicit_worktree_map>[<basename>]` = `<path>`. Otherwise treat the entry as the legacy single form and record as `<legacy_worktree>` (normalized absolute path).
   - Mixing both forms (some entries with `=`, some without) is an error: abort with "mix of legacy and `<basename>=<path>` forms in `$WORKTREE` is not allowed; use one or the other".
   - If `<legacy_worktree>` is set, defer its application until `<target_repos>` is computed in step 5; it is only valid when exactly one `<target_repo>` is discovered.

4. **Compute `<story-slug>`**. Strip the `.md` extension from the resolved step's spec file.

5. **Compute `<target_repos>`**:
   - If `<recorded_worktree_map>` is non-empty, build `<target_repos>` from its basenames: for each `<basename>`, resolve to `<workspace_root>/projects/<basename>` if `<workspace_root>/projects/<basename>/.git` exists, or to `<workspace_root>` if `<basename>` matches `basename(<workspace_root>)` AND `<workspace_root>` is itself a git repo. If a recorded basename resolves to neither, warn "recorded worktree for `<basename>` cannot be matched to any repo on disk" and retain it for downstream verification anyway.
   - Else (legacy story or fresh resume with no recorded worktree), fall back to the same target-discovery flow as `$epic_claim` (Worktree preflight steps 2–3): parse `## Scope` of the step file for `projects/[A-Za-z0-9_-]+/` tokens, intersect with real `<workspace_root>/projects/<name>/.git` repos, and additionally include `<workspace_root>` if it is itself a git repo.

   If `<legacy_worktree>` is set (from step 3), it is now applied: `<explicit_worktree_map>[basename(<sole_target_repo>)]` = `<legacy_worktree>` if `<target_repos>` has exactly one element, otherwise abort with "`WORKTREE=\"<path>\"` requires exactly one target repo; found N (basenames: ...). Use `WORKTREE=\"<basename>=<path>\"` to specify which repo".

6. **No targets**. If `<target_repos>` is empty, set `<project_root_map>` = `{}` and skip to step 10. The continuation will only touch `<workspace_root>/agent_coordination/...`.

7. **Per-repo decision**. Initialize `<project_root_map>` = `{}` and `<pending_prompt>` = `[]`. For each `<target_repo>` in `<target_repos>`, iterating in sorted order by basename:
   - `<repo-basename>` = `basename <target_repo>`.
   - `<default-path>` = `/tmp/add-worktrees/<repo-basename>-$EPIC-<story-slug>`.

   Branch on the four cases:

   **(a) Explicit override present** (`<explicit_worktree_map>[<repo-basename>]` is set): `<wt-path>` = explicit path. Mark for create-or-reattach in step 9 regardless of dirtiness.

   **(b) Recorded entry present** (`<recorded_worktree_map>[<repo-basename>]` is set, no explicit override): verify it via `git -C <target_repo> worktree list --porcelain`. If a `worktree <recorded path>` line exists AND the recorded path exists on disk, reuse: `<project_root_map>[<repo-basename>]` = recorded path. Skip step 9 for this repo. If the recorded entry is stale (path missing or unregistered), prompt the operator once for this repo:

   ```
   Recorded worktree for `<repo-basename>`: <recorded path> is missing or not registered.
   Recreate?
     Default path: <default-path>  (recorded: <recorded path>)
   Reply: `default`, `recorded`, a new path, or `no`.
   ```

   On `no`: `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree), warn "proceeding on dirty main tree for `<repo-basename>`" if the repo is dirty, otherwise no warning. On `default`: `<wt-path>` = `<default-path>`, mark for create-or-reattach. On `recorded`: `<wt-path>` = recorded path, mark for create-or-reattach. On a path: `<wt-path>` = normalized absolute, mark for create-or-reattach.

   **(c) Neither recorded nor explicit, `<target_repo>` is clean**: `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree). Done for this repo.

   **(d) Neither recorded nor explicit, `<target_repo>` is dirty**: append `(<repo-basename>, <target_repo>, <default-path>, <porcelain output>)` to `<pending_prompt>` — decision deferred to the batched prompt.

8. **Batched operator prompt** for case-(d) entries. If `<pending_prompt>` is non-empty, show ONE combined message (identical shape and parsing rules to `$epic_claim` step 7):

   ```
   These target repos have uncommitted changes:
     <repo-basename-1>:
       <indented porcelain output, capped at ~5 lines with "...and N more" suffix if truncated>
       Default worktree path: <default-path-1>
     <repo-basename-2>:
       <indented porcelain output...>
       Default worktree path: <default-path-2>

   Reply with one of:
     - `default` or `all` — create worktrees at all default paths
     - `no` — proceed on dirty main trees for all listed repos (NOT recommended)
     - one line per repo: `<repo-basename>: default | no | <path>`
   ```

   Parse the reply identically to `$epic_claim` step 7 (single token `default`/`all`/`no`, or multi-line `<repo-basename>: ...` form). On malformed input, re-prompt once with a clearer hint; on a second malformed reply, abort with "couldn't parse reply after two attempts; re-run `$epic_resume`". After parsing, for each pending repo: either set `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree mode) and warn, or resolve `<wt-path>` and mark for create-or-reattach in step 9.

9. **Create or reattach worktrees** for every repo marked in step 7 (cases a/b-stale-recreated) or step 8, iterating in sorted basename order:
   - `mkdir -p "$(dirname <wt-path>)"`
   - **Reattach first** (the branch likely already exists from the original `$epic_claim`): `git -C <target_repo> worktree add <wt-path> $EPIC/<story-slug>`
   - If reattach fails because the branch `$EPIC/<story-slug>` does not exist in `<target_repo>`, fall back to create: `git -C <target_repo> worktree add -b $EPIC/<story-slug> <wt-path>`.
   - If both fail with branch-already-exists in the create-fallback path (genuinely impossible after reattach failed), report the git error verbatim. List any worktrees already created earlier in this loop as "successfully created but NOT cleaned up: <list>" so the operator can decide whether to keep them, then abort. **Do NOT auto-clean up successful worktrees** on partial failure — preserve operator choice.
   - For any other git error: same verbatim-report-and-abort with "NOT cleaned up" list.
   - On success: `<project_root_map>[<repo-basename>]` = `<wt-path>`.

10. **Re-read the story's current state per worktree**. For every `<basename>` in `<project_root_map>` whose value is a worktree, re-read any branch-local files that the resume needs from that worktree path. Coordination files (`<epic>/MASTER.md`, the step file, dependency step files) are NOT re-read from worktrees — they remain anchored at `<workspace_root>/agent_coordination/...` unconditionally. Subsequent "Resume intent" prioritization operates on the workspace-anchored copies.

11. **Stale-recorded-entries warning**. If `<recorded_worktree_map>` had basenames that did not resolve to any real repo in step 5, retain those entries in the upcoming claim refresh (step 9 of `## Claim refresh protocol`) so they are not silently dropped, and warn: "recorded worktree for `<basename>` could not be resolved to any repo on disk — retained in next claim refresh for manual review".

12. **Conditional `<workspace_root>` sanity check**. Run this check ONLY if ALL of the following are true:
    - `<workspace_root>` is itself a git repo,
    - `<workspace_root>` is in `<target_repos>`,
    - `<project_root_map>[basename(<workspace_root>)]` is a worktree (not `<workspace_root>` itself).

    Then, if the original `git -C <workspace_root> status --porcelain` output mentioned files under `agent_coordination/`, warn: "pending changes to `agent_coordination/` on `<workspace_root>` main will NOT be in any worktree — commit them on main and rerun, or proceed knowing they are stranded". Do NOT run this check against sub-repo worktrees; sub-repos do not contain `agent_coordination/` at all.

13. **Done**. `<project_root_map>` is set. All downstream resolution uses these rules:
    - `<epic>/MASTER.md`, step files, and anything under `agent_coordination/...` → read/write at `<workspace_root>/agent_coordination/...` unconditionally.
    - Code at `projects/<name>/foo/bar` → if `<project_root_map>` has `<name>`, route to `<project_root_map>[<name>]/foo/bar`; else route to `<workspace_root>/projects/<name>/foo/bar`.
    - Git commands targeting repo `<name>`: `git -C <project_root_map>[<name>] ...` (or `git -C <workspace_root>/projects/<name> ...` if `<name>` is not in the map).

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
- Worktrees:
  - <repo-basename>: <absolute-worktree-path>
  - <repo-basename>: <absolute-worktree-path>
- Main-tree targets: <repo-basename>, <repo-basename>
- Primary write surfaces: <paths>
```

The `- Worktrees:` parent bullet must reflect the current `<project_root_map>`: list one child entry per repo whose value is an actual worktree (not the main tree). If the preflight reused recorded worktrees, keep their paths as-is; if it recreated stale entries at new locations, update those paths; if it added new entries (because the operator passed `$WORKTREE` for a previously-unrecorded repo or the scope expanded), include them. If `<project_root_map>` has no worktree entries, omit the `- Worktrees:` bullet entirely. Never delete a worktree entry that other sessions depend on for reattachment unless step 11 of the preflight explicitly retained it for manual review (in which case keep it). If the preflight read the story in back-compat mode (legacy singular `- Worktree:` bullet), this refresh rewrites it as the new `- Worktrees:` list — that is the one place legacy stories are migrated forward.

The `- Main-tree targets:` bullet lists every repo basename from `<project_root_map>` whose value is the repo's own main tree (i.e. NOT a worktree). This tells `$epic_review` that these repos were intentionally written to directly — their dirtiness at review time is the implementation itself. Omit when there are no main-tree target repos. If the previous claim had a `- Main-tree targets:` bullet, refresh it to reflect the current `<project_root_map>`.

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
- If you discover non-material proof-path drift, update the story's
  `## Verification` matrix immediately and record why in `## Progress Log`
  before continuing.
- If you discover material contract drift, pause feature work, record a
  replanning checkpoint in `## Progress Log`, update the story contract, and
  only then continue implementation.
- If the step turns out to be blocked by a hard external dependency or
  contradiction, stop broadening scope and mark it clearly as blocked.

## Progress tracking
While working, keep the selected step file updated.

Append concise timestamped bullets under `## Progress Log` after meaningful
milestones, for example:
- design change locked
- files patched
- tests added/updated
- proof matrix updated to match implementation reality
- replanning checkpoint recorded after material contract drift
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
