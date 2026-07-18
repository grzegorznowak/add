## Pi Primitives

Use Pi runtime tools (`spawn`, `notebook_write`, `notebook_read`, and `notebook_index`) only for fresh review evidence gathering and optional supplemental review-memory write-back. Follow the base skill's canonical review authority, durable `progress.md → ## Implementation Review Receipt`, and fresh-review firewall.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every child prompt and Pi notebook page name.

### Fresh review firewall

Do not retrieve, import, quote, summarize, or pass through any notebook page/reference supplied by an implementation parent or converger. Do not reuse implementation/convergence research or ops pages under a renamed selector. If inherited notebook context or prior implementation-session framing is present, abort under the base skill's Oblivious Context Boundary before spawning a child.

A standalone prior review page `openspec-review-<initiative_slug>-<story_slug>` may be read only after the firewall passes and only as optional sourced orientation. The story artifacts, live evidence, and durable implementation review receipt outrank it.

### Review coordination write-back

A fresh substantive review may reconcile malformed or duplicate review-owned receipt sections. Inventory their parseable findings without choosing a latest record, then build and validate a resulting `progress.md` that preserves unrelated sections while replacing all receipt sections with exactly one normalized current `## Implementation Review Receipt`. Follow the base fail-closed order: write `blocked.md` first for BLOCKED, write and re-read the normalized receipt plus required timeline entry, then update top-level Status last. Perform no writes after Status. Report any partial failure for explicit review-owned artifact reconciliation; never treat a failed APPROVE sequence as legacy DONE.

### Research before review

When broad context would be noisy, spawn a fresh read-only child for codebase evidence before forming review opinions. Give it only current artifact paths, canonical slugs, acceptance/proof selectors, and live repo/worktree locations discovered independently in this review session:

```
spawn({prompt: "For openspec/<initiative_slug>/<story_slug>, independently inspect the current story scope, critical files, existing tests, and activated risk-lens surfaces. Use only the current OpenSpec artifacts and live repo/worktree evidence named in this prompt. Do not retrieve or accept parent/converger notebooks, implementation summaries, operational notes, or prior chat context. Write sourced findings to notebook page 'openspec-review-research-<initiative_slug>-<story_slug>' with path:line anchors. Do not decide the verdict or edit files.", thinking: "high"})
```

Retrieve only that fresh review-session page with `notebook_read({name: "openspec-review-research-<initiative_slug>-<story_slug>"})`. Use child findings for orientation only. Verify every material claim with direct reads/search against cited anchors before any verdict, top-level `Status:` update, or receipt write. After the completed review, optionally persist supplemental findings to notebook page `openspec-review-<initiative_slug>-<story_slug>`; it never replaces the durable receipt.
