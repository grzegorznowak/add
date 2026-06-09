## Pi Primitives

Use `spawn` for optional read-only evidence probes. Do not use notebook pages to store review verdicts, approval evidence, Research Board state, or lifecycle decisions; `reviews.md` is the durable review authority.

### Research before review
When broad context would be noisy, spawn a read-only child for codebase context before forming review opinions:

```
spawn({prompt: "For openspec/<initiative>/<story>, research: scope boundaries, critical files from story.md, existing tests, and risk-lens surface. Cite path:line anchors. Return a compact summary only; do not decide the verdict or edit files.", thinking: "high"})
```

Use child findings for orientation only. Verify every material claim with direct reads/search against cited anchors before any verdict or `reviews.md` write-back.

### Review findings
Write the final review verdict only to the canonical OpenSpec review artifact (`openspec/changes/<story>/reviews.md`) using the schema in the base skill. Do not persist a duplicate verdict in notebook storage.
