---
name: epic_story_claim
description: Claim one ready story from an epic and execute it
---

Story implementation: $EPIC / $STORY

Treat `$EPIC` as the exact directory name of an epic under the agent's current
working directory at:
`agent_coordination/epics`

`$STORY` is optional. When it is present, treat it as a `MASTER.md` `Step` value or `Spec` filename and claim exactly that ready unclaimed row. When it is empty, keep the existing behavior and select the first ready unclaimed story from `MASTER.md`.

`$WORKTREE` is an optional explicit opt-in for forcing worktree paths per target repo. Two value forms are accepted: `WORKTREE="<basename>=<path>"` for a single repo override (preferred), or comma-separated `WORKTREE="<basename1>=<path1>,<basename2>=<path2>"` for multiple repos. The legacy bare-path form `WORKTREE="<path>"` is still accepted but only when the story has exactly one target repo. When `$WORKTREE` is empty, the `## Worktree preflight` section discovers target sub-repos from the selected step's `## Scope` and creates one worktree per dirty target repo automatically; clean target repos are written to directly.

Your job is to pick exactly one ready and unclaimed story from that epic,
claim it in the coordination docs, execute it, and leave behind a clean handoff.


Do **not** try to rediscover or redefine the epic from scratch.
The workflow is:
1. read the epic master
2. pick one ready step
3. claim it
4. inspect sources and choose the smallest focused red seam
5. work only that step plus required dependencies
6. move it to `IN REVIEW` after implementation is complete
7. leave the step file in a state that the next fresh session can continue

## Resolution
1. Set `<workspace_root>` = `<cwd>` and resolve `<epic>` = `<workspace_root>/agent_coordination/epics/$EPIC`. `<workspace_root>` and `<epic>` are never re-anchored; coordination files always live here.
2. If `<epic>` does not exist, stop and report the exact missing path.
3. Read first (from `<workspace_root>`):
   - the main repo `AGENTS.md` for the repo you will touch
   - `<epic>/MASTER.md`

## Source-of-truth hierarchy
1. `<epic>/MASTER.md`
2. the claimed step file
3. dependency step files listed in the master table
4. repo code and tests

Anything else is background only unless the claimed step explicitly requires it.

## Shared Research Board Input

When launched by a converger, you may receive `Shared Research Board from parent orchestration session` before the slash command. This is the only allowed cross-session context beyond neutral operational notes. Use it as sourced orientation only. The converger owns keeping it relevant; you only decide whether the needed fact is present in the provided board. If present, verify it with direct reads/search against the cited anchors before it affects implementation, proof updates, or coordination write-back instead of rerunning expensive research. If absent, follow this skill's normal research rules. Ignore any board item that lacks an exact source anchor such as `path:line`, symbol, command/output excerpt, or tool/query/path.

## Step selection
If `$STORY` is present:
- use `<epic>/MASTER.md` as the only lookup table
- first try to match exactly one row whose `Step` value equals `$STORY`
- if no row matches by `Step`, try to match exactly one row whose `Spec` value equals `$STORY`
- if neither lookup finds a row, stop and report the unresolved selector plus the available `Step` and `Spec` values from `MASTER.md`
- if the `Step` lookup and `Spec` lookup both match but point to different rows, stop and report the ambiguity
- select that matched row only; never fall back to a different ready row

If `$STORY` is empty, preserve the original behavior: from `<epic>/MASTER.md`, select the first step that is all of:
- plan-approved:
  - if the tracker has a `Plan` column, `Plan` is exactly `🟢 PLAN APPROVED`
  - if the tracker has no `Plan` column, the newest effective `## Plan Review Log` verdict is `approve`, with no later unresolved `request_changes`, `not_reviewable`, or `blocked`
- unclaimed:
  - status is `⬜ TODO`, `⚪ TODO`, `TODO`, or otherwise clearly unclaimed
- ready:
  - every dependency listed in `Depends` is marked `✅ DONE` or `DONE`
- concrete:
  - the referenced step file exists

After a row is selected by either path, verify it is all of:
- plan-approved:
  - if the tracker has a `Plan` column, `Plan` is exactly `🟢 PLAN APPROVED`
  - if the tracker has no `Plan` column, the newest effective `## Plan Review Log` verdict is `approve`, with no later unresolved `request_changes`, `not_reviewable`, or `blocked`
- unclaimed:
  - status is `⬜ TODO`, `⚪ TODO`, `TODO`, or otherwise clearly unclaimed
- ready:
  - every dependency listed in `Depends` is marked `✅ DONE` or `DONE`
- concrete:
  - the referenced step file exists

If no such step exists, or the targeted row is not claimable:
- do not guess or switch rows
- stop after a concise report listing:
  - plan approval state, with next action `epic_story_plan_converge $EPIC <story>` when not approved
  - no-ready-step reason
  - blocked steps
  - next step that must complete first

## Worktree preflight

After picking a step but before writing any claim, figure out which repos the step will write to, whether any of them are dirty, and for each dirty target build a linked git worktree on the story-specific branch. Clean target repos are written to directly; implementation work on dirty repos happens in a clean branch isolated from whatever else was in the main tree.

**Invariant**: `<workspace_root>` = `<cwd>`, always. All reads and writes under `agent_coordination/...` anchor at `<workspace_root>` unconditionally, regardless of any worktrees created below. Worktrees only redirect writes to `projects/<name>/...` paths and `git -C` commands for the corresponding sub-repo.

1. **Compute `<story-slug>`**. Strip the `.md` extension from the selected step's spec file. Example: `story-03-bootstrap-and-docs-rewrite.md` → `story-03-bootstrap-and-docs-rewrite`.

2. **Parse `## Scope` for target paths**. In the selected step file, extract the text between the line matching `^## Scope$` and the next line matching `^## ` (any heading), or EOF if no next heading. Inside that text, find every substring matching the regex `projects/[A-Za-z0-9_-]+/` and deduplicate to `<scope_prefixes>` — the set of `<name>` values found. If the step file has no `## Scope` section, `<scope_prefixes>` is empty.

3. **Resolve `<target_repos>`**. Initialize `<target_repos>` as an empty set. For each `<name>` in `<scope_prefixes>`:
   - If `<workspace_root>/projects/<name>/.git` exists (a directory OR a gitlink file — test with `test -e`, not `git rev-parse`), add absolute `<workspace_root>/projects/<name>` to `<target_repos>`.
   - Otherwise skip silently (stale reference to a repo no longer on disk).

   Additionally, run `git -C <workspace_root> rev-parse --is-inside-work-tree`. If it succeeds, add `<workspace_root>` to `<target_repos>`. This preserves the single-repo case (where `<cwd>` itself is the code repo) and the nested-monorepo case.

4. **No targets**. If `<target_repos>` is empty, set `<project_root_map>` = `{}` and skip to step 10. The story will only touch workspace-root paths like `<workspace_root>/agent_coordination/...`.

5. **Parse `$WORKTREE` into `<explicit_worktree_map>`**. If `$WORKTREE` is empty, `<explicit_worktree_map>` is empty and `<legacy_worktree>` is unset. Otherwise:
   - Split `$WORKTREE` on commas into one or more entries.
   - For each entry: if it contains `=`, split on the FIRST `=` into `<basename>` and `<path>`, normalize `<path>` to an absolute path, and record as `<explicit_worktree_map>[<basename>]` = `<path>`. Otherwise treat the entry as the legacy single form and record as `<legacy_worktree>` (normalized absolute path).
   - Mixing both forms (some entries with `=`, some without) is an error: abort with "mix of legacy and `<basename>=<path>` forms in `$WORKTREE` is not allowed; use one or the other".
   - If `<legacy_worktree>` is set, it is only valid when exactly one `<target_repo>` was discovered. Apply it as `<explicit_worktree_map>[basename(<target_repo>)]` = `<legacy_worktree>`. Otherwise abort with "`WORKTREE=\"<path>\"` requires exactly one target repo; found N (basenames: ...). Use `WORKTREE=\"<basename>=<path>\"` to specify which repo".

6. **Per-repo dirty check and decision**. Initialize `<project_root_map>` = `{}` and `<pending_prompt>` = `[]`. For each `<target_repo>` in `<target_repos>`, iterating in sorted order by basename for determinism:
   - `<repo-basename>` = `basename <target_repo>`.
   - `<dirty>` = `git -C <target_repo> status --porcelain` output non-empty.
   - `<default-path>` = `$HOME/add-worktrees/<repo-basename>-$EPIC-<story-slug>`.
   - If `<explicit_worktree_map>[<repo-basename>]` is set: mark for creation with `<wt-path>` = that path, regardless of dirtiness.
   - Else if `<dirty>`: append `(<repo-basename>, <target_repo>, <default-path>, <porcelain output>)` to `<pending_prompt>` — decision deferred to the batched prompt in step 7.
   - Else (clean, no override): `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree). Done for this repo.

7. **Batched operator prompt**. If `<pending_prompt>` is non-empty, show ONE combined message:

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

   Parse the reply:
   - Single token `default` or `all`: every pending repo gets its own `<default-path>`.
   - Single token `no`: every pending repo resolves to its `<target_repo>` (main tree) and is annotated "proceeding on dirty main tree for `<basename>`".
   - Multi-line form: each line must match `<repo-basename>: (default|no|<path>)`. Lines for basenames not in `<pending_prompt>` are ignored with a warning. Basenames in `<pending_prompt>` missing a line are an error.
   - Anything else (unparseable, partial, or mixed): re-prompt ONCE with a clearer hint restating the three acceptable reply forms. On a second malformed reply, abort with "couldn't parse reply after two attempts; re-run `$epic_story_claim`". No `MASTER.md` or story-file writes have happened yet — aborting is safe.

   After parsing, for each pending repo: either set `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree mode) and warn, or resolve `<wt-path>` and mark for creation.

8. **Create worktrees** for every repo marked for creation in step 6 or 7, iterating in sorted basename order:
   - `mkdir -p "$(dirname <wt-path>)"`
   - `git -C <target_repo> worktree add -b $EPIC/<story-slug> <wt-path>`
   - If it fails because the branch `$EPIC/<story-slug>` already exists in `<target_repo>`, abort with: "story branch `$EPIC/<story-slug>` already exists in repo `<repo-basename>`; this looks like a resumable story — run `$epic_story_resume EPIC=\"$EPIC\"` instead". List any worktrees already created earlier in this loop as "successfully created but NOT cleaned up: <list>" so the operator can decide whether to keep them. No `MASTER.md` or story-file writes have happened yet.
   - If it fails for any other reason, report the git error verbatim, list successful worktrees as "NOT cleaned up", and abort. **Do NOT auto-clean up successful worktrees** on partial failure — preserve operator choice.
   - On success: `<project_root_map>[<repo-basename>]` = `<wt-path>`.

9. **Conditional `<workspace_root>` sanity check**. Run this check ONLY if ALL of the following are true:
   - `<workspace_root>` is itself a git repo (step 3's `rev-parse --is-inside-work-tree` succeeded),
   - `<workspace_root>` is in `<target_repos>`,
   - `<project_root_map>[basename(<workspace_root>)]` is a worktree (not `<workspace_root>` itself).

   Then run `git -C <project_root_map>[basename(<workspace_root>)] ls-files --error-unmatch agent_coordination/epics/$EPIC/MASTER.md`. If it fails, abort with: "agent_coordination/ appears to be ignored or uncommitted in `<workspace_root>`'s repo; commit the epic files first, then re-run `$epic_story_claim`".

   Additionally, if `<workspace_root>` is a git repo AND its step-6 porcelain output mentioned files under `agent_coordination/`, warn: "pending changes to `agent_coordination/` on `<workspace_root>` main will NOT be in any worktree — commit them on main and rerun, or proceed knowing they are stranded".

   Do NOT run this check against sub-repo worktrees; sub-repos do not contain `agent_coordination/` at all.

10. **Done**. `<project_root_map>` is set. All downstream resolution uses these rules:
    - `<epic>/MASTER.md`, step files, and anything under `agent_coordination/...` → read/write at `<workspace_root>/agent_coordination/...` unconditionally.
    - Code at `projects/<name>/foo/bar` → if `<project_root_map>` has `<name>`, route to `<project_root_map>[<name>]/foo/bar`; else route to `<workspace_root>/projects/<name>/foo/bar`.
    - Git commands targeting repo `<name>`: `git -C <project_root_map>[<name>] ...` (or `git -C <workspace_root>/projects/<name> ...` if `<name>` is not in the map).

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
- Worktrees:
  - <repo-basename>: <absolute-worktree-path>
  - <repo-basename>: <absolute-worktree-path>
- Main-tree targets: <repo-basename>, <repo-basename>
- Primary write surfaces: <paths>

## Progress Log
- <UTC ISO timestamp> Claimed step and started implementation.
```

The `- Worktrees:` parent bullet is present if and only if at least one entry in `<project_root_map>` resolves to a real worktree (i.e. `<project_root_map>[<basename>]` != `<workspace_root>/projects/<basename>` and != `<workspace_root>`). List only those repos whose value is an actual worktree; repos resolved to main tree are NOT listed (their absence implies main-tree mode). If `<project_root_map>` has no worktree entries (all targets clean, or no targets, or operator answered `no` for every dirty repo), omit the `- Worktrees:` bullet entirely — do not write it with no children.

The `- Main-tree targets:` bullet lists every repo basename from `<project_root_map>` whose value is the repo's own main tree (i.e. NOT a worktree). This tells `$epic_story_review` that these repos were intentionally written to directly — their dirtiness at review time is the implementation itself. Omit this bullet when there are no main-tree target repos (all targets got worktrees, or no targets at all).

3. Do not claim more than one step in a single session.
4. Do not silently switch to a different step once work has started.

## Execution rules
- Treat `MASTER.md` plus the claimed step file as the source of truth.
- Read dependency step files for context, but do not widen scope unless required
  to finish the claimed step correctly.
- Inspect the relevant code and tests before the first change. Use the story's
  `## Verification`, `## Critical Files`, and `## Discovery Notes` to choose
  the smallest focused seam that covers the next behavior.
- Run a Debt Friction check before the first patch: ask whether implementation
  is being made harder by unclear ownership, duplicated behavior, weak or mocked
  tests, missing seams, hidden behavior, or unsafe structure. Only write a
  `Debt Friction` entry when there is a story-local causal link: current story
  action -> concrete evidence -> delivery impact -> explicit decision.
- Default to red-first: make that focused seam fail, implement until it
  passes, then broaden verification.
- Do not jump straight to broad suites or code-first implementation if a
  smaller focused seam is available.
- Implement the claimed step end-to-end when feasible.
- Prefer code changes over restating plans.
- If you discover an epic-wide architectural contradiction, update `MASTER.md`
  minimally and note it in the step file.
- If you discover non-material proof-path drift, update the story's
  `## Verification` matrix immediately and record why in `## Progress Log`
  before continuing.
- If you discover material contract drift, pause feature work, record a
  replanning checkpoint in `## Progress Log`, update the story contract, and
  only then continue implementation.
- If red-first is not feasible, record an explicit written exception in
  `## Progress Log` before proceeding. Name the reason, the alternative proof
  seam, and the verification path you will use instead.
- If Debt Friction exists, record it in `## Progress Log` using the
  `docs/epic-conventions.md` shape. Use `fix-now` only for enabling cleanup
  directly required to make this story correct, testable, reviewable, or safely
  maintainable; include `Scope Justification`. Use `split-story`,
  `defer-explicitly`, or `block` for debt that is non-enabling, too large, too
  non-local, or proof-blocking.
- If the claimed step turns out to be blocked by an unmet dependency or hard
  contradiction, stop broadening scope and mark it clearly as blocked.

## Progress tracking
While working, keep the claimed step file updated.

Append concise timestamped bullets under `## Progress Log` after meaningful
milestones, for example:
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
- Red-first path: <focused seam + red/green outcome, or explicit exception + alternative proof path>
- Tests run: <commands/results or not run>
- Remaining work: <short bullets>
- Unresolved Debt Friction: <split-story / defer-explicitly / block / unfinished fix-now entries, or none>
- Blockers / risks: <short bullets>
- Exact next step: <one concrete recommendation>
```

Before transitioning to `✅ DONE`, offer to check in worktree changes. For each worktree in `## Active Claim` -> `- Worktrees:`, run `git -C <path> status --porcelain`. If dirty, propose `git -C <path> add -A && git -C <path> commit -m "<epic>/<story-slug>: <worksummary>"` and execute on operator confirmation. If all worktrees are clean, skip.

Then update `MASTER.md` status for the claimed row using this lifecycle:
- `🔄 IN PROGRESS`
  - implementation is still actively underway
- `🟣 IN REVIEW`
  - implementation is done enough for review
  - the focused red seam is green or an explicit exception is recorded
  - run final verification, review the touched files, and tighten any rough edges
  - do not mark `DONE` before this pass
- `🔵 IN PR` (optional)
  - local review passed and the changes are in a GitHub pull request awaiting
    remote review and merge
  - do not set this status from `epic_story_claim`; use the `epic_story_pr` flow to record
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
   - use `epic_story_pr` to transition to `🔵 IN PR` and move to `✅ DONE` only
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
- `## Research Events` with reused board entries and newly sourced research; for reused entries, name the board entry plus the direct-read/search anchors used to verify it; for new research, include exact anchors; use `- None.` when no research was used or produced
- the exact next action for the next fresh session
