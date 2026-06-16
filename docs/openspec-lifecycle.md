# OpenSpec Lifecycle

The active `add` workflow is an OpenSpec initiative/change-workspace lifecycle.
Commands are designed for fresh sessions: each command reads repo-local
OpenSpec artifacts, performs one job, writes only the artifacts it owns, and
hands off through files rather than chat memory.

## Workspace model

```text
openspec/
├── initiatives/<initiative-slug>/initiative.md
├── changes/<story-slug>/
│   ├── proposal.md
│   ├── story.md
│   ├── design.md
│   ├── tasks.md
│   ├── specs/**/*.md
│   ├── progress.md
│   ├── reviews.md
│   └── blocked.md
└── changes/archive/<story-slug>/
```

- `initiative.md` groups related changes and stores initiative-level goal,
  constraints, decisions, resources, feedback receipts, and future story
  candidates.
- `openspec/changes/<story-slug>/` is the active change workspace for one
  story-sized outcome.
- `story.md → Plan:` is the authoritative planning lane.
- `story.md → Status:` is the authoritative implementation status.
- `blocked.md` is an explicit lifecycle gate. If it exists, implementation and
  archive commands stop until the blocker is resolved and the file is removed.
- `progress.md` and `reviews.md` hold runtime evidence; they are not planning
  inputs seeded by `/openspec-story-plan`.

There is no central tracker table in the active workflow. Commands discover
initiatives and changes from `openspec/initiatives/` and `openspec/changes/`.
`/openspec-next-action` is the read-only routing helper for this model: it
inspects current or selected initiative/change/spec artifacts and recommends the
next owner command without performing transitions.

## OpenSpec state machine

The diagram below is the canonical ASCII view of the active workflow. It shows
durable file states, not transient chat state. `/openspec-next-action` may
inspect any active initiative/change/spec state and recommend the next owner
command, but it never edits files or performs transitions.

```text
Legend: [state] = durable OpenSpec state, "-- command -->" = owner transition,
        {gate} = required file/evidence gate.

(no initiative)
    |
    | /openspec-initiative-plan
    v
[initiative.md]
    |
    | /openspec-story-plan INITIATIVE=<slug>
    v
[active change workspace]
  proposal.md + story.md + design.md + tasks.md + optional specs/**/*.md
  story.md: Plan = 🟡 PLAN DRAFT, Status = ⬜ TODO
    |
    v
+----------------------------- PLAN LANE --------------------------------+
|                                                                        |
| [🟡 PLAN DRAFT]                                                        |
|      | /openspec-story-plan-review                                     |
|      v                                                                 |
| [🟣 PLAN IN REVIEW]                                                    |
|      | approve                                                        |
|      +-------------------------------> [🟢 PLAN APPROVED]              |
|      | request changes / repairable planning gap                       |
|      +-------------------------------> [🟠 PLAN CHANGES REQUESTED]     |
|      |                        /openspec-story-plan-resume                |
|      |                                      v                          |
|      |                                 [🟡 PLAN DRAFT]                 |
|      | blocked verdict                                                 |
|      +-------------------------------> [⛔ PLAN BLOCKED]               |
|                                             | operator resolves cause   |
|                                             v                          |
|                                        [🟡 PLAN DRAFT or review]       |
|                                                                        |
| /openspec-feedback may downgrade or repair planning artifacts, but it   |
| never approves the Plan lane.                                           |
|                                                                        |
| /openspec-story-plan-converge orchestrates fresh review/resume passes   |
| until approved, blocked, no progress, invalid state, or cycle limit.    |
+------------------------------------------------------------------------+
    |
    | Only Plan: 🟢 PLAN APPROVED and no blocked.md unlocks implementation.
    v
+------------------------- IMPLEMENTATION LANE --------------------------+
|                                                                        |
| [⬜/⚪ TODO] --/openspec-story-claim--> [🔄 IN PROGRESS]                |
|                                         |                              |
|                                         | implementation complete      |
|                                         v                              |
|                                  [🟣 IN REVIEW]                        |
|                                                                        |
| /openspec-story-resume continues [🔄 IN PROGRESS], applies review/PR    |
| feedback, and returns completed work to [🟣 IN REVIEW].                |
|                                                                        |
| /openspec-story-review branches from [🟣 IN REVIEW]:                   |
|   request changes ---------------------------> [🔄 IN PROGRESS]        |
|   blocked -----------------------------------> [⛔ BLOCKED]            |
|   approve, no PR ----------------------------> [✅ DONE]               |
|   approve locally; next /openspec-story-pr --> [🟣 IN REVIEW]          |
|                                                                        |
| [⛔ BLOCKED] -- operator removes blocked.md --> [⛔ BLOCKED, resumable] |
| [⛔ BLOCKED, resumable] --/openspec-story-resume--> [🔄 IN PROGRESS]   |
|                                                                        |
| Optional PR stage owned by /openspec-story-pr:                         |
| [🟣 IN REVIEW] -- open or attach PR ---------> [🔵 IN PR]              |
| [🔵 IN PR] -- still open --------------------> [🔵 IN PR]              |
| [🔵 IN PR] -- PR requests changes -----------> [🔄 IN PROGRESS]        |
| [🔵 IN PR] -- merged evidence ---------------> [✅ DONE]               |
| explicit non-archived [✅ DONE] -- late PR --> [🔵 IN PR or ✅ DONE]    |
|                                                                        |
| /openspec-story-converge orchestrates fresh claim/resume/review passes  |
| until DONE, local approval, blocked, invalid state, no progress, or     |
| cycle budget exhaustion.                                               |
+------------------------------------------------------------------------+
    |
    | /openspec-archive preflights DONE, task checklist, review approval,
    | no blocked.md, and merged PR evidence or explicit no-PR confirmation.
    | It then delegates to OpenSpec /opsx:archive <story-slug>.
    v
[archived change workspace]
  openspec/changes/archive/<story-slug>/
[durable specs]
  openspec/specs/**
```

Side inputs and gates:

- `/openspec-feedback` can route feedback into initiative logs, story plan
  review logs, implementation review logs, future story candidates, or
  initiative-level decisions. It never touches product source, never approves
  the Plan lane, and never advances implementation status.
- `blocked.md` is the hard implementation and archive stop, even if the
  `Status:` header is stale.
- Delta specs live under the active change workspace until archive. The
  archive command delegates to OpenSpec's built-in `/opsx:archive` step, which
  syncs durable spec behavior into `openspec/specs/` and moves the workspace to
  `openspec/changes/archive/<story-slug>/`.

## Pi context-management building block

For Pi runtimes, ADD treats
[`pi-agenticoding`](https://github.com/agenticoding/pi-agenticoding) as a core
building block for getting the most out of these session-bounded workflows. The
extension provides `spawn`, `notebook`, and `handoff` primitives for isolated
subtasks, compact durable grounding, and deliberate clean-context handoffs; its
primer explicitly frames research, planning, and execution as separate jobs. See
its [Core Primitives](https://github.com/agenticoding/pi-agenticoding#core-primitives)
and [context primer](https://github.com/agenticoding/pi-agenticoding/blob/main/system-prompt.ts)
for the source of those runtime concepts.

`pi-agenticoding` is not OpenSpec-specific. ADD layers the OpenSpec artifact
conventions and command authority described here on top of those generic Pi
context-management tools, while the repo-local OpenSpec files remain the source
of truth.

## Standard lifecycle

### 1. Initiative planning

`/openspec-initiative-plan` creates exactly one initiative file:

```text
openspec/initiatives/<initiative-slug>/initiative.md
```

This is the initiative-level planning counterpart to `/openspec-story-plan`. It
records goal, source-of-truth mode, rough story candidates, decisions,
constraints, external resources, and risks. It never creates change workspaces
or touches product code.

### 2. Story/change planning

`/openspec-story-plan INITIATIVE=<slug>` creates one change workspace with:

- `proposal.md`
- `story.md`
- `design.md`
- `tasks.md`
- optional `specs/**/*.md`

The plan is proof-first. The story contract must name observable acceptance
criteria, verification commands, a Test Architecture Plan, and an Acceptance
Proof Matrix before implementation begins. Runtime files such as `progress.md`,
`reviews.md`, and `blocked.md` are intentionally left to the commands that own
them.

### 3. Plan review and repair

Planning uses a separate lane from implementation:

| Plan value | Meaning |
|---|---|
| `🟡 PLAN DRAFT` | Contract exists but needs review or repair. |
| `🟣 PLAN IN REVIEW` | Independent plan review is evaluating the contract. |
| `🟢 PLAN APPROVED` | Contract is approved for implementation or rework. |
| `🟠 PLAN CHANGES REQUESTED` | Planning feedback found contract/proof gaps. |
| `⛔ PLAN BLOCKED` | The story is not safely plannable until a blocker is resolved. |

Command ownership:

- `/openspec-story-plan-review` writes only the Plan lane and
  `story.md → ## Plan Review Log`.
- `/openspec-story-plan-resume` edits planning artifacts to absorb feedback and
  returns the Plan lane to draft; it does not approve its own work.
- `/openspec-story-plan-converge` orchestrates fresh plan-review and plan-resume
  sessions until approval, block, no-progress, or cycle limit. It performs no
  normal review/resume artifact writes itself; its direct writes are limited to
  safety normalization required by its skill contract, such as downgrading an
  orphaned `🟢 PLAN APPROVED` that lacks an independent approve log.
- `/openspec-feedback` may downgrade the Plan lane when new feedback changes a
  contract, but it never approves the plan.

Implementation cannot start or continue unless `Plan: 🟢 PLAN APPROVED`.

### 4. Implementation

Implementation uses `story.md → Status:`:

| Status value | Meaning |
|---|---|
| `⬜ TODO` / `⚪ TODO` | Not started. |
| `🔄 IN PROGRESS` | An implementation session owns current work. |
| `🟣 IN REVIEW` | Implementation is ready for independent local review. |
| `🔵 IN PR` | Local review passed and the optional PR stage is active. |
| `✅ DONE` | Local workflow is complete, and any active PR stage has merged. |
| `⛔ BLOCKED` | An implementation blocker exists. `blocked.md` is the hard gate. |

Implementation commands are red-first by default:

1. inspect source and the approved story contract;
2. choose the smallest credible failing seam;
3. make it fail for the right reason;
4. implement the smallest fix;
5. turn the focused seam green;
6. broaden verification and update proof evidence.

If red-first is infeasible, the implementation command must record a written
exception and an alternative proof path before proceeding.

### 5. Implementation review

`/openspec-story-review` is independent and read-only for product code. It may
write only the change workspace review/status artifacts it owns, chiefly:

- `reviews.md`
- `story.md → Status:`

Review checks the story contract, implementation, tests, task completion,
previous findings, design trace, risk lenses, and evidence quality. It can:

- request changes and route back to `/openspec-story-resume`;
- mark a story blocked;
- leave a locally approved story at `🟣 IN REVIEW` when a PR stage is expected;
- mark a no-PR local story `✅ DONE` when all completion gates pass.

### 6. Implementation convergence

`/openspec-story-converge <initiative> <story>` is an orchestrator for one
operator-selected change. It alternates fresh claim/resume/review sessions until
one of these hard stops occurs:

- authoritative `Status: ✅ DONE` with durable review or merged-PR evidence;
- local approval with `Status: 🟣 IN REVIEW` and optional next PR action;
- `blocked.md` or another explicit blocker;
- invalid lifecycle state, such as unapproved Plan lane;
- no-progress detection;
- cycle budget exhaustion.

The converger may pass neutral operational notes or sourced notebook page names
to child sessions. Those notes are orientation only; material claims must be
verified against live files before edits or verdicts.

### 7. Optional PR stage

`/openspec-story-pr` owns GitHub PR metadata and the `🔵 IN PR` state. It writes
`progress.md → ## PR State` and appends to `## Progress Timeline`.

Allowed transitions:

| From | To | Condition |
|---|---|---|
| `🟣 IN REVIEW` | `🔵 IN PR` | PR opened or attached. |
| `🔵 IN PR` | `🔵 IN PR` | PR refreshed and still open. |
| `🔵 IN PR` | `🔄 IN PROGRESS` | PR/reviewer requests changes. |
| `🔵 IN PR` | `✅ DONE` | PR is merged with durable merge commit and merged-at evidence. |
| explicit non-archived `✅ DONE` | `🔵 IN PR` | A late unmerged PR stage is injected. |
| explicit non-archived `✅ DONE` | `✅ DONE` | A late PR is already merged with durable evidence. |

PR bodies are product-facing. They must not paste implementation diary content
from `progress.md`, `reviews.md`, `tasks.md`, or internal planning sections.

### 8. Feedback absorption

`/openspec-feedback` is a side input to the lifecycle. It classifies structured
feedback and writes coordination artifacts only. It never touches product source,
worktrees, branches, archived changes, or PR bodies.

Canonical dispositions:

| Disposition | Destination |
|---|---|
| `queue-planning-feedback` | `story.md → ## Plan Review Log` and Plan lane downgrade. |
| `amend-existing-story` | Story/design contract edits plus Plan lane downgrade. |
| `resume-current-story` | `reviews.md`, optional contract edits, and next resume/plan-review action. |
| `new-story-candidate` | Initiative candidate section for future `/openspec-story-plan`. |
| `initiative-level-decision` | Initiative decision notes plus absorption log. |
| `defer-or-reject` | Initiative absorption log only. |

Contract-changing feedback must pass fresh `/openspec-story-plan-review` before
implementation continues.

### 9. Archive

`/openspec-archive <initiative> <story>` runs completion preflights and then
delegates the actual spec sync/move to the OpenSpec archive command. Archive
requires:

- `Status: ✅ DONE`;
- no `blocked.md`;
- task checklist complete;
- durable local review approval;
- merged PR evidence, or explicit operator confirmation that the story is
  archived without a PR stage.

After those gates pass, `/openspec-archive` invokes OpenSpec's built-in
`/opsx:archive <story-slug>` command. Archived workspaces move to
`openspec/changes/archive/<story-slug>/`; durable spec behavior lands under
`openspec/specs/` through that OpenSpec archive step.

## Command authority table

| Transition / write | Owner |
|---|---|
| Create `openspec/initiatives/<slug>/initiative.md` | `/openspec-initiative-plan` |
| Create change planning artifacts | `/openspec-story-plan` |
| `Plan:` independent verdict | `/openspec-story-plan-review` |
| Planning artifact repair | `/openspec-story-plan-resume` |
| Plan-lane downgrade from external feedback | `/openspec-feedback` |
| TODO → IN PROGRESS claim | `/openspec-story-claim` |
| Implementation progress, handoff, blocker creation | `/openspec-story-claim`, `/openspec-story-resume` |
| Implementation review log and local approval/request changes | `/openspec-story-review` |
| PR state and PR-driven transitions | `/openspec-story-pr` |
| Feedback routing receipts/candidates/decisions | `/openspec-feedback` |
| Archive preflight and delegation to `/opsx:archive` | `/openspec-archive` |
| Read-only lifecycle inspection and next-command recommendation | `/openspec-next-action` |
| Plan or implementation loop selection | `/openspec-story-plan-converge`, `/openspec-story-converge` |

`/openspec-next-action` recommends the owner command; loopers choose the next
command within their convergence loops. Neither bypasses command authority.

## Rules of thumb

1. Treat `story.md → Plan:` and `story.md → Status:` as the lane/status source
   of truth.
2. Do not implement without `Plan: 🟢 PLAN APPROVED`.
3. Do not approve implementation while proof rows are provisional or acceptance
   coverage is incomplete.
4. Do not leave a story at `✅ DONE` while an active PR is unmerged.
5. Do not archive `🔵 IN PR` or blocked stories.
6. Use `/openspec-feedback` for new external feedback, especially after a story
   is complete or when feedback might affect several stories.
7. Keep fresh-session boundaries: planning, plan review, implementation,
   implementation review, PR handling, feedback absorption, and archive are
   separate jobs.
