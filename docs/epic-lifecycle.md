# Epic / Story Lifecycle

The `add` commands all share one status state machine. This document is the
single source of truth for what each status means and which commands
transition between them. When the rules in a command's body and the rules
here disagree, **this document wins** — open a PR to fix the command.

## Planning phase (pre-⚪ TODO)

Before a story enters the `⚪ TODO` state, it passes through a linear
planning chain:

1. **`/epic-plan`** — once per epic. Bootstraps the epic directory and
   the `MASTER.md` skeleton (header, goal/context, legend, empty story
   tracker). Never touches story files or tracker rows. Aborts if the
   epic directory already exists.
2. **`/epic-story-plan EPIC=<slug>`** — once per story. Interview-driven
   draft that produces a plan file at
   `~/.claude/plans/<epic>-<story-slug>.md`. Never touches the epic
   directory or any tracker row. The plan must already contain the
   implementation-ready `Acceptance` contract and `Verification` proof
   matrix before it can be saved. Planning is proof-first: the proof
   surfaces must be concrete enough that an implementer can inspect the
   repo and choose a smallest focused red seam without re-planning the
   story. If the story spans multiple product surfaces, variants, modes,
   or orchestration branches, the plan must expand that risk surface into
   a `Surface / Branch Proof Matrix`. If shared helpers or multiple
   callsites are involved, the plan must distinguish helper, routing, and
   behavior proofs. If the feature is prompt- or placeholder-driven, the
   plan must include fail-open checks.
3. **`/epic-story-save EPIC=<slug>`** — once per story. Consumes the plan
   file, writes `story-NN-<slug>.md`, and appends a `⚪ TODO` row to
   `MASTER.md`. It must fail on malformed or incomplete acceptance/proof
   contracts rather than inventing missing structure. This is the
   transition into the state machine below.

This phase is entirely upstream of the state-machine states — the two
new commands are not states and do not appear as transitions in the
state diagram. They feed the first row of the tracker, nothing more.

## Status values

| Status | Meaning |
|---|---|
| `⚪ TODO` | Not started yet. The default state for newly created stories. |
| `🔄 IN PROGRESS` | A session is actively working on this story. Default method is red-first: inspect sources, choose the smallest focused failing seam, turn it green, then broaden verification. Contract drift or any explicit exception to red-first must be logged before review. |
| `🟣 IN REVIEW` | Implementation is done enough to review, the focused red-first path or explicit exception is recorded, the proof matrix is fully finalized, and any relevant epic-contract obligations are concrete enough to judge. Local review may still find issues, including epic contract drift. |
| `🔵 IN PR` | **Optional.** Local review passed and the changes are in a GitHub PR awaiting remote review and merge. Skip this stage entirely if a story does not need a PR. |
| `✅ DONE` | Implementation and review are both complete. If a PR stage was used, the PR is merged. |
| `⛔ BLOCKED` | An external blocker prevents progress, or `/epic-story-plan-review` has determined the plan is not implementable as specified. The story definition may be revised and work resumes once the blocker clears. |

`⛔ BLOCKED` is a side state. It can be entered from any of the active
statuses and exited back to whichever was correct when work resumes.

## State diagram

```
                         ┌─────────────┐  ◀─── /epic-story-plan-review (optional, logs verdict)
                         │   ⚪ TODO   │
                         └──────┬──────┘
                                │ /epic-story-claim
                                ▼
                         ┌─────────────┐  ◀─── /epic-story-resume
                         │ 🔄 IN PROG  │
                         └──────┬──────┘
                                │ implementation done
                                │   (via /epic-story-claim, /epic-story-resume, or /epic-story-review)
                                ▼
                         ┌─────────────┐
                         │ 🟣 IN REV   │
                         └──────┬──────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
        no PR stage                      /epic-story-pr (optional)
                │                               │
                │                               ▼
                │                       ┌─────────────┐
                │                       │  🔵 IN PR   │ ◀──┐
                │                       └──────┬──────┘    │
                │                              │           │
                │                       ┌──────┴──────┐    │
                │                  PR merged   PR requests changes
                │                       │             │    │
                │                       ▼             ▼    │
                │               ┌─────────────┐  ┌─────────┘
                │               │  ✅ DONE    │  /epic-story-resume
                │               └─────────────┘  /epic-story-pr (resync)
                │                       ▲
                └───────────────────────┘
```

## Command authority

Each command has a defined window of which transitions it is allowed to
make. Sticking to these windows prevents two commands from racing on the
same row.

| From → To | `/epic-story-claim` | `/epic-story-resume` | `/epic-story-plan-review` | `/epic-story-review` | `/epic-story-pr` | `/epic-squash` |
|---|---|---|---|---|---|---|
| `⚪ TODO` → `⚪ TODO` (plan review logged) | — | — | ✅ | — | — | — |
| `⚪ TODO` → `🔄 IN PROGRESS` | ✅ | — | — | — | — | — |
| `🔄 IN PROGRESS` → `🟣 IN REVIEW` | ✅ | ✅ | — | ✅ | — | — |
| `🟣 IN REVIEW` → `✅ DONE` (no PR stage) | — | ✅ | — | ✅ | — | — |
| `🟣 IN REVIEW` → `🔵 IN PR` | — | — | — | — | ✅ | — |
| `🔵 IN PR` → `🔄 IN PROGRESS` (changes requested) | — | — | — | — | ✅ | — |
| `🔵 IN PR` → `✅ DONE` (PR merged) | — | — | — | — | ✅ | — |
| `🔵 IN PR` → `🔵 IN PR` (refresh) | — | — | — | — | ✅ | — |
| `*` → `⛔ BLOCKED` | ✅ | ✅ | ✅ | ✅ | — | — |
| `✅ DONE` → archived | — | — | — | — | — | ✅ |

`/epic-squash` does not transition statuses; it archives stories whose status
is already `✅ DONE` and folds their contract terms into the merged
`CONTRACT.md`.

## Rules of thumb

1. **Never mark `✅ DONE` while a PR is open.** If the story uses the PR
   stage, only `/epic-story-pr` may move it to `✅ DONE`, and only after
   `gh pr view --json state` reports `MERGED`.
2. **Never archive a `🔵 IN PR` story.** `/epic-squash` skips them by design,
   and reports them in a "skipped" list so the operator knows to rerun after
   the PR merges.
3. **`⛔ BLOCKED` is reversible.** Don't delete progress when entering it; the
   work resumes from where it stopped.
4. **Status drift between `MASTER.md` and the story file header is a known
   failure mode.** `/epic-squash` flags it as part of Phase 1.
5. **`MASTER.md` is the lookup table.** Story file headers are advisory; if
   the two disagree, `MASTER.md` wins until `/epic-squash` reconciles them.
6. **`/epic-story-plan-review` never advances a story.** Its only allowed
   transitions are `⚪ TODO` → `⚪ TODO` (logged review) and
   `⚪ TODO` → `⛔ BLOCKED` (unsalvageable plan). It must never move a
   story into `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `🔵 IN PR`, or `✅ DONE`.
7. **Proof contracts must be final before local implementation review passes.**
   Planning may use `provisional` proof rows, but `/epic-story-review` cannot approve
   while any row remains provisional.
8. **Helper proof is not routing proof.** For multi-callsite or
   orchestration-heavy features, approval requires explicit proof that the
   supported callsites or branches actually route through the intended helper or
   branch logic.
9. **Fail-open prompt risks need explicit proof.** Prompt-driven or
   placeholder-driven stories are incomplete unless the proof contract checks
   for unresolved placeholders, silent no-op behavior on enabled paths, and
   unchanged behavior on an appropriate disabled/default path.
10. **Epic contract obligations are part of local review when present.**
    If `CONTRACT.md`, dependency stories, or relevant sibling stories define
    shared interfaces or invariants the story touches, `/epic-story-review` cannot
    approve while those obligations are violated unless the intentional drift is
    explicitly recorded and reflected in the review outcome.

## The Legend block

Every epic's `MASTER.md` should include a Legend section listing the status
values it uses. The commands in this repo will add the `🔵 IN PR` line
automatically the first time they touch an epic that doesn't have it:

```md
## Legend
- `⚪ TODO` — not started yet
- `🔄 IN PROGRESS` — actively being worked; red-first path underway or exception recorded
- `🟣 IN REVIEW` — focused seam is green or exception is recorded; implementation/evidence ready for review
- `🔵 IN PR` — local review passed, PR opened, awaiting GitHub review + merge
- `✅ DONE` — completed with linked evidence or verification
- `⛔ BLOCKED` — a concrete blocker exists; the story resumes once it is cleared
```
