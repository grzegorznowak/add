## Pi Primitives

Use `spawn`, `ledger_add`, `ledger_get`, `ledger_list`.

### Codebase probing → spawn
When verifying Critical Files, searching domain keywords, or checking Locked Decisions against AGENTS.md, delegate to parallel children:
`spawn({prompt: "Probe <files/keywords> for story <epic>/<story>. Verify Critical Files resolve, check for reusable implementations, confirm Locked Decisions don't contradict AGENTS.md. Be read-only. Write findings to ledger 'plan-review-probe-<epic>-<story>' with path:line anchors.", thinking: "medium"})`.

Retrieve: `ledger_get("plan-review-probe-<epic>-<story>")`.

### Research Board from converger → ledger
Retrieve: `ledger_get("plan-research-<epic>-<story>")`. Verify entries with direct reads before using in findings.
