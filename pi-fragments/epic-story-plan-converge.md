---
name: epic-story-plan-converge
description: Run fresh plan-review and plan-resume children against one story until its Plan lane is approved, blocked, or the loop reaches a hard stop.
---

# Epic Story Plan Converge

Coordinate planning-side ping-pong for one story. Spawn children for `/epic-story-plan-review` and `/epic-story-plan-resume` in cycles. Use the ledger for Research Board and babysitting notes. Stop on approval, blocker, no-progress, or cycle-budget exhaustion.

Argument: `<epic> <story> [MAX_CYCLES=5]`. No `WORKTREE=` — planning never touches source code.

## Phase 1 — Parse and Resolve

1. Parse `$ARGUMENTS`: `<epic>` required, `<story>` required, `MAX_CYCLES=<n>` optional (default 5).
2. Resolve `<epic_dir>` = `<cwd>/agent_coordination/epics/<epic>`.
3. Read `<epic_dir>/MASTER.md`. Match `<story>` by `Step`, then `Spec`. Abort on mismatch or ambiguity.
4. Resolve `<story_file>` from the matched row's `Spec` value.

## Phase 2 — Eligibility Gate

Abort if: implementation `Status` is `✅ DONE`, `Plan` is already `🟢 PLAN APPROVED` with no unresolved findings, story is so malformed that resume can't identify the scaffold.

## Phase 3 — Cycle Loop

Run up to `MAX_CYCLES` cycles. Before each child launch, re-read `MASTER.md` and story file. A planning cycle is one opportunity to get the plan approved.

### Ledger entries

Maintain two ledger entries:
- `plan-babysit-<epic>-<story>` — neutral operational notes
- `plan-research-<epic>-<story>` — sourced Research Board entries (path:line anchors required)

### Launching children

For each cycle, decide pass type:
- Missing/incomplete spec sections, no newer unaddressed review finding → `/epic-story-plan-resume`
- Story ready for review → `/epic-story-plan-review`
- After review `request_changes` → follow with `/epic-story-plan-resume`

Spawn one child per pass:

```
spawn({
  prompt: "<task: plan-review or plan-resume story <epic>/<story>.
  Retrieve ledger entries: 'plan-research-<epic>-<story>' (verify with direct reads), 'plan-babysit-<epic>-<story>' (operational notes).
  Write new sourced research to 'plan-research-<epic>-<story>'. Report blockers or repeated failures.",
  thinking: "high"
})
```

After each child:
1. Re-read `MASTER.md` and story file. Derive decisions from file state.
2. Read `ledger_get("plan-research-<epic>-<story>")`. Curate entries.
3. Update `plan-babysit-<epic>-<story>` with neutral operational facts.
4. If child asks operator question: pause, ask, resume same child for that pass only.
5. If review decision is `approve` or `Plan` reaches `🟢 PLAN APPROVED` → stop. Recommend `/epic-story-claim` or `/epic-story-resume`.
6. If `blocked` → stop.
7. If `request_changes` → launch resume child, then next cycle.
8. If implementation `Status` changes during convergence → stop (unexpected state).

## Phase 4 — No-Progress Gate

Stop when: latest review requested changes, subsequent resume didn't materially edit targeted sections, same blocker would go to review unchanged.

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
- Entries: <n> (ledger: plan-research-<epic>-<story>)
- Hotspots: <paths/symbols>
- Persistence: ledger entry `plan-research-<epic>-<story>`

## Babysitter Notes
- <neutral operational fact>
- None.

## Operator Nice-To-Haves
- <proposed improvement>
- None.

## Next Action
- <single concrete command or decision>
```
