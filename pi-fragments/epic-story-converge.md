---
name: epic-story-converge
description: Run fresh claim, resume, and review children against one story until implementation is locally approved, blocked, or the loop reaches a hard stop.
---

# Epic Story Converge

Coordinate implementation-side ping-pong for one story. Spawn children for `/epic-story-claim`, `/epic-story-resume`, and `/epic-story-review` in cycles. Use notebook pages for the Research Board and babysitting notes. Stop on local approval, blocker, no-progress, or cycle-budget exhaustion.

Argument: `<epic> <story> [MAX_CYCLES=5] [WORKTREE="<basename>=<path>"]...`. `MAX_CYCLES` defaults to 5. `WORKTREE=` values pass through to children unchanged.

## Phase 1 — Parse and Resolve

1. Parse `$ARGUMENTS`: `<epic>` required, `<story>` required, `MAX_CYCLES=<n>` optional (default 5), `WORKTREE=` optional repeatable.
2. Resolve `<epic_dir>` = `<cwd>/agent_coordination/epics/<epic>`.
3. Read `<epic_dir>/MASTER.md`. Match `<story>` by `Step`, then `Spec`. Abort on mismatch or ambiguity.
4. Resolve `<step>` from the matched row's `Step` value and `<story_file>` from its `Spec` value. Use `<step>` — never the raw `<story>` selector — in every notebook page name and child prompt.

## Phase 2 — Eligibility Gate

Allowed starting states: `⬜ TODO` or `⚪ TODO` (plan-approved only), `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `🔵 IN PR` (with requested changes), `✅ DONE` (stop immediately).

Reject with next action:
- `Plan` not `🟢 PLAN APPROVED` → `/epic-story-plan-converge`
- `⛔ BLOCKED` → operator must unblock
- Status drift → ask operator to resolve

## Phase 3 — Cycle Loop

Run up to `MAX_CYCLES` cycles. Before each child launch, re-read `MASTER.md` and story file. Choose child type from current status: `⬜ TODO` or `⚪ TODO` → claim, `🔄 IN PROGRESS` → resume, `🟣 IN REVIEW` → review, `🔵 IN PR` with changes → resume.

### Notebook pages

Maintain two notebook pages:
- `babysit-<epic>-<step>` — neutral operational notes (command failures, hotspots, repeated findings)
- `research-<epic>-<step>` — sourced Research Board entries (path:line anchors required)

### Launching children

For each cycle, spawn one child. Build the prompt with:
- The exact owning workflow skill name: `epic-story-claim`, `epic-story-resume`, or `epic-story-review`
- The task description and resolved story (`<epic>/<step>`, with `<spec>` if useful)
- Reference notebook page names so the child can `notebook_read` them
- `WORKTREE=` values if provided
- Operational context from `babysit-<epic>-<step>` (summarize, don't inline full content)

Use one of these exact opening lines, based on the selected pass:
- Claim child: `You are executing the epic-story-claim workflow for story <epic>/<step>. Treat this as the pi-native equivalent of /epic-story-claim <epic> <step>.`
- Resume child: `You are executing the epic-story-resume workflow for story <epic>/<step>. Treat this as the pi-native equivalent of /epic-story-resume <epic> <step>.`
- Review child: `You are executing the epic-story-review workflow for story <epic>/<step>. Treat this as the pi-native equivalent of /epic-story-review <epic> <step>.`

```
spawn({
  prompt: "<exact opening line for claim/resume/review>
  Retrieve notebook pages: 'research-<epic>-<step>' (cached research, verify with direct reads), 'babysit-<epic>-<step>' (operational notes).
  Write new sourced research to notebook page 'research-<epic>-<step>'. Report blockers or repeated failures so the converger can update notebook page 'babysit-<epic>-<step>'.
  WORKTREE=\"<basename>=<path>\" ...",
  thinking: "high"
})
```

After the child completes:
1. Re-read `MASTER.md` and story file. Derive decisions from file state, not chat output.
2. Read `notebook_read({name: "research-<epic>-<step>"})`. Curate: keep verified entries, replace invalidated entries, retire stale ones. Every entry must have a source anchor.
3. Update notebook page `babysit-<epic>-<step>` with new operational facts (neutral, no verdicts).
4. If child asks an operator question, pause, ask, then resume with same child for that pass only.
5. If a claim or resume leaves story at `🟣 IN REVIEW`, same cycle may launch a fresh review child.
6. If review returns `approve`, confirm the latest story `## Review Log` records risk-lens review and finding closure (or explicit `none material`) before stopping successfully. If approval lacks that evidence, launch one fresh review child focused on risk-lens closure instead of accepting chat output alone.
7. If review returns `request_changes` or `not_reviewable`, same cycle may launch one corrective resume, then next cycle starts with fresh review. If the finding exposes a new risk lens, ensure the resume child treats that lens as part of the acceptance/proof closure or routes back to planning.
8. Stop on `⛔ BLOCKED`, `✅ DONE`, or no-progress.

## Phase 4 — No-Progress Gate

Stop when all are true: latest review returned `request_changes` or `not_reviewable`, subsequent resume didn't add new progress/addressing the finding, and same blocker would go to another review unchanged. Do not use another broad cycle to compensate for an oversized or under-specified story; route newly discovered contract/risk-lens gaps back to planning.

Other hard stops: `MAX_CYCLES` reached, status is `⛔ BLOCKED`, story enters status owned by another command, subagent failure, operator declines required interaction.

## Phase 5 — Commit Recommendation

For each worktree in story's `## Active Claim`, run `git -C <path> status --porcelain`. Recommend commit on branch `<epic>/<story-slug>` for dirty changes belonging to the story. Never commit directly.

- Final commit: when approved or DONE with dirty worktrees
- WIP checkpoint: stopped at MAX_CYCLES, operator input, or no-progress with useful changes

## Phase 6 — Final Response

```markdown
**Convergence Result**: APPROVED | DONE | BLOCKED | STOPPED | MAX_CYCLES
**Story**: Step <step> / <spec>
**Cycles Used**: <n>/<MAX_CYCLES>
**Final Status**: <status>

## Trace
- Cycle 1: claim/resume/review -> <result>
- Cycle 2: ...

## Research Board Snapshot
- Entries: <n> (notebook: research-<epic>-<step>)
- Hotspots: <paths/symbols>
- Persistence: notebook page `research-<epic>-<step>`

## Babysitter Notes
- <neutral operational fact>
- None.

## Commit Recommendation
- <final commit, WIP checkpoint, or none>
- Suggested command: `git -C <path> status && git -C <path> add -A && git -C <path> commit -m "<epic>/<story-slug>: <summary>"`

## Operator Nice-To-Haves
- <proposed improvement, including recurring risk/miss category worth automating or adding to future planning>
- None.

## Next Action
- <single concrete command or decision>
```
