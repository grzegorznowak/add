---
name: openspec-story-claim
description: Claim one ready, unclaimed story from an OpenSpec initiative and execute it end-to-end, leaving a clean handoff. Use when starting a fresh session on a new story in an OpenSpec change workspace.
disable-model-invocation: true
argument-hint: "<initiative-slug> [story-slug] [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Edit Write Grep Glob Bash
---

# OpenSpec Story Claim

Pick exactly one ready, unclaimed story from an OpenSpec initiative, claim it, execute it, and leave a clean handoff for the next session.

Argument: `$ARGUMENTS` — `<initiative_slug> [<story_slug>] [WORKTREE="<basename>=<path>"]...`. Initiative and story slugs must match the canonical regex `^[a-z0-9]+(?:-[a-z0-9]+)*$`; reject non-canonical positional slugs before path resolution. The initiative slug is the first bare positional token (e.g. `cure-core-review-pipeline`) and resolves to `openspec/initiatives/<slug>/initiative.md`; if omitted and there is exactly one active initiative under `openspec/initiatives/`, default to that one. The optional story slug targets one ready unclaimed change workspace; when omitted, this command selects the first ready unclaimed story. `WORKTREE=` is an optional, repeatable opt-in that forces a worktree to be created (or reused) at a specific path for a specific target repo. Two forms are accepted: `WORKTREE="<basename>=<path>"` (multi form, repeatable, preferred) and legacy `WORKTREE="<path>"` (valid only when the story has exactly one target repo; the path is applied to that sole repo). Mixing the two forms in a single invocation is an error. When `WORKTREE=` is absent, the `## Worktree preflight` section creates a worktree for any discovered target repo whose `git status --porcelain` is non-empty; clean target repos are written to directly.

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

1. Parse `$ARGUMENTS`, then validate each supplied or auto-selected initiative/story slug against `^[a-z0-9]+(?:-[a-z0-9]+)*$` before interpolating it into a path; reject malformed values. Record `<explicit_pair>` as true only when the operator supplied both positional slugs in this invocation; an auto-defaulted initiative or auto-selected story does not make an explicit pair.
    - `<initiative_slug>`: the first bare positional token (falls back to the single active initiative under `openspec/initiatives/` if omitted)
    - `<story_slug>`: optional second bare positional token (story slug / change workspace name)
    - The raw list of `WORKTREE="<value>"` occurrences (parsed in `## Worktree preflight` step 5 into `<explicit_worktree_map>` and/or `<legacy_worktree>`)
2. Set `<workspace_root>` = `<cwd>` and `<openspec_root>` = `<workspace_root>`. `<openspec_root>` is a transient active coordination root; never persist an `OpenSpec root:` field.
   - When `<story_slug>` is known, first inspect all explicit `WORKTREE=` values in either accepted form. A root candidate qualifies only when it is a git checkout containing both `openspec/initiatives/<initiative_slug>/initiative.md` and `openspec/changes/<story_slug>/story.md`. If exactly one explicit candidate qualifies, set `<openspec_root>` to it immediately; it is authoritative, and record its repo/worktree identity so the preflight reuses the selected checkout rather than creating over it. If multiple explicit candidates qualify, ask which checkout is active and halt; never guess.
   - Only when no explicit candidate qualifies, inspect registered root-repo worktrees other than `<workspace_root>` from `git -C <workspace_root> worktree list --porcelain` on branch `refs/heads/<initiative_slug>/<story_slug>`. If exactly one branch worktree qualifies, set `<openspec_root>` to it even when the launch checkout contains matching but possibly stale artifacts; that unique branch worktree outranks launch. Record its registered repo/worktree identity so `## Worktree preflight` reuses it instead of attempting a later duplicate `git worktree add`. If multiple branch worktrees qualify, ask which checkout is active and halt; never guess.
   - When `<story_slug>` is known and neither an explicit nor branch-worktree candidate qualifies, fall back to `<workspace_root>` and require both artifacts there. When `<story_slug>` is omitted, defer the full resolver, select the story only from `<workspace_root>`, then immediately run the full resolver and recompute every artifact path before lifecycle gates or writes. A root selected by this resolver is authoritative immediately and may change only if step 9 creates a new root worktree and verifies the artifact copy.
3. Recompute `<initiative_dir>` = `<openspec_root>/openspec/initiatives/<initiative_slug>`. If `<initiative_dir>` does not exist, stop and report the exact missing path.
4. Read first (from `<openspec_root>`):
   - the main repo `AGENTS.md` for the repo you will touch
   - `<initiative_dir>/initiative.md`

## Source-of-truth hierarchy

1. `<initiative_dir>/initiative.md`
2. the claimed `story.md`
3. dependency change workspace `story.md` files listed in `## Expected Prerequisites`
4. repo code and tests

## Notebook Input

When launched by a converger, you may receive a `Notebook references from parent orchestration session` block before the slash command. This is the only allowed cross-session context beyond neutral operational notes. Use referenced notebook selectors or compact fallback excerpts as sourced orientation only. The converger owns keeping notebook references relevant; you only decide whether the needed fact is reachable from a referenced selector or excerpt. If present, read only the relevant notebook page/entry on demand when available, then verify it with direct reads/search against the cited anchors before it affects implementation, proof updates, or coordination write-back instead of rerunning expensive research. If a referenced notebook entry or excerpt does not verify, mention the mismatch with exact anchors in the relevant final-response section; do not decide how to curate the notebook. If absent, follow this skill's normal research rules. Ignore any notebook item that lacks an exact source anchor such as `path:line`, symbol, command/output excerpt, or tool/query/path.

## Story selection

If `<story_slug>` was provided:
- use `openspec/changes/` as the scan root
- look for a directory `openspec/changes/<story_slug>/` containing `story.md`
- if found, check `blocked.md` first; only when absent read `story.md` to extract `Status:` and then `Plan:`
- if not found, check `openspec/changes/archive/<story_slug>/`; if found there, stop and report that the story is archived
- if not found in either location, stop and report the unresolved slug plus list available change workspace names under `openspec/changes/`; if the requested workspace is genuinely absent rather than relocated, route singularly to `/openspec-story-plan INITIATIVE=<initiative_slug>`

If `<story_slug>` was not provided, scan all directories under `openspec/changes/` for `story.md` files. Apply the initiative-binding resolver while enumerating: include only stories explicitly bound or uniquely candidate-associated with the resolved initiative; an auto-defaulted initiative cannot admit a zero-reference legacy story. For each eligible workspace, check `blocked.md` before reading lifecycle headers; record blocked workspaces as ineligible. Then read `Status:` before `Plan:` so IN REVIEW is never treated as a planning/claimability route. Select the first story that is all of:
- **unclaimed**: `Status:` is `⬜ TODO` or `⚪ TODO` or the header is absent
- **plan-approved**: `Plan:` is `🟢 PLAN APPROVED`
- **ready**: every prerequisite listed in `story.md → ## Expected Prerequisites` passes the complete `### Prerequisite Resolution` rule below; `Status: ✅ DONE` alone is insufficient
- **concrete**: the change workspace exists and contains `story.md`

After a story is selected by either path, rerun the transient OpenSpec-root resolver when selection filled an omitted story slug, recompute `<initiative_dir>`, `<change_dir>`, and all artifact paths from `<openspec_root>`, then validate the durable initiative binding before Plan or claimability checks:

- Inventory the top-level header region before the first `## ` heading for every unindented `Initiative` field or Initiative-like field line. Exactly one present header is valid only when the whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`. Duplicate headers, an empty value, whitespace-before-colon variants, non-canonical values, or any other malformed Initiative-like field are hard conflicts: stop before any claim/status/progress write and report every offending line. Never reinterpret malformed input as the legacy no-header case.
- When exactly one valid `Initiative:` header is present, require its value to equal `<initiative_slug>`; a mismatch is a hard conflict and reports both values.
- Only zero Initiative or Initiative-like header lines is a legacy story. For that case, scan active `<openspec_root>/openspec/initiatives/*/initiative.md` files for `## Story Candidates` references to this exact story slug. If exactly one initiative references it and that initiative is `<initiative_slug>`, accept that unique exact candidate association. If no initiative references it, accept only when `<explicit_pair>` is true; emit a compatibility warning and do not backfill the missing header. An auto-defaulted initiative or auto-selected story is not explicit enough for this zero-reference exception and requires exactly one candidate association with `<initiative_slug>`. Any reference by another initiative, including multiple references, is conflicting candidate evidence: halt and never guess.
- Auto-selection is initiative-aware: enumerate active change workspaces, apply the same binding resolver to each, and select only a workspace explicitly bound or uniquely candidate-associated with the resolved initiative. Exclude zero-reference legacy workspaces from auto-selection and never select a workspace bound or candidate-associated with another initiative.

Then apply these gates in order:

1. Check the selected change workspace for `blocked.md`. If it exists, stop first with the singular operator action to resolve the blocker and remove the file; do not offer wrapper/direct choices.
2. Read authoritative `Status:`. If it is `🔄 IN PROGRESS`, or `⛔ BLOCKED` with no `blocked.md` after the blocker was removed, stop with the singular `/openspec-story-resume <initiative_slug> <story_slug>` route. An already-valid story worktree does not make an active claim claimable again. If Status is `🟣 IN REVIEW`, do not blindly route back to review. Inspect bounded readiness evidence: implementation/proof incompleteness routes singularly to `/openspec-story-resume <initiative_slug> <story_slug>`; a missing anchor or incomplete/non-reviewable planning scaffold routes singularly to `/openspec-story-plan-resume <initiative_slug> <story_slug>` (or `/openspec-story-plan INITIATIVE=<initiative_slug>` when the workspace is absent); unresolved external evidence routes to one concrete operator action. Say that fresh review happens only after the named repair. Only when review has not yet run against the current evidence and all prerequisites are satisfied, stop with exactly one fresh, oblivious `/openspec-story-review <initiative_slug> <story_slug>` route. The implementation wrapper never launches review.
3. If `Status: ✅ DONE`, first require an unambiguous `Plan: 🟢 PLAN APPROVED`; otherwise stop with exactly `Operator action: investigate and reconcile the contradictory durable Status: ✅ DONE and Plan: <value> state before delivery or archive.` A bound story (exactly one valid `Initiative:` header) must have exactly one well-formed current receipt whose required fields occur exactly once and whose verdict is `Decision: APPROVE`, `Approval gate: PASS`, with a transition ending in `✅ DONE`. Do not recompute review identity here: it is story-scoped delivery evidence for PR, not lifecycle or prerequisite state. A duplicate, malformed, non-approving, or missing bound-story receipt routes only to a completely fresh `/openspec-story-review <initiative_slug> <story_slug>` substantive review, which owns normalization to one current receipt; do not attempt repair here. Only an unbound pre-v3 DONE story with zero Initiative headers and zero receipt sections qualifies for bounded legacy compatibility, with a warning and no backfill. A consistent DONE story is not claimable; route from its terminal/delivery evidence. Do not recommend planning, claim, or resume commands and do not invent a lifecycle owner.
4. Only then verify that the story is all of:
   - **unclaimed**: `Status:` is `⬜ TODO`, `⚪ TODO`, or absent
   - **plan-approved**: `Plan:` is `🟢 PLAN APPROVED`
   - **ready**: every prerequisite listed in `## Expected Prerequisites` passes the complete `### Prerequisite Resolution` rule below; `Status: ✅ DONE` alone is insufficient
   - **concrete**: the change workspace directory exists and contains `story.md`

If no such story exists, or the targeted story is not claimable:
- do not guess or switch stories
- preserve the blocked and IN REVIEW precedence above
- otherwise stop after a concise report listing: no-ready-story reason, plan lane if present, blocked stories, and the next story that must complete first
- if a non-DONE story has a valid but repairably incomplete/non-reviewable planning scaffold that `/openspec-story-plan-resume` can safely restore, including an unambiguously absent Plan/Status/log anchor, route singularly to `/openspec-story-plan-resume <initiative_slug> <story_slug>`; plan-converge rejects that entry shape
- if a non-DONE story's plan is complete and structurally reviewable with no unresolved finding, offer the planning Converge wrapper plus Non-looped plan-review; PLAN CHANGES REQUESTED with unresolved findings may use the wrapper plus Non-looped plan-resume only when the complete scaffold is one plan-converge can actually orchestrate
- keep prerequisite, missing-workspace, and malformed/ambiguous or unresolvable scaffold recovery routes singular

### Prerequisite Resolution

Apply this complete qualification rule to every expected prerequisite; the earlier selection/readiness summaries are shorthand for this rule:

1. Parse `story.md → ## Expected Prerequisites` for list bullets naming dependency story slugs. Validate each slug against `^[a-z0-9]+(?:-[a-z0-9]+)*$`; malformed values are unsatisfied and must not be interpolated into paths.
2. Resolve the active prerequisite first at `<openspec_root>/openspec/changes/<slug>/story.md`. The active prerequisite is authoritative whenever that file exists. Only when the active prerequisite file is absent, fall back to `<openspec_root>/openspec/changes/archive/<slug>/story.md`. Never let an archived DONE copy override an existing active prerequisite.
3. In the resolved prerequisite directory, require exactly one unambiguous top-level `Status:` header whose whole line is `Status: ✅ DONE`. Missing, duplicate, malformed, or non-DONE Status is unsatisfied. Check sibling `blocked.md` before trusting DONE: its existence makes the prerequisite contradictory and unsatisfied in both active and archived locations, regardless of receipt evidence.
4. Inventory the prerequisite's top-level header region exactly as for the selected story. Duplicate or malformed Initiative-like fields are contradictory and unsatisfied, never legacy. Exactly one valid canonical `Initiative:` header makes this a bound modern prerequisite.
5. A bound modern prerequisite must have `progress.md` containing exactly one `## Implementation Review Receipt` heading and one current body. Every required field (`Reviewed at`, `Decision`, `Approval gate`, `Status transition`, `Evidence reviewed`, `Identity method`, `Identity digest`, `Identity bases`, `Identity paths`, `Findings`, `Proof`, and `Next owner`) must occur exactly once; require `Decision: APPROVE`, `Approval gate: PASS`, and a transition ending in `✅ DONE`. Missing, duplicate, malformed, or non-approving receipt evidence is unsatisfied. After slug resolution and modern/legacy classification, prerequisite satisfaction uses only authoritative Status, `blocked.md`, and this modern receipt verdict; never recompute or freshness-check the story-scoped review identity against mutable repository state.
6. A prerequisite with zero Initiative or Initiative-like header lines is unbound legacy input. If any receipt section is present, it must satisfy the same single-current APPROVE/PASS verdict checks; malformed or contradictory receipt material fails. Only an unbound pre-v3 prerequisite with `Status: ✅ DONE`, no `blocked.md`, zero Initiative headers, and zero receipt sections may satisfy without a receipt: emit a compatibility warning and never synthesize or backfill one.
7. If neither active nor archived `story.md` exists, the prerequisite is unsatisfied. Report the exact failed gate and the prerequisite owner/action; do not claim or write lifecycle state.

If `## Expected Prerequisites` is absent or empty, the story has no dependencies and the readiness check for dependencies passes automatically.

## Worktree preflight

After picking a story but before writing any claim, figure out which repos the story will write to, whether any of them are dirty outside this story's own OpenSpec coordination paths, and for each dirty target build a linked git worktree on the story-specific branch. Clean target repos are written to directly; implementation work on dirty repos happens in a clean branch isolated from whatever else was in the main tree.

**Invariant**: `<workspace_root>` = `<cwd>` at launch and remains the discovery base. `<openspec_root>` is the root already selected by `## Resolution`: a qualifying explicit `WORKTREE=` root wins; otherwise one unique qualifying branch worktree outranks launch; multiple branch candidates halt; only no qualifying worktree falls back to launch. The selected existing root is authoritative immediately and must be reused without copying from a possibly stale launch checkout. Step 9 may change it only by creating a new root worktree and verifying a copy from the current authoritative root. Worktrees redirect writes to `projects/<name>/...` paths and `git -C` commands for the corresponding repo. Do not persist an `OpenSpec root:` field; later commands must run from the checkout containing the active `openspec/...` artifacts (or pass explicit `WORKTREE=` selectors for target repos).

1. **Set `<story_slug>` as the canonical change workspace name**. This is the directory name under `openspec/changes/`.

2. **Parse `## Scope` for target paths**. In the selected `story.md`, extract the text between the line matching `^## Scope$` and the next line matching `^## ` (any heading), or EOF if no next heading. Inside that text, find every substring matching the regex `projects/[A-Za-z0-9_-]+/` and deduplicate to `<scope_prefixes>` — the set of `<name>` values found. If the story file has no `## Scope` section, `<scope_prefixes>` is empty.

3. **Resolve `<target_repos>`**. Initialize `<target_repos>` as an empty set. For each `<name>` in `<scope_prefixes>`:
   - If `<workspace_root>/projects/<name>/.git` exists (a directory OR a gitlink file — test with `test -e`, not `git rev-parse`), add absolute `<workspace_root>/projects/<name>` to `<target_repos>`.
   - Otherwise skip silently (stale reference to a repo no longer on disk).

   Additionally, run `git -C <workspace_root> rev-parse --is-inside-work-tree`. If it succeeds, add `<workspace_root>` to `<target_repos>`. This preserves the single-repo case (where `<cwd>` itself is the code repo) and the nested-monorepo case.

4. **No targets**. If `<target_repos>` is empty, set `<project_root_map>` = `{}` and skip to step 10. The story will only touch coordination paths under `<openspec_root>/openspec/...`.

5. **Parse explicit `WORKTREE=` arguments** into `<explicit_worktree_map>`. Collect every `WORKTREE="<value>"` occurrence from `$ARGUMENTS`. For each value:
   - If it contains `=`, split on the FIRST `=` into `<basename>` and `<path>`. Normalize `<path>` to an absolute path and record as `<explicit_worktree_map>[<basename>]` = `<path>`.
   - Otherwise treat it as the legacy single form and record as `<legacy_worktree>` (normalized absolute path).

   Validation:
   - Mixing both forms (some `WORKTREE=` with `=`, some without) is an error: abort with "mix of `WORKTREE=\"path\"` and `WORKTREE=\"basename=path\"` forms is not allowed; use one or the other".
   - If `<legacy_worktree>` is set, it is only valid when exactly one `<target_repo>` was discovered. Apply it as `<explicit_worktree_map>[basename(<target_repo>)]` = `<legacy_worktree>`. Otherwise abort with "`WORKTREE=\"<path>\"` requires exactly one target repo; found N (basenames: ...). Pass `WORKTREE=\"<basename>=<path>\"` form to specify which repo".

6. **Per-repo dirty check and decision**. Initialize `<project_root_map>` = `{}`, `<pending_prompt>` = `[]`, and `<story_openspec_status_map>` = `{}`. Also carry forward any already-valid registered worktree discovered by the OpenSpec-root resolver. For each `<target_repo>` in `<target_repos>`, iterating in sorted order by basename for determinism:
   - `<repo-basename>` = `basename <target_repo>`.
   - `<porcelain>` = `git -C <target_repo> status --porcelain`.
   - `<default-path>` = `$HOME/add-worktrees/<repo-basename>-<initiative_slug>-<story_slug>`.
   - If `<target_repo>` is exactly `<workspace_root>`, split `<porcelain>` into two groups:
     - `<story_openspec_porcelain>`: porcelain lines whose path operand(s) are all under one of the current story-owned prefixes `openspec/initiatives/<initiative_slug>/` or `openspec/changes/<story_slug>/`.
     - `<blocking_porcelain>`: every other porcelain line, including any other `openspec/...` path.
     - For rename/copy porcelain entries containing ` -> `, classify the line as story-owned only when both the old and new path operands are under the story-owned prefixes. For quoted porcelain paths, classify by the unquoted path value. Ignore the porcelain status code otherwise: modified, staged, untracked, deleted, renamed, and copied entries are all allowed when the path scope is story-owned.
   - Else, set `<story_openspec_porcelain>` = empty and `<blocking_porcelain>` = `<porcelain>` (sub-repos do not own root `openspec/...`).
   - Record non-empty `<story_openspec_porcelain>` in `<story_openspec_status_map>[<repo-basename>]` for reporting. `<dirty_for_decision>` is true only when `<blocking_porcelain>` is non-empty.
   - If `<explicit_worktree_map>[<repo-basename>]` is set: set `<wt-path>` to that path. If it is already a registered worktree of `<target_repo>` on branch `<initiative_slug>/<story_slug>`, mark it for reuse; otherwise mark it for creation, regardless of dirtiness.
   - Else if the root resolver recorded an already-valid registered worktree for this target repo on branch `<initiative_slug>/<story_slug>`, mark that path for reuse. A TODO/unset unclaimed story may be claimed in this existing worktree; active claimed statuses have already routed to resume.
   - Else if `<dirty_for_decision>`: append `(<repo-basename>, <target_repo>, <default-path>, <blocking_porcelain>, <story_openspec_porcelain>)` to `<pending_prompt>` — decision deferred to the batched prompt in step 7.
   - Else (clean or only story-owned OpenSpec changes, no override): `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree). If `<story_openspec_porcelain>` is non-empty, report it as informational: these current-story OpenSpec changes are ignored for the worktree decision and `<repo-basename>` will still be recorded as a `Main-tree targets:` entry.

7. **Batched operator prompt**. If `<pending_prompt>` is non-empty, show ONE combined message. Decisions are based only on dirty paths outside the current story-owned OpenSpec prefixes; story-owned OpenSpec lines are grouped separately as informational:

   ```
   These target repos have uncommitted changes outside the current story's OpenSpec paths:
     <repo-basename-1>:
       Dirty changes requiring a worktree decision:
         <indented blocking porcelain output, capped at ~5 lines with "...and N more" suffix if truncated>
       Story-owned OpenSpec changes ignored for this decision:
         <indented story-owned porcelain output, capped the same way; omit this group when empty>
       Default worktree path: <default-path-1>
     <repo-basename-2>:
       Dirty changes requiring a worktree decision:
         <indented blocking porcelain output...>
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

   After parsing, for each pending repo: either set `<project_root_map>[<repo-basename>]` = `<target_repo>` (main tree mode) and warn, or resolve `<wt-path>` and mark for creation. Keep the story-owned OpenSpec group informational only; it must not force a worktree or block direct main-tree use.

8. **Reuse or create worktrees** for every repo marked in step 6 or 7, iterating in sorted basename order for determinism:
   - For a path marked for reuse, verify immediately before use that it still exists, is registered in `git -C <target_repo> worktree list --porcelain`, and is on branch `<initiative_slug>/<story_slug>`. On success set `<project_root_map>[<repo-basename>]` = `<wt-path>` and do not run `git worktree add`. On failure, abort before claim writes with the exact stale/mismatch detail; never silently create over it.
   - For a path marked for creation, run `mkdir -p "$(dirname <wt-path>)"`, then `git -C <target_repo> worktree add -b <initiative_slug>/<story_slug> <wt-path>`.
   - If creation fails because branch `<initiative_slug>/<story_slug>` already exists, recheck registered worktrees once. Reuse a unique registered worktree on that branch when valid; an unclaimed TODO/unset story may be claimed there in place. If no unique valid worktree exists, abort with the exact branch/worktree conflict and one concrete operator reconciliation action; do not misroute an unclaimed story to resume. List any worktrees already created earlier in this loop as "successfully created but NOT cleaned up: <list>". No story.md or progress.md writes have happened yet.
   - If it fails for any other reason, report the git error verbatim, list successful worktrees as "NOT cleaned up", and abort. **Do NOT auto-clean up successful worktrees** on partial failure — preserve operator choice.
   - On success: `<project_root_map>[<repo-basename>]` = `<wt-path>`.

9. **Root worktree OpenSpec copy and activation**. Run this step ONLY if ALL of the following are true:
   - `<workspace_root>` is itself a git repo (step 3's `rev-parse --is-inside-work-tree` succeeded),
   - `<workspace_root>` is in `<target_repos>`,
   - `<project_root_map>[basename(<workspace_root>)]` is a worktree (not `<workspace_root>` itself).

   Let `<root_wt>` = `<project_root_map>[basename(<workspace_root>)]`. If the resolver already selected this same valid `<root_wt>`, reuse the authoritative artifacts there in place: verify both required files again, skip all copying and source-checkout cleanup prompts in this step, and keep `<openspec_root>=<root_wt>`. Never overwrite the active worktree artifacts with a possibly stale launch-checkout copy.

   Otherwise, set `<copy_source_root>` to the current authoritative `<openspec_root>` and copy the current story's coordination artifacts from it into the newly selected root worktree before any `story.md` or `progress.md` write:
   - Copy `<copy_source_root>/openspec/initiatives/<initiative_slug>/` to `<root_wt>/openspec/initiatives/<initiative_slug>/`.
   - Copy `<copy_source_root>/openspec/changes/<story_slug>/` to `<root_wt>/openspec/changes/<story_slug>/`.
   - Create parent directories as needed. Copy only these two path-bounded directories; do not copy broad `openspec/`.
   - Verify the copy before continuing: `<root_wt>/openspec/initiatives/<initiative_slug>/initiative.md` and `<root_wt>/openspec/changes/<story_slug>/story.md` must exist, and recursive comparison of each copied source directory against its destination must show no missing or different files. If verification fails, abort before writing any claim and report the exact source/destination pair that failed.

   After verification succeeds, set `<openspec_root>` = `<root_wt>` for the rest of this claim and re-resolve `<initiative_dir>` and the selected change workspace under `<openspec_root>`. Do not write any persisted `OpenSpec root:` field; future `/openspec-story-resume`, `/openspec-story-review`, and `/openspec-story-converge` invocations should be run from `<root_wt>` (or supplied with explicit `WORKTREE="<basename>=<path>"` selectors for target repos as needed).

   Then ask the operator whether to clean the copied story-owned coordination paths from `<copy_source_root>`:
   ```
   Copied this story's OpenSpec artifacts into the root worktree at <root_wt> and verified them.
   Clean the copied paths from the source checkout <copy_source_root> now? Paths: openspec/initiatives/<initiative_slug>/ and openspec/changes/<story_slug>/ (yes/no)
   ```
   - If the operator says yes: verify the copy one more time, then run only path-scoped cleanup for those two paths in `<copy_source_root>` (tracked restore for tracked files, then `git -C <copy_source_root> clean -fd -- openspec/initiatives/<initiative_slug> openspec/changes/<story_slug>` for untracked files). Never clean broad `openspec/`, never clean unrelated paths, and never clean before copy verification.
   - If the operator says no: leave `<copy_source_root>` unchanged and warn that the active coordination copy for this claim is `<root_wt>/openspec/...`.

   Do NOT run this step against sub-repo worktrees; sub-repos do not contain root `openspec/` at all.

10. **Done**. `<project_root_map>` is set. All downstream resolution uses these rules:
    - `<initiative_dir>/initiative.md`, story files, and anything under `openspec/...` → read/write at `<openspec_root>/openspec/...`.
    - Code at `projects/<name>/foo/bar` → if `<project_root_map>` has `<name>`, route to `<project_root_map>[<name>]/foo/bar`; else route to `<workspace_root>/projects/<name>/foo/bar`.
    - Code in the root repo outside `openspec/...` and outside `projects/<name>/...` → if `<project_root_map>` has `basename(<workspace_root>)`, route the same relative path to that mapped root; else use `<workspace_root>/<relative-path>`.
    - Git commands targeting repo `<name>`: `git -C <project_root_map>[<name>] ...` (or `git -C <workspace_root>/projects/<name> ...` if `<name>` is not in the map).
    - If `<openspec_root>` differs from `<workspace_root>`, every operator-facing next command must say to run from `<openspec_root>` or preserve the explicit `WORKTREE=` selectors needed for non-root target repos.

## Claim protocol

Before deep implementation work, immediately re-read the selected story's complete Initiative header region, Plan/Status, `blocked.md`, and every prerequisite's active-first story/blocked/progress evidence. Rerun the exact binding and complete `### Prerequisite Resolution` gates after the worktree preflight; any duplicate/malformed binding, blocker, changed Status/Plan, or other failed prerequisite halts before the first claim/progress write.

Then:
1. Update the `Status:` header in `story.md` from `⬜ TODO` (or `⚪ TODO`, or absent) to `🔄 IN PROGRESS`
2. Create or update `progress.md` with these sections:

```md
## Current Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: $RUNTIME_NAME fresh session
- Model: $MODEL (the exact model name used for this claim)
- Scope: <one sentence>
- Worktrees:
  - <repo-basename>: <absolute-worktree-path>
  - <repo-basename>: <absolute-worktree-path>
- Main-tree targets: <repo-basename>, <repo-basename>
- Primary write surfaces: <paths>
- Status: 🔄 IN PROGRESS

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
7. If source inspection proves the TAP or contract materially wrong, follow the row's fallback plan only when it stays within scope; otherwise record the blocker and route to `/openspec-feedback`, singular story-plan-resume for an incomplete/non-reviewable scaffold, or `/openspec-story-plan-converge` only when the scaffold is complete/reviewable and the current Plan/log lane can be orchestrated. Do not silently replan inside claim.

- Default to red-first: make that focused seam fail, implement until it passes, then broaden verification.
- Do not jump straight to broad suites or code-first implementation if a smaller focused seam is available.
- Implement the claimed story end-to-end when feasible
- Prefer code changes over restating plans
- If you discover an initiative-wide architectural contradiction, update `initiative.md` minimally and note it in `progress.md → ## Progress Timeline`
- If you discover non-material evidence drift where the contract is still correct but the actual proof command/name changed, update only the concrete evidence row in `## Verification` and record why in `## Progress Timeline` before continuing.
- If implementation reveals variant-level proof needs, acceptance gaps, branch coverage gaps, input-boundary shape risk, activated risk lenses, or material contract drift not captured in the story, stop implementation work. Record a concise blocker in `## Progress Timeline`, set or ask to set the `Plan:` header to `🟠 PLAN CHANGES REQUESTED` when available, and route the story to `/openspec-feedback`, singular story-plan-resume for an incomplete/non-reviewable scaffold, or `/openspec-story-plan-converge` only when the complete/reviewable Plan/log lane can be orchestrated. Do not perform replanning inside `/openspec-story-claim`.
- If red-first is not feasible, record an explicit written exception in `## Progress Timeline` before proceeding. Name the reason, the alternative proof seam, and the verification path you will use instead.
- If Debt Friction exists, record it in `## Progress Timeline` using the `docs/openspec-conventions.md` shape. Use `fix-now` only for enabling cleanup directly required to make this story correct, testable, reviewable, or safely maintainable; include `Scope Justification`. Use `split-story`, `defer-explicitly`, or `block` for debt that is non-enabling, too large, too non-local, or proof-blocking.
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

Only check off tasks that are demonstrably complete per the implementation proof. If `tasks.md` does not exist, create a minimal one from `story.md → ## Acceptance` items after confirming with the operator.

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
- `🟣 IN REVIEW` — implementation done enough for an independent `/openspec-story-review`; the focused red seam is green or an explicit exception is recorded; run final verification, review the touched files, tighten rough edges
- `✅ DONE` — independent review completed via `/openspec-story-review`. **Do not set this status from `/openspec-story-claim`.**
- `⛔ BLOCKED` — an external blocker prevents completion or review

**Default rule:**
1. Claim as `🔄 IN PROGRESS`
2. Once the chosen focused seam is green and implementation is complete, move to `🟣 IN REVIEW`
3. Stop there and tell the operator to open a completely fresh, oblivious session and run `/openspec-story-review <initiative-slug> <story-slug>` from the checkout containing the active OpenSpec artifacts (`<openspec_root>` if it differs from the launch root), with no parent notebook, implementation summary, operational notes, or prior chat context. Optional GitHub PR delivery happens after local completion via `/openspec-pr`, which records PR metadata but does not own `story.md → Status:`.
4. If the session ends after implementation is complete but before independent review, leave at `🟣 IN REVIEW`
5. If the session ends before implementation is complete, leave at `🔄 IN PROGRESS`

### Blocked detection

In addition to normal status transitions, check for blocker signals:

1. If `blocked.md` exists in the change workspace (`openspec/changes/<story_slug>/blocked.md`), read it and halt with the blocker message.
2. If an external blocker is encountered during implementation, create `blocked.md` with the blocker details.
3. Transition `story.md → Status:` to `⛔ BLOCKED`.

### Commit check

Before transitioning to `🟣 IN REVIEW`, offer to check in worktree changes. For each worktree in `progress.md → ## Current Claim → - Worktrees:`, run `git -C <path> status --porcelain`. If dirty, propose `git -C <path> add -A && git -C <path> commit -m "<initiative_slug>/<story_slug>: <worksummary>"` and execute on operator confirmation. If all worktrees are clean, skip.

### Default Legend

There is no `MASTER.md` legend to update. The canonical status definitions are maintained in this skill's status transition table. If additional status conventions need to be documented, note them in `progress.md` directly.

## Final response

State:
- which story you claimed
- its final status
- files changed
- whether the initiative or story was updated
- notebook context used or updated, if material: referenced entries verified with direct-read/search anchors, stale referenced entries or absent needed facts with correction anchors, and notebook pages written for new sourced research; if notebook tools were unavailable, include compact sourced notes in the relevant final section instead

Suggested next action: <scalar route; leave empty only for a dual route>
- Converge wrapper: <command; dual routes only>
- Non-looped pass: <state-correct command; dual routes only>
Choose one; do not run both.

Derive the route from final authoritative `Plan:` and `Status:` plus the named gate evidence. For a scalar route, put its value on the label line and omit the three dual-route lines. For a dual route, leave the label empty and render those lines immediately after it. IN PROGRESS uses the implementation wrapper/Non-looped resume choice. IN REVIEW routes to the singular repair owner when a named deficiency exists and says fresh review happens only after repair; use a completely fresh, oblivious `/openspec-story-review` handoff only when review has not yet run and prerequisites are satisfied. The wrapper never launches review. DONE with non-approved Plan uses only the operator action to investigate/reconcile contradictory durable state and names no lifecycle owner. Keep blocked, incomplete/non-reviewable scaffold, malformed/ambiguous, missing-workspace, prerequisite, other DONE, PR, archive, wait, and terminal routes singular.
