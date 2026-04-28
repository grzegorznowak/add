---
name: epic-story-claim
description: Claim one ready story from an epic and execute it end-to-end, leaving a clean handoff. Use when starting a fresh session on a new story from an epic's MASTER.md tracker.
disable-model-invocation: true
argument-hint: "<epic-name>"
allowed-tools: Read Edit Write Grep Glob Bash
---

# Epic Story Claim

Pick exactly one ready, unclaimed story from an epic, claim it, execute it, and leave a clean handoff for the next session.

Argument: `$ARGUMENTS` — `<epic-name> [WORKTREE="<basename>=<path>"]...`. The epic name is the first bare positional token (e.g. `cure-core-review-pipeline`) and resolves to `agent_coordination/epics/<epic-name>`; if omitted and there is exactly one active epic under `agent_coordination/epics/`, default to that one. `WORKTREE=` is an optional, repeatable opt-in that forces a worktree to be created (or reused) at a specific path for a specific target repo. Two forms are accepted: `WORKTREE="<basename>=<path>"` (multi form, repeatable, preferred) and legacy `WORKTREE="<path>"` (valid only when the story has exactly one target repo; the path is applied to that sole repo). Mixing the two forms in a single invocation is an error. When `WORKTREE=` is absent, the `## Worktree preflight` section creates a worktree for any discovered target repo whose `git status --porcelain` is non-empty; clean target repos are written to directly.

Do **not** try to rediscover or redefine the epic from scratch. Do **not** claim more than one step in a single session.

## Workflow
1. Read the epic `MASTER.md`
2. Pick one ready step
3. Claim it
4. Inspect sources and choose the smallest focused red seam
5. Work only that step plus required dependencies
6. Move it to `🟣 IN REVIEW` after implementation is complete
7. Leave the step file in a state the next fresh session can continue

## Resolution

1. Parse `$ARGUMENTS` into:
   - `<epic-name>`: the first bare positional token (falls back to the single active epic under `agent_coordination/epics/` if omitted)
   - The raw list of `WORKTREE="<value>"` occurrences (parsed in `## Worktree preflight` step 5 into `<explicit_worktree_map>` and/or `<legacy_worktree>`)
2. Set `<workspace_root>` = `<cwd>` and resolve `<epic>` = `<workspace_root>/agent_coordination/epics/<epic-name>`. `<workspace_root>` and `<epic>` are never re-anchored; coordination files always live here.
3. If `<epic>` does not exist, stop and report the exact missing path.
4. Read first (from `<workspace_root>`):
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

After picking a step but before writing any claim, figure out which repos the step will write to, whether any of them are dirty, and for each dirty target build a linked git worktree on the story-specific branch. Clean target repos are written to directly; implementation work on dirty repos happens in a clean branch isolated from whatever else was in the main tree.

**Invariant**: `<workspace_root>` = `<cwd>`, always. All reads and writes under `agent_coordination/...` anchor at `<workspace_root>` unconditionally, regardless of any worktrees created below. Worktrees only redirect writes to `projects/<name>/...` paths and `git -C` commands for the corresponding sub-repo.

1. **Compute `<story-slug>`**. Strip the `.md` extension from the selected step's spec file. Example: `story-03-bootstrap-and-docs-rewrite.md` → `story-03-bootstrap-and-docs-rewrite`.

2. **Parse `## Scope` for target paths**. In the selected step file, extract the text between the line matching `^## Scope$` and the next line matching `^## ` (any heading), or EOF if no next heading. Inside that text, find every substring matching the regex `projects/[A-Za-z0-9_-]+/` and deduplicate to `<scope_prefixes>` — the set of `<name>` values found. If the step file has no `## Scope` section, `<scope_prefixes>` is empty.

3. **Resolve `<target_repos>`**. Initialize `<target_repos>` as an empty set. For each `<name>` in `<scope_prefixes>`:
   - If `<workspace_root>/projects/<name>/.git` exists (a directory OR a gitlink file — test with `test -e`, not `git rev-parse`), add absolute `<workspace_root>/projects/<name>` to `<target_repos>`.
   - Otherwise skip silently (stale reference to a repo no longer on disk).

   Additionally, run `git -C <workspace_root> rev-parse --is-inside-work-tree`. If it succeeds, add `<workspace_root>` to `<target_repos>`. This preserves the single-repo case (where `<cwd>` itself is the code repo) and the nested-monorepo case.

4. **No targets**. If `<target_repos>` is empty, set `<project_root_map>` = `{}` and skip to step 10. The story will only touch workspace-root paths like `<workspace_root>/agent_coordination/...`.

5. **Parse explicit `WORKTREE=` arguments** into `<explicit_worktree_map>`. Collect every `WORKTREE="<value>"` occurrence from `$ARGUMENTS`. For each value:
   - If it contains `=`, split on the FIRST `=` into `<basename>` and `<path>`. Normalize `<path>` to an absolute path and record as `<explicit_worktree_map>[<basename>]` = `<path>`.
   - Otherwise treat it as the legacy single form and record as `<legacy_worktree>` (normalized absolute path).

   Validation:
   - Mixing both forms (some `WORKTREE=` with `=`, some without) is an error: abort with "mix of `WORKTREE=\"path\"` and `WORKTREE=\"basename=path\"` forms is not allowed; use one or the other".
   - If `<legacy_worktree>` is set, it is only valid when exactly one `<target_repo>` was discovered. Apply it as `<explicit_worktree_map>[basename(<target_repo>)]` = `<legacy_worktree>`. Otherwise abort with "`WORKTREE=\"<path>\"` requires exactly one target repo; found N (basenames: ...). Pass `WORKTREE=\"<basename>=<path>\"` form to specify which repo".

6. **Per-repo dirty check and decision**. Initialize `<project_root_map>` = `{}` and `<pending_prompt>` = `[]`. For each `<target_repo>` in `<target_repos>`, iterating in sorted order by basename for determinism:
   - `<repo-basename>` = `basename <target_repo>`.
   - `<dirty>` = `git -C <target_repo> status --porcelain` output non-empty.
   - `<default-path>` = `$HOME/add-worktrees/<repo-basename>-<epic-name>-<story-slug>`.
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
   - Anything else (unparseable, partial, or mixed): re-prompt ONCE with a clearer hint restating the three acceptable reply forms. On a second malformed reply, abort with "couldn't parse reply after two attempts; re-run /epic-story-claim". No MASTER.md or story-file writes have happened yet — aborting is safe.

   After parsing, for each pending repo: either set `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree mode) and warn, or resolve `<wt-path>` and mark for creation.

8. **Create worktrees** for every repo marked for creation in step 6 or 7, iterating in sorted basename order for determinism:
   - `mkdir -p "$(dirname <wt-path>)"`
   - `git -C <target_repo> worktree add -b <epic-name>/<story-slug> <wt-path>`
   - If it fails because the branch `<epic-name>/<story-slug>` already exists in `<target_repo>`, abort with: "story branch `<epic-name>/<story-slug>` already exists in repo `<repo-basename>`; this looks like a resumable story — run `/epic-story-resume <epic-name> <story>` instead". List any worktrees already created earlier in this loop as "successfully created but NOT cleaned up: <list>" so the operator can decide whether to keep them. No MASTER.md or story-file writes have happened yet.
   - If it fails for any other reason, report the git error verbatim, list successful worktrees as "NOT cleaned up", and abort. **Do NOT auto-clean up successful worktrees** on partial failure — preserve operator choice.
   - On success: `<project_root_map>[<repo-basename>]` = `<wt-path>`.

9. **Conditional `<workspace_root>` sanity check**. Run this check ONLY if ALL of the following are true:
   - `<workspace_root>` is itself a git repo (step 3's `rev-parse --is-inside-work-tree` succeeded),
   - `<workspace_root>` is in `<target_repos>`,
   - `<project_root_map>[basename(<workspace_root>)]` is a worktree (not `<workspace_root>` itself).

   Then run `git -C <project_root_map>[basename(<workspace_root>)] ls-files --error-unmatch agent_coordination/epics/<epic-name>/MASTER.md`. If it fails, abort with: "agent_coordination/ appears to be ignored or uncommitted in `<workspace_root>`'s repo; commit the epic files first, then re-run /epic-story-claim".

   Additionally, if `<workspace_root>` is a git repo AND its step-6 porcelain output mentioned files under `agent_coordination/`, warn: "pending changes to `agent_coordination/` on `<workspace_root>` main will NOT be in any worktree — commit them on main and rerun, or proceed knowing they are stranded".

   Do NOT run this check against sub-repo worktrees; sub-repos do not contain `agent_coordination/` at all.

10. **Done**. `<project_root_map>` is set. All downstream resolution uses these rules:
    - `<epic>/MASTER.md`, step files, and anything under `agent_coordination/...` → read/write at `<workspace_root>/agent_coordination/...` unconditionally.
    - Code at `projects/<name>/foo/bar` → if `<project_root_map>` has `<name>`, route to `<project_root_map>[<name>]/foo/bar`; else route to `<workspace_root>/projects/<name>/foo/bar`.
    - Git commands targeting repo `<name>`: `git -C <project_root_map>[<name>] ...` (or `git -C <workspace_root>/projects/<name> ...` if `<name>` is not in the map).

## Claim protocol

Before deep implementation work:
1. Update the selected row in `MASTER.md` to `🔄 IN PROGRESS`
2. Add or refresh these sections in the step file:

```md
## Active Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: Claude fresh session
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

The `- Main-tree targets:` bullet lists every repo basename from `<project_root_map>` whose value is the repo's own main tree (i.e. NOT a worktree). This tells `/epic-story-review` that these repos were intentionally written to directly — their dirtiness at review time is the implementation itself. Omit this bullet when there are no main-tree target repos (all targets got worktrees, or no targets at all).

3. Do not silently switch to a different step once work has started.

## Execution rules

- Treat `MASTER.md` plus the claimed step file as the source of truth
- Read dependency step files for context; do not widen scope unless required to finish the claimed step correctly
- Inspect the relevant code and tests before the first change. Use the story's `## Verification`, `## Critical Files`, and `## Discovery Notes` to choose the smallest focused seam that covers the next behavior.
- Run a Debt Friction check before the first patch: ask whether implementation is being made harder by unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure. Only write a `Debt Friction` entry when there is a story-local causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.
- Default to red-first: make that focused seam fail, implement until it passes, then broaden verification.
- Do not jump straight to broad suites or code-first implementation if a smaller focused seam is available.
- Implement the claimed step end-to-end when feasible
- Prefer code changes over restating plans
- If you discover an epic-wide architectural contradiction, update `MASTER.md` minimally and note it in the step file
- If you discover non-material proof-path drift, update the story's `## Verification` matrix immediately and record why in `## Progress Log` before continuing
- If you discover material contract drift, pause feature work, record a replanning checkpoint in `## Progress Log`, update the story contract, and only then continue implementation
- If red-first is not feasible, record an explicit written exception in `## Progress Log` before proceeding. Name the reason, the alternative proof seam, and the verification path you will use instead.
- If Debt Friction exists, record it in `## Progress Log` using the `docs/epic-conventions.md` shape. Use `fix-now` only for enabling cleanup directly required to make this story correct, testable, reviewable, or safely maintainable; include `Scope Justification`. Use `split-story`, `defer-explicitly`, or `block` for debt that is non-enabling, too large, too non-local, or proof-blocking.
- If the claimed step is blocked by an unmet dependency or hard contradiction, stop broadening scope and mark it `⛔ BLOCKED`

## Progress tracking

Append concise timestamped bullets under `## Progress Log` after meaningful milestones:
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

Assume other fresh sessions may work on nearby steps. Avoid touching files outside the claimed step's primary write surfaces unless required. If you must cross that boundary, record it immediately in the progress log.

## Finish protocol

At the end of the session, update the step file:

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

Then update `MASTER.md` status using this lifecycle:
- `🔄 IN PROGRESS` — implementation still actively underway
- `🟣 IN REVIEW` — implementation done enough for review; the focused red seam is green or an explicit exception is recorded; run final verification, review the touched files, tighten rough edges
- `🔵 IN PR` (optional) — local review passed and changes are in a GitHub PR awaiting remote review and merge. **Do not set this status from `/epic-story-claim`**; use `/epic-story-pr` to record PR metadata.
- `✅ DONE` — implementation and review complete; if a PR stage was used, the PR is merged
- `⛔ BLOCKED` — an external blocker prevents completion or review

**Default rule:**
1. Claim as `🔄 IN PROGRESS`
2. Once the chosen focused seam is green and implementation is complete, move to `🟣 IN REVIEW`
3. Then either:
   - move straight to `✅ DONE` if no GitHub PR stage is needed, or
   - use `/epic-story-pr` to transition to `🔵 IN PR` and move to `✅ DONE` only after the PR is merged
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
