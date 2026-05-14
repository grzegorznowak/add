---
name: merge-conflict-analysis
description: Analyze whether one git ref merges cleanly into another and, when conflicts exist, trace them to PR, Jira, or ticket-backed intent before recommending a resolution. Use when a merge conflict needs evidence-backed analysis without changing code.
disable-model-invocation: true
argument-hint: "REPO=<path> FROM=<incoming-ref> INTO=<target-ref> [TEMP_ROOT=/tmp]"
allowed-tools: Read Grep Glob Task Bash(git:*) Bash(gh:*) Bash(jira:*)
---

# Merge Conflict Analysis

Analyze whether `$FROM` can be merged into `$INTO` inside `$REPO`; if the merge conflicts, explain the real conflicts by tracing commits to PRs, Jira issues, business stories, or another reliable change-intent source. This is analysis-only: do not implement the resolution, commit, push, or leave the repository changed.

Argument: `$ARGUMENTS` — `REPO=<path> FROM=<incoming-ref> INTO=<target-ref> [TEMP_ROOT=/tmp]`. `FROM` is the incoming branch or ref to merge. `INTO` is the branch or ref that would receive the merge. `TEMP_ROOT` is optional and defaults to `/tmp`; any throwaway checkout or worktree must live below it.

## Non-negotiable rules

1. **Direction matters.** Always state that you are analyzing merging `FROM` into `INTO`.
2. **Analysis only.** Do not edit conflicted files, implement resolutions, commit, push, or modify tickets.
3. **Intent wins when grounded.** Business stories, Jira issues, PR rationale, acceptance criteria, and reliable ticket comments are the primary source of truth for intended behavior when they can be connected to the conflict.
4. **Code is evidence, not authority.** Use code to understand implementation and surrounding behavior; do not override clearly stated ticket-backed intent with code-shape guesses.
5. **Never invent linkage.** If a conflict cannot be connected to a meaningful story, Jira issue, PR rationale, or reliable change-intent source, mark it as requiring human clarification.
6. **Protect the working tree.** Never leave the target repo changed. Abort any temporary merge before finishing and restore the original checked-out ref if operating in place.
7. **Use temporary space safely.** Never create throwaway checkouts or worktrees inside `$REPO`, inside `$REPO/.git`, or as a sibling under `$REPO`'s parent directory. Use `$TEMP_ROOT`, defaulting to `/tmp`, and remove the temp checkout before finishing.
8. **Read before claiming.** Never speculate about commits, PRs, tickets, tests, or business requirements you have not actually inspected.
9. **Use parallel research when useful.** Use code research tools and subagents for independent files, tickets, PRs, or code paths when that improves confidence.

## Phase 0 — Parse arguments and validate repo

1. Parse `$ARGUMENTS` strictly as key-value pairs:
   - `REPO=<path>`: target git repository.
   - `FROM=<incoming-ref>`: incoming branch or ref to merge.
   - `INTO=<target-ref>`: branch or ref that would receive the merge.
   - `TEMP_ROOT=<path>`: optional temporary root, default `/tmp`.
2. Stop and ask for missing `REPO`, `FROM`, or `INTO`. Do not infer them from the current directory or branch.
3. Enter `$REPO` and validate:
   - it is a git repository
   - `FROM` and `INTO` resolve as git refs after fetch
   - no merge, rebase, cherry-pick, revert, or bisect is already in progress
4. Record the original checked-out branch or detached HEAD ref, current commit, and `git status --porcelain` output.
5. Fetch both refs from their remotes when applicable. If a ref is purely local, record that fact.

## Phase 1 — Choose safe execution mode

Choose one execution mode and state why:

1. **In-place mode** is allowed only when all conditions are true:
   - `git status --porcelain` is empty
   - no merge/rebase/cherry-pick/revert/bisect is in progress
   - the original checked-out ref can be restored before exit
   - the operator's working tree will not be dirtied by the probe
2. **Temporary checkout mode** is required when any in-place condition is false or ambiguous:
   - create a temporary worktree or checkout below `$TEMP_ROOT`
   - do not place it inside `$REPO`, `$REPO/.git`, or the parent directory of `$REPO`
   - remove it before the final response
3. If neither mode can be made safe, stop and report the safety blocker.

## Phase 2 — Attempt merge and classify result

1. In the chosen execution location, check out `INTO`.
2. Attempt `git merge --no-commit --no-ff FROM`.
3. If the merge is clean:
   - record that the merge is clean
   - collect notable incoming commits and PRs present on `FROM` but not yet in `INTO`
   - skip conflict analysis
4. If the merge conflicts:
   - inspect `git status --short`, `git status --porcelain=v1`, `git ls-files -u`, combined diffs, and merge-base data
   - handle multiple merge bases explicitly when present
   - identify each conflicted file and conflict shape
   - note when visible conflict markers are trivial but the underlying overlap is larger
5. Do not resolve files. Leave the merge in conflicted state only long enough to inspect it, then clean it up in Phase 5.

## Phase 3 — Analyze conflicts

For each conflicted file:

1. Identify what the `INTO` side is preserving or changing.
2. Identify what the `FROM` side is preserving or changing.
3. Use merge-base comparisons and file history to identify commits that introduced overlapping changes.
4. Prefer concrete evidence:
   - commit hashes and subjects
   - merge commits
   - PR or MR numbers
   - branch names
   - Jira or ticket keys
   - changed tests or acceptance fixtures
5. Inspect surrounding code, parent components/controllers, dependencies, and related tests enough to understand how each side implemented its requirement.
6. If the file-level history is incomplete, mine PR titles, PR bodies, merge commits, commit bodies, and branch names for more references before concluding that intent is missing.

## Phase 4 — Trace intent

For each conflict, trace implementation evidence back to intent:

1. Mine ticket keys and story references aggressively from:
   - commit subjects and bodies
   - merge commits
   - PR or MR titles and bodies
   - branch names
   - test names and fixture names when they refer to business scenarios
2. Read the relevant PRs and tickets before drawing conclusions from code.
3. For Jira, use `jira issue view` when available; otherwise report that Jira could not be read and use only inspected evidence.
4. Extract confirmed requirements first:
   - acceptance criteria
   - user-visible behavior
   - API, schema, configuration, or persisted-state contracts
   - explicit non-goals
   - notable ticket or PR clarifications
5. Separate confirmed requirements from inference. If Jira or ticket evidence is weak, contradictory, inaccessible, or absent, say so explicitly.
6. If meaningful story linkage exists, recommend the merged outcome that best preserves the ticket-backed requirements from both sides.
7. If meaningful story linkage does not exist, do not recommend a code-shape resolution. Mark the conflict as `HUMAN CLARIFICATION REQUIRED`.

## Phase 5 — Clean up

Before final response:

1. Abort any temporary merge.
2. Restore the original checked-out branch or detached HEAD if you operated in place.
3. Remove any temporary checkout or worktree under `$TEMP_ROOT`.
4. Confirm the target repo has the same working-tree state as recorded at intake, or clearly report any cleanup failure.

## Phase 6 — Final response

Use this format:

```markdown
**Merge Summary**: [repo, FROM, INTO, clean/conflicted, conflict count]
**Execution Mode**: [in-place or temp checkout, and why]
**Incoming Changes**: [only if merge is clean; short summary]
**Conflicts**:
- [file path]
  - INTO side: [commits / PRs / Jira tickets]
  - FROM side: [commits / PRs / Jira tickets]
  - Business requirements: [ticket-backed summary; acceptance criteria first]
  - Intent judgment: [which side better matches the business requirement, and why]
  - Recommended resolution: [what the merged file should preserve]
  - Validation: [tests/checks to run if someone implements the resolution]
**Confidence / Gaps**: [missing PR links, missing Jira IDs, ambiguous history, inaccessible tickets, etc.]
```

If a conflict lacks meaningful story linkage, replace the normal recommendation with:

```markdown
- Story linkage: NOT ESTABLISHED
- Status: HUMAN CLARIFICATION REQUIRED
- Reason: [why the available git/PR/Jira evidence is insufficient]
- Safe next step: [what a human should clarify or where to look next]
```

Keep the final answer concise, explicit about merge direction, and grounded in inspected commit, PR, ticket, and code evidence.
