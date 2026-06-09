## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, and `notebook_index` for fresh child-agent launches and shared notebook context. Notebook pages may store sourced planning research and neutral operational notes. They must not store Plan lane decisions, lifecycle status, implementation proof state, review verdicts, or approval decisions; `story.md` and the change workspace artifacts remain canonical.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every notebook page name and child prompt.

### Notebook pages
Maintain two notebook pages for the planning run:

- `openspec-plan-research-<initiative_slug>-<story_slug>` — sourced planning research entries with exact path:line, symbol, command/output, or tool/query anchors.
- `openspec-plan-ops-<initiative_slug>-<story_slug>` — neutral operational notes such as missing sections, repeated validation failures, unresolved prerequisites, command failures, hotspots, and proof rows repeatedly implicated across passes.

### Child-agent launches
Each cycle launches exactly one fresh subagent via `spawn`. Build the prompt with the exact owning workflow skill name (`openspec-story-plan-review` or `openspec-story-plan-resume`), the resolved story, notebook page names, and a short operational summary when useful.

```
spawn({
  prompt: "You are executing the openspec-story-plan-<review|resume> workflow for openspec/<initiative_slug>/<story_slug>. Treat this as the pi-native equivalent of /openspec-story-plan-<review|resume> <initiative_slug> <story_slug>.
  Retrieve notebook pages: 'openspec-plan-research-<initiative_slug>-<story_slug>' (sourced research, verify with direct reads/search) and 'openspec-plan-ops-<initiative_slug>-<story_slug>' (neutral operational notes).
  Write new sourced research to notebook page 'openspec-plan-research-<initiative_slug>-<story_slug>'. Report blockers, repeated failures, or recurring TAP/proof/spec-section hotspots so the converger can update notebook page 'openspec-plan-ops-<initiative_slug>-<story_slug>'.",
  thinking: "high"
})
```

After the subagent returns, trust its final response as provisional and use a minimal authority spot-check before routing, for example `rg -n '^(Plan:|## Plan Review Log|### |Verdict:)' story.md` plus a bounded read of the newest log entry only if needed. Broaden only when anchors are missing, stale, ambiguous, or conflict with the agent report. Then read `notebook_read({name: "openspec-plan-research-<initiative_slug>-<story_slug>"})`, curate entries, and update `openspec-plan-ops-<initiative_slug>-<story_slug>` with neutral operational facts only. If a notebook entry does not verify, refine or retire it and summarize stale-reference handling in the final report.
