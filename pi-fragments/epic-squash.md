## Pi Primitives

Use `spawn`, `notebook_write`, `notebook_read`, `notebook_index`.

For large squashes, use bounded read-only fan-out by repo, domain, or story batch when it reduces context load:

`spawn({prompt: "Squash evidence pass for <epic>: verify <repo/domain/story-batch> claims against code and story evidence. Report discrepancies as story-vs-code, contract-vs-code, or code-regression candidates with path:line anchors. Write findings to notebook page 'squash-evidence-<epic>-<slug>'. Do not edit files, classify final discrepancies, move files, or decide archive actions.", thinking: "medium"})`.

The parent keeps story selection, discrepancy classification, product-code approval questions, contract edits, archive decisions, file moves, and final summary.
