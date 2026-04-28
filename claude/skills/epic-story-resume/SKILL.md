---
name: epic-story-resume
description: Pick up one already in-progress story from an epic and continue it. Use when a fresh session needs to resume ongoing work on a specific story.
disable-model-invocation: true
argument-hint: "<epic-name> [story-number-or-spec-file]"
allowed-tools: Read Edit Write Grep Glob Bash
---

# Epic Story Resume

Continue exactly one already-ongoing story, following the existing handoff / review guidance, and leave the coordination docs in a state the next fresh session can trust.

Argument: `$ARGUMENTS` — `<epic_name> [<story_number_or_spec_file>] [WORKTREE="<basename>=<path>"]...`. The epic name is required. The story selector is optional; when omitted and there is exactly one in-progress step, it is selected automatically. `WORKTREE=` is an optional, repeatable opt-in that overrides the preflight's default decision per target repo. Two forms are accepted: `WORKTREE="<basename>=<path>"` (multi form, repeatable, preferred) and legacy `WORKTREE="<path>"` (valid only when the story has exactly one target repo; the path is applied to that sole repo). Mixing the two forms in a single invocation is an error. When `WORKTREE=` is absent, the preflight reads any `- Worktrees:` list recorded in the story's `## Active Claim`, falling back to a legacy `- Worktree:` singular bullet for stories claimed before the multi-worktree format.

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
   - The raw list of `WORKTREE="<value>"` occurrences (parsed in `## Worktree preflight` step 3 into `<explicit_worktree_map>` and/or `<legacy_worktree>`)
2. Set `<workspace_root>` = `<cwd>` and resolve `<epic>` = `<workspace_root>/agent_coordination/epics/<epic-name>`. `<workspace_root>` and `<epic>` are never re-anchored; coordination files always live here.
3. If `<epic>` does not exist, stop and report the exact missing path.
4. Read first (from `<workspace_root>`):
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
- if there are none, stop and recommend `/epic-story-claim` instead
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
   - `## PR Tracking` (only present on steps that went through `/epic-story-pr`)

If the step is `🔵 IN PR` and the PR is requesting code changes, treat the PR review comments as the authoritative CTA for this continuation and move the step back to `🔄 IN PROGRESS` for the duration of the session.

## Worktree preflight

After reading the story file's `## Active Claim`, build `<project_root_map>` for this continuation session: reuse worktrees the original claim recorded, recreate stale ones, and fall back to on-the-fly creation for legacy stories that predate the multi-worktree format.

**Invariant**: `<workspace_root>` = `<cwd>`, always. All reads and writes under `agent_coordination/...` anchor at `<workspace_root>` unconditionally, regardless of any worktrees built below. Worktrees only redirect writes to `projects/<name>/...` paths and `git -C` commands for the corresponding sub-repo.

1. **Read `Worktrees:` from `## Active Claim`**. Parse the story file for a `- Worktrees:` bullet under `## Active Claim`. For each child bullet of the form `- <basename>: <path>`, record `<recorded_worktree_map>[<basename>]` = `<path>` (normalized absolute). If no `- Worktrees:` bullet exists, `<recorded_worktree_map>` is empty.

2. **Back-compat read for legacy single-form**. If `<recorded_worktree_map>` is empty, look for a legacy `- Worktree: <path>` (singular) bullet. If present, set `<recorded_worktree_map>[basename(<path>)]` = `<path>` and note the session is in back-compat mode (the next claim refresh in step 9 will rewrite it as a `- Worktrees:` list).

3. **Parse explicit `WORKTREE=` arguments** into `<explicit_worktree_map>`. Collect every `WORKTREE="<value>"` occurrence from `$ARGUMENTS`. For each value:
   - If it contains `=`, split on the FIRST `=` into `<basename>` and `<path>`. Normalize `<path>` to an absolute path and record as `<explicit_worktree_map>[<basename>]` = `<path>`.
   - Otherwise treat it as the legacy single form and record as `<legacy_worktree>` (normalized absolute path).

   Validation:
   - Mixing both forms (some `WORKTREE=` with `=`, some without) is an error: abort with "mix of `WORKTREE=\"path\"` and `WORKTREE=\"basename=path\"` forms is not allowed; use one or the other".
   - If `<legacy_worktree>` is set, defer its application until `<target_repos>` is computed in step 5; it is only valid when exactly one `<target_repo>` is discovered.

4. **Compute `<story-slug>`**. Strip the `.md` extension from the resolved step's spec file. Example: `story-03-bootstrap-and-docs-rewrite.md` → `story-03-bootstrap-and-docs-rewrite`.

5. **Compute `<target_repos>`**:
   - If `<recorded_worktree_map>` is non-empty, build `<target_repos>` from its basenames: for each `<basename>`, resolve to `<workspace_root>/projects/<basename>` if `<workspace_root>/projects/<basename>/.git` exists, or to `<workspace_root>` if `<basename>` matches `basename(<workspace_root>)` AND `<workspace_root>` is itself a git repo. If a recorded basename resolves to neither, warn "recorded worktree for `<basename>` cannot be matched to any repo on disk" and retain it for downstream verification anyway.
   - Else (legacy story or fresh resume with no recorded worktree), fall back to the same target-discovery flow as `/epic-story-claim` (Worktree preflight steps 2–3): parse `## Scope` of the step file for `projects/[A-Za-z0-9_-]+/` tokens, intersect with real `<workspace_root>/projects/<name>/.git` repos, and additionally include `<workspace_root>` if it is itself a git repo.

   If `<legacy_worktree>` is set (from step 3), it is now applied: `<explicit_worktree_map>[basename(<sole_target_repo>)]` = `<legacy_worktree>` if `<target_repos>` has exactly one element, otherwise abort with "`WORKTREE=\"<path>\"` requires exactly one target repo; found N (basenames: ...). Pass `WORKTREE=\"<basename>=<path>\"` form to specify which repo".

6. **No targets**. If `<target_repos>` is empty, set `<project_root_map>` = `{}` and skip to step 10. The continuation will only touch `<workspace_root>/agent_coordination/...`.

7. **Per-repo decision**. Initialize `<project_root_map>` = `{}` and `<pending_prompt>` = `[]`. For each `<target_repo>` in `<target_repos>`, iterating in sorted order by basename:
   - `<repo-basename>` = `basename <target_repo>`.
   - `<default-path>` = `$HOME/add-worktrees/<repo-basename>-<epic-name>-<story-slug>`.

   Branch on the four cases:

   **(a) Explicit override present** (`<explicit_worktree_map>[<repo-basename>]` is set): `<wt-path>` = explicit path. Mark for create-or-reattach in step 8 regardless of dirtiness.

   **(b) Recorded entry present** (`<recorded_worktree_map>[<repo-basename>]` is set, no explicit override): verify it via `git -C <target_repo> worktree list --porcelain`. If a `worktree <recorded path>` line exists AND the recorded path exists on disk, reuse: `<project_root_map>[<repo-basename>]` = recorded path. Skip step 8 for this repo. If the recorded entry is stale (path missing or unregistered), prompt the operator once for this repo:

   ```
   Recorded worktree for `<repo-basename>`: <recorded path> is missing or not registered.
   Recreate?
     Default path: <default-path>  (recorded: <recorded path>)
   Reply: `default`, `recorded`, a new path, or `no`.
   ```

   On `no`: `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree), warn "proceeding on dirty main tree for `<repo-basename>`" if the repo is dirty, otherwise no warning. On `default`: `<wt-path>` = `<default-path>`, mark for create-or-reattach. On `recorded`: `<wt-path>` = recorded path, mark for create-or-reattach. On a path: `<wt-path>` = normalized absolute, mark for create-or-reattach.

   **(c) Neither recorded nor explicit, `<target_repo>` is clean**: `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree). Done for this repo.

   **(d) Neither recorded nor explicit, `<target_repo>` is dirty**: append `(<repo-basename>, <target_repo>, <default-path>, <porcelain output>)` to `<pending_prompt>` — decision deferred to the batched prompt.

8. **Batched operator prompt** for case-(d) entries. If `<pending_prompt>` is non-empty, show ONE combined message (identical shape and parsing rules to `/epic-story-claim` step 7):

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

   Parse the reply identically to `/epic-story-claim` step 7 (single token `default`/`all`/`no`, or multi-line `<repo-basename>: ...` form). On malformed input, re-prompt once with a clearer hint; on a second malformed reply, abort with "couldn't parse reply after two attempts; re-run /epic-story-resume". After parsing, for each pending repo: either set `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree mode) and warn, or resolve `<wt-path>` and mark for create-or-reattach in step 9.

9. **Create or reattach worktrees** for every repo marked in step 7 (cases a/b-stale-recreated) or step 8, iterating in sorted basename order:
   - `mkdir -p "$(dirname <wt-path>)"`
   - **Reattach first** (the branch likely already exists from the original `/epic-story-claim`): `git -C <target_repo> worktree add <wt-path> <epic-name>/<story-slug>`
   - If reattach fails because the branch `<epic-name>/<story-slug>` does not exist in `<target_repo>`, fall back to create: `git -C <target_repo> worktree add -b <epic-name>/<story-slug> <wt-path>`.
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
- Worktrees:
  - <repo-basename>: <absolute-worktree-path>
  - <repo-basename>: <absolute-worktree-path>
- Main-tree targets: <repo-basename>, <repo-basename>
- Primary write surfaces: <paths>
```

The `- Worktrees:` parent bullet must reflect the current `<project_root_map>`: list one child entry per repo whose value is an actual worktree (not the main tree). If the preflight reused recorded worktrees, keep their paths as-is; if it recreated stale entries at new locations, update those paths; if it added new entries (because the operator passed `WORKTREE=` for a previously-unrecorded repo or the scope expanded), include them. If `<project_root_map>` has no worktree entries, omit the `- Worktrees:` bullet entirely. Never delete a worktree entry that other sessions depend on for reattachment unless step 11 of the preflight explicitly retained it for manual review (in which case keep it). If the preflight read the story in back-compat mode (legacy singular `- Worktree:` bullet), this refresh rewrites it as the new `- Worktrees:` list — that is the one place legacy stories are migrated forward.

The `- Main-tree targets:` bullet lists every repo basename from `<project_root_map>` whose value is the repo's own main tree (i.e. NOT a worktree). This tells `/epic-story-review` that these repos were intentionally written to directly — their dirtiness at review time is the implementation itself. Omit when there are no main-tree target repos. If the previous claim had a `- Main-tree targets:` bullet, refresh it to reflect the current `<project_root_map>`.

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
- Inspect the relevant code and tests before the first change in this session. Use the story's `## Verification`, `## Critical Files`, `## Discovery Notes`, and latest runtime notes to choose the smallest focused seam for the next behavior.
- Run a Debt Friction check before the first patch in this session: ask whether implementation is being made harder by unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure. Only write a `Debt Friction` entry when there is a story-local causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.
- Default to red-first: make that focused seam fail, implement until it passes, then broaden verification.
- Do not jump straight to broad suites or code-first implementation if a smaller focused seam is available.
- Prefer code changes over restating plans
- If the step is in progress because of review feedback, address that feedback first
- If you discover an epic-wide architectural contradiction, update `MASTER.md` minimally and note it in the step file
- If you discover non-material proof-path drift, update the story's `## Verification` matrix immediately and record why in `## Progress Log` before continuing
- If you discover material contract drift, pause feature work, record a replanning checkpoint in `## Progress Log`, update the story contract, and only then continue implementation
- If red-first is not feasible, record an explicit written exception in `## Progress Log` before proceeding. Name the reason, the alternative proof seam, and the verification path you will use instead.
- If Debt Friction exists, record it in `## Progress Log` using the `docs/epic-conventions.md` shape. Use `fix-now` only for enabling cleanup directly required to make this story correct, testable, reviewable, or safely maintainable; include `Scope Justification`. Use `split-story`, `defer-explicitly`, or `block` for debt that is non-enabling, too large, too non-local, or proof-blocking.
- If the step is blocked by a hard external dependency or contradiction, stop broadening scope and mark it `⛔ BLOCKED`

## Progress tracking

Append concise timestamped bullets under `## Progress Log` after meaningful milestones. Examples:
- focused red seam chosen
- focused seam turned green
- design change locked
- files patched
- tests added/updated
- proof matrix updated to match implementation reality
- replanning checkpoint recorded after material contract drift
- red-first exception recorded with alternative proof seam
- Debt Friction recorded with decision and guardrail
- blocker discovered
- epic-wide finding recorded in `MASTER.md`
- review feedback addressed

Do not wait until the end to record progress.

## Parallelism guard

Avoid touching files outside the selected step's primary write surfaces unless required. Record any boundary crossing in the progress log.

## Finish protocol

At the end of the session:

```md
## Session Handoff
- Status: done | blocked | in progress | in review
- What changed: <short bullets>
- Files touched: <paths>
- Red-first path: <focused seam + red/green outcome, or explicit exception + alternative proof path>
- Tests run: <commands/results or not run>
- Remaining work: <short bullets>
- Unresolved Debt Friction: <split-story / defer-explicitly / block / unfinished fix-now entries, or none>
- Blockers / risks: <short bullets>
- Exact next step: <one concrete recommendation>
```

Update `MASTER.md` status using this lifecycle:
- `🔄 IN PROGRESS` — implementation or requested-change work still underway
- `🟣 IN REVIEW` — outstanding implementation work complete, focused seam green or exception recorded, ready for a fresh review pass
- `🔵 IN PR` (optional) — local review passed, PR awaiting GitHub review + merge. **Do not set this status from `/epic-story-resume`**; use `/epic-story-pr` to record PR metadata.
- `✅ DONE` — only if a real review pass completes and passes in this session AND any PR stage is merged
- `⛔ BLOCKED` — external blocker prevents completion or review

**Default rule:**
1. Resume at `🔄 IN PROGRESS`
2. Once the chosen focused seam is green and outstanding implementation is complete, move to `🟣 IN REVIEW`
3. Then either move straight to `✅ DONE` if no PR stage is needed, or hand off to `/epic-story-pr` which transitions to `🔵 IN PR`
4. If resuming a `🔵 IN PR` step that is requesting changes, move to `🔄 IN PROGRESS` while working, then back to `🔵 IN PR` via `/epic-story-pr` once the new push is ready for another review round
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
