## Pi Primitives

Use `spawn`, `ledger_add`, `ledger_get`, `ledger_list`.

### Multipass focused passes → spawn
Instead of sub-agents for each focused pass, use `spawn()`:
`spawn({prompt: "Focused review pass: <title>. Inspect <files/symbols> for acceptance items <A<n>>. Be read-only. Write findings to ledger 'review-pass-<epic>-<story>-<title>' using the detailed finding card format. Return summary.", thinking: "high"})`.

Synthesize by reading all pass ledger entries: `ledger_get("review-pass-<epic>-<story>-<pass>")` for each pass.

### Research Board from converger → ledger
Retrieve: `ledger_get("research-<epic>-<story>")`. Verify entries with direct reads against cited anchors before using in findings. If an entry doesn't verify, refine the entry with correction.

### Review findings cache → ledger (optional)
For findings needing cross-session persistence beyond the story file's `## Review Log`: `ledger_add("review-<epic>-<story>", "## Review Findings\n...")`. The story file's `## Review Log` remains the durable record.
