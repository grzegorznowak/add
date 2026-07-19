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
│   └── blocked.md
└── changes/archive/<story-slug>/
```

- `initiative.md` groups related changes and stores initiative-level goal,
  constraints, decisions, resources, and future story candidates.
  `/openspec-feedback` creates `## Feedback Receipts` on first use; initiative
  planning does not seed that operational section.
- `openspec/changes/<story-slug>/` is the active change workspace for one
  story-sized outcome.
- `story.md → Initiative:` is the required top-level story-to-initiative binding.
- `story.md → Plan:` is the authoritative planning lane.
- The top-level `story.md → Status:` field is the authoritative implementation
  status; an `## Status` section is not equivalent.
- `blocked.md` is an explicit lifecycle gate. If it exists, lifecycle commands
  stop until the blocker is resolved and the file is removed.
- `progress.md` holds runtime evidence, including the durable implementation
  review receipt; it is not a planning input and is not seeded by
  `/openspec-story-plan`.

Commands may resolve a transient `<openspec_root>` that contains both selected
initiative and story artifacts, including after worktree relocation. For
commands accepting `WORKTREE=`, exactly one explicit value containing the pair
wins; several halt. If none qualifies, exactly one registered worktree on
`refs/heads/<initiative>/<story>` containing the pair wins even over a matching,
possibly stale launch copy; several branch candidates halt. The launch checkout
is fallback only when no qualifying branch worktree exists and it contains the
pair. Commands recompute every coordination path after selection and never
persist an absolute `OpenSpec root:` field in an artifact or receipt.

One feedback invocation resolves one root that contains its initiative plus
every targeted active story before acknowledgement or writes; all edits and
receipts use that root's single ledger. With no story target, a unique explicit
checkout wins; otherwise one registered `refs/heads/<initiative>/*` worktree
containing the initiative wins over launch. Multiple qualifying explicit or
initiative-branch worktrees halt; launch is fallback only when no branch
qualifies and it contains the initiative. A batch never splits ledgers. Archive
discovers the active root with the same unique-branch precedence, but remote-root
adapter redesign is deferred: when the active pair is outside the launch checkout, archive halts and requires a rerun
from that checkout rather than invoking rootless `/opsx:archive` against it.

A valid top-level `story.md → Initiative:` is authoritative for discovery,
menus, and routing. Commands first inventory every unindented Initiative or
Initiative-like field in the top-level header region. Zero such lines is legacy,
exactly one whole-line canonical header is valid, and duplicate or malformed
present lines halt. Empty values, whitespace-before-colon variants, and other
malformed Initiative-like fields never count as absence. `## Story Candidates`
is only a bounded compatibility index for a legacy story with zero such lines. Accept such a story only for an operator-explicit initiative **and story** pair with an existing initiative and
no exact association to a different or multiple initiatives, or discover it by
exactly one exact Story Candidates association. An auto-defaulted initiative or
initiative-only menu selection is not an explicit pair; a zero-association story
therefore remains unresolved until its story is also explicitly selected. Every
accepted case warns and never backfills the header. Duplicate, empty, malformed,
or mismatched headers and conflicting/ambiguous candidate evidence halt;
commands never guess from general prose.

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
  story.md: Initiative = <initiative>, Plan = 🟡 PLAN DRAFT, Status = ⚪ TODO
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
    | Implementation claim requires Plan: 🟢 PLAN APPROVED, no blocked.md,
    | TODO/unclaimed status, and /openspec-story-claim readiness gates,
    | including receipt-qualified ## Expected Prerequisites.
    v
+------------------------- IMPLEMENTATION LANE --------------------------+
|                                                                        |
| [⬜/⚪ TODO] --/openspec-story-claim--> [🔄 IN PROGRESS]                |
|                                         |                              |
|                                         | implementation complete      |
|                                         v                              |
|                                  [🟣 IN REVIEW]                        |
|                                                                        |
| /openspec-story-resume continues [🔄 IN PROGRESS], applies local review |
| or feedback that /openspec-feedback routed back to the story, and       |
| returns completed work to [🟣 IN REVIEW].                              |
|                                                                        |
| /openspec-story-review owns Status + review receipt and branches:      |
|   request changes -------------------------> [🔄 IN PROGRESS]          |
|   blocked -- blocked.md first -------------> [⛔ BLOCKED]              |
|   approve ---------------------------------> [✅ DONE]                 |
|                                                                        |
| [⛔ BLOCKED] -- operator removes blocked.md --> [⛔ BLOCKED, resumable] |
| [⛔ BLOCKED, resumable] --/openspec-story-resume--> [🔄 IN PROGRESS]   |
|                                                                        |
| PR delivery utility, not a story status:                               |
| [✅ DONE] -- /openspec-pr open/attach/refresh PR evidence               |
| PR feedback -- /openspec-feedback --> plan repair, story reopen/resume,|
|                 follow-up story, initiative decision, or defer/reject  |
| merged PR evidence + review approval + tasks --> /openspec-archive     |
|                                                                        |
| /openspec-story-converge orchestrates fresh claim/resume passes until  |
| IN REVIEW, blocked, invalid state, no progress, or cycle budget        |
| exhaustion. It never launches review.                                  |
+------------------------------------------------------------------------+
    |
    | /openspec-archive preflights DONE, tasks, blocker absence, valid receipt,
    | and matching merged-PR verification or no-PR identity recomputation.
    | It then delegates to OpenSpec /opsx:archive <story-slug>.
    v
[archived change workspace]
  openspec/changes/archive/<story-slug>/
[durable specs]
  openspec/specs/**
```

Side inputs and gates:

- `/openspec-feedback` can route feedback into initiative operational sections,
  story plan review logs, acknowledged story contract/reopen edits, future
  story candidates, or initiative-level decisions. Every disposition also gets
  one durable initiative receipt. Feedback never touches product source, never
  approves the Plan lane, and never advances implementation status. Its only
  status write is an acknowledged `resume-current-story` reopen from `✅ DONE`
  or `🟣 IN REVIEW` back to `🔄 IN PROGRESS`; PR metadata alone never reopens a
  story.
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
- `story.md`, including exactly one top-level `Initiative: <slug>` binding plus
  top-level `Plan:` and `Status:` fields
- `design.md`
- `tasks.md`
- optional `specs/**/*.md`

The plan is proof-first. The story contract uses the canonical `## Acceptance`
heading (never `## Acceptance Criteria`) and must name observable criteria,
verification commands, a Test Architecture Plan, and an Acceptance Proof Matrix
before implementation begins. Runtime files such as `progress.md`,
and `blocked.md` are intentionally left to the commands that own
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
- `/openspec-story-plan-resume` repairs/completes `proposal.md`, `story.md`,
  `design.md`, `tasks.md`, and delta files under `specs/`; repairs malformed
  story-plan scaffold anchors (`Plan:`, `Status:`, `## Plan Review Log`) within
  its narrow TODO-normalization rules; and returns the Plan lane to draft when
  plan content changed. It does not approve its own work or backfill Initiative.
- `/openspec-story-plan-converge` orchestrates fresh plan-review and plan-resume
  sessions until approval, block, no-progress, or cycle limit. It performs no
  normal review/resume artifact writes itself; its direct writes are limited to
  safety normalization required by its skill contract, such as downgrading an
  orphaned `🟢 PLAN APPROVED` that lacks an independent approve log.
- `/openspec-feedback` may downgrade the Plan lane when new feedback changes a
  contract, but it never approves the plan.

Implementation cannot start or continue unless `Plan: 🟢 PLAN APPROVED`.
A fresh claim also requires `/openspec-story-claim` readiness gates: TODO or
legacy-unset status, concrete change workspace, no `blocked.md`, and every
`## Expected Prerequisites` dependency qualified. Resolve active before archive
fallback; every prerequisite must have exact DONE Status and no `blocked.md`. A
bound prerequisite requires exactly one well-formed current APPROVE/PASS receipt
with every required field exactly once, a transition ending in DONE, and no
later contradiction. Prerequisite readers do not recompute
`review-identity-v1`. Any present unbound-story receipt uses the same
current-receipt checks. Only an unbound pre-v3 DONE with zero Initiative or
Initiative-like lines and zero receipt sections passes with a compatibility
warning. Planning commands apply the same bound-DONE receipt rule whenever they
inspect or route an already-DONE story; missing modern receipts are not legacy.

### 4. Implementation

Implementation uses `story.md → Status:`. `/openspec-story-claim` owns the
ready TODO-to-IN-PROGRESS transition; `/openspec-story-resume` owns authorized
continuation transitions, including return to IN REVIEW; feedback may only
perform an acknowledged reopen to IN PROGRESS; review owns completed-verdict
transitions:

| Status value | Meaning |
|---|---|
| `⬜ TODO` / `⚪ TODO` | Not started. |
| `🔄 IN PROGRESS` | An implementation session owns current work. |
| `🟣 IN REVIEW` | Implementation is ready for independent local review. |
| `✅ DONE` | Local workflow is complete after independent review approval. |
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

`/openspec-story-review` is independent, oblivious, and read-only for product
code. It must run from a completely fresh session with no implementation-loop
notebook, summary, operational notes, or prior chat context. It may write only:

- the single compact current completed verdict in
  `progress.md → ## Implementation Review Receipt`;
- the top-level `story.md → Status:` field;
- a concise `progress.md → ## Progress Timeline` transition entry;
- `blocked.md` for BLOCKED.

A completed verdict publishes in one unambiguous fail-closed order: for BLOCKED,
write `blocked.md` first; then replace/create the normalized receipt **and** its
required transition timeline entry together in the same validated `progress.md`
write; then update top-level Status last. Re-read after Status and perform no
later writes. A receipt/progress failure therefore cannot publish DONE/BLOCKED
Status. A Status failure leaves contradictory durable evidence that blocks DONE
and must be repaired rather than inferred away. Pre-verdict `NOT REVIEWABLE`
aborts write no blocker, receipt, Status, or timeline entry.

The receipt body records Reviewed at, Decision (`APPROVE`, `REQUEST CHANGES`, or
`BLOCKED`), Approval gate, Status transition, Evidence reviewed, Identity method
(`review-identity-v1`), Identity digest, Identity bases, Identity paths,
Findings, Proof, and Next owner. There is exactly one current receipt
heading/body: review replaces it after each completed verdict, while the
append-only progress timeline carries history. Review checks the story contract,
implementation, tests, tasks, prior findings, design trace, risk lenses, and
evidence quality. It can request changes and route to
`/openspec-story-resume`, block, or mark a locally approved story `✅ DONE` when
all completion gates pass.

Malformed or duplicate receipt sections fail closed for DONE delivery/archive.
A fresh oblivious review may reconcile them only after completing the substantive
review: it carries recoverable prior concerns into the assessment, replaces the
entire malformed/duplicate receipt span with one current well-formed body, and
then writes Status last. It never selects the apparent latest old body, invents
approval, or performs receipt-only cleanup.

Status controls non-DONE routing. Authorized later claim/resume/feedback work may
make an older receipt historical without deleting it; the next completed review
replaces it. DONE with a present receipt requires exactly one well-formed current
APPROVE/PASS body, a DONE transition, complete `review-identity-v1` fields, and
no later contradiction. Duplicate or malformed sections and FAIL/non-approve or
contradictory evidence block. A bound DONE missing its receipt also blocks in
planning and implementation routing. Only an unbound pre-v3 DONE—zero Initiative
or Initiative-like lines and zero receipt sections—gets bounded compatibility,
with a warning and no backfill.

`review-identity-v1` is story-scoped. Its receipt stores the digest and exact
scope as compact no-whitespace UTF-8 JSON arrays: bases use
`{"repo":"<basename>","base":"<review-base>"}` sorted by `repo` bytes and paths
use `{"repo":"<basename>","path":"<relative-path>"}` sorted by `repo`, then
`path` bytes (`[]` when empty); basenames and `(repo,path)` pairs are unique.
Each base is the full immutable Git commit object ID delimiting the story scope;
each path is relative to its repository root. For every listed
path, emit exactly one UTF-8, no-header row
`repo<TAB>path<TAB>type<TAB><lowercase-64-hex-sha256><LF>`. `repo` is the repository
basename; `path` is `/`-separated and relative to its repository root;
`type` is exactly `file`, `executable`, `symlink`, or `deleted`; and the row hash
covers exact file bytes, symlink-target bytes, or zero bytes for `deleted`.
Reject repository names or paths containing TAB, LF, or CR. Bytewise-sort the
complete encoded rows, concatenate them with every row LF-terminated and no
other bytes, then SHA-256 the result; an empty path list hashes zero bytes.

The path list is the exact reviewed story implementation/config/test/runtime
scope, including relevant tracked, modified, deleted, type-changed, and
non-ignored untracked paths. Exclude VCS metadata and the selected story's
review-owned coordination files `story.md`, `progress.md`, and `blocked.md`; do
not broadly exclude `openspec/` or unrelated selected source paths. PR
recomputes from the receipt bases/paths before any write, requires an exact
receipt-digest match, and records the verified digest/time in PR State. Archive
trusts that matching durable verification for a merged PR and does not
recompute; only the explicit no-PR archive route recomputes before writes.

GitHub PRs are external delivery/review channels. A PR may still be opened or
refreshed after local completion, but PR state does not own `story.md → Status:`.

### 6. Implementation convergence

`/openspec-story-converge <initiative> <story>` is an orchestrator for one
operator-selected change. It runs fresh claim/resume implementation sessions
until one of these hard stops occurs:

- authoritative `Status: 🟣 IN REVIEW`, meaning implementation is ready for
  independent review;
- an already-complete bound `Status: ✅ DONE` with exactly one well-formed
  current APPROVE/PASS receipt, complete identity fields, and no later
  contradiction, or an unbound pre-v3 DONE with no receipt and no contradictory
  durable evidence;
- `blocked.md` or another explicit blocker;
- invalid lifecycle state, such as unapproved Plan lane;
- no-progress detection;
- cycle budget exhaustion.

The converger may pass neutral operational notes or sourced notebook page names
to implementation child sessions only. Those notes are orientation only;
material claims must be verified against live files before edits. When the story
reaches `🟣 IN REVIEW`, the converger stops and tells the operator to open a
completely fresh, oblivious session and run `/openspec-story-review <initiative>
<story-slug>` without parent/converger notebook entries, implementation
summaries, operational notes, or prior chat context.

### 7. PR delivery helper

`/openspec-pr` is a lightweight PR delivery helper. It writes
`progress.md → ## PR State`, updates the product-facing PR body when possible,
and appends to `## Progress Timeline`. It does not change `story.md → Status:`.
Local story completion is represented by `Status: ✅ DONE`. A bound DONE requires
exactly one well-formed current APPROVE/PASS receipt with complete
`review-identity-v1` fields. PR resolves the recorded bases/paths, recomputes the
canonical manifest, and requires an exact receipt-digest match before **any** PR,
PR-body, or progress write. Its single progress write records both `Verified
implementation digest` and `Verified at` in PR State. Missing, duplicate,
non-approve/FAIL, malformed, mismatched, or contradictory evidence blocks.
Only an unbound pre-v3 DONE with zero Initiative or Initiative-like lines and no
receipt gets compatibility when every other gate passes; `/openspec-pr` warns
and never invents a receipt. For non-DONE Status, routing follows Status rather
than an older, now-historical receipt.

Supported operations:

| Operation | Effect |
|---|---|
| Open or attach a PR for a locally DONE story | Record/update `## PR State` and PR body. |
| Refresh PR metadata | Verify the current receipt digest before writes; update PR status, review decision, merge commit, merged-at, verified digest/time, and last-sync evidence. |
| PR merged | Record durable merge evidence plus matching verified digest/time for archive preflight. |
| PR or reviewer requests changes | Route through `/openspec-feedback` for classification; `/openspec-pr` does not mutate story status directly. |

PR bodies are product-facing. They must not paste implementation diary content
from `progress.md`, `tasks.md`, or internal planning sections.

### 8. Feedback absorption

`/openspec-feedback` is a side input to the lifecycle. It classifies structured
feedback, including GitHub PR review feedback, and writes coordination artifacts
only. It never touches product source, worktrees, branches, archived changes, or
PR bodies. When an acknowledged `resume-current-story` disposition invalidates a
locally completed or in-review result, it may reopen `story.md → Status:` to
`🔄 IN PROGRESS` so `/openspec-story-resume` can own the code changes.

Canonical dispositions:

| Disposition | Destination in addition to the receipt |
|---|---|
| `queue-planning-feedback` | `story.md → ## Plan Review Log` and Plan lane downgrade. |
| `amend-existing-story` | Acknowledged story/design/task contract edits, Plan lane downgrade, and an FB-tagged `progress.md` absorption checkpoint. |
| `resume-current-story` | Acknowledged top-level Status reopen to `🔄 IN PROGRESS`, optional contract edits, and an FB-tagged `progress.md` absorption checkpoint. |
| `new-story-candidate` | Initiative candidate section for future `/openspec-story-plan`. |
| `initiative-level-decision` | Initiative decision notes. |
| `defer-or-reject` | Receipt only, preserving the acknowledged reason. |

For every disposition, `/openspec-feedback` creates `## Feedback Receipts` in
`initiative.md` if absent and appends exactly one portable entry with Feedback
ID, Source ID, Source hash, Disposition, Target, Acknowledged reason/rationale,
Changed artifacts, and Next owner. `Source ID` plus `Source hash` is the
reproducible deduplication key: stable provider object IDs identify hosted
feedback. A manual/file item is valid UTF-8 with CRLF converted to LF and only
outer Unicode whitespace trimmed; SHA-256 is computed over the complete remaining
normalized UTF-8 bytes with no added delimiter or terminal LF. Its Source ID is
`manual:sha256:<full-hex>` and its Source hash uses that same full hash—never an
ordinal, path, label, timestamp, truncation, or runtime value. Identical
normalized items intentionally deduplicate regardless of payload order.

Before acknowledgement or any write, a feedback invocation resolves exactly one
root containing the selected initiative and every active targeted story. It
uses only that root's `initiative.md` ledger for dedupe, ID allocation, and all
receipts. For an initiative-only batch, a unique explicit checkout wins;
otherwise a unique registered initiative branch worktree outranks launch, while
none or ambiguity halts. It never sends receipts to per-story or stale launch
ledgers. The root remains in-memory and is not persisted.

Per item, feedback applies acknowledged owned edits—including `tasks.md`
contract/proof alignment where required—before appending its receipt. Every
`amend-existing-story` and `resume-current-story` mutation also appends an
FB-tagged `progress.md → ## Progress Timeline` absorption checkpoint: direct
amendments, status-only reopens, unchanged Status, and unchanged contract fields
are not exceptions; unchanged fields are recorded as `none`. Planning-queue
mutations carry their corresponding FB-tagged Plan Review Log entry.

If interrupted, a retry uses the deterministic source identity and current owned
artifacts to avoid repeating completed edits, then publishes the one missing
receipt after acknowledgement. An existing receipt is reused, not duplicated;
receipt-only dispositions recover by the same dedupe rule. Notebook support is
optional orientation only and cannot replace the ledger; `/openspec-feedback`
does not require notebook APIs. Contract-changing feedback must pass fresh
`/openspec-story-plan-review` before implementation continues.

### 9. Archive

`/openspec-archive <initiative> <story>` runs completion preflights and then
delegates the actual spec sync/move to the OpenSpec archive command. Archive
requires:

- `Status: ✅ DONE`;
- no `blocked.md`;
- task checklist complete;
- for a bound story, exactly one well-formed current APPROVE/PASS implementation
  review receipt with complete `review-identity-v1` digest/base/path fields;
- merged PR evidence whose PR State verified digest exactly matches the current
  receipt digest, or explicit operator confirmation of the no-PR route followed
  by exact identity recomputation before any archive write/delegation.

Only an unbound pre-v3 DONE with zero Initiative or Initiative-like lines and no
implementation review receipt remains archive compatible when every other gate
passes. Archive warns and never creates a synthetic receipt. A bound DONE with a
missing receipt blocks, as do duplicate, non-approving/FAIL, malformed, or
contradictory receipts. For a merged PR, archive trusts current matching PR
verification and does not recompute. For the explicit no-PR route, archive
recomputes `review-identity-v1` and requires an exact receipt-digest match before
any write or delegation.

After those gates pass, `/openspec-archive` invokes OpenSpec's built-in
`/opsx:archive <story-slug>` command from the checkout that contains the active
pair. Its rootless adapter redesign remains deferred: discovery may identify a
unique active branch worktree, but when that root differs from the launch
checkout archive halts with a `cd <active-root>` plus rerun instruction rather
than mutating it remotely. Archived workspaces move to
`openspec/changes/archive/<story-slug>/`; durable spec behavior lands under
`openspec/specs/` through that OpenSpec archive step.

## Command authority table

| Transition / write | Owner |
|---|---|
| Create `openspec/initiatives/<slug>/initiative.md` | `/openspec-initiative-plan` |
| Create change planning artifacts | `/openspec-story-plan` |
| `Plan:` independent verdict | `/openspec-story-plan-review` |
| Repair/complete `proposal.md`, `story.md`, `design.md`, `tasks.md`, and delta `specs/` | `/openspec-story-plan-resume` |
| Plan-lane downgrade and acknowledged contract/reopen/replanning edits, including task/proof alignment, from feedback | `/openspec-feedback` |
| Ready TODO → IN PROGRESS Status claim, including prerequisite readiness | `/openspec-story-claim` |
| Authorized implementation continuation Status writes | `/openspec-story-resume` |
| Implementation progress and handoff | `/openspec-story-claim`, `/openspec-story-resume` |
| Explicit implementation blocker creation/update | `/openspec-story-claim`, `/openspec-story-resume`, `/openspec-story-review` |
| Current review receipt, completed-verdict Status, and review timeline transition | `/openspec-story-review` |
| PR metadata and delivery evidence | `/openspec-pr` |
| First-use `## Feedback Receipts` creation and all feedback receipts/candidates/decisions | `/openspec-feedback` |
| Archive preflight and delegation to `/opsx:archive` | `/openspec-archive` |
| Read-only lifecycle inspection and next-command recommendation | `/openspec-next-action` |
| Plan or implementation loop selection | `/openspec-story-plan-converge`, `/openspec-story-converge` |
| Orphaned `🟢 PLAN APPROVED` safety downgrade | `/openspec-story-plan-converge` |

`/openspec-next-action` recommends the owner command; loopers choose only the
commands inside their documented convergence loops. Implementation convergence
stops at `🟣 IN REVIEW` and does not invoke `/openspec-story-review`. Neither
looper bypasses command authority.

## Suggested next action routing

Final responses expose routing through one canonical field. A single route is:

```text
Suggested next action: <exact command | operator action | wait | None>
```

When the current state genuinely permits either iterative convergence or one
direct owner pass, the response instead uses:

```text
Suggested next action:
- Converge wrapper: <exact command | operator action | wait | None>
- Non-looped pass: <exact command | operator action | wait | None>
Choose one; do not run both.
```

The planning wrapper owns repeated fresh plan-review/plan-resume dispatch; a
non-looped pass performs only the state-correct direct command, and any repair
must still receive a fresh plan review before approval. The implementation
wrapper owns repeated fresh claim/resume dispatch and stops at `🟣 IN REVIEW`;
a non-looped pass is one claim or resume and may stop in `🔄 IN PROGRESS`.
Neither route authorizes implementation review. At `🟣 IN REVIEW`, use only a
fresh, oblivious `/openspec-story-review` session with no implementation-loop
notebook, summary, operational notes, or prior chat context.

Use an exact command when executable routing is known, an operator action when
human intervention or selection is required, `wait` for an external event, and
`None` when no further action remains.

## Rules of thumb

1. Treat `story.md → Plan:` and `story.md → Status:` as the lane/status source
   of truth.
2. Do not implement without `Plan: 🟢 PLAN APPROVED`.
3. Do not approve implementation while proof rows are provisional or acceptance
   coverage is incomplete.
4. Treat unmerged PRs as archive blockers, not story-status blockers.
5. Status controls non-DONE routing. Bound DONE requires one current well-formed
   APPROVE/PASS receipt with complete identity fields; delivery verifies identity
   through PR or the explicit no-PR archive route. Missing, duplicate,
   malformed/non-approve, stale, or contradictory evidence blocks. Only unbound
   pre-v3 DONE with zero Initiative-like lines and no receipt gets compatibility.
6. Reject modern prerequisites with `blocked.md` or missing, malformed,
   superseded, contradictory, or non-approving current receipts; prerequisite
   readers do not recompute identity. Warn for the bounded unbound pre-v3 DONE
   exception.
7. Do not archive stories with `blocked.md` or missing PR/no-PR evidence.
8. Use `/openspec-feedback` for new external feedback, especially PR feedback,
   after a story is complete, or when feedback might affect several stories.
9. Treat notebooks as optional sourced orientation only; artifacts and live
   evidence own lifecycle, review, and feedback authority.
10. Keep fresh-session boundaries: planning, plan review, implementation,
    implementation review, PR handling, feedback absorption, and archive are
    separate jobs.
