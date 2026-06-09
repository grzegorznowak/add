---
name: openspec-story-review
description: Review one implemented OpenSpec change workspace against its spec, current repo state, and recorded handoff context. Read-only for code; updates only the change workspace's reviews.md and story.md Status header.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug> [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Edit Grep Glob Task Bash(git status:*) Bash(git diff:*) Bash(git log:*) Bash(git show:*) Bash(git rev-parse:*) Bash(git worktree:*) Bash(basename:*) Bash(gh issue view:*) Bash(gh pr view:*) Bash(jira issue view:*)
---

# OpenSpec Story Review

Review one story implementation against its spec, current repo state, and recorded handoff context. Record the verdict into `reviews.md` and update the `Status:` header in `story.md`.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug> [WORKTREE="<basename>=<path>"]...`. Both positional args are recommended; if either is omitted, this command uses the explicit menu fallback in `## Resolution`. `WORKTREE=` is an optional, repeatable opt-in that overrides the preflight's worktree lookup per target repo. Two forms are accepted: `WORKTREE="<basename>=<path>"` (multi form, repeatable, preferred) and legacy `WORKTREE="<path>"` (valid only when the story has exactly one target repo; the path is applied to that sole repo). Mixing the two forms in a single invocation is an error. When `WORKTREE=` is absent, the preflight reads any `- Worktrees:` list from `progress.md`'s `## Current Claim`, falling back to a legacy `- Worktree:` singular bullet for claims predating the multi-worktree format.

## Important

You can only change the coordination files in the change workspace (`reviews.md` and `story.md`'s `Status:` header), **never** the source code of the app. Review is inherently a read-only process.

## Safety guardrails

- Do not modify source code — review is read-only.
- Do not run destructive git operations (push, `reset --hard`, force commands, branch deletion).
- Never write outside the change workspace's `openspec/` directory or `/tmp`; do not edit target worktrees.
- Test execution is permitted only to verify the story's proof matrix (not for broad exploration), even when normal test tooling writes caches or artifacts.
- GitHub/Jira access is read-only for intent mining. Use view-only commands such as `gh issue view`, `gh pr view`, and `jira issue view`; do not use generic API commands that can issue mutating requests.

## Why operator-explicit (arg or menu) selection

`/openspec-story-review` never auto-infers the initiative or the story. The operator explicitly chooses — either by passing `<initiative-slug> <story-slug>` as arguments or by picking from the menu this skill shows when either is absent. The menu is **not** inference: it lists the legal candidates (filtered to `🟣 IN REVIEW`) and asks the operator to pick.

The reasoning: review must come from a fresh, independent perspective. The same session that just implemented a story will rationalize its own work, not scrutinize it. Auto-inferring "the current story" would silently pick whatever the session was last working on — exactly the coupling we want to avoid.

A gentle nudge: if you find yourself picking from the menu in the same session that just wrote the implementation, consider opening a fresh session for the review. The menu still makes it possible to run review from the implementation session, but the friction is intentional and any future change that adds silent auto-inference here must be rejected.

## Resolution

1. Parse `$ARGUMENTS`:
   - `<initiative-slug>`: optional, the first positional token (initiative slug)
   - `<story-slug>`: optional, the second positional token (story slug / change workspace name)
   - The raw list of `WORKTREE="<value>"` occurrences (parsed in `## Worktree preflight` step 3 into `<explicit_worktree_map>` and/or `<legacy_worktree>`)

   Set `<workspace_root>` = `<cwd>`. `<workspace_root>` is never re-anchored; coordination files always live here.
2. **INITIATIVE resolution (menu fallback):**
   - If `<initiative-slug>` was passed, resolve `<workspace_root>/openspec/initiatives/<initiative-slug>/initiative.md`.
   - If `<initiative-slug>` was not passed, scan every directory under `<workspace_root>/openspec/initiatives/` whose `initiative.md` exists and whose `## Story Candidates` section references at least one change workspace with a `story.md` that has `Status: 🟣 IN REVIEW`. For each candidate, print: `<slug> — <N stories IN REVIEW, last-touched YYYY-MM-DD>`. If the filtered list is empty, abort with: `no initiatives have stories ready for review (nothing at 🟣 IN REVIEW)`. Otherwise ask the operator to pick (number or slug).
3. **STORY resolution (menu fallback):**
   - If `<story-slug>` was passed, continue to resolution step 4.
   - If `<story-slug>` was not passed, scan every change workspace referenced in the resolved initiative's `## Story Candidates` section whose `story.md` has `Status: 🟣 IN REVIEW`. For each, print: `<story-slug> — <Status> — <Deliverable summary>`. If the filtered list is empty, abort with: `no stories at 🟣 IN REVIEW in initiative <slug>`. Otherwise ask the operator to pick (number or slug).
4. Set `<initiative_dir>` = `<workspace_root>/openspec/initiatives/<initiative-slug>`.
   - If `<initiative_dir>` does not exist, abort with: `initiative not found: openspec/initiatives/<initiative-slug>/ — run /openspec-epic-plan first`.
5. Set `<initiative_file>` = `<initiative_dir>/initiative.md`.
   - If `<initiative_file>` does not exist, abort with the exact missing path.
6. Set `<change_dir>` = `<workspace_root>/openspec/changes/<story-slug>`.
   - If `<change_dir>` does not exist, check `<workspace_root>/openspec/changes/archive/<story-slug>/`.
   - If archived, abort with: `story is archived under openspec/changes/archive/; move it back to openspec/changes/ first`.
   - If missing in both locations, abort with: `change workspace not found: openspec/changes/<story-slug>/ — run /openspec-story-plan first`.
7. Set `<story_file>` = `<change_dir>/story.md`.
   - If `<story_file>` does not exist, abort with the exact missing path.
8. The `Status:` header field in `<story_file>` is the authoritative implementation status. There is no `MASTER.md` in this flow. If the story does not use a YAML frontmatter-style `Status:` header but has an equivalent (e.g., an `## Status` section with `🟣 IN REVIEW`), treat that as the authority and use the same format for write-back.
9. The `Plan:` header field in `<story_file>` is the authoritative planning lane. Check that it is `🟢 PLAN APPROVED` before approving implementation (see `## Review readiness check`).

## Read first

1. the main repo `AGENTS.md` for the repo the implementation touches
2. `<initiative_dir>/initiative.md` — for Goal/Context, Story Candidates, Decisions & Constraints, External Resources, and Feedback Absorption Log context
3. the resolved `<story_file>` — every section (Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, Discovery Notes)
4. `<change_dir>/proposal.md` — for Goal/Context and Decisions & Constraints
5. `<change_dir>/design.md` — for technical design context, architecture decisions, and implementation strategy
6. `<change_dir>/tasks.md` — for task breakdown and implementation plan; verify tasks.md checkbox state matches the claimed implementation progress
7. delta spec files under `<change_dir>/specs/` — for spec-level behavioral obligations
8. `<change_dir>/progress.md` — for Progress Timeline, Session Handoff, Current Claim (worktree bindings and main-tree targets), and PR State
9. `<change_dir>/reviews.md` — for prior review log entries (all past `Decision`, `Approval gate`, `Key findings`, and `Prior review concerns`)
10. dependency change workspace `story.md` files listed in the resolved story's `## Expected Prerequisites`
11. materially relevant sibling change workspaces (from `## Story Candidates` in `initiative.md`) when they define shared interfaces, proof surfaces, actor flows, or locked decisions that this story's implementation touches
12. original intent artifacts explicitly linked or keyed from `initiative.md`, `story.md`, dependency workspaces, branch names, commit messages, or existing PR text: GitHub issues, GitHub PRs, Jira tickets, or stable ticket/card ids
13. design sources explicitly listed in `## Verification` (`### Design Sources`) when present; inspect only durable/reviewable anchors and treat orientation-only sources as context

## Review intent

Do **not** rediscover the initiative from scratch. Your job is to:
1. Understand the story spec in the resolved `story.md`
2. Inspect the actual implementation and current worktree
3. Inspect initiative-wide context and targeted sibling-story context when they materially constrain the story
4. Review the implementation against the story spec, initiative context, original intent when explicitly available, and surrounding architecture
5. Record the review result into `reviews.md` and update the `Status:` header in `story.md`

## Review readiness check

Before doing a full review:
- inspect the `Status:` header in `story.md`
- inspect the `Plan:` header in `story.md`
- inspect `<change_dir>/progress.md` for `## Current Claim`, `## Progress Timeline`, `## Session Handoff`, and `## PR State`
- inspect `<change_dir>/blocked.md` — if this file exists, the story is explicitly blocked; abort or record `not_reviewable`
- inspect every relevant story-spec section as a claim, not only `## Acceptance` and `## Verification`: `## Purpose`, `## Actors`, `## Triggering Need`, `## Expected Prerequisites`, `## Scope`, `## Out of Scope`, `## Scenarios / Behavior Examples`, `## Acceptance`, `## Verification`, `## Critical Files`, `## Implementation Notes`, `## Locked Decisions`, and `## Discovery Notes` when present
- inspect `<initiative_file>` for sections that define initiative-wide invariants or shared obligations for this story
- inspect original issue/PR/Jira/card intent only when explicitly linked or keyed; if unavailable, weak, or contradictory, record that instead of inventing linkage

If the story is clearly not reviewable yet, abort fast with a concise reason. Examples:
- story `Status:` is still `⬜ TODO` and there is no implementation / handoff evidence
- story is blocked by an unmet dependency (`blocked.md` exists or `## Expected Prerequisites` lists an unsatisfied dependency) and the code cannot be sensibly judged
- no credible mapping from the story spec to any code or tests yet
- any acceptance id has no proof row, or any proof row is still `provisional`
- `Plan:` is not `🟢 PLAN APPROVED` (the implementation cannot be approved without plan approval)

If you must ABORT:
- Output using the output format below.
- Set **Decision** to `NOT REVIEWABLE`.
- Set **Approval Gate** to `FAIL`.
- Include a Gate Finding explaining why.
- Keep all other sections present using `- None.`

## Worktree preflight

After reading `progress.md`'s `## Current Claim`, build `<project_root_map>` from what the claim recorded plus any explicit overrides. This command **never creates** a worktree; it only reuses what the implementer recorded or what the operator passed explicitly.

**Invariant**: `<workspace_root>` = `<cwd>`, always. All reads under `openspec/...` anchor at `<workspace_root>` unconditionally, regardless of any worktrees referenced below. The review verdict write-back to `reviews.md` and the `Status:` header write-back to `story.md` also anchor at `<workspace_root>/openspec/changes/<story-slug>/`.

1. **Read `Worktrees:` from `## Current Claim` in `progress.md`**. Parse `progress.md` for a `- Worktrees:` bullet under `## Current Claim`. For each child bullet of the form `- <basename>: <path>`, record `<recorded_worktree_map>[<basename>]` = `<path>` (normalized absolute). If no `- Worktrees:` bullet exists, `<recorded_worktree_map>` is empty.

2. **Back-compat read for legacy single-form**. If `<recorded_worktree_map>` is empty, look for a legacy `- Worktree: <path>` (singular) bullet under `## Current Claim`. If present, set `<recorded_worktree_map>[basename(<path>)]` = `<path>`. Review never rewrites the claim, so back-compat mode just reads the legacy bullet without changing the file.

3. **Parse explicit `WORKTREE=` arguments** into `<explicit_worktree_map>`. Collect every `WORKTREE="<value>"` occurrence from `$ARGUMENTS`. For each value:
   - If it contains `=`, split on the FIRST `=` into `<basename>` and `<path>`. Normalize `<path>` to an absolute path and record as `<explicit_worktree_map>[<basename>]` = `<path>`.
   - Otherwise treat it as the legacy single form and record as `<legacy_worktree>` (normalized absolute path).

   Validation:
   - Mixing both forms (some `WORKTREE=` with `=`, some without) is an error: abort with "mix of `WORKTREE=\"path\"` and `WORKTREE=\"basename=path\"` forms is not allowed; use one or the other".
   - If `<legacy_worktree>` is set, defer its application until `<target_repos>` is computed in step 5; it is only valid when exactly one `<target_repo>` is discovered.

4. **Read `Main-tree targets:` from `## Current Claim` in `progress.md`**. Parse `progress.md` for a `- Main-tree targets:` bullet under `## Current Claim`. Split its value on commas and trim whitespace to produce `<main_tree_targets>` — a set of repo basenames that the implementer explicitly wrote to on the main tree (no worktree). If the bullet is absent, `<main_tree_targets>` is empty.

5. **Compute `<story-slug>` and `<target_repos>`**:
   - `<story-slug>` is the second positional argument, already resolved.
   - Initialize `<target_repos>` as empty.
   - For every basename in the union of `<recorded_worktree_map>` keys, `<explicit_worktree_map>` keys, and `<main_tree_targets>`, resolve the repo to `<workspace_root>/projects/<basename>` if `<workspace_root>/projects/<basename>/.git` exists, or to `<workspace_root>` if `<basename>` matches `basename(<workspace_root>)` AND `<workspace_root>` is itself a git repo. Add each resolved repo to `<target_repos>`. If any recorded/explicit/main-tree basename cannot be resolved, abort with "claimed target `<basename>` cannot be matched to any repo on disk".
   - If `<target_repos>` is still empty, fall back to parsing `story.md`'s `## Scope` section: parse for `projects/[A-Za-z0-9_-]+/` tokens, intersect with real `<workspace_root>/projects/<name>/.git` repos, additionally include `<workspace_root>` if it is itself a git repo.

   If `<legacy_worktree>` is set (from step 3), it is now applied: `<explicit_worktree_map>[basename(<sole_target_repo>)]` = `<legacy_worktree>` if `<target_repos>` has exactly one element, otherwise abort with "`WORKTREE=\"<path>\"` requires exactly one target repo; found N (basenames: ...). Pass `WORKTREE=\"<basename>=<path>\"` form to specify which repo".

6. **Build `<project_root_map>` from recorded + explicit entries**. Initialize empty. For each `<basename>` in the union of `<recorded_worktree_map>` keys and `<explicit_worktree_map>` keys:
   - Effective path = `<explicit_worktree_map>[<basename>]` if present (explicit wins for the overridden basename only), else `<recorded_worktree_map>[<basename>]`.
   - Resolve `<target_repo>` for `<basename>`: `<workspace_root>/projects/<basename>` if `<basename>` resolves to a sub-repo, else `<workspace_root>` if it matches `basename(<workspace_root>)`. If neither, abort with "claimed worktree for `<basename>` cannot be matched to any repo on disk".
   - Verify the effective path exists on disk AND appears in `git -C <target_repo> worktree list --porcelain`.
   - Verify the worktree's HEAD is on branch `<initiative-slug>/<story-slug>` via `git -C <effective path> rev-parse --abbrev-ref HEAD`. Tolerate a detached HEAD with a warning ("worktree for `<basename>` is in detached HEAD state — review will run against the checked-out commit").
   - On any verification failure: abort with "worktree for `<basename>` is missing, unregistered, or on the wrong branch: <verbatim detail>. Clean the main tree and retry, ask the implementer to `/openspec-story-resume` (which recreates stale worktrees), or pass `WORKTREE=\"<basename>=<path>\"` explicitly". **Never create a worktree in review.**
   - On success: `<project_root_map>[<basename>]` = effective path.

7. **Handle target repos not in any worktree map**. For each `<target_repo>` from step 5 whose basename is NOT yet in `<project_root_map>`:
   - `<project_root_map>[<basename>]` = `<target_repo>` (main tree).
   - If `<basename>` is in `<main_tree_targets>`: the implementer recorded that this repo was written to directly on main. If the main tree is dirty, emit a note: "reviewing `<basename>` on main tree (recorded as a main-tree target by the implementer)". If clean, no note needed. Either way, review proceeds.
   - Else if `<main_tree_targets>` is empty (legacy claim predating this bullet): fall back to accepting the main tree regardless of dirtiness. If dirty, emit a note: "reviewing `<basename>` on dirty main tree (no `Main-tree targets:` bullet in claim — assuming implementation was done directly on main)". Review proceeds.
   - Else (`<main_tree_targets>` is non-empty but does NOT include `<basename>`): this repo was not declared as a main-tree target and has no recorded worktree. If clean, proceed silently. If dirty, warn: "`<basename>` is dirty and was not recorded as a main-tree target or worktree — the dirty state may include unrelated changes. Review proceeds but findings should be checked carefully."

8. **Done**. `<project_root_map>` is set. All downstream resolution uses these rules:
   - `<initiative_file>`, `<story_file>`, `progress.md`, `reviews.md`, `blocked.md`, and anything under `openspec/...` → read/write at `<workspace_root>/openspec/...` unconditionally. The review verdict write-back to `reviews.md` also lands at this anchor.
   - Code at `projects/<name>/foo/bar` → if `<project_root_map>` has `<name>`, route to `<project_root_map>[<name>]/foo/bar`; else route to `<workspace_root>/projects/<name>/foo/bar`.
   - Git commands targeting repo `<name>`: `git -C <project_root_map>[<name>] ...`.

## Source-of-truth hierarchy

1. the main repo `AGENTS.md`
2. `<initiative_file>` for initiative identity, constraints, decisions, and story candidate context
3. the resolved `<story_file>` — the story contract
4. dependency change workspace `story.md` files
5. relevant sibling change workspaces or contract sections the resolved story depends on
6. durable design sources explicitly listed as `normative` in the resolved story's `### Design Sources`; orientation-only design sources are context only
7. original issue/ticket/PR/Jira intent and acceptance criteria, when explicitly linkable and not superseded by decisions recorded in `initiative.md` or `story.md`
8. actual code, tests, and worktree diff

`initiative.md` is authoritative for already-established initiative-level context. If original ticket/PR/Jira intent conflicts with decisions recorded in `initiative.md`, do not silently prefer the ticket; the implementation is not approvable unless the story records an explicit reopen, scope-deviation, or initiative-staleness decision. If `initiative.md` context conflicts with the live codebase, name the conflict: codebase facts win as evidence of reality, and the finding should route initiative context repair through `/openspec-epic-plan`, `/openspec-feedback`, or `/openspec-story-plan-converge` as appropriate rather than silently approving drift. Never invent linkage: if ticket/PR/Jira evidence is absent, inaccessible, weak, or contradictory, say so explicitly and review against the remaining initiative/story/code sources.

Do not infer identity from filename shape or naming conventions that are not explicitly recorded in `initiative.md` or `story.md`.

## Notebook Input

When launched by a converger, you may receive a `Shared notebook context from parent orchestration session` block before the slash command. This is the only allowed cross-session context beyond neutral operational notes. Use it as sourced orientation only. The converger owns keeping notebook entries relevant; you only decide whether the needed fact is present in the provided notebook context. If present, verify it with direct reads/search against the cited anchors before it affects a finding, approval, or write-back instead of rerunning expensive research. If a provided notebook entry does not verify, report a notebook-refresh signal with exact anchors; do not decide how to curate the notebook. If absent, follow this skill's normal research rules. Ignore any notebook item that lacks an exact source anchor such as `path:line`, symbol, command/output excerpt, or tool/query/path.

## Proof-boundary discipline

Use the approval gate below as the canonical pass/fail contract; this section defines what evidence must be inspected before applying that gate.

- Read the latest entry in `<change_dir>/reviews.md` before source inspection (the last entry in the append-only file) and carry every prior concern into the review as `resolved`, `still_open`, `superseded`, or `not_assessable`.
- Treat every relevant story-spec section as a review claim. Purpose, Triggering Need, Scope, Out of Scope, Discovery Notes, Critical Files, Implementation Notes, and Locked Decisions can all create implementation obligations or exclusions; do not validate only Acceptance and Verification.
- Build an implementation trace map before approval:
  - forward trace: initiative context/original issue/ticket/intent -> story Purpose/Scope/Scenarios/Acceptance -> final Verification proof rows -> changed code/tests/config/runtime surfaces
  - backward trace: every changed file, symbol, helper, command, test, config, generated/runtime surface, and proof row -> Acceptance id -> in-scope story rationale or explicit exclusion
  - design trace when applicable: normative design source anchor -> visible element/state -> `required` or bounded `flexible` trace row -> Scenario -> Acceptance -> final proof row -> rendered artifact or reviewer observation
  Orphan changed surfaces, gold-plated behavior, or proof rows for unrequested behavior block approval unless the story records a safe justification.
- When an acceptance or proof row names an end-to-end boundary, verify the proof starts at that named boundary. A lower-level test with hand-built intermediate data does not satisfy a resolver/orchestration acceptance item unless the row explicitly permits that narrower proof.
- When an acceptance item names variants, modes, branches, fallback paths, error cases, or examples, treat each named case as a required proof obligation. A test or proof row that covers only one variant does not cover sibling variants unless the story explicitly excludes them with rationale.
- When `## Scenarios / Behavior Examples` is present, enforce the funnel `Scenario -> Acceptance -> Verification`: every normative `S<n>` scenario must use exactly one `Covers: A<n>`, and the linked acceptance/proof path must satisfy that scenario's concrete behavior. Orientation-only scenarios are not proof obligations, must not drive required implementation scope unless also present in Acceptance, and must not contradict the implemented behavior.
- When raw persisted, external, framework, or generated input crosses into stricter application assumptions, treat it as an `Input Boundary Shape Risk`: proof must start at the raw input boundary for every in-scope case, or the story must record an explicit exclusion / unknown with mitigation.
- Treat external or local technical docs as contract hints, not implementation proof. If a story claims an exact route, model family, auth mode, metadata label, or dispatch path, verify repo code or tests prove that exact behavior.
- Treat normative design sources as extraction inputs to the story contract, not as a free-form implementation checklist. Mapped `### Design Element Trace` rows are review claims. Also inspect normative design sources enough to catch obvious unmapped visible elements/states; classify those as planning-contract extraction gaps routed to `/openspec-story-plan-converge` or `/openspec-feedback`, not direct implementation failures unless the element is mapped in Acceptance/trace.
- If a story touches surfaces owned by dependency stories, inspect the relevant dependency proof rows and ensure prior accepted contracts still hold.
- If progress logs, review logs, or code structure reveal duplicated live owners for one behavior, include each owner in the review plan; do not approve a story that updates or proves only one side without an explicit exclusion.

## Multipass review mode

Before starting the implementation review, count the concrete items in the story's `## Acceptance` list. `## Acceptance` is the source of truth for this trigger.

Counting rules:
- Count top-level acceptance bullets or checklist items under `## Acceptance`.
- Count stable acceptance ids such as `A1`, `A2`, ... when present.
- Do not count prose paragraphs, examples, nested explanatory bullets, notes, or out-of-scope bullets.
- If `## Acceptance` is malformed or the concrete item count cannot be determined, record a `Gate Finding`, set `**Approval Gate**: FAIL`, and do not approve.

When `## Acceptance` has 6 or more concrete items, multipass review is required. Multipass is also required when the combined diff across all target repos exceeds 30 files or 1500 lines, even if acceptance items are fewer than 6.

Diff-size computation:
- Compute the combined diff per repo before deciding whether multipass is triggered. Prefer the story branch delta from the merge-base with the repo's default branch (`git -C <root> diff --numstat <base>...HEAD`) when reviewing a worktree on the story branch.
- If the implementation is recorded on a dirty main tree or the branch base cannot be identified, count the reviewable uncommitted delta with `git -C <root> diff --numstat` and `git -C <root> diff --cached --numstat`, then state that fallback in `Steps taken`.
- Sum unique changed file paths across target repos for the file threshold, and sum added plus deleted lines for the line threshold. Rename-only rows count as one file and zero changed lines unless the numstat row reports additions/deletions.
- If diff size cannot be computed credibly, record a `Gate Finding`; do not use uncertainty to avoid multipass.

Multipass planning:
1. Build a compact review plan with 2-8 focused passes.
2. Group passes by acceptance-area and activated-risk lens, not mechanically one pass per acceptance item.
3. Use the fewest genuinely independent passes needed for strong coverage. Merge candidate passes that would inspect the same changed-file cluster, root-cause family, invariant, or evidence surface.
4. Keep tests, regressions, and gap checks inside the pass that owns the subsystem risk unless they need a truly independent evidence path.
5. Map every acceptance item to at least one planned pass.
6. For acceptance items with named variants, modes, fallback paths, or failure cases, map every named case to at least one planned pass or record an explicit exclusion.
7. For every normative scenario with exactly one `Covers: A<n>`, map the scenario-relevant case to the pass that covers that acceptance id. If no pass covers the linked scenario behavior, add one or record a gate finding.
8. Each pass must have a clear title, acceptance items covered, risk focus, and expected evidence surface.

Focused pass execution:
- Use focused child agents in normal operation when the runtime provides them. Each child is read-only for code and coordination files; runtime-specific invocation details belong in runtime-specific fragments.
- A documented manual focused-pass substitute is allowed only when child-agent spawning fails, times out, or is unavailable. The substitute must record the pass title, substitution reason, files/symbols inspected, searches/direct reads used, findings, and explicit clean or inconclusive result.
- Child agents may use only their allowed read-only evidence tools such as direct file reads, `git`, and search. Treat any provided notebook entry as orientation only and verify it with direct reads/search against cited anchors before relying on it.
- External documentation may inform hypotheses only when specialized external knowledge is needed; repo code/tests/story artifacts still govern approval.

Focused pass return contract:
- Pass title and acceptance items covered.
- Scope reviewed: repos, files, symbols, callsites, and tests.
- Search/direct-read evidence used, including notebook entries verified through direct anchors or `not needed` with a short reason.
- External sources used, or `none`.
- Hypothesis Triage: compact bullets using `suspicious surface: <file/API/flow>; tentative issue: <possible failure>; next proof target: <source/test/proof to check>`. Include only candidate issue threads the pass actually inspected; prune weak candidates before promoting anything into `Findings`.
- Findings: every non-empty finding ends with `Sources: path:line`; use `- None.` when clean.
- Verification/proof notes: proof rows checked, tests inspected, commands rerun, or reason commands were not rerun.
- Evidence quality: `confirmed`, `inferred`, `unknown`, and/or `provisional` evidence used by the pass, with unknowns/provisional items called out.
- Result: `clean | findings | inconclusive`.
- Evidence gaps: use `- None.` when none.

Multipass synthesis:
- Synthesis is an assembly pass, not a new investigation pass.
- Treat focused-pass outputs as hypotheses, not authority. Before carrying any claim into the final review, verify that primary evidence in the current worktree or story artifacts supports the claim, not just that a cited `file:line` exists.
- Read the plan and all focused-pass outputs.
- Map every `## Acceptance` item, including every named variant/failure mode inside an item, to at least one completed focused-pass result or explicit exclusion.
- Map every `S<n> Covers: A<n>` normative scenario to the completed focused-pass result that proves the linked acceptance behavior. If implementation satisfies the acceptance wording generally but not the linked scenario case, record a `Gate Finding`.
- Dedupe repeated findings while preserving original `Sources: path:line` evidence.
- Classify accumulated findings into `Gate Findings`, `Product Assessment`, `Technical Assessment`, or `Initiative Contract Drift`.
- Produce a `### Strengths` section under both Assessments from positive observations in focused-pass outputs.
- Do not perform new broad code research, invent missing evidence, silently resolve conflicting pass results, or convert an inconclusive pass into approval.
- If any acceptance item or required named variant is uncovered, any focused pass is inconclusive, or focused-pass outputs conflict, record a `Gate Finding`; `**Approval Gate**` must be `FAIL` and `**Decision**` cannot be `APPROVE`.

## Hypothesis triage and detailed findings

Use a compact Chain-of-Draft-style hypothesis triage before finalizing review findings. This is visible review work, not hidden reasoning.

For single-pass review, include a `## Hypothesis Triage` section in the final output. For multipass review, require each focused pass to return Hypothesis Triage bullets, then synthesize only the useful surviving threads into the final `## Hypothesis Triage` section.

Hypothesis Triage bullets use this exact shape:

```md
- suspicious surface: <file/API/flow>; tentative issue: <possible failure>; next proof target: <source/test/proof to check>
```

Rules:
- Include only candidate issue threads actually inspected.
- Prune weak, duplicate, or disproven candidates before promoting findings.
- Do not treat triage bullets as final proof. Findings still require the detailed finding card and `Sources: path:line` contract below.
- Synthesis may summarize and dedupe triage from focused passes, but must not perform new broad investigation.

Every concrete issue under `Gate Findings`, `Product Assessment`, `Technical Assessment`, or `Initiative Contract Drift` must use this detailed finding card format in both the final review output and the `reviews.md` write-back:

```md
- <finding summary> Sources: `path:line`

  <details open>
  <summary><b>SEVERITY_LABEL</b> severity · <b>LIKELIHOOD_LABEL</b> likelihood</summary>

  **Why:** <simple operator-facing explanation of why the change is being requested>

  **Assumptions / Preconditions:** <required conditions, or `None.`>

  **Downgrade Factors:** <what would reduce confidence or impact, or `None.`>

  **Code Trail:** <grounded path from the cited evidence to the review conclusion>

  **Reproduction:** <brief reproduction narrative or simple text diagram>, or `Not applicable.`

  </details>
```

Severity labels must be one of: `Critical`, `High`, `Medium`, `Low`, `Info`.
Likelihood labels must be one of: `High`, `Medium`, `Low`, `Not Assessed`.
Keep `Why` in plain operator-facing language. Prefer `Not Assessed` over fake precision when evidence is insufficient.

## Review process

1. Use code search and direct reading to understand the story's implementation and impacted surfaces. Record the owner-discovery searches you performed (`Code surfaces searched`) including domain terms, callsites/routes, existing tests, duplicate owners, generated/config/runtime surfaces, and any areas intentionally not searched.
2. Use `git -C <project_root_map>[<basename>] status`, `git -C <project_root_map>[<basename>] diff`, and targeted file reads to inspect what was actually changed. When the story spans multiple repos, run status/diff per repo (iterating over `<project_root_map>` in sorted basename order) and group findings per-repo in the review write-back. Each `<basename>` resolves to either an implementer's worktree (most common) or the main tree at `<workspace_root>/projects/<basename>` (clean main-tree fallback case from the preflight).
3. Read all relevant story-spec sections and treat each section as a claim: Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, and Discovery Notes when present.
4. Read any existing entries in `<change_dir>/reviews.md` before deciding. If prior review runs requested changes or recorded blockers, explicitly verify whether each concern is resolved, still open, superseded by later story changes, or not assessable from current evidence.
5. Before approving implementation, verify the `Plan:` header field in `<story_file>` is `🟢 PLAN APPROVED`. If `Plan:` is `🟡 PLAN DRAFT`, `🟣 PLAN IN REVIEW`, `🟠 PLAN CHANGES REQUESTED`, or `⛔ PLAN BLOCKED`, the implementation cannot be approved; record a `request_changes` verdict with next action `/openspec-story-plan-converge <initiative-slug> <story-slug>`.
6. Check for `<change_dir>/blocked.md` — if this explicit blocker gate file exists, record a `blocked` verdict. Do not auto-resolve or remove the file.
7. Mine original intent only from explicit anchors: ticket/PR URLs, Jira keys, issue numbers, branch names, commit messages, `initiative.md` Story Candidates and External Resources, dependency workspace `story.md` files, PR bodies, or story prose. Use read-only commands such as `gh issue view`, `gh pr view`, `jira issue view`, `git log`, and `git show` when available and relevant. If an external source cannot be accessed, record the missing source and do not invent its content.
8. Build the implementation trace map and record whether forward/backward traceability is complete or has gaps. Every changed source/test/config/runtime surface and every proof row must map back to an acceptance id plus story scope, initiative context/original intent, or an explicit exclusion.
9. Classify material evidence as `confirmed`, `inferred`, `unknown`, or `provisional`. Unknown or provisional evidence that affects acceptance, route ownership, ticket intent, contract drift, or proof credibility blocks approval unless safely scoped out with a follow-up path.
10. Never speculate about code you haven't read
11. When `initiative.md` defines constraints relevant to the resolved story's owned surfaces and invariants, inspect those sections.
12. If the final implementation or final proof matrix clearly differs from the earlier planned proof path, consult `progress.md`'s `## Progress Timeline` and `## Session Handoff` to confirm the change was recorded and justified.
13. If sibling stories define shared interfaces, invariants, or proof surfaces this story touches, inspect those targeted stories rather than assuming the resolved `story.md` is complete.
14. If ticket intent, initiative context, story text, and live code point in different directions, name the conflict and route it: contract-changing findings go to `/openspec-story-plan-converge` or `/openspec-feedback`, stale initiative context goes to `/openspec-epic-plan`, and unimplemented in-scope story obligations go to `/openspec-story-resume`.
15. Run a Debt Friction check: ask whether implementation or review was made harder by unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure. Only record a `Debt Friction` finding when there is a story-local causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.
16. Run a risk-sensitive sanity pass for activated risk lenses. Use story text, diff, source inspection, and tests to identify material domains such as async/event-loop behavior, concurrency, process/resource lifecycle, platform/OS APIs, filesystem/network/subprocess I/O, permissions/security, persistence, retries/timeouts, generated artifacts, prompt/template fail-open behavior, external services, and naming-sensitive invariants. Review those domains by failure mode and existing repo idiom, not only by changed file.
17. Break the reviewed implementation into logical groups; explain the grouping briefly
18. Review each group sequentially
19. Prioritize:
   - correctness
   - regressions
   - product / acceptance drift from the requested outcome
   - design-source extraction gaps and rendered-surface proof gaps where relevant
   - initiative contract drift from `initiative.md` or sibling-story commitments
   - architectural consistency
   - duplication / missed reuse
   - status / progress drift from the story spec
   - branch-coverage drift from the planned proof surface
   - missing routing completeness across supported callsites
   - fail-open prompt regressions where relevant
   - red-first workflow drift or undocumented exceptions
   - missing tests
   - rollout / operational risks where relevant

## Critical checks

Before approving, run these grouped checks. Use the canonical approval gate in `## Review log write-back` for the exact pass/fail contract; this section organizes the investigation that feeds that gate.

### 1. Product and story contract

- Does the implementation satisfy the requested outcome, every acceptance id, every named variant/failure mode, and every normative `S<n> Covers: A<n>` scenario through its linked acceptance id?
- Do Purpose, Triggering Need, Scope, Out of Scope, Critical Files, Implementation Notes, Locked Decisions, Discovery Notes, and dependency/sibling-story obligations still hold as claims against the implementation?
- Are original issue/PR/Jira/card sources, `initiative.md`, and story text reconciled? If ticket, initiative context, story, and code point in different directions, the conflict must be named and routed instead of silently approved.
- Are normative design sources satisfied for every mapped `required` and bounded `flexible` row, with rendered-surface evidence for visibility, placement, navigation, copy, responsive behavior, and interaction state unless the story records a narrower proof boundary?
- Are obvious unmapped visible elements/states from normative design sources routed as planning-contract extraction gaps rather than silently ignored?

### 2. Implementation traceability and repo fit

- Can every changed file, helper, API, test, command, config/runtime surface, generated artifact, TAP row, and proof row be traced backward to an acceptance id and in-scope rationale? Orphan work blocks approval unless explicitly justified.
- Was owner discovery broad enough beyond changed files and listed Critical Files: domain owners, similar implementations, tests, routes/callsites, fixtures, CLI/API entrypoints, generated artifacts, config/runtime owners, deprecation paths, and reusable existing code?
- Do the changes respect module boundaries, existing idioms, sibling contracts, and initiative-wide architectural decisions?
- Are status/progress transitions accurate, and is any dirty target worktree either the implementation under review or an explicit blocker?

### 3. TAP and final proof alignment

- Does the story file record the focused red seam used, or an explicit written exception with the alternative proof path?
- Do actual tests and reviewer actions match `### Test Architecture Plan`: owning files/suites, boundaries, assertions/observability, fixture/data strategy, CI lanes, fallback decisions, and split/merge rationale? Any material drift must be logged and justified.
- Does the final Acceptance Proof Matrix match actual implementation and verification surfaces, with every row `final` before approval?
- Do proof rows start at the boundary they claim to prove, rather than bypassing orchestration/end-to-end paths with hand-built intermediate data unless explicitly narrowed?
- Are tests behavior-centered and caller-observable rather than only private helper calls, retry counts, sleeps, ordering, or implementation choreography unless those mechanics are contractual?
- Do final verification commands cover focused and broad TAP lanes sufficiently, or explain why commands were not rerun.

### 4. Branch, input, fail-open, and risk coverage

- For multiple supported surfaces, variants, modes, or orchestration branches, is every in-scope row from `Surface / Branch Proof Matrix` covered or explicitly excluded, including routing proof when multiple callsites are supported?
- For fallback/default/degraded/malformed/missing-data/error behavior, is that path directly proven? Success-path proof does not cover fallback behavior.
- For prompt/template/placeholder stories, do tests or reviewer actions prove no unresolved placeholders/raw tokens, enabled-path activation, and disabled/default baseline behavior?
- For `Input Boundary Shape Risk`, does final evidence start at each named raw input boundary and cover every in-scope shape case, or record an explicit exclusion/unknown with mitigation?
- Are activated risk lenses reviewed at their owning boundary: async/event-loop, concurrency, platform/OS APIs, external I/O, permissions/security, persistence, resource lifecycle, retries/timeouts, generated artifacts, prompt/template fail-open behavior, naming-sensitive invariants, and similar domains?
- For platform/process/filesystem/network/subprocess/resource-lifecycle work, are sibling failure modes handled or explicitly excluded: stale/not-found, permission/access denied, already complete, timeout/cancellation, unsupported platform, and partial failure?
- Do names, comments, tests, and locked terminology avoid overstating identity, ownership, lifecycle, durability, permission, locking, or safety guarantees?

### 5. Evidence quality, finding closure, and debt

- Were prior review findings and feedback fixes closed with disposition, fix proof, and regression/side-effect verification rather than prose acknowledgement only?
- Are evidence-quality categories explicit, with no unknown or provisional evidence affecting acceptance, route ownership, ticket intent, contract drift, or proof credibility?
- Was multipass review completed when triggered, with every acceptance item and named variant mapped to a focused-pass result or explicit exclusion?
- If any `Debt Friction` entry used `fix-now`, did cleanup stay within its `Scope Justification`, remain enabling for this story, and have verification? If not, request changes or split the debt into follow-up work.
- Are security, performance, scalability, packaging, runtime, rollout, and operational implications reviewed where material?

## Status transitions

Before transitioning to `✅ DONE`, check `progress.md`'s `## Current Claim` -> `- Worktrees:` for uncommitted changes. Review is read-only for source: do **not** run `git add`, `git commit`, or otherwise mutate the target repo from this skill. If any review-target worktree is dirty, approval is allowed only when the dirty state is the implementation being reviewed and the review log names the reviewed worktree/diff; otherwise request changes or block with a cleanup/explicit-worktree instruction. If the change workspace has no `progress.md` or no `## Current Claim` section (review-only session), skip.

You may update only the `Status:` header field in `story.md` and append to `reviews.md` as part of the review. Use this policy:

- if review starts on a story with `Status: 🔄 IN PROGRESS` but implementation is clearly ready for review, move it to `Status: 🟣 IN REVIEW`
- if review passes with no blocking findings AND the story does not use the optional GitHub PR stage, mark it `Status: ✅ DONE`
- if review passes with no blocking findings AND the story is expected to go through a GitHub PR review, leave it at `Status: 🟣 IN REVIEW` and tell the user to run `/openspec-story-pr <initiative-slug> <story-slug>` to transition to `Status: 🔵 IN PR`
- if a story was already marked `Status: ✅ DONE` as local-only completion and later needs a GitHub PR, `/openspec-story-pr <initiative-slug> <story-slug>` owns that late injection; review does not reopen it
- if review finds issues that require more implementation work, move it to `Status: 🔄 IN PROGRESS`
- if review cannot complete because of an external blocker, mark it `Status: ⛔ BLOCKED`
- if the story is currently `Status: 🔵 IN PR`, treat this as a pre-merge sanity review only; **do not transition the status from `Status: 🔵 IN PR` yourself**. Any merge-state change belongs to `/openspec-story-pr`. Record findings in `reviews.md` as normal.

## Review log write-back

Append a new entry to `<change_dir>/reviews.md`. `reviews.md` is a standalone artifact with append-only numbered entries using the same field schema as the existing ADD Review Log. If `reviews.md` does not exist, create it with a top-level `# Review Log` heading and append the first entry.

Each entry uses this schema:

```md
- <UTC ISO timestamp> Review run by fresh maintainer session
  - Decision: approve | request_changes | blocked | not_reviewable
  - Approval gate: pass | fail
  - Product verdict: approve | request_changes | reject | not_assessed
  - Technical verdict: approve | request_changes | reject | not_assessed
  - Multipass review: not_triggered | completed | incomplete
  - Prior review concerns: none | resolved | still_open | superseded | not_assessable
  - Plan lane at review time: <value or absent>
  - Initiative contract drift: none | present
  - Status transition: <from> -> <to>
  - Sections reviewed: Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, Discovery Notes
  - Original intent checked: <issues/PRs/Jira/tickets/initiative sources or none found/inaccessible>
  - Traceability: forward <complete|gaps>; backward <complete|gaps>
  - Design trace: complete|gaps|not applicable; rendered evidence: complete|gaps|not applicable
  - Code surfaces searched: <paths/patterns/entrypoints or none beyond changed files>
  - Risk lenses reviewed: <activated lenses and exclusions, or none material>
  - Finding closure: <disposition + fix proof + regression/side-effect check, or none>
  - Evidence quality: confirmed <short>; inferred <short|none>; unknown <short|none>; provisional <short|none>
  - Files reviewed: <paths>
  - Hypothesis triage:
    - suspicious surface: <file/API/flow>; tentative issue: <possible failure>; next proof target: <source/test/proof to check>
  - Key findings:
    - <finding summary> Sources: `<path:line>`

      <details open>
      <summary><b>SEVERITY_LABEL</b> severity · <b>LIKELIHOOD_LABEL</b> likelihood</summary>

      **Why:** <operator-facing reason>

      **Assumptions / Preconditions:** <required conditions, or `None.`>

      **Downgrade Factors:** <confidence/impact reducers, or `None.`>

      **Code Trail:** <grounded path from cited evidence to conclusion>

      **Reproduction:** <brief reproduction narrative, or `Not applicable.`>

      </details>
  - Debt Friction: none | <decision + short title>
  - Next action: <one concrete recommendation>
```

If a `# Review Log` heading does not exist, create it at the top of `reviews.md`. Append the new review entry below it.

Approval is not allowed if the proof contract is still unresolved. A story is only eligible for approval when:
- every acceptance id remains covered
- every named variant, mode, branch, fallback path, and failure case inside an acceptance id is covered or explicitly excluded
- every normative scenario linked with exactly one `Covers: A<n>` is satisfied through its linked acceptance id and final proof row
- every proof row is `final`
- the matrix matches the actual implementation and verification surfaces
- every named end-to-end proof starts at the claimed entry boundary, or the story explicitly narrows the proof row
- every required surface / variant / branch row is covered or explicitly excluded
- routing completeness is proven when multiple supported callsites or orchestration paths exist
- route, model-family, auth-mode, and metadata claims are proven by repo code/tests rather than documentation alone
- multipass review is either not triggered or completed with every acceptance item covered by a focused-pass result
- required fail-open checks are satisfied for prompt/template/placeholder-driven features
- required design trace rows are satisfied, with every mapped `required` row proven and every `flexible` row within its explicit bounds
- rendered-surface evidence exists for visibility, placement, navigation, copy, responsive, and interaction-state design obligations unless the story records an explicit exception or narrower proof boundary
- obvious unmapped visible elements/states from normative design sources have been routed as planning-contract gaps rather than silently ignored
- required input-boundary shape risk rows are covered by real-boundary evidence, explicitly excluded, or recorded as unknown with mitigation
- any apparent proof drift was logged when it happened
- the story file records either the focused red seam that was used or an explicit written exception with the alternative proof path
- any relevant initiative context or sibling-story obligation touched by this story remains satisfied, or the intentional drift is explicitly recorded and reflected in the review verdict
- forward and backward traceability are complete, or every traceability gap is safely scoped out and does not affect acceptance, proof, ownership, or contract fidelity
- evidence quality is explicit, with no unknown or provisional evidence affecting acceptance, route ownership, ticket intent, contract drift, or proof credibility
- activated risk lenses are reviewed at their owning boundary, or explicitly excluded with rationale
- prior findings and feedback fixes have disposition, fix proof, and regression/side-effect verification

## Classification rules

- The Product and Technical verdicts are independent and may disagree. Either may also be `NOT ASSESSED` when the reviewer lacks sufficient evidence for that dimension. Out-of-scope issues may still downgrade a verdict when materially important.
- `Gate Findings` contains readiness, proof-contract, state-transition, and red-first/precondition failures. Any unresolved gate finding means `**Approval Gate**: FAIL` and `**Decision**` cannot be `APPROVE`.
- `Product Assessment` evaluates requested outcome, acceptance behavior, user-visible correctness, and initiative-level obligations explicitly owned by this story.
- `Technical Assessment` evaluates correctness, regressions, architecture, reuse, tests, security, performance, maintainability, and rollout safety.
- If the same underlying issue qualifies for both `Product Assessment` and `Technical Assessment`, report the canonical finding only once. Prefer `Product Assessment` when the issue affects requested behavior, acceptance, user-visible correctness, operator value, or the approval verdict. Use `Technical Assessment` for distinct implementation concerns that are not already captured by the product finding.
- `In Scope Issues` are issues the resolved story directly owns or must satisfy to pass.
- `Out of Scope Issues` are adjacent problems, follow-on work, or broader initiative concerns worth flagging but not required for this story to pass.
- `Initiative Contract Drift` (was `Epic Contract Drift` in the legacy epic flow) is only for mismatches between this story and initiative-level commitments in `initiative.md`, dependencies, or relevant sibling stories. Do not use it for generic cleanup or unrelated debt.
- Contract-changing feedback discovered during implementation review must be routed explicitly. If the implementation seems reasonable but the story/initiative context is stale, request contract repair through `/openspec-story-plan-converge`, `/openspec-feedback`, or `/openspec-epic-plan` rather than approving a hidden contract change. If the story contract is current and code is wrong, route to `/openspec-story-resume`.
- Order findings in every issue list by severity, include file references, and use `- None.` when a list is empty.

## Output format

Start with gate findings and issue lists, ordered by severity, with file references.

```markdown
**Decision**: [APPROVE | REQUEST CHANGES | BLOCKED | NOT REVIEWABLE]
**Reviewed Story**: <story-slug> / <change_dir>
**Status Transition**: [<old> -> <new>]
**Grouping**: [brief grouping logic]
**Initiative Context Used**: [initiative.md, dependency stories, sibling stories reviewed, handoff/progress sections]
**Original Intent Used**: [issues/PRs/Jira/tickets/initiative sources inspected, none found, or inaccessible]
**Prior Review Log Check**: [none, or prior concerns checked with resolved/still open/superseded/not assessable status]
**Traceability**: [forward complete/gaps; backward complete/gaps]
**Design Trace**: [complete | gaps | not applicable; rendered evidence complete | gaps | not applicable]
**Code Surfaces Searched**: [paths/patterns/entrypoints/domain terms searched]
**Risk Lenses**: [activated lenses reviewed, proof/exclusion gaps, or none material]
**Finding Closure**: [dispositions, fix proof, regression/side-effect check, or none]
**Evidence Quality**: [confirmed <short>; inferred <short|none>; unknown <short|none>; provisional <short|none>]
**Approval Gate**: [PASS | FAIL]

### Steps taken
- [1 line per major inspection action]

## Multipass Review
- Triggered: yes | no
- Acceptance count: <count from ## Acceptance>
- Plan surfaces: <focused pass titles, or `not triggered`>
- Focused-pass results: <pass title -> clean | findings | inconclusive, or `not triggered`>
- Manual substitutes: <none, or pass title + reason>
- Uncovered acceptance items: <none, or A ids / bullet summaries>
- Conflicts / evidence gaps: <none, or blocking gap summary>

## Hypothesis Triage
- suspicious surface: <file/API/flow>; tentative issue: <possible failure>; next proof target: <source/test/proof to check>
- None.

## Gate Findings
- <finding summary> Sources: `path:line`
- None.

## Product Assessment
**Verdict**: [APPROVE | REQUEST CHANGES | REJECT | NOT ASSESSED]

### Strengths
- <finding summary> Sources: `path:line`
- None.

### In Scope Issues
- <finding summary> Sources: `path:line`
- None.

### Out of Scope Issues
- <finding summary> Sources: `path:line`
- None.

## Technical Assessment
**Verdict**: [APPROVE | REQUEST CHANGES | REJECT | NOT ASSESSED]

### Strengths
- <finding summary> Sources: `path:line`
- None.

### In Scope Issues
- <finding summary> Sources: `path:line`
- None.

### Out of Scope Issues
- <finding summary> Sources: `path:line`
- None.

### Reusability
- <finding summary> Sources: `path:line`
- None.

## Initiative Contract Drift
- <finding summary> Sources: `path:line`
- None.

## Research Events
- reused: <notebook entries verified by direct reads/search with anchors, or none>
- notebook-refresh: <provided entries not verified or needed facts absent, with anchors, or none>
- added: <new sourced research facts with anchors, or none>

## Summary
- [2-4 short bullets]

**Next Action**
- [single concrete next step]
```

If there are no findings in a section, say that explicitly with `- None.`.