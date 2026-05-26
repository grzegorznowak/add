## Pi Primitives

Use `spawn`, `ledger_add`, `ledger_get`, `ledger_list`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every ledger key. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename.

### Resume context → ledger
Retrieve cached state from prior sessions:
- `ledger_get("proof-<epic>-<step>")` — acceptance proof ledger from previous claim/resume
- `ledger_get("research-<epic>-<step>")` — cached codebase research (if converger populated it)
- `ledger_get("debt-<epic>-<step>")` — prior Debt Friction findings (if any)

If none exist, rebuild from the story file as usual.

### Research before continuing
Spawn a read-only child to refresh codebase understanding before the first change:
`spawn({prompt: "Re-inspect the codebase for <epic>/<step>. Focus on areas flagged by latest Review Log / Progress Log. Verify Critical Files still resolve, check for drift. Write to ledger 'research-<epic>-<step>' with path:line anchors.", thinking: "high"})`.

### Review feedback re-inspection
When resuming after `request_changes`, spawn a child to re-inspect flagged files:
`spawn({prompt: "Re-inspect <files/symbols> from the latest Review Log finding for <epic>/<step>. Are the issues still present? What's changed since the review? Write to ledger 'review-recheck-<epic>-<step>'.", thinking: "medium"})`.

### Proof tracking → ledger
Update the proof ledger as acceptance items are completed: `ledger_add("proof-<epic>-<step>", ...)`. Refine the entry with updated status and evidence.

### Research Board from converger → ledger
Retrieve: `ledger_get("research-<epic>-<step>")`. Verify entries with direct reads before acting.
