---
name: openspec-story-converge
description: "Run fresh claim/resume implementation passes against one OpenSpec change until it reaches Status: 🟣 IN REVIEW, becomes blocked, or the loop reaches a hard stop. Use when a plan-approved implementation story needs continuation only; independent review is intentionally left to a separate fresh session."
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug> [MAX_CYCLES=5] [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Grep Glob Task Bash(git status:*) Bash(git worktree list:*)
---

# OpenSpec Story Converge

Coordinate the implementation-side iteration loop for exactly one OpenSpec change workspace. This command is an orchestrator only: it may start a fresh `/openspec-story-claim` pass for an approved unstarted story, then run fresh `/openspec-story-resume` passes until implementation is ready for independent local review at `Status: 🟣 IN REVIEW`, blocks, no-progress is detected, or the cycle budget is exhausted. It must never launch `/openspec-story-review`, must never pass notebook or implementation-session context to review, and must stop at `🟣 IN REVIEW` with an explicit operator instruction to run review from a completely fresh, oblivious session.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug> [MAX_CYCLES=5] [WORKTREE="<basename>=<path>"]...`. Initiative and story slugs must match the canonical regex `^[a-z0-9]+(?:-[a-z0-9]+)*$`; reject non-canonical positional slugs before path resolution. The initiative slug and story slug are required. `MAX_CYCLES` is optional and defaults to `5`; it counts implementation-producing passes, not review attempts. `WORKTREE=` values are passed through unchanged to `/openspec-story-claim` and `/openspec-story-resume`; when stopping at `🟣 IN REVIEW`, preserve them in the final `/openspec-story-review` recommendation.

## Resolution Model

- `<workspace_root>` = `<cwd>` at launch. Keep it for root-repo worktree discovery.
- `<openspec_root>` = the active checkout containing this story's OpenSpec artifacts. It starts as `<workspace_root>` and may be updated in memory during initial resolution or after a claim/resume pass if the active artifacts live in a root repo worktree. Never persist an `OpenSpec root:` field.
- `<initiative_dir>` = `<openspec_root>/openspec/initiatives/<initiative>`.
- `<initiative_file>` = `<initiative_dir>/initiative.md`.
- `<change_dir>` = `<openspec_root>/openspec/changes/<story-slug>`.
- `<story_file>` = `<change_dir>/story.md`.
- The `Status:` header in `story.md` is the convergence gate signal.
- `<progress_file>` = `<change_dir>/progress.md`.
- `<blocked_file>` = `<change_dir>/blocked.md`.

There is no `MASTER.md` and no tracker table. All status is self-contained in the change workspace artifacts:

- The `Status:` header field in `<story_file>` is the authoritative implementation status.
- The `Plan:` header field in `<story_file>` is the authoritative planning lane.
- The `## Current Claim` section in `<progress_file>` records active implementation state and worktree bindings.
- Implementation completion is represented by the exact top-level `Status:` plus current task/proof artifacts. A bound receiptless DONE is lifecycle-valid. Legacy receipt material is inert migration input; never validate, replace, normalize, or create it here. Optional notebooks are implementation orientation only and never lifecycle authority.

## Workflow
1. Resolve the requested initiative and change workspace through `openspec/initiatives/<slug>/initiative.md` and `openspec/changes/<story-slug>/story.md`.
2. Choose the first implementation pass from the story's current status, or stop immediately when it is already `🟣 IN REVIEW` / `✅ DONE`.
3. If an unstarted story is plan-approved, delegate claiming to `/openspec-story-claim <initiative> <story-slug>`.
4. Run up to `MAX_CYCLES` fresh-agent implementation cycles (`claim` once when needed, then `resume` as needed).
5. Pass compact notebook references for sourced research, plus neutral operational notes, into later implementation agents only.
6. After each implementation pass, refresh `<openspec_root>` before reading lifecycle artifacts so a claim-created root worktree does not leave convergence reading stale files from the launch checkout.
7. Stop when the story is ready for independent review, blocked, no-progress is detected, invalid state is found, or the cycle budget is exhausted.
8. Print the convergence trace, notebook context summary, commit recommendation, and optional operator follow-ups without writing coordination files directly.

## Phase 1 — Parse and Resolve

1. Parse `$ARGUMENTS` and validate both positional slugs against `^[a-z0-9]+(?:-[a-z0-9]+)*$` before interpolating them into paths; reject malformed values.
   - `<initiative>`: required first positional token.
   - `<story-slug>`: required second positional token.
   - `MAX_CYCLES=<n>`: optional positive integer; default `5`.
   - `WORKTREE="<value>"`: optional, repeatable, passed through unchanged.
2. Reject unknown flags.
3. Set `<workspace_root>` = `<cwd>` and `<openspec_root>` = `<workspace_root>`. There is no persisted `OpenSpec root:` field. `<workspace_root>` remains the launch checkout/root-repo worktree discovery base; `<openspec_root>` is the transient artifact anchor for all `openspec/...` reads.
4. Before reading lifecycle artifacts or making readiness decisions, run the OpenSpec-root preflight in this order:
   - Inspect all explicit `WORKTREE=` values first. A root candidate qualifies only when it is a git checkout containing both `openspec/initiatives/<initiative>/initiative.md` and `openspec/changes/<story-slug>/story.md`. If exactly one explicit candidate qualifies, set `<openspec_root>=<path>` immediately; it is authoritative. If multiple explicit candidates qualify, ask which checkout is active and halt; never guess. Explicit target-repo overrides that lack both artifacts remain normal pass-through inputs.
   - Only when no explicit candidate qualifies, inspect registered root-repo worktrees other than `<workspace_root>` from `git -C <workspace_root> worktree list --porcelain` on branch `refs/heads/<initiative>/<story-slug>`. If exactly one branch worktree qualifies, set `<openspec_root>` to it even when launch contains matching but possibly stale artifacts; that unique branch worktree outranks launch. If multiple branch worktrees qualify, ask which checkout is active and halt; never guess.
   - Only when neither an explicit nor branch-worktree candidate qualifies, fall back to `<workspace_root>` and require both artifacts there.
5. Recompute `<initiative_dir>` = `<openspec_root>/openspec/initiatives/<initiative>` and read `<initiative_dir>/initiative.md`. If missing, ask whether the story was claimed into a root repo worktree and the OpenSpec artifacts were moved there. Recommend rerunning `/openspec-story-converge <initiative> <story-slug> [WORKTREE=...]` from that worktree, or rerunning with an explicit valid root `WORKTREE="<basename>=<path>"`. Abort with: `initiative not found in this checkout`.
6. Resolve `<change_dir>` = `<openspec_root>/openspec/changes/<story-slug>/`.
   - If missing, check `<openspec_root>/openspec/changes/archive/<story-slug>/`.
   - If archived, abort with: `story is archived; move it back to openspec/changes/ first`.
   - If missing in both, ask whether the story was moved to a root repo worktree during claim. If a checkout containing it is identified, give only the rerun-from-that-checkout or explicit-root `WORKTREE="<basename>=<path>"` operator action. If relocation is ruled out and the workspace is genuinely absent, route singularly to `/openspec-story-plan INITIATIVE=<initiative>`. Abort with: `change workspace not found in this checkout`.
7. Check `<blocked_file>` before reading lifecycle fields or offering any wrapper/direct route. If it exists, stop with the singular operator action to resolve the blocker and remove the file.
8. Read `<story_file>` and confirm the top-level `Status:` header field is present (it may be default-valued or unset).
   - If `story.md` is missing or unreadable, ask the same root-worktree relocation question and abort with: `story.md is missing from change workspace`.
9. Validate the durable initiative binding before lifecycle routing:
   - Inventory the top-level header region before the first `## ` heading for every unindented `Initiative` field or Initiative-like field line. Exactly one present header is valid only when the whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`. Duplicate headers, an empty value, whitespace-before-colon variants, non-canonical values, or any other malformed Initiative-like field are hard conflicts: halt without launching a pass or writing any artifact and report every offending line. Never reinterpret malformed input as the legacy no-header case.
   - When exactly one valid `Initiative:` header is present, require its value to equal `<initiative>`; a mismatch is a hard conflict and reports both values.
   - Only zero Initiative or Initiative-like header lines is a legacy story. For that case, scan active `<openspec_root>/openspec/initiatives/*/initiative.md` files for `## Story Candidates` references to the exact story slug. If exactly one initiative references it and it equals `<initiative>`, accept that unique exact candidate association. If no initiative references it, accept because both required positional slugs form the operator-explicit pair; emit a compatibility warning and do not backfill the header. Any reference by another initiative, including multiple references, is conflicting evidence: halt and never guess.
10. Ignore legacy receipt material for routing; receipt presence, absence, shape, verdict, duplication, and staleness have no lifecycle effect. This converger never synthesizes or normalizes it. Keep the exact `WORKTREE=` fragments for later command lines. Do not normalize or reinterpret them except for the read-only OpenSpec-root preflight above.

## Phase 2 — Eligibility Gate

Use the `Status:` and `Plan:` header fields in `<story_file>` as the authoritative implementation status and planning lane. Check for `blocked.md` as an explicit gate file.

Allowed starting states:

- `Status:` is absent, unset, `⬜ TODO`, or `⚪ TODO` only when the story is plan-approved and the `## Current Claim` section in `<progress_file>` does not exist or is empty.
- `Status: 🔄 IN PROGRESS` only when `Plan:` is `🟢 PLAN APPROVED`.
- `Status: 🟣 IN REVIEW` is a successful implementation-convergence stop only when bounded readiness evidence shows no named repair issue and review has not yet run against the current evidence. An aborted review's preserved status does not override its named implementation/proof, contract, or external-evidence repair owner. Legacy receipt material is inert and cannot affect current IN REVIEW routing.
- `Status: ⛔ BLOCKED` only when `Plan:` is `🟢 PLAN APPROVED` and `<blocked_file>` is absent; this means the explicit gate file was removed and `/openspec-story-resume` must normalize the stale status back to `🔄 IN PROGRESS` before work continues.
- `Status: ✅ DONE` is independent completion authority, but only a DONE story whose `Plan:` is `🟢 PLAN APPROVED` and whose bounded task/proof evidence is consistent may take the already-complete early return. Convergence must not create or pursue `✅ DONE` itself.

Reject with a precise next action, in this order:

- If `<blocked_file>` exists, stop at that singular operator-action gate. Do not evaluate or offer wrapper/direct choices until the operator resolves the blocker and removes the file.
- If `Status: 🟣 IN REVIEW`, inspect bounded readiness evidence. A named implementation/proof incompleteness routes singularly to `/openspec-story-resume <initiative> <story-slug> [WORKTREE=...]`; a missing anchor or incomplete/non-reviewable contract scaffold routes singularly to `/openspec-story-plan-resume <initiative> <story-slug>` (or story-plan when the workspace is absent); unresolved external evidence routes to one concrete operator action. Say fresh review happens only after repair. Use the singular fresh, oblivious story-review handoff only when review has not yet run against the current evidence and all prerequisites are satisfied.
- If `Status: ✅ DONE` is paired with any non-approved, missing, malformed, or ambiguous `Plan:`, stop with only `Operator action: investigate and reconcile the contradictory durable Status: ✅ DONE and Plan: <value> state before delivery or archive.` Do not recommend planning commands that reject DONE and do not invent a lifecycle owner.
- A non-DONE story with `Plan:` at `🟡 PLAN DRAFT` or `🟣 PLAN IN REVIEW`: offer the planning Converge wrapper plus Non-looped plan-review when the full planning scaffold is structurally reviewable; when the scaffold is incomplete/non-reviewable but `/openspec-story-plan-resume` can safely identify and repair it, route singularly to plan-resume.
- A non-DONE story with an unambiguously absent Plan/Status/log anchor or other safely repairable incomplete/non-reviewable planning scaffold: route singularly to `/openspec-story-plan-resume <initiative> <story-slug>`; plan-converge rejects that entry shape.
- A non-DONE story with `Plan: 🟠 PLAN CHANGES REQUESTED`: unresolved findings use the planning Converge wrapper plus Non-looped plan-resume only when the scaffold is complete/reviewable and plan-converge can orchestrate it; repairable scaffold gaps route singularly to plan-resume. When all findings are fully blended/addressed and the scaffold is structurally reviewable, route to the wrapper plus Non-looped plan-review.
- A non-DONE story with `Plan: ⛔ PLAN BLOCKED`, duplicated/conflicting/malformed/ambiguous/unknown Plan state, or scaffold damage that plan-resume cannot safely resolve: give only the state-owning blocker or concrete operator repair action; do not offer a wrapper/direct choice.
- `Status:` absent, `⬜ TODO`, or `⚪ TODO` with `## Current Claim` already present in `<progress_file>`: status drift; ask the operator to resolve before converging.
- Conflicting, malformed, or ambiguous `Status:` headers: status drift; ask the operator to resolve the `story.md` header before converging.
- `Status: ⛔ BLOCKED` with no `<blocked_file>` is stale status and routes singularly to `/openspec-story-resume` for normalization.

Plan-approved means `Plan:` is `🟢 PLAN APPROVED`. No other source is consulted for the plan state.

Apply this complete qualification rule to every canonical list bullet in `story.md → ## Expected Prerequisites` before any claim/resume launch:

1. Require each dependency slug to match `^[a-z0-9]+(?:-[a-z0-9]+)*$`; malformed values are unsatisfied and must not be interpolated into paths.
2. Resolve active `<openspec_root>/openspec/changes/<prerequisite-slug>/story.md` first. The active copy is authoritative whenever present. Only when absent, fall back to `<openspec_root>/openspec/changes/archive/<prerequisite-slug>/story.md`; never let archived DONE override an active copy.
3. In the resolved prerequisite directory require exactly one unambiguous top-level line `Status: ✅ DONE`. Missing, duplicate, malformed, or non-DONE Status is unsatisfied. A sibling `blocked.md` makes the prerequisite contradictory and unsatisfied in active or archive, regardless of DONE or receipt evidence.
4. Inventory the prerequisite's top-level header region for Initiative-like lines by Phase 1 step 9. Duplicate or malformed Initiative-like fields are contradictory and unsatisfied, never legacy. Exactly one valid canonical `Initiative:` header makes this a bound modern prerequisite.
5. Receipt presence or absence does not and must not affect prerequisite satisfaction. Ignore legacy receipt shape, verdict, identity, duplication, and staleness; never synthesize or normalize receipt material.
6. Bound and accepted legacy prerequisites use the same current-state rule: exact `Status: ✅ DONE`, no sibling `blocked.md`, valid path/binding resolution, and any still-required current task/proof checks.
7. Missing active and archived story files, or any failed gate above, is a singular stop naming the exact prerequisite owner/action, never a claim/resume/review launch. An absent or empty prerequisites section passes automatically.

### Current-state routing

Authoritative Status plus the `blocked.md` gate owns routing. Legacy receipt material is inert: receipt presence, absence, malformed or duplicate shape, verdict, identity, and staleness cannot alter a route and must never be normalized or synthesized here.

- `Status: 🟣 IN REVIEW` enters the repair-or-review branch based on current readiness evidence.
- An exact bound receiptless DONE is lifecycle-valid when Plan and current task/proof evidence are consistent. Stop with completion; stale receipt material cannot force review.

## Phase 3 — Fresh-Agent Loop

Run at most `MAX_CYCLES` cycles. An implementation cycle is one opportunity to move the story toward `Status: 🟣 IN REVIEW`; it may include exactly one implementation-producing claim or resume pass. It never includes an implementation review pass.

Before each subagent launch, build the command line from the current status in the current `<openspec_root>`. If `<openspec_root>` differs from `<workspace_root>`, the fresh implementation subagent must run from `<openspec_root>` so claim/resume resolves the active `openspec/...` artifacts instead of the launch checkout:

- `Status:` absent/unset, `⬜ TODO`, or `⚪ TODO` and plan-approved: `/openspec-story-claim <initiative> <story-slug> [WORKTREE=...]`.
- `Status: 🔄 IN PROGRESS`: `/openspec-story-resume <initiative> <story-slug> [WORKTREE=...]`.
- `Status: 🟣 IN REVIEW`: do not launch review. Apply the IN REVIEW repair-or-review gate above. For named implementation/proof incompleteness, stop with the singular resume owner; for contract or external evidence use its singular owner. Only a ready story not yet reviewed against current evidence stops successfully with result `IN_REVIEW` and the fresh, oblivious review route.
- `Status: ⛔ BLOCKED` with no `<blocked_file>` present and plan-approved: `/openspec-story-resume <initiative> <story-slug> [WORKTREE=...]` to normalize the resolved blocker and continue.
- `Status: ✅ DONE`: do not launch claim or resume. If `Plan:` is not unambiguously `🟢 PLAN APPROVED`, use the singular operator reconciliation action above. Otherwise spot-check bounded task/proof evidence. If it is consistent, stop with result `DONE` because the `story.md` Status header is completion authority. If tasks are unchecked or implementation evidence is stale/incomplete, stop with a singular operator action to reconcile the contradictory durable DONE and current task/proof evidence; never route to the read-only evaluator or resume.

For each cycle:

1. Re-read `<story_file>` and `<progress_file>` from the current `<openspec_root>` before choosing the next pass, and recheck `<blocked_file>` before all status/Plan routing. If it exists, stop at the singular operator-action gate.
2. If the current status is `🟣 IN REVIEW`, execute the repair-or-review branch above before building a slash command; never infer fresh review from status alone. If the current status is `✅ DONE`, execute the DONE Plan/evidence checks above before building a slash command. Otherwise build the exact slash command line for the chosen claim or resume pass.
3. If notebook-backed context is available, do not inline entire notebook pages or broad notebook dumps. Pass only compact notebook references, selectors, and the reason/scope for consulting them before the implementation command under this heading:

   ```text
   Notebook references from parent orchestration session:
   This is allowed cross-session orientation for implementation passes only because every reference points to sourced research or neutral operational context. Use it for orientation only. The converger owns keeping notebook references relevant; executor subagents only decide whether the needed fact is reachable from the referenced selector or compact fallback excerpt. When runtime notebook tools are available, read only the referenced page/entry on demand and verify behavior with direct reads/search against the cited anchors before editing or lifecycle writes instead of rerunning expensive research. When notebook tools are unavailable, use only compact curated excerpts supplied here. If a referenced entry or excerpt does not verify, mention the mismatch with exact anchors in the relevant final-response section.

   - Ref: <notebook page name, entry id, or narrow selector>
     - Purpose: <why this may matter for the implementation pass>
     - Expected anchors: <tool/query/path, file:line, symbol, or command/output excerpt>
     - Lookup: <specific page/entry to read or narrow search to run>
     - Fallback excerpt: <optional compact sourced excerpt only when notebook tools are unavailable>
   ```

   If the useful context cannot be represented as narrow references plus optional compact excerpts, pause and ask the operator before omitting or summarizing it.
4. If in-memory operational notes exist, include them before the implementation command under this heading only:

   ```text
   Operational context from convergence coordinator:
   - <neutral blocker, hotspot, repeated command failure, or expensive operation>
   - Do not treat this as a verdict; apply the underlying skill independently.
   ```

5. End the task prompt with the exact slash command line and, when `<openspec_root>` differs from `<workspace_root>`, an explicit instruction to run it from `<openspec_root>`. Then launch exactly one fresh implementation subagent.
6. Require implementation subagents to write new sourced research directly to the named research notebook page when runtime notebook tools are available. If notebook tools are unavailable, allow compact sourced fallback notes in normal final reporting instead. Require subagents to mention any referenced notebook entry or fallback excerpt that failed verification with exact anchors in their relevant blocker or notes section. After the pass finishes, inspect the named research notebook page or child-reported entries as needed, then use mismatch notes to update, replace, retire, or ask about affected entries. Do not append verdicts, implementation opinions, or unanchored summaries.
7. If the subagent asks an operator question, pause the convergence run, ask the operator, then resume the same subagent for that implementation pass only. The next lifecycle pass still starts in a new fresh subagent.
8. After the pass finishes, treat the subagent final response as provisional, then refresh the active OpenSpec artifact root before any lifecycle spot-check. After every reroot, recompute `<initiative_dir>`, `<initiative_file>`, `<change_dir>`, `<story_file>`, `<progress_file>`, and `<blocked_file>`, and rerun the full exactly-one/malformed/legacy `story.md → Initiative:` binding validation from Phase 1 step 9 under the refreshed root before routing:
   - Run this refresh after every claim pass, and after any resume pass whose reported anchors are missing or whose spot-check would otherwise read stale paths.
   - Inspect all explicit `WORKTREE=` arguments first. If exactly one path is a git checkout containing both `<path>/openspec/initiatives/<initiative>/initiative.md` and `<path>/openspec/changes/<story-slug>/story.md`, set `<openspec_root>` to it and recompute artifact paths before any spot-check. If multiple explicit paths qualify, ask which checkout is active and halt; never guess. Target-repo overrides that lack both artifacts are ignored for OpenSpec-root discovery.
   - Only when no explicit path qualifies, inspect registered root-repo worktrees other than `<workspace_root>` with `git -C <workspace_root> worktree list --porcelain`. A branch candidate qualifies only when it is on `refs/heads/<initiative>/<story-slug>` and contains both required artifact files.
   - If exactly one branch candidate qualifies, set `<openspec_root>` to it and immediately recompute `<initiative_dir>`, `<initiative_file>`, `<change_dir>`, `<story_file>`, `<progress_file>`, and `<blocked_file>` from the new root. That unique branch worktree outranks launch even when launch has matching but stale artifacts. Record a neutral operational note when the root changes: `OpenSpec artifacts moved to root worktree <candidate>; convergence continued from that checkout.` Do not read or route from the old artifact paths afterward.
   - If multiple branch candidates qualify, stop and ask which checkout is active; include the candidate paths and never guess.
   - Only when neither an explicit nor branch candidate qualifies, fall back to `<workspace_root>`. If the launch `<story_file>` or `<progress_file>` is missing after a claim pass, stop with: `OpenSpec artifacts may have moved to a root worktree, but convergence could not locate them. Rerun from the checkout containing openspec/changes/<story-slug>/story.md, or pass WORKTREE="<basename>=<path>" from that checkout.`

   Before routing or stopping, perform a minimal authority spot-check of only the decision-bearing fields and anchors at the refreshed `<openspec_root>`: inventory the full top-level header region so duplicate or malformed Initiative-like lines cannot evade an exact-field grep, then inspect Status/Plan and bounded reads of the newest relevant progress/handoff entry when they matter. Use bounded reads only for the newest relevant progress or handoff entry body. If those spot-checks agree with the agent's report, continue from the canonical fields. If anchors are missing, stale, ambiguous, or conflicting, broaden to targeted reads of the affected file(s) or stop with a concrete operator repair action; do not launch `/openspec-story-review` from this skill.
9. After every claim or resume pass and artifact-root refresh, recheck `<blocked_file>` and rerun the complete prerequisite qualification from Phase 2 against current active-first story/blocked/progress evidence before accepting IN REVIEW, DONE, or any continuation. If the selected blocker exists or any prerequisite is now unsatisfied/contradictory, stop immediately with the singular owner/action; do not launch another implementation or review pass.
10. If the pass leaves the story at `Status: 🟣 IN REVIEW`, stop with result `IN_REVIEW`. Do not launch a review pass in the same cycle.
11. If the pass leaves the story at `Status: 🔄 IN PROGRESS`, continue only when the cycle budget remains and the no-progress gate does not fire.
12. If any pass moves the story to `Status: ⛔ BLOCKED`, stop.
13. If any implementation pass moves the story to `Status: ✅ DONE`, apply the same entry checks: require unambiguous `Plan: 🟢 PLAN APPROVED`, then bounded-check task completion and current implementation/proof evidence rather than confirming only the Status header. A non-approved Plan uses the singular operator reconciliation action; unchecked tasks or stale/incomplete proof use only the singular operator action to reconcile the contradictory durable DONE and current task/proof evidence. Stop with result `DONE` only when all checks are consistent, and note that this command did not create the completion authority.
14. Run the no-progress gate before starting the next cycle.

### Worktree Discovery

When preparing a subagent command line, discover worktrees from the current `<progress_file> → ## Current Claim → - Worktrees:` (plural form with parent bullet), where `<progress_file>` is derived from the refreshed `<openspec_root>`. The legacy singular `- Worktree:` form is accepted by the subagent commands; this converger passes `WORKTREE=` values through unchanged and does not reinterpret them. If no `## Current Claim` exists yet (pre-claim), only explicit `WORKTREE=` arguments from the invocation are passed through.

## Phase 4 — Operational Notes and Stops

Maintain a convergence notebook containing neutral operational notes and sourced research entries for implementation passes only. Do not write notebook content to `initiative.md`, `story.md`, `progress.md`, `blocked.md`, or any coordination file as a duplicate source of lifecycle, proof, or review authority.

Record neutral operational facts only:

- command failures and exact command names;
- test commands that failed because of missing environment or setup;
- worktree or dirty-tree blockers;
- files, symbols, tasks, or acceptance ids repeatedly implicated as implementation hotspots;
- slow commands or broad searches that later fresh implementation agents should not repeat blindly;
- unresolved prior review findings that a resume pass is explicitly addressing.

Do not record persuasive verdict framing. Never tell a later reviewer that a previous reviewer was wrong, that approval is expected, or that a finding should be ignored. The final review handoff must be oblivious: no notebook references, operational notes, implementation summaries, or parent chat context are passed to `/openspec-story-review` by this command.

Sourced notebook references and compact fallback excerpts are allowed cross-subagent research orientation for claim/resume passes. Each referenced entry or excerpt must be sourced by an exact anchor: file path plus line range or symbol, command plus relevant output excerpt, or tool name plus query/action/resource/path/URL and relevant output excerpt for any sourced tool. Notebook entries are an orientation aid, not authority. The converger owns keeping references relevant for later implementation passes; executor subagents only decide whether the needed fact is reachable from the referenced selector or compact excerpt. If present, the executor reads only the relevant notebook page/entry on demand when available and verifies behavior with direct reads/search against the cited anchors before editing or lifecycle writes instead of rerunning expensive research. If absent, the executor follows the underlying skill's normal research rules. If a referenced entry or fallback excerpt does not verify, the executor mentions the mismatch with exact anchors in the relevant final-response section; the converger decides how to update, replace, retire, or ask about that reference. Do not pass broad notebook dumps; if needed context cannot be represented by narrow selectors and compact excerpts, ask the operator before omitting or summarizing it.

Stop early for conservative no-progress when all are true:

- the latest implementation pass did not move the story to `🟣 IN REVIEW`;
- the pass did not add newer progress, handoff, proof-matrix, test, or source changes addressing the open task, blocker, or prior review finding;
- another resume pass would hand the same blocker or finding forward unchanged.

Do not use another broad cycle to compensate for an oversized or under-specified story; route newly discovered contract/risk-lens gaps back to planning.

Other hard stops:

- `MAX_CYCLES` reached;
- latest decision is blocked, or `Status:` is `⛔ BLOCKED` while `blocked.md` still exists;
- `blocked.md` appears in `<change_dir>`;
- story enters an unknown or unsupported status;
- subagent cannot resolve the story, command, or worktree;
- the operator declines an interactive decision required by claim or resume.

## Phase 5 — Commit Recommendation

At the end of the run, inspect the current `<progress_file> → ## Current Claim` when present:

- For each `- Worktrees:` child bullet (`- <repo-basename>: <absolute path>`), run `git -C <path> status --porcelain` when the path exists.
- For `- Main-tree targets:`, run `git status --porcelain` against the corresponding target repo when it can be resolved from `<openspec_root>/projects/<basename>`, `<workspace_root>/projects/<basename>`, `<openspec_root>`, or `<workspace_root>`.
- If dirty changes appear to belong to the story, recommend committing them on the feature branch `<initiative>/<story-slug>`.

Do not commit directly. The recommendation is advisory and must be explicit about whether it is a ready-for-review checkpoint or a WIP checkpoint.

Recommend a ready-for-review checkpoint when:

- the story reached `Status: 🟣 IN REVIEW`;
- implementation proof appears complete enough for independent review;
- worktree changes remain dirty.

Recommend a WIP checkpoint only when stopping at `MAX_CYCLES`, operator input, or no-progress with useful completed changes. Do not recommend a commit when the story blocked before meaningful implementation or no code/test/config changes exist.

When the final authoritative status is `🟣 IN REVIEW`, treat implementation convergence as complete only when bounded readiness evidence has no named repair deficiency and review has not yet run against the current evidence. Then the next lifecycle step is `/openspec-story-review`, run by the operator from a completely fresh, oblivious session rooted at the current `<openspec_root>` if it differs from the launch checkout. If an aborted review preserved IN REVIEW, route to its named repair owner instead and state that fresh review happens only after repair. `/openspec-pr` may be a later delivery helper only after the story is `Status: ✅ DONE`.

When the final authoritative status is `✅ DONE`, treat the story as already locally complete when Plan and current task/proof evidence are consistent. `/openspec-pr` may be a later delivery helper before archive, but it is not the next lifecycle step.

## Phase 6 — Final Response

Return only the compact report below. Do not include internal deliberation, analysis prose, "Thinking:" blocks, private rationale, or comments about what you are considering before or after the report. Include every section in the template; use `None.` or `unavailable` rather than omitting a section.

```markdown
**Convergence Result**: IN_REVIEW | DONE | BLOCKED | STOPPED | MAX_CYCLES
**Initiative**: <initiative-slug>
**Story**: <story-slug>
**Cycles Used**: <n>/<MAX_CYCLES>
**Final Status**: <status>
**OpenSpec Root**: <current openspec_root; say same as launch checkout or absolute path when relocated>
**Change Workspace**: openspec/changes/<story-slug>/

## Trace
- Cycle 1: claim/resume -> <result>
- Cycle 2: ...

## Notebook Context
- References passed: <n>
- Hotspots: <paths/symbols surfaced by sourced research, or none>
- Research notebook updates: <entries added/updated/retired this run, or none>
- Referenced entries verified: <summary or none>
- Stale reference handling: <referenced entries/excerpts not verified, needed facts absent from referenced notebook selectors, or none>
- Persistence: <notebook page references, compact excerpt fallback, runtime-specific notebook pages, or none>; no coordination-file cache written; no notebook or operational context is passed to review

## Commit Recommendation
- <ready-for-review checkpoint, WIP checkpoint, or none>
- Suggested command: `git -C <path> status && git -C <path> add -A && git -C <path> commit -m "<initiative>/<story-slug>: <summary>"`

## Operational Notes
- <neutral operational note>
- None.

## Optional Operator Follow-Ups
- <proposed future improvement surfaced by repeated friction, including recurring risk/miss category worth automating or adding to future planning>
- None.

Suggested next action: <scalar route; leave empty only for a dual route>
- Converge wrapper: <command; dual routes only>
- Non-looped pass: <state-correct claim/resume command; dual routes only>
Choose one; do not run both.
```

Select that block from authoritative final state plus named gate evidence. When result is IN_REVIEW and no repair issue exists, give only this route: open a completely fresh, oblivious session rooted at the current OpenSpec root with no parent/converger notebook references, implementation summaries, operational notes, or prior chat context, then run `/openspec-story-review <initiative> <story-slug> [WORKTREE=...]`. Use it only when review has not yet run against the current ready evidence. If an aborted review preserved IN REVIEW, give only the named implementation/proof, contract, or external-evidence repair owner and say fresh review happens after repair. The wrapper never launches review.

For a scalar route, put its value on the label line and omit the three dual-route lines. For a dual route, leave the label empty and render those three lines immediately after it.

When MAX_CYCLES leaves Status IN PROGRESS, or a clean actionable incomplete lane remains with no unresolved operator question or resolution failure, use the implementation Converge wrapper and Non-looped resume grammar above. Generic STOPPED due to an operator question, declined decision, unresolved command/worktree/root selection, or other resolution failure is singular: state the exact operator action needed and do not also suggest rerunning the wrapper/direct pass.

When result is DONE with approved Plan and consistent task/evidence state, use `None. Story is already ✅ DONE.` A DONE/non-approved-Plan contradiction uses only the operator reconciliation action and names no lifecycle owner. A DONE/task-or-evidence contradiction uses only the singular operator reconciliation action. For BLOCKED, planning-gate, malformed/ambiguous, PR, archive, wait, or terminal routes, give only the state-owning route.

Do not run `/memorize` automatically. If the nice-to-haves are valuable, the operator can decide whether to promote them later.
