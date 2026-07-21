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
  constraints, decisions, resources, and future story candidates. Ordinary
  `/openspec-feedback` creates `## Feedback Receipts` on first receipt-bearing
  use; review packet triage is receiptless, and initiative planning does not
  seed that operational section.
- `openspec/changes/<story-slug>/` is the active change workspace for one
  story-sized outcome.
- `story.md → Initiative:` is the required top-level story-to-initiative binding.
- `story.md → Plan:` is the authoritative planning lane.
- The top-level `story.md → Status:` field is the authoritative implementation
  status; an `## Status` section is not equivalent.
- `blocked.md` is an explicit lifecycle gate. If it exists, lifecycle commands
  stop until the blocker is resolved and the file is removed, except that a
  confirmed `/openspec-feedback` packet-triage rerun may verify exact existing
  planned bytes without rewriting and continue to Status-last BLOCKED publication.
- `progress.md` holds runtime evidence, including the durable implementation
  review receipt; it is not a planning input and is not seeded by
  `/openspec-story-plan`.

Commands may resolve a transient `<openspec_root>` that contains selected
coordination artifacts, including after worktree relocation. Explicit contained
unregistered `WORKTREE=` paths are supported specifically by the
`/openspec-story-review` packet producer and `/openspec-feedback` packet consumer
when resolving their exact initiative/story pair. Their fallback discovery uses
registered `refs/heads/<initiative>/<story>` worktrees before the launch root.
This is not a global `WORKTREE=` rule: ordinary feedback and next-action retain
their documented launch-root/registered-worktree boundaries, and every other
command follows its own resolver contract. Commands recompute every coordination
path after selection and never persist an absolute `OpenSpec root:` field in an
artifact or receipt.

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
| /openspec-story-review emits one readonly packet; confirmed            |
| /openspec-feedback packet triage publishes Status last:                |
|   accepted current rework -----------------> [🔄 IN PROGRESS]          |
|   accepted external blocker -> blocked.md -> [⛔ BLOCKED]              |
|   eligible clean completion ----------------> [✅ DONE]                |
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

- Ordinary `/openspec-feedback` can route feedback into initiative operational
  sections, story plan review logs, acknowledged story contract/reopen edits,
  future story candidates, or initiative-level decisions. Every ordinary
  disposition also gets one durable initiative receipt. Ordinary feedback never
  touches product source, never approves the Plan lane, and its only Status write
  is an acknowledged `resume-current-story` reopen to `🔄 IN PROGRESS`. The
  separate receiptless packet-triage mode owns only its confirmed Status-last
  outcomes; PR metadata alone never reopens a story.
- `blocked.md` is the hard implementation and archive stop, even if the
  `Status:` header is stale. The sole existing-file exception is confirmed
  packet-triage rerun reconciliation of exact planned bytes before Status-last
  BLOCKED publication; it verifies without rewriting.
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
continuation transitions, including return to IN REVIEW. Ordinary feedback may
only perform an acknowledged reopen to IN PROGRESS. Review packet triage instead
owns its confirmed Status-last IN PROGRESS, DONE, or BLOCKED publication;
`NOT REVIEWABLE` cannot publish DONE. Readonly review emits a packet and owns no
transition:

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

`/openspec-story-review` is an independent, oblivious, readonly evaluator. It
must run from a completely fresh session with no implementation-loop notebook,
summary, operational notes, or prior chat context. It reads the bound IN REVIEW
story, contract, implementation, tests, tasks, prior durable evidence, design
trace, risk lenses, and proof quality, then returns exactly one portable
`ADD-REVIEW-PACKET/1` response. It does not write product code, OpenSpec
artifacts, notebook state, receipts, Status, `blocked.md`, progress timelines,
or publication logs.

`/openspec-feedback` review packet triage is the sole publisher for this flow. It
validates and pair-binds the complete packet, dispositions all packet and
operator-added findings as one set, shows every canonical postcondition and one
lifecycle outcome, and requires complete confirmation before writing. Canonical
story/design/task/initiative edits are verified first; an accepted external
blocker creates or verifies exact `blocked.md` bytes next; top-level Status is
published last. Accepted current work returns to IN PROGRESS, an accepted
external blocker publishes BLOCKED, and an eligible clean APPROVE or REQUEST
CHANGES disposition set may publish DONE. BLOCKED and NOT REVIEWABLE packets
never publish DONE.

Legacy `progress.md → ## Implementation Review Receipt` bodies and their
`review-identity-v1` fields remain reader-compatibility inputs for prerequisite,
next-action, PR, archive, resume, and convergence gates during migration. No new
readonly-review or packet-triage receipt/timeline/history is produced. Existing
readers continue to fail closed on a bound DONE story whose retained receipt is
missing, duplicate, malformed, non-approving, identity-incomplete, superseded,
or contradictory. Only the documented unbound pre-v3 DONE exception may qualify
without a receipt, with a warning and no backfill. This compatibility does not
confer write ownership on `/openspec-story-review`.

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

PR bodies are product-facing and catalyst-first. Their opening orients a cold
reader with the source-supported reason the work is needed now, explicit causal
boundaries, and the observable before/after outcome when the eligible artifacts
state them; it does not invent missing context. The remaining requirements,
acceptance, contract, scope, and verification sections preserve the review
contract. PR
bodies must not paste implementation diary content from `progress.md`,
`tasks.md`, or internal planning sections.

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

For every ordinary-mode disposition, `/openspec-feedback` creates `## Feedback
Receipts` in `initiative.md` if absent and appends exactly one portable entry
with Feedback ID, Source ID, Source hash, Disposition, Target, Acknowledged
reason/rationale, Changed artifacts, and Next owner. `Source ID` plus `Source
hash` is the reproducible deduplication key: stable provider object IDs identify
hosted feedback. A manual/file item is valid UTF-8 with CRLF converted to LF and only
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

Review packet triage is a separate atomic mode. It validates the producer's
complete ordered packet grammar and pair-qualified root, writes only within the
bound current story/current initiative, records no packet receipt/cycle/digest/
history, and publishes Status last after all confirmed postconditions. It may
create a confirmed absent `blocked.md`; exact existing bytes satisfy the
postcondition and conflicting existing content is preserved as a hard stop.
Ordinary mode keeps the receipt-based contract above. Existing prerequisite,
next-action, PR, archive, resume, and convergence readers retain their legacy
receipt compatibility until the later explicit readers/migration slice; this
packet-triage slice does not normalize or rewrite those readers.

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
| Explicit implementation blocker creation/update | `/openspec-story-claim`, `/openspec-story-resume`; confirmed absent-file creation by `/openspec-feedback` review packet triage |
| Portable readonly implementation review packet | `/openspec-story-review` |
| Confirmed review-packet canonical edits and Status-last publication | `/openspec-feedback` review packet triage |
| Legacy implementation review receipts | Retained reader compatibility only until the later readers/migration slice; no new packet-triage receipt |
| PR metadata and delivery evidence | `/openspec-pr` |
| Ordinary-mode first-use `## Feedback Receipts` creation and feedback receipts/candidates/decisions | `/openspec-feedback` ordinary mode |
| Receiptless review-packet current-story/current-initiative decisions and handoffs | `/openspec-feedback` review packet triage |
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
