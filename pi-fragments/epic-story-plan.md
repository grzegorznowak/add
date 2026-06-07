## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

After the story's Purpose, Scope, and draft Acceptance have stabilized, optionally spawn one read-only discovery child before finalizing Verification:

`spawn({prompt: "Planning discovery for <epic>/<step>. Starting from Purpose/Scope/Acceptance, inspect the repo for test layout, fixtures, CI lanes, owning seams/callsites, activated risk surfaces, and candidate TAP rows. Use path:line anchors and write findings to notebook page 'plan-discovery-<epic>-<step>'. Do not make TAP/risk decisions or edit files.", thinking: "medium"})`.

Retrieve findings with `notebook_read({name: "plan-discovery-<epic>-<step>"})`. The parent keeps the interview, final Acceptance/TAP/risk choices, and all story writes.
