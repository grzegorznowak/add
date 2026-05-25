## Pi Primitives

Use `spawn`, `ledger_add`, `ledger_get`, `ledger_list`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every ledger key. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename.

### Research Board from converger → ledger
Retrieve: `ledger_get("plan-research-<epic>-<step>")`. Verify entries with direct reads before acting. If an entry doesn't verify, refine the entry with correction + new anchors.

### Parallel codebase probing → spawn
When Critical Files probing or Discovery Notes probing requires searching multiple keywords:
`spawn({prompt: "Search the codebase for <keywords> for story <epic>/<step>. Report paths, roles, reusable code, gotchas. Write to ledger 'plan-probe-<epic>-<step>' with path:line anchors.", thinking: "medium"})`.

Retrieve findings: `ledger_get("plan-probe-<epic>-<step>")`. Integrate into spec sections.

### Handoff for multi-session planning
When planning spans multiple sessions (e.g., Mode A → Mode B), use `handoff()` between modes. Brief should contain: modes completed, sections edited, remaining incomplete sections, ledger entry names.
