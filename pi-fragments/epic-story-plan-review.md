## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every notebook page name. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename.

### Original intent / ticket archaeology → spawn
When the story, MASTER row, branch/history, dependency stories, or PR text expose issue/PR/Jira/card anchors, delegate a read-only child to trace original intent:
`spawn({prompt: "For story <epic>/<step>, inspect explicit original intent anchors only (GitHub issues/PRs, Jira/card ids, branch names, commit messages, dependency references). Build ticket/issue intent facts, contradictions, missing acceptance cases, and inaccessible sources. Do not infer unlinked tickets. Write findings to notebook page 'plan-review-intent-<epic>-<step>' with exact anchors.", thinking: "medium"})`.

Retrieve: `notebook_read({name: "plan-review-intent-<epic>-<step>"})`.

### Codebase probing → spawn
When verifying Critical Files, searching domain keywords, checking Locked Decisions against AGENTS.md, or looking for omitted owners, delegate to parallel children:
`spawn({prompt: "Probe <files/keywords> for story <epic>/<step>. Verify Critical Files resolve; search beyond them for domain owners, existing tests, public APIs, callsites/routes, duplicate/deprecated implementations, reusable code, hidden gotchas, and Locked Decision conflicts with AGENTS.md or established patterns. Be read-only. Write findings to notebook page 'plan-review-probe-<epic>-<step>' with path:line anchors.", thinking: "medium"})`.

Retrieve: `notebook_read({name: "plan-review-probe-<epic>-<step>"})`.

### Traceability / adversarial review → notebook
Before verdict, write a compact trace map to `notebook_write({name: "plan-review-trace-<epic>-<step>", content: "..."})` covering:
- forward trace: `CONTRACT.md`/original intent/epic source → Purpose/Scope/Scenarios/Acceptance → Verification rows → code/test surfaces
- backward trace: every planned helper/API/test/proof/command/config branch → Acceptance id → in-scope rationale and `CONTRACT.md`/original-intent source when available
- design trace when applicable: `Design Sources` anchor → visible element/state → required or bounded flexible trace row → Scenario → Acceptance → Verification row/rendered reviewer action
- contract conflicts: ticket/PR/Jira intent vs `CONTRACT.md` vs codebase, or none
- hypothesis triage: suspicious surface → tentative plan failure → next proof target
- evidence quality: confirmed / inferred / unknown / provisional

Retrieve it with `notebook_read({name: "plan-review-trace-<epic>-<step>"})` when writing the final log.

### Research Board from converger → notebook
Retrieve: `notebook_read({name: "plan-research-<epic>-<step>"})`. Verify entries with direct reads before using in findings.
