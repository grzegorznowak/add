## Pi Primitives

Use `notebook_write`, `notebook_index`.

This skill maps directly to `notebook_write`. After identifying friction points and patches:
`notebook_write({name: "memorize-<topic>", content: "- <friction> (score: <N>/10)\n- Proposed patch: <description>"})`.

Use `notebook_index()` to find existing related memory pages when needed. Propose patches to AGENTS.md/stories/docs as before — confirm with operator before applying. The notebook page survives session resets without file edits.
