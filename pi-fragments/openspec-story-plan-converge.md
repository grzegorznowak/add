## Pi Primitives

Use Pi runtime tools (`spawn`, `notebook_write`, `notebook_read`, and `notebook_index`) for fresh planning child-agent launches and sourced notebook orientation. Follow the base skill's canonical Plan-lane, notebook-authority, and convergence-routing rules.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every Pi notebook page name and child prompt.

### Notebook pages
Maintain two notebook pages for the planning run:

- `openspec-plan-research-<initiative_slug>-<story_slug>` — sourced planning research entries with exact path:line, symbol, command/output, or tool/query anchors.
- `openspec-plan-ops-<initiative_slug>-<story_slug>` — neutral operational notes such as missing sections, repeated validation failures, unresolved prerequisites, command failures, hotspots, and proof rows repeatedly implicated across passes.

### Child-agent launches
Launch each base-selected planning pass with `spawn`. Include the owning workflow skill name (`openspec-story-plan-review` or `openspec-story-plan-resume`), resolved `openspec/<initiative_slug>/<story_slug>`, Pi notebook page names, and a short `openspec-plan-ops-<initiative_slug>-<story_slug>` summary when useful.

```
spawn({
  prompt: "You are executing the openspec-story-plan-<review|resume> workflow for openspec/<initiative_slug>/<story_slug>. Treat this as the pi-native equivalent of /openspec-story-plan-<review|resume> <initiative_slug> <story_slug>.
  Retrieve notebook pages: 'openspec-plan-research-<initiative_slug>-<story_slug>' (sourced research, verify with direct reads/search) and 'openspec-plan-ops-<initiative_slug>-<story_slug>' (neutral operational notes).
  Write new sourced research to notebook page 'openspec-plan-research-<initiative_slug>-<story_slug>'. Report blockers, repeated failures, or recurring TAP/proof/spec-section hotspots so the converger can update notebook page 'openspec-plan-ops-<initiative_slug>-<story_slug>'.",
  thinking: "high"
})
```

After the subagent returns, use `notebook_read` / `notebook_write` for the named planning research and ops pages, then apply the base skill's provisional-result, minimal Plan-lane spot-check, curation, and stale-reference handling rules.
