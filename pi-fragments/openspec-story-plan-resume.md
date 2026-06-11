## Pi Primitives

Use Pi runtime tools (`spawn`, `notebook_write`, `notebook_read`, and `notebook_index`) only as optional focused read-only planning probes and sourced notebook orientation. Follow the base skill's canonical Plan-lane, story-contract, and notebook-authority rules.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every child prompt and Pi notebook page name.

### Planning research
When a spec gap needs codebase evidence, spawn a read-only child for the specific section, TAP row, prerequisite, or ownership seam:

```
spawn({prompt: "For openspec/<initiative_slug>/<story_slug>, research planning gap <section/TAP/prerequisite/owner>. Checklist: relevant paths and roles; existing test layout, fixtures, markers, and CI lanes; candidate behavior-facing assertion/observable signal; fallback if the preferred seam is wrong. Write findings to notebook page 'openspec-plan-research-<initiative_slug>-<story_slug>' with path:line anchors. Do not edit files or decide Plan lane.", thinking: "medium"})
```

Retrieve findings with `notebook_read({name: "openspec-plan-research-<initiative_slug>-<story_slug>"})`. Verify material claims with direct reads/search before story edits.

### Pi notebook from converger
When a converger names `openspec-plan-research-<initiative_slug>-<story_slug>`, retrieve it with `notebook_read({name: "openspec-plan-research-<initiative_slug>-<story_slug>"})`; then apply the base skill's verification and stale-reference handling rules.
