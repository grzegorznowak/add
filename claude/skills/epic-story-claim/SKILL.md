---
name: epic-story-claim
description: Claim one ready story from an epic and execute it end-to-end, leaving a clean handoff. Use when starting a fresh session on a new story from an epic's MASTER.md tracker.
disable-model-invocation: true
argument-hint: "<epic-name> [story-number-or-spec-file] [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Edit Write Grep Glob Bash
---

# Epic Story Claim

Pick exactly one ready, unclaimed story from an epic, claim it, execute it, and leave a clean handoff for the next session.

Argument: `$ARGUMENTS` — `<epic-name> [<story-number-or-spec-file>] [WORKTREE="<basename>=<path>"]...`. The epic name is the first bare positional token (e.g. `cure-core-review-pipeline`) and resolves to `agent_coordination/epics/<epic-name>`; if omitted and there is exactly one active epic under `agent_coordination/epics/`, default to that one. The optional story selector targets one ready unclaimed row by `Step` or `Spec`; when omitted, this command keeps its existing behavior and selects the first ready unclaimed story. `WORKTREE=` is an optional, repeatable opt-in that forces a worktree to be created (or reused) at a specific path for a specific target repo. Two forms are accepted: `WORKTREE="<basename>=<path>"` (multi form, repeatable, preferred) and legacy `WORKTREE="<path>"` (valid only when the story has exactly one target repo; the path is applied to that sole repo). Mixing the two forms in a single invocation is an error. When `WORKTREE=` is absent, the `## Worktree preflight` section creates a worktree for any discovered target repo whose `git status --porcelain` is non-empty; clean target repos are written to directly.

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
    - `<story>`: optional second bare positional token (story number or spec file)
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

## Shared Research Board Input

When launched by a converger, you may receive `Shared Research Board from parent orchestration session` before the slash command. This is the only allowed cross-session context beyond neutral operational notes. Use it as sourced orientation only. The converger owns keeping it relevant; you only decide whether the needed fact is present in the provided board. If present, verify it with direct reads/search against the cited anchors before it affects implementation, proof updates, or coordination write-back instead of rerunning expensive research. If a provided entry does not verify, report a board-refresh signal with exact anchors; do not decide how to curate the board. If absent, follow this skill's normal research rules. Ignore any board item that lacks an exact source anchor such as `path:line`, symbol, command/output excerpt, or tool/query/path.

## Step selection

If `<story>` was provided:
- use `<epic>/MASTER.md` as the only lookup table
- first try to match exactly one row whose `Step` value equals the selector
- if no row matches by `Step`, try to match exactly one row whose `Spec` value equals the selector
- if neither lookup finds a row, stop and report the unresolved selector plus the available `Step` and `Spec` values from `MASTER.md`
- if the `Step` lookup and `Spec` lookup both match but point to different rows, stop and report the ambiguity
- select that matched row only; never fall back to a different ready row

If `<story>` was not provided, preserve the original behavior: from `<epic>/MASTER.md`, select the first step that is all of:
- **unclaimed**: status is `⬜ TODO`, `⚪ TODO`, or otherwise clearly unclaimed
- **plan-approved**: `Plan` is `🟢 PLAN APPROVED`, or the tracker has no `Plan` column and the newest effective `## Plan Review Log` verdict is `approve` with no later unresolved `request_changes`, `not_reviewable`, or `blocked`
- **ready**: every dependency listed in `Depends` is `✅ DONE`
- **concrete**: the referenced step file exists

After a row is selected by either path, verify it is all of:
- **unclaimed**: status is `⬜ TODO`, `⚪ TODO`, or otherwise clearly unclaimed
- **plan-approved**: `Plan` is `🟢 PLAN APPROVED`, or the tracker has no `Plan` column and the newest effective `## Plan Review Log` verdict is `approve` with no later unresolved `request_changes`, `not_reviewable`, or `blocked`
- **ready**: every dependency listed in `Depends` is `✅ DONE`
- **concrete**: the referenced step file exists

If no such step exists, or the targeted row is not claimable:
- do not guess or switch rows
- stop after a concise report listing: no-ready-step reason, plan lane if present, blocked steps, and the next step that must complete first. If the plan is not approved, the next action is `/epic-story-plan-converge <epic> <story>` or `/epic-story-plan-review <epic> <story>` depending on whether edits are still needed.

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
- Claimed by: $RUNTIME_NAME fresh session
- Model: $MODEL (the exact model name used for this claim)
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
- Inspect the relevant code and tests before the first change. Use the story's `## Actors`, normative `## Scenarios / Behavior Examples` linked with exactly one `Covers: A<n>`, `## Verification`, `## Critical Files`, and `## Discovery Notes` to choose the smallest focused seam that covers the next behavior. Treat `Orientation only` scenarios as context only; they must not create implementation or proof obligations unless the same behavior is also present in `## Acceptance`.
- Before choosing the first red seam, build a compact acceptance proof map from the story: list every `A<n>` id and, for any acceptance item that names variants, modes, branches, fallback paths, error cases, or examples, list each named case separately. If `## Scenarios / Behavior Examples` contains `S<n> Covers: A<n>`, include the linked scenario case under that acceptance id. Use this proof map to decide tests and implementation order; do not treat one variant, linked scenario, or orientation-only example as covering siblings unless the story explicitly excludes them.
- Run a Debt Friction check before the first patch: ask whether implementation is being made harder by unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure. Only write a `Debt Friction` entry when there is a story-local causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.
- Default to red-first: make that focused seam fail, implement until it passes, then broaden verification.
- Do not jump straight to broad suites or code-first implementation if a smaller focused seam is available.
- Implement the claimed step end-to-end when feasible
- Prefer code changes over restating plans
- If you discover an epic-wide architectural contradiction, update `MASTER.md` minimally and note it in the step file
- If you discover non-material evidence drift where the contract is still correct but the actual proof command/name changed, update only the concrete evidence row in `## Verification` and record why in `## Progress Log` before continuing.
- If implementation reveals variant-level proof needs, acceptance gaps, branch coverage gaps, input-boundary shape risk, or material contract drift not captured in the story, stop implementation work. Record a concise blocker in `## Progress Log`, set or ask to set the `Plan` lane to `🟠 PLAN CHANGES REQUESTED` when available, and route the story to `/epic-feedback` or `/epic-story-plan-converge`. Do not perform replanning inside `/epic-story-claim`.
- If red-first is not feasible, record an explicit written exception in `## Progress Log` before proceeding. Name the reason, the alternative proof seam, and the verification path you will use instead.
- If Debt Friction exists, record it in `## Progress Log` using the `docs/epic-conventions.md` shape. Use `fix-now` only for enabling cleanup directly required to make this story correct, testable, reviewable, or safely maintainable; include `Scope Justification`. Use `split-story`, `defer-explicitly`, or `block` for debt that is non-enabling, too large, too non-local, or proof-blocking.
- If the claimed step is blocked by an unmet dependency or hard contradiction, stop broadening scope and mark it `⛔ BLOCKED`

## Progress tracking

Append concise timestamped bullets under `## Progress Log` after meaningful milestones:
- focused red seam chosen
- focused seam turned green
- acceptance proof map checked or updated when named variants/failure modes exist
- design change locked
- files patched
- tests added/updated
- proof evidence row updated to match implementation reality without changing contract meaning
- planning-lane blocker recorded after material contract drift
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
- Acceptance proof coverage: <all acceptance ids and named variants covered | gaps/exclusions listed>
- Remaining work: <short bullets>
- Unresolved Debt Friction: <split-story / defer-explicitly / block / unfinished fix-now entries, or none>
- Blockers / risks: <short bullets>
- Exact next step: <one concrete recommendation>
```

Before transitioning to `✅ DONE`, offer to check in worktree changes. For each worktree in `## Active Claim` -> `- Worktrees:`, run `git -C <path> status --porcelain`. If dirty, propose `git -C <path> add -A && git -C <path> commit -m "<epic-name>/<story-slug>: <worksummary>"` and execute on operator confirmation. If all worktrees are clean, skip.

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
- `## Research Events` with reused board entries, board-refresh signals, and newly sourced research; for reused entries, name the board entry plus the direct-read/search anchors used to verify it; for board-refresh signals, name the board entry or absent needed fact plus anchors proving the miss or replacement fact; for new research, include exact anchors; use `- None.` when no research was used or produced
- the exact next action for the next fresh session
