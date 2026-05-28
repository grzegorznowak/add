---
name: epic-story-plan-converge
description: Run fresh plan-review and plan-resume children against one story until its Plan lane is approved, blocked, or the loop reaches a hard stop.
---

# Epic Story Plan Converge

Coordinate planning-side ping-pong for one story. Spawn children for `/epic-story-plan-review` and `/epic-story-plan-resume` in cycles. Use notebook pages for the Research Board and babysitting notes. Stop on approval, blocker, no-progress, or cycle-budget exhaustion.

Argument: `<epic> <story> [MAX_CYCLES=5]`. No `WORKTREE=` — planning never touches source code.

## Phase 1 — Parse and Resolve

1. Parse `$ARGUMENTS`: `<epic>` required, `<story>` required, `MAX_CYCLES=<n>` optional (default 5).
2. Resolve `<epic_dir>` = `<cwd>/agent_coordination/epics/<epic>`.
3. Read `<epic_dir>/MASTER.md`. Match `<story>` by `Step`, then `Spec`. Abort on mismatch or ambiguity.
4. Resolve `<step>` from the matched row's `Step` value and `<story_file>` from its `Spec` value. Use `<step>` — never the raw `<story>` selector — in every notebook page name and child prompt.

## Phase 2 — Eligibility Gate

Abort if: implementation `Status` is `✅ DONE`, `Plan` is already `🟢 PLAN APPROVED` with no unresolved findings, story is so malformed that resume can't identify the scaffold.

## Phase 3 — Cycle Loop

Run up to `MAX_CYCLES` cycles. Before each child launch, re-read `MASTER.md` and story file. A planning cycle is one opportunity to get the plan approved.

### Notebook pages

Maintain two notebook pages:
- `plan-babysit-<epic>-<step>` — neutral operational notes
- `plan-research-<epic>-<step>` — sourced Research Board entries (path:line anchors required)

### Launching children

For each cycle, decide pass type:
- Missing/incomplete spec sections, no newer unaddressed review finding → `/epic-story-plan-resume`
- Story ready for review → `/epic-story-plan-review`
- After review `request_changes` or `not_reviewable` → follow with `/epic-story-plan-resume`

Spawn one child per pass. Name the exact owning workflow skill in the prompt: `epic-story-plan-review` for review passes or `epic-story-plan-resume` for resume passes.

Use one of these exact opening lines, based on the selected pass:
- Plan-review child: `You are executing the epic-story-plan-review workflow for story <epic>/<step>. Treat this as the pi-native equivalent of /epic-story-plan-review <epic> <step>.`
- Plan-resume child: `You are executing the epic-story-plan-resume workflow for story <epic>/<step>. Treat this as the pi-native equivalent of /epic-story-plan-resume <epic> <step>.`

```
spawn({
  prompt: "<exact opening line for plan-review/plan-resume>
  Retrieve notebook pages: 'plan-research-<epic>-<step>' (verify with direct reads), 'plan-babysit-<epic>-<step>' (operational notes).
  Write new sourced research to notebook page 'plan-research-<epic>-<step>'. Report blockers or repeated failures so the converger can update notebook page 'plan-babysit-<epic>-<step>'.",
  thinking: "high"
})
```

After each child:
1. Re-read `MASTER.md` and story file. Derive decisions from file state.
2. Read `notebook_read({name: "plan-research-<epic>-<step>"})`. Curate entries.
3. Update notebook page `plan-babysit-<epic>-<step>` with neutral operational facts.
4. If child asks operator question: pause, ask, resume same child for that pass only.
5. If review decision is `approve` or `Plan` reaches `🟢 PLAN APPROVED` → stop. Recommend `/epic-story-claim` or `/epic-story-resume`.
6. If `blocked` → stop.
7. If `request_changes` or `not_reviewable` → launch resume child, then next cycle.
8. If implementation `Status` changes during convergence → stop (unexpected state).

## Phase 4 — No-Progress Gate

Stop when: latest review returned `request_changes` or `not_reviewable`, subsequent resume didn't materially edit targeted sections, same blocker would go to review unchanged.

Other stops: `MAX_CYCLES`, `blocked`, implementation status change, subagent failure, operator declines required interaction.

## Phase 5 — Final Response

```markdown
**Convergence Result**: APPROVED | BLOCKED | STOPPED | MAX_CYCLES
**Story**: Step <step> / <spec>
**Cycles Used**: <n>/<MAX_CYCLES>
**Final Status**: <status>

## Trace
- Cycle 1: plan-review -> <decision>; plan-resume -> <completed/skipped>
- Cycle 2: ...

## Research Board Snapshot
- Entries: <n> (notebook: plan-research-<epic>-<step>)
- Hotspots: <paths/symbols>
- Persistence: notebook page `plan-research-<epic>-<step>`

## Babysitter Notes
- <neutral operational fact>
- None.

## Operator Nice-To-Haves
- <proposed improvement>
- None.

## Next Action
- <single concrete command or decision>
```
