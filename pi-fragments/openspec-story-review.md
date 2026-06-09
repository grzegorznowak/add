## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, and `notebook_index` for optional read-only evidence probes and shared notebook context. Notebook pages may store sourced research orientation only. Do not use notebook pages to store review verdicts, approval evidence, lifecycle decisions, or implementation proof state; `reviews.md` is the durable review authority.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every child prompt and notebook page name.

### Research before review
When broad context would be noisy, spawn a read-only child for codebase context before forming review opinions:

```
spawn({prompt: "For openspec/<initiative_slug>/<story_slug>, research: scope boundaries, critical files from story.md, existing tests, and risk-lens surface. Write findings to notebook page 'openspec-review-research-<initiative_slug>-<story_slug>' with path:line anchors. Do not decide the verdict or edit files.", thinking: "high"})
```

Retrieve findings with `notebook_read({name: "openspec-review-research-<initiative_slug>-<story_slug>"})`. Use child findings for orientation only. Verify every material claim with direct reads/search against cited anchors before any verdict or `reviews.md` write-back. If a converger names `openspec-research-<initiative_slug>-<story_slug>`, retrieve it the same way and verify before use.

### Review findings
Write the final review verdict only to the canonical OpenSpec review artifact (`openspec/changes/<story_slug>/reviews.md`) using the schema in the base skill. Do not persist a duplicate verdict in notebook storage.
