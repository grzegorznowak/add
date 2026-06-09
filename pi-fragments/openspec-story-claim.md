## Pi Primitives

Use Pi runtime tools (`spawn`, `notebook_write`, `notebook_read`, and `notebook_index`) only as optional focused read-only probes and sourced notebook orientation. Follow the base skill's canonical artifact and notebook-authority rules.

After story selection, use the canonical `<initiative_slug>` and `<story_slug>` in every child prompt and Pi notebook page name.

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

Do not store Debt Friction decisions in notebook pages; record accepted Debt Friction only in the base skill's canonical write-back location.

### Pi notebook from converger
When a converger names `openspec-research-<initiative_slug>-<story_slug>`, retrieve it with `notebook_read({name: "openspec-research-<initiative_slug>-<story_slug>"})`; then apply the base skill's verification and stale-reference handling rules.
