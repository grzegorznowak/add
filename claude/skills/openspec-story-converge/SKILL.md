---
name: openspec-story-converge
description: Run fresh claim/resume implementation passes against one OpenSpec change until it reaches Status: 🟣 IN REVIEW, becomes blocked, or the loop reaches a hard stop. Use when a plan-approved implementation story needs continuation only; independent review is intentionally left to a separate fresh session.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug> [MAX_CYCLES=5] [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Grep Glob Task Bash(git status:*) Bash(git worktree:*)
---

# OpenSpec Story Converge

Coordinate the implementation-side iteration loop for exactly one OpenSpec change workspace. This command is an orchestrator only: it may start a fresh `/openspec-story-claim` pass for an approved unstarted story, then run fresh `/openspec-story-resume` passes until implementation is ready for independent local review at `Status: 🟣 IN REVIEW`, blocks, no-progress is detected, or the cycle budget is exhausted. It must never launch `/openspec-story-review`, must never pass notebook or implementation-session context to review, and must stop at `🟣 IN REVIEW` with an explicit operator instruction to run review from a completely fresh, oblivious session.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug> [MAX_CYCLES=5] [WORKTREE="<basename>=<path>"]...`. The initiative slug and story slug are required. `MAX_CYCLES` is optional and defaults to `5`; it counts implementation-producing passes, not review attempts. `WORKTREE=` values are passed through unchanged to `/openspec-story-claim` and `/openspec-story-resume`; when stopping at `🟣 IN REVIEW`, preserve them in the final `/openspec-story-review` recommendation.

## Resolution Model

- `<workspace_root>` = `<cwd>`.
- `<initiative_dir>` = `<workspace_root>/openspec/initiatives/<initiative>`.
- `<initiative_file>` = `<initiative_dir>/initiative.md`.
- `<change_dir>` = `<workspace_root>/openspec/changes/<story-slug>`.
- `<story_file>` = `<change_dir>/story.md`.
- `<reviews_file>` = `<change_dir>/reviews.md`.
- `<progress_file>` = `<change_dir>/progress.md`.
- `<blocked_file>` = `<change_dir>/blocked.md`.

There is no `MASTER.md` and no tracker table. All status is self-contained in the change workspace artifacts:

- The `Status:` header field in `<story_file>` is the authoritative implementation status.
- The `Plan:` header field in `<story_file>` is the authoritative planning lane.
- The `## Current Claim` section in `<progress_file>` records active implementation state and worktree bindings.
- The `## Review Log` equivalent for implementation reviews is the standalone `<reviews_file>` artifact.

## Workflow
1. Resolve the requested initiative and change workspace through `openspec/initiatives/<slug>/initiative.md` and `openspec/changes/<story-slug>/story.md`.
2. Choose the first implementation pass from the story's current status, or stop immediately when it is already `🟣 IN REVIEW` / `✅ DONE`.
3. If an unstarted story is plan-approved, delegate claiming to `/openspec-story-claim <initiative> <story-slug>`.
4. Run up to `MAX_CYCLES` fresh-agent implementation cycles (`claim` once when needed, then `resume` as needed).
5. Pass compact notebook references for sourced research, plus neutral operational notes, into later implementation agents only.
6. Stop when the story is ready for independent review, blocked, no-progress is detected, invalid state is found, or the cycle budget is exhausted.
7. Print the convergence trace, notebook context summary, commit recommendation, and optional operator follow-ups without writing coordination files directly.

## Phase 1 — Parse and Resolve

1. Parse `$ARGUMENTS`:
   - `<initiative>`: required first positional token.
   - `<story-slug>`: required second positional token.
   - `MAX_CYCLES=<n>`: optional positive integer; default `5`.
   - `WORKTREE="<value>"`: optional, repeatable, passed through unchanged.
2. Reject unknown flags.
3. Set `<workspace_root>` = `<cwd>` and resolve `<initiative_dir>` = `<workspace_root>/openspec/initiatives/<initiative>`.
4. Read `<initiative_dir>/initiative.md`. If missing, abort with: `initiative not found — run /openspec-initiative-plan first`.
5. Resolve `<change_dir>` = `<workspace_root>/openspec/changes/<story-slug>/`.
   - If missing, check `<workspace_root>/openspec/changes/archive/<story-slug>/`.
   - If archived, abort with: `story is archived; move it back to openspec/changes/ first`.
   - If missing in both, abort with: `change workspace not found — run /openspec-story-plan first`.
6. Read `<story_file>` and confirm the `Status:` header field is present (it may be default-valued or unset).
   - If `story.md` is missing or unreadable, abort with: `story.md is missing from change workspace`.
7. Keep the exact `WORKTREE=` fragments for later command lines. Do not normalize or reinterpret them in the converger.

## Phase 2 — Eligibility Gate

Use the `Status:` and `Plan:` header fields in `<story_file>` as the authoritative implementation status and planning lane. Check for `blocked.md` as an explicit gate file.

Allowed starting states:

- `Status:` is absent, unset, `⬜ TODO`, or `⚪ TODO` only when the story is plan-approved and the `## Current Claim` section in `<progress_file>` does not exist or is empty.
- `Status: 🔄 IN PROGRESS` only when `Plan:` is `🟢 PLAN APPROVED`.
- `Status: 🟣 IN REVIEW` only when `Plan:` is `🟢 PLAN APPROVED`; this is a successful implementation-convergence stop, not a route to review inside this command.
- `Status: ⛔ BLOCKED` only when `Plan:` is `🟢 PLAN APPROVED` and `<blocked_file>` is absent; this means the explicit gate file was removed and `/openspec-story-resume` must normalize the stale status back to `🔄 IN PROGRESS` before work continues.
- `Status: ✅ DONE` only when durable evidence shows independent completion authority: the latest relevant `<reviews_file>` entry records `Decision: approve`, `Approval gate: pass`, and risk-lens/finding-closure evidence. This is an already-complete early return; convergence must not create or pursue `✅ DONE` itself.

Reject with a precise next action:

- Any non-DONE story whose `Plan:` header field exists and is not `🟢 PLAN APPROVED`: use `/openspec-story-plan-converge <initiative> <story-slug>`.
- `Status:` absent, `⬜ TODO`, or `⚪ TODO` with `## Current Claim` already present in `<progress_file>`: status drift; ask the operator to resolve before converging.
- `Status: ✅ DONE` without durable review approval with `Approval gate: pass`: status drift; ask the operator to restore `Status: 🟣 IN REVIEW` and run `/openspec-story-review <initiative> <story-slug>` from a completely fresh, oblivious session.
- `Status: ⛔ BLOCKED` while `<blocked_file>` exists: blocked stories need operator unblocking before convergence.
- `<blocked_file>` exists at `<change_dir>/blocked.md`: convergence is refused while an explicit gate file exists. The operator may edit it to record resolution notes, but must remove `blocked.md` to unblock. Once the file is removed, stale `Status: ⛔ BLOCKED` is resumable and routes to `/openspec-story-resume` for normalization.

Plan-approved means `Plan:` is `🟢 PLAN APPROVED`. No other source is consulted for the plan state.

## Phase 3 — Fresh-Agent Loop

Run at most `MAX_CYCLES` cycles. An implementation cycle is one opportunity to move the story toward `Status: 🟣 IN REVIEW`; it may include exactly one implementation-producing claim or resume pass. It never includes an implementation review pass.

Before each subagent launch, build the command line from the current status:

- `Status:` absent/unset, `⬜ TODO`, or `⚪ TODO` and plan-approved: `/openspec-story-claim <initiative> <story-slug> [WORKTREE=...]`.
- `Status: 🔄 IN PROGRESS`: `/openspec-story-resume <initiative> <story-slug> [WORKTREE=...]`.
- `Status: 🟣 IN REVIEW`: do not launch claim, resume, or review. Stop successfully with result `IN_REVIEW` and route the operator to a fresh, oblivious `/openspec-story-review <initiative> <story-slug> [WORKTREE=...]` session.
- `Status: ⛔ BLOCKED` with no `<blocked_file>` present and plan-approved: `/openspec-story-resume <initiative> <story-slug> [WORKTREE=...]` to normalize the resolved blocker and continue.
- `Status: ✅ DONE`: do not launch claim, resume, or review. Re-check the durable completion authority from the eligibility gate; if present, stop with result `DONE`. If the evidence is absent or incomplete, stop as status drift and route to a fresh, oblivious `/openspec-story-review <initiative> <story-slug>` session instead of continuing the loop.

For each cycle:

1. Re-read `<story_file>` and `<progress_file>` before choosing the next pass.
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

5. End the task prompt with the exact slash command line, then launch exactly one fresh implementation subagent.
6. Require implementation subagents to write new sourced research directly to the named research notebook page when runtime notebook tools are available. If notebook tools are unavailable, allow compact sourced fallback notes in normal final reporting instead. Require subagents to mention any referenced notebook entry or fallback excerpt that failed verification with exact anchors in their relevant blocker or notes section. After the pass finishes, inspect the named research notebook page or child-reported entries as needed, then use mismatch notes to update, replace, retire, or ask about affected entries. Do not append verdicts, implementation opinions, or unanchored summaries.
7. If the subagent asks an operator question, pause the convergence run, ask the operator, then resume the same subagent for that implementation pass only. The next lifecycle pass still starts in a new fresh subagent.
8. After the pass finishes, treat the subagent final response as the provisional result. Before routing or stopping, perform a minimal authority spot-check of only the decision-bearing fields and anchors: for example, use `rg -n '^(Status:|Plan:)' <story_file>` for lifecycle headers and `rg -n '^(### |Status:)' <progress_file>` only when progress state matters. Use bounded reads only for the newest relevant progress or handoff entry body. If those spot-checks agree with the agent's report, continue from the canonical fields. If anchors are missing, stale, ambiguous, or conflicting, broaden to targeted reads of the affected file(s) or stop with a concrete operator repair action; do not launch `/openspec-story-review` from this skill.
9. If a claim or resume pass leaves the story at `Status: 🟣 IN REVIEW`, stop with result `IN_REVIEW`. Do not launch a review pass in the same cycle.
10. If a claim or resume pass leaves the story at `Status: 🔄 IN PROGRESS`, continue only when the cycle budget remains and the no-progress gate does not fire.
11. If any pass moves the story to `Status: ⛔ BLOCKED`, stop.
12. If any implementation pass moves the story to `Status: ✅ DONE`, treat that as status drift unless a bounded spot-check confirms durable independent review authority in `<reviews_file>` as described in the eligibility gate. If DONE lacks that evidence, stop and route to fresh oblivious `/openspec-story-review` instead of accepting subagent chat output. If DONE has that evidence, stop with result `DONE` but note that this command did not create the completion authority.
13. If `<blocked_file>` appears in `<change_dir>` at any point during the convergence run, stop immediately.
14. Run the no-progress gate before starting the next cycle.

### Worktree Discovery

When preparing a subagent command line, discover worktrees from `<progress_file> → ## Current Claim → - Worktrees:` (plural form with parent bullet). The legacy singular `- Worktree:` form is accepted by the subagent commands; this converger passes `WORKTREE=` values through unchanged and does not reinterpret them. If no `## Current Claim` exists yet (pre-claim), only explicit `WORKTREE=` arguments from the invocation are passed through.

## Phase 4 — Operational Notes and Stops

Maintain a convergence notebook containing neutral operational notes and sourced research entries for implementation passes only. Do not write notebook content to `initiative.md`, `story.md`, `progress.md`, `reviews.md`, `blocked.md`, or any coordination file as a duplicate source of lifecycle, proof, or review authority.

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

At the end of the run, inspect `<progress_file> → ## Current Claim` when present:

- For each `- Worktrees:` child bullet (`- <repo-basename>: <absolute path>`), run `git -C <path> status --porcelain` when the path exists.
- For `- Main-tree targets:`, run `git status --porcelain` against the corresponding target repo when it can be resolved from `<workspace_root>/projects/<basename>` or `<workspace_root>`.
- If dirty changes appear to belong to the story, recommend committing them on the feature branch `<initiative>/<story-slug>`.

Do not commit directly. The recommendation is advisory and must be explicit about whether it is a ready-for-review checkpoint or a WIP checkpoint.

Recommend a ready-for-review checkpoint when:

- the story reached `Status: 🟣 IN REVIEW`;
- implementation proof appears complete enough for independent review;
- worktree changes remain dirty.

Recommend a WIP checkpoint only when stopping at `MAX_CYCLES`, operator input, or no-progress with useful completed changes. Do not recommend a commit when the story blocked before meaningful implementation or no code/test/config changes exist.

When the final authoritative status is `🟣 IN REVIEW`, treat implementation convergence as complete. The next lifecycle step is `/openspec-story-review`, but it must be run by the operator from a completely fresh, oblivious session. `/openspec-pr` may be a later delivery helper only after review marks the story `Status: ✅ DONE`.

When the final authoritative status is `✅ DONE`, treat the story as already locally complete due to independent review authority that existed outside this convergence loop. `/openspec-pr` may be a later delivery helper before archive, but it is not the next lifecycle step.

## Phase 6 — Final Response

Return only the compact report below. Do not include internal deliberation, analysis prose, "Thinking:" blocks, private rationale, or comments about what you are considering before or after the report. Include every section in the template; use `None.` or `unavailable` rather than omitting a section.

```markdown
**Convergence Result**: IN_REVIEW | DONE | BLOCKED | STOPPED | MAX_CYCLES
**Initiative**: <initiative-slug>
**Story**: <story-slug>
**Cycles Used**: <n>/<MAX_CYCLES>
**Final Status**: <status>
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
- <single concrete command or decision. When result is IN_REVIEW: open a completely fresh, oblivious session with no parent/converger notebook references, implementation summaries, operational notes, or prior chat context, then run `/openspec-story-review <initiative> <story-slug> [WORKTREE=...]`. When result is DONE: `None. Story is already ✅ DONE.`>
```

Do not run `/memorize` automatically. If the nice-to-haves are valuable, the operator can decide whether to promote them later.
