---
name: openspec-story-plan-converge
description: Run fresh plan-review and plan-resume sessions against one OpenSpec change until its Plan lane is approved, blocked, or the loop reaches a hard stop. Use when a story needs repeated independent plan feedback and feedback absorption before implementation or rework continues.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug> [MAX_CYCLES=5]"
allowed-tools: Read Edit Grep Glob Task Bash(git status:*) Bash(git worktree list:*) Bash(git -C:* remote get-url --all origin) Bash(printf:*) Bash(sha256sum:*)
---

# OpenSpec Story Plan Converge

Coordinate the planning-side iteration loop for exactly one OpenSpec change workspace, independent of implementation status. This command is an orchestrator only: it starts fresh subagent sessions for `/openspec-story-plan-review` and `/openspec-story-plan-resume`, preserves their ownership boundaries, keeps parent-session notebook context with sourced research plus neutral operational notes, and stops when the Plan lane is approved, blocked, no longer eligible, or out of cycle budget.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug> [MAX_CYCLES=5]`. The initiative slug and story slug are required. `MAX_CYCLES` is optional and defaults to `5`; it counts full review/resume cycles, not individual subagents.

## Workflow
1. Resolve the requested initiative and change workspace through `openspec/initiatives/<slug>/initiative.md` and `openspec/changes/<story-slug>/story.md`.
2. Confirm the story is non-archived and has a planning contract that can be reviewed or resumed.
3. Choose the first planning pass from the story shape: resume first for incomplete specs, otherwise review first.
4. Run up to `MAX_CYCLES` fresh-agent planning cycles.
5. Pass copied compact sourced records, plus neutral operational notes, into later fresh agents.
6. Stop on approval, blocker, no-progress, invalid state, or cycle budget exhaustion.
7. Print the convergence trace, notebook context summary, and optional operator follow-ups without writing coordination files directly.

## Resolution Model

- `<workspace_root>` = `<cwd>` and remains the worktree-discovery base.
- `<repository_key>`: When notebook orientation or persistence is available and selected, Repository-key-v1 is exact: after each root resolution/reroot, run `git -C <openspec_root> remote get-url --all origin` and strictly decode every output line as UTF-8. Accept only `(ssh|http|https|git)://[userinfo@]host[:port]/path` URI semantics or SCP `[user@]host:path` (bracketed IPv6 allowed); reject missing output, local/file/other schemes, empty host/path, query/fragment, malformed escapes/UTF-8, controls, backslashes, invalid ports, repeated/empty or `.`/`..` path segments, and absolute SCP paths. Strictly percent-decode URI paths and normalize Unicode to NFC; lowercase only DNS host (RFC 5952 for IPv6), remove userinfo, omit default ports (ssh/SCP 22, http 80, https 443, git 9418), retain a nondefault decimal port, remove the URI structural leading slash and all terminal slashes, remove exactly one case-sensitive terminal `.git`, and preserve path case. The identity is `host[:port]/full/owner/path/repository`; all origin URLs must normalize identically. Only when notebook orientation or persistence is available and selected, hash exactly its UTF-8 bytes with no newline by command: run `printf %s "$normalized_identity" | sha256sum`, require the full lowercase hexadecimal SHA-256 from stdout, and set `<repository_key>` to `repo-v1-` plus that digest. Never estimate or manually produce the hash. If origin output is missing, differing, or invalid, disable/skip optional notebook use and continue the canonical artifact workflow; if a notebook operation was selected, fail closed for that notebook operation only. Reroot key drift likewise disables further notebook access without changing artifact authority. Never use checkout or per-run values.
- `<openspec_root>` starts as `<workspace_root>` and is the transient artifact anchor selected during resolution; never persist an `OpenSpec root:` field.
- `<initiative_dir>` = `<openspec_root>/openspec/initiatives/<initiative>`.
- `<initiative_file>` = `<initiative_dir>/initiative.md`.
- `<change_dir>` = `<openspec_root>/openspec/changes/<story-slug>`.
- `<story_file>` = `<change_dir>/story.md`.
- `<progress_file>` = `<change_dir>/progress.md`.
- The `Plan:` header field in `<story_file>` is the authoritative planning lane.
- The `Status:` header field in `<story_file>` is the authoritative implementation lane.
- The `## Plan Review Log` section in `<story_file>` is the authoritative review history.
- New workspaces created by `/openspec-story-plan` must seed the convergence scaffold: `Plan: 🟡 PLAN DRAFT`, `Status: ⚪ TODO`, exactly one top-level `Initiative: <initiative-slug>` binding, and an empty `## Plan Review Log` section.

There is no `MASTER.md`, no tracker table, no step/number row, and no implementation Status column in this flow. The change workspace is self-contained under `openspec/changes/<story-slug>/`.

## Phase 1 — Parse and Resolve

1. Parse `$ARGUMENTS`:
   - `<initiative>`: required first positional token.
   - `<story-slug>`: required second positional token.
   - `MAX_CYCLES=<n>`: optional positive integer; default `5`.
2. Reject unknown flags. This command does not accept `WORKTREE=` because planning may read source code for evidence but never writes source code.
3. Validate `<initiative>` and `<story-slug>` before resolving paths. Each must match `^[a-z0-9]+(?:-[a-z0-9]+)*$`; if either fails, abort with: `invalid slug; use lowercase hyphenated slug characters only`.
4. Set `<workspace_root>` = `<cwd>` and `<openspec_root>` = `<workspace_root>`, then run `git worktree list --porcelain` from `<workspace_root>`. This planning command accepts no `WORKTREE=` selector, so resolve the remaining tiers in order: inspect registered worktrees other than `<workspace_root>` on `refs/heads/<initiative>/<story-slug>` and require both `openspec/initiatives/<initiative>/initiative.md` and `openspec/changes/<story-slug>/story.md`. Exactly one qualifying branch worktree outranks launch even when launch has stale matching artifacts; multiple qualifying branch worktrees halt for operator selection. Only when no branch worktree qualifies, fall back to `<workspace_root>` and require both artifacts there. Ignore unrelated/non-branch worktree copies; never select an arbitrary root merely because it contains the same slug. Recompute every artifact path from `<openspec_root>`.
5. Resolve `<initiative_file>` = `<openspec_root>/openspec/initiatives/<initiative>/initiative.md`.
   - If missing, abort with the exact path and `/openspec-initiative-plan` recovery.
6. Resolve `<change_dir>` = `<openspec_root>/openspec/changes/<story-slug>/`.
   - If absent, check `<openspec_root>/openspec/changes/archive/<story-slug>/`; if archived, halt and require moving it back first.
   - If absent from both after worktree discovery, rule out relocation, then abort with the singular creation route `/openspec-story-plan INITIATIVE=<initiative>`. The converger never sends a nonexistent workspace to plan-resume.
7. Resolve `<story_file>` = `<change_dir>/story.md`. If it is missing or unreadable, halt with the exact path and require the operator to restore it from version control or backup; do not route a colliding incomplete workspace to story creation.
8. Validate the durable initiative binding before lifecycle or scaffold routing:
   - Inventory the complete top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line. Exactly one present line is valid only when its whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`. Duplicate canonical headers, an empty value, whitespace before the colon (for example `Initiative : foo`), a non-canonical value, or any other malformed Initiative-like line halts without editing or launching a child and reports every offending line. Never reinterpret malformed present input as zero-header legacy.
   - The one valid header must equal `<initiative>`. On an Initiative mismatch, halt and report both values; do not proceed.
   - This command's two required positional slugs are an operator-explicit initiative+story pair. Only zero Initiative or Initiative-like lines is legacy. For that case, scan active `<openspec_root>/openspec/initiatives/*/initiative.md` files for exact `<story-slug>` associations in `## Story Candidates`. With no associations, the explicit pair may target the legacy story because the selected initiative file exists. With candidate evidence, continue only when exactly one association exists and it equals `<initiative>`; a different or multiple association conflicts and halts. Print a compatibility warning and never backfill the header. An auto-defaulted or menu-selected initiative alone would not be an explicit pair and could not authorize this zero-reference fallback.
9. Check `<change_dir>/blocked.md` before reading lifecycle fields or scaffold routing. If it exists, abort with the singular operator action to resolve the blocker and remove the file; do not offer wrapper/direct choices.
10. Read `<story_file>`.
   - Read `Status:` first. If it is `✅ DONE`, defer all Plan/scaffold routing to the DONE gate in Phase 2; never recommend plan-resume/review for a completed story.
   - If it is `🟣 IN REVIEW`, defer every Plan/scaffold decision to the Phase 2 hard stop. This converger never launches a planning child from IN REVIEW; only the direct story-plan-resume repair route may handle a named contract/scaffold defect while preserving IN REVIEW.
   - For every other non-DONE status, confirm the `Plan:` header field, `Status:` header field, and `## Plan Review Log` section are present. A legacy story may remain without `Initiative:` only under step 8's bounded fallback. `Plan:` and `## Plan Review Log` may be default-valued or empty.
   - If a repairable scaffold anchor is missing, abort with the singular recovery route: `story.md is missing the /openspec-story-plan convergence scaffold — run /openspec-story-plan-resume <initiative> <story-slug> to repair missing Plan:, Status:, or ## Plan Review Log anchors.` Re-check authoritative state after repair; do not pre-offer a wrapper choice for missing, incomplete, malformed, or non-reviewable scaffold.

## Phase 2 — Eligibility Gate

Before starting the loop, abort with a clear next action if any condition is true, in this order:

- A `blocked.md` file exists at `<change_dir>/blocked.md`: enforce the Phase 1 hard singular operator-action gate; never offer wrapper/direct choices first.
- The implementation `Status:` header is `🟣 IN REVIEW`: always stop before the planning loop and never launch plan-review, plan-resume, implementation work, or review. For a named implementation/proof deficiency, offer the implementation choice—Converge wrapper `/openspec-story-converge <initiative> <story-slug>` or Non-looped pass `/openspec-story-resume <initiative> <story-slug>`—and say fresh review follows repair. For a named planning-contract or scaffold deficiency, give only the executable direct repair route `/openspec-story-plan-resume <initiative> <story-slug>`; when all structural sections are present and no Plan Review Log finding is pending, include the verified current planning-artifact selector as `REPAIR_REF=<planning-path>#<anchor>` so Mode C is reachable without prior-chat authority. That owner performs planning-contract/scaffold-only repair, preserves `Status: 🟣 IN REVIEW`, and returns the operator to fresh oblivious review without launching it. Do not recommend this wrapper or plan-review for that route. For unresolved external evidence, give one concrete operator action. Only when no repair condition exists and review has not run against the current ready evidence use the singular fresh, oblivious `/openspec-story-review <initiative> <story-slug>` handoff.
- The implementation `Status:` header field in `story.md` is `✅ DONE`: completed stories are not contract-reviewed or contract-reworked in place. Inventory all `<progress_file> → ## Implementation Review Receipt` headings. When any receipt is present, require exactly one section/body with every canonical required field exactly once, `Decision: APPROVE`, `Approval gate: PASS`, and a `Status transition` ending in `✅ DONE`; duplicate, truncated, malformed, contradictory, stale, or non-approving content routes only to `Open a completely fresh, oblivious session and run /openspec-story-review <initiative> <story-slug>.` Receipt absence is legacy compatibility only for a true unbound pre-v3 story with zero Initiative or Initiative-like header lines and zero receipt sections: warn and do not synthesize one. A bound modern DONE story without a receipt routes to the same fresh oblivious review, never legacy compatibility. After that receipt gate, if `Plan:` is anything other than unambiguous `🟢 PLAN APPROVED`, stop with only `Operator action: investigate and reconcile the contradictory durable Status: ✅ DONE and Plan: <value> state before delivery or archive.` Do not recommend planning commands that reject DONE and do not invent a lifecycle owner. If the receipt qualifies but bounded task/evidence state still contradicts DONE, use the same executable fresh-review route; never resume. Only a consistent DONE with approved Plan and a qualifying receipt or the exact zero-Initiative/zero-receipt pre-v3 exception routes new feedback through `/openspec-feedback` as a candidate, initiative-level decision, defer/reject entry, or explicit lifecycle reopen decision.
- Before any approved Plan/log shortcut, validate the current required `/openspec-story-plan` scaffold and artifact shape expected by `/openspec-story-plan-review`: required spec sections, unambiguous Plan/Status/log anchors, and current `proposal.md`, `design.md`, and `tasks.md`. If repairable shape drift exists, stop with `/openspec-story-plan-resume <initiative> <story-slug>`; a genuinely absent workspace already routed to `/openspec-story-plan INITIATIVE=<initiative>` in Phase 1. If the story is so malformed that plan-resume cannot identify spec sections to continue, use the singular operator action to restore planning artifacts from version control/backup or remove the invalid workspace before creating it again.
- Only after that scaffold/artifact-shape gate passes, if the `Plan:` header field is `🟢 PLAN APPROVED`, there are no unresolved `## Plan Review Log` findings, and the log contains at least one entry with `Verdict: approve` (or a legacy equivalent) from an independent `/openspec-story-plan-review` pass, stop successfully; planning is already complete. Route by authoritative implementation `Status:` using the implementation choice below for TODO/IN PROGRESS, the singular fresh oblivious review route for IN REVIEW, and singular state-owner routes otherwise.
- Only after that scaffold/artifact-shape gate passes, if the `Plan:` header field is `🟢 PLAN APPROVED` but `## Plan Review Log` is empty or lacks an approve entry, treat it as orphaned approval. Set `Plan:` to `🟠 PLAN CHANGES REQUESTED` and route through the normal review cycle.
- The `Plan:` header field is `⛔ PLAN BLOCKED`: stop with blocked status. The operator must resolve the blocker before convergence can proceed.

The planning-lane authority is the `Plan:` header field in `story.md`. No other source is consulted for the plan state.

## Phase 3 — Fresh-Agent Loop

Run at most `MAX_CYCLES` cycles. A planning cycle is one opportunity to get the plan approved; depending on current story shape it may include one fresh `/openspec-story-plan-resume` pass and one fresh `/openspec-story-plan-review` pass.

For each cycle:

1. Re-read `<initiative_file>` and `<story_file>` and recheck `<change_dir>/blocked.md` before choosing the next pass. If the blocker file exists, stop with the singular operator action before launching a child.
2. Optional notebook orientation happens now, before child-prompt dispatch. Only when notebook-backed context is available, useful, and selected, first revalidate the current root's repository-key-v1, read the whole stable page through the available runtime notebook facility, select bounded entries, and copy records with exactly `Ref`, `Purpose`, `Expected anchors`, and `Lookup`; `Lookup` is selected content, never a retrieval instruction. Separately prepare at most one `Neutral ops payload:`. If notebook support is absent or not selected, skip this step without changing canonical workflow behavior.
3. After optional extraction, build the fresh child task prompt in this order: copied compact sourced records when present, the separate neutral ops payload when present, then runtime dispatch. Child mode must apply the owning plan-review/plan-resume workflow, prohibit nested child launch and optional-record tools, ignore runtime-supplied notebook index/preview material, research inline, and consume only records already copied into the prompt. Runtime adapters own their available dispatch mechanics; native command expansion may put the exact slash command on the final line. Never make notebook work a prerequisite for dispatch.
4. If a newer unaddressed plan-review finding exists (a `request_changes` or `not_reviewable` entry in `## Plan Review Log` without a matching addressed entry), select Mode A and capture the exact pre-resume snapshot immediately before launch: the full newest unresolved finding and timestamp, current `Plan:`, every affected authoritative artifact/section named by the finding, and current blocker state. Then launch one fresh plan-resume child with the step 3 prompt. The native-command form is:

   ```text
   /openspec-story-plan-resume <initiative> <story-slug>
   ```

   If it asks an operator question, pause, ask the operator, then resume that same child for this pass only. Immediately after it finishes, before any plan-review launch or other lifecycle dispatch, hold all returned notebook proposals and mismatch notes in memory. Refresh worktree/root resolution, recompute every artifact path, revalidate the durable initiative/story binding, re-read the refreshed authoritative artifacts, and recheck `blocked.md`. Then run the Mode A gate against the captured snapshot: require a matching newer addressed-log entry plus targeted edits in every affected authoritative artifact/section. Missing, ambiguous, unchanged, or incomplete evidence stops; it never launches plan-review. Only after this artifact gate passes, and only if optional notebook persistence remains available and selected, rederive repository-key-v1 from the refreshed root and require exact equality with the pre-launch key. Key failure or drift skips the optional merge. Equality permits a fresh whole-page read followed by one read-modify-write merge that preserves unrelated entries and applies accepted proposals/stale-record updates.
5. Else if required spec sections are missing or structurally incomplete and there is no newer unaddressed plan-review finding, select Mode B and capture the exact pre-resume snapshot immediately before launch: current `Plan:`, every missing/incomplete required section and scaffold artifact, their bounded contents/absence, and current blocker state. Launch one fresh plan-resume child with the step 3 prompt. Immediately after it finishes, before any plan-review launch or other lifecycle dispatch, hold all returned notebook proposals and mismatch notes in memory; refresh worktree/root resolution and every artifact path; revalidate the durable binding; re-read refreshed artifacts; and recheck `blocked.md`. Then run the Mode B gate against the captured snapshot: require every named gap repaired and the resulting scaffold structurally review-ready. Missing, ambiguous, unchanged, or incomplete evidence stops; it never launches plan-review. Only after this artifact gate passes may selected optional persistence rederive and require the same repository-key-v1, then freshly read and read-modify-write the stable page; failure or drift skips that merge.
6. Only after any applicable immediate Mode A or Mode B post-resume gate has passed, and when refreshed artifacts show no unaddressed findings and a review-ready story, prepare and launch one fresh plan-review child with the step 3 prompt. The native-command form is:

   ```text
   /openspec-story-plan-review <initiative> <story-slug>
   ```

   On return, hold proposals and mismatch notes in memory. Before accepting chat or merging anything, refresh root/worktree resolution, recompute and revalidate every artifact path and durable binding, re-read refreshed authority, and recheck `blocked.md`. Only then may selected optional persistence rederive and require the same repository-key-v1, freshly read the whole stable page, and perform a preserving read-modify-write merge; failure or key drift skips the optional merge.
7. Require every child to return only proposed new sourced entries and exact-anchor stale-record notes; children never overwrite shared notebook pages. Never pass whole pages, broad retrieval instructions, fallback excerpts, a second ops channel, or selectors requiring notebook access. Do not persist verdicts, implementation opinions, or unanchored summaries.
8. After the review agent finishes, treat its final response as provisional and first recheck `<change_dir>/blocked.md`. If it exists, stop with the singular operator action before accepting approval, launching repair, or continuing. Then perform a minimal authority spot-check against `<story_file>` with the Grep tool pattern `^(Plan:|## Plan Review Log|### |Verdict:)` to fetch the `Plan:` header, log anchors, and verdict markers, then use a bounded read only for the newest log entry body if needed. If the spot-check agrees with the agent's report, continue from those decision-bearing fields. If the anchors are missing, stale, ambiguous, or conflicting, broaden to a targeted story read or launch a focused repair/review pass.
9. If the decision is `approve` or `Plan:` is `🟢 PLAN APPROVED`, confirm the latest story `## Plan Review Log` records activated risk lenses or explicit `none material` and sufficient risk/evidence output with the same minimal spot-check/bounded-read approach. If approval lacks that evidence, launch exactly one fresh plan-review child focused on the missing risk/evidence coverage rather than accepting chat output alone.
    - Immediately after that focused child, recheck `<change_dir>/blocked.md`. If it exists, stop with the singular operator action; do not accept approval or launch repair first.
    - Then re-read the authoritative Plan status from the `Plan:` header, the newest review verdict/log entry in `## Plan Review Log`, blocker state (`blocked.md`, blocked Plan/verdict, and any recorded blocker), and the focused risk-evidence output from durable story/log evidence. The child's chat summary is provisional and cannot satisfy this re-read.
    - Stop with `APPROVED` only when the refreshed `Plan:` remains `🟢 PLAN APPROVED`, the newest durable verdict remains `approve`, no blocker exists, and the previously missing risk/evidence is now sufficient.
    - If the refreshed verdict is `request_changes` or `not_reviewable`, or `Plan:` is `🟠 PLAN CHANGES REQUESTED`, route through step 11 to a fresh plan-resume child when the scaffold remains complete/reviewable; if the finding made the scaffold non-reviewable, stop with the singular `/openspec-story-plan-resume <initiative> <story-slug>` owner route.
    - If the refreshed verdict or `Plan:` is blocked, stop with the singular blocker-resolution route.
    - If the focused child leaves the same risk/evidence deficiency unchanged, do not report approval and do not launch another focused review. Stop for no progress with the singular `/openspec-story-plan-resume <initiative> <story-slug>` route to repair the named deficiency; fresh plan review occurs only after repair.
    - If the refreshed fields are missing, ambiguous, or conflict, stop with a concrete singular operator repair action rather than guessing.
    Only after the approval conditions above pass, stop successfully. Do not claim or resume the story. Recommend `/openspec-story-claim <initiative> <story-slug>` or `/openspec-story-resume <initiative> <story-slug>` to begin implementation.
10. If the decision is `blocked` or `Plan:` is `⛔ PLAN BLOCKED`, stop with blocked planning status.
11. If the decision is `request_changes` or `not_reviewable`, select Mode A and capture the exact pre-resume snapshot immediately before launch: the full newest unresolved finding and timestamp, current `Plan:`, every affected authoritative artifact/section named by the finding, and blocker state. Then prepare and launch a different fresh plan-resume subagent using the step 3 dispatch contract; if selected optional records need refreshing, repeat step 2 before building that prompt. The native-command form is:

    ```text
    /openspec-story-plan-resume <initiative> <story-slug>
    ```

12. If the resume agent asks an operator question, pause, ask the operator, then resume that same subagent for this pass only. Immediately after the resume finishes, before any next-cycle plan-review launch or other lifecycle dispatch, hold returned proposals and mismatch notes in memory, refresh root/worktree resolution and every artifact path, revalidate the durable binding, re-read the refreshed authoritative artifacts, and recheck `blocked.md`. Run the Mode A gate against the captured snapshot. Require the matching newer addressed-log entry and targeted edits in every affected authoritative planning artifact/section; a mandatory line anchor or one section alone is insufficient. Missing, ambiguous, unchanged, or incomplete exact pre/post evidence fails and stops. Only after the artifact gate passes may selected optional persistence rederive and require the same repository-key-v1, then freshly read and perform a preserving read-modify-write merge; failure or key drift skips that merge. Never launch another review from only `blocked.md` plus `Plan:`.
13. Run the no-progress gate immediately after the applicable post-resume mode gate and before the next cycle.

## Phase 4 — Operational Notes and Stops

Only when compact-record notebook orientation or persistence is available and selected, derive repository-key-v1 after root resolution/reroot and require equality before that optional operation. Missing/invalid origin or key drift disables notebook use while canonical artifacts continue authoritatively. When enabled, maintain exactly `openspec-plan-research-<repository_key>-<initiative_slug>-<story_slug>` and `openspec-plan-ops-<repository_key>-<initiative_slug>-<story_slug>`. The convergence coordinator is the single coordinator writer for these shared pages; children report proposed updates rather than overwriting them. Before every write, read the current whole page, perform read-modify-write, preserve all active entries and unrelated content, and write the complete merged page. Use explicit in-page retirement tombstones and in-page compaction of superseded entries while retaining provenance. Never create per-run pages, assume deletion/reset, or rely on notebook topic inheritance/namespacing. Do not write notebook content or the transient `<openspec_root>` value to `story.md`, `initiative.md`, `progress.md`, or any coordination file as a duplicate source of lifecycle, proof, review, or root authority.

Record neutral operational facts only:

- command failures and their exact command names;
- missing environment or worktree prerequisites;
- story sections or proof rows that repeatedly block progress;
- files or concepts that multiple agents identify as hotspots;
- time-consuming operations that later fresh agents should avoid repeating blindly.

Do not record persuasive verdict framing. Never tell a later reviewer that a previous reviewer was wrong, that approval is expected, or that a finding should be ignored.

Copied compact sourced records built by the coordinator after a whole-page read are the only cross-subagent notebook orientation. Each record has an exact anchor and selected content. Notebook entries are orientation, not authority. The executor never retrieves notebook pages and verifies supplied anchors directly before editing or approving. It reports mismatches with exact anchors so the converger can update, replace, retire, or ask. Do not pass broad dumps, fallback excerpts, bare page names, or retrieval references/instructions.

Stop early for conservative no-progress when all are true:

- the latest review requested changes or said not reviewable;
- the subsequent Mode A resume pass did not add a matching newer addressed-feedback entry and materially edit the authoritative planning artifacts/every affected section identified by the finding, or the Mode B pass did not repair every named structural gap;
- the same blocker or finding would be handed to another review unchanged.

Do not use repeated cycles to paper over an under-specified or over-large story; newly discovered risk-lens or proof-contract gaps must be edited into the story contract or explicitly excluded.

Other hard stops:

- `MAX_CYCLES` reached;
- latest decision is `blocked`;
- `blocked.md` appears in `<change_dir>` during the convergence run;
- subagent cannot resolve the story or command;
- the operator declines an interactive decision required by resume.

## Phase 5 — Final Response

Return only the compact report below. Do not include internal deliberation, analysis prose, "Thinking:" blocks, private rationale, or comments about what you are considering before or after the report. Include every section in the template; use `None.` or `unavailable` rather than omitting a section.

```markdown
**Convergence Result**: APPROVED | BLOCKED | STOPPED | MAX_CYCLES
**Initiative**: <initiative-slug>
**Story**: <story-slug>
**Cycles Used**: <n>/<MAX_CYCLES>
**Final Plan Lane**: <plan>
**Change Workspace**: openspec/changes/<story-slug>/

## Trace
- Cycle 1: plan-review -> <decision>; plan-resume -> <completed/skipped>
- Cycle 2: ...

## Notebook Context
- Copied compact records passed: <n>
- Hotspots: <paths/symbols surfaced by sourced research, or none>
- Research notebook updates: <entries added/updated/retired this run, or none>
- Copied/supplied records verified: <summary or none>
- Stale record handling: <supplied compact records not verified or none>
- Persistence: <stable notebook page updates or compact records passed, or none>; no coordination-file cache written

## Operational Notes
- <neutral operational note>
- None.

## Optional Operator Follow-Ups
- <proposed future improvement surfaced by repeated friction, including recurring risk/miss category worth automating or adding to future planning>
- None.

Suggested next action: <scalar route; leave empty only for a dual route>
- Converge wrapper: <command; dual routes only>
- Non-looped pass: <state-correct review/resume or claim/resume command; dual routes only>
Choose one; do not run both.
```

Select that block from authoritative final state. When APPROVED and implementation is TODO or IN PROGRESS, offer **Converge wrapper:** `/openspec-story-converge <initiative> <story-slug>` and **Non-looped pass:** TODO -> `/openspec-story-claim <initiative> <story-slug>`, IN PROGRESS -> `/openspec-story-resume <initiative> <story-slug>`. Say to choose one and not run both because the wrapper delegates direct claim/resume passes.

For a scalar route, put its value on the label line and omit the three dual-route lines. For a dual route, leave the label empty and render those three lines immediately after it.

When MAX_CYCLES leaves a valid, complete/reviewable planning lane active without an unresolved operator question/resolution failure, use the planning Converge wrapper plus Non-looped plan-review when no unresolved finding remains, or Non-looped plan-resume when findings remain and converge can orchestrate that lane. `Plan: 🟠 PLAN CHANGES REQUESTED` with unresolved findings uses plan-resume when the scaffold stays complete/reviewable; when every finding is fully blended/addressed and the scaffold is reviewable, it uses fresh plan-review. Missing anchors or any incomplete/non-reviewable scaffold always use singular `/openspec-story-plan-resume <initiative> <story-slug>` (or story-plan when the workspace is absent), never the wrapper.

Generic STOPPED due to an operator question, declined decision, unresolved command/story resolution, unchanged focused risk/evidence deficiency, or other resolution failure is singular: state the exact operator or repair-owner action needed and do not also suggest rerunning the wrapper/direct pass. When implementation Status is IN REVIEW, never launch planning review/resume: implementation/proof rework may use the implementation converge/resume choice, while a named contract/scaffold defect routes only to direct `/openspec-story-plan-resume <initiative> <story-slug>` for planning-contract/scaffold-only repair that preserves IN REVIEW and returns to operator-run fresh review; external-evidence defects require one explicit operator action. Fresh oblivious `/openspec-story-review` is valid only when no repair remains and review has not run against current ready evidence. DONE with a non-approved Plan uses only the operator action to investigate/reconcile the contradictory durable state and names no lifecycle owner. For BLOCKED, incomplete/non-reviewable scaffold outside IN REVIEW, malformed/ambiguous, DONE with consistent evidence, DONE/evidence contradiction, PR, archive, wait, or terminal states, give only the state-owning singular route.

Do not run `/memorize` automatically. If the nice-to-haves are valuable, the operator can decide whether to promote them later.
