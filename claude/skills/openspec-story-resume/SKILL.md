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

1. Set `<workspace_root>` = `<cwd>` and `<openspec_root>` = `<workspace_root>`. `<workspace_root>` is the launch checkout/root-repo discovery base; `<openspec_root>` is the transient artifact anchor for `openspec/...` and may be rerooted in memory. There is no persisted `OpenSpec root:` field.
2. Before reading lifecycle artifacts or making readiness decisions, run the OpenSpec-root preflight when `<story-slug>` is known:
   - Inspect explicit `WORKTREE="<basename>=<path>"` values first. If exactly one points at a git checkout that contains both `openspec/initiatives/<initiative-slug>/initiative.md` and `openspec/changes/<story-slug>/story.md`, treat it as operator-authoritative for the OpenSpec root: set `<openspec_root>=<path>` and route all coordination reads/writes there. If multiple explicit values qualify, ask the operator which checkout is active and halt until clarified; never guess. Explicit target-repo worktree overrides that do not contain both OpenSpec artifacts remain normal Phase 1 worktree inputs.
   - If no explicit value qualifies, inspect `git -C <workspace_root> worktree list --porcelain` for entries on branch `refs/heads/<initiative-slug>/<story-slug>` that contain both required files above. If exactly one valid candidate exists, set `<openspec_root>` to that candidate, even when `<workspace_root>` also has matching but possibly stale artifacts. If multiple valid candidates exist, ask the operator which checkout is active and halt until clarified; never guess.
   - If `<story-slug>` is omitted, do not run non-explicit branch-based discovery yet. Use `<workspace_root>` only to present the menu/auto-selection, then rerun this preflight immediately after a story is selected and before eligibility gates or writes. Do not invent a story from a worktree scan.
3. Read `<openspec_root>/openspec/initiatives/<initiative-slug>/initiative.md` to confirm the initiative exists and gather context.
   - If it is missing, do not guess or silently search other checkouts. Ask whether this story was claimed into a root repo worktree and the OpenSpec artifacts were moved there. Recommend rerunning `/openspec-story-resume <initiative-slug> [story-slug]` from that root worktree, or pass an explicit valid root `WORKTREE="<basename>=<path>"` when the story slug is provided. Halt until the command resolves a checkout that contains `openspec/initiatives/<initiative-slug>/initiative.md`.
4. If `story-slug` is provided:
   - Confirm `<openspec_root>/openspec/changes/<story-slug>/` exists and contains `story.md`.
   - If it is missing, check `<openspec_root>/openspec/changes/archive/<story-slug>/`; if archived, report that the story is archived and halt.
   - If it is missing from both active and archive locations, ask whether the story was moved to a root repo worktree during claim. Recommend rerunning from the checkout/worktree that contains `openspec/changes/<story-slug>/story.md`, or pass an explicit valid root `WORKTREE="<basename>=<path>"`. Halt without updating `progress.md` or touching implementation files.
   - Read `story.md` from `<openspec_root>` to extract the `Status:` header and confirm the change is in a resumable state.
5. If `story-slug` is omitted:
   - Scan all directories under `<openspec_root>/openspec/changes/` for `story.md` files.
   - Read each `story.md` and check the `Status:` header.
   - Select the first change with `Status: 🔄 IN PROGRESS`, or `Status: ⛔ BLOCKED` when `blocked.md` is absent (previous blocker resolved by removing the gate file).
   - Do not infer work from PR metadata alone. If PR feedback appears actionable for a locally DONE story, tell the operator to run `/openspec-feedback` first so feedback is classified and routed before implementation resumes.
   - If multiple are found, report them and ask the operator to disambiguate.
   - If none are found, report that no in-progress changes exist in this checkout. Ask whether the active story's OpenSpec artifacts were moved to a root repo worktree; if yes, rerun from that worktree or rerun with a story slug plus explicit valid root `WORKTREE=...`. Halt.
   - After selecting a story, rerun the OpenSpec-root preflight from step 2 for the selected `<story-slug>` and recompute all artifact paths from `<openspec_root>` before continuing.

### 0.2 Read All Change Workspace Artifacts

Before any implementation begins, read these files from the resolved change workspace (`<openspec_root>/openspec/changes/<story-slug>/`):

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

#### Resume Status Check

1. Read `story.md → Status:` after the Plan Approval and Blocker checks.
2. If `Status: 🔄 IN PROGRESS`, proceed.
3. If `Status: ⛔ BLOCKED` and `blocked.md` is absent, proceed only for the stale-blocker normalization described above.
4. If status is TODO, IN REVIEW, DONE, missing, or unknown, halt and recommend the owning lifecycle command (`/openspec-story-claim`, `/openspec-story-review`, `/openspec-feedback`, `/openspec-pr`, or `/openspec-next-action`) instead of guessing. For actionable PR feedback on a DONE story, recommend `/openspec-feedback <initiative-slug> --pr <pr-url>`; when acknowledged as `resume-current-story`, feedback reopens the story to `🔄 IN PROGRESS` before implementation resumes.

#### Parallelism Guard

1. Before refreshing `progress.md → ## Current Claim`, read the existing claim's `- Claimed at:` and `- Claimed by:` fields.
2. If the existing claim was updated within the last 2 minutes by a different runtime/agent, halt without editing `progress.md`, `story.md`, or implementation files. Report a potential parallelism conflict and include the observed claimant and timestamp.
3. If the claim is older than 2 minutes, absent, or clearly belongs to the current continuation session, proceed to Phase 1.

## Phase 1 — Worktree Preflight

### 1.1 Resolve Worktrees

1. Parse `WORKTREE` arguments into a map of `basename → path` for implementation worktree routing; this does not change `<openspec_root>` unless the Phase 0.1 OpenSpec-root preflight already validated the path as the artifact root.
2. Read `<openspec_root>/openspec/changes/<story-slug>/progress.md → ## Current Claim` and extract both:
   - the `- Worktrees:` child list (`- <repo-basename>: <absolute path>`), and
   - the `- Main-tree targets:` bullet, splitting comma-separated repo basenames and trimming whitespace.
3. Merge worktrees:
   - Operator-provided WORKTREE arguments take precedence.
   - If the operator provides none, use the worktrees from the current claim.
   - If the operator provides a subset, use operator values for those basenames and retain the rest from the claim.
4. Preserve main-tree targets from the current claim unless that basename now has an operator-provided or retained worktree. Do not drop the `Main-tree targets:` shape during claim refresh; `/openspec-story-review` uses it to scope dirty main-tree work.
5. Validate each worktree path exists and is a git repository.
6. Validate each worktree basename matches the repository's actual directory name or a known alias. Additionally, accept a recorded or explicit basename as a root-repo alias when its path resolves to the current `<openspec_root>` or `<workspace_root>` and that root is itself a git repo, even if the directory basename now differs from the original checkout basename. Treat that alias as the resolved repo identity without adding a persisted `OpenSpec root:` field or changing the `progress.md → ## Current Claim` shape.

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

1. Update `<openspec_root>/openspec/changes/<story-slug>/progress.md → ## Current Claim` with:
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

The `## Current Claim` section in `progress.md` uses the canonical claim shape consumed by review/converge. Preserve this shape exactly; do not add a persisted `OpenSpec root:` field:

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
| `🔄 IN PROGRESS` | `⛔ BLOCKED` | External blocker encountered |
| `⛔ BLOCKED` | `🔄 IN PROGRESS` | Blocker resolved after `blocked.md` removal |

`/openspec-story-resume` does not interpret PR metadata as a lifecycle status.
`/openspec-pr` may refresh PR metadata/evidence, but actionable PR feedback
must be routed through `/openspec-feedback` before implementation work resumes.

Status transitions update both:
1. `story.md → Status:` header
2. `progress.md → ## Session Handoff → Status:`

### 3.5 Default Behavior Rule

The agent's default behavior on resume is:
1. **Resume at `IN PROGRESS`** — Continue implementing remaining tasks.
2. **Move to `🟣 IN REVIEW` when done** — When all tasks are complete and implementation proof passes.
3. **Then hand off to review** — Tell the operator to open a completely fresh, oblivious session and run `/openspec-story-review <initiative-slug> <story-slug>` with no parent notebook, implementation summary, operational notes, or prior chat context. Optional PR delivery happens only after local completion.

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
3. Tell the operator to open a completely fresh, oblivious session and run `/openspec-story-review <initiative-slug> <story-slug>`; do not pass parent notebook entries, implementation summaries, operational notes, or prior chat context into review.

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

### PR State Boundary

If `progress.md → ## PR State` indicates a PR is open or has requested changes:
1. Do not refresh PR metadata, derive lifecycle status from PR metadata, or mark the story done.
2. If actionable PR feedback is present, report: "PR feedback is present. Run `/openspec-feedback <initiative-slug> --pr <pr-url>` to classify and route it; an acknowledged `resume-current-story` disposition reopens the story before implementation resumes."
3. If merged evidence appears, report: "PR may be merged; run `/openspec-pr` to refresh durable merge evidence for archive, or `/openspec-archive` when all archive gates are ready."
4. Otherwise report: "PR is open and awaiting review; no implementation work to resume unless feedback is routed through `/openspec-feedback`."
5. Halt and let the parent handle the PR delivery or feedback workflow.

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
- the exact next action for the next fresh session (`/openspec-story-review`, `/openspec-story-resume`, `/openspec-story-plan-converge`, `/openspec-pr`, or operator blocker resolution); when the next action is review, explicitly tell the operator to run it from a completely fresh, oblivious session with no parent notebook, implementation summary, operational notes, or prior chat context
