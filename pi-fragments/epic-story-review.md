## Pi Primitives

Use `spawn`, `ledger_add`, `ledger_get`, `ledger_list`.

After Step selection, use the canonical resolved `Step` value as `<step>` in every ledger key. Never use the raw `<story>` selector, because callers may pass either a Step or a Spec filename. Slug free-form pass titles before embedding them in keys: lowercase, replace non-alphanumeric runs with `-`, trim leading/trailing `-`, and keep enough title text to remain unique within the review.

Ledger writes support review orchestration only. The story file's `## Review Log` remains the durable record. If any `ledger_add` write fails, keep going: include the same compact data in the final output and `## Review Log`, and note the ledger failure in `## Research Events`.

### Original intent / ticket archaeology → spawn
When the story, MASTER row, branch/history, dependency stories, PR text, or commit messages expose issue/PR/Jira/card anchors, delegate a read-only child to trace original intent:
`spawn({prompt: "For implementation review <epic>/<step>, inspect explicit original intent anchors only (GitHub issues/PRs, Jira/card ids, branch names, commit messages, dependency references, PR text). Build ticket/issue intent facts, contradictions with CONTRACT.md/story/code, missing acceptance cases, and inaccessible sources. Do not infer unlinked tickets. Write findings to ledger 'review-intent-<epic>-<step>' with exact anchors.", thinking: "medium"})`.

Retrieve: `ledger_get("review-intent-<epic>-<step>")`.

### Codebase probing / owner discovery → spawn
When checking changed surfaces, omitted owners, callsites/routes, duplicate implementations, generated/config/runtime surfaces, or reusable existing code, delegate parallel read-only children:
`spawn({prompt: "Probe implementation surfaces for review <epic>/<step>. Search beyond changed files for domain owners, existing tests, public APIs, callsites/routes, duplicate/deprecated implementations, generated/config/runtime surfaces, fixtures, CLI/API entrypoints, and sibling contract obligations. Be read-only. Write findings to ledger 'review-probe-<epic>-<step>' with path:line anchors and searches performed.", thinking: "medium"})`.

Retrieve: `ledger_get("review-probe-<epic>-<step>")`.

### Traceability / evidence ledger
Before verdict, write a compact implementation trace map to `ledger_add("review-trace-<epic>-<step>", ...)` covering:
- forward trace: `CONTRACT.md`/original intent/epic source → Purpose/Scope/Scenarios/Acceptance → final Verification rows → changed code/tests/config/runtime surfaces
- backward trace: every changed file/helper/API/test/proof/command/config/generated/runtime branch → Acceptance id → in-scope rationale and `CONTRACT.md`/original-intent source when available
- orphan changed surfaces or proof rows for unrequested behavior, or none
- contract conflicts: ticket/PR/Jira intent vs `CONTRACT.md` vs story vs codebase, or none
- code surfaces searched: paths/patterns/entrypoints/domain terms and any intentional omissions
- hypothesis triage: suspicious surface → tentative issue → next proof target
- evidence quality: confirmed / inferred / unknown / provisional

Retrieve it with `ledger_get("review-trace-<epic>-<step>")` when writing the final output and `## Review Log`.

### Multipass focused passes → spawn
Instead of sub-agents for each focused pass, use `spawn()`:
`spawn({prompt: "Focused review pass: <title> for <epic>/<step>. Inspect <files/symbols> for acceptance items <A<n>>. Be read-only. Write findings to ledger 'review-pass-<epic>-<step>-<slugged-title>' using the detailed finding card format, including code surfaces searched and evidence quality. Return summary.", thinking: "high"})`.

Synthesize by reading all pass ledger entries: `ledger_get("review-pass-<epic>-<step>-<slugged-pass>")` for each pass. If a pass ledger entry is missing or malformed, use the child return summary only as a hypothesis, verify directly before relying on it, and record the missing ledger entry as an evidence gap if it affects approval.

### Research Board from converger → ledger
Retrieve: `ledger_get("research-<epic>-<step>")`. Verify entries with direct reads against cited anchors before using in findings. If an entry doesn't verify, refine the entry with correction. Use this board as orientation only; direct anchors still govern findings, approval, and write-back.

### Review findings cache → ledger (optional)
For findings needing cross-session persistence beyond the story file's `## Review Log`: `ledger_add("review-<epic>-<step>", "## Review Findings\n...")`. The story file's `## Review Log` remains the durable record.
