## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

After the story's Purpose, Scope, and draft Acceptance have stabilized, optionally spawn one read-only discovery child before finalizing Verification. Because story numbering is resolved later, first choose a deterministic draft notebook page name that does not use `<step>`, for example `plan-discovery-<epic>-draft-<draft-slug>`:

`spawn({prompt: "Planning discovery for draft story <epic>/<draft-slug>. Starting from Purpose/Scope/Acceptance, inspect the repo for test layout, fixtures, CI lanes, owning seams/callsites, activated risk surfaces, and candidate TAP rows. Use path:line anchors and write findings to notebook page 'plan-discovery-<epic>-draft-<draft-slug>'. Do not make TAP/risk decisions or edit files.", thinking: "medium"})`.

Retrieve findings with `notebook_read({name: "plan-discovery-<epic>-draft-<draft-slug>"})`. After `next_n` is resolved, carry only relevant evidence into the story or any resolved-step notes. The parent keeps the interview, final Acceptance/TAP/risk choices, and all story writes.
