# Epic / Story Lifecycle

The `add` commands all share one status state machine. This document is the
single source of truth for what each status means and which commands
transition between them. When the rules in a command's body and the rules
here disagree, **this document wins** — open a PR to fix the command.

## Planning phase (pre-⚪ TODO)

Before a story enters the `⚪ TODO` state, it is created through a short
planning chain:

1. **`/epic-plan`** — once per epic. Bootstraps the epic directory and
   the `MASTER.md` skeleton (header, goal/context, legend, empty story
   tracker). Never touches story files or tracker rows. Aborts if the
   epic directory already exists.
2. **`/epic-story-plan EPIC=<slug>`** — once per story. Interviews the
   operator, captures actor context and scenario examples, validates the
   implementation-ready `Acceptance` contract and `Verification` proof matrix,
   writes `story-NN-<slug>.md`, and appends the `⚪ TODO` tracker row to
   `MASTER.md`.

Planning is proof-first: the proof surfaces must be concrete enough that
an implementer can inspect the repo and choose a smallest focused red
seam without re-planning the story. If the story spans multiple product
surfaces, variants, modes, or orchestration branches, the story must
expand that risk surface into a `Surface / Branch Proof Matrix`. If
shared helpers or multiple callsites are involved, the story must
distinguish helper, routing, and behavior proofs. If the feature is
prompt- or placeholder-driven, the story must include fail-open checks. If
raw persisted, external, framework, or generated input crosses into stricter
application assumptions, the proof contract must cover the `Input Boundary
Shape Risk` at the real input boundary.

Modern story drafts include `## Actors` and `## Scenarios / Behavior Examples`.
Legacy stories remain reviewable when either section is absent; absence alone is
not a blocker.
When scenarios are present, they funnel into the hard contract as
`Scenario -> Acceptance -> Verification`: normative scenarios must map to
acceptance ids, and the linked acceptance/proof path must cover the scenario's
concrete behavior.

This phase is upstream of the state-machine states. `/epic-story-plan`
feeds the first row of the tracker; the state diagram starts at
`⚪ TODO`.

After a story reaches `⚪ TODO`, `/epic-story-plan-converge` may be used as an
optional planning looper. It delegates to fresh `/epic-story-plan-review` and
`/epic-story-plan-resume` sessions until the plan is approved, blocked, or a
hard stop is reached. It does not claim the story and does not own any status
transition itself.

## Status values

Planning lane values are orthogonal to implementation status:

| Plan | Meaning |
|---|---|
| `🟡 PLAN DRAFT` | The story contract exists but needs fresh plan review before implementation should start or continue. |
| `🟣 PLAN IN REVIEW` | A plan-review pass is currently evaluating the contract. |
| `🟠 PLAN CHANGES REQUESTED` | Plan review or feedback found contract/proof gaps. Absorb unresolved gaps with `/epic-story-plan-resume`, then rerun `/epic-story-plan-review`; if feedback already blended the contract, run `/epic-story-plan-review` next. |
| `🟢 PLAN APPROVED` | The story contract is approved for implementation or implementation rework. |
| `⛔ PLAN BLOCKED` | The story contract is not safely plannable until the operator resolves a blocker. |

| Status | Meaning |
|---|---|
| `⚪ TODO` | Not started yet. The default state for newly created stories. |
| `🔄 IN PROGRESS` | A session is actively working on this story. Default method is red-first: inspect sources, choose the smallest focused failing seam, turn it green, then broaden verification. Contract drift or any explicit exception to red-first must be logged before review. |
| `🟣 IN REVIEW` | Implementation is done enough to review, the focused red-first path or explicit exception is recorded, the proof matrix is fully finalized, and any relevant epic-contract obligations are concrete enough to judge. Local review may still find issues, including epic contract drift. |
| `🔵 IN PR` | **Optional.** Local review passed and the changes are in a GitHub PR awaiting remote review and merge. Skip this stage entirely if a story does not need a PR. A local-DONE story moves back here if `/epic-story-pr` later opens or attaches an unmerged PR. |
| `✅ DONE` | Implementation and review are complete for the workflow known at the time. If a PR stage is active, the PR is merged. If a PR stage is added late to a local-DONE story, `/epic-story-pr` moves it back to `🔵 IN PR` until remote review completes. |
| `⛔ BLOCKED` | An external implementation blocker prevents progress. Planning blockers use `⛔ PLAN BLOCKED` in the `Plan` lane. |

`⛔ BLOCKED` is a side state. It can be entered from any of the active
statuses and exited back to whichever was correct when work resumes.

## State diagram

`/epic-feedback` is a side input to the state machine, not an implementation
status transition. It routes feedback into the epic absorption log,
planning-lane invalidation, story candidates, epic-level decisions, or a story
`Review Log` entry. Contract-changing feedback must pass independent
`/epic-story-plan-review` before `/epic-story-resume` can continue.

```
        PR / CURe / reviewer feedback
                    │
                    │ /epic-feedback
                    ▼
        ┌───────────────────────────┐
        │ Feedback Absorption Log   │
        └──────┬────────┬───────────┘
               │        ├─ future work -> /epic-story-plan
               │        └─ epic decision notes
               │
               ├─ story contract refinement
               │      -> Plan lane downgrade -> /epic-story-plan-review
               │
               └─ implementation review finding
                      -> Review Log
                      -> contract unchanged: /epic-story-resume
                      -> contract changed: /epic-story-plan-review
                      -> /epic-story-resume after Plan approval
```

```
                         ┌─────────────┐  ◀─── /epic-story-plan-review (sets Plan verdict)
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
                │               └──────┬──────┘  /epic-story-pr (resync)
                │                      │ ▲
                │        late /epic-story-pr │
                │          (unmerged PR) │
                │                      ▼ │
                │               back to 🔵 IN PR
                └───────────────────────┘
```

## Command authority

Each command has a defined window of which transitions it is allowed to
make. Sticking to these windows prevents two commands from racing on the
same row.

| From → To | `/epic-feedback` | `/epic-story-plan-resume` | `/epic-story-plan-review` | `/epic-story-claim` | `/epic-story-resume` | `/epic-story-review` | `/epic-story-pr` | `/epic-squash` |
|---|---|---|---|---|---|---|---|---|
| `Plan` lane downgrade/invalidation, implementation `Status` unchanged | ✅ | — | — | — | — | — | — | — |
| `Plan` lane draft after contract repair, implementation `Status` unchanged | — | ✅ | — | — | — | — | — | — |
| `Plan` lane independent review verdict, implementation `Status` unchanged | — | — | ✅ | — | — | — | — | — |
| `⚪ TODO` → `🔄 IN PROGRESS` | — | — | — | ✅ | — | — | — | — |
| `🔄 IN PROGRESS` → `🟣 IN REVIEW` | — | — | — | ✅ | ✅ | ✅ | — | — |
| `🟣 IN REVIEW` → `✅ DONE` (no PR stage) | — | — | — | — | ✅ | ✅ | — | — |
| `🟣 IN REVIEW` → `🔵 IN PR` | — | — | — | — | — | — | ✅ | — |
| `🔵 IN PR` → `🔄 IN PROGRESS` (changes requested) | — | — | — | — | — | — | ✅ | — |
| `🔵 IN PR` → `✅ DONE` (PR merged) | — | — | — | — | — | — | ✅ | — |
| `🔵 IN PR` → `🔵 IN PR` (refresh) | — | — | — | — | — | — | ✅ | — |
| `✅ DONE` → `🔵 IN PR` (late PR injection, unmerged PR) | — | — | — | — | — | — | ✅ | — |
| `✅ DONE` → `✅ DONE` (late PR metadata attach, PR already merged) | — | — | — | — | — | — | ✅ | — |
| `*` → `⛔ BLOCKED` | — | — | — | ✅ | ✅ | ✅ | — | — |
| `✅ DONE` → archived | — | — | — | — | — | — | — | ✅ |

`/epic-squash` does not transition statuses; it archives stories whose status
is already `✅ DONE` and folds their contract terms into the merged
`CONTRACT.md`.

`/epic-story-plan-converge` and `/epic-story-converge` are looper commands, not
transition owners. They may decide which underlying lifecycle command to run
next, but any lane or status change is made by `/epic-feedback`,
`/epic-story-plan-resume`, `/epic-story-plan-review`, `/epic-story-claim`,
`/epic-story-resume`, `/epic-story-review`, or `/epic-story-pr` according to
the table above. They may carry a session-only
Research Board of exactly sourced facts across fresh agents, but that board is
orientation only and never replaces live-source verification. The looper owns
keeping the board relevant to later passes. Fresh lifecycle agents only decide
whether the needed fact is present in the provided board; when it is, they
verify it with direct reads/search against the cited anchors instead of
rerunning expensive research. If direct verification shows a provided entry no
longer supports its claim, the executor reports a board-refresh signal with the
entry id and live-source anchors; the looper decides how to update, replace, or
retire that board entry.

`/epic-pr` is outside the story status state machine. It opens or refreshes an
epic-level PR from `CONTRACT.md` plus current non-archived `✅ DONE` stories,
writes only epic-level `## Epic PR Tracking` in `MASTER.md`, and never
transitions story rows.

`/epic-feedback` is also outside the story implementation-status state
machine. It absorbs CURe, PR, or reviewer feedback into epic/story
coordination docs, writes the epic-level `## Feedback Absorption Log`, may
refine non-archived story contract sections, may append implementation-review
findings to a story's `## Review Log`, and may downgrade or invalidate the
`Plan` lane when feedback changes the contract. It never creates full story
files, never changes implementation `Status`, and never sets `Plan` to
`🟢 PLAN APPROVED`; approval belongs to `/epic-story-plan-review`.

## Rules of thumb

1. **Never leave `✅ DONE` while a PR is open.** If the story uses the PR
   stage, only `/epic-story-pr` may move it to `✅ DONE`, and only after
   `gh pr view --json state` reports `MERGED`. If `/epic-story-pr` is run
   later for a non-archived local-DONE story and the PR is unmerged, it moves
   the story back to `🔵 IN PR`.
2. **Never archive a `🔵 IN PR` story.** `/epic-squash` skips them by design,
   and reports them in a "skipped" list so the operator knows to rerun after
   the PR merges.
3. **`⛔ BLOCKED` is reversible.** Don't delete progress when entering it; the
   work resumes from where it stopped.
4. **Status drift between `MASTER.md` and the story file header is a known
   failure mode.** `/epic-squash` flags implementation-status drift as part of Phase 1. The story header does not mirror the `Plan` lane.
5. **`MASTER.md` is the lookup table.** Story file headers are advisory; if
   the two disagree, `MASTER.md` wins. Commands that intentionally change
   status should update a parseable story header too.
6. **`/epic-story-plan-review` never advances implementation status.** It only
   updates the `Plan` lane and `## Plan Review Log`. It must never move a story
   into `⚪ TODO`, `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `🔵 IN PR`, `✅ DONE`, or
   implementation `⛔ BLOCKED`.
7. **Proof contracts must be final before local implementation review passes.**
   Planning may use `provisional` proof rows, but `/epic-story-review` cannot approve
   while any row remains provisional.
8. **Broad acceptance scope requires focused multipass review.** When
   `## Acceptance` has 6 or more concrete items, `/epic-story-review` cannot
   approve until every acceptance item is covered by a focused pass and the
   synthesis records no unresolved conflicts, inconclusive passes, or coverage
   gaps. Focused passes should be de-fragmented by evidence surface and
   root-cause family rather than split mechanically by acceptance item.
9. **Review findings carry triage and detailed rationale.** `/epic-story-review`
   should record compact hypothesis triage for inspected candidate issue threads
   and use detailed finding cards for concrete issues in both the review output
   and `## Review Log`.
10. **Review reruns must account for earlier review findings.** Before
   approving, `/epic-story-review` checks prior `## Review Log` concerns and
   records whether they are resolved, still open, superseded, or not assessable.
11. **Helper proof is not routing proof.** For multi-callsite or
   orchestration-heavy features, approval requires explicit proof that the
   supported callsites or branches actually route through the intended helper or
   branch logic.
12. **Fail-open prompt risks need explicit proof.** Prompt-driven or
    placeholder-driven stories are incomplete unless the proof contract checks
    for unresolved placeholders, silent no-op behavior on enabled paths, and
    unchanged behavior on an appropriate disabled/default path.
13. **Input boundary shape risks need real-boundary proof.** When raw
    persisted, external, framework, or generated input crosses into stricter
    application assumptions, approval requires proof from the named input
    boundary for every in-scope shape case, or an explicit exclusion / unknown
    with mitigation.
14. **Epic contract obligations are part of local review when present.**
    If `CONTRACT.md`, dependency stories, or relevant sibling stories define
    shared interfaces or invariants the story touches, `/epic-story-review` cannot
    approve while those obligations are violated unless the intentional drift is
    explicitly recorded and reflected in the review outcome.
15. **Use loopers to converge, not to change ownership.**
    `/epic-story-plan-converge` is for repeated plan-review/plan-resume passes
    before claim. `/epic-story-converge` is for an approved unstarted story or
    already-started implementation work. Neither replaces `/epic-story-pr`, and
    neither directly writes coordination files, source files, tests, or commits.
    Their Research Board remains in parent-session memory only and is not a
    durable cache. It is still a reusable source guide for later fresh agents:
    the looper curates relevance, while executors verify provided entries
    directly before trusting them and report refresh signals when a provided
    entry does not verify.
16. **Looper final reports are operational only.**
    `/epic-story-converge` reports `APPROVED` when local review approves but the
    authoritative status remains `🟣 IN REVIEW`, and reports `DONE` only when
    the authoritative status is `✅ DONE`. It should not suggest
    `/epic-story-pr` after `DONE`, and final reports must not include private
    thinking or deliberation text.

## The Legend block

Every epic's `MASTER.md` should include a Legend section listing the planning
lane and implementation status values it uses:

```md
## Legend
- `🟡 PLAN DRAFT` — contract exists but needs review
- `🟣 PLAN IN REVIEW` — contract review is running
- `🟠 PLAN CHANGES REQUESTED` — contract/proof gaps need plan-resume or fresh plan review
- `🟢 PLAN APPROVED` — contract is ready for implementation or rework
- `⛔ PLAN BLOCKED` — planning blocker exists
- `⚪ TODO` — not started yet
- `🔄 IN PROGRESS` — actively being worked; red-first path underway or exception recorded
- `🟣 IN REVIEW` — focused seam is green or exception is recorded; implementation/evidence ready for review
- `🔵 IN PR` — local review passed, PR opened, awaiting GitHub review + merge
- `✅ DONE` — completed with linked evidence or verification; if a late PR is opened, `/epic-story-pr` moves it back to `🔵 IN PR`
- `⛔ BLOCKED` — a concrete blocker exists; the story resumes once it is cleared
```
