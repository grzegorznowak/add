## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, and `notebook_index` for optional focused read-only planning probes and shared notebook context. Notebook pages support sourced planning research orientation only; `story.md`, `proposal.md`, `design.md`, `tasks.md`, and `specs/*.md` remain canonical for Plan lane, plan-review findings, and story contract edits.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every child prompt and notebook page name.

### Planning research
When a spec gap needs codebase evidence, spawn a read-only child for the specific section, TAP row, prerequisite, or ownership seam:

```
spawn({prompt: "For openspec/<initiative_slug>/<story_slug>, research planning gap <section/TAP/prerequisite/owner>. Checklist: relevant paths and roles; existing test layout, fixtures, markers, and CI lanes; candidate behavior-facing assertion/observable signal; fallback if the preferred seam is wrong. Write findings to notebook page 'openspec-plan-research-<initiative_slug>-<story_slug>' with path:line anchors. Do not edit files or decide Plan lane.", thinking: "medium"})
```

Retrieve findings with `notebook_read({name: "openspec-plan-research-<initiative_slug>-<story_slug>"})`. Verify material claims with direct reads/search before story edits.

### Notebook from converger
Retrieve `notebook_read({name: "openspec-plan-research-<initiative_slug>-<story_slug>"})` when a converger names that page. If an entry does not verify, report a `## Research Events` notebook-refresh signal with correction anchors in the final response; do not curate converger-provided notebook entries directly.
