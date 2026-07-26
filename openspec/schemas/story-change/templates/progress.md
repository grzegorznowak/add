# Progress: <change-slug>

## Current Claim
<!-- Exactly one Active Claim section per session.
     Written by /openspec-story-claim and /openspec-story-resume.
     Do not add a persisted OpenSpec artifact-root field. Worktrees below are
     execution bindings for individual repositories, not artifact authority. -->
- Claimed at:
- Claimed by: <fresh / continuation> session
- Model: <model name>
- Scope: <one sentence for this work chunk>
- Worktrees:
  - <repo-basename>: <absolute path>
- Main-tree targets: <repo-basename>, <repo-basename>
- Primary write surfaces: <paths>
- Status: 🔄 IN PROGRESS | 🟣 IN REVIEW | ✅ DONE | ⛔ BLOCKED

## Progress Timeline
<!-- Append-only timestamped bullets recording meaningful milestones.
     Written by `/openspec-story-claim`, `/openspec-story-resume`,
     `/openspec-feedback`, and `/openspec-pr`. Feedback writes acknowledged
     replanning checkpoints and publishes validated review handoff transitions;
     PR writes only delivery evidence. -->

## Implementation Review Receipt
<!-- Exactly one compact current completed-verdict body, written by `/openspec-feedback` from a validated completed-review handoff only.
     The handoff comes from the read-only reviewer. Feedback replaces this body; it never appends receipt
     history. The timeline carries history. Feedback writes the receipt and
     required transition timeline entry together in one validated progress
     write (after blocked.md for BLOCKED), then writes top-level Status last and
     performs no later writes. Status controls non-DONE routing, where an older receipt may be
     historical/superseded by authorized later work. A bound
     DONE requires one well-formed current APPROVE/PASS body. Duplicate
     headings/bodies, malformed or non-approving fields, or a contradiction
     block. Missing-receipt compatibility is limited to an unbound pre-v3 DONE
     story with zero Initiative or Initiative-like lines; malformed present
     Initiative-like fields are conflicts, never absence. Never synthesize a
     backfill. -->
- Reviewed at: <UTC ISO timestamp>
- Decision: APPROVE | REQUEST CHANGES | BLOCKED
- Approval gate: PASS | FAIL
- Status transition: <old> -> <new>
- Evidence reviewed: <source targets and proof-matrix state>
- Identity method: review-identity-v1
- Identity digest: sha256:<lowercase hex digest of the canonical manifest>
- Identity bases: <compact JSON [{"repo":"<basename>","base":"<full Git commit object id>"},...] or []>
- Identity paths: <compact JSON [{"repo":"<basename>","path":"<relative-path>"},...] or []>
- Findings: <compact ids/severity/source anchors, or None.>
- Proof: <commands/results, or not run with reason>
- Next owner: <state-owning command or terminal/delivery route>

## Session Handoff
<!-- Refreshed at the end of every session. Only the most recent entry is authoritative. -->
- Status: done | blocked | in progress | in review
- What changed: <short bullets>
- Files touched: <paths>
- Red-first path: <focused seam + outcome, or explicit exception + alternative>
- Tests run: <commands/results or not run>
- Remaining work: <short bullets>
- Unresolved Debt Friction: <or none>
- Blockers / risks: <short bullets>
- Exact next step: <one concrete recommendation>

## PR State
<!-- Written by `/openspec-pr`. There is exactly one PR State section. Before
     any PR or progress write, PR recomputes review-identity-v1 from the receipt
     bases/paths and records the matching digest and verification time here. -->
- PR URL:
- Number:
- Title:
- Branch:
- Opened at:
- PR status: open | changes_requested | approved | merged | closed
- Review decision: <APPROVED | CHANGES_REQUESTED | REVIEW_REQUIRED | blank | unavailable>
- Merge commit: <sha or "—">
- Merged at: <UTC ISO timestamp or "—">
- Verified implementation digest: sha256:<lowercase hex digest or "—">
- Verified at: <UTC ISO timestamp or "—">
- Last synced:

## Unresolved Debt Friction
<!-- Carried forward entries: split-story, defer-explicitly, block, or unfinished fix-now. -->
- None.
