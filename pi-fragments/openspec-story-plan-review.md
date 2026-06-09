## Pi Primitives

Use Pi runtime tools (`spawn`, `notebook_write`, `notebook_read`, and `notebook_index`) only as optional read-only planning evidence probes and sourced notebook orientation. Follow the base skill's canonical Plan Review Log, Plan-lane, story-contract, and notebook-authority rules.

After story resolution, use the canonical `<initiative_slug>` and `<story_slug>` in every child prompt and Pi notebook page name.

### Research before plan review
When broad planning context would be noisy, spawn a read-only child for a focused evidence probe:

```
spawn({prompt: "For openspec/<initiative_slug>/<story_slug>, inspect planning evidence for <intent/owner/TAP/dependency/risk>. Write findings to notebook page 'openspec-plan-review-research-<initiative_slug>-<story_slug>' with path:line anchors. Do not decide the verdict or edit files.", thinking: "medium"})
```

Retrieve findings with `notebook_read({name: "openspec-plan-review-research-<initiative_slug>-<story_slug>"})`. Use child findings for orientation only. Verify every material claim with direct reads/search against cited anchors before any Plan Review Log write-back. If a converger names `openspec-plan-research-<initiative_slug>-<story_slug>`, retrieve it the same way and verify before use.
