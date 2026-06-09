## Pi Primitives

Use `spawn` for fresh child-agent launches. Do not use notebook pages as lifecycle authority, Research Board storage, proof state, review verdict storage, or operational-note storage for this command.

### Child-agent launches
Each cycle launches exactly one fresh subagent via `spawn`. Use:

```
spawn({prompt: "<full task prompt including Research Board, operational notes, and slash command>", thinking: "high"})
```

After the subagent returns, re-read coordination files (`story.md`, `progress.md`, `reviews.md`) directly to derive state — never trust subagent prose alone.

### Research Board and operational-note persistence
The converger maintains the Research Board and operational notes in memory only for the current run. Do not persist them to notebook pages or any other cache. If durable process learning is valuable after the run, ask the operator whether to record it separately; it must never replace `story.md`, `progress.md`, or `reviews.md` as lifecycle authority.
