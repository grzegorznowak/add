---
name: epic-story-review
description: Review one implemented story against its spec, current repo state, and recorded handoff context. Read-only for code; updates only the story's coordination file.
disable-model-invocation: true
argument-hint: "<epic-name> <story-number-or-spec-file>"
allowed-tools: Read Edit Grep Glob Bash(git status:*) Bash(git diff:*) Bash(git log:*) Bash(git show:*) Bash(git rev-parse:*) Bash(git worktree:*) Bash(basename:*) Bash(gh issue view:*) Bash(gh pr view:*) Bash(jira issue view:*)
---

# Epic Story Review

Review one story implementation against its spec, current repo state, and recorded handoff context. Record the verdict back into the coordination file.

Argument: `$ARGUMENTS` — `<epic_name> <story_number_or_spec_file> [WORKTREE="<basename>=<path>"]...`. Both positional args are recommended; if either is omitted, this command uses the explicit menu fallback in `## Resolution`. `WORKTREE=` is an optional, repeatable opt-in that overrides the preflight's worktree lookup per target repo. Two forms are accepted: `WORKTREE="<basename>=<path>"` (multi form, repeatable, preferred) and legacy `WORKTREE="<path>"` (valid only when the story has exactly one target repo; the path is applied to that sole repo). Mixing the two forms in a single invocation is an error. When `WORKTREE=` is absent, the preflight reads any `- Worktrees:` list from the story's `## Active Claim`, falling back to a legacy `- Worktree:` singular bullet for stories claimed before the multi-worktree format.

## Important

You can only change the coordination files in the epic, **never** the source code of the app. Review is inherently a read-only process.

## Safety guardrails

- Do not modify source code — review is read-only.
- Do not run destructive git operations (push, `reset --hard`, force commands, branch deletion).
- Never write outside the story's coordination directory or `/tmp`; do not edit target worktrees.
- Test execution is permitted only to verify the story's Acceptance Proof Matrix and TAP-owned verification commands (not for broad exploration), even when normal test tooling writes caches or artifacts.
- GitHub/Jira access is read-only for intent mining. Use view-only commands such as `gh issue view`, `gh pr view`, and `jira issue view`; do not use generic API commands that can issue mutating requests.

## Why operator-explicit (arg or menu) selection

`/epic-story-review` never auto-infers the epic or the story. The operator explicitly chooses — either by passing `<epic> <story>` as arguments or by picking from the menu this skill shows when either is absent. The menu is **not** inference: it lists the legal candidates (filtered to `🟣 IN REVIEW`) and asks the operator to pick.

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
5. `<epic>/CONTRACT.md` if present
6. original intent artifacts explicitly linked or keyed from `MASTER.md`, the story file, dependency stories, branch names, commit messages, or existing PR text: GitHub issues, GitHub PRs, Jira tickets, or stable ticket/card ids
7. any sibling story files that define shared constraints, interfaces, or proof surfaces the resolved story claims to satisfy, when relevant

## Review intent

Do **not** rediscover the epic from scratch. Your job is to:
1. Understand the story spec in the resolved step file
2. Inspect the actual implementation and current worktree
3. Inspect epic-wide contract and targeted sibling-story context when they materially constrain the story
4. Review the implementation against the step spec, epic contract, original intent when explicitly available, and surrounding architecture
5. Record the review result back into the coordination file

## Review readiness check

Before doing a full review:
- inspect the row for the resolved step in `MASTER.md`
- inspect any `Active Claim`, `Progress Log`, `Session Handoff`, and `PR Tracking` sections in the step file
- inspect every relevant story-spec section as a claim, not only `## Acceptance` and `## Verification`: `## Purpose`, `## Actors`, `## Triggering Need`, `## Expected Prerequisites`, `## Scope`, `## Out of Scope`, `## Scenarios / Behavior Examples`, `## Acceptance`, `## Verification`, `## Critical Files`, `## Implementation Notes`, `## Locked Decisions`, and `## Discovery Notes` when present
- if `<epic>/CONTRACT.md` exists, inspect the sections that define epic-wide invariants or shared obligations for this story
- inspect original issue/PR/Jira/card intent only when explicitly linked or keyed; if unavailable, weak, or contradictory, record that instead of inventing linkage

If the story is clearly not reviewable yet, abort fast with a concise reason. Examples:
- step is still `TODO` and there is no implementation / handoff evidence
- step is blocked by an unmet dependency and the code cannot be sensibly judged
- no credible mapping from the step spec to any code or tests yet
- any acceptance id has no proof row, or any proof row is still `provisional`
- epic-wide obligations relevant to this story are still materially undefined

If you must ABORT:
- Output using the output format below.
- Set **Decision** to `NOT REVIEWABLE`.
- Set **Approval Gate** to `FAIL`.
- Include a Gate Finding explaining why.
- Keep all other sections present using `- None.`

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
   - Else fall back to the same `## Scope` strict parse + target-resolution logic as `/epic-story-claim` (Worktree preflight steps 2–3): parse `## Scope` for `projects/[A-Za-z0-9_-]+/` tokens, intersect with real `<workspace_root>/projects/<name>/.git` repos, additionally include `<workspace_root>` if it is itself a git repo.

   If `<legacy_worktree>` is set (from step 3), it is now applied: `<explicit_worktree_map>[basename(<sole_target_repo>)]` = `<legacy_worktree>` if `<target_repos>` has exactly one element, otherwise abort with "`WORKTREE=\"<path>\"` requires exactly one target repo; found N (basenames: ...). Pass `WORKTREE=\"<basename>=<path>\"` form to specify which repo".

5. **Build `<project_root_map>` from recorded + explicit entries**. Initialize empty. For each `<basename>` in the union of `<recorded_worktree_map>` keys and `<explicit_worktree_map>` keys:
   - Effective path = `<explicit_worktree_map>[<basename>]` if present (explicit wins for the overridden basename only), else `<recorded_worktree_map>[<basename>]`.
   - Resolve `<target_repo>` for `<basename>`: `<workspace_root>/projects/<basename>` if `<basename>` resolves to a sub-repo, else `<workspace_root>` if it matches `basename(<workspace_root>)`. If neither, abort with "claimed worktree for `<basename>` cannot be matched to any repo on disk".
   - Verify the effective path exists on disk AND appears in `git -C <target_repo> worktree list --porcelain`.
   - Verify the worktree's HEAD is on branch `<epic-name>/<story-slug>` via `git -C <effective path> rev-parse --abbrev-ref HEAD`. Tolerate a detached HEAD with a warning ("worktree for `<basename>` is in detached HEAD state — review will run against the checked-out commit").
   - On any verification failure: abort with "worktree for `<basename>` is missing, unregistered, or on the wrong branch: <verbatim detail>. Clean the main tree and retry, ask the implementer to `/epic-story-resume` (which recreates stale worktrees), or pass `WORKTREE=\"<basename>=<path>\"` explicitly". **Never create a worktree in review.**
   - On success: `<project_root_map>[<basename>]` = effective path.

6. **Read `Main-tree targets:` from `## Active Claim`**. Parse the story file for a `- Main-tree targets:` bullet under `## Active Claim`. Split its value on commas and trim whitespace to produce `<main_tree_targets>` — a set of repo basenames that the implementer explicitly wrote to on the main tree (no worktree). If the bullet is absent, `<main_tree_targets>` is empty.

7. **Handle scope-scan repos not in any map**. For each `<target_repo>` from step 4 whose basename is NOT yet in `<project_root_map>`:
   - `<project_root_map>[<basename>]` = `<target_repo>` (main tree).
   - If `<basename>` is in `<main_tree_targets>`: the implementer recorded that this repo was written to directly on main. If the main tree is dirty, emit a note: "reviewing `<basename>` on main tree (recorded as a main-tree target by the implementer)". If clean, no note needed. Either way, review proceeds.
   - Else if `<main_tree_targets>` is empty (legacy story or claim predating this bullet): fall back to accepting the main tree regardless of dirtiness. If dirty, emit a note: "reviewing `<basename>` on dirty main tree (no `Main-tree targets:` bullet in claim — assuming implementation was done directly on main)". Review proceeds.
   - Else (`<main_tree_targets>` is non-empty but does NOT include `<basename>`): this repo was not declared as a main-tree target and has no recorded worktree. If clean, proceed silently. If dirty, warn: "`<basename>` is dirty and was not recorded as a main-tree target or worktree — the dirty state may include unrelated changes. Review proceeds but findings should be checked carefully."

8. **Done**. `<project_root_map>` is set. All downstream resolution uses these rules:
   - `<epic>/MASTER.md`, the resolved step file, dependency step files, and anything under `agent_coordination/...` → read/write at `<workspace_root>/agent_coordination/...` unconditionally. The `## Review Log` write-back also lands at this anchor.
   - Code at `projects/<name>/foo/bar` → if `<project_root_map>` has `<name>`, route to `<project_root_map>[<name>]/foo/bar`; else route to `<workspace_root>/projects/<name>/foo/bar`.
   - Git commands targeting repo `<name>`: `git -C <project_root_map>[<name>] ...`.

## Source-of-truth hierarchy

1. `<epic>/MASTER.md`
2. the resolved step file
3. `<epic>/CONTRACT.md` when present
4. dependency step files
5. relevant sibling story files or contract sections the resolved story depends on
6. durable design sources explicitly listed as `normative` in the resolved story's `### Design Sources`; orientation-only design sources are context only
7. original issue/ticket/PR/Jira intent and acceptance criteria, when explicitly linkable and not superseded by `CONTRACT.md` or code
8. actual code, tests, and worktree diff

`CONTRACT.md` is authoritative for already-squashed epic scope. If original ticket/PR/Jira intent conflicts with `CONTRACT.md`, do not silently prefer the ticket; the implementation is not approvable unless the story records an explicit reopen, scope-deviation, or contract-staleness decision. If `CONTRACT.md` conflicts with the live codebase, name the conflict: codebase facts win as evidence of reality, and the finding should route contract repair through `/epic-squash`, `/epic-feedback`, or `/epic-story-plan-converge` as appropriate rather than silently approving drift. Never invent linkage: if ticket/PR/Jira evidence is absent, inaccessible, weak, or contradictory, say so explicitly and review against the remaining epic/story/code sources.

Do not infer identity from filename shape or naming conventions that are not explicitly recorded in `MASTER.md`.

## Shared Research Board Input

When launched by a converger, you may receive `Shared Research Board from parent orchestration session` before the slash command. This is the only allowed cross-session context beyond neutral operational notes. Use it as sourced orientation only. The converger owns keeping it relevant; you only decide whether the needed fact is present in the provided board. If present, verify it with direct reads/search against the cited anchors before it affects a finding, approval, or write-back instead of rerunning expensive research. If a provided entry does not verify, report a board-refresh signal with exact anchors; do not decide how to curate the board. If absent, follow this skill's normal research rules. Ignore any board item that lacks an exact source anchor such as `path:line`, symbol, command/output excerpt, or tool/query/path.

## Proof-boundary discipline

- Read the latest `## Review Log` entry before source inspection and carry every prior concern into the review as `resolved`, `still_open`, `superseded`, or `not_assessable`.
- Treat every relevant story-spec section as a review claim. Purpose, Triggering Need, Scope, Out of Scope, Discovery Notes, Critical Files, Implementation Notes, and Locked Decisions can all create implementation obligations or exclusions; do not validate only Acceptance and Verification.
- Build an implementation trace map before approval:
  - forward trace: `CONTRACT.md`/original issue/ticket/epic intent -> story Purpose/Scope/Scenarios/Acceptance -> final Test Architecture Plan -> final Verification proof rows -> changed code/tests/config/runtime surfaces
  - backward trace: every changed file, symbol, helper, command, test, TAP row, config, generated/runtime surface, and proof row -> Acceptance id -> in-scope story rationale or explicit exclusion
  - design trace when applicable: normative design source anchor -> visible element/state -> `required` or bounded `flexible` trace row -> Scenario -> Acceptance -> final proof row -> rendered artifact or reviewer observation
  Orphan changed surfaces, gold-plated behavior, or proof rows for unrequested behavior block approval unless the story records a safe justification.
- When an acceptance or proof row names an end-to-end boundary, verify the proof starts at that named boundary. A lower-level test with hand-built intermediate data does not satisfy a resolver/orchestration acceptance item unless the row explicitly permits that narrower proof.
- When an acceptance item names variants, modes, branches, fallback paths, error cases, or examples, treat each named case as a required proof obligation. A test or proof row that covers only one variant does not cover sibling variants unless the story explicitly excludes them with rationale.
- When `## Scenarios / Behavior Examples` is present, enforce the funnel `Scenario -> Acceptance -> Verification`: every normative `S<n>` scenario must use exactly one `Covers: A<n>`, and the linked acceptance/proof path must satisfy that scenario's concrete behavior. Orientation-only scenarios are not proof obligations, must not drive required implementation scope unless also present in Acceptance, and must not contradict the implemented behavior.
- When raw persisted, external, framework, or generated input crosses into stricter application assumptions, treat it as an `Input Boundary Shape Risk`: proof must start at the raw input boundary for every in-scope case, or the story must record an explicit exclusion / unknown with mitigation.
- Treat external or local technical docs as contract hints, not implementation proof. If a story claims an exact route, model family, auth mode, metadata label, or dispatch path, verify repo code or tests prove that exact behavior.
- Treat normative design sources as extraction inputs to the story contract, not as a free-form implementation checklist. Mapped `### Design Element Trace` rows are review claims. Also inspect normative design sources enough to catch obvious unmapped visible elements/states; classify those as planning-contract extraction gaps routed to `/epic-story-plan-converge` or `/epic-feedback`, not direct implementation failures unless the element is mapped in Acceptance/trace.
- If a story touches surfaces owned by dependency stories, inspect the relevant dependency proof rows and ensure prior accepted contracts still hold.
- If progress logs, review logs, or code structure reveal duplicated live owners for one behavior, include each owner in the review plan; do not approve a story that updates or proves only one side without an explicit exclusion.

## Multipass review mode

Before starting the implementation review, count the concrete items in the
story's `## Acceptance` list. `## Acceptance` is the source of truth for this
trigger.

Counting rules:
- Count top-level acceptance bullets or checklist items under `## Acceptance`.
- Count stable acceptance ids such as `A1`, `A2`, ... when present.
- Do not count prose paragraphs, examples, nested explanatory bullets, notes,
  or out-of-scope bullets.
- If `## Acceptance` is malformed or the concrete item count cannot be
  determined, record a `Gate Finding`, set `**Approval Gate**: FAIL`, and do
  not approve.

When `## Acceptance` has 6 or more concrete items, multipass review is
required. Multipass is also required when the combined diff across all
target repos exceeds 30 files or 1500 lines, even if acceptance items
are fewer than 6.

Diff-size computation:
- Compute the combined diff per repo before deciding whether multipass is triggered. Prefer the story branch delta from the merge-base with the repo's default branch (`git -C <root> diff --numstat <base>...HEAD`) when reviewing a worktree on the story branch.
- If the implementation is recorded on a dirty main tree or the branch base cannot be identified, count the reviewable uncommitted delta with `git -C <root> diff --numstat` and `git -C <root> diff --cached --numstat`, then state that fallback in `Steps taken`.
- Sum unique changed file paths across target repos for the file threshold, and sum added plus deleted lines for the line threshold. Rename-only rows count as one file and zero changed lines unless the numstat row reports additions/deletions.
- If diff size cannot be computed credibly, record a `Gate Finding`; do not use uncertainty to avoid multipass.

Multipass planning:
1. Build a compact review plan with 2-8 focused passes.
2. Group passes by acceptance-area and activated-risk lens, not mechanically one pass per
   acceptance item.
3. Use the fewest genuinely independent passes needed for strong coverage.
   Merge candidate passes that would inspect the same changed-file cluster,
   root-cause family, invariant, or evidence surface.
4. Keep tests, regressions, and gap checks inside the pass that owns the
   subsystem risk unless they need a truly independent evidence path.
5. Map every acceptance item to at least one planned pass.
6. For acceptance items with named variants, modes, fallback paths, or failure cases, map every named case to at least one planned pass or record an explicit exclusion.
7. For every normative scenario with exactly one `Covers: A<n>`, map the scenario-relevant case to the pass that covers that acceptance id. If no pass covers the linked scenario behavior, add one or record a gate finding.
8. Each pass must have a clear title, acceptance items covered, risk focus, and
   expected evidence surface.

Focused pass execution:
- Use subagents in normal operation. Each subagent is read-only for code and
  coordination files.
- A documented manual focused-pass substitute is allowed only when subagent
  spawning fails or a subagent times out. The substitute must record the pass
  title, substitution reason, files/symbols inspected, search/research used,
  findings, and explicit clean or inconclusive result.
- Subagents may use direct file reads, `git`, and search for straightforward
  questions.
- Use `code_research` for complex cross-file behavior, architecture, routing,
  lifecycle, orchestration, shared-helper, or unclear-ownership investigations
  only when the provided Research Board does not already contain a sourced entry
  covering the question. If it does, verify the entry with direct reads/search
  against the cited anchors first.
- Subagents may use SERP/web research only when specialized external knowledge
  is needed. Web-derived claims must be source-linked, separated from
  repo-grounded findings, and never substitute for reading changed code.

Focused pass return contract:
- Pass title and acceptance items covered.
- Scope reviewed: repos, files, symbols, callsites, and tests.
- Search/direct-read evidence used.
- `code_research` question used, or `not needed` with a short reason such as
  `verified board entry <id> via <anchors>`.
- SERP/web sources used, or `none`.
- Hypothesis Triage: compact bullets using
  `suspicious surface: <file/API/flow>; tentative issue: <possible failure>; next proof target: <source/test/proof to check>`.
  Include only candidate issue threads the pass actually inspected; prune weak
  candidates before promoting anything into `Findings`.
- Findings: every non-empty finding ends with `Sources: path:line`; use
  `- None.` when clean.
- Verification/proof notes: proof rows checked, tests inspected, commands
  rerun, or reason commands were not rerun.
- Evidence quality: `confirmed`, `inferred`, `unknown`, and/or `provisional` evidence used by the pass, with unknowns/provisional items called out.
- Result: `clean | findings | inconclusive`.
- Evidence gaps: use `- None.` when none.

Multipass synthesis:
- Synthesis is an assembly pass, not a new investigation pass.
- Treat focused-pass outputs as hypotheses, not authority. Before
  carrying any claim into the final review, verify that primary evidence
  in the current worktree or story artifacts supports the claim, not
  just that a cited `file:line` exists.
- Read the plan and all focused-pass outputs.
- Map every `## Acceptance` item, including every named variant/failure mode inside an item, to at least one completed focused-pass result or explicit exclusion.
- Map every `S<n> Covers: A<n>` normative scenario to the completed focused-pass result that proves the linked acceptance behavior. If implementation satisfies the acceptance wording generally but not the linked scenario case, record a `Gate Finding`.
- Dedupe repeated findings while preserving original `Sources: path:line`
  evidence.
- Classify accumulated findings into `Gate Findings`, `Product Assessment`,
  `Technical Assessment`, or `Epic Contract Drift`.
- Produce a `### Strengths` section under both Assessments from positive
  observations in focused-pass outputs.
- Do not perform new broad code research, invent missing evidence, silently
  resolve conflicting pass results, or convert an inconclusive pass into
  approval.
- If any acceptance item or required named variant is uncovered, any focused pass is inconclusive, or
  focused-pass outputs conflict, record a `Gate Finding`; `**Approval Gate**`
  must be `FAIL` and `**Decision**` cannot be `APPROVE`.

## Hypothesis triage and detailed findings

Use a compact Chain-of-Draft-style hypothesis triage before finalizing review
findings. This is visible review work, not hidden reasoning.

For single-pass review, include a `## Hypothesis Triage` section in the final
output. For multipass review, require each focused pass to return Hypothesis
Triage bullets, then synthesize only the useful surviving threads into the final
`## Hypothesis Triage` section.

Hypothesis Triage bullets use this exact shape:

```md
- suspicious surface: <file/API/flow>; tentative issue: <possible failure>; next proof target: <source/test/proof to check>
```

Rules:
- Include only candidate issue threads actually inspected.
- Prune weak, duplicate, or disproven candidates before promoting findings.
- Do not treat triage bullets as final proof. Findings still require the
  detailed finding card and `Sources: path:line` contract below.
- Synthesis may summarize and dedupe triage from focused passes, but must not
  perform new broad investigation.

Every concrete issue under `Gate Findings`, `Product Assessment`,
`Technical Assessment`, or `Epic Contract Drift` must use this detailed finding
card format in both the final review output and the `## Review Log` write-back:

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
Keep `Why` in plain operator-facing language. Prefer `Not Assessed` over fake
precision when evidence is insufficient.

## Review process

1. Use code search and direct reading to understand the story's implementation and impacted surfaces. Record the owner-discovery searches you performed (`Code surfaces searched`) including domain terms, callsites/routes, existing tests, duplicate owners, generated/config/runtime surfaces, and any areas intentionally not searched.
2. Use `git -C <project_root_map>[<basename>] status`, `git -C <project_root_map>[<basename>] diff`, and targeted file reads to inspect what was actually changed. When the story spans multiple repos, run status/diff per repo (iterating over `<project_root_map>` in sorted basename order) and group findings per-repo in the review write-back. Each `<basename>` resolves to either an implementer's worktree (most common) or the main tree at `<workspace_root>/projects/<basename>` (clean main-tree fallback case from the preflight).
3. Read all relevant story-spec sections and treat each section as a claim: Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification (including `### Test Architecture Plan`), Critical Files, Implementation Notes, Locked Decisions, and Discovery Notes when present.
4. Read any existing `## Review Log` entries in the story before deciding. If prior review runs requested changes or recorded blockers, explicitly verify whether each concern is resolved, still open, superseded by later story changes, or not assessable from current evidence.
5. Before approving implementation, verify the matched `MASTER.md` row's `Plan` lane is `🟢 PLAN APPROVED` when the column exists. If `Plan` is `🟡 PLAN DRAFT`, `🟣 PLAN IN REVIEW`, `🟠 PLAN CHANGES REQUESTED`, or `⛔ PLAN BLOCKED`, the implementation cannot be approved; record a `request_changes` verdict with next action `/epic-story-plan-converge <epic> <story>`.
6. Mine original intent only from explicit anchors: ticket/PR URLs, Jira keys, issue numbers, branch names, commit messages, `MASTER.md`, dependency stories, PR bodies, or story prose. Use read-only commands such as `gh issue view`, `gh pr view`, `jira issue view`, `git log`, and `git show` when available and relevant. If an external source cannot be accessed, record the missing source and do not invent its content.
7. Build the implementation trace map and record whether forward/backward traceability is complete or has gaps. Every changed source/test/config/runtime surface, Test Architecture Plan row, and proof row must map back to an acceptance id plus story scope, `CONTRACT.md`/original intent, or an explicit exclusion.
8. Classify material evidence as `confirmed`, `inferred`, `unknown`, or `provisional`. Unknown or provisional evidence that affects acceptance, route ownership, ticket intent, contract drift, or proof credibility blocks approval unless safely scoped out with a follow-up path.
9. Never speculate about code you haven't read
10. When `<epic>/CONTRACT.md` exists, inspect the sections relevant to the resolved story's owned surfaces and invariants
11. If the final implementation, final Test Architecture Plan, or final proof matrix clearly differs from the earlier planned test/proof path, consult `## Progress Log` and `## Session Handoff` to confirm the change was recorded and justified
12. If sibling stories define shared interfaces, invariants, or proof surfaces this story touches, inspect those targeted stories rather than assuming the resolved step file is complete
13. If ticket intent, `CONTRACT.md`, story text, and live code point in different directions, name the conflict and route it: contract-changing findings go to `/epic-story-plan-converge` or `/epic-feedback`, stale merged contracts go to `/epic-squash`/contract repair, and unimplemented in-scope story obligations go to `/epic-story-resume`.
14. Run a Debt Friction check: ask whether implementation or review was made harder by unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure. Only record a `Debt Friction` finding when there is a story-local causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.
15. Run a risk-sensitive sanity pass for activated risk lenses. Use story text, diff, source inspection, and tests to identify material domains such as async/event-loop behavior, concurrency, process/resource lifecycle, platform/OS APIs, filesystem/network/subprocess I/O, permissions/security, persistence, retries/timeouts, generated artifacts, prompt/template fail-open behavior, external services, and naming-sensitive invariants. Review those domains by failure mode and existing repo idiom, not only by changed file.
16. Break the reviewed implementation into logical groups; explain the grouping briefly
17. Review each group sequentially
18. Prioritize:
   - correctness
   - regressions
   - product / acceptance drift from the requested outcome
   - design-source extraction gaps and rendered-surface proof gaps where relevant
   - epic contract drift from `MASTER.md`, `CONTRACT.md`, or sibling-story commitments
   - architectural consistency
   - duplication / missed reuse
   - status / progress drift from the step spec
   - branch-coverage drift from the planned proof surface
   - test architecture drift: wrong layer/file, unexplained single-file aggregation, hidden fixture coupling, or CI lane gaps
   - missing routing completeness across supported callsites
   - fail-open prompt regressions where relevant
   - red-first workflow drift or undocumented exceptions
   - missing tests
   - rollout / operational risks where relevant

## Critical checks

Before approving, verify:
- Does the implementation actually satisfy the step spec and requested outcome?
- Were any explicit epic-wide contract or architectural decisions violated?
- Can existing code be extended instead of creating new? Search the codebase for similar patterns before concluding new code is needed.
- Do the changes respect module boundaries and current patterns?
- Are there security implications in the implementation or operational model?
- Are there performance or scalability regressions in the changed path?
- Are follow-on status transitions accurate in `MASTER.md` and the step file?
- Does the step file record the focused red seam that was used, or an explicit written exception with the alternative proof path?
- If red-first was bypassed, was the exception recorded before proceeding and was the alternative proof path concrete?
- Are there adequate tests for the change, including each named acceptance variant, mode, fallback path, and failure case?
- Does the implementation follow `### Test Architecture Plan`, including the planned assertion/observable proof signals and fallback decisions, or does `## Progress Log` / `## Session Handoff` justify each material drift?
- Are tests placed in the planned owning suites/files, with unrelated layers split unless an explicit repo-convention rationale exists?
- Do fixtures/data setup remain explicit, isolated, cleanup-safe, deterministic, and free of hidden live network/db/filesystem dependencies unless explicitly accepted?
- Do final verification commands cover the planned TAP CI lanes, assertion/observable signals, and focused/broad gates?
- If `## Scenarios / Behavior Examples` is present, does every normative scenario flow through a linked acceptance id and final proof row, and does implementation satisfy the scenario's concrete behavior?
- Are there hidden packaging / runtime / ops implications not captured in the step?
- Is every acceptance id still covered by the final Acceptance Proof Matrix?
- Is every named variant/failure mode inside each acceptance id covered by actual tests, source inspection, or command output, rather than only by broad proof-matrix claims?
- Are any Acceptance Proof Matrix rows still `provisional`?
- Does every proof row start at the boundary it claims to prove, rather than bypassing it with hand-built intermediate state?
- Are route/model/auth/metadata claims grounded in repo behavior or tests, not only in external or local documentation?
- If the story includes `### Design Element Trace`, does the implementation satisfy every mapped `required` row and every bounded `flexible` row within its stated bounds?
- If the story names normative design sources, did review inspect those durable sources enough to catch obvious unmapped visible elements/states and route any extraction gap as a planning-contract issue rather than a direct implementation failure?
- For design obligations involving visibility, placement, navigation, copy, responsive behavior, or interaction state, is there rendered-surface evidence (browser/manual UI observation, screenshot, rendered DOM/output, or equivalent) unless the story records an explicit exception or narrower proof boundary?
- If the story spans multiple surfaces / variants / branches, does the final proof contract still cover every in-scope row from the `Surface / Branch Proof Matrix`, or log an explicit intentional exclusion?
- If an acceptance item defines fallback, default, degraded, malformed, missing-data, or error behavior, is that path directly proven? Success-path tests do not cover fallback behavior.
- If shared helpers or multiple callsites were in scope, is there explicit routing proof showing that each supported callsite actually reaches the intended helper or branch logic rather than only proving helper correctness?
- If the story is prompt/template/placeholder-driven, do the final tests or reviewer actions prove there are no unresolved placeholders on supported paths, that enabled paths actually activate the feature, and that an appropriate disabled/default path stays unchanged?
- If the story has `Input Boundary Shape Risk`, does final evidence start at each named raw input boundary and cover every in-scope shape case, or record an explicit exclusion / unknown with mitigation?
- If proof paths changed, was the story updated and the drift logged?
- If sibling stories or the epic contract declare shared interfaces or obligations this story touches, does the implementation still match them, or is any intentional drift explicitly recorded?
- Do all relevant story-spec sections still hold as claims against the implementation, including Purpose, Triggering Need, Scope, Out of Scope, Critical Files, Implementation Notes, Locked Decisions, and Discovery Notes when present?
- If an original issue, PR, Jira ticket, parent epic, or stable card id is available, does each Purpose/Scope/Acceptance claim map to that source, to `CONTRACT.md` when the contract superseded it, or to an explicit scoped deviation?
- If grounded ticket intent, `CONTRACT.md`, story text, and current code shape point in different directions, is the conflict named with a routed decision rather than silently letting one source erase another?
- Does every changed helper, API, test, command, config/runtime surface, generated artifact, TAP row, and proof row map backward to an acceptance id and in-scope rationale? Orphan implementation work blocks approval unless explicitly justified.
- Was owner discovery broad enough beyond listed Critical Files: domain owners, similar implementations, tests, routes/callsites, fixtures, CLI/API entrypoints, generated artifacts, config/runtime owners, and deprecation paths?
- Are activated risk lenses identified and reviewed at the owning boundary? Check material domains such as async/event-loop behavior, concurrency, platform/OS APIs, external I/O, permissions/security, persistence, resource lifecycle, retries/timeouts, generated artifacts, and naming-sensitive invariants.
- For async or event-loop paths, are blocking sync calls avoided, offloaded, or justified with a safe rationale consistent with existing project idioms?
- For platform/API/external-reality operations, are common sibling failure modes handled or explicitly excluded, including not-found/stale, permission/access denied, already complete, timeout/cancellation, unsupported platform, and partial failure?
- Do tests prove caller-observable behavior and contract signals rather than only private helper calls, retry counts, sleeps, ordering, or implementation choreography? Treat internal-mechanics assertions as supplementary unless the story makes them contractual.
- Do names, comments, and tests state sensitive invariants truthfully, without implying stronger identity, ownership, lifecycle, durability, permission, locking, or safety guarantees than the code provides?
- Were review findings and feedback fixes closed with disposition, fix proof, and regression/side-effect verification rather than only prose acknowledgement?
- Are evidence-quality categories explicit, and do any `unknown` or `provisional` items affect acceptance, route ownership, ticket intent, contract drift, or proof credibility? If yes, approval is blocked unless the story safely scopes them out.
- If any `Debt Friction` entry used `fix-now`, did the cleanup stay within its `Scope Justification`, remain enabling for this story, and have verification? If not, request changes or split the debt into a follow-up recommendation.

## Status transitions

Before transitioning to `✅ DONE`, check `## Active Claim` -> `- Worktrees:` for uncommitted changes. Review is read-only for source: do **not** run `git add`, `git commit`, or otherwise mutate the target repo from this skill. If any review-target worktree is dirty, approval is allowed only when the dirty state is the implementation being reviewed and the review log names the reviewed worktree/diff; otherwise request changes or block with a cleanup/explicit-worktree instruction. If the step has no `## Active Claim` section (review-only session), skip.

You may update only coordination files (`MASTER.md` and the story file) as part of the review. Use this policy:

- if review starts on a step marked `🔄 IN PROGRESS` but implementation is clearly ready for review, move it to `🟣 IN REVIEW`
- if review passes with no blocking findings AND the epic does not use the optional GitHub PR stage for this story, mark it `✅ DONE`
- if review passes with no blocking findings AND the story is expected to go through a GitHub PR review, leave it at `🟣 IN REVIEW` and tell the user to run `/epic-story-pr` to transition to `🔵 IN PR`
- if a story was already marked `✅ DONE` as local-only completion and later needs a GitHub PR, `/epic-story-pr <epic> <story>` owns that late injection; review does not reopen it
- if review finds issues that require more implementation work, move it to `🔄 IN PROGRESS`
- if review cannot complete because of an external blocker, mark it `⛔ BLOCKED`
- if the step is currently `🔵 IN PR`, treat this as a pre-merge sanity review only; **do not transition the status from `🔵 IN PR` yourself**. Any merge-state change belongs to `/epic-story-pr`. Record findings in the `Review Log` as normal.

## Review log write-back

Append or update a `## Review Log` section in the step file with a new entry:

```md
- <UTC ISO timestamp> Review run by fresh maintainer session
  - Decision: approve | request_changes | blocked | not_reviewable
  - Approval gate: pass | fail
  - Product verdict: approve | request_changes | reject | not_assessed
  - Technical verdict: approve | request_changes | reject | not_assessed
  - Multipass review: not_triggered | completed | incomplete
  - Prior review concerns: none | resolved | still_open | superseded | not_assessable
  - Plan lane at review time: <value or absent>
  - Epic contract drift: none | present
  - Status transition: <from> -> <to>
  - Sections reviewed: Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, Discovery Notes
  - Original intent checked: <issues/PRs/Jira/tickets/epic sources or none found/inaccessible>
  - Traceability: forward <complete|gaps>; backward <complete|gaps>
  - Test architecture: complete|gaps|not applicable; TAP rows <aligned|missing|misplaced|drift logged>
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

If a `Review Log` section does not exist, create it.

Approval is not allowed if the proof contract is still unresolved. A story is only eligible for approval when:
- every acceptance id remains covered
- every named variant, mode, branch, fallback path, and failure case inside an acceptance id is covered or explicitly excluded
- every normative scenario linked with exactly one `Covers: A<n>` is satisfied through its linked acceptance id and final proof row
- every Acceptance Proof Matrix proof row is `final`
- the Test Architecture Plan rows match actual test placement, assertions/observability, fixture/data strategy, CI lanes, and fallback decisions, or every deviation is logged and justified
- the Acceptance Proof Matrix matches the actual implementation and verification surfaces
- final tests and commands satisfy `### Test Architecture Plan`, or every deviation is logged, justified, and still preserves acceptance proof quality
- every named end-to-end proof starts at the claimed entry boundary, or the story explicitly narrows the proof row
- every required surface / variant / branch row is covered or explicitly excluded
- routing completeness is proven when multiple supported callsites or orchestration paths exist
- route, model-family, auth-mode, and metadata claims are proven by repo code/tests rather than documentation alone
- multipass review is either not triggered or completed with every acceptance
  item covered by a focused-pass result
- required fail-open checks are satisfied for prompt/template/placeholder-driven features
- required design trace rows are satisfied, with every mapped `required` row proven and every `flexible` row within its explicit bounds
- rendered-surface evidence exists for visibility, placement, navigation, copy, responsive, and interaction-state design obligations unless the story records an explicit exception or narrower proof boundary
- obvious unmapped visible elements/states from normative design sources have been routed as planning-contract gaps rather than silently ignored
- required input-boundary shape risk rows are covered by real-boundary evidence, explicitly excluded, or recorded as unknown with mitigation
- any apparent proof drift was logged when it happened
- the step file records either the focused red seam that was used or an explicit written exception with the alternative proof path
- any relevant epic contract or sibling-story obligation touched by this story remains satisfied, or the intentional drift is explicitly recorded and reflected in the review verdict
- forward and backward traceability are complete, or every traceability gap is safely scoped out and does not affect acceptance, proof, ownership, or contract fidelity
- evidence quality is explicit, with no unknown or provisional evidence affecting acceptance, route ownership, ticket intent, contract drift, or proof credibility
- activated risk lenses are reviewed at their owning boundary, or explicitly excluded with rationale
- prior findings and feedback fixes have disposition, fix proof, and regression/side-effect verification

## Classification rules

- The Product and Technical verdicts are independent and may disagree.
  Either may also be `NOT ASSESSED` when the reviewer lacks sufficient
  evidence for that dimension. Out-of-scope issues may still downgrade a
  verdict when materially important.
- `Gate Findings` contains readiness, proof-contract, state-transition, and red-first/precondition failures. Any unresolved gate finding means `**Approval Gate**: FAIL` and `**Decision**` cannot be `APPROVE`.
- `Product Assessment` evaluates requested outcome, acceptance behavior, user-visible correctness, and epic-contract obligations explicitly owned by this story.
- `Technical Assessment` evaluates correctness, regressions, architecture, reuse, tests, security, performance, maintainability, and rollout safety.
- If the same underlying issue qualifies for both `Product Assessment` and
  `Technical Assessment`, report the canonical finding only once. Prefer
  `Product Assessment` when the issue affects requested behavior, acceptance,
  user-visible correctness, operator value, or the approval verdict. Use
  `Technical Assessment` for distinct implementation concerns that are not
  already captured by the product finding.
- `In Scope Issues` are issues the resolved story directly owns or must satisfy to pass.
- `Out of Scope Issues` are adjacent problems, follow-on work, or broader epic concerns worth flagging but not required for this story to pass.
- `Epic Contract Drift` is only for mismatches between this story and epic-level commitments in `MASTER.md`, `CONTRACT.md`, dependencies, or relevant sibling stories. Do not use it for generic cleanup or unrelated debt.
- Contract-changing feedback discovered during implementation review must be routed explicitly. If the implementation seems reasonable but the story/contract is stale, request contract repair through `/epic-story-plan-converge`, `/epic-feedback`, or `/epic-squash` rather than approving a hidden contract change. If the story contract is current and code is wrong, route to `/epic-story-resume`.
- Order findings in every issue list by severity, include file references, and use `- None.` when a list is empty.

## Output format

Start with gate findings and issue lists, ordered by severity, with file references.

```markdown
**Decision**: [APPROVE | REQUEST CHANGES | BLOCKED | NOT REVIEWABLE]
**Reviewed Story**: [Step <resolved_step_number> / <resolved_spec_file>]
**Status Transition**: [<old> -> <new>]
**Grouping**: [brief grouping logic]
**Epic Context Used**: [MASTER.md, CONTRACT.md if present, dependency stories, sibling stories reviewed, handoff/progress sections]
**Original Intent Used**: [issues/PRs/Jira/tickets/epic sources inspected, none found, or inaccessible]
**Prior Review Log Check**: [none, or prior concerns checked with resolved/still open/superseded/not assessable status]
**Traceability**: [forward complete/gaps; backward complete/gaps]
**Test Architecture**: [complete | gaps | not applicable; TAP rows aligned/missing/misplaced/drift logged]
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

## Epic Contract Drift
- <finding summary> Sources: `path:line`
- None.

## Research Events
- reused: <board entries verified by direct reads/search with anchors, or none>
- board-refresh: <provided entries not verified or needed facts absent, with anchors, or none>
- added: <new sourced research facts with anchors, or none>

## Summary
- [2-4 short bullets]

**Next Action**
- [single concrete next step]
```

If there are no findings in a section, say that explicitly with `- None.`.
