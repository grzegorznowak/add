## Pi Primitives

Use `spawn`, `ledger_add`, `ledger_get`, `ledger_list`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every ledger key. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename.

### Research before first change
Spawn a read-only child to probe the codebase before choosing the focused red seam:
`spawn({prompt: "Research <domain-keywords> from the story's Purpose/Scope for <epic>/<step>. Verify Critical Files paths, find reusable code, trace call paths, identify test seams. Write to ledger 'research-<epic>-<step>' with path:line anchors. Return summary.", thinking: "high"})`.
Retrieve: `ledger_get("research-<epic>-<step>")`.

### Debt Friction check
`spawn({prompt: "Debt Friction check for <epic>/<step>. Inspect for duplicated behavior, unclear ownership, weak tests, missing seams, hidden coupling. Only report with causal link: story action → evidence → delivery impact. Write to ledger 'debt-<epic>-<step>'.", thinking: "medium"})`.

### Proof tracking → ledger
Persist acceptance proof state: `ledger_add("proof-<epic>-<step>", "- A<n>: <status> — <evidence>")`. Update as each acceptance item is proven. Next session retrieves: `ledger_get("proof-<epic>-<step>")`.

### Research Board from converger → ledger
Retrieve: `ledger_get("research-<epic>-<step>")`. Verify each entry with direct reads against cited anchors before acting. If an entry doesn't verify, refine the ledger entry with correction + new anchors.
