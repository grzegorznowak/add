## Pi Primitives

Use `spawn` for optional focused read-only probes. Do not use notebook pages to store Research Board entries, implementation proof state, lifecycle status, or claimed/reviewed decisions; `story.md`, `progress.md`, `tasks.md`, and `reviews.md` remain the canonical OpenSpec artifacts.

After story selection, use the canonical `<story_slug>` in every child prompt.

### Research before first change
Spawn a read-only child for the next acceptance/TAP slice you are about to implement, not for broad architecture:

```
spawn({prompt: "For openspec/<initiative_slug>/<story_slug>, research the next implementation slice: <A<n>> / <TAP-*>. Checklist: Critical Files resolve; reusable owner/callsites; existing test layout, fixtures, and CI lane; expected behavior-facing RED assertion or observable signal; fallback if the planned seam is wrong. Cite path:line anchors. Return a compact summary only; do not edit files.", thinking: "high"})
```

The parent chooses the red seam, performs TDD, edits files, and records proof in canonical OpenSpec artifacts (`progress.md`, `tasks.md`, and final review evidence), not notebook storage.

### Debt Friction check
When needed, spawn a focused read-only Debt Friction probe:

```
spawn({prompt: "Debt Friction check for openspec/<initiative_slug>/<story_slug>. Inspect for duplicated behavior, unclear ownership, weak tests, missing seams, hidden coupling. Only report with causal link: story action → evidence → delivery impact. Cite path:line anchors. Return a compact summary only.", thinking: "medium"})
```

Record accepted Debt Friction only in the canonical places named by the base skill (`progress.md` during implementation and review evidence when relevant).

### Research Board from converger
If a converger provides an in-memory Research Board in the prompt, verify entries with direct reads before acting. If an entry does not verify, report a `## Research Events` board-refresh signal in the final response; do not copy the board into notebook storage.
