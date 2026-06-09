## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, and `notebook_index` for optional focused read-only probes and shared notebook context. Notebook pages support sourced research orientation only; `story.md`, `progress.md`, `tasks.md`, and `reviews.md` remain the canonical OpenSpec artifacts for lifecycle status, implementation proof, task state, and review decisions.

After story selection, use the canonical `<initiative_slug>` and `<story_slug>` in every child prompt and notebook page name.

### Research before first change
Spawn a read-only child for the next acceptance/TAP slice you are about to implement, not for broad architecture:

```
spawn({prompt: "For openspec/<initiative_slug>/<story_slug>, research the next implementation slice: <A<n>> / <TAP-*>. Checklist: Critical Files resolve; reusable owner/callsites; existing test layout, fixtures, and CI lane; expected behavior-facing RED assertion or observable signal; fallback if the planned seam is wrong. Write findings to notebook page 'openspec-research-<initiative_slug>-<story_slug>' with path:line anchors. Return a compact summary only; do not edit files.", thinking: "high"})
```

Retrieve findings with `notebook_read({name: "openspec-research-<initiative_slug>-<story_slug>"})`. The parent verifies material claims with direct reads/search, chooses the red seam, performs TDD, edits files, and records proof in canonical OpenSpec artifacts.

### Debt Friction check
When needed, spawn a focused read-only Debt Friction probe:

```
spawn({prompt: "Debt Friction check for openspec/<initiative_slug>/<story_slug>. Inspect for duplicated behavior, unclear ownership, weak tests, missing seams, hidden coupling. Only report with causal link: story action → evidence → delivery impact. Write findings to notebook page 'openspec-debt-<initiative_slug>-<story_slug>' with path:line anchors.", thinking: "medium"})
```

Record accepted Debt Friction only in the canonical places named by the base skill (`progress.md` during implementation and review evidence when relevant).

### Notebook from converger
Retrieve `notebook_read({name: "openspec-research-<initiative_slug>-<story_slug>"})` when a converger names that page. Verify each entry with direct reads/search against cited anchors before acting. If an entry does not verify, mention the mismatch with correction anchors in the relevant final-response section; do not curate converger-provided notebook entries directly. Write new sourced research to that notebook page when runtime notebook tools are available.
