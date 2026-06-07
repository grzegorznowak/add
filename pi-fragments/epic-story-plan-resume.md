## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every notebook page name. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename.

### Research Board from converger → notebook
Retrieve: `notebook_read({name: "plan-research-<epic>-<step>"})`. Verify entries with direct reads before acting. If an entry doesn't verify, refine the notebook page with correction + new anchors.

### Parallel codebase probing → spawn
When Critical Files probing, Discovery Notes probing, or Test Architecture Plan repair would require several searches, spawn a read-only evidence child for the specific planning gap. Keep the prompt short and name the checklist:
`spawn({prompt: "For planning story <epic>/<step>, probe <keywords/files> for the current spec gap. Checklist: resolved paths and roles; reusable owners/callsites; existing test layout, fixtures, markers, and CI lanes; candidate TAP rows with behavior-facing assertion/observable signal; fallback if the preferred seam is wrong. Write findings to notebook page 'plan-probe-<epic>-<step>' with path:line anchors.", thinking: "medium"})`.

Retrieve findings: `notebook_read({name: "plan-probe-<epic>-<step>"})`. The parent integrates evidence into spec sections and owns every TAP/risk decision and write.

### Multi-session planning transition
When planning spans multiple sessions (e.g., Mode A → Mode B), write the durable state to notebook pages first, then give the operator the clean next command and context to resume with. The transition note should contain: modes completed, sections edited, Test Architecture Plan status, remaining incomplete sections, notebook page names, and the next recommended skill. Use a harness handoff only when the operator explicitly requests it or the current pi session says it is available.
