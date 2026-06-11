## Pi Primitives

Use Pi runtime tools (`spawn`, `notebook_write`, `notebook_read`, and `notebook_index`) for fresh child-agent launches and sourced notebook orientation. Follow the base skill's canonical artifact, notebook-authority, and convergence-routing rules.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every Pi notebook page name and child prompt.

### Notebook pages
Maintain two notebook pages for the run:

- `openspec-research-<initiative_slug>-<story_slug>` — sourced research entries with exact path:line, symbol, command/output, or tool/query anchors.
- `openspec-ops-<initiative_slug>-<story_slug>` — neutral operational notes such as command failures, worktree/test blockers, hotspots, repeated findings, and acceptance/proof rows repeatedly implicated across passes.

### Child-agent launches
Launch each base-selected fresh pass with `spawn`. Include the owning workflow skill name, resolved `openspec/<initiative_slug>/<story_slug>`, Pi notebook page names, any `WORKTREE=` passthrough values, and a short `openspec-ops-<initiative_slug>-<story_slug>` summary when useful.

```
spawn({
  prompt: "You are executing the openspec-story-<claim|resume|review> workflow for openspec/<initiative_slug>/<story_slug>. Treat this as the pi-native equivalent of /openspec-story-<claim|resume|review> <initiative_slug> <story_slug>.
  Retrieve notebook pages: 'openspec-research-<initiative_slug>-<story_slug>' (sourced research, verify with direct reads/search) and 'openspec-ops-<initiative_slug>-<story_slug>' (neutral operational notes).
  Write new sourced research to notebook page 'openspec-research-<initiative_slug>-<story_slug>'. Report blockers, repeated failures, or recurring acceptance/proof/review hotspots so the converger can update notebook page 'openspec-ops-<initiative_slug>-<story_slug>'.
  WORKTREE=\"<basename>=<path>\" ...",
  thinking: "high"
})
```

After the subagent returns, use `notebook_read` / `notebook_write` for the named research and ops pages, then apply the base skill's provisional-result, minimal authority spot-check, curation, and stale-reference handling rules.
