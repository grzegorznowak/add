## Pi Primitives

Use Pi runtime tools (`spawn`, `notebook_write`, `notebook_read`, and `notebook_index`) only as optional focused read-only probes and sourced notebook orientation. Follow the base skill's canonical artifact and notebook-authority rules.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every child prompt and Pi notebook page name.

### Resume research
When the next resume slice is unclear, spawn a read-only child for the specific acceptance/TAP/review-finding seam:

```
spawn({prompt: "For openspec/<initiative_slug>/<story_slug>, re-inspect the next resume slice: <A<n>> / <TAP-*> / latest finding <id>. Checklist: Critical Files still resolve; changed or reusable owners/callsites; test layout, fixtures, and CI lane still match the story; expected assertion/observable signal; fallback if the planned seam drifted. Write findings to notebook page 'openspec-research-<initiative_slug>-<story_slug>' with path:line anchors. Do not edit files.", thinking: "high"})
```

Retrieve findings with `notebook_read({name: "openspec-research-<initiative_slug>-<story_slug>"})`. Verify material claims with direct reads/search before implementation or write-back.

### Pi notebook from converger
When a converger names `openspec-research-<initiative_slug>-<story_slug>`, retrieve it with `notebook_read({name: "openspec-research-<initiative_slug>-<story_slug>"})`; then apply the base skill's verification and stale-reference handling rules.
