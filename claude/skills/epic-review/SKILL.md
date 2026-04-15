---
name: epic-review
description: Review one implemented epic step against its story spec, current repo state, and recorded handoff context. Read-only for code; updates only the step's coordination file.
disable-model-invocation: true
argument-hint: "<epic-name> <story-number-or-spec-file>"
allowed-tools: Read Edit Grep Glob Bash(git status:*) Bash(git diff:*) Bash(git log:*) Bash(git rev-parse:*) Bash(git worktree:*) Bash(basename:*)
---

# Epic Review

Review one epic story implementation against its step spec, current repo state, and recorded handoff context. Record the verdict back into the coordination file.

Argument: `$ARGUMENTS` — `<epic_name> <story_number_or_spec_file> [WORKTREE="<basename>=<path>"]...`. Both positional args are required (a menu fallback is shown when either is omitted, see `## Resolution`). `WORKTREE=` is an optional, repeatable opt-in that overrides the preflight's worktree lookup per target repo. Two forms are accepted: `WORKTREE="<basename>=<path>"` (multi form, repeatable, preferred) and legacy `WORKTREE="<path>"` (valid only when the story has exactly one target repo; the path is applied to that sole repo). Mixing the two forms in a single invocation is an error. When `WORKTREE=` is absent, the preflight reads any `- Worktrees:` list from the story's `## Active Claim`, falling back to a legacy `- Worktree:` singular bullet for stories claimed before the multi-worktree format.

## Important

You can only change the coordination files in the epic, **never** the source code of the app. Review is inherently a read-only process.

## Why operator-explicit (arg or menu) selection

`/epic-review` never auto-infers the epic or the story. The operator explicitly chooses — either by passing `<epic> <story>` as arguments or by picking from the menu this skill shows when either is absent. The menu is **not** inference: it lists the legal candidates (filtered to `🟣 IN REVIEW`) and asks the operator to pick.

The reasoning: review must come from a fresh, independent perspective. The same session that just implemented a story will rationalize its own work, not scrutinize it. Auto-inferring "the current story" would silently pick whatever the session was last working on — exactly the coupling we want to avoid.

A gentle nudge: if you find yourself picking from the menu in the same session that just wrote the implementation, consider opening a fresh session for the review. The menu still makes it possible to run review from the implementation session, but the friction is intentional and any future change that adds silent auto-inference here must be rejected.

## Resolution

1. Parse `$ARGUMENTS`:
   - `<epic>`: optional, the first positional token (epic name)
   - `<story>`: optional, the second positional token (story number or spec file)
   - The raw list of `WORKTREE="<value>"` occurrences (parsed in `## Worktree preflight` step 3 into `<explicit_worktree_map>` and/or `<legacy_worktree>`)

   Set `<workspace_root>` = `<cwd>`. `<workspace_root>` is never re-anchored; coordination files always live here.
2. **EPIC resolution (menu fallback):**
   - If `<epic>` was passed, resolve `<workspace_root>/agent_coordination/epics/<epic>`.
   - If `<epic>` was not passed, list every directory under `<workspace_root>/agent_coordination/epics/` whose `MASTER.md` has at least one row with status `🟣 IN REVIEW`. For each, print: `<slug> — <N stories IN REVIEW, last-touched YYYY-MM-DD>`. If the filtered list is empty, abort with: `no epics have stories ready for review (nothing at 🟣 IN REVIEW)`. Otherwise ask the operator to pick (number or slug).
3. **STORY resolution (menu fallback):**
   - If `<story>` was passed, continue to resolution step 4.
   - If `<story>` was not passed, list every row in `<epic>/MASTER.md` whose status is `🟣 IN REVIEW`. For each, print: `<Step> — <Deliverable>`. If the filtered list is empty, abort with: `no stories at 🟣 IN REVIEW in <epic>`. Otherwise ask the operator to pick (number or slug).
4. Use `<epic>/MASTER.md` as the only lookup table.
5. First try to match exactly one row whose `Step` value equals `<story>`.
6. If no row matches by `Step`, try to match exactly one row whose `Spec` value equals `<story>`.
7. If neither lookup finds a row, abort fast and report the unresolved selector plus the available `Step` and `Spec` values from `MASTER.md`.
8. If the `Step` lookup and `Spec` lookup both match but point to different rows, abort fast and report the ambiguity.
9. Resolve the step file as `<epic>/<matched row Spec value>`.
10. If that path does not exist, abort fast and report the exact missing path.

## Read first

1. the main repo `AGENTS.md` for the repo you will touch
2. `<epic>/MASTER.md`
3. the resolved step file
4. dependency step files listed for the resolved step in `MASTER.md`

## Review intent

Do **not** rediscover the epic from scratch. Your job is to:
1. Understand the story spec in the resolved step file
2. Inspect the actual implementation and current worktree
3. Review the implementation against the step spec and surrounding architecture
4. Record the review result back into the coordination file

## Review readiness check

Before doing a full review:
- inspect the row for the resolved step in `MASTER.md`
- inspect any `Active Claim`, `Progress Log`, `Session Handoff`, and `PR Tracking` sections in the step file

If the story is clearly not reviewable yet, abort fast with a concise reason. Examples:
- step is still `TODO` and there is no implementation / handoff evidence
- step is blocked by an unmet dependency and the code cannot be sensibly judged
- no credible mapping from the step spec to any code or tests yet

## Worktree preflight

After reading the story's `## Active Claim`, build `<project_root_map>` from what the claim recorded plus any explicit overrides. This command **never creates** a worktree; it only reuses what the implementer recorded or what the operator passed explicitly.

**Invariant**: `<workspace_root>` = `<cwd>`, always. All reads under `agent_coordination/...` anchor at `<workspace_root>` unconditionally, regardless of any worktrees referenced below. The review verdict and `## Review Log` write-back also anchor at `<workspace_root>/agent_coordination/...`.

1. **Read `Worktrees:` from `## Active Claim`**. Parse the story file for a `- Worktrees:` bullet under `## Active Claim`. For each child bullet of the form `- <basename>: <path>`, record `<recorded_worktree_map>[<basename>]` = `<path>` (normalized absolute). If no `- Worktrees:` bullet exists, `<recorded_worktree_map>` is empty.

2. **Back-compat read for legacy single-form**. If `<recorded_worktree_map>` is empty, look for a legacy `- Worktree: <path>` (singular) bullet. If present, set `<recorded_worktree_map>[basename(<path>)]` = `<path>`. Review never rewrites the claim, so back-compat mode just reads the legacy bullet without changing the file.

3. **Parse explicit `WORKTREE=` arguments** into `<explicit_worktree_map>`. Collect every `WORKTREE="<value>"` occurrence from `$ARGUMENTS`. For each value:
   - If it contains `=`, split on the FIRST `=` into `<basename>` and `<path>`. Normalize `<path>` to an absolute path and record as `<explicit_worktree_map>[<basename>]` = `<path>`.
   - Otherwise treat it as the legacy single form and record as `<legacy_worktree>` (normalized absolute path).

   Validation:
   - Mixing both forms (some `WORKTREE=` with `=`, some without) is an error: abort with "mix of `WORKTREE=\"path\"` and `WORKTREE=\"basename=path\"` forms is not allowed; use one or the other".
   - If `<legacy_worktree>` is set, defer its application until `<target_repos>` is computed in step 4; it is only valid when exactly one `<target_repo>` is discovered.

4. **Compute `<story-slug>` and `<target_repos>`**:
   - `<story-slug>` = strip `.md` from the resolved step's spec file.
   - If `<recorded_worktree_map>` is non-empty, build `<target_repos>` from its basenames: for each `<basename>`, resolve to `<workspace_root>/projects/<basename>` if `<workspace_root>/projects/<basename>/.git` exists, or to `<workspace_root>` if `<basename>` matches `basename(<workspace_root>)` AND `<workspace_root>` is itself a git repo.
   - Else fall back to the same `## Scope` strict parse + target-resolution logic as `/epic-claim` (Worktree preflight steps 2–3): parse `## Scope` for `projects/[A-Za-z0-9_-]+/` tokens, intersect with real `<workspace_root>/projects/<name>/.git` repos, additionally include `<workspace_root>` if it is itself a git repo.

   If `<legacy_worktree>` is set (from step 3), it is now applied: `<explicit_worktree_map>[basename(<sole_target_repo>)]` = `<legacy_worktree>` if `<target_repos>` has exactly one element, otherwise abort with "`WORKTREE=\"<path>\"` requires exactly one target repo; found N (basenames: ...). Pass `WORKTREE=\"<basename>=<path>\"` form to specify which repo".

5. **Build `<project_root_map>` from recorded + explicit entries**. Initialize empty. For each `<basename>` in the union of `<recorded_worktree_map>` keys and `<explicit_worktree_map>` keys:
   - Effective path = `<explicit_worktree_map>[<basename>]` if present (explicit wins for the overridden basename only), else `<recorded_worktree_map>[<basename>]`.
   - Resolve `<target_repo>` for `<basename>`: `<workspace_root>/projects/<basename>` if `<basename>` resolves to a sub-repo, else `<workspace_root>` if it matches `basename(<workspace_root>)`. If neither, abort with "claimed worktree for `<basename>` cannot be matched to any repo on disk".
   - Verify the effective path exists on disk AND appears in `git -C <target_repo> worktree list --porcelain`.
   - Verify the worktree's HEAD is on branch `<epic-name>/<story-slug>` via `git -C <effective path> rev-parse --abbrev-ref HEAD`. Tolerate a detached HEAD with a warning ("worktree for `<basename>` is in detached HEAD state — review will run against the checked-out commit").
   - On any verification failure: abort with "worktree for `<basename>` is missing, unregistered, or on the wrong branch: <verbatim detail>. Clean the main tree and retry, ask the implementer to `/epic-resume` (which recreates stale worktrees), or pass `WORKTREE=\"<basename>=<path>\"` explicitly". **Never create a worktree in review.**
   - On success: `<project_root_map>[<basename>]` = effective path.

6. **Handle scope-scan repos not in any map**. For each `<target_repo>` from step 4 whose basename is NOT yet in `<project_root_map>`:
   - Run `git -C <target_repo> status --porcelain`.
   - If the output is non-empty (dirty): abort with "can't review dirty `<basename>` without a recorded worktree. Clean `<target_repo>`, have the implementer `/epic-resume` (which records a Worktrees entry), or pass `WORKTREE=\"<basename>=<path>\"` explicitly pointing at a worktree with the story's branch checked out".
   - If clean: `<project_root_map>[<basename>]` = `<target_repo>` (main tree — review inspects the implementation in place).

7. **Done**. `<project_root_map>` is set. All downstream resolution uses these rules:
   - `<epic>/MASTER.md`, the resolved step file, dependency step files, and anything under `agent_coordination/...` → read/write at `<workspace_root>/agent_coordination/...` unconditionally. The `## Review Log` write-back also lands at this anchor.
   - Code at `projects/<name>/foo/bar` → if `<project_root_map>` has `<name>`, route to `<project_root_map>[<name>]/foo/bar`; else (clean main-tree fallback from step 6) route to `<workspace_root>/projects/<name>/foo/bar`.
   - Git commands targeting repo `<name>`: `git -C <project_root_map>[<name>] ...`.

## Source-of-truth hierarchy

1. `<epic>/MASTER.md`
2. the resolved step file
3. dependency step files
4. actual code, tests, and worktree diff

Do not infer identity from filename shape or naming conventions that are not explicitly recorded in `MASTER.md`.

## Review process

1. Use code search and direct reading to understand the story's implementation and impacted surfaces
2. Use `git -C <project_root_map>[<basename>] status`, `git -C <project_root_map>[<basename>] diff`, and targeted file reads to inspect what was actually changed. When the story spans multiple repos, run status/diff per repo (iterating over `<project_root_map>` in sorted basename order) and group findings per-repo in the review write-back. Each `<basename>` resolves to either an implementer's worktree (most common) or the main tree at `<workspace_root>/projects/<basename>` (clean main-tree fallback case from the preflight).
3. Never speculate about code you haven't read
4. Break the reviewed implementation into logical groups; explain the grouping briefly
5. Review each group sequentially
6. Prioritize:
   - correctness
   - regressions
   - architectural consistency
   - duplication / missed reuse
   - status / progress drift from the step spec
   - missing tests
   - rollout / operational risks where relevant

## Critical checks

Before approving, verify:
- Does the implementation actually satisfy the step spec?
- Were any epic-wide architectural decisions violated?
- Can existing code have been extended instead of creating new duplication?
- Do the changes respect module boundaries and current patterns?
- Are there security implications in the implementation or operational model?
- Are there performance or scalability regressions in the changed path?
- Are follow-on status transitions accurate in `MASTER.md` and the step file?
- Are there adequate tests for the change?
- Are there hidden packaging / runtime / ops implications not captured in the step?

## Status transitions

You may update `MASTER.md` as part of the review. Use this policy:

- if review starts on a step marked `🔄 IN PROGRESS` but implementation is clearly ready for review, move it to `🟣 IN REVIEW`
- if review passes with no blocking findings AND the epic does not use the optional GitHub PR stage for this story, mark it `✅ DONE`
- if review passes with no blocking findings AND the story is expected to go through a GitHub PR review, leave it at `🟣 IN REVIEW` and tell the user to run `/epic-pr` to transition to `🔵 IN PR`
- if review finds issues that require more implementation work, move it to `🔄 IN PROGRESS`
- if review cannot complete because of an external blocker, mark it `⛔ BLOCKED`
- if the step is currently `🔵 IN PR`, treat this as a pre-merge sanity review only; **do not transition the status from `🔵 IN PR` yourself**. Any merge-state change belongs to `/epic-pr`. Record findings in the `Review Log` as normal.

## Review log write-back

Append or update a `## Review Log` section in the step file with a new entry:

```md
- <UTC ISO timestamp> Review run by Claude fresh session
  - Verdict: approve | request_changes | blocked | not_reviewable
  - Status transition: <from> -> <to>
  - Files reviewed: <paths>
  - Key findings:
    - <short bullet>
    - <short bullet>
  - Next action: <one concrete recommendation>
```

If a `Review Log` section does not exist, create it.

## Output format

Start with findings, ordered by severity, with file references.

```markdown
**Decision**: [APPROVE | REQUEST CHANGES | BLOCKED | NOT REVIEWABLE]
**Reviewed Story**: [Step <resolved_step_number> / <resolved_spec_file>]
**Grouping**: [brief grouping logic]

**Findings**
- [Severity] [file:line] issue

**Summary**
- [2-4 short bullets]

**Status Transition**
- [old -> new]

**Next Action**
- [single concrete next step]
```

If there are no findings, say that explicitly.
