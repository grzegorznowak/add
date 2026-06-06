## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every notebook page name. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename.

### Research Board from converger → notebook
Retrieve: `notebook_read({name: "plan-research-<epic>-<step>"})`. Verify entries with direct reads before acting. If an entry doesn't verify, refine the notebook page with correction + new anchors.

### Parallel codebase probing → spawn
When Critical Files probing, Discovery Notes probing, or Test Architecture Plan repair requires searching multiple keywords:
`spawn({prompt: "Search the codebase for <keywords> for story <epic>/<step>. Report paths, roles, reusable code, gotchas, existing test layout, fixtures, markers, CI lanes, and candidate TAP rows when tests/proof surfaces change. Write findings to notebook page 'plan-probe-<epic>-<step>' with path:line anchors.", thinking: "medium"})`.

Retrieve findings: `notebook_read({name: "plan-probe-<epic>-<step>"})`. Integrate into spec sections.

### Handoff for multi-session planning
When planning spans multiple sessions (e.g., Mode A → Mode B), use `handoff()` between modes. Brief should contain: modes completed, sections edited, Test Architecture Plan status, remaining incomplete sections, notebook page names.
