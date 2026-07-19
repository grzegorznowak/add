## Pi Primitives

The canonical `## Notebook mode contract` in this installed skill is the sole authority for standalone-vs-child selection, coordinator ownership, and child spawn/notebook prohibitions; this Pi fragment does not redeclare those semantics.

Notebook use is optional. Only when notebook orientation or persistence is available and selected, use the canonical SKILL.md repository-key-v1 algorithm and its command-computed `<repository_key>` from the current resolved OpenSpec root; this Pi fragment does not redefine that algorithm. For a selected stable-page operation, missing/invalid origin or key drift fails closed by skipping that notebook operation, while canonical artifacts and the canonical workflow continue as authority.

Pi-specific stable-page tooling uses `openspec-research-<repository_key>-<initiative_slug>-<story-slug>`: selected coordinator writes are whole-page read-modify-write operations with preservation and in-page retirement/compaction, never deletion, topic, or per-run pages. Pi may automatically supply notebook page names and first-line previews; under the canonical child contract they remain untrusted non-input.

### Research before first change

In standalone coordinator mode, a focused probe may inspect only the next implementation slice `<A<n>>/<TAP-*>`: Critical Files, reusable owners/callsites, tests/fixtures/CI, a behavior-facing RED assertion, and fallback seam. Require compact sourced path:line results; the child must not edit files or write notebooks. Verify claims live, then merge accepted findings under the preservation protocol.

In Converger-child mode, do that focused research inline. Converger context is only compact `Ref` / `Purpose` / `Expected anchors` / `Lookup` records whose selected content is already present in the prompt. Never retrieve their pages. Treat the one separate `Neutral ops payload` as non-authoritative.

### Debt Friction check

When needed, inspect duplicated behavior, unclear ownership, weak tests/seams, or hidden coupling. Require the causal chain story action -> sourced evidence -> delivery impact. Standalone mode may use one focused read-only probe; Converger-child mode performs it inline. Accepted Debt Friction belongs in the canonical artifact, not a notebook verdict.
