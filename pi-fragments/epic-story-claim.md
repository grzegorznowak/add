## Pi Primitives

Use `spawn`, `ledger_add`, `ledger_get`, `ledger_list`.

### Research before first change
Spawn a read-only child to probe the codebase before choosing the focused red seam:
`spawn({prompt: "Research <domain-keywords> from the story's Purpose/Scope. Verify Critical Files paths, find reusable code, trace call paths, identify test seams. Write to ledger 'research-<epic>-<story>' with path:line anchors. Return summary.", thinking: "high"})`.
Retrieve: `ledger_get("research-<epic>-<story>")`.

### Debt Friction check
`spawn({prompt: "Debt Friction check for <story>. Inspect for duplicated behavior, unclear ownership, weak tests, missing seams, hidden coupling. Only report with causal link: story action → evidence → delivery impact. Write to ledger 'debt-<epic>-<story>'.", thinking: "medium"})`.

### Proof tracking → ledger
Persist acceptance proof state: `ledger_add("proof-<epic>-<story>", "- A<n>: <status> — <evidence>")`. Update as each acceptance item is proven. Next session retrieves: `ledger_get("proof-<epic>-<story>")`.

### Research Board from converger → ledger
Retrieve: `ledger_get("research-<epic>-<story>")`. Verify each entry with direct reads against cited anchors before acting. If an entry doesn't verify, refine the ledger entry with correction + new anchors.
