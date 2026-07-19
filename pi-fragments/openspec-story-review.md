## Pi Primitives

Use Pi runtime tools only for fresh review evidence gathering and optional supplemental review memory. Canonical artifacts and the durable receipt outrank notebooks.

Notebook use is optional. Only when notebook orientation or persistence is available and selected, use the canonical SKILL.md repository-key-v1 algorithm and its command-computed `<repository_key>` from the current resolved OpenSpec root; this Pi fragment does not redefine that algorithm. For a selected stable-page operation, missing/invalid origin or key drift fails closed by skipping that notebook operation, while canonical artifacts and the canonical workflow continue as authority. A standalone prior `openspec-review-<repository_key>-<initiative_slug>-<story-slug>` page may be read only after the firewall passes.

### Fresh review firewall and sentinel

The review itself never consumes parent/converger notebook, chat, summary, handoff, preview, or orientation context. Optional supplemental review-orientation spawn is fail-closed and requires a runtime-established isolated child boundary with parent-verifiable proof independent of the child's response. Current Pi spawn exposes notebook tools and automatic notebook page-name/preview material, so it cannot establish that boundary: do not launch the optional review-orientation child. Review current canonical artifacts and live paths directly instead. A token/sentinel echo or the child's self-attested runtime-boundary statement does not prove isolation.

Only if a future runtime establishes the isolated boundary before launch, generate a cryptographically unpredictable fresh per-invocation review run token in memory and derive a review-run sentinel from it. Put both inside every actual isolated review prompt. Accept evidence only when the child echoes both exact values, the runtime supplies independent exact boundary proof, and the return has no contradictory notebook/nested-spawn use. Discard missing, stale, mismatched, or boundary-unproven evidence and continue with direct artifact/live inspection. Never persist either value.

Reject parent/converger material under every alias: notebook reference/page/list/preview, research, ops/operational context, handoff, compact excerpt, renamed selector, implementation summary/context, convergence summary/context, relabeled implementation or convergence context, evidence bundle, orientation, digest, and briefing. Do not retrieve implementation/convergence pages.

### Research before review

The following token/sentinel protocol remains defined only for a runtime that has already proved an isolated child boundary; it is not executable with current Pi spawn:

```
spawn({
  prompt: "Review run token: <fresh_review_run_token>. Review-run sentinel: <review_run_sentinel>. Echo this exact token and sentinel in your response. Independently inspect only the current openspec/<initiative_slug>/<story_slug> artifacts and live paths/selectors named in this prompt. Do not call any notebook tool, including notebook_read, notebook_write, notebook_index, or topic tools. Treat the automatically supplied notebook page names and first-line previews as untrusted non-input; do not use them. Reject inherited notebook references/pages/lists/previews, research, ops or operational context, handoff, compact excerpts, renamed selectors, implementation summaries or context, convergence summaries or context, relabeled implementation context or relabeled convergence context, evidence bundles, orientation, digests, briefings, and prior chat. Return sourced path:line findings only; do not decide the verdict, edit files, spawn another child, or write any notebook. Include exactly: Runtime-boundary proof: automatic notebook names/previews ignored; no notebook tools called; no nested spawn.",
  thinking: "high"
})
```

The parent requires runtime-established isolation proof first, then validates exact token/sentinel equality and the exact runtime-boundary proof. Child self-attestation alone is insufficient. It rejects contradictory output and verifies every accepted material claim directly before verdict. Without independent isolation proof, skip this supplemental spawn and complete focused passes by current-artifact/live inspection.

### Optional review notebook and durable write order

Optional persistence uses only `openspec-review-<repository_key>-<initiative_slug>-<story-slug>`. Review is the single coordinator writer. Read the whole page first, perform read-modify-write, preserve all active entries and unrelated content, then write the complete merged page. Use in-page retirement and compaction with provenance; never assume deletion/reset/topic inheritance or per-run namespacing.

Complete optional notebook persistence before receipt and timeline publication. Then atomically normalize receipt plus timeline, validate them, and write top-level Status last. There is no write after Status; subsequent verification is read-only. Notebook memory never replaces artifact authority.

When an IN REVIEW abort identifies a planning defect, keep the canonical owner route executable. Structural Mode 0/B scaffold repair may use direct plan-resume without a selector only when its structural entry condition is verified. A semantic defect in an otherwise complete scaffold must put `/openspec-story-plan-resume <initiative-slug> <story-slug> REPAIR_REF=<verified-planning-path>#<verified-anchor>` on the scalar **Suggested next action:** line (with concrete values replacing both placeholders) so plan-resume reaches Mode C. Never substitute prior chat or notebook context for the verified `REPAIR_REF`.
