---
name: openspec-archive
description: Archive a locally completed OpenSpec change workspace after pre-flight checks (review approved, tasks done, PR merged or explicitly waived). Thin wrapper over /opsx:archive.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug>"
allowed-tools: Read Grep Glob Edit Bash(git worktree:*) Bash(git status:*) Bash(git diff:*) Bash(git rev-parse:*) Bash(git ls-files:*) Bash(git hash-object:*) Bash(sha256sum:*) Bash(shasum:*) Bash(gh pr view:*) Bash(date -u:*)
---

# OpenSpec Archive

Archive a completed OpenSpec change workspace after verifying all completion gates are satisfied. This is a thin wrapper over OpenSpec's built-in `/opsx:archive` command that adds pre-flight checks and a post-archive initiative update. It NEVER touches source code, tests, or product files.

Argument: `$ARGUMENTS` — `<initiative-slug> <story-slug>`. Both are required. The initiative slug identifies the parent initiative under `openspec/initiatives/`. The story slug identifies the change workspace under `openspec/changes/`.

## Resolution Model

- `<workspace_root>` = `<cwd>` and remains the launch checkout/worktree-discovery base.
- `<openspec_root>` = the transient active coordination artifact anchor resolved in Phase 1; never persist an `OpenSpec root:` field.
- `<initiative_dir>` = `<openspec_root>/openspec/initiatives/<initiative-slug>`.
- `<initiative_file>` = `<initiative_dir>/initiative.md`.
- `<change_dir>` = `<openspec_root>/openspec/changes/<story-slug>`.
- `<progress_file>` = `<change_dir>/progress.md`.
- The `Status:` header in `story.md` is the archival gate signal. Inventory the top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line. Exactly one present line is valid only when its whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`; duplicate, empty, whitespace-before-colon, non-canonical, or otherwise malformed Initiative-like lines are hard conflicts, never legacy absence. A bound modern story also requires one qualifying implementation review receipt.
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
3. Discover the active OpenSpec root before reading lifecycle evidence, but never mutate through a remote/rootless archive adapter:
   - Set `<openspec_root>=<workspace_root>`, then inspect `<workspace_root>` and `git worktree list --porcelain`. This command accepts no `WORKTREE=` selector, so its first applicable tier is registered branch-worktree discovery.
   - A branch candidate is a registered worktree other than `<workspace_root>` on `refs/heads/<initiative-slug>/<story-slug>` containing both `<candidate>/openspec/initiatives/<initiative-slug>/initiative.md` and `<candidate>/openspec/changes/<story-slug>/story.md` (or the archived story path when checking terminal state). Exactly one qualifying branch worktree outranks a possibly stale launch checkout. Multiple qualifying branch worktrees halt for operator selection; never guess.
   - Only when no branch worktree qualifies, fall back to `<workspace_root>` and require both artifact families there. Ignore unrelated/non-branch matching copies instead of selecting an arbitrary root. If launch does not qualify, report the checked roots; when exactly one remote checkout contains both artifacts, print its exact rerun, otherwise ask the operator to identify the active checkout.
   - If the selected or identified active checkout differs from `<workspace_root>`, halt before any PR refresh, artifact edit, `/opsx:archive`, or initiative update. Print the exact two-step rerun: `cd <active-root>` followed by `/openspec-archive <initiative-slug> <story-slug>`. Do not invoke the rootless `/opsx:archive` adapter against that remote root. Adapter redesign remains deferred.
   - Continue only when launch fallback qualifies; then `<openspec_root>=<workspace_root>`. The root is transient and is never persisted.
4. Resolve `<initiative_dir>`. If `<initiative_dir>/initiative.md` is missing, abort with: `initiative not found: openspec/initiatives/<initiative-slug>/initiative.md`.
5. Resolve `<change_dir>`:
   - If `<change_dir>` is missing, check `<openspec_root>/openspec/changes/archive/<story-slug>/`.
   - If already archived, abort with: `story <story-slug> is already archived at openspec/changes/archive/<story-slug>/`.
   - If missing in both locations, abort with: `change workspace not found: openspec/changes/<story-slug>/`.
6. Read `<change_dir>/story.md` and resolve its initiative binding before any lifecycle route:
   - Inventory the complete top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line. Exactly one present line is valid only when its whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`. Duplicate canonical headers, an empty value, whitespace before the colon (for example `Initiative : foo`), a non-canonical value, or any other malformed Initiative-like line halts without mutation and reports every offending line. Never reinterpret malformed present input as zero-header legacy.
   - If the one valid value does not match the explicit `<initiative-slug>`, halt on the Initiative mismatch, report both values, and do not proceed or guess.
   - The two required positional slugs form an operator-explicit initiative+story pair. Only zero Initiative or Initiative-like lines is legacy. For that case, scan active `<openspec_root>/openspec/initiatives/*/initiative.md` files for exact `<story-slug>` associations in `## Story Candidates`. With no associations, the explicit pair may target the legacy story because its selected initiative file exists. With candidate evidence, require exactly one association equal to `<initiative-slug>`; a different or multiple association conflicts and halts. Print a compatibility warning and never backfill the header. An auto-defaulted or menu-selected initiative alone would not authorize zero-reference legacy compatibility.
7. Check `<blocked_file>` before offering any wrapper/direct route. If `blocked.md` exists, abort with the singular operator action to resolve the blocker and remove the file.
8. Read the authoritative `Status:` and `Plan:` header fields.
   - If `Status: 🟣 IN REVIEW`, abort with one route only even when `Plan:` contradicts it: note the Plan drift for review, open a completely fresh, oblivious session with no parent/converger notebook, implementation summary, operational notes, or prior chat context, then run `/openspec-story-review <initiative-slug> <story-slug>`. The wrapper never launches review.
   - If `Status: ✅ DONE`, inventory every `<progress_file> → ## Implementation Review Receipt` heading/body. When any receipt is present, require exactly one section and exactly one occurrence of every canonical field: `Reviewed at`, `Decision`, `Approval gate`, `Status transition`, `Evidence reviewed`, `Identity method`, `Identity digest`, `Identity bases`, `Identity paths`, `Findings`, `Proof`, and `Next owner`. Require `Decision: APPROVE`, `Approval gate: PASS`, a `Status transition` ending in `✅ DONE`, `Identity method: review-identity-v1`, one canonical `sha256:<lowercase-hex>` digest, and reproducible canonical JSON bases/path arrays (`[]` is valid for an empty list). Duplicate headings/bodies/fields, omitted or extra entry-shaped fields, malformed/contradictory values, or any other verdict routes only to `Open a completely fresh, oblivious session and run /openspec-story-review <initiative-slug> <story-slug>.` Never search older receipt history; fresh substantive review owns normalization. At this phase validate receipt shape and remember its digest but do not recompute identity or mutate PR State; Phase 2 selects the merged-PR versus no-PR identity gate. A true pre-v3 legacy DONE without a receipt is compatible only when the story has zero Initiative or Initiative-like header lines and zero receipt sections; warn that both artifacts are absent, use step 6's explicit/unique-association resolution, and backfill neither. A bound modern DONE with an absent receipt routes only to fresh oblivious review. After these gates, if `Plan:` is anything other than unambiguous `🟢 PLAN APPROVED`, abort with only `Operator action: investigate and reconcile the contradictory durable Status: ✅ DONE and Plan: <value> state before delivery or archive.` Do not recommend planning commands that reject DONE and do not invent a lifecycle owner.
   - Otherwise, if the non-DONE story's `Plan:` is not `🟢 PLAN APPROVED`, route planning repair before any claim/resume choice. For DRAFT or PLAN IN REVIEW, use direct `/openspec-story-plan-review <initiative-slug> <story-slug>` only when all required planning artifacts/sections exist, scaffold anchors are unambiguous, and no unresolved Plan Review Log finding remains; otherwise use direct `/openspec-story-plan-resume <initiative-slug> <story-slug>`. For PLAN CHANGES REQUESTED, unresolved findings route to direct plan-resume; fully blended findings with a structurally reviewable scaffold route to direct plan-review. PLAN BLOCKED and malformed/ambiguous lanes remain singular operator/repair routes. Do not offer implementation choices until planning is approved.
   - Then require `Status: ✅ DONE`. For TODO, offer the implementation Converge wrapper and Non-looped claim pass. For IN PROGRESS, offer the implementation Converge wrapper and Non-looped resume pass. Keep BLOCKED, missing, malformed/ambiguous, and unknown states singular. Use `/openspec-pr` only after local completion.
9. Read `<initiative_file>` for the post-archive update context.

## Phase 2 — Pre-flight checks

Run all four checks in order. Stop at the first failure and report exactly what must be resolved before archiving.

### Check A — blocked.md gate

If `<blocked_file>` exists at `<change_dir>/blocked.md`, abort with: `Story has an explicit block gate (blocked.md exists). Resolve the blocker and remove blocked.md before archiving.`

### Check B — PR State (PR must be merged)

Inventory all `## PR State` headings in `<progress_file>`; more than one is ambiguous and aborts to `/openspec-pr <initiative-slug> <story-slug>` for normalization. From the sole section, when present, extract the exactly-once `- PR URL:` value and trim whitespace. If the section is absent, the line is absent, or the value is blank/placeholder (`<empty>`, `—`, `none`, or a template `<...>` value), mark `<archive_route>=no-pr` and ask: `No PR State found for <story-slug>. Archive without a PR? [y/N]`. If the operator declines, abort with the singular route: `Archive deferred. Run /openspec-pr <initiative-slug> <story-slug> to create or attach a PR.` Do not recompute identity yet; the final no-PR gate runs after task checks and immediately before archive mutation.

**If the sole `## PR State` has a non-empty `- PR URL:` value, mark `<archive_route>=merged-pr` and:**

- For a modern receipt, require exactly one non-placeholder `Verified implementation digest:` and exactly one non-placeholder UTC `Verified at:` in PR State. The verified digest must exactly equal the current receipt's `Identity digest`; missing, duplicate, stale, or mismatched verification aborts with `/openspec-pr <initiative-slug> <story-slug> <pr_url>` so PR can recompute `review-identity-v1` and refresh the same record. Do not recompute identity in archive's merged-PR route. For the exact pre-v3 zero-Initiative/zero-receipt exception, warn that no digest comparison is possible and preserve the bounded compatibility route.
- Do not trust cached local `PR status`, `Merge commit`, or `Merged at` fields as merge evidence by themselves. Run `gh pr view <url> --json state,mergedAt,mergeCommit` and use the live GitHub response as authority.
- If `gh` is unavailable, the command fails, the PR cannot be read, or GitHub reports any non-merged state, abort with: `PR is not confirmed merged from GitHub. Run /openspec-pr <initiative-slug> <story-slug> <pr_url> to resync, then re-archive.` Include the observed state/error in the report.
- If GitHub confirms the PR is merged but `mergeCommit.oid` or `mergedAt` is missing, abort with the same resync hint; archive requires both a non-placeholder merge commit and a non-placeholder merged timestamp.
- If GitHub confirms merged with complete evidence, refresh/populate only the live delivery fields in `## PR State`: `PR status: merged`, `Merge commit:` (from `mergeCommit.oid`), `Merged at:` (from `mergedAt`), and `Last synced:`. Preserve the already-matched `Verified implementation digest` and `Verified at` byte-for-byte. This coordination refresh is outside `review-identity-v1`; do not recompute identity after archive's own PR State refresh.

### Check C — Review approval

Use the `Status:` header already read from `<change_dir>/story.md` as the local lifecycle gate. It must be `Status: ✅ DONE`; Phase 1 aborts before pre-flight checks for any other status.

Then consume `progress.md → ## Implementation Review Receipt`:

- Re-run Phase 1's exact receipt inventory and full canonical-field validation against the current file. Require the one APPROVE/PASS record, DONE-ending transition, and well-formed `review-identity-v1` fields. Duplicate, truncated, malformed, non-approving, or contradictory evidence routes only to `Open a completely fresh, oblivious session and run /openspec-story-review <initiative-slug> <story-slug>.` Never search for or select an older approval.
- For `<archive_route>=merged-pr`, require the still-current receipt digest to equal the PR State verified digest already checked before live merge verification. Do not recompute identity here or after archive's PR State refresh; PR established the identity checkpoint before PR delivery, and coordination-only PR State/timeline writes are excluded from `review-identity-v1`.
- For `<archive_route>=no-pr`, defer recomputation until after Check D so it occurs immediately before archive mutation. Receipt absence passes only for a true pre-v3 DONE story with zero Initiative or Initiative-like header lines and zero receipt sections. Print a compatibility warning, rely on the already-validated explicit/unique association, and synthesize neither binding nor receipt. A bound modern DONE with no receipt routes only to fresh oblivious review.
- Phase 1 routes every non-DONE story from authoritative `Status:` before this gate. An old receipt may be historical context but cannot override a current non-DONE lane.

Continue to Check D.

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

### Final no-PR identity gate

Only when `<archive_route>=no-pr` and a modern receipt exists, immediately before the first archive mutation re-read the Initiative-like header inventory, Status/Plan, blocked gate, and the complete receipt, then recompute canonical `review-identity-v1` from exactly its recorded `Identity bases` and `Identity paths`. Require the result to equal `Identity digest`; missing bases/paths, unavailable inputs, malformed method/value, or mismatch routes only to fresh oblivious `/openspec-story-review <initiative-slug> <story-slug>`. Do not write PR State for a no-PR archive. For the exact zero-Initiative/zero-receipt pre-v3 exception, warn and skip identity recomputation because no identity exists. After this gate, perform no coordination write before `/opsx:archive`; if any gate-bearing artifact changes, restart preflight rather than using the prior result.

For `<archive_route>=merged-pr`, do not recompute here: the receipt-equal PR State verification and live GitHub merged state are the authoritative archive evidence, and archive's own coordination refresh is outside identity scope.

### All pre-flights pass

If all four checks pass, print a summary gate report:

```
Pre-flight checks passed for <story-slug>:
- [x] blocked.md: not present
- [x] PR State: merged (or confirmed no-PR)
- [x] Review: exactly one complete canonical APPROVE/PASS/DONE receipt; merged PR State digest matched it, or no-PR review-identity-v1 recomputed immediately before archive (or exact pre-v3 zero-Initiative/zero-receipt compatibility)
- [x] Tasks: tasks.md present with valid checked/skipped/deferred task evidence
Proceeding to archive...
```

Then proceed to Phase 3.

## Phase 3 — Delegate to /opsx:archive

This is the delegation step. There is no manual move or manual spec-sync in this skill.

1. Assert again that `<openspec_root>` equals `<workspace_root>` and that the current launch checkout contains `<initiative_file>` and `<story_file>`. If not, halt before mutation and print `cd <openspec_root>` followed by `/openspec-archive <initiative-slug> <story-slug>`. The current rootless adapter is never invoked against a different checkout; redesign remains deferred. Then read the OpenSpec schema file at `<openspec_root>/openspec/schemas/story-change/schema.yaml` for domain context (optional, only if needed for error diagnosis) and capture a relative-path inventory of the coordination artifacts already in `<change_dir>`.
2. Archive the change workspace by running the built-in OpenSpec command `/opsx:archive`. This command:
   - Syncs the delta specs under `<change_dir>/specs/` into the durable specs at `<openspec_root>/openspec/specs/`.
   - Moves `<change_dir>` to `<openspec_root>/openspec/changes/archive/<story-slug>/`.
   - Must preserve the complete change-workspace artifact set, including `progress.md → ## Implementation Review Receipt` and any durable feedback-receipt/feedback-ledger evidence; archive must not regenerate, summarize, or drop those records.

   **How to invoke `/opsx:archive`:** Call it as a built-in slash command with the change slug as its argument. If the underlying OpenSpec system requires a specific invocation form, provide the change name `<story-slug>`. The exact mechanism is: invoke `/opsx:archive <story-slug>`.

3. **If `/opsx:archive` succeeds**, confirm the outcome: verify that `<openspec_root>/openspec/changes/archive/<story-slug>/` now exists and `<change_dir>` no longer exists at its original location. Compare the archived relative-path inventory with the pre-delegation inventory. If any coordination artifact is missing—including the implementation review receipt or feedback evidence—report an artifact-preservation failure and do not proceed to Phase 4; do not invent replacement records.
4. **If `/opsx:archive` fails**, report the error and do not proceed to Phase 4. Diagnose the failure: check if delta specs have conflicts with existing specs, if the change directory is writeable, or if the archive directory already has a conflicting entry. Do not attempt to fix OpenSpec internals — report what went wrong and suggest manual resolution. Invocation remains deferred to the runtime's built-in `/opsx:archive <story-slug>` adapter; this skill does not implement a manual fallback.

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

1. **Never archive a story that fails any pre-flight check.** Abort with a precise reason and recovery hint for each failure, including initiative-binding, transient-root, single-current-review-receipt, and artifact-preservation failures.
2. **Never touch source code, tests, or product files.** This command is a coordination-only transition.
3. **Never manually move files or manually sync specs.** The actual archive operation is `/opsx:archive`'s responsibility.
4. **Never modify initiative.md beyond the `## Story Candidates` archival note.** Other sections are owned by other commands.
5. **Never archive an already-archived story.** Detect and abort early.
6. **Never override the operator's explicit no-PR decision.** When `## PR State` is absent, ask; don't assume.
7. **Never proceed to Phase 3 if Phase 2 fails.** Each pre-flight check is a hard gate.
8. **Never archive without the route-specific identity gate.** A merged-PR route requires PR State's verified digest to equal the current receipt digest plus live GitHub merged evidence and never recomputes after archive's coordination refresh. A no-PR route recomputes `review-identity-v1` from the receipt-recorded bases/paths immediately before archive mutation. Route missing, mismatched, or unverifiable modern evidence to fresh substantive review.

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
