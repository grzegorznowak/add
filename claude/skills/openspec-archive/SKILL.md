---
name: openspec-archive
description: Archive a locally completed OpenSpec change workspace after pre-flight checks (review approved, tasks done, PR merged or explicitly waived). Thin wrapper over /opsx:archive.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug>"
allowed-tools: Read Grep Glob Edit Bash(gh pr view:*) Bash(date -u:*)
---

# OpenSpec Archive

Archive a completed OpenSpec change workspace after verifying all completion gates are satisfied. This is a thin wrapper over OpenSpec's built-in `/opsx:archive` command that adds pre-flight checks and a post-archive initiative update. It NEVER touches source code, tests, or product files.

Argument: `$ARGUMENTS` — `<initiative-slug> <story-slug>`. Both are required. The initiative slug identifies the parent initiative under `openspec/initiatives/`. The story slug identifies the change workspace under `openspec/changes/`.

## Resolution Model

- `<workspace_root>` = `<cwd>`.
- `<initiative_dir>` = `<workspace_root>/openspec/initiatives/<initiative-slug>`.
- `<initiative_file>` = `<initiative_dir>/initiative.md`.
- `<change_dir>` = `<workspace_root>/openspec/changes/<story-slug>`.
- `<progress_file>` = `<change_dir>/progress.md`.
- The `Status:` header in `story.md` is the archival gate signal.
- `<tasks_file>` = `<change_dir>/tasks.md`.
- `<blocked_file>` = `<change_dir>/blocked.md`.

## Important

This command is a coordination-only transition. It never touches source code, tests, config files, or product artifacts. It delegates the actual delta-spec sync and archive move to `/opsx:archive` after its own pre-flight checks pass.

## Phase 1 — Parse and resolve

1. Parse `$ARGUMENTS`:
   - `<initiative-slug>`: required first positional token.
   - `<story-slug>`: required second positional token.
   - Reject any additional tokens or unknown flags.
2. Validate both slugs before resolving paths. Each must match `^[a-z0-9]+(?:-[a-z0-9]+)*$`; if either fails, abort with: `invalid slug; use lowercase hyphenated slug characters only`.
3. Resolve `<initiative_dir>`. If `<initiative_dir>/initiative.md` is missing, abort with: `initiative not found: openspec/initiatives/<initiative-slug>/initiative.md`.
4. Resolve `<change_dir>`:
   - If `<change_dir>` is missing, check `<workspace_root>/openspec/changes/archive/<story-slug>/`.
   - If already archived, abort with: `story <story-slug> is already archived at openspec/changes/archive/<story-slug>/`.
   - If missing in both locations, abort with: `change workspace not found: openspec/changes/<story-slug>/`.
5. Read `<change_dir>/story.md`, then check `<blocked_file>` before offering any wrapper/direct route. If `blocked.md` exists, abort with the singular operator action to resolve the blocker and remove the file.
6. Read the authoritative `Status:` and `Plan:` header fields.
   - If `Status: 🟣 IN REVIEW`, abort with one route only even when `Plan:` contradicts it: note the Plan drift for review, open a completely fresh, oblivious session with no parent/converger notebook, implementation summary, operational notes, or prior chat context, then run `/openspec-story-review <initiative-slug> <story-slug>`. The wrapper never launches review.
   - If `Status: ✅ DONE` and `Plan:` is anything other than unambiguous `🟢 PLAN APPROVED`, abort with only `Operator action: investigate and reconcile the contradictory durable Status: ✅ DONE and Plan: <value> state before delivery or archive.` Do not recommend planning commands that reject DONE and do not invent a lifecycle owner.
   - Otherwise, if the non-DONE story's `Plan:` is not `🟢 PLAN APPROVED`, route planning repair before any claim/resume choice. For DRAFT or PLAN IN REVIEW, use direct `/openspec-story-plan-review <initiative-slug> <story-slug>` only when all required planning artifacts/sections exist, scaffold anchors are unambiguous, and no unresolved Plan Review Log finding remains; otherwise use direct `/openspec-story-plan-resume <initiative-slug> <story-slug>`. For PLAN CHANGES REQUESTED, unresolved findings route to direct plan-resume; fully blended findings with a structurally reviewable scaffold route to direct plan-review. PLAN BLOCKED and malformed/ambiguous lanes remain singular operator/repair routes. Do not offer implementation choices until planning is approved.
   - Then require `Status: ✅ DONE`. For TODO, offer the implementation Converge wrapper and Non-looped claim pass. For IN PROGRESS, offer the implementation Converge wrapper and Non-looped resume pass. Keep BLOCKED, missing, malformed/ambiguous, and unknown states singular. Use `/openspec-pr` only after local completion.
7. Read `<initiative_file>` for the post-archive update context.

## Phase 2 — Pre-flight checks

Run all four checks in order. Stop at the first failure and report exactly what must be resolved before archiving.

### Check A — blocked.md gate

If `<blocked_file>` exists at `<change_dir>/blocked.md`, abort with: `Story has an explicit block gate (blocked.md exists). Resolve the blocker and remove blocked.md before archiving.`

### Check B — PR State (PR must be merged)

Read `<progress_file>` and look for the `## PR State` section. Extract the `- PR URL:` value, trimming whitespace. If the section is absent, the `- PR URL:` line is absent, or the value is blank/placeholder (`<empty>`, `—`, `none`, or a template `<...>` value), this means there is no durable PR binding. Ask the operator: `No PR State found for <story-slug>. Archive without a PR? [y/N]`. If the operator declines, abort with the singular route: `Archive deferred. Run /openspec-pr <initiative-slug> <story-slug> to create or attach a PR.`

**If `## PR State` has a non-empty `- PR URL:` value:**

- Do not trust cached local `PR status`, `Merge commit`, or `Merged at` fields as merge evidence by themselves. Before passing the PR gate, run `gh pr view <url> --json state,mergedAt,mergeCommit` and use the live GitHub response as the authority.
- If `gh` is unavailable, the command fails, the PR cannot be read, or GitHub reports any non-merged state, abort with: `PR is not confirmed merged from GitHub. Run /openspec-pr <initiative-slug> <story-slug> <pr_url> to resync, then re-archive.` Include the observed state/error in the report.
- If GitHub confirms the PR is merged but `mergeCommit.oid` or `mergedAt` is missing, abort with the same resync hint; archive requires both a non-placeholder merge commit and a non-placeholder merged timestamp.
- If GitHub confirms merged with complete evidence, refresh/populate `## PR State` in `<progress_file>` so `- PR status: merged`, `- Merge commit:` (from `mergeCommit.oid`), `- Merged at:` (from `mergedAt`), and `- Last synced:` reflect the live response before continuing.

### Check C — Review approval

Use the `Status:` header already read from `<change_dir>/story.md` as the local review gate. The review check passes only when `Status: ✅ DONE`; Phase 1 aborts before pre-flight checks for any other status. Continue to Check D.

### Check D — Tasks completeness

If `<tasks_file>` does not exist, abort with: `Status: ✅ DONE contradicts missing tasks.md implementation evidence. Reconcile this in a completely fresh /openspec-story-review <initiative-slug> <story-slug> session.` Do not route to claim or resume.

Read `<tasks_file>`. If it is empty or whitespace-only, abort with: `Status: ✅ DONE contradicts empty tasks.md implementation evidence. Reconcile this in a completely fresh /openspec-story-review <initiative-slug> <story-slug> session.` Do not route to claim or resume.

Validate the task checklist shape before checking completion:

- Collect valid checkbox task lines matching `- [ ] <task description>` or `- [x] <task description>` / `- [X] <task description>` with a non-empty description.
- Treat malformed checkbox-like task lines as a hard DONE/evidence contradiction, including `- []`, `- [x]` with no description, or any `- [<marker>]` marker other than space, `x`, or `X`. List the malformed lines and route only to a completely fresh `/openspec-story-review <initiative-slug> <story-slug>` session; never claim or resume.
- If no valid checkbox task lines exist, report the DONE/evidence contradiction and route only to a completely fresh `/openspec-story-review <initiative-slug> <story-slug>` session.

If any valid unchecked tasks remain:

- List each unchecked task as `- [ ] <task description>`.
- Abort because `Status: ✅ DONE` contradicts task evidence. Route only to a completely fresh `/openspec-story-review <initiative-slug> <story-slug>` session so review owns reconciliation; never claim or resume.

### All pre-flights pass

If all four checks pass, print a summary gate report:

```
Pre-flight checks passed for <story-slug>:
- [x] blocked.md: not present
- [x] PR State: merged (or confirmed no-PR)
- [x] Review: approved and approval gate passed
- [x] Tasks: tasks.md present with valid checked/skipped/deferred task evidence
Proceeding to archive...
```

Then proceed to Phase 3.

## Phase 3 — Delegate to /opsx:archive

This is the delegation step. There is no manual move or manual spec-sync in this skill.

1. Read the OpenSpec schema file at `<workspace_root>/openspec/schemas/story-change/schema.yaml` for domain context (optional, only if needed for error diagnosis).
2. Archive the change workspace by running the built-in OpenSpec command `/opsx:archive`. This command:
   - Syncs the delta specs under `<change_dir>/specs/` into the durable specs at `<workspace_root>/openspec/specs/`.
   - Moves `<change_dir>` to `<workspace_root>/openspec/changes/archive/<story-slug>/`.

   **How to invoke `/opsx:archive`:** Call it as a built-in slash command with the change slug as its argument. If the underlying OpenSpec system requires a specific invocation form, provide the change name `<story-slug>`. The exact mechanism is: invoke `/opsx:archive <story-slug>`.

3. **If `/opsx:archive` succeeds**, confirm the outcome: verify that `<workspace_root>/openspec/changes/archive/<story-slug>/` now exists and `<change_dir>` no longer exists at its original location.
4. **If `/opsx:archive` fails**, report the error and do not proceed to Phase 4. Diagnose the failure: check if delta specs have conflicts with existing specs, if the change directory is writeable, or if the archive directory already has a conflicting entry. Do not attempt to fix OpenSpec internals — report what went wrong and suggest manual resolution.

## Phase 4 — Post-archive initiative update

After successful archiving, update `<initiative_file>`:

1. Read `<initiative_file>` again (it may have changed since Phase 1).
2. Locate the `## Story Candidates` section.
3. Append a note immediately after the section heading or at the end of the section's existing content:

   ```md
   - **Archived**: `<story-slug>` was archived on <YYYY-MM-DD>.
   ```

   Use the current UTC date for `<YYYY-MM-DD>`. If there are already other `- **Archived**:` entries, add this one as the newest entry at the end of the list.

4. If the `## Story Candidates` section does not exist, create one with the archived note as its first content:

   ```md
   ## Story Candidates
   - **Archived**: `<story-slug>` was archived on <YYYY-MM-DD>.
   ```

5. Do not modify any other section of the initiative file. Do not add to `## Feedback-Derived Story Candidates`, `## Feedback-Derived Decisions`, or any other section. Do not change the `source_of_truth` flag or the `## Goal / Context` section.

## Rules

1. **Never archive a story that fails any pre-flight check.** Abort with a precise reason and recovery hint for each failure.
2. **Never touch source code, tests, or product files.** This command is a coordination-only transition.
3. **Never manually move files or manually sync specs.** The actual archive operation is `/opsx:archive`'s responsibility.
4. **Never modify initiative.md beyond the `## Story Candidates` archival note.** Other sections are owned by other commands.
5. **Never archive an already-archived story.** Detect and abort early.
6. **Never override the operator's explicit no-PR decision.** When `## PR State` is absent, ask; don't assume.
7. **Never proceed to Phase 3 if Phase 2 fails.** Each pre-flight check is a hard gate.

## Final response

State:
- The story slug and initiative slug that were archived.
- The archive destination: `openspec/changes/archive/<story-slug>/`.
- Which pre-flight checks passed.
- Whether the post-archive initiative update was applied.
- The updated `initiative.md` path.

End every success or abort response with exactly one selected route:

```markdown
Suggested next action: <scalar recovery route or None; leave empty only for a dual route>
- Converge wrapper: <command; dual routes only>
- Non-looped pass: <state-correct command; dual routes only>
Choose one; do not run both.
```

For scalar routes, put the value on the label line and omit the three dual-route lines. For a valid TODO/IN PROGRESS implementation choice only, leave the label empty and render the Converge wrapper line, the state-correct Non-looped pass line, and `Choose one; do not run both.` immediately after it. On successful archive, use `None. The story is archived and complete.` DONE with non-approved Plan uses only the operator action to investigate/reconcile the contradictory durable state and names no lifecycle owner. Keep blocked, malformed/ambiguous, Plan repair for non-DONE stories, PR resync, no-PR decision, archive failure, DONE/evidence contradiction, and terminal routes singular. IN REVIEW uses only the fresh oblivious review route.
