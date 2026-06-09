## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, and `notebook_index` for optional read-only planning evidence probes and shared notebook context. Notebook pages may store sourced planning research orientation only. Do not use notebook pages to store Plan lane decisions, review verdicts, approval evidence, lifecycle decisions, or story contract authority; `story.md` and its `## Plan Review Log` are canonical.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every child prompt and notebook page name.

### Research before plan review
When broad planning context would be noisy, spawn a read-only child for a focused evidence probe:

```
spawn({prompt: "For openspec/<initiative_slug>/<story_slug>, inspect planning evidence for <intent/owner/TAP/dependency/risk>. Write findings to notebook page 'openspec-plan-review-research-<initiative_slug>-<story_slug>' with path:line anchors. Do not decide the verdict or edit files.", thinking: "medium"})
```

Retrieve findings with `notebook_read({name: "openspec-plan-review-research-<initiative_slug>-<story_slug>"})`. Use child findings for orientation only. Verify every material claim with direct reads/search against cited anchors before any Plan Review Log write-back. If a converger names `openspec-plan-research-<initiative_slug>-<story_slug>`, retrieve it the same way and verify before use.
