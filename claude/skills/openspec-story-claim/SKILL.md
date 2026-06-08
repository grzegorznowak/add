---
name: openspec-story-claim
description: Claim one ready, unclaimed story from an OpenSpec initiative and execute it end-to-end, leaving a clean handoff. Use when starting a fresh session on a new story in an OpenSpec change workspace.
disable-model-invocation: true
argument-hint: "<initiative-slug> [story-slug] [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Edit Write Grep Glob Bash
---

# OpenSpec Story Claim

Pick exactly one ready, unclaimed story from an OpenSpec initiative, claim it, execute it, and leave a clean handoff for the next session.

Argument: `$ARGUMENTS` — `<initiative_slug> [<story_slug>] [WORKTREE="<basename>=<path>"]...`. The initiative slug is the first bare positional token (e.g. `cure-core-review-pipeline`) and resolves to `openspec/initiatives/<slug>/initiative.md`; if omitted and there is exactly one active initiative under `openspec/initiatives/`, default to that one. The optional story slug targets one ready unclaimed change workspace; when omitted, this command selects the first ready unclaimed story. `WORKTREE=` is an optional, repeatable opt-in that forces a worktree to be created (or reused) at a specific path for a specific target repo. Two forms are accepted: `WORKTREE="<basename>=<path>"` (multi form, repeatable, preferred) and legacy `WORKTREE="<path>"` (valid only when the story has exactly one target repo; the path is applied to that sole repo). Mixing the two forms in a single invocation is an error. When `WORKTREE=` is absent, the `## Worktree preflight` section creates a worktree for any discovered target repo whose `git status --porcelain` is non-empty; clean target repos are written to directly.

Do **not** try to rediscover or redefine the initiative from scratch. Do **not** claim more than one story in a single session.

## Workflow
1. Read the initiative `initiative.md`
2. Scan change workspaces and pick one ready story
3. Claim it
4. Inspect sources and choose the smallest focused red seam
5. Work only that story plus required dependencies
6. Move it to `🟣 IN REVIEW` after implementation is complete
7. Leave the change workspace in a state the next fresh session can continue

## Resolution

1. Parse `$ARGUMENTS` into:
    - `<initiative_slug>`: the first bare positional token (falls back to the single active initiative under `openspec/initiatives/` if omitted)
    - `<story_slug>`: optional second bare positional token (story slug / change workspace name)
    - The raw list of `WORKTREE="<value>"` occurrences (parsed in `## Worktree preflight` step 5 into `<explicit_worktree_map>` and/or `<legacy_worktree>`)
2. Set `<workspace_root>` = `<cwd>` and resolve `<initiative_dir>` = `<workspace_root>/openspec/initiatives/<initiative_slug>`. `<workspace_root>` is never re-anchored; coordination files always live here.
3. If `<initiative_dir>` does not exist, stop and report the exact missing path.
4. Read first (from `<workspace_root>`):
   - the main repo `AGENTS.md` for the repo you will touch
   - `<initiative_dir>/initiative.md`

## Source-of-truth hierarchy

1. `<initiative_dir>/initiative.md`
2. the claimed `story.md`
3. dependency change workspace `story.md` files listed in `## Expected Prerequisites`
4. repo code and tests

## Story selection

If `<story_slug>` was provided:
- use `openspec/changes/` as the scan root
- look for a directory `openspec/changes/<story_slug>/` containing `story.md`
- if found, read `story.md` to extract the `Status:` header
- if not found, check `openspec/changes/archive/<story_slug>/`; if found there, stop and report that the story is archived
- if not found in either location, stop and report the unresolved slug plus list available change workspace names under `openspec/changes/`

If `<story_slug>` was not provided, preserve the original discovery behavior: scan all directories under `openspec/changes/` for `story.md` files. For each, read the `Status:` header. Select the first story that is all of:
- **unclaimed**: `Status:` is `⬜ TODO` or `⚪ TODO` or the header is absent
- **plan-approved**: `Plan:` is `🟢 PLAN APPROVED`
- **ready**: every prerequisite listed in `story.md → ## Expected Prerequisites` is satisfied (the referenced change workspace's `story.md` has `Status: ✅ DONE`)
- **concrete**: the change workspace exists and contains `story.md`

After a story is selected by either path, verify it is all of:
- **unclaimed**: `Status:` is `⬜ TODO`, `⚪ TODO`, or absent
- **plan-approved**: `Plan:` is `🟢 PLAN APPROVED`
- **ready**: every prerequisite listed in `## Expected Prerequisites` has `Status: ✅ DONE` in the referenced change workspace
- **concrete**: the change workspace directory exists and contains `story.md`
- **not blocked**: `blocked.md` does not exist in the change workspace

If no such story exists, or the targeted story is not claimable:
- do not guess or switch stories
- stop after a concise report listing: no-ready-story reason, plan lane if present, blocked stories, and the next story that must complete first. If the plan is not approved, the next action is `/openspec-story-plan-converge <initiative_slug> <story_slug>` or `/openspec-story-plan-review <initiative_slug> <story_slug>` depending on whether edits are still needed.

### Prerequisite Resolution

To check whether an expected prerequisite is satisfied:

1. Parse `story.md → ## Expected Prerequisites` for references to other change workspaces. Expected format: a list where each bullet names a dependency story slug.
2. For each dependency slug, resolve `<workspace_root>/openspec/changes/<slug>/story.md`.
3. Read the `Status:` header. The dependency is satisfied when `Status: ✅ DONE`.
4. If any dependency is not `✅ DONE`, the story is not ready to claim.

If `## Expected Prerequisites` is absent or empty, the story has no dependencies and the readiness check for dependencies passes automatically.

## Worktree preflight

After picking a story but before writing any claim, figure out which repos the story will write to, whether any of them are dirty, and for each dirty target build a linked git worktree on the story-specific branch. Clean target repos are written to directly; implementation work on dirty repos happens in a clean branch isolated from whatever else was in the main tree.

**Invariant**: `<workspace_root>` = `<cwd>`, always. All reads and writes under `openspec/...` anchor at `<workspace_root>` unconditionally, regardless of any worktrees created below. Worktrees only redirect writes to `projects/<name>/...` paths and `git -C` commands for the corresponding sub-repo.

1. **Set `<story_slug>` as the canonical change workspace name**. This is the directory name under `openspec/changes/`.

2. **Parse `## Scope` for target paths**. In the selected `story.md`, extract the text between the line matching `^## Scope$` and the next line matching `^## ` (any heading), or EOF if no next heading. Inside that text, find every substring matching the regex `projects/[A-Za-z0-9_-]+/` and deduplicate to `<scope_prefixes>` — the set of `<name>` values found. If the story file has no `## Scope` section, `<scope_prefixes>` is empty.

3. **Resolve `<target_repos>`**. Initialize `<target_repos>` as an empty set. For each `<name>` in `<scope_prefixes>`:
   - If `<workspace_root>/projects/<name>/.git` exists (a directory OR a gitlink file — test with `test -e`, not `git rev-parse`), add absolute `<workspace_root>/projects/<name>` to `<target_repos>`.
   - Otherwise skip silently (stale reference to a repo no longer on disk).

   Additionally, run `git -C <workspace_root> rev-parse --is-inside-work-tree`. If it succeeds, add `<workspace_root>` to `<target_repos>`. This preserves the single-repo case (where `<cwd>` itself is the code repo) and the nested-monorepo case.

4. **No targets**. If `<target_repos>` is empty, set `<project_root_map>` = `{}` and skip to step 10. The story will only touch workspace-root paths like `<workspace_root>/openspec/...`.

5. **Parse explicit `WORKTREE=` arguments** into `<explicit_worktree_map>`. Collect every `WORKTREE="<value>"` occurrence from `$ARGUMENTS`. For each value:
   - If it contains `=`, split on the FIRST `=` into `<basename>` and `<path>`. Normalize `<path>` to an absolute path and record as `<explicit_worktree_map>[<basename>]` = `<path>`.
   - Otherwise treat it as the legacy single form and record as `<legacy_worktree>` (normalized absolute path).

   Validation:
   - Mixing both forms (some `WORKTREE=` with `=`, some without) is an error: abort with "mix of `WORKTREE=\"path\"` and `WORKTREE=\"basename=path\"` forms is not allowed; use one or the other".
   - If `<legacy_worktree>` is set, it is only valid when exactly one `<target_repo>` was discovered. Apply it as `<explicit_worktree_map>[basename(<target_repo>)]` = `<legacy_worktree>`. Otherwise abort with "`WORKTREE=\"<path>\"` requires exactly one target repo; found N (basenames: ...). Pass `WORKTREE=\"<basename>=<path>\"` form to specify which repo".

6. **Per-repo dirty check and decision**. Initialize `<project_root_map>` = `{}` and `<pending_prompt>` = `[]`. For each `<target_repo>` in `<target_repos>`, iterating in sorted order by basename for determinism:
   - `<repo-basename>` = `basename <target_repo>`.
   - `<dirty>` = `git -C <target_repo> status --porcelain` output non-empty.
   - `<default-path>` = `$HOME/add-worktrees/<repo-basename>-<initiative_slug>-<story_slug>`.
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
   - Anything else (unparseable, partial, or mixed): re-prompt ONCE with a clearer hint restating the three acceptable reply forms. On a second malformed reply, abort with "couldn't parse reply after two attempts; re-run /openspec-story-claim". No story.md or progress.md writes have happened yet — aborting is safe.

   After parsing, for each pending repo: either set `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree mode) and warn, or resolve `<wt-path>` and mark for creation.

8. **Create worktrees** for every repo marked for creation in step 6 or 7, iterating in sorted basename order for determinism:
   - `mkdir -p "$(dirname <wt-path>)"`
   - `git -C <target_repo> worktree add -b <initiative_slug>/<story_slug> <wt-path>`
   - If it fails because the branch `<initiative_slug>/<story_slug>` already exists in `<target_repo>`, abort with: "story branch `<initiative_slug>/<story_slug>` already exists in repo `<repo-basename>`; this looks like a resumable story — run `/openspec-story-resume <initiative_slug> <story_slug>` instead". List any worktrees already created earlier in this loop as "successfully created but NOT cleaned up: <list>" so the operator can decide whether to keep them. No story.md or progress.md writes have happened yet.
   - If it fails for any other reason, report the git error verbatim, list successful worktrees as "NOT cleaned up", and abort. **Do NOT auto-clean up successful worktrees** on partial failure — preserve operator choice.
   - On success: `<project_root_map>[<repo-basename>]` = `<wt-path>`.

9. **Conditional `<workspace_root>` sanity check**. Run this check ONLY if ALL of the following are true:
   - `<workspace_root>` is itself a git repo (step 3's `rev-parse --is-inside-work-tree` succeeded),
   - `<workspace_root>` is in `<target_repos>`,
   - `<project_root_map>[basename(<workspace_root>)]` is a worktree (not `<workspace_root>` itself).

   Then run `git -C <project_root_map>[basename(<workspace_root>)] ls-files --error-unmatch openspec/initiatives/<initiative_slug>/initiative.md`. If it fails, abort with: "openspec/ appears to be ignored or uncommitted in `<workspace_root>`'s repo; commit the initiative files first, then re-run /openspec-story-claim".

   Additionally, if `<workspace_root>` is a git repo AND its step-6 porcelain output mentioned files under `openspec/`, warn: "pending changes to `openspec/` on `<workspace_root>` main will NOT be in any worktree — commit them on main and rerun, or proceed knowing they are stranded".

   Do NOT run this check against sub-repo worktrees; sub-repos do not contain `openspec/` at all.

10. **Done**. `<project_root_map>` is set. All downstream resolution uses these rules:
    - `<initiative_dir>/initiative.md`, story files, and anything under `openspec/...` → read/write at `<workspace_root>/openspec/...` unconditionally.
    - Code at `projects/<name>/foo/bar` → if `<project_root_map>` has `<name>`, route to `<project_root_map>[<name>]/foo/bar`; else route to `<workspace_root>/projects/<name>/foo/bar`.
    - Git commands targeting repo `<name>`: `git -C <project_root_map>[<name>] ...` (or `git -C <workspace_root>/projects/<name> ...` if `<name>` is not in the map).

## Claim protocol

Before deep implementation work:
1. Update the `Status:` header in `story.md` from `⬜ TODO` (or `⚪ TODO`, or absent) to `🔄 IN PROGRESS`
2. Create or update `progress.md` with these sections:

```md
## Current Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: pi fresh session
- Model: $MODEL (the exact model name used for this claim)
- Scope: <one sentence>
- Worktrees:
  - <repo-basename>: <absolute-worktree-path>
  - <repo-basename>: <absolute-worktree-path>
- Main-tree targets: <repo-basename>, <repo-basename>
- Primary write surfaces: <paths>

## Progress Timeline
- <UTC ISO timestamp> Claimed story and started implementation.
```

The `- Worktrees:` parent bullet is present if and only if at least one entry in `<project_root_map>` resolves to a real worktree (i.e. `<project_root_map>[<basename>]` != `<workspace_root>/projects/<basename>` and != `<workspace_root>`). List only those repos whose value is an actual worktree; repos resolved to main tree are NOT listed (their absence implies main-tree mode). If `<project_root_map>` has no worktree entries (all targets clean, or no targets, or operator answered `no` for every dirty repo), omit the `- Worktrees:` bullet entirely — do not write it with no children.

The `- Main-tree targets:` bullet lists every repo basename from `<project_root_map>` whose value is the repo's own main tree (i.e. NOT a worktree). This tells `/openspec-story-review` that these repos were intentionally written to directly — their dirtiness at review time is the implementation itself. Omit this bullet when there are no main-tree target repos (all targets got worktrees, or no targets at all).

3. Do not silently switch to a different story once work has started.

## Execution rules

- Treat `initiative.md` plus the claimed `story.md` as the source of truth
- Read dependency story files for context; do not widen scope unless required to finish the claimed story correctly

### Implementation proof preflight

Before the first patch:

1. Read the story's change workspace artifacts for full context:
   - `story.md` — for verification, acceptance criteria, scenarios, actors, and proof contract
   - `tasks.md` — for the task checklist tracking implementation progress
   - `proposal.md` — for original rationale and scope boundaries
   - `design.md` — for technical design decisions and architecture context
2. Inspect relevant code/tests and the story proof sections: `## Actors`, normative `## Scenarios / Behavior Examples` linked with exactly one `Covers: A<n>`, `## Verification`, especially `### Test Architecture Plan`, `## Critical Files`, and `## Discovery Notes`.
3. Build an acceptance proof map: every `A<n>` id, every named variant/mode/branch/fallback/error/example, and every normative `S<n> Covers: A<n>` case. Orientation-only scenarios are context only and must not create implementation or proof obligations unless the same behavior is also in `## Acceptance`.
4. Build a TAP map: each `TAP-*` row's acceptance slice, layer/scope, owning suite/file, boundary, assertions/observability, fixture/data strategy, CI lane/command, fallback plan, and split/merge rationale. Use it to choose the smallest credible red seam while preserving planned test organization.
5. Build an activated-risk map from story + source inspection. Note material lenses such as async/event-loop behavior, concurrency, process/resource lifecycle, platform/OS APIs, filesystem/network/subprocess I/O, permissions/security, persistence, retries/timeouts, generated artifacts, prompt/template fail-open behavior, external services, and naming-sensitive invariants; record `none material` when appropriate.
6. Run a Debt Friction check: record it only when there is a story-local causal link from current story action to concrete evidence, delivery impact, and explicit decision.
7. If source inspection proves the TAP or contract materially wrong, follow the row's fallback plan only when it stays within scope; otherwise record the blocker and route to `/openspec-story-plan-converge` or `/openspec-feedback`. Do not silently replan inside claim.

- Default to red-first: make that focused seam fail, implement until it passes, then broaden verification.
- Do not jump straight to broad suites or code-first implementation if a smaller focused seam is available.
- Implement the claimed story end-to-end when feasible
- Prefer code changes over restating plans
- If you discover an initiative-wide architectural contradiction, update `initiative.md` minimally and note it in `progress.md → ## Progress Timeline`
- If you discover non-material evidence drift where the contract is still correct but the actual proof command/name changed, update only the concrete evidence row in `## Verification` and record why in `## Progress Timeline` before continuing.
- If implementation reveals variant-level proof needs, acceptance gaps, branch coverage gaps, input-boundary shape risk, activated risk lenses, or material contract drift not captured in the story, stop implementation work. Record a concise blocker in `## Progress Timeline`, set or ask to set the `Plan:` header to `🟠 PLAN CHANGES REQUESTED` when available, and route the story to `/openspec-feedback` or `/openspec-story-plan-converge`. Do not perform replanning inside `/openspec-story-claim`.
- If red-first is not feasible, record an explicit written exception in `## Progress Timeline` before proceeding. Name the reason, the alternative proof seam, and the verification path you will use instead.
- If Debt Friction exists, record it in `## Progress Timeline` using the `docs/epic-conventions.md` shape. Use `fix-now` only for enabling cleanup directly required to make this story correct, testable, reviewable, or safely maintainable; include `Scope Justification`. Use `split-story`, `defer-explicitly`, or `block` for debt that is non-enabling, too large, too non-local, or proof-blocking.
- Before moving to `🟣 IN REVIEW`, run a reviewer-mindset self-check over every activated risk lens: compare risky choices with existing repo idioms; check async paths for blocking sync calls; check external/OS/API operations for sibling failure modes such as not-found, permission denied, timeout/cancellation, already-complete, unsupported, and partial failure; verify tests assert observable behavior rather than private choreography unless the mechanic is contractual; verify sensitive names/comments do not overstate identity, ownership, lifecycle, or safety invariants; and confirm every review finding or discovered risk has disposition, fix proof, and regression/side-effect verification.
- If the claimed story is blocked by an unmet dependency or hard contradiction, stop broadening scope and mark it `⛔ BLOCKED`

## Progress tracking

Append concise timestamped bullets under `## Progress Timeline` in `progress.md` after meaningful milestones:
- focused red seam chosen
- focused seam turned green
- acceptance proof map checked or updated when named variants/failure modes exist
- activated-risk map checked or updated when implementation reveals new risk lenses
- design change locked
- files patched
- tests added/updated
- proof evidence row updated to match implementation reality without changing contract meaning
- planning-lane blocker recorded after material contract drift
- red-first exception recorded with alternative proof seam
- Debt Friction recorded with decision and guardrail
- blocker discovered
- initiative-wide finding recorded in `initiative.md`
- task in `tasks.md` checked off as completed

Do not wait until the very end to record progress.

## Task checklist

As tasks from `tasks.md` are completed, mark them as checked:

```markdown
- [x] Task 1: Description  ← mark completed tasks
- [ ] Task 2: Description
- [x] Task 3: Description  ← mark completed tasks
```

Only check off tasks that are demonstrably complete per the implementation proof. If `tasks.md` does not exist, create a minimal one from `story.md → ## Acceptance Criteria` items after confirming with the operator.

## Parallelism guard

Assume other fresh sessions may work on nearby stories. Avoid touching files outside the claimed story's primary write surfaces unless required. If you must cross that boundary, record it immediately in the progress timeline.

## Finish protocol

At the end of the session, update `progress.md → ## Session Handoff`:

```md
## Session Handoff
- Status: done | blocked | in progress | in review
- What changed: <short bullets>
- Files touched: <paths>
- Red-first path: <focused seam + red/green outcome, or explicit exception + alternative proof path>
- Tests run: <commands/results or not run>
- Acceptance proof coverage: <all acceptance ids and named variants covered | gaps/exclusions listed>
- Risk-lens self-check: <activated lenses checked, exclusions, or none material>
- Finding closure: <review/feedback findings fixed with proof and regression check, or none>
- Remaining work: <short bullets>
- Unresolved Debt Friction: <split-story / defer-explicitly / block / unfinished fix-now entries, or none>
- Blockers / risks: <short bullets>
- Exact next step: <one concrete recommendation>
```

### Status Transitions

The `Status:` field in `story.md` is the authoritative implementation status. There is no `MASTER.md` in this flow. Update `story.md → Status:` using this lifecycle:
- `🔄 IN PROGRESS` — implementation still actively underway
- `🟣 IN REVIEW` — implementation done enough for review; the focused red seam is green or an explicit exception is recorded; run final verification, review the touched files, tighten rough edges
- `🔵 IN PR` (optional) — local review passed and changes are in a GitHub PR awaiting remote review and merge. **Do not set this status from `/openspec-story-claim`**; use `/openspec-story-pr` to record PR metadata.
- `✅ DONE` — implementation and review complete; if a PR stage was used, the PR is merged
- `⛔ BLOCKED` — an external blocker prevents completion or review

**Default rule:**
1. Claim as `🔄 IN PROGRESS`
2. Once the chosen focused seam is green and implementation is complete, move to `🟣 IN REVIEW`
3. Then either:
   - move straight to `✅ DONE` if no GitHub PR stage is needed, or
   - use `/openspec-story-pr` to transition to `🔵 IN PR` and move to `✅ DONE` only after the PR is merged
4. If the session ends before review is complete, leave at `🟣 IN REVIEW`
5. If the session ends before implementation is complete, leave at `🔄 IN PROGRESS`

### Blocked detection

In addition to normal status transitions, check for blocker signals:

1. If `blocked.md` exists in the change workspace (`openspec/changes/<story_slug>/blocked.md`), read it and halt with the blocker message.
2. If an external blocker is encountered during implementation, create `blocked.md` with the blocker details.
3. Transition `story.md → Status:` to `⛔ BLOCKED`.

### Commit check

Before transitioning to `🟣 IN REVIEW` or `✅ DONE`, offer to check in worktree changes. For each worktree in `progress.md → ## Current Claim → - Worktrees:`, run `git -C <path> status --porcelain`. If dirty, propose `git -C <path> add -A && git -C <path> commit -m "<initiative_slug>/<story_slug>: <worksummary>"` and execute on operator confirmation. If all worktrees are clean, skip.

### Default Legend

There is no `MASTER.md` legend to update. The canonical status definitions are maintained in this skill's status transition table. If additional status conventions need to be documented, note them in `progress.md` directly.

## Final response

State:
- which story you claimed
- its final status
- files changed
- whether the initiative or story was updated
- `## Research Events` with reused board entries, board-refresh signals, and newly sourced research; for reused entries, name the board entry plus the direct-read/search anchors used to verify it; for board-refresh signals, name the board entry or absent needed fact plus anchors proving the miss or replacement fact; for new research, include exact anchors; use `- None.` when no research was used or produced
- the exact next action for the next fresh session

## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

After story selection, use the canonical `<story_slug>` in every notebook page name.

### Research before first change
Spawn a read-only child for the next acceptance/TAP slice you are about to implement, not for broad architecture:
`spawn({prompt: "For openspec/<initiative_slug>/<story_slug>, research the next implementation slice: <A<n>> / <TAP-*>. Checklist: Critical Files resolve; reusable owner/callsites; existing test layout, fixtures, and CI lane; expected behavior-facing RED assertion or observable signal; fallback if the planned seam is wrong. Write findings to notebook page 'research-openspec-<initiative_slug>-<story_slug>' with path:line anchors. Return summary.", thinking: "high"})`.
Retrieve: `notebook_read({name: "research-openspec-<initiative_slug>-<story_slug>"})`. The parent chooses the red seam, performs TDD, edits files, and records proof.

### Debt Friction check
`spawn({prompt: "Debt Friction check for openspec/<initiative_slug>/<story_slug>. Inspect for duplicated behavior, unclear ownership, weak tests, missing seams, hidden coupling. Only report with causal link: story action → evidence → delivery impact. Write findings to notebook page 'debt-openspec-<initiative_slug>-<story_slug>'.", thinking: "medium"})`.

### Proof tracking → notebook
Persist acceptance proof state: `notebook_write({name: "proof-openspec-<initiative_slug>-<story_slug>", content: "- A<n>: <status> — <evidence>"})`. Update as each acceptance item is proven. Next session retrieves: `notebook_read({name: "proof-openspec-<initiative_slug>-<story_slug>"})`.

### Research Board from converger → notebook
Retrieve: `notebook_read({name: "research-openspec-<initiative_slug>-<story_slug>"})`. Verify each entry with direct reads against cited anchors before acting. If an entry doesn't verify, refine the notebook page with correction + new anchors.
