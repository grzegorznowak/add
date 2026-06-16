## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every notebook page name. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename.

### Research before first change
Spawn a read-only child for the next acceptance/TAP slice you are about to implement, not for broad architecture:
`spawn({prompt: "For <epic>/<step>, research the next implementation slice: <A<n>> / <TAP-*>. Checklist: Critical Files resolve; reusable owner/callsites; existing test layout, fixtures, and CI lane; expected behavior-facing RED assertion or observable signal; fallback if the planned seam is wrong. Write findings to notebook page 'research-<epic>-<step>' with path:line anchors. Return summary.", thinking: "high"})`.
Retrieve: `notebook_read({name: "research-<epic>-<step>"})`. The parent chooses the red seam, performs TDD, edits files, and records proof.

### Debt Friction check
`spawn({prompt: "Debt Friction check for <epic>/<step>. Inspect for duplicated behavior, unclear ownership, weak tests, missing seams, hidden coupling. Only report with causal link: story action → evidence → delivery impact. Write findings to notebook page 'debt-<epic>-<step>'.", thinking: "medium"})`.

### Proof tracking → notebook
Persist acceptance proof state: `notebook_write({name: "proof-<epic>-<step>", content: "- A<n>: <status> — <evidence>"})`. Update as each acceptance item is proven. Next session retrieves: `notebook_read({name: "proof-<epic>-<step>"})`.

### Research Board from converger → notebook
Retrieve: `notebook_read({name: "research-<epic>-<step>"})`. Verify each entry with direct reads against cited anchors before acting. If an entry doesn't verify, refine the notebook page with correction + new anchors.
