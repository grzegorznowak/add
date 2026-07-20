---
name: openspec-story-review
description: Review one implemented OpenSpec change workspace from a fresh, oblivious session against its OpenSpec artifacts and live repo evidence. Read-only for code; writes only review coordination artifacts in the change workspace and optionally supplemental notebook findings.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug> [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Edit Write Grep Glob Task Bash
---

# OpenSpec Story Review

Review one story implementation from a fresh, oblivious session against its OpenSpec artifacts and live repo evidence. Write the completed verdict durably to `story.md` and `progress.md → ## Implementation Review Receipt`; notebook persistence is optional and supplemental.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug> [WORKTREE="<basename>=<path>"]...`. Initiative and story slugs must match the canonical regex `^[a-z0-9]+(?:-[a-z0-9]+)*$`; reject non-canonical positional slugs before path resolution. Both positional args are recommended; if either is omitted, this command uses the explicit menu fallback in `## Resolution`. `WORKTREE=` is an optional, repeatable opt-in that overrides the preflight's worktree lookup per target repo. Two forms are accepted: `WORKTREE="<basename>=<path>"` (multi form, repeatable, preferred) and legacy `WORKTREE="<path>"` (valid only when the story has exactly one target repo; the path is applied to that sole repo). Mixing the two forms in a single invocation is an error. When `WORKTREE=` is absent, the preflight reads any `- Worktrees:` list from `progress.md`'s `## Current Claim`, falling back to a legacy `- Worktree:` singular bullet for claims predating the multi-worktree format.

## Important

You may write only review-owned coordination artifacts inside `<change_dir>`: the top-level `Status:` header in `story.md`, `progress.md → ## Implementation Review Receipt`, exactly one concise `## Progress Timeline` verdict-transition entry, and `blocked.md` for a completed BLOCKED verdict. You may optionally write a supplemental review notebook page. **Never** modify product source code or target worktrees; review is read-only for implementation.

## Safety guardrails

- Do not modify source code — review is read-only.
- Do not run destructive git operations (push, `reset --hard`, force commands, branch deletion).
- Never write outside `<openspec_root>/openspec/changes/<story-slug>/`, an optional review notebook page, or `/tmp`; do not edit target worktrees.
- Test execution is permitted only to verify the story's proof matrix (not for broad exploration), even when normal test tooling writes caches or artifacts.
- GitHub/Jira access is read-only for intent mining. Use view-only commands such as `gh issue view`, `gh pr view`, and `jira issue view`; do not use generic API commands that can issue mutating requests.

## Why operator-selected targets

`/openspec-story-review` never auto-infers the initiative or the story. The operator chooses — either by passing `<initiative-slug> <story-slug>` as arguments or by picking from the menu this skill shows when either is absent. The menu lists only legally bound candidates at `🟣 IN REVIEW`. For the narrow missing-`Initiative:`/zero-candidate legacy exception, however, only both positional slugs supplied together in the invocation count as an operator-explicit pair; selecting an initiative from a menu is not enough to admit unrelated zero-reference stories.

The reasoning: review must come from a fresh, oblivious arbitration perspective. The same session that just implemented or converged a story will rationalize its own work, not scrutinize it. Auto-inferring "the current story" would silently pick whatever the session was last working on — exactly the coupling we want to avoid.

If this command is being considered from the same session that just wrote or converged the implementation, stop and open a completely fresh session first. Do not carry parent/converger notebook entries, implementation summaries, operational notes, or prior chat context into review. Do not accept parent/converger notebook references under any alias or import implementation-convergence research/ops pages. The menu still makes operator-explicit selection possible, but the friction is intentional and any future change that adds silent auto-inference or implementation-context handoff here must be rejected.

## Resolution

1. Parse `$ARGUMENTS`. Validate each supplied or menu-selected initiative/story slug against `^[a-z0-9]+(?:-[a-z0-9]+)*$` before interpolating it into a path; reject malformed values. Record `<explicit_pair>` as true only when both positional slugs were supplied in this invocation before any menu fallback.
   - `<initiative-slug>`: optional, the first positional token (initiative slug)
   - `<story-slug>`: optional, the second positional token (story slug / change workspace name)
   - The raw list of `WORKTREE="<value>"` occurrences (parsed in `## Worktree preflight` step 3 into `<explicit_worktree_map>` and/or `<legacy_worktree>`)

   Set `<workspace_root>` = `<cwd>` and `<openspec_root>` = `<workspace_root>`. `<workspace_root>` is the launch checkout/root-repo discovery base and is never re-anchored. `<openspec_root>` is the transient artifact anchor for `openspec/...` and may reroot in memory. There is no persisted `OpenSpec root:` field.
2. **OpenSpec-root preflight (only when `<initiative-slug>` and `<story-slug>` are known):** run this before lifecycle/readiness checks and before reading or writing coordination artifacts.
   - Inspect all explicit `WORKTREE=` values in either accepted form first. A root candidate qualifies only when it is a git checkout containing both `openspec/initiatives/<initiative-slug>/initiative.md` and `openspec/changes/<story-slug>/story.md`. If exactly one explicit candidate qualifies, set `<openspec_root>=<path>` immediately and route all coordination reads/writes there. If multiple explicit candidates qualify, ask which checkout is active and halt; never guess. Explicit target-repo overrides that lack both artifacts remain normal worktree preflight inputs.
   - Only when no explicit candidate qualifies, inspect registered root-repo worktrees other than `<workspace_root>` from `git -C <workspace_root> worktree list --porcelain` on branch `refs/heads/<initiative-slug>/<story-slug>`. If exactly one branch worktree qualifies, set `<openspec_root>` to it even when launch contains matching but possibly stale artifacts; that unique branch worktree outranks launch. If multiple branch worktrees qualify, ask which checkout is active and halt; never guess.
   - Only when neither an explicit nor branch-worktree candidate qualifies, fall back to `<workspace_root>` and require both artifacts there.
   - If either positional slug is omitted, skip this full preflight until both are known, use `<workspace_root>` to list menu choices, then run the full preflight immediately after the operator selects the missing value(s). Do not invent a story from a worktree scan.
3. **INITIATIVE resolution (menu fallback):**
   - If `<initiative-slug>` was passed, resolve `<openspec_root>/openspec/initiatives/<initiative-slug>/initiative.md`.
   - If `<initiative-slug>` was not passed, scan active change workspaces with `story.md` at `Status: 🟣 IN REVIEW` and resolve each durable initiative binding: a canonical top-level `Initiative:` header wins; otherwise only a unique exact `## Story Candidates` association binds the legacy workspace. Group those bound workspaces by existing initiative and print `<slug> — <N bound stories IN REVIEW, last-touched YYYY-MM-DD>`. Exclude malformed, conflicting, multiply-associated, and zero-reference legacy workspaces from this initiative menu because no explicit initiative has yet accepted them. If the filtered list is empty, ask whether the review-ready story's OpenSpec artifacts were moved to a root repo worktree; recommend rerunning from that worktree if so, then abort with: `no initiatives have bound stories ready for review in this checkout (nothing at 🟣 IN REVIEW)`. Otherwise ask the operator to pick (number or slug). If `<story-slug>` was already provided, rerun the OpenSpec-root preflight from step 2 after the initiative pick and recompute all artifact paths before proceeding.
4. **STORY resolution (menu fallback):**
   - If `<story-slug>` was passed, continue to resolution step 5.
   - If `<story-slug>` was not passed, scan all active change workspaces with `story.md` at `Status: 🟣 IN REVIEW` and apply the binding resolver for the resolved initiative. Enumerate only workspaces explicitly bound to it or uniquely candidate-associated with it. A passed or menu-selected initiative alone is not an explicit pair, so exclude zero-reference legacy workspaces from this menu. Never list a workspace bound or candidate-associated with another initiative. For each, print: `<story-slug> — <Status> — <Deliverable summary>`. If the filtered list is empty, abort with: `no stories at 🟣 IN REVIEW associated with initiative <slug>`. Otherwise ask the operator to pick (number or slug).
   - After any menu selection that fills a missing initiative or story slug, rerun the OpenSpec-root preflight from step 2 for the resolved slugs and recompute all artifact paths from `<openspec_root>` before proceeding.
5. Set `<initiative_dir>` = `<openspec_root>/openspec/initiatives/<initiative-slug>`.
   - If `<initiative_dir>` does not exist, ask whether the story was claimed into a root repo worktree and the OpenSpec artifacts were moved there. Give the singular operator action to locate/select the checkout containing both artifacts (or pass an explicit valid root `WORKTREE="<basename>=<path>"`) and verify review prerequisites there. Recommend rerunning `/openspec-story-review <initiative-slug> <story-slug>` only after that verification confirms review has not yet run against the current ready evidence. Abort with: `initiative not found in this checkout: openspec/initiatives/<initiative-slug>/`.
6. Set `<initiative_file>` = `<initiative_dir>/initiative.md`.
   - If `<initiative_file>` does not exist, ask the same root-worktree relocation question and abort with the exact missing path.
7. Set `<change_dir>` = `<openspec_root>/openspec/changes/<story-slug>`.
   - If `<change_dir>` does not exist, check `<openspec_root>/openspec/changes/archive/<story-slug>/`.
   - If archived, abort with: `story is archived under openspec/changes/archive/; move it back to openspec/changes/ first`.
   - If missing in both locations, ask whether the story was moved to a root repo worktree during claim. If a checkout containing it is identified, give the singular operator action to rerun from that checkout or with an explicit valid root `WORKTREE="<basename>=<path>"`. If relocation is ruled out and the workspace is genuinely absent, route singularly to `/openspec-story-plan INITIATIVE=<initiative-slug>`. Abort with: `change workspace not found in this checkout: openspec/changes/<story-slug>/`.
8. Set `<story_file>` = `<change_dir>/story.md`.
   - If `<story_file>` does not exist, ask the same root-worktree relocation question. If relocation is ruled out, route singularly to `/openspec-story-plan-resume <initiative-slug> <story-slug>` to repair the incomplete workspace. Abort with the exact missing path.
9. Validate the durable initiative binding before lifecycle checks or writes:
   - Inventory the top-level header region before the first `## ` heading for every unindented `Initiative` field or Initiative-like field line. Exactly one present header is valid only when the whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`. Duplicate headers, an empty value, whitespace-before-colon variants, non-canonical values, or any other malformed Initiative-like field are hard conflicts: halt without changing status, progress, blocked.md, or notebook and report every offending line. Never reinterpret malformed input as the legacy no-header case.
   - When exactly one valid `Initiative:` header is present, require its value to equal `<initiative-slug>`; a mismatch is a hard conflict and reports both values.
   - Only zero Initiative or Initiative-like header lines is a legacy story. For that case, scan active `<openspec_root>/openspec/initiatives/*/initiative.md` files for `## Story Candidates` references to the exact story slug. If exactly one initiative references it and it equals `<initiative-slug>`, accept that unique exact candidate association. If no initiative references it, accept only when `<explicit_pair>` is true; emit a compatibility warning and do not backfill the header. An initiative selected from a menu or supplied without an explicitly paired story is not enough and requires exactly one candidate association. Any reference by another initiative, including multiple references, is conflicting evidence: halt and never guess.
10. The top-level `Status:` header in `<story_file>` is the sole authoritative implementation status. There is no `MASTER.md` and no alternate `## Status` authority. If the top-level header is missing, duplicated, conflicting, or malformed, abort to planning repair without write-back.
11. The `Plan:` header field in `<story_file>` is the authoritative planning lane. Check that it is `🟢 PLAN APPROVED` before approving implementation (see `## Review readiness check`).

## Read first

1. the main repo `AGENTS.md` for the repo the implementation touches
2. `<initiative_dir>/initiative.md` — for Goal/Context, Story Candidates, Decisions & Constraints, External Resources, and Feedback-Derived Story Candidates / Decisions context
3. the resolved `<story_file>` — every section (Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, Discovery Notes)
4. `<change_dir>/proposal.md` — for Goal/Context and Decisions & Constraints
5. `<change_dir>/design.md` — for technical design context, architecture decisions, and implementation strategy
6. `<change_dir>/tasks.md` — for task breakdown and implementation plan; verify tasks.md checkbox state matches the claimed implementation progress
7. delta spec files under `<change_dir>/specs/` — for spec-level behavioral obligations
8. `<change_dir>/progress.md` — read `## Implementation Review Receipt` first for prior completed verdict/finding continuity, then Progress Timeline, Session Handoff, Current Claim (worktree bindings and main-tree targets), and PR State
9. Optional prior notebook entry `openspec-review-<initiative_slug>-<story_slug>` if it exists — supplemental sourced orientation only after durable artifacts; it cannot override or replace the receipt
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
5. For every completed verdict, update the top-level `Status:` header and write the compact durable `progress.md → ## Implementation Review Receipt`; optionally persist supplemental findings to notebook page `openspec-review-<initiative_slug>-<story_slug>`.

## Review readiness check

After confirming entry `Status: 🟣 IN REVIEW`, parse this literal top-level shape:

```yaml
Review Focus: |
  <optional reviewer guidance on indented lines>
```

`Review Focus: |` is exactly one top-level field. Its content is the immediately following indented lines; the next top-level header terminates the block. No indented non-whitespace content means the block is blank. Malformed, duplicate, or conflicting Review Focus forms fail closed. Treat more than 1,000 whitespace-delimited units as over budget and fail closed rather than silently truncating guidance. Keep nonblank Review Focus guidance roughly 500–1,000 tokens. This is a ceiling range, not a required minimum.

If the Review Focus block is blank, perform a full review.
If it is nonblank, a focused pass is allowed: read the actual content and inspect the focused surface and evidence. Resolve concrete paths, symbols, behaviors, risks, tests, and proof named by the guidance against live artifacts; do not merely repeat the focus text in the verdict. Always perform the readiness/prerequisite gates, inventory the complete diff and acceptance/proof map, inspect the actual implementation and tests for the focused surface, and follow directly connected callsites or invariants needed to judge it. Record which surfaces were intentionally not inspected.

Widen the focused pass to a full review whenever baseline, scope, or risk is unclear. Also widen when the guidance cannot be resolved to live evidence, the diff escapes the claimed focus, an acceptance or proof dependency crosses the focused boundary, a material risk lens points outside it, or focused evidence is inconclusive. Review Focus is guidance, not an inspection boundary: inspect outside it whenever needed, and report any defect encountered there.

During review, `Review Focus: |` is read-only: review reads it but does not write it.
Outside `🟣 IN REVIEW`, `Review Focus: |` is inert. A permitted review of an existing `✅ DONE` story therefore uses full-review scope rather than stale focus from an earlier handoff.

Before choosing and executing the review scope:
- inspect the `Status:` header in `story.md`
- if `Status:` is neither `🟣 IN REVIEW` nor `✅ DONE`, treat the story as not reviewable from this command. In particular, `🔄 IN PROGRESS` must reach `🟣 IN REVIEW` through implementation ownership before review starts; do not normalize it into review from here.
- inspect the `Plan:` header in `story.md`
- inspect `<change_dir>/progress.md` for every `## Implementation Review Receipt` heading, plus `## Current Claim`, `## Progress Timeline`, `## Session Handoff`, and `## PR State`
- one well-formed receipt is the current record unless traceable newer feedback/resume/unblock evidence makes it historical. Duplicate or malformed receipt sections are non-authoritative reconciliation inputs: do not choose a latest one, but do not reject the story permanently. Carry every parseable prior finding into a fresh substantive review, then normalize all review-owned receipt sections to exactly one current receipt after the verdict using the ordered write protocol below
- if entry Status is already `✅ DONE`, a bound story must have exactly one well-formed current receipt with every required field exactly once, `Decision: APPROVE`, `Approval gate: PASS`, and a transition ending in `✅ DONE`. Do not recompute review identity as lifecycle authority; it is story-scoped delivery evidence for PR. A missing, malformed, duplicate, or non-approving bound-story receipt requires fresh substantive review to reconcile it, not a blind backfill or permanent rejection. Only an unbound pre-v3 DONE story with zero Initiative headers and zero receipt sections gets bounded legacy compatibility: warn and do not rerun review merely to create a receipt
- inspect `<change_dir>/blocked.md` — if this file exists before review begins, the story is explicitly blocked; abort as `NOT REVIEWABLE` without rewriting it or creating a completed-verdict receipt
- apply the complete `### Prerequisite qualification` rule below to every dependency; Status DONE alone is not sufficient
- inspect every relevant story-spec section as a claim, not only `## Acceptance` and `## Verification`: `## Purpose`, `## Actors`, `## Triggering Need`, `## Expected Prerequisites`, `## Scope`, `## Out of Scope`, `## Scenarios / Behavior Examples`, `## Acceptance`, `## Verification`, `## Critical Files`, `## Implementation Notes`, `## Locked Decisions`, and `## Discovery Notes` when present
- inspect `<initiative_file>` for sections that define initiative-wide invariants or shared obligations for this story
- inspect original issue/PR/Jira/card intent only when explicitly linked or keyed; if unavailable, weak, or contradictory, record that instead of inventing linkage

### Prerequisite qualification

Apply this identical gate to every canonical list bullet in `story.md → ## Expected Prerequisites` before substantive review:

1. Require the dependency slug to match `^[a-z0-9]+(?:-[a-z0-9]+)*$`; malformed values are unsatisfied and must not be interpolated into paths.
2. Resolve active `<openspec_root>/openspec/changes/<prerequisite-slug>/story.md` first. The active copy is authoritative whenever present. Only when absent, fall back to `<openspec_root>/openspec/changes/archive/<prerequisite-slug>/story.md`; never let archived DONE override an active copy.
3. In the resolved prerequisite directory require exactly one unambiguous top-level line `Status: ✅ DONE`. Missing, duplicate, malformed, or non-DONE Status is unsatisfied. A sibling `blocked.md` makes the prerequisite contradictory and unsatisfied in active or archive, regardless of DONE or receipt evidence.
4. Inventory the prerequisite's top-level header region for Initiative-like lines by the Resolution step 9 rule. Duplicate or malformed Initiative-like fields are contradictory and unsatisfied, never legacy. Exactly one valid canonical `Initiative:` header makes this a bound modern prerequisite.
5. A bound modern prerequisite must have `progress.md` with exactly one `## Implementation Review Receipt` heading and one current body. Every required field (`Reviewed at`, `Decision`, `Approval gate`, `Status transition`, `Evidence reviewed`, `Identity method`, `Identity digest`, `Identity bases`, `Identity paths`, `Findings`, `Proof`, and `Next owner`) occurs exactly once; require APPROVE/PASS and a transition ending in `✅ DONE`. Missing, duplicate, malformed, or non-approving receipt evidence is unsatisfied. After slug resolution and modern/legacy classification, prerequisite satisfaction uses only authoritative Status, `blocked.md`, and this modern receipt verdict; never recompute or freshness-check the story-scoped review identity against mutable repository state.
6. Zero Initiative or Initiative-like header lines is unbound legacy input. Any present receipt must pass the same single-current APPROVE/PASS verdict checks. Only an unbound pre-v3 prerequisite with DONE, no `blocked.md`, zero Initiative headers, and zero receipt sections may satisfy without a receipt; emit a compatibility warning and never synthesize/backfill one.
7. Missing active and archived story files, or any failed gate above, aborts as `NOT REVIEWABLE` without coordination writes and names the exact prerequisite owner/action. An absent or empty prerequisites section passes automatically.

If the story is clearly not reviewable yet, abort fast with a concise reason. Examples:
- story `Status:` is still `⬜ TODO` and there is no implementation / handoff evidence
- story `Status:` is `🔄 IN PROGRESS`; implementation readiness still belongs to implementation ownership, not review
- story is blocked by an unmet dependency (`blocked.md` exists or `## Expected Prerequisites` lists an unsatisfied dependency) and the code cannot be sensibly judged
- no credible mapping from the story spec to any code or tests yet
- any acceptance id has no proof row, or any proof row is still `provisional`
- `Plan:` is not `🟢 PLAN APPROVED` (the implementation cannot be approved without plan approval). If authoritative entry Status is IN REVIEW, do not abort solely for this drift: complete the fresh review, record a non-approve verdict, and route from the final status written by that verdict. If the story is already `Status: ✅ DONE`, do not recommend a planning command that rejects DONE; abort with only `Operator action: investigate and reconcile the contradictory durable Status: ✅ DONE and Plan: <value> state before delivery or archive.` Do not invent a lifecycle owner. For other entry statuses, abort as not reviewable with the state-correct singular or planning route.

If you must ABORT:
- Output using the output format below.
- An abort/`NOT REVIEWABLE` outcome is not a completed verdict: leave the top-level Status unchanged and do not create or update `progress.md → ## Implementation Review Receipt`. This preserves legacy DONE workspaces and prevents retroactive receipts.
- Set **Decision** to `NOT REVIEWABLE`.
- Set **Approval Gate** to `FAIL`.
- Include a Gate Finding explaining why.
- Keep all other sections present using `- None.`
- Name the exact missing evidence/contract issue and route to the owner that can repair it; do not default back to this review command merely because authoritative Status remains `🟣 IN REVIEW`:
  - implementation, test, handoff, proof-row, proof-matrix, or implementation-mapping incompleteness -> singular `/openspec-story-resume <initiative-slug> <story-slug>`;
  - missing anchors or incomplete/non-reviewable planning scaffold -> singular `/openspec-story-plan-resume <initiative-slug> <story-slug>`, or `/openspec-story-plan INITIATIVE=<initiative-slug>` when the change workspace is absent;
  - a contract deficiency in a complete/reviewable planning scaffold -> the planning wrapper plus state-correct Non-looped plan-resume/review choice only when `/openspec-story-plan-converge` can actually orchestrate that current Plan/log lane; otherwise singular plan-resume;
  - unresolved external evidence that neither implementation nor planning can produce -> one concrete operator action to obtain, attach, or explicitly resolve that evidence.
- State explicitly: `Run a completely fresh, oblivious /openspec-story-review only after the named repair is complete and review prerequisites are satisfied.` This is a future-after-repair caveat, not the value on `Suggested next action:`.
- A direct fresh-review recommendation is valid only when review has not yet run against the current evidence and all prerequisites are already satisfied.

## Worktree preflight

After reading `progress.md`'s `## Current Claim`, build `<project_root_map>` from what the claim recorded plus any explicit overrides. This command **never creates** a worktree; it only reuses what the implementer recorded or what the operator passed explicitly.

**Invariant**: `<workspace_root>` = `<cwd>`, always, and remains the root-repo worktree discovery base. `<openspec_root>` is the transient artifact anchor resolved in `## Resolution`; all reads/writes under `openspec/...` anchor at `<openspec_root>`, not necessarily `<workspace_root>`. The `Status:` header write-back to `story.md` anchors at `<openspec_root>/openspec/changes/<story-slug>/`. Review remains read-only for code and never creates worktrees.

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
   - For every basename in the union of `<recorded_worktree_map>` keys, `<explicit_worktree_map>` keys, and `<main_tree_targets>`, resolve the repo to `<workspace_root>/projects/<basename>` if `<workspace_root>/projects/<basename>/.git` exists, or to `<workspace_root>` if `<basename>` matches `basename(<workspace_root>)` AND `<workspace_root>` is itself a git repo. For basenames that have a recorded or explicit worktree path, also accept the basename as a root-repo alias when that effective path resolves to `<openspec_root>` or `<workspace_root>` and that root is itself a git repo; add the resolved root repo to `<target_repos>` for that alias. Add each resolved repo to `<target_repos>`. If any recorded/explicit/main-tree basename cannot be resolved by repo location or this root-alias rule, abort with "claimed target `<basename>` cannot be matched to any repo on disk".
   - If `<target_repos>` is still empty, fall back to parsing `story.md`'s `## Scope` section: parse for `projects/[A-Za-z0-9_-]+/` tokens, intersect with real `<workspace_root>/projects/<name>/.git` repos, additionally include `<openspec_root>` or `<workspace_root>` when that root is itself a git repo and is in scope.

   If `<legacy_worktree>` is set (from step 3), it is now applied: `<explicit_worktree_map>[basename(<sole_target_repo>)]` = `<legacy_worktree>` if `<target_repos>` has exactly one element, otherwise abort with "`WORKTREE=\"<path>\"` requires exactly one target repo; found N (basenames: ...). Pass `WORKTREE=\"<basename>=<path>\"` form to specify which repo".

6. **Build `<project_root_map>` from recorded + explicit entries**. Initialize empty. For each `<basename>` in the union of `<recorded_worktree_map>` keys and `<explicit_worktree_map>` keys:
   - Effective path = `<explicit_worktree_map>[<basename>]` if present (explicit wins for the overridden basename only), else `<recorded_worktree_map>[<basename>]`.
   - Resolve `<target_repo>` for `<basename>`: `<workspace_root>/projects/<basename>` if `<basename>` resolves to a sub-repo, else `<workspace_root>` if it matches `basename(<workspace_root>)`, else `<openspec_root>` if it matches `basename(<openspec_root>)`. If neither matches but the effective path resolves to `<openspec_root>` or `<workspace_root>` and that root is itself a git repo, treat `<basename>` as a root-repo alias for that checkout and set `<target_repo>` to the resolved root. If none of those rules resolves, abort with "claimed worktree for `<basename>` cannot be matched to any repo on disk".
   - Verify the effective path exists on disk AND appears in `git -C <target_repo> worktree list --porcelain`.
   - Verify the worktree's HEAD is on branch `<initiative-slug>/<story-slug>` via `git -C <effective path> rev-parse --abbrev-ref HEAD`. Tolerate a detached HEAD with a warning ("worktree for `<basename>` is in detached HEAD state — review will run against the checked-out commit").
   - On any verification failure: abort with "worktree for `<basename>` is missing, unregistered, or on the wrong branch: <verbatim detail>. Clean the main tree and retry, ask the implementer to `/openspec-story-resume` (which recreates stale worktrees), or pass `WORKTREE=\"<basename>=<path>\"` explicitly". **Never create a worktree in review.**
   - On success: `<project_root_map>[<basename>]` = effective path, and mark `<target_repo>` as consumed by this worktree entry. Root-repo alias keys are consumed/resolved under their recorded or explicit basename; do not add a duplicate `basename(<workspace_root>)` entry solely because the key differs from the current worktree directory basename.

7. **Handle target repos not in any worktree map**. For each `<target_repo>` from step 5 whose repo path is NOT marked consumed by a worktree entry:
   - `<project_root_map>[<basename>]` = `<target_repo>` (main tree).
   - If `<basename>` is in `<main_tree_targets>`: the implementer recorded that this repo was written to directly on main. If the main tree is dirty, emit a note: "reviewing `<basename>` on main tree (recorded as a main-tree target by the implementer)". If clean, no note needed. Either way, review proceeds.
   - Else if `<main_tree_targets>` is empty (legacy claim predating this bullet): fall back to accepting the main tree regardless of dirtiness. If dirty, emit a note: "reviewing `<basename>` on dirty main tree (no `Main-tree targets:` bullet in claim — assuming implementation was done directly on main)". Review proceeds.
   - Else (`<main_tree_targets>` is non-empty but does NOT include `<basename>`): this repo was not declared as a main-tree target and has no recorded worktree. If clean, proceed silently. If dirty, warn: "`<basename>` is dirty and was not recorded as a main-tree target or worktree — the dirty state may include unrelated changes. Review proceeds but findings should be checked carefully."

8. **Done**. `<project_root_map>` is set. All downstream resolution uses these rules:
   - `<initiative_file>`, `<story_file>`, `progress.md`, `blocked.md`, and anything under `openspec/...` → read/write at `<openspec_root>/openspec/...`. The review verdict write-back to the `Status:` header in `story.md` lands at this anchor.
   - Code at `projects/<name>/foo/bar` → if `<project_root_map>` has `<name>`, route to `<project_root_map>[<name>]/foo/bar`; else route to `<workspace_root>/projects/<name>/foo/bar`.
   - Code in the root repo outside `openspec/...` and outside `projects/<name>/...` → if `<project_root_map>` has `basename(<openspec_root>)` or `basename(<workspace_root>)`, route the same relative path to that mapped root; else if a consumed root-repo alias key exists in `<project_root_map>` and its value resolves to `<openspec_root>` or `<workspace_root>`, route through that mapped root; else use `<openspec_root>/<relative-path>` when `<openspec_root>` is the active root checkout, otherwise `<workspace_root>/<relative-path>`.
   - Git commands targeting repo `<name>`: `git -C <project_root_map>[<name>] ...`. For root-repo git commands, use the mapped `basename(<openspec_root>)` or `basename(<workspace_root>)` key when present, otherwise use the consumed root-repo alias key whose mapped value resolves to `<openspec_root>` or `<workspace_root>`, otherwise use `<openspec_root>` when it is the active root checkout or `<workspace_root>`.

## Source-of-truth hierarchy

1. the main repo `AGENTS.md`
2. `<initiative_file>` for initiative identity, constraints, decisions, and story candidate context
3. the resolved `<story_file>` — the story contract
4. dependency change workspace `story.md` files
5. relevant sibling change workspaces or contract sections the resolved story depends on
6. durable design sources explicitly listed as `normative` in the resolved story's `### Design Sources`; orientation-only design sources are context only
7. original issue/ticket/PR/Jira intent and acceptance criteria, when explicitly linkable and not superseded by decisions recorded in `initiative.md` or `story.md`
8. actual code, tests, and worktree diff

`initiative.md` is authoritative for already-established initiative-level context. If original ticket/PR/Jira intent conflicts with decisions recorded in `initiative.md`, do not silently prefer the ticket; the implementation is not approvable unless the story records an explicit reopen, scope-deviation, or initiative-staleness decision. If `initiative.md` context conflicts with the live codebase, name the conflict: codebase facts win as evidence of reality, and the finding should route initiative context repair through `/openspec-initiative-plan`, `/openspec-feedback`, or planning repair as appropriate rather than silently approving drift. Use `/openspec-story-plan-converge` only for a complete/reviewable scaffold and a Plan/log lane it can orchestrate; otherwise use singular story-plan-resume. Never invent linkage: if ticket/PR/Jira evidence is absent, inaccessible, weak, or contradictory, say so explicitly and review against the remaining initiative/story/code sources.

Do not infer identity from filename shape or naming conventions that are not explicitly recorded in `initiative.md` or `story.md`.

## Oblivious Context Boundary

`/openspec-story-review` must run as fresh, oblivious arbitration. Its review inputs are limited to current OpenSpec artifacts, live repo/worktree evidence, read-only external issue/PR/Jira evidence explicitly linked or keyed from those artifacts, and explicit operator arguments such as `<initiative-slug>`, `<story-slug>`, and `WORKTREE=` selectors.

Do not accept parent/converger notebook references, implementation summaries, operational notes, prior chat context, or any other implementation-session framing as review input. Do not accept parent/converger notebook references even when relabeled as research, ops, handoff, or compact excerpts. If the prompt includes a `Notebook references from parent orchestration session` block, broad notebook excerpts, an implementation/convergence notebook page, or a request to continue review inside an implementation convergence session, abort before reviewing. If artifact readiness checks already establish that review has not run against the current evidence and all prerequisites are satisfied, tell the operator to rerun exactly `/openspec-story-review <initiative-slug> <story-slug> [WORKTREE=...]` from a completely fresh session with no carried context. Otherwise route the named readiness deficiency to its owner first and say fresh review follows repair.

A standalone prior review notebook may be consulted only after the firewall passes and only as optional sourced orientation. `progress.md → ## Implementation Review Receipt`, the story contract, and live evidence outrank it. Never use a notebook to infer a completed verdict, status transition, current next owner, or initiative binding.

After this boundary check passes, perform normal evidence discovery from the artifacts and live repo. `progress.md` handoff/proof entries remain reviewable because they are durable OpenSpec artifacts, not inherited chat or notebook context.

## Proof-boundary discipline

Use the approval gate below as the canonical pass/fail contract; this section defines what evidence must be inspected before applying that gate.

- Read prior completed concerns from `progress.md → ## Implementation Review Receipt` and carry each into the review as `resolved`, `still_open`, `superseded`, or `not_assessable`. A standalone prior review notebook, when available, may add sourced orientation but cannot add or replace lifecycle authority. If neither durable receipt nor optional notebook entry exists, mark prior concerns as `not_assessable`.
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
- Treat normative design sources as extraction inputs to the story contract, not as a free-form implementation checklist. Mapped `### Design Element Trace` rows are review claims. Also inspect normative design sources enough to catch obvious unmapped visible elements/states; classify those as planning-contract extraction gaps routed to `/openspec-feedback`, singular story-plan-resume for incomplete/non-reviewable scaffold, or `/openspec-story-plan-converge` only for a complete/reviewable lane it can orchestrate—not direct implementation failures unless the element is mapped in Acceptance/trace.
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
- Child agents may use only their allowed read-only evidence tools such as direct file reads, `git`, and search. Do not pass notebook entries, implementation summaries, operational notes, prior chat context, or convergence framing into review child agents.
- External documentation may inform hypotheses only when specialized external knowledge is needed; repo code/tests/story artifacts still govern approval.

Focused pass return contract:
- Pass title and acceptance items covered.
- Scope reviewed: repos, files, symbols, callsites, and tests.
- Search/direct-read evidence used, or `not needed` with a short reason.
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

Every concrete issue under `Gate Findings`, `Product Assessment`, `Technical Assessment`, or `Initiative Contract Drift` must use this detailed finding card format in the final review output:

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

Execute the full or focused branch selected in `## Review readiness check`. In the full branch, apply the process across all impacted surfaces. In the focused branch, apply it to the mandatory baseline, the actual surfaces named by Review Focus, and connected evidence needed to judge them; widen immediately when a widening trigger is met. The remaining approval gate still applies: focused scope changes inspection breadth, not evidence standards or finding severity.

1. Use code search and direct reading to understand the story's implementation and impacted surfaces at the selected scope. Record the owner-discovery searches you performed (`Code surfaces searched`) including domain terms, callsites/routes, existing tests, duplicate owners, generated/config/runtime surfaces, and any areas intentionally not searched.
2. Use `git -C <project_root_map>[<basename>] status`, `git -C <project_root_map>[<basename>] diff`, and targeted file reads to inspect what was actually changed. When the story spans multiple repos, run status/diff per repo (iterating over `<project_root_map>` in sorted basename order) and group findings per-repo in the review write-back. Each `<basename>` resolves to either an implementer's worktree (most common) or the main tree at `<workspace_root>/projects/<basename>` (clean main-tree fallback case from the preflight).
3. Read all relevant story-spec sections and treat each section as a claim: Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, and Discovery Notes when present.
4. Check the one well-formed current `progress.md → ## Implementation Review Receipt`, or inventory every parseable concern when existing receipt sections are malformed/duplicated. Explicitly verify each concern as resolved, still open, superseded by later authorized feedback/resume/unblock evidence, or not assessable from current evidence. Superseded receipt material is historical context and does not overrule current non-DONE Status/blocker routing; malformed/duplicate material is input to reconciliation, not a reason to skip substantive review. An optional standalone prior review notebook may orient this check only after the fresh-review firewall passes. If no receipt exists, do not manufacture prior concerns from notebook prose; treat them as not assessable unless current artifacts independently state them.
5. Check for `<change_dir>/blocked.md` before lifecycle routing. If this explicit gate already exists at entry, abort as `NOT REVIEWABLE` and give only the operator action to resolve/remove it; do not rewrite it, create a completed-verdict receipt, auto-resolve it, or offer wrapper/direct choices. A completed `BLOCKED` verdict is reserved for an external blocker discovered during substantive review and follows the ordered write protocol below.
6. Before approving implementation, verify the `Plan:` header field in `<story_file>` is `🟢 PLAN APPROVED`. When the story arrived at authoritative `Status: 🟣 IN REVIEW`, complete this fresh review and record contradictory Plan state as lifecycle drift; do not replace this review with planning workflow choices. A completed verdict must route from the status transition it actually writes, not from the arrival status. If a different active non-DONE entry state has DRAFT or PLAN IN REVIEW, Non-looped plan-review is valid only for a structurally reviewable scaffold with no unresolved finding; otherwise use plan-resume. PLAN CHANGES REQUESTED with unresolved findings uses plan-resume, while fully blended/addressed findings in a reviewable scaffold use fresh plan-review. PLAN BLOCKED remains singular operator blocker resolution. If entry Status is already DONE with non-approved Plan, use only the operator contradiction-reconciliation action; never recommend a planning command.
7. Mine original intent only from explicit anchors: ticket/PR URLs, Jira keys, issue numbers, branch names, commit messages, `initiative.md` Story Candidates and External Resources, dependency workspace `story.md` files, PR bodies, or story prose. Use read-only commands such as `gh issue view`, `gh pr view`, `jira issue view`, `git log`, and `git show` when available and relevant. If an external source cannot be accessed, record the missing source and do not invent its content.
8. Build the implementation trace map and record whether forward/backward traceability is complete or has gaps. Every changed source/test/config/runtime surface and every proof row must map back to an acceptance id plus story scope, initiative context/original intent, or an explicit exclusion.
9. Classify material evidence as `confirmed`, `inferred`, `unknown`, or `provisional`. Unknown or provisional evidence that affects acceptance, route ownership, ticket intent, contract drift, or proof credibility blocks approval unless safely scoped out with a follow-up path.
10. Never speculate about code you haven't read
11. When `initiative.md` defines constraints relevant to the resolved story's owned surfaces and invariants, inspect those sections.
12. If the final implementation or final proof matrix clearly differs from the earlier planned proof path, consult `progress.md`'s `## Progress Timeline` and `## Session Handoff` to confirm the change was recorded and justified.
13. If sibling stories define shared interfaces, invariants, or proof surfaces this story touches, inspect those targeted stories rather than assuming the resolved `story.md` is complete.
14. If ticket intent, initiative context, story text, and live code point in different directions, name the conflict and route it: contract-changing findings go to `/openspec-feedback`, singular story-plan-resume for incomplete/non-reviewable scaffold, or `/openspec-story-plan-converge` only for a complete/reviewable lane it can orchestrate; stale initiative context goes to `/openspec-initiative-plan`; unimplemented in-scope story obligations go to `/openspec-story-resume`.
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

Before approving, run these grouped checks against the selected review scope. A focused pass applies them to the mandatory baseline, focused surfaces, and required adjacent evidence; any uncertainty about an unchecked surface triggers widening rather than an assumption of safety. Use the canonical approval gate in `## Review log write-back` for the exact pass/fail contract; this section organizes the investigation that feeds that gate.

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

## Reviewed implementation identity

After all proof commands and immediately before a completed verdict, calculate `review-identity-v1` for the exact story-scoped delivery snapshot. This is mandatory for APPROVE, REQUEST CHANGES, and BLOCKED; failure is a Gate Finding and prevents publication.

1. Re-read the selected story's Initiative header region, Plan/Status, `blocked.md`, and every prerequisite's active-first Status/blocker/modern-receipt verdict. Rerun Resolution step 9 and prerequisite qualification. A failed gate prevents writes; never recompute a prerequisite's review identity.
2. Freeze `<project_root_map>` and one immutable full Git commit object ID used to delimit the story scope in each reviewed repository. Store the immutable base used for each compared range/endpoint in `Identity bases`; do not add a `range` key to the canonical receipt shape. Freeze the exact story-scoped implementation/config/test/runtime path set: relevant tracked, modified, deleted, and type-changed paths against that base; reviewed non-ignored untracked paths; and explicit in-scope `## Critical Files`, including unchanged or absent paths. Exclude only the selected story's `<change_dir>/story.md`, `<change_dir>/progress.md`, and `<change_dir>/blocked.md` review-owned coordination files. Do not include unrelated repository changes or widen identity to a whole-repository snapshot.
3. Reject the identity as unverifiable if any repository basename or relative path is not valid UTF-8 or contains TAB, LF, or CR; two reviewed repositories have the same basename; a base is not a reproducible full immutable Git commit ID; the same `(repo,path)` occurs twice; or a listed path cannot be classified. Record `Evidence reviewed` as a concise target/proof summary, not an alternative path identity. Record `Identity method: review-identity-v1` exactly once. Record `Identity bases` as one compact canonical JSON array of `{"repo":"<basename>","base":"<full-object-id>"}` objects sorted by the UTF-8 bytes of `repo`, and `Identity paths` as one compact canonical JSON array of `{"repo":"<basename>","path":"<relative-path>"}` objects sorted by the UTF-8 bytes of `repo`, then `path`. Use standard JSON string escaping with no insignificant whitespace; use `[]` for an empty list; require each repository basename and each `(repo,path)` pair exactly once.
4. Build the canonical manifest from exactly `Identity paths`. Each manifest row is exactly `<repo>\t<path>\t<type>\t<lowercase-64-hex-sha256>\n` encoded as UTF-8, where `\t` is one TAB and `\n` one LF. `type` is exactly `file`, `executable`, `symlink`, or `deleted`. Hash the exact reviewed file bytes for `file`/`executable`, exact link-target bytes for `symlink`, or the zero-byte string for `deleted`; unsupported special files prevent a completed verdict. Sort the complete encoded row bytes bytewise, concatenate them without a header or extra separator, require LF termination on every row, and add no normalization or terminal data.
5. SHA-256 hash the exact concatenated manifest bytes; an empty `Identity paths` hashes the zero-byte manifest. Record `Identity digest: sha256:<lowercase-hex>` exactly once. Rebuild once from the frozen `Identity bases` and exact `Identity paths` before any write and require the same digest.

The receipt's `Identity method`, `Identity digest`, `Identity bases`, and `Identity paths` are delivery evidence so `/openspec-pr` can recompute this identity. They are not prerequisite satisfaction or lifecycle freshness gates.

## Status transitions

Before transitioning to `✅ DONE`, check `progress.md`'s `## Current Claim` -> `- Worktrees:` for uncommitted changes. Review is read-only for source: do **not** run `git add`, `git commit`, or otherwise mutate the target repo from this skill. If any review-target worktree is dirty, approval is allowed only when that dirty state is the story implementation represented by the receipt's `Identity bases`, exact `Identity paths`, and `Identity digest`; otherwise request changes or block with a cleanup/explicit-worktree instruction. If the change workspace has no `progress.md` or no `## Current Claim` section (review-only session), skip.

A completed verdict is `APPROVE`, `REQUEST CHANGES`, or `BLOCKED` after substantive review. Every completed verdict writes both the compact durable `progress.md → ## Implementation Review Receipt` and the top-level story Status. `NOT REVIEWABLE` and other pre-verdict aborts write neither. Fail closed with this exact order:

1. Inventory all existing receipt headings and parseable prior findings without treating malformed or duplicate sections as current authority. Calculate and double-check `review-identity-v1`, then build the receipt, one timeline entry, target Status, and resulting `progress.md` in memory. Preserve unrelated sections, remove every old receipt section, and require exactly one normalized receipt in which each required field (`Reviewed at`, `Decision`, `Approval gate`, `Status transition`, `Evidence reviewed`, `Identity method`, `Identity digest`, `Identity bases`, `Identity paths`, `Findings`, `Proof`, and `Next owner`) occurs exactly once. Pair `APPROVE` with `PASS`/`✅ DONE`, `REQUEST CHANGES` with `FAIL`/`🔄 IN PROGRESS`, and `BLOCKED` with `FAIL`/`⛔ BLOCKED`. Do not write if validation fails.
2. For `BLOCKED`, create or update `<change_dir>/blocked.md` first with the blocker, evidence, resolution condition, and next owner. If that fails, leave receipts and Status unchanged and report the failure. Complete any optional notebook write now; it is supplemental and must precede durable verdict publication.
3. In one atomic `progress.md` write, replace all existing receipt sections with the one validated receipt and write exactly one concise timestamped review timeline entry; never append a duplicate receipt or retain receipt history there. Re-read and require exactly one well-formed matching receipt with every required field exactly once and the matching timeline entry.
4. Only after that succeeds, write the top-level `Status:` last (even when preserving the same target value): `APPROVE` -> `✅ DONE`, `REQUEST CHANGES` -> `🔄 IN PROGRESS`, `BLOCKED` -> `⛔ BLOCKED`. This is the final write of the command. A non-approve verdict must not leave the story IN REVIEW and suggest another fresh review.
5. Re-read all affected artifacts after Status; perform no further writes of any kind. Timeline history is never completion authority.

Partial failures require explicit reconciliation and must never be disguised as legacy state. If `blocked.md` succeeds but normalized-receipt/progress write fails, leave Status unchanged, report the partial write, and route explicit review-owned artifact reconciliation. If the normalized progress write succeeds but Status fails, report the exact receipt/Status mismatch and route explicit review-owned artifact reconciliation; do not call the verdict complete. In particular, an APPROVE receipt with a failed Status write remains IN REVIEW, not legacy DONE. Re-read all affected files and report `Receipt Write: failed` for any incomplete required pair.

- If review starts on a story whose Status is not `🟣 IN REVIEW` or `✅ DONE`, treat it as `NOT REVIEWABLE` and leave Status unchanged; review does not promote `🔄 IN PROGRESS` to `🟣 IN REVIEW`.
- If review aborts without a completed verdict for malformed/ambiguous/missing non-receipt evidence, leave Status and receipt unchanged. Malformed or duplicate review-owned receipt sections alone are not an abort reason; reconcile them through the substantive-review normalization protocol above. A true abort may finish at IN REVIEW, but its immediate next action is the singular repair owner (or a valid planning wrapper/direct choice for a complete/reviewable contract lane), never another review. State that fresh oblivious review happens only after the named repair and prerequisites are satisfied.
- If the story is already `Status: ✅ DONE`, do not reopen it solely because PR delivery is pending. Only an unbound pre-v3 DONE with zero Initiative headers and zero receipt sections is legacy; do not create a retroactive receipt for that case. A bound DONE requires one current matching APPROVE/PASS receipt; review identity is delivery evidence that PR recomputes, not lifecycle authority. Use `/openspec-pr <initiative-slug> <story-slug>` for PR metadata/evidence and `/openspec-feedback` for actionable PR feedback.

For each completed verdict, create `progress.md` if needed without inventing unrelated sections, or normalize all existing receipt sections to exactly one `## Implementation Review Receipt` with this compact shape (never append a duplicate heading):

```md
## Implementation Review Receipt
- Reviewed at: <UTC ISO timestamp>
- Decision: APPROVE | REQUEST CHANGES | BLOCKED
- Approval gate: PASS | FAIL
- Status transition: <old> -> <new>
- Evidence reviewed: <source targets and proof-matrix state>
- Identity method: review-identity-v1
- Identity digest: sha256:<lowercase manifest digest>
- Identity bases: <compact JSON [{"repo":"<basename>","base":"<full Git commit object id>"},...] or []>
- Identity paths: <compact JSON [{"repo":"<basename>","path":"<relative-path>"},...] or []>
- Findings: <compact ids/severity/source anchors, or None.>
- Proof: <commands/results, or not run with reason>
- Next owner: <state-owning command or terminal/delivery route>
```

For every completed verdict, add one concise timestamped `## Progress Timeline` entry naming the decision and `<old> -> <new>` transition in the same atomic progress write as the normalized receipt. Then write Status last and perform no later write. The timeline is history, not a substitute for the receipt. Never persist `<openspec_root>` or an `OpenSpec root:` field in `story.md`, `progress.md`, or `blocked.md`.

## Notebook write-back (optional)

The operator MAY persist review findings to the pi notebook page `openspec-review-<initiative_slug>-<story_slug>` for cross-session memory. If this command performs that optional write, it must do so before the atomic receipt+timeline write; never write the notebook after Status. It is supplemental and not authoritative for downstream skills. The top-level `Status:` header and `progress.md → ## Implementation Review Receipt` are the durable completed-verdict signals; canonical artifacts outrank notebook orientation.

When writing the notebook entry, use a compact structured format:
- Timestamp, Decision, Approval gate, Product verdict, Technical verdict
- Prior review concerns, Key findings (with Sources), Next action
- Hypothesis triage summary

If notebook tools are unavailable (non-pi runtime), skip the notebook write-back; a completed review is complete only after the required receipt+timeline write and final top-level Status write succeed.

Legacy review artifacts in existing workspaces are silently tolerated; do not read or write them. Do not retroactively create `## Implementation Review Receipt` for an unbound pre-v3 DONE story with zero Initiative headers and zero receipt sections.

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
- `Initiative Contract Drift` is only for mismatches between this story and initiative-level commitments in `initiative.md`, dependencies, or relevant sibling stories. Do not use it for generic cleanup or unrelated debt.
- Contract-changing feedback discovered during implementation review must be routed explicitly. If the implementation seems reasonable but a valid story plan lane is stale, offer the planning Converge wrapper and state-correct Non-looped plan-review/plan-resume pass, with the choose-one warning; use singular `/openspec-feedback` or `/openspec-initiative-plan` when those commands own the change. If the story contract is current and code is wrong, set Status to `🔄 IN PROGRESS` and offer **Converge wrapper:** `/openspec-story-converge <initiative-slug> <story-slug>` plus **Non-looped pass:** `/openspec-story-resume <initiative-slug> <story-slug>`, saying to choose one and not run both because the wrapper delegates direct claim/resume passes.
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
**Prior Review Receipt Check**: [none/legacy DONE without receipt, or prior durable concerns checked with resolved/still open/superseded/not assessable status]
**Receipt Write**: [written with path, not written because NOT REVIEWABLE/legacy DONE, or failed]
**Review Identity**: [review-identity-v1 sha256:<hex> with recorded Identity bases and exact Identity paths, not calculated because NOT REVIEWABLE/legacy DONE, or failed]
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

## Summary
- [2-4 short bullets]

Suggested next action: <scalar route; leave empty only for a dual route>
- Converge wrapper: <command; dual routes only>
- Non-looped pass: <state-correct command; dual routes only>
Choose one; do not run both.
```

For a scalar route, put its value on the label line and omit the three dual-route lines. For a dual route, leave the label empty and render those lines immediately after it. For implementation REQUEST CHANGES with final Status IN PROGRESS, use the implementation Converge wrapper plus Non-looped resume.

For planning re-entry, offer the planning wrapper/state-correct Non-looped pass choice only for a complete/reviewable scaffold and a Plan/log lane plan-converge can orchestrate. Missing anchors or incomplete/non-reviewable scaffold use singular story-plan-resume (or story-plan when the workspace is absent). For APPROVE with final Status DONE, select the singular state-correct PR/archive route from durable evidence. DONE with non-approved Plan uses only the operator action to investigate/reconcile contradictory durable state and names no lifecycle owner. For BLOCKED, NOT REVIEWABLE due to malformed/ambiguous input, feedback, initiative repair, PR, archive, wait, or terminal states, give only the owning route. Never suggest the implementation wrapper as a review launcher. If this command aborts without a completed verdict and authoritative final Status remains IN REVIEW, route to the owner of the named implementation/proof, contract, or external-evidence deficiency and state that fresh oblivious review happens only after repair. Do not emit a review self-loop merely because the command arrived at IN REVIEW. Recommend `/openspec-story-review` directly only when review has not yet run against the current evidence and prerequisites are already satisfied.

If there are no findings in a section, say that explicitly with `- None.`.