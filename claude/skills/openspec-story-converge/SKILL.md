---
name: openspec-story-converge
description: "Run fresh claim/resume implementation passes against one OpenSpec change until it reaches Status: 🟣 IN REVIEW, becomes blocked, or the loop reaches a hard stop. Use when a plan-approved implementation story needs continuation only; independent review is intentionally left to a separate fresh session."
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug> [MAX_CYCLES=5] [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Grep Glob Task Bash(git status:*) Bash(git worktree:*)
---

# OpenSpec Story Converge

Coordinate the implementation-side iteration loop for exactly one OpenSpec change workspace. This command is an orchestrator only: it may start a fresh `/openspec-story-claim` pass for an approved unstarted story, then run fresh `/openspec-story-resume` passes until implementation is ready for independent local review at `Status: 🟣 IN REVIEW`, blocks, no-progress is detected, or the cycle budget is exhausted. It must never launch `/openspec-story-review`, must never pass notebook or implementation-session context to review, and must stop at `🟣 IN REVIEW` with an explicit operator instruction to run review from a completely fresh, oblivious session.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug> [MAX_CYCLES=5] [WORKTREE="<basename>=<path>"]...`. The initiative slug and story slug are required. `MAX_CYCLES` is optional and defaults to `5`; it counts implementation-producing passes, not review attempts. `WORKTREE=` values are passed through unchanged to `/openspec-story-claim` and `/openspec-story-resume`; when stopping at `🟣 IN REVIEW`, preserve them in the final `/openspec-story-review` recommendation.

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
- Implementation review completion is represented by the `Status:` header in `story.md`; optional supporting details may live in notebook `openspec-review-<initiative_slug>-<story_slug>`.

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

1. Parse `$ARGUMENTS`:
   - `<initiative>`: required first positional token.
   - `<story-slug>`: required second positional token.
   - `MAX_CYCLES=<n>`: optional positive integer; default `5`.
   - `WORKTREE="<value>"`: optional, repeatable, passed through unchanged.
2. Reject unknown flags.
3. Set `<workspace_root>` = `<cwd>` and `<openspec_root>` = `<workspace_root>`. There is no persisted `OpenSpec root:` field. `<workspace_root>` remains the launch checkout/root-repo worktree discovery base; `<openspec_root>` is the transient artifact anchor for all `openspec/...` reads.
4. Before reading lifecycle artifacts or making readiness decisions, run the OpenSpec-root preflight:
   - Inspect explicit `WORKTREE="<basename>=<path>"` values first. If exactly one points at a git checkout containing both `openspec/initiatives/<initiative>/initiative.md` and `openspec/changes/<story-slug>/story.md`, set `<openspec_root>=<path>`. This operator-provided root is authoritative. If multiple explicit values qualify, ask the operator which checkout is active and halt; never guess. Explicit target-repo overrides that do not contain both OpenSpec artifacts remain normal pass-through worktree inputs.
   - If no explicit value qualifies, inspect `git -C <workspace_root> worktree list --porcelain` for entries on branch `refs/heads/<initiative>/<story-slug>` that contain both required artifact files. If exactly one valid candidate exists, set `<openspec_root>` to that candidate even when `<workspace_root>` also has matching but possibly stale artifacts. If multiple valid candidates exist, ask the operator which checkout is the active OpenSpec root and halt; never guess.
5. Recompute `<initiative_dir>` = `<openspec_root>/openspec/initiatives/<initiative>` and read `<initiative_dir>/initiative.md`. If missing, ask whether the story was claimed into a root repo worktree and the OpenSpec artifacts were moved there. Recommend rerunning `/openspec-story-converge <initiative> <story-slug> [WORKTREE=...]` from that worktree, or rerunning with an explicit valid root `WORKTREE="<basename>=<path>"`. Abort with: `initiative not found in this checkout`.
6. Resolve `<change_dir>` = `<openspec_root>/openspec/changes/<story-slug>/`.
   - If missing, check `<openspec_root>/openspec/changes/archive/<story-slug>/`.
   - If archived, abort with: `story is archived; move it back to openspec/changes/ first`.
   - If missing in both, ask whether the story was moved to a root repo worktree during claim. Recommend rerunning from the checkout/worktree that contains `openspec/changes/<story-slug>/story.md`, or rerunning with an explicit valid root `WORKTREE="<basename>=<path>"`. Abort with: `change workspace not found in this checkout`.
7. Read `<story_file>` and confirm the `Status:` header field is present (it may be default-valued or unset).
   - If `story.md` is missing or unreadable, ask the same root-worktree relocation question and abort with: `story.md is missing from change workspace`.
8. Keep the exact `WORKTREE=` fragments for later command lines. Do not normalize or reinterpret them in the converger except for the read-only OpenSpec-root preflight above.

## Phase 2 — Eligibility Gate

Use the `Status:` and `Plan:` header fields in `<story_file>` as the authoritative implementation status and planning lane. Check for `blocked.md` as an explicit gate file.

Allowed starting states:

- `Status:` is absent, unset, `⬜ TODO`, or `⚪ TODO` only when the story is plan-approved and the `## Current Claim` section in `<progress_file>` does not exist or is empty.
- `Status: 🔄 IN PROGRESS` only when `Plan:` is `🟢 PLAN APPROVED`.
- `Status: 🟣 IN REVIEW` only when `Plan:` is `🟢 PLAN APPROVED`; this is a successful implementation-convergence stop, not a route to review inside this command.
- `Status: ⛔ BLOCKED` only when `Plan:` is `🟢 PLAN APPROVED` and `<blocked_file>` is absent; this means the explicit gate file was removed and `/openspec-story-resume` must normalize the stale status back to `🔄 IN PROGRESS` before work continues.
- `Status: ✅ DONE` means the story is already complete because `Status: ✅ DONE` in `story.md` is independent completion authority. This is an already-complete early return; convergence must not create or pursue `✅ DONE` itself.

Reject with a precise next action:

- Any non-DONE story whose `Plan:` header field exists and is not `🟢 PLAN APPROVED`: use `/openspec-story-plan-converge <initiative> <story-slug>`.
- `Status:` absent, `⬜ TODO`, or `⚪ TODO` with `## Current Claim` already present in `<progress_file>`: status drift; ask the operator to resolve before converging.
- Conflicting, malformed, or ambiguous `Status:` headers: status drift; ask the operator to resolve the `story.md` header before converging.
- `Status: ⛔ BLOCKED` while `<blocked_file>` exists: blocked stories need operator unblocking before convergence.
- `<blocked_file>` exists at `<change_dir>/blocked.md`: convergence is refused while an explicit gate file exists. The operator may edit it to record resolution notes, but must remove `blocked.md` to unblock. Once the file is removed, stale `Status: ⛔ BLOCKED` is resumable and routes to `/openspec-story-resume` for normalization.

Plan-approved means `Plan:` is `🟢 PLAN APPROVED`. No other source is consulted for the plan state.

## Phase 3 — Fresh-Agent Loop

Run at most `MAX_CYCLES` cycles. An implementation cycle is one opportunity to move the story toward `Status: 🟣 IN REVIEW`; it may include exactly one implementation-producing claim or resume pass. It never includes an implementation review pass.

Before each subagent launch, build the command line from the current status in the current `<openspec_root>`. If `<openspec_root>` differs from `<workspace_root>`, the fresh implementation subagent must run from `<openspec_root>` so claim/resume resolves the active `openspec/...` artifacts instead of the launch checkout:

- `Status:` absent/unset, `⬜ TODO`, or `⚪ TODO` and plan-approved: `/openspec-story-claim <initiative> <story-slug> [WORKTREE=...]`.
- `Status: 🔄 IN PROGRESS`: `/openspec-story-resume <initiative> <story-slug> [WORKTREE=...]`.
- `Status: 🟣 IN REVIEW`: do not launch claim, resume, or review. Stop successfully with result `IN_REVIEW` and route the operator to a fresh, oblivious `/openspec-story-review <initiative> <story-slug> [WORKTREE=...]` session.
- `Status: ⛔ BLOCKED` with no `<blocked_file>` present and plan-approved: `/openspec-story-resume <initiative> <story-slug> [WORKTREE=...]` to normalize the resolved blocker and continue.
- `Status: ✅ DONE`: do not launch claim, resume, or review. Stop with result `DONE` because the `story.md` Status header is completion authority.

For each cycle:

1. Re-read `<story_file>` and `<progress_file>` from the current `<openspec_root>` before choosing the next pass.
2. If the current status is `🟣 IN REVIEW`, execute the successful review-handoff branch above before building a slash command. If the current status is `✅ DONE`, execute the DONE early-return branch above before building a slash command. Otherwise build the exact slash command line for the chosen claim or resume pass.
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
8. After the pass finishes, treat the subagent final response as the provisional result, then refresh the active OpenSpec artifact root before any lifecycle spot-check:
   - Run this refresh after every claim pass, and after any resume pass whose reported anchors are missing or whose spot-check would otherwise read stale paths.
   - Inspect explicit `WORKTREE="<basename>=<path>"` arguments first. If exactly one path is a git checkout containing both `<path>/openspec/initiatives/<initiative>/initiative.md` and `<path>/openspec/changes/<story-slug>/story.md`, it is operator-authoritative for `<openspec_root>`; set `<openspec_root>` to it and recompute artifact paths before any spot-check. If multiple explicit paths qualify, ask the operator which checkout is active and halt; never guess. Target-repo overrides that lack those artifacts are ignored for OpenSpec-root discovery.
   - If no explicit path qualifies, inspect root-repo worktrees with `git -C <workspace_root> worktree list --porcelain`. Find worktree entries on branch `refs/heads/<initiative>/<story-slug>` and consider a candidate active OpenSpec root only when both `<candidate>/openspec/initiatives/<initiative>/initiative.md` and `<candidate>/openspec/changes/<story-slug>/story.md` exist.
   - If exactly one candidate qualifies and differs from `<openspec_root>`, set `<openspec_root>` to that candidate and immediately recompute `<initiative_dir>`, `<initiative_file>`, `<change_dir>`, `<story_file>`, `<progress_file>`, and `<blocked_file>` from the new root. Record a neutral operational note: `OpenSpec artifacts moved to root worktree <candidate>; convergence continued from that checkout.` Do not read or route from the old artifact paths after this point. This reroot also applies when `<workspace_root>` still has matching but stale artifacts.
   - If multiple candidates qualify, stop and ask the operator which checkout is the active OpenSpec root; include the candidate paths. Do not guess.
   - If no candidate qualifies and the current `<story_file>` or `<progress_file>` is missing after a claim pass, stop with: `OpenSpec artifacts may have moved to a root worktree, but convergence could not locate them. Rerun from the checkout containing openspec/changes/<story-slug>/story.md, or pass WORKTREE="<basename>=<path>" from that checkout.`

   Before routing or stopping, perform a minimal authority spot-check of only the decision-bearing fields and anchors at the refreshed `<openspec_root>`: for example, use `rg -n '^(Status:|Plan:)' <story_file>` for lifecycle headers and `rg -n '^(### |Status:)' <progress_file>` only when progress state matters. Use bounded reads only for the newest relevant progress or handoff entry body. If those spot-checks agree with the agent's report, continue from the canonical fields. If anchors are missing, stale, ambiguous, or conflicting, broaden to targeted reads of the affected file(s) or stop with a concrete operator repair action; do not launch `/openspec-story-review` from this skill.
9. If a claim or resume pass leaves the story at `Status: 🟣 IN REVIEW`, stop with result `IN_REVIEW`. Do not launch a review pass in the same cycle.
10. If a claim or resume pass leaves the story at `Status: 🔄 IN PROGRESS`, continue only when the cycle budget remains and the no-progress gate does not fire.
11. If any pass moves the story to `Status: ⛔ BLOCKED`, stop.
12. If any implementation pass moves the story to `Status: ✅ DONE`, run a bounded spot-check confirming the refreshed `story.md` header is `Status: ✅ DONE`, then stop with result `DONE` and note that this command did not create the completion authority.
13. If `<blocked_file>` appears in `<change_dir>` at any point during the convergence run, stop immediately.
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

When the final authoritative status is `🟣 IN REVIEW`, treat implementation convergence as complete. The next lifecycle step is `/openspec-story-review`, but it must be run by the operator from a completely fresh, oblivious session rooted at the current `<openspec_root>` if it differs from the launch checkout. `/openspec-pr` may be a later delivery helper only after review marks the story `Status: ✅ DONE`.

When the final authoritative status is `✅ DONE`, treat the story as already locally complete due to independent review authority that existed outside this convergence loop. `/openspec-pr` may be a later delivery helper before archive, but it is not the next lifecycle step.

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

## Next Action
- <single concrete command or decision. When result is IN_REVIEW: open a completely fresh, oblivious session rooted at the current OpenSpec root with no parent/converger notebook references, implementation summaries, operational notes, or prior chat context, then run `/openspec-story-review <initiative> <story-slug> [WORKTREE=...]`. When result is DONE: `None. Story is already ✅ DONE.`>
```

Do not run `/memorize` automatically. If the nice-to-haves are valuable, the operator can decide whether to promote them later.
