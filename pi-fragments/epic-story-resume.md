## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every notebook page name. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename.

### Resume context → notebook
Retrieve cached state from prior sessions:
- `notebook_read({name: "proof-<epic>-<step>"})` — acceptance proof and TAP row map from previous claim/resume
- `notebook_read({name: "research-<epic>-<step>"})` — cached codebase research (if converger populated it)
- `notebook_read({name: "debt-<epic>-<step>"})` — prior Debt Friction findings (if any)

If none exist, rebuild from the story file as usual.

### Research before continuing
Spawn a read-only child to refresh codebase understanding before the first change:
`spawn({prompt: "Re-inspect the codebase for <epic>/<step>. Focus on areas flagged by latest Review Log / Progress Log and the story's Test Architecture Plan. Verify Critical Files still resolve, TAP rows still match test layout, assertions/observable signals, fixtures, CI lanes, and fallback plans; check for drift. Write findings to notebook page 'research-<epic>-<step>' with path:line anchors.", thinking: "high"})`.

### Review feedback re-inspection
When resuming after `request_changes`, spawn a child to re-inspect flagged files:
`spawn({prompt: "Re-inspect <files/symbols> from the latest Review Log finding for <epic>/<step>. Are the issues still present? What's changed since the review? Write findings to notebook page 'review-recheck-<epic>-<step>'.", thinking: "medium"})`.

### Proof tracking → notebook
Update the proof page as acceptance items and TAP rows are completed: `notebook_write({name: "proof-<epic>-<step>", content: "..."})`. Refine the entry with updated status, TAP ownership, evidence, and any logged test-architecture drift.

### Research Board from converger → notebook
Retrieve: `notebook_read({name: "research-<epic>-<step>"})`. Verify entries with direct reads before acting.
