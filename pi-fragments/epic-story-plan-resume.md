## Pi Primitives

Use `spawn`, `ledger_add`, `ledger_get`, `ledger_list`.

### Research Board from converger → ledger
Retrieve: `ledger_get("plan-research-<epic>-<story>")`. Verify entries with direct reads before acting. If an entry doesn't verify, refine the entry with correction + new anchors.

### Parallel codebase probing → spawn
When Critical Files probing or Discovery Notes probing requires searching multiple keywords:
`spawn({prompt: "Search the codebase for <keywords> for story <epic>/<story>. Report paths, roles, reusable code, gotchas. Write to ledger 'plan-probe-<epic>-<story>' with path:line anchors.", thinking: "medium"})`.

Retrieve findings: `ledger_get("plan-probe-<epic>-<story>")`. Integrate into spec sections.

### Handoff for multi-session planning
When planning spans multiple sessions (e.g., Mode A → Mode B), use `handoff()` between modes. Brief should contain: modes completed, sections edited, remaining incomplete sections, ledger entry names.
