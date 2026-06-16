## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every notebook page name. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename.

### Resume context → notebook
Retrieve cached state from prior sessions:
- `notebook_read({name: "proof-<epic>-<step>"})` — acceptance proof map from previous claim/resume
- `notebook_read({name: "research-<epic>-<step>"})` — cached codebase research (if converger populated it)
- `notebook_read({name: "debt-<epic>-<step>"})` — prior Debt Friction findings (if any)

If none exist, rebuild from the story file as usual.

### Research before continuing
Spawn a read-only child for the next acceptance/TAP slice or review finding you are about to address, not for broad architecture:
`spawn({prompt: "For <epic>/<step>, re-inspect the next resume slice: <A<n>> / <TAP-*> / latest finding <id>. Checklist: Critical Files still resolve; changed or reusable owners/callsites; test layout, fixtures, and CI lane still match the TAP; expected assertion/observable signal; fallback if the planned seam drifted. Write findings to notebook page 'research-<epic>-<step>' with path:line anchors.", thinking: "high"})`.

### Review feedback re-inspection
When resuming after `request_changes`, spawn a child to re-inspect flagged files:
`spawn({prompt: "Re-inspect <files/symbols> from the latest Review Log finding for <epic>/<step>. Are the issues still present? What's changed since the review? Write findings to notebook page 'review-recheck-<epic>-<step>'.", thinking: "medium"})`.

### Proof tracking → notebook
Update the proof page as acceptance items are completed: `notebook_write({name: "proof-<epic>-<step>", content: "..."})`. Refine the entry with updated status and evidence.

### Research Board from converger → notebook
Retrieve: `notebook_read({name: "research-<epic>-<step>"})`. Verify entries with direct reads before acting.
