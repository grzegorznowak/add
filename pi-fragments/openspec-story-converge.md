## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, and `notebook_index` for fresh child-agent launches and shared notebook context. Notebook pages may store sourced research entries and neutral operational notes. They must not store lifecycle status, implementation proof state, review verdicts, approval decisions, or claimed/reviewed lifecycle decisions; `story.md`, `progress.md`, `tasks.md`, and `reviews.md` remain the canonical OpenSpec artifacts.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every notebook page name and child prompt.

### Notebook pages
Maintain two notebook pages for the run:

- `openspec-research-<initiative_slug>-<story_slug>` — sourced research entries with exact path:line, symbol, command/output, or tool/query anchors.
- `openspec-ops-<initiative_slug>-<story_slug>` — neutral operational notes such as command failures, worktree/test blockers, hotspots, repeated findings, and acceptance/proof rows repeatedly implicated across passes.

### Child-agent launches
Each cycle launches exactly one fresh subagent via `spawn`. Build the prompt with:

- the exact owning workflow skill name: `openspec-story-claim`, `openspec-story-resume`, or `openspec-story-review`;
- the task description and resolved change workspace (`<initiative_slug>/<story_slug>`);
- notebook page names so the child can `notebook_read` them;
- `WORKTREE=` values if provided; and
- a short operational summary from `openspec-ops-<initiative_slug>-<story_slug>` when useful.

```
spawn({
  prompt: "You are executing the openspec-story-<claim|resume|review> workflow for openspec/<initiative_slug>/<story_slug>. Treat this as the pi-native equivalent of /openspec-story-<claim|resume|review> <initiative_slug> <story_slug>.
  Retrieve notebook pages: 'openspec-research-<initiative_slug>-<story_slug>' (sourced research, verify with direct reads/search) and 'openspec-ops-<initiative_slug>-<story_slug>' (neutral operational notes).
  Write new sourced research to notebook page 'openspec-research-<initiative_slug>-<story_slug>'. Report blockers, repeated failures, or recurring acceptance/proof/review hotspots so the converger can update notebook page 'openspec-ops-<initiative_slug>-<story_slug>'.
  WORKTREE=\"<basename>=<path>\" ...",
  thinking: "high"
})
```

After the subagent returns, re-read coordination files (`story.md`, `progress.md`, `reviews.md`) directly to derive state; never trust subagent prose alone. Then read `notebook_read({name: "openspec-research-<initiative_slug>-<story_slug>"})`, curate entries, and update `openspec-ops-<initiative_slug>-<story_slug>` with neutral operational facts only. If a notebook entry does not verify, refine or retire it and summarize stale-reference handling in the final report.
