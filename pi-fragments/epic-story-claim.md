## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every notebook page name. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename.

### Research before first change
Spawn a read-only child to probe the codebase before choosing the focused red seam:
`spawn({prompt: "Research <domain-keywords> from the story's Purpose/Scope and Test Architecture Plan for <epic>/<step>. Verify Critical Files paths, find reusable code, trace call paths, identify TAP rows, test seams, intended assertions/observable signals, fallback plans, existing test layout, fixtures, and CI lanes. Write findings to notebook page 'research-<epic>-<step>' with path:line anchors. Return summary.", thinking: "high"})`.
Retrieve: `notebook_read({name: "research-<epic>-<step>"})`.

### Debt Friction check
`spawn({prompt: "Debt Friction check for <epic>/<step>. Inspect for duplicated behavior, unclear ownership, weak tests, missing seams, hidden coupling. Only report with causal link: story action → evidence → delivery impact. Write findings to notebook page 'debt-<epic>-<step>'.", thinking: "medium"})`.

### Proof tracking → notebook
Persist acceptance proof state with TAP ownership: `notebook_write({name: "proof-<epic>-<step>", content: "- A<n> / TAP-*: <status> — <evidence>"})`. Update as each acceptance item and Test Architecture Plan row is proven or intentionally changed. Next session retrieves: `notebook_read({name: "proof-<epic>-<step>"})`.

### Research Board from converger → notebook
Retrieve: `notebook_read({name: "research-<epic>-<step>"})`. Verify each entry with direct reads against cited anchors before acting. If an entry doesn't verify, refine the notebook page with correction + new anchors.
