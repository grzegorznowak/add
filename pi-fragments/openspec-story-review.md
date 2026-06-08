## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

### Research before review
Spawn a read-only child for broad codebase context before forming review opinions:

```
spawn({prompt: "For openspec/<initiative>/<story>, research: scope boundaries, critical files from story.md, existing tests, and risk-lens surface. Write findings to notebook page 'review-openspec-<initiative>-<story>' with path:line anchors. Return summary.", thinking: "high"})
```

Retrieve: `notebook_read({name: "review-openspec-<initiative>-<story>"})`. Use findings for orientation only — verify everything with direct reads against cited anchors before any verdict.

### Review findings → notebook
Persist review verdict: `notebook_write({name: "review-openspec-<initiative>-<story>", content: "- Decision: <approve|request_changes|blocked|not_reviewable>\n- Key findings: <summary>"})`.
