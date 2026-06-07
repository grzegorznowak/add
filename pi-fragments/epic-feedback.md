## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

For large feedback batches, use evidence children only for bounded harvest or target checks:

- **Feedback harvest normalizer**: `spawn({prompt: "Normalize feedback sources for <epic>: collect PR/issue/review/manual items already identified by the parent, summarize each item, preserve stable source ids/URLs, and write 'feedback-harvest-<epic>' with anchors. Do not choose dispositions.", thinking: "medium"})`.
- **Target evidence probe**: `spawn({prompt: "Target evidence probe for feedback <FB-###> in <epic>: inspect plausible story/MASTER rows and cited paths only. Report matching acceptance/scope/log anchors and write 'feedback-target-<epic>-<FB-###>'. Do not choose final disposition or edit files.", thinking: "medium"})`.

The parent owns final disposition, acknowledgement plan, operator questions, story/MASTER edits, lane rules, and write-back.
