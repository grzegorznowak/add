## Pi Primitives

Use Pi runtime tools (`spawn`, `notebook_write`, `notebook_read`, and `notebook_index`) for fresh child-agent launches and sourced notebook orientation. Follow the base skill's canonical artifact, notebook-authority, receipt-routing, and convergence rules.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every Pi notebook page name and child prompt.

### Notebook pages
Maintain two notebook pages for implementation passes only:

- `openspec-research-<initiative_slug>-<story_slug>` — sourced research entries with exact path:line, symbol, command/output, or tool/query anchors.
- `openspec-ops-<initiative_slug>-<story_slug>` — neutral operational notes such as command failures, worktree/test blockers, hotspots, repeated findings, and acceptance/proof rows repeatedly implicated across passes.

Neither page is review/lifecycle authority. The converger reads the single current `progress.md → ## Implementation Review Receipt` for completed-review routing and never passes implementation notebook context into review. A prior receipt may be historical after a newer authorized feedback/resume/unblock transition; non-DONE Status/blocker routing owns. DONE with a present receipt requires one complete canonical APPROVE/PASS record whose transition ends in `✅ DONE`. Receipt absence is legacy compatibility only for a true pre-v3 DONE story with zero Initiative or Initiative-like header lines and zero receipt sections; a bound modern DONE without a receipt routes only to ordinary `/openspec-feedback <initiative-slug>` with an operator-acknowledged `resume-current-story` disposition, never directly to story review.

After blocker and receipt-shape precedence, when a bound modern `Status: ✅ DONE` has exactly one valid `APPROVE`/`PASS` receipt but a current `review-identity-v1` mismatch or unverifiable identity, or bounded task/proof evidence contradicting DONE, is detected, route only to ordinary `/openspec-feedback <initiative-slug>` with an operator-acknowledged `resume-current-story` disposition; preserve the existing receipt bytes.
Never route that contradiction directly to a fresh review or implementation resume command.
The fragment cannot narrow that canonical route: convergence performs no DONE, PR/archive, Plan, implementation, notebook-lifecycle, or external mutation on the contradiction branch. Feedback alone acknowledges and reopens; resume repairs and returns IN REVIEW before fresh readonly review and feedback publication.

Use Bash only for the base skill's required read-only `git status` and `git worktree list` commands. Use Read/Grep/Glob for artifact inspection; do not broaden Bash to arbitrary shell commands.

### Child-agent launches
Launch each base-selected fresh implementation pass with `spawn`. Include the owning workflow skill name, resolved `openspec/<initiative_slug>/<story_slug>`, Pi notebook page names, any `WORKTREE=` passthrough values, and a short ops summary when useful. The prompt must end with the exact owning slash command.

```
spawn({
  prompt: "You are executing the openspec-story-<claim|resume> workflow for openspec/<initiative_slug>/<story_slug>.
Retrieve notebook pages: 'openspec-research-<initiative_slug>-<story_slug>' (sourced research, verify with direct reads/search) and 'openspec-ops-<initiative_slug>-<story_slug>' (neutral operational notes).
Write new sourced research to notebook page 'openspec-research-<initiative_slug>-<story_slug>'. Report blockers, repeated failures, or recurring acceptance/proof/review hotspots so the converger can update notebook page 'openspec-ops-<initiative_slug>-<story_slug>'.
Pass through resolved WORKTREE selectors and run from the current transient <openspec_root> when it differs from launch.
/openspec-story-<claim|resume> <initiative_slug> <story_slug> [WORKTREE=...]",
  thinking: "high"
})
```

After the subagent returns, use `notebook_read` / `notebook_write` for the named research and ops pages, then apply the base skill's provisional-result, transient-root refresh/recompute, durable receipt routing, curation, and stale-reference handling rules.
