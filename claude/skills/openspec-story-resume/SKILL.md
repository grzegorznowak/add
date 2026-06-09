---
name: openspec-story-resume
description: Resume implementation of an in-progress OpenSpec change story — picks up where the last session left off, applies red-first discipline, verifies implementation proof, and tracks progress through change workspace artifacts. Use when a fresh session needs to continue ongoing implementation work on an OpenSpec change.
disable-model-invocation: true
argument-hint: "<initiative-slug> [story-slug] [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Edit Write Grep Glob Bash
---

# OpenSpec Story Resume

Resume implementation of an in-progress OpenSpec change story. This is the
implementation resume session — the agent picks up implementation where it
left off, applying red-first discipline, verifying implementation proof, and
tracking progress through the change workspace artifacts.

Argument: `$ARGUMENTS` — `<initiative_slug> [<story_slug>] [WORKTREE="<basename>=<path>"]...`. The initiative slug is required. The story slug is optional; when omitted and exactly one in-progress change workspace exists under the initiative, it is selected automatically. WORKTREE values are passed through unchanged to implementation commands.

## Source-of-Truth Hierarchy

This skill defers to the following artifacts, in priority order. Notebook context is sourced orientation only and is handled separately in `### Notebook Input`; it does not outrank or replace these artifacts.

1. **story.md `Status:` header** — Authoritative current lane/status.
2. **progress.md `## Current Claim`** — The most recent claim details, including assigned worktrees.
3. **progress.md `## Progress Timeline`** — Sequential implementation log (newest first).
4. **progress.md `## Session Handoff`** — Exit state from the most recent session.
5. **reviews.md** — Implementation review history (append-only; the latest review is the last entry in the file).
6. **story.md content** — Purpose, acceptance criteria, verification sections, Plan header.
7. **proposal.md** — The original proposal rationale and scope.
8. **design.md** — Technical design decisions.
9. **tasks.md** — Task checklist for implementation tracking.
10. **blocked.md** — Blocked state signal file (existence = blocked).
11. **initiative.md** — Parent initiative context.

## Phase 0 — Resolution

### 0.1 Resolve the Initiative and Change Workspace

1. Read `openspec/initiatives/<initiative-slug>/initiative.md` to confirm the initiative exists and gather context.
2. If `story-slug` is provided:
   - Confirm `openspec/changes/<story-slug>/` exists and contains `story.md`.
   - Read `story.md` to extract the `Status:` header and confirm the change is in a resumable state.
3. If `story-slug` is omitted:
   - Scan all directories under `openspec/changes/` for `story.md` files.
   - Read each `story.md` and check the `Status:` header.
   - Select the first change with `Status: 🔄 IN PROGRESS`, `Status: 🔵 IN PR` where `changes_requested` is present in reviews.md or progress.md, or `Status: ⛔ BLOCKED` when `blocked.md` is absent (previous blocker resolved by removing the gate file).
   - If multiple are found, report them and ask the operator to disambiguate.
   - If none are found, report that no in-progress changes exist and halt.

### 0.2 Read All Change Workspace Artifacts

Before any implementation begins, read these files from the resolved change workspace (`openspec/changes/<story-slug>/`):

1. **`proposal.md`** — Understand the "why" and scope boundaries.
2. **`story.md`** — Extract `Status:`, `Plan:`, `## Purpose`, `## Acceptance Criteria`, `## Verification`, and any other sections.
3. **`design.md`** — Understand architecture decisions, if present.
4. **`tasks.md`** — Extract the task checklist for implementation tracking.
5. **`progress.md`** — Extract `## Current Claim`, `## Progress Timeline`, `## Session Handoff`, `## PR State`.
6. **`reviews.md`** — Extract most recent review entry and any unresolved feedback.
7. Check for `blocked.md` existence — if present, the change is blocked; treat as a blocking signal.

### 0.3 Determine Resume Intent

Prioritize the resume intent from these sources (in order):

1. **Latest `reviews.md` entry** — Use the last append-only review entry. If there is unresolved review feedback, that is the primary resume intent.
2. **`progress.md → ## Session Handoff`** — The handoff from the most recent session.
3. **`progress.md → ## Progress Timeline`** (newest entry) — What was last done.
4. **`story.md → ## Purpose / ## Acceptance Criteria`** — The original intent, used as fallback.

Report the resolved resume intent to the operator before proceeding.

### 0.4 Pre-write Eligibility Gates

These gates must pass before Phase 1 worktree checks, Phase 2 claim refresh, any `progress.md` write, or implementation work. If any gate fails, halt without updating `progress.md → ## Current Claim` or appending to `## Progress Timeline`.

#### Plan Approval Check

1. Read `story.md → Plan:` header.
2. If `Plan: 🟢 PLAN APPROVED`, proceed.
3. If the `Plan:` header is missing or any other value (`🟡 PLAN DRAFT`, `🟣 PLAN IN REVIEW`, `🟠 PLAN CHANGES REQUESTED`, `⛔ PLAN BLOCKED`, or an unknown legacy value), halt. Report that implementation cannot proceed without plan approval and recommend `/openspec-story-plan-converge <initiative-slug> <story-slug>`.

#### Blocker Check

1. If `blocked.md` exists in the change workspace, read it and halt with the blocker message. File existence is the explicit lifecycle gate.
2. If `blocked.md` is absent but `story.md → Status:` contains `⛔ BLOCKED`, treat this as a resolved blocker marker: proceed, and normalize the status back to `🔄 IN PROGRESS` during Phase 2 before implementation work. Do not halt on status alone.
3. If `progress.md → ## Session Handoff → Status:` contains `⛔ BLOCKED` while `blocked.md` is absent, treat it as stale handoff context. Preserve it as history, but proceed and write a fresh handoff/status during this resume.
4. If a blocker is reported by any source other than the removed gate file, ask the operator to recreate `blocked.md` before halting; do not keep a story stranded solely by stale status text.

#### Parallelism Guard

1. Before refreshing `progress.md → ## Current Claim`, read the existing claim's `- Claimed at:` and `- Claimed by:` fields.
2. If the existing claim was updated within the last 2 minutes by a different runtime/agent, halt without editing `progress.md`, `story.md`, or implementation files. Report a potential parallelism conflict and include the observed claimant and timestamp.
3. If the claim is older than 2 minutes, absent, or clearly belongs to the current continuation session, proceed to Phase 1.

## Phase 1 — Worktree Preflight

### 1.1 Resolve Worktrees

1. Parse `WORKTREE` arguments into a map of `basename → path`.
2. Read `progress.md → ## Current Claim` and extract both:
   - the `- Worktrees:` child list (`- <repo-basename>: <absolute path>`), and
   - the `- Main-tree targets:` bullet, splitting comma-separated repo basenames and trimming whitespace.
3. Merge worktrees:
   - Operator-provided WORKTREE arguments take precedence.
   - If the operator provides none, use the worktrees from the current claim.
   - If the operator provides a subset, use operator values for those basenames and retain the rest from the claim.
4. Preserve main-tree targets from the current claim unless that basename now has an operator-provided or retained worktree. Do not drop the `Main-tree targets:` shape during claim refresh; `/openspec-story-review` uses it to scope dirty main-tree work.
5. Validate each worktree path exists and is a git repository.
6. Validate each worktree basename matches the repository's actual directory name or a known alias.

### 1.2 Dirty Detection

For each resolved worktree:

1. Run `git -C <path> status --porcelain` to detect uncommitted changes.
2. Run `git -C <path> diff --stat` to detect unstaged changes.
3. If dirty worktrees are found:
   - Report each dirty worktree with a summary of changes.
   - Ask the operator: "Dirty worktrees detected. Continue anyway? (yes/no)"
   - If the operator says no, halt.
   - If the operator says yes, proceed with a caution note.

### 1.3 Backward Compatibility

If the current claim has no `Worktrees:` field (older format), fall back to:
- Searching `progress.md → ## Progress Timeline` for worktree references.
- Using operator-provided WORKTREE arguments.
- If neither is available, continue without worktrees only when the target repo is known to be an intentional main-tree target or ask the operator to specify worktrees.

If the current claim has no `Main-tree targets:` field, treat it as legacy unknown rather than an empty intentional set. Do not invent targets, but preserve any existing `Main-tree targets:` value exactly when present.

## Phase 2 — Claim Refresh

### 2.1 Refresh the Current Claim

1. Update `progress.md → ## Current Claim` with:
   - Claimed/refreshed timestamp: Current ISO 8601 timestamp.
   - Worktrees: The resolved worktree map from Phase 1, using the canonical `- Worktrees:` parent bullet only when at least one worktree exists.
   - Main-tree targets: The preserved/resolved main-tree target basenames from Phase 1, using the canonical `- Main-tree targets:` bullet only when at least one main-tree target exists.
   - Claim: A concise statement of what this session will do, based on the resume intent from Phase 0.
   - Status: Current status (matches `story.md Status:` header), except a stale `⛔ BLOCKED` header with no `blocked.md` is first normalized to `🔄 IN PROGRESS`.

2. If `story.md → Status:` was `⛔ BLOCKED` and `blocked.md` is absent, update `story.md → Status:` to `🔄 IN PROGRESS` before writing the refreshed claim and include this timeline note before the normal resume entry:
   ```
   [<ISO 8601 timestamp>] **Unblocked**: blocked.md is absent; normalized stale blocked status to `🔄 IN PROGRESS`.
   ```
3. Append to `progress.md → ## Progress Timeline`:
   ```
   [<ISO 8601 timestamp>] **Resume**: <session resume summary>
     Worktrees: <basename>=<path>, ...
     Main-tree targets: <basename>, ...
     Claim: <claim statement>
   ```

### 2.2 Format

The `## Current Claim` section in `progress.md` uses the canonical claim shape consumed by review/converge:

```markdown
## Current Claim
- Claimed at: 2026-06-08T12:00:00Z
- Claimed by: $RUNTIME_NAME fresh session (resume)
- Model: $MODEL
- Scope: Implement the remaining tasks from tasks.md, starting with Task 3: ...
- Worktrees:
  - <repo-basename>: /absolute/path/to/worktree
  - <repo-basename>: /absolute/path/to/worktree
- Main-tree targets: <repo-basename>, <repo-basename>
- Primary write surfaces: <paths>
- Status: 🔄 IN PROGRESS
```

Omit `- Worktrees:` when no worktrees are resolved. Omit `- Main-tree targets:` only when there are no preserved/resolved main-tree targets.

## Phase 3 — Implementation

### 3.1 Gate Reconfirmation

Before implementing, confirm the pre-write eligibility gates from Phase 0.4 already passed in this run. If `story.md`, `progress.md`, or `blocked.md` changed after Phase 0.4, repeat the Plan Approval, Blocker, and Parallelism Guard checks before reading or writing implementation surfaces. Do not refresh `progress.md`, continue implementation, or mutate code when the plan is unapproved, a blocker signal is present, or a parallel session is detected.

### 3.2 Implementation Proof Preflight (READ BEFORE CODE)

Before writing any code, establish the implementation proof baseline:

1. **Read `story.md`** — Extract `## Verification` sections, acceptance criteria, and any explicit proof steps.
2. **Read `tasks.md`** — Extract the task checklist to understand what needs to be done, what is checked off, and what remains.
3. **Read `progress.md`** — Extract current state: what passed last, what was in progress, what failed.
4. **Formulate the proof** — State clearly: "To prove this is done, we will see: <observable outcomes>."

This proof must be stated explicitly to the operator before any code change.

### 3.3 Execution Rules

#### RED FIRST

For any behavior change:
1. Write or update a failing test FIRST.
2. Run the test to confirm it fails (RED).
3. Implement the minimal change to make it pass.
4. Run the test to confirm it passes (GREEN).
5. Run the surrounding test suite to detect regressions.

#### Implementation Progress Tracking

After each meaningful implementation step, append to `progress.md → ## Progress Timeline`:

```markdown
[<ISO 8601 timestamp>] **Step**: <action summary>
  - Changed: <files modified>
  - Test: <test result — PASS/FAIL>
  - Notes: <any observations>
```

#### Task Checklist Updates

As tasks from `tasks.md` are completed, mark them as checked:

```markdown
## Tasks

- [x] Task 1: Description  ← mark completed tasks
- [ ] Task 2: Description
- [x] Task 3: Description  ← mark completed tasks
```

#### Parallelism Guard Reconfirmation

**Only one implementation session per change workspace at a time.** The active-claim collision check must pass in Phase 0.4 before Phase 2 refreshes `progress.md → ## Current Claim`. Before beginning Phase 3, reconfirm only if `story.md`, `progress.md`, or `blocked.md` changed after Phase 0.4. If the current claim was updated within the last 2 minutes by a different runtime/agent after the pre-write guard passed, halt and report a potential parallelism conflict.

### 3.4 Status Transitions

The agent may transition the change status through these states:

| From | To | Trigger |
|------|----|---------|
| `🔄 IN PROGRESS` | `🔄 IN PROGRESS` | Continue implementing (default on resume) |
| `🔄 IN PROGRESS` | `🟣 IN REVIEW` | All tasks complete, ready for review |
| `🔵 IN PR` | `🔄 IN PROGRESS` | Changes requested in review |
| `🔵 IN PR` | `🔵 IN PR` | PR open, waiting for review |
| `🔵 IN PR` | `✅ DONE` | PR merged |
| `🔄 IN PROGRESS` | `⛔ BLOCKED` | External blocker encountered |
| `⛔ BLOCKED` | `🔄 IN PROGRESS` | Blocker resolved |

Status transitions update both:
1. `story.md → Status:` header
2. `progress.md → ## Session Handoff → Status:`

### 3.5 Default Behavior Rule

The agent's default behavior on resume is:
1. **Resume at `IN PROGRESS`** — Continue implementing remaining tasks.
2. **Move to `🟣 IN REVIEW` when done** — When all tasks are complete and implementation proof passes.
3. **Then hand off to PR** — The parent or a subsequent session will handle the PR workflow.

## Phase 4 — Finish Protocol

### 4.1 Session Handoff

When the session ends (natural completion, operator interrupt, or context limit approached), write to `progress.md → ## Session Handoff`:

```markdown
## Session Handoff

- **Timestamp**: <ISO 8601 timestamp, end of session>
- **Status**: <current status — 🔄 IN PROGRESS, 🟣 IN REVIEW, ✅ DONE, ⛔ BLOCKED>
- **Completed In This Session**:
  - <summary of what was done>
- **Remaining**:
  - <what still needs to be done, referencing tasks.md>
- **Blockers**: <any blockers, or "none">
- **Next Steps**: <concrete next actions for the next session>
- **Worktrees**:
  - <basename>: <path>
  - ...
- **Proof Statement**: <implementation proof status — what passed, what was verified>
```

### 4.2 Status Tracking

At session end, update:
1. `story.md → Status:` — Set to the current status.
2. `progress.md → ## Session Handoff → Status:` — Set to the current status.

### 4.3 Completed Session Signal

If all tasks are complete and implementation proof passes:
1. Transition status to `🟣 IN REVIEW`.
2. In the Session Handoff, note: "Ready for review. All tasks complete. Implementation proof passes."
3. The parent agent can then invoke the review flow.

### 4.4 Blocked Session Signal

If a blocker was encountered:
1. Create or update `blocked.md` with the blocker details.
2. Transition status to `⛔ BLOCKED`.
3. In the Session Handoff, detail the blocker and any known resolution steps.
4. Halt — do not continue implementation.

## Allowed Tools

- `read` — Read files
- `bash` — Execute shell commands (including git, test runners, linters)
- `edit` — Edit files with precise text replacement
- `write` — Write new files
- `notebook_read` — Read notebook pages
- `notebook_write` — Write notebook pages
- `notebook_index` — Scan notebook index

## Edge Cases

### Missing Artifacts

- **Missing `proposal.md`**: Proceed without it; note the absence in the session handoff.
- **Missing `design.md`**: Proceed without it; note the absence.
- **Missing `tasks.md`**: Create a minimal `tasks.md` from `story.md → ## Acceptance Criteria` items; ask the operator to confirm.
- **Missing `progress.md`**: Create it with `## Current Claim`, `## Progress Timeline`, `## Session Handoff`, `## PR State` sections.
- **Missing `reviews.md`**: Treat as no reviews yet; proceed normally.
- **Missing `story.md`**: Halt — this is a required artifact.

### Status Inconsistencies

If `story.md → Status:` and `progress.md → ## Session Handoff → Status:` disagree, prefer `story.md → Status:` (the durable status header) and note the inconsistency in the session handoff. A stale `⛔ BLOCKED` handoff does not block resume once `blocked.md` has been removed.

### Worktree Mismatch

If the resolved worktrees don't match what was in the previous claim:
1. Report the mismatch to the operator.
2. Use the operator-provided worktrees if specified.
3. If the operator didn't specify, ask which worktrees to use.
4. Document the change in the Progress Timeline.

### PR State Transition

If `progress.md → ## PR State` indicates a PR is open and the status is `🔵 IN PR`:
1. Check for `changes_requested` in reviews.md or progress.md.
2. If changes are requested, treat as "resume implementation."
3. If no changes are requested, report "PR is open and awaiting review; no implementation work to resume."
4. Halt and let the parent handle the PR workflow.

### No Remaining Work

If `tasks.md` shows all tasks complete and implementation proof passes:
1. Transition status to `🟣 IN REVIEW`.
2. Report completion to the operator.
3. Halt — no implementation to resume.

### Notebook Input

If the parent provides a `Notebook references from parent orchestration session` block, use only referenced notebook selectors or compact fallback excerpts for sourced orientation. Extract:
- sourced research relevant to the current tasks;
- unresolved open questions that still need verification against canonical artifacts; and
- constraints or approaches that are already anchored in cited source material.

When runtime notebook tools are available, read only the referenced notebook page/entry on demand. Verify cited anchors before making implementation decisions. If a referenced notebook entry or excerpt does not verify, mention the mismatch with exact anchors in the relevant final-response section; do not decide how to curate the notebook. If notebook orientation conflicts with the change workspace artifacts, flag the conflict and ask the operator to resolve.

## Default Legend

There is no `MASTER.md` legend to update. If status definitions or conventions need to be documented, note them in `progress.md` or `story.md` directly. The canonical status definitions are maintained in this skill's status transition table (Phase 3.5).

## Final response

State:
- which story was resumed (slug and path)
- the starting and final `Status:` values, including any `⛔ BLOCKED` → `🔄 IN PROGRESS` normalization after `blocked.md` removal
- files changed (coordination files and product files separately)
- tasks completed or still open
- proof commands run and results, or why proof was not run
- blockers, risks, or dirty worktree notes, if any
- notebook context used or updated, if material: referenced entries verified with direct-read/search anchors, stale referenced entries or absent needed facts with correction anchors, and notebook pages written for new sourced research; if notebook tools were unavailable, include compact sourced notes in the relevant final section instead
- the exact next action for the next fresh session (`/openspec-story-review`, `/openspec-story-resume`, `/openspec-story-plan-converge`, `/openspec-story-pr`, or operator blocker resolution)
