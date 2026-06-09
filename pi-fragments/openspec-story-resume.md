## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, and `notebook_index` for optional focused read-only probes and shared notebook context. Notebook pages support sourced research orientation only; `story.md`, `progress.md`, `tasks.md`, and `reviews.md` remain canonical for lifecycle status, proof, task state, and review decisions.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every child prompt and notebook page name.

### Resume research
When the next resume slice is unclear, spawn a read-only child for the specific acceptance/TAP/review-finding seam:

```
spawn({prompt: "For openspec/<initiative_slug>/<story_slug>, re-inspect the next resume slice: <A<n>> / <TAP-*> / latest finding <id>. Checklist: Critical Files still resolve; changed or reusable owners/callsites; test layout, fixtures, and CI lane still match the story; expected assertion/observable signal; fallback if the planned seam drifted. Write findings to notebook page 'openspec-research-<initiative_slug>-<story_slug>' with path:line anchors. Do not edit files.", thinking: "high"})
```

Retrieve findings with `notebook_read({name: "openspec-research-<initiative_slug>-<story_slug>"})`. Verify material claims with direct reads/search before implementation or write-back.

### Notebook from converger
Retrieve `notebook_read({name: "openspec-research-<initiative_slug>-<story_slug>"})` when a converger names that page. If an entry does not verify, mention the mismatch with correction anchors in the relevant final-response section; do not curate converger-provided notebook entries directly. Write new sourced research to that notebook page when runtime notebook tools are available.
