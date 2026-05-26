## Pi Primitives

Use `spawn`, `ledger_add`, `ledger_get`, `ledger_list`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every ledger key. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename.

### Multipass focused passes → spawn
Instead of sub-agents for each focused pass, use `spawn()`:
`spawn({prompt: "Focused review pass: <title> for <epic>/<step>. Inspect <files/symbols> for acceptance items <A<n>>. Be read-only. Write findings to ledger 'review-pass-<epic>-<step>-<title>' using the detailed finding card format. Return summary.", thinking: "high"})`.

Synthesize by reading all pass ledger entries: `ledger_get("review-pass-<epic>-<step>-<pass>")` for each pass.

### Research Board from converger → ledger
Retrieve: `ledger_get("research-<epic>-<step>")`. Verify entries with direct reads against cited anchors before using in findings. If an entry doesn't verify, refine the entry with correction.

### Review findings cache → ledger (optional)
For findings needing cross-session persistence beyond the story file's `## Review Log`: `ledger_add("review-<epic>-<step>", "## Review Findings\n...")`. The story file's `## Review Log` remains the durable record.
