---
name: openspec-migrate
description: Remove the deprecated Implementation Review Receipt block from explicitly bound active OpenSpec changes after a deterministic fail-closed preview and digest confirmation.
disable-model-invocation: true
argument-hint: "<initiative-slug> [<story-slug>]"
allowed-tools: Bash(python3:*)
---

# OpenSpec Migrate

Run the bundled standard-library migration helper. Do not inspect, edit, or recreate migration targets yourself. The helper is the sole authority for parsing, containment, binding, preview construction, revalidation, and writes.

Argument: `$ARGUMENTS` — exactly one required `<initiative-slug>` and at most one optional `<story-slug>`. Reject flags and extra tokens. Both slugs must match `^[a-z0-9]+(?:-[a-z0-9]+)*$`.

## Execution contract

1. Use the checkout from which the command was launched as the workspace root. Do not select another worktree. Resolve `migrate.py` adjacent to this `SKILL.md`; do not copy it into the workspace or invoke a different helper.
2. Parse `$ARGUMENTS` once, preserving the same initiative/story positional order for both phases.
3. From the workspace root run:

   `python3 <absolute-skill-directory>/migrate.py preview <initiative-slug> [<story-slug>]`

4. Show the single JSON preview exactly as returned. Explain that `remove` is the complete write set, `no_op` is already current, and `excluded` is never inspected as active work. Ask the operator to confirm by supplying the exact 64-lowercase-hex `digest` from that preview. Do not treat a generic yes, silence, a digest from another run, or an edited scope as confirmation.
5. Only after receiving that exact digest, from the same workspace root run:

   `python3 <absolute-skill-directory>/migrate.py apply <initiative-slug> [<story-slug>] --confirm <digest>`

6. Report the helper's single JSON apply result exactly. A nonzero result is a failed migration; show its diagnostic and do not retry with broader permissions, repair files, or reuse the old digest.

## Safety and revalidation

`preview` never writes. `apply` rebuilds the complete plan from current bytes and accepts only the exact preview digest, thereby revalidating scope, active-only containment, initiative binding, regular-file/no-symlink constraints, receipt grammar, every source hash, and every constructed output before the first write. It then rechecks each source immediately before atomic per-file replacement and verifies the resulting bytes. Each successful atomic replacement is that file's commit point; the helper never attempts a racy post-commit rollback.

Any pre-commit drift, duplicate or malformed receipt material, ambiguous binding, traversal, archive/reviews target, symlink, or non-regular input must fail closed without changing source bytes. Containment or verification drift detected after a commit fails loudly as a partial migration and leaves committed or later concurrent bytes untouched. Request a fresh preview after any failure or independent change. Migration is idempotent: interrupted or partial reruns are safe, already migrated files become no-ops, and only remaining exact legacy blocks are previewed.

Only explicitly bound active changes are eligible. Unbound pre-v3 legacy stories are out of scope and left untouched because no safe initiative inference exists; they must not migrate even when named explicitly. Under `openspec/changes/`, `archive/` and archived changes are excluded and remain untouched.

The helper removes only the validated deprecated receipt byte range from active `progress.md`. It preserves every other byte, including timeline and non-review content, and never writes status, story, initiative, packet, Session Handoff, Progress Timeline, Review Focus, or review-history content. Never synthesize a receipt, approval, packet, replacement review evidence, or lifecycle authority.
