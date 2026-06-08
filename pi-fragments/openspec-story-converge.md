## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

### Child-agent launches
Each cycle launches exactly one fresh subagent via `spawn`. Use:

```
spawn({prompt: "<full task prompt including Research Board, operational notes, and slash command>", thinking: "high"})
```

After the subagent returns, re-read coordination files (`story.md`, `progress.md`, `reviews.md`) directly to derive state — never trust subagent prose alone.

### Research Board persistence
The converger maintains an in-memory Research Board. Do not persist it to disk. When the board grows too large to pass in full, pause and ask the operator before compacting.

### Operational notes → notebook
After each cycle, update: `notebook_write({name: "converge-openspec-<initiative>-<story>", content: "- Cycle <n>: <result> — <state change>"})`.
