---
name: openspec-feedback
description: Absorb structured review/tool, PR, or reviewer feedback into an OpenSpec initiative by routing it to story edits, review rework, story candidates, or initiative-level decisions. Use when feedback needs to be incorporated without bloating or drifting stories.
disable-model-invocation: true
argument-hint: "<initiative-slug> [--pr <pr-url>] [feedback-or-file] [WORKTREE=\"<basename>=<path>\"]"
allowed-tools: Read Edit Write Grep Glob Bash(gh pr view:*) Bash(gh api:*) Bash(date -u:*) Bash(printf:*) Bash(sha256sum:*) Bash(shasum:*) Bash(git worktree list:*)
---

# OpenSpec Feedback

Absorb structured feedback into one OpenSpec initiative without turning PR reviews or tool output into messy story prose. This command classifies each feedback item first, shows a lightweight acknowledgement plan, then applies the smallest coordination-doc edits needed to preserve story intent, feedback provenance, and the story's planning lane.

Argument: `$ARGUMENTS` — `<initiative_slug> [--pr <pr_url>] [feedback_or_file] [WORKTREE="<basename>=<path>"]`. The initiative slug is required by argument or explicit menu selection. PR mode processes all actionable feedback items from the PR.

## Mode router

Route the invocation before applying workflow prose. One complete fenced `ADD-REVIEW-PACKET/1` packet in the immediately preceding message or pasted payload selects **review packet triage mode**; use the shared boundaries in `## Important` and then only `## Review packet triage mode`. Every other valid feedback source selects **ordinary non-review feedback mode**; use the shared boundaries and Phases 0–6. Packet-like input that fails the exact review-mode intake contract stops with zero writes and never falls through to ordinary mode.

## Important

The boundaries in this section apply to both modes. This command may edit coordination documents only:

- `initiative.md` (Feedback-Derived Story Candidates, Feedback-Derived Decisions, Feedback Receipts)
- non-archived change workspace artifacts under `openspec/changes/<story-slug>/`:
  - `story.md` (contract sections, Plan lane, Plan Review Log)
  - `design.md` (when design sources or element trace are affected)
  - `tasks.md` (feedback-owned task additions, reopenings, or contract-alignment edits)
  - `story.md` Status header and contract sections (review findings reflected in contract)
  - `progress.md` (an ordinary-feedback checkpoint for every direct amendment or implementation resume, including status-only resume)
  - `blocked.md` (review packet mode only, for a confirmed accepted external blocker)

In ordinary non-review feedback mode, `Write` is permitted only when a missing `progress.md`, `## Progress Timeline`, or `initiative.md → ## Feedback Receipts` section must be created for an acknowledged edit, or when exact retained bytes/hashes are needed for transaction rollback or reconciliation; do not create unrelated scaffold. Review packet mode may additionally create its confirmed `blocked.md`, under the stricter atomic procedure below. Neither mode touches product source code, tests, configs, archived change workspaces, `CONTRACT.md`, worktree contents outside the resolved coordination artifacts, branches, GitHub PR bodies, or `reviews.md` (legacy artifact). Neither mode creates a full new change workspace.

Ordinary mode never advances or approves implementation status. Its only allowed `story.md → Status:` write is an explicitly acknowledged `resume-current-story` reopen to `🔄 IN PROGRESS` so implementation can resume after local/PR feedback. Review packet mode instead owns only the confirmed, Status-last lifecycle outcomes defined in its dedicated section. New work discovered from ordinary feedback becomes a feedback-derived story candidate in the initiative; `/openspec-story-plan` owns full story planning.

There is no dry-run mode. Normal operation is:

```text
classify feedback -> show absorption plan -> operator acknowledgement -> apply edits
```

## Why initiative-scoped

Feedback often spans several stories. Selecting a story before classification recreates the failure mode this command exists to avoid. The initiative is the routing boundary; each feedback item is then classified into the right destination.

`## Feedback-Derived Story Candidates`, `## Feedback-Derived Decisions`, and `## Feedback Receipts` in `initiative.md` answer: "where did this feedback go and why?" The compact receipt ledger is canonical across runtimes. A runtime may maintain an optional notebook mirror for orientation, but this workflow never invokes or requires notebook APIs and the mirror has no lifecycle or deduplication authority.

`story.md` Status header and contract sections answer: "what is wrong with this story implementation and what must be fixed?" The paired initiative receipt carries the stable source identity, routing rationale, changed artifacts, and next owner.

`## Plan Review Log` in `story.md` answers: "what planning contract concerns must be resolved before implementation continues?"

`Plan:` header in `story.md` answers: "is the story contract ready to implement, or does it need planning rework?"

## Review packet triage mode

This is a dedicated, atomic intake path. It does not use Phases 0–6 below. Review mode starts only from one complete fenced `ADD-REVIEW-PACKET/1` packet supplied as the immediately preceding message or pasted payload. Recognize that exact fence token before treating its contents as ordinary payload; a mention of the token, an excerpt, an unfenced block, or a packet mixed with other feedback stays invalid and must not fall through to ordinary mode. The initiative argument, when supplied, is a binding assertion rather than a second feedback source.

The mode router and `## Important` are shared rules. Phases 0–6 are ordinary-mode rules and are not part of packet triage. Review packet mode uses only this section after routing. Ordinary non-review feedback mode remains separate: ordinary mode retains the existing receipt-based compatibility contract, including its acknowledgement, dispositions, FB identities, checkpoints, recovery rules, `## Feedback Receipts`, and Phase 6 response. None of those ordinary-mode contracts may be imported into review packet triage.

### Validate and bind before triage

Hold the packet only in transient invocation memory. The packet is never persisted, copied into an artifact, summarized as packet metadata, or used as a durable identity. Review packet mode must not create or append feedback receipts, review cycles, identity digests, or review history.

Packet grammar validation is separate from artifact qualification. Before classification, confirmation, or any write, first validate only the complete packet grammar:

1. Require one matching opening and closing `ADD-REVIEW-PACKET/1` fence and no text outside it. The complete ordered scalar grammar is exactly: `Review mode:`, `Review focus:`, `Subject:`, `Root:`, `Initiative:`, `Story:`, `Verdict:`, `Coverage:`, `Acceptance / proof assessment:`, `Verification run:`, `Red-first assessment:`, `Final stability recheck:`, and `Finding count:`. Require each scalar exactly once, in that order, and non-empty except for the producer-documented `none` or not-run forms. `Review mode` is `full` or `focused`; `Verdict` is exactly `APPROVE`, `REQUEST CHANGES`, `BLOCKED`, or `NOT REVIEWABLE`. After the conditional findings form and one final `Next step`, reject every unrecognized, additional, duplicated, or out-of-order line.
2. Parse `Finding count` as a base-10 nonnegative integer. A zero count requires exactly `Findings: none` and forbids finding-block lines. A nonzero count forbids `Findings: none` and requires exactly that many contiguous blocks. The exact consumer finding-field manifest is: `Finding ID:`, `Severity:`, `Summary:`, `Evidence:`, `Impact:`, `Proof / verification:`, `Requested outcome:`. Require exactly those seven lines in that order in each block, unique non-empty finding IDs, and no extra block fields. `Severity` is exactly one of `Critical`, `High`, `Medium`, `Low`, or `Info`. Require exactly one final `Next step: /openspec-feedback` after all findings. Require packet Initiative and Story values to match the canonical slug grammar before using either in a path.

A malformed, truncated, or internally stale packet fails these grammar/intake gates with zero writes and requires a fresh complete packet. Packet-like input that fails this contract never falls through to ordinary feedback mode.

After grammar succeeds, attempt artifact qualification and pair binding:

3. **Pair-qualified root contract.** Resolve the review root independently of ordinary Phase 0: every candidate must contain both the packet initiative artifact and packet story artifact at their exact contained active paths. Use this precedence: explicit selector, then the unique exact initiative/story branch worktree, then launch root. An explicit `WORKTREE=` path may qualify whether or not it is registered, provided both exact artifacts are contained beneath that path; multiple qualifying explicit candidates halt as ambiguous. Only the fallback branch-discovery step is restricted to registered worktrees: when no explicit candidate qualifies, a registered worktree qualifies when its exact branch is `refs/heads/<Initiative>/<Story>` and both artifacts are contained; ambiguity halts. Use launch root only when no qualifying branch worktree exists and both artifacts are contained there. Require packet `Root` to resolve to that same root and the invocation initiative (if present) to equal packet Initiative. Never merge roots or redirect a mismatch.
4. **Packet legacy-binding compatibility.** Inventory the complete top-level header region of the contained non-archived `openspec/changes/<Story>/story.md` before consuming a binding. Exactly one canonical `Initiative:` equal to packet Initiative binds. Any duplicate, malformed, empty, noncanonical, or mismatched Initiative-like line is a hard zero-write conflict. With zero Initiative or Initiative-like lines, inspect only exact story-slug associations in every existing initiative’s `## Story Candidates`: exactly one unique exact `## Story Candidates` association binds only when it equals packet Initiative; different or multiple exact associations halt. When there is no exact association, the packet’s explicit `Initiative:`/`Story:` pair is the compatibility fallback because the producer already emitted that operator-selected pair; require the matching existing packet initiative and story artifacts and warn that the durable header is absent. Never silently backfill or normalize the binding. A canonical header may be added only when that canonical header edit is part of the complete confirmed triage set shown before writes; otherwise safely publish under this same legacy binding without repair.
5. When the pair binds, re-read `story.md`, the packet evidence anchors, and the minimum artifacts needed to test the requested outcomes. Require every path to remain within the bound root and every cited fact needed for triage to be inspectable. Record current canonical content and hashes in memory. A normal writable first pass requires top-level `Status: 🟣 IN REVIEW`; the same status also permits reconciliation after an interrupted confirmed pass whose canonical edits landed before Status publication.

For `APPROVE`, `REQUEST CHANGES`, or `BLOCKED`, failed qualification, binding, containment, evidence inspection, or IN-REVIEW state is a hard zero-write stop; request a fresh packet only when the packet itself is malformed or stale, otherwise route the failed artifact/state prerequisite to its owning workflow.

**NOT REVIEWABLE prerequisite route.** A structurally valid `NOT REVIEWABLE` packet does not dead-end when pair qualification, binding, artifact integrity, or current `Status: 🟣 IN REVIEW` is the failed review prerequisite. Attempt qualification and binding first. If either cannot succeed, or current Status is not IN REVIEW, enter a routing-only, zero-write branch rather than requiring a new packet. Disposition every packet and operator-added finding together, if any, as a transient routing set; include an explicit no-findings outcome when both sets are empty. Show the complete proposed no-write routing set and obtain one confirmation when operator judgment or an added finding affects the route. Never propose canonical edits, create `blocked.md`, or publish any lifecycle Status in this branch, and never publish DONE. Route the failed prerequisite to its owning workflow—for example planning repair, blocker resolution/resume, missing workspace planning, prerequisite owner, or the current state-owning command. Ask for a fresh packet only if packet grammar is malformed or its asserted packet facts are stale, not merely because the review correctly reported an unqualified pair or state. A `NOT REVIEWABLE` packet that does bind a valid IN-REVIEW pair continues into normal triage below and may accept a current-story correction or external blocker, but remains ineligible for DONE.

### Build one complete triage decision

Start with every validated packet finding. Include operator-added findings in the same review-mode finding set. Before disposition, require each operator-added finding to supply the same substantive facts—summary, direct evidence, impact, proof or verification, and requested outcome—as a packet finding; keep any transient local label out of canonical artifacts. If the packet has zero findings and the operator adds none, record an explicit transient `no findings` outcome for confirmation rather than inventing a disposition or durable entry.

Disposition every finding as exactly one of `accept`, `reject-or-waive`, `defer`, or `re-scope`.

- `accept`: identify the smallest canonical story contract, task, design, proof, or blocker edit that satisfies the requested outcome. Classify accepted work as current-story rework or as an external prerequisite that genuinely prevents current-story work.
- `reject-or-waive`: require a specific operator-confirmed rationale. Plan a durable statement of the actual product/scope decision in `story.md` under the applicable `## Locked Decisions`, `## Out of Scope`, acceptance, or verification text; never store only a conversational rejection.
- `defer`: require a named future owner and concrete destination. Plan the bounded non-current obligation in `story.md` and, when the destination is initiative work, the corresponding initiative story candidate or decision so it remains actionable.
- `re-scope`: require the destination initiative/story or explicit owner that now owns the outcome. Remove ambiguity from the current story contract and preserve an actionable handoff without creating or editing a destination change workspace.

**Bounded destination contract.** Durable review-mode writes stay inside the bound current story and current initiative. Record every deferred or re-scoped obligation, future owner, and named destination in the bound current `story.md`; when initiative routing is needed, add only the corresponding candidate or decision in the bound current `initiative.md`. Re-scoping to another initiative or story is a handoff recorded in those current artifacts, not authority to write the destination. Revalidate canonical slugs, active/non-archived source binding, path containment, expected content, and current initiative association for every current-story/current-initiative candidate immediately before confirmation and writes.

For every proposed canonical change, show the exact artifact and section, the intended postcondition, and why that location is authoritative. Do not include raw packet text, the fence token, packet verdict metadata, finding IDs as journal keys, source hashes, receipt IDs, review-cycle numbers, or a review-history entry. Durable text records the resulting contract, rationale, owner, or destination—not the packet that prompted it.

Determine one proposed lifecycle outcome from the complete disposition set and packet Verdict:

1. An accepted external prerequisite that prevents current work is the blocker outcome. **Blocker publication contract.** Plan complete final `blocked.md` bytes from the canonical template, with its `# Blocked: <story-slug>`, `## Blocker`, and `## Resolution` sections naming the blocker, evidence, resolution condition, and owner, followed by `⛔ BLOCKED`. If an existing bound `blocked.md` exactly matches the planned final bytes, treat that postcondition as already satisfied and do not rewrite it. A conflicting existing `blocked.md` is a hard conflict: stop with zero new writes, preserve it, and require owner resolution or a rebuilt complete triage plan; never overwrite or merge it.
2. Otherwise, accepted current-story rework is the rework outcome. Any accepted finding owned by the current story publishes `🔄 IN PROGRESS`.
3. Only `APPROVE` and `REQUEST CHANGES` packets are eligible for clean completion. When every finding is durably rejected/waived, deferred, or re-scoped, with no accepted current-story work and no accepted external blocker, publish `✅ DONE`.
4. A `NOT REVIEWABLE` packet may triage an accepted current-story correction or accepted external blocker through outcomes 1–2, but it is never eligible for clean completion. `NOT REVIEWABLE` never publishes `✅ DONE`. With neither accepted correction nor accepted blocker, leave Status `🟣 IN REVIEW`, make no lifecycle write, and route the failed prerequisite to its owner.
5. A `BLOCKED` packet with an accepted external blocker creates or verifies `blocked.md` and then publishes `⛔ BLOCKED`. A `BLOCKED` packet with accepted current-story correction but no accepted external blocker publishes `🔄 IN PROGRESS`. A `BLOCKED` packet with neither accepted outcome remains `🟣 IN REVIEW`, writes no lifecycle Status, and routes blocker resolution or a fresh review as appropriate. `BLOCKED` is never eligible for clean completion and can never publish `✅ DONE`.

The blocker outcome takes precedence because work cannot truthfully be published resumable while its accepted external prerequisite prevents progress. All accepted non-blocker findings still receive canonical edits before that blocker publication.

### Single confirmation and zero-write exits

Collect and show every finding disposition together, then obtain one explicit confirmation of the complete set before any write. The confirmation view includes operator-added findings (or the explicit zero-finding outcome), every artifact postcondition, every reject/waive rationale, every deferred/re-scoped owner and destination, and the one lifecycle outcome. Ask exactly whether to apply the complete triage set.

The operator may revise any disposition, rationale, owner, destination, or edit; rebuild and show the entire set after a revision. Do not interpret confirmation of one row, a subset, canonical edits without the lifecycle outcome, or the lifecycle outcome without all canonical edits as authorization. Cancellation or partial selection ends review mode with zero writes. Questions, requested revisions, invalid confirmation, and a choice to handle only some findings also end or repeat planning without edits; they never fall through to ordinary mode.

### Apply, verify, and publish

After complete confirmation, re-resolve the same bounded root and re-run packet binding, top-level `Status: 🟣 IN REVIEW`, path containment, evidence, target-section, and expected-content/hash gates. Construct the complete final bytes for every planned artifact before the first write. If anything drifted, stop with zero new writes and request a fresh plan or packet.

Apply and verify every confirmed canonical artifact edit before publishing lifecycle Status. Use this order:

1. Apply idempotent story/design/tasks/initiative edits for all dispositions. After each edit, re-read the artifact and verify the exact intended postcondition and content hash. For each `reject-or-waive`, durably record the confirmed rationale in canonical story artifacts. For each `defer` or `re-scope`, durably record the future owner and destination in canonical artifacts.
2. For an accepted external blocker, create and verify `blocked.md` before publishing `⛔ BLOCKED`; when it already exactly matches the confirmed final bytes, verify and retain it without a write. Refuse to publish BLOCKED if the blocker file is missing, incomplete, conflicting, outside the bound story, or fails verification.
3. Re-read and verify every confirmed non-Status postcondition as one complete set. Ensure the proposed lifecycle outcome still follows from current evidence and no unconfirmed edit is present.
4. Write the top-level `Status:` header last, only after every other confirmed write is verified. Change only that exact header: blocker outcome to `⛔ BLOCKED`, rework outcome to `🔄 IN PROGRESS`, and eligible clean completion to `✅ DONE`. Re-read it and all final postconditions before reporting success.

A write or verification failure stops immediately and forbids the Status write. Report exact changed paths and which intended postconditions are present or missing; do not claim cancellation and do not manufacture rollback success. Canonical edits may therefore exist while Status remains `🟣 IN REVIEW`.

**Rerun contract.** On a rerun with the same complete packet while Status remains `🟣 IN REVIEW`, validate and pair-bind it from scratch, rebuild the complete dispositions, and obtain complete confirmation again. Reconcile each intended postcondition against current canonical content: treat an exact already-satisfied edit (including exact `blocked.md` bytes) as complete, reject conflicting or ambiguous content, and apply only missing edits in the same order. This reconciliation uses canonical end state, not a journal, packet identity, receipt, digest, cycle, or persisted packet. Status remains the final operation. If Status already left IN REVIEW, do not infer that a newly supplied packet is the one previously applied; stop and require the state-owning workflow.

Report packet mode separately: dispositions by transient finding label, verified canonical paths, and final Status (or unchanged IN REVIEW after failure). Do not use the ordinary Phase 6 receipt fields or ordinary-mode next-route derivation.

## Phase 0 — Resolve initiative and intake

1. Set `<launch_root>` = `<cwd>` and leave the invocation-wide `<receipt_root>` unresolved only until the selected initiative is known. Both variables are transient, in-memory artifact anchors; never persist either path in `initiative.md`, story artifacts, receipts, or any other file.
2. Parse `$ARGUMENTS`.
   - Accept an initiative slug or `INITIATIVE=<slug>` as the initiative selector.
   - Accept `--pr <url>`, `PR_URL=<url>`, or a bare GitHub PR URL as PR pointer mode.
   - Preserve raw `WORKTREE="<basename>=<path>"` occurrences as explicit checkout selectors; they are not feedback text.
   - Treat remaining text as feedback payload unless it resolves to a readable file path.
3. Select the initiative slug without making the launch checkout authoritative:
   - If a slug was provided, validate it matches `^[a-z0-9]+(?:-[a-z0-9]+)*$` before resolving any path. If it fails, abort with: `invalid initiative slug; use lowercase hyphenated slug characters only`.
   - If omitted, run `git worktree list --porcelain` from `<launch_root>`, list each distinct canonical initiative slug having `openspec/initiatives/<slug>/initiative.md` in `<launch_root>` or a registered worktree, and ask the operator to pick by number or slug. This is explicit menu selection, not inference. Validate the selected slug against the same canonical slug rule before resolving any path.
   - If no initiatives exist in the bounded roots, stop and tell the operator to run `/openspec-initiative-plan` first.
4. Resolve `<receipt_root>` immediately, before validating a launch-root initiative copy, reading receipts, deduplicating, allocating an FB ID, classifying initiative-only items, or resolving any story target:
   - Refresh `git worktree list --porcelain`. A root is bounded only when it is `<launch_root>` or a registered worktree. A qualifying root must contain `openspec/initiatives/<initiative-slug>/initiative.md`, and that resolved file must remain contained under the root's `openspec/initiatives/` directory.
   - First inspect explicit `WORKTREE="<basename>=<path>"` selectors. Exactly one distinct bounded qualifying explicit path sets `<receipt_root>`. Multiple qualifying explicit paths halt for one explicit active-checkout choice. If selectors were supplied but none qualifies, halt and require a valid selector or a rerun without it; never silently ignore an explicit checkout choice.
   - With no qualifying explicit selector, inspect registered worktrees other than `<launch_root>` whose exact branch is `refs/heads/<initiative-slug>/<story-slug>`, where `<story-slug>` is canonical, and which contain the selected initiative file. Exactly one qualifying branch worktree sets `<receipt_root>` and outranks a possibly stale launch copy. Multiple qualifying branch roots halt before intake/dedupe and require the operator to choose the active checkout, then rerun with exactly one `WORKTREE=` selector; never guess from recency or story contents.
   - Only when no qualifying branch worktree exists may `<launch_root>` set `<receipt_root>`, and only if its selected initiative file exists and passes containment. Otherwise halt: the selected initiative has no valid bounded checkout.
   - Set `<receipt_root>` exactly once for the invocation. Every initiative-only batch, mixed batch, receipt, candidate, decision, defer/reject record, legacy-evidence scan, and story artifact uses this root. Never default an initiative-only batch blindly to `<launch_root>`.
5. Read the authoritative project guidance before making recommendations:
   - `<receipt_root>/AGENTS.md`, then `<receipt_root>/CLAUDE.md` as fallback when present.
   - `<receipt_root>/openspec/initiatives/<initiative-slug>/initiative.md` for routing context, including existing story candidates, decisions, and receipts. Do not deduplicate or allocate an FB ID until Phase 3, but do not consult a different checkout for authority.
   - Read `tasks.md`, `progress.md`, and `story.md` only for plausible story targets after their canonical path and initiative binding under `<receipt_root>` pass Phase 3. Legacy evidence is considered only under `<receipt_root>`.
6. Determine intake mode:
   - **PR pointer mode** when a PR URL is present.
   - **Payload mode** when pasted feedback or a feedback file is present.
     If the remaining argument resolves to a readable file path, ask the operator: `Read <path> as feedback source? [y/N]` before reading. If declined, treat the path as literal feedback text instead.
   - If neither is present, ask the operator to paste feedback or pass `--pr <pr-url>`.

## Phase 1 — Gather feedback sources

In PR pointer mode:

1. Parse the PR URL into `<owner>`, `<repo>`, and `<number>`.
2. Query GitHub with `gh`:
   - `gh pr view <url> --json number,title,url,state,reviewDecision,updatedAt`
   - `gh api repos/<owner>/<repo>/issues/<number>/comments --paginate`
   - `gh api repos/<owner>/<repo>/pulls/<number>/reviews --paginate`
   - `gh api repos/<owner>/<repo>/pulls/<number>/comments --paginate`
3. Normalize all human-visible feedback sources into one timeline:
   - PR conversation comments → `github_issue_comment`
   - submitted review bodies → `github_pr_review`
   - inline review comments → `github_pr_review_comment`
4. Apply this deterministic text normalization before hashing any source or manual item: decode as UTF-8 (stop on invalid UTF-8), replace CRLF with LF, and trim only outer Unicode whitespace. Preserve all remaining text, including internal whitespace and LF characters.
5. For every GitHub source, keep:
   - stable source id: prefer `node_id`; fallback to `<type>:<id>`
   - source URL: `html_url` when available
   - author
   - created timestamp
   - updated timestamp
   - body text
   - review state, path, line, and diff hunk when available
   - source hash: `sha256:<hex>` over exactly this fixed-order record: `body`, `review_state`, `path`, `line`, `diff_hunk`. Encode each field as `<field-name>:<UTF-8-byte-length>:<normalized-value>\n`, include the final LF, and use literal `n/a` for a missing value. Field names, order, colon delimiters, decimal byte length, and final LF are fixed; do not add author, timestamps, URL, or runtime-specific serialization.
6. During intake, exclude only empty comments/review bodies (unless change-request review state is the sole signal) and non-actionable acknowledgements such as "thanks", "LGTM", "done", or "rebase only". Do not exclude an item because any receipt or artifact appears to match it; authoritative dedupe occurs in Phase 3.

Continue to Phase 2 with all remaining actionable items.

If `gh` is unavailable or the PR cannot be queried, stop and ask the operator to paste the relevant feedback. Do not scrape GitHub with ad-hoc unauthenticated requests.

In payload mode:

1. If the remaining argument is a readable file path, read that file and record its path as `Source path`.
2. Otherwise treat the remaining argument or pasted text as the feedback payload and set `Source path` to `manual-paste`.
3. Split the payload into feedback items by explicit IDs, headings, bullets, review comments, or clear topic boundaries.
4. For each item, apply the same UTF-8 / CRLF-to-LF / outer-whitespace normalization above, then compute `Source hash` as `sha256:<full-hex>` over exactly the normalized UTF-8 bytes, with no added delimiter or terminal LF. Use an allowed hash command such as `printf %s '<normalized-item-text>' | sha256sum` (or `shasum -a 256`). Set every manual/file item's `Source ID` to `manual:sha256:<full-hex>` using the complete content hash and no ordinal, path, supplied label, timestamp, truncation, or runtime value; preserve any supplied URL separately as `Source URL`. Identical normalized items therefore have the same identity regardless of payload ordering or runtime.
5. Preserve a short, safe excerpt from the item as `Evidence` so dedupe/audit can reconstruct what was absorbed without pasting the full payload.

## Phase 2 — Normalize feedback items

Build each item record without allocating an FB ID. Use `<pending>` until Phase 3 reads the already-selected root's authoritative ledger. Duplicate normalized manual items remain one stable identity, not separate ordinal items. Build this working record:

```md
- Feedback ID: <pending until authoritative-ledger allocation>
- Source type: github_issue_comment | github_pr_review | github_pr_review_comment | manual
- Source ID: <stable source id>
- Source URL: <url or n/a>
- Source path: <file path | manual-paste | n/a>
- Source hash: <sha256:... for every source>
- Created: <timestamp or n/a>
- Updated: <timestamp or n/a>
- Summary: <one sentence>
- Evidence: <short excerpt or source-local fact, not a long paste>
- Affected paths: <paths mentioned by the feedback, if any>
- Candidate stories: <change workspace slugs that may be affected>
- Risk / miss category: <async/event-loop | platform/API failure | behavior-vs-mechanics proof | design trace extraction | semantic invariant naming | security | persistence | resource lifecycle | other | none>
- Actionability: actionable | non_actionable | ambiguous
```

When a feedback item is ambiguous, ask one focused question before classification. Do not guess a target story just because it is the most recent story in the initiative. When feedback exposes an escaped miss, classify the recurring miss category so the initiative log can feed future planning, review, tests, lint/static checks, and skill updates without bloating the target story with process-retrospective detail.

## Phase 3 — Classify targets and draft absorption plan

Story identification is by change workspace slug under `openspec/changes/<slug>/`. There is no MASTER.md tracker table — discover candidate stories from the authoritative `<receipt_root>` initiative.md sections (Story Candidates, resources), active change workspace directories under that root, and explicit links in the feedback. Worktree discovery selects the invocation root, not a different root per story.

### Canonical slug and initiative-binding gate

Before reading or writing any story workspace from discovered feedback, initiative text, PR metadata, or operator correction:

1. Validate every candidate `<story-slug>` against `^[a-z0-9]+(?:-[a-z0-9]+)*$`. Reject slugs with path separators, whitespace, `..`, absolute paths, URL fragments, or any other non-canonical shape.
2. Resolve a story target only as `<receipt_root>/openspec/changes/<story-slug>/story.md`; never concatenate raw feedback into a path and never redirect one story to another checkout. Confirm the active story directory exists, is not under `openspec/changes/archive/`, and remains contained under `<receipt_root>/openspec/changes/` after resolution. If a proposed batch needs a story that is authoritative only in another checkout, halt before dedupe, FB-ID allocation, acknowledgement, or writes and ask the operator to split the batch or rerun from/select that active checkout. All story roots must exactly equal `<receipt_root>`.
3. Read every exact top-level `Initiative:` header in the selected story.md before treating the target as associated:
   - If any top-level `Initiative:` header is present, there must be exactly one. Its value must be a canonical slug and equal `<initiative-slug>`; a different canonical value is an Initiative mismatch and halts.
   - Duplicate headers, empty values, malformed header syntax, or noncanonical values are hard conflicts, not legacy input; halt without relabeling or repair. Do not ignore a malformed occurrence merely because another occurrence is valid.
   - With no top-level `Initiative:` header, scan every existing initiative.md under `<receipt_root>` and consider only exact story-slug references inside `## Story Candidates`. During initial discovery or inference, the legacy story may appear as a provisional target only when exactly one initiative has such a reference and it is `<initiative-slug>`; zero associations cannot be inferred, and multiple associations or any association to another initiative halt.
   - A zero-association legacy story may enter the provisional plan only after the operator explicitly names or corrects the story target; do not discover it from feedback, branch name, recency, or general prose. Every no-header target qualifies for any story disposition, including status-only resume or receipt backfill, only after the operator acknowledges a plan that names the exact `<initiative-slug>` + `<story-slug>` pair and a refreshed scan proves that no other initiative has an exact Story Candidates reference. A reference by the selected initiative is compatible. Warn that the durable header is absent and never backfill it.
4. Complete the binding gate above for every story target under the one fixed `<receipt_root>`. Immediately after acknowledgement and again before the first write for every batch, including an initiative-only batch, refresh `git worktree list --porcelain`, rerun Phase 0's receipt-root precedence, and require it to select the same root. Also rerun every applicable story containment/header/legacy-association check. Acknowledgement never overrides malformed, mismatched, duplicate, conflicting, moved, or cross-root evidence. If root precedence would now select another root, or any story resolves elsewhere, halt and require a split or explicit active-checkout rerun; never change `<receipt_root>` in place.
5. If an acknowledged operator redirect names an invalid, missing, archived, mismatched, malformed, ambiguous, non-contained, or cross-root target, stop and ask for a canonical non-archived story slug in `<receipt_root>` or choose a non-story disposition (`new-story-candidate`, `initiative-level-decision`, or `defer-or-reject`).
6. Recompute and containment-check every initiative and story path from the fixed `<receipt_root>` immediately before reads and writes. Initiative-only and mixed batches use the same root.

After every item has a proposed disposition and every story target passes the gate, re-read `<receipt_root>/openspec/initiatives/<initiative-slug>/initiative.md` and revalidate every initiative-only disposition against that authoritative context. Only then read the authoritative ledger and allocate IDs from its initiative namespace (`FB-001`, `FB-002`, ...):

- Deduplicate only by exact `Source ID` + `Source hash` in `<receipt_root>/openspec/initiatives/<initiative-slug>/initiative.md → ## Feedback Receipts`. Exact match reuses that receipt and FB ID. The same Source ID with a different hash is a new identity.
- If no receipt exists but canonical story/initiative evidence under `<receipt_root>` unambiguously records this same normalized item with an FB ID, treat it as legacy evidence: reuse that FB ID, mark already-completed owned edits as complete, and plan exactly one receipt-only backfill. Never allocate a replacement ID or reapply those edits. Ambiguous legacy evidence is a hard stop, not a guessed match.
- Otherwise allocate a new ID after the highest FB number in the authoritative ledger and unambiguous legacy evidence under `<receipt_root>`. Allocate new identities in their normalized input order. No launch-root copy has authority unless it is the selected `<receipt_root>`.

Use the story intent test before editing any story. A feedback item may amend an existing story only when all are true:

1. Same user or system outcome.
2. Same acceptance boundary.
3. Same implementation ownership area.
4. Can be completed without changing the story's core scope.

Classify each actionable feedback item into exactly one disposition:

| Disposition | Use when | Target |
|---|---|---|
| `queue-planning-feedback` | Feedback clarifies a story that is still in planning, or should re-enter planning review before implementation continues. | `story.md` → `## Plan Review Log`, `Plan:` lane. |
| `amend-existing-story` | Rare direct amendment explicitly acknowledged by the operator outside a planning or implementation feedback cycle. | `story.md` contract sections (+ `design.md` and `tasks.md` when affected), `Plan:` lane invalidation when the contract changes, `progress.md` feedback checkpoint, then one initiative receipt under `<receipt_root>`. |
| `resume-current-story` | Implemented work misses the current story or PR review requests rework for it. | `story.md` Status header (set to `🔄 IN PROGRESS`), contract and `tasks.md` edits when needed, `progress.md` feedback checkpoint even when status-only, `Plan:` lane invalidation when the contract changes, then one initiative receipt under `<receipt_root>`. |
| `new-story-candidate` | Feedback introduces a new outcome, dependency, rollout concern, or hardening task. | `<receipt_root>` initiative candidate section, then one receipt. |
| `initiative-level-decision` | Feedback changes an initiative policy, architectural choice, or cross-story rule. | `<receipt_root>` initiative decision notes, then one receipt. |
| `defer-or-reject` | Feedback is out of scope, duplicate, non-actionable, deferred, or intentionally declined. | `<receipt_root>` initiative receipt recording the acknowledged rationale and next owner. |

Read only the change workspace artifacts needed to classify plausible targets. Prefer explicit evidence from:

- source links or story slugs in the feedback
- the selected `<receipt_root>` initiative.md story candidates and external resources
- `## PR State` URLs in `progress.md` (when present)
- matching acceptance IDs, paths, or scope language in `story.md`
- existing `## Plan Review Log` entries or prior `## Feedback Receipts` entries when they directly identify the same issue

Status and lane rules:

- Do not edit archived change workspaces under `openspec/changes/archive/`.
- Do not route to, read as writable, or create paths for a story target that failed the canonical slug and containment gate.
- Do not rewrite a `✅ DONE` story's product contract. Convert feedback to a candidate, initiative-level decision, or defer/reject entry unless the operator explicitly acknowledges a `resume-current-story` reopen through the normal lifecycle.
- Do not advance or approve implementation `Status` in `story.md` from this command. The only allowed status mutation is reopening an acknowledged `resume-current-story` target from `✅ DONE` or `🟣 IN REVIEW` to `🔄 IN PROGRESS`; if it is already `🔄 IN PROGRESS`, leave it unchanged.
- Never derive a status reopen from PR metadata alone. The acknowledged Proposed Feedback Absorption plan must name `resume-current-story`, the target story, and the reason the local completion/review state must be revisited.
- You may downgrade or invalidate the `Plan:` header field in `story.md`, but this command must never set `Plan:` to `🟢 PLAN APPROVED`:
  - `queue-planning-feedback` sets `Plan:` to `🟠 PLAN CHANGES REQUESTED`.
  - contract-changing `amend-existing-story` sets `Plan:` to `🟠 PLAN CHANGES REQUESTED` after the contract edits are blended and validation passes, because fresh `/openspec-story-plan-review` must independently approve the changed contract before implementation resumes.
  - contract-changing `resume-current-story` sets `Plan:` to `🟠 PLAN CHANGES REQUESTED` after the contract edits are blended and validation passes, because fresh `/openspec-story-plan-review` must independently approve the changed contract before implementation resumes.
  - if contract feedback cannot be fully blended, set `Plan:` to `🟠 PLAN CHANGES REQUESTED` and offer **Converge wrapper:** `/openspec-story-plan-converge <initiative> <story-slug>` or **Non-looped pass:** `/openspec-story-plan-resume <initiative> <story-slug>`. Say to choose one and not run both because the wrapper delegates direct review/resume passes.
- Write `## Plan Review Log` in `story.md` only for `queue-planning-feedback`; `/openspec-story-plan-review` remains the owner of independent review verdicts and the only command that may set `Plan:` to `🟢 PLAN APPROVED`.
- Update `story.md` Status header to `🔄 IN PROGRESS` for implementation-review feedback that should drive immediate story resume or PR rework. The prior `progress.md → ## Implementation Review Receipt` becomes historical evidence for the pre-reopen implementation; do not delete or rewrite it, and do not treat it as contradictory while the story is active. A fresh completed review must replace it before any new `✅ DONE`. Persist feedback identity and routing in the `<receipt_root>` initiative ledger after owned edits succeed.

Draft the acknowledgement plan. The plan must target only the coordination documents listed above and must never include `reviews.md` rows (there is no standalone reviews.md artifact; review findings route through story.md and the initiative receipt). Include the receipt destination for every item. A batch may classify and absorb multiple explicit targets, but it must not arbitrarily select one target's follow-up as the batch next action. If more than one actionable target remains after absorption, the final route is one scalar operator decision asking which target to advance first and listing every target type with a stable identifier; do not emit a wrapper/direct choice. Use `story:<story-slug> [FB-###,...]` for story targets, `initiative:<initiative-slug> [FB-###,...]` for initiative decisions, and `candidate:<initiative-slug>/feedback:<FB-###>` for new-story candidates that do not yet have a story slug.

```md
## Proposed Feedback Absorption

| Feedback ID | Source | Disposition | Target | Planned edit | Rationale |
|---|---|---|---|---|---|
| FB-001 | PR #42 comment IC_... | queue-planning-feedback | <story-slug> | Plan Review Log + Plan lane + paired initiative receipt | Same story, planning contract needs rework. |
| FB-002 | PR #42 review PRRC_... | resume-current-story | <story-slug> | story.md Status + paired initiative receipt | Implementation misses existing A2. |
| FB-003 | PR #42 comment IC_... | new-story-candidate | initiative.md | Candidate + receipt-root receipt | New audit logging outcome. |
```

## Phase 4 — Acknowledgement checkpoint

Show the proposed absorption plan and ask for acknowledgement:

```text
Acknowledge this absorption plan, or list target/disposition corrections.
```

This is not a broad confirmation ritual and not a dry-run mode. The operator may:

- acknowledge the plan
- skip specific feedback IDs
- redirect a feedback ID to another story or disposition
- ask one clarifying question

Do not edit files before acknowledgement. If the operator changes routing, revise the plan once and ask for acknowledgement again.

## Phase 5 — Apply coordination edits

Apply the acknowledged plan with minimal edits. Before the first write for the batch, construct every disposition-owned edit and compact receipt in memory, re-resolve all paths from the fixed `<receipt_root>`, run every applicable content validation gate, and verify that each target and receipt insertion point is writable and still has the expected pre-edit content. Retain the exact initial bytes and SHA-256 hash of every file that may be changed, plus every expected post-operation bytes/hash. Immediately before each item, refresh and retain that item's pre-write bytes/hash (including earlier completed items) as its rollback baseline and require it to match the constructed sequence. A log-only disposition skips the story spec/proof checks, but not construction, hash, path, and insertion-point validation.

Every story-target owned-edit transaction must carry its FB ID in a durable story artifact. `queue-planning-feedback` carries it in `## Plan Review Log`; every `amend-existing-story` and `resume-current-story` carries it in `progress.md → ## Progress Timeline`, even for a direct amendment with no status change or a status-only resume. Any changed or added `tasks.md` row also includes `[FB-###]`; candidate and decision headings carry the ID. Do not inject process provenance into Acceptance or other product-contract prose merely to carry the ID. Unmarked story/design edits are covered by the same item's FB-tagged progress checkpoint, which must be written and verified before the receipt.

Process one acknowledged item at a time. Apply each of its disposition-owned file edits from the constructed content, verifying the expected post-edit hash after every write; write and verify its FB marker/checkpoint as part of that owned-edit transaction. If any owned edit or marker fails, stop before its receipt and later items. Best-effort restore every file already written for that item from the retained item-baseline bytes, then verify every restored hash. Do not roll back earlier items whose receipts already succeeded.

If rollback verifies, report the failed item and leave it unapplied. If rollback is incomplete, report every exact partially changed path with its current hash, expected item-baseline hash, and expected post-edit hash. On retry, reconcile only those reported paths against the retained/FB-tagged state: finish rollback or establish which constructed writes completed, then continue from the first missing operation. Never blindly reapply the whole item, duplicate a marker, or allocate another FB ID.

Only after all disposition-owned edits for an item succeed, append its already-constructed receipt to `<receipt_root>/openspec/initiatives/<initiative-slug>/initiative.md → ## Feedback Receipts`. If the authoritative ledger already has the identity, reuse it and do not append or repeat owned edits. An unambiguous legacy backfill has no repeated owned edit and appends only its missing receipt after acknowledgement.

If a receipt append fails after owned edits succeeded, stop immediately; do not process later items, roll back or reapply successful owned edits, or allocate a different ID. Check whether the exact identity receipt is complete; if not, report the initiative.md current hash and expected pre/post-receipt hashes so retry can reconcile a partial append. Report the successful artifact paths and print:

```text
Receipt append failed after owned edits for FB-###.
Retry exactly: <the verbatim original /openspec-feedback invocation>
Backfill only: reuse FB-### from the named FB marker under <receipt_root>; do not reapply owned edits.
```

On that exact retry, root selection and authoritative-ledger dedupe run again; the newly written FB-tagged evidence must be treated as legacy evidence, reuse the same FB ID, reconcile any reported partial file first, and produce a receipt-only backfill plan. For `defer-or-reject`, the receipt is the sole write: no prior artifact marker is required. If that append fails or its outcome is uncertain, retry with the same deterministic `Source ID` + `Source hash`; the authoritative ledger comparison either reuses the completed receipt or reconstructs only the missing receipt append under the then-current ID allocation, never a disposition-owned edit.

### Validation gate (story spec/proof edits only)

After constructing story spec/proof edits and before writing, run these phases in order. Read the story's original sections so the before/after diff is available. Phase A is the same story-plan validation gate used by `/openspec-story-plan-resume` for Acceptance, Verification, TAP, scenarios, actors, design trace, input-boundary, fail-open, and risk-lens edits; Phases B and C add feedback-specific preservation and red-first checks.

**Phase A — Structural checks.** Verify:
1. Every acceptance bullet starts with `A<n>:`.
2. `## Verification` contains `### Verification Commands`, `### Test Architecture Plan`, and `### Acceptance Proof Matrix` subsections.
3. The Test Architecture Plan uses stable `TAP-*` row ids and required columns: `Row ID | Layer / Scope | Behavior / Acceptance Slice | Owning Suite / File(s) | Boundary Exercised | Assertions / Observability | Fixture / Test Data Strategy | CI Lane / Command | Fallback Plan | Split / Merge Rationale`.
4. The Test Architecture Plan covers every added/changed test or proof surface introduced or affected by the feedback and satisfies the TAP quality gate: stable `TAP-*` ids, cheapest reliable real boundary, exact seam, behavior-facing assertion/observable signal, fixture/data isolation and live-dependency policy, focused command/CI lane, fallback plan, and split/merge rationale.
5. The proof matrix uses the required columns: `Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail`, and references relevant `TAP-*` row ids when tests or proof surfaces change.
6. Every `A<n>` appears in at least one proof row.
7. `Proof Maturity` is `final` or `provisional` only.
8. Every `provisional` row has non-blank `Open Detail`.
9. No `<TODO: ...>` placeholders in `## Acceptance` or `## Verification`.
10. If `## Actors` is present, it uses role bullets with at least one `Primary:` actor and stays consistent with Purpose, Scope, Scenarios, Acceptance, and Verification.
11. If feedback changes who initiates, participates in, reviews, or is affected by the behavior, the edit updates `## Actors` in `story.md` or records an explicit non-change rationale before writing.
12. If feedback changes concrete flows or examples, the edit updates `## Scenarios / Behavior Examples` in `story.md` or records an explicit non-change rationale before writing.
13. If `## Scenarios / Behavior Examples` is present, every normative `S<n>` scenario has exactly one `Covers: A<n>` and every orientation-only scenario says `Orientation only`.
14. Every normative scenario funnels through Acceptance and Verification: the covered `A<n>` wording includes the scenario behavior, and that acceptance id has proof row(s) covering the scenario, including named variants, modes, branches, fallback paths, and failure cases or explicit exclusions.
15. If the story spans surfaces, supported variants, modes, or internal orchestration branches, `### Surface / Branch Proof Matrix` exists and covers every in-scope combination or records an explicit exclusion.
16. If feedback introduces, changes, or exposes a design source, `### Design Sources` exists with durable/reviewable anchors and every source is marked `normative` or `orientation only`. Updates to design sources go into `design.md` when that artifact exists alongside `story.md`.
17. If any design source is `normative`, `### Design Element Trace` exists; every feedback-mentioned or obvious visible element/state from the normative source is mapped as `required` or bounded `flexible`; every trace row maps through Scenario → Acceptance → Verification/proof row; and visibility, placement, navigation, copy, responsive, or interaction-state obligations name rendered-surface proof or an explicit exception.
18. If raw persisted, external, framework, or generated input crosses stricter application assumptions, `### Input Boundary Shape Risk` exists when needed and covers every in-scope boundary/shape case or records an explicit exclusion/unknown with mitigation.
19. If prompt placeholders, template variables, or string substitution can fail open, `### Fail-open Checks` exists and covers enabled and disabled/default paths.
20. If feedback introduces or exposes an activated risk lens, the amended contract covers it through existing matrices or `### Risk Lens Inventory` with proof obligations or explicit exclusions.
21. Planned proof remains behavior-centered: private retry counts, sleeps, helper call order, timing, or implementation choreography are contractual only when explicitly locked.

**Phase B — Contract-preservation diff.** Compare the edited sections against the originals:
- Every pre-existing `A<n>` still appears in at least one proof row in the edited version (coverage match — row shape may change).
- Pre-existing `## Out of Scope` items have not been silently pulled into `## Scope` without explicit override.
- Pre-existing `### Design Sources` anchors/statuses and `### Design Element Trace` rows in `design.md` or `story.md` have not been silently removed, downgraded, or loosened unless the feedback explicitly overrides them and the operator confirms.
- Pre-existing `## Locked Decisions` in `story.md` have not been removed unless the feedback explicitly overrides them and the operator confirms.

**Phase C — Red-first seam alignment.** When `## Acceptance` or `## Scope` was edited and `## Implementation Notes` mentions a red-first seam:
- Show the planned seam and the amended acceptance criteria.
- Ask the operator: "Does this seam still cover the amended criteria?"
- Yes → proceed. No → block; operator must update `## Implementation Notes` before retrying.

**On failure:**
- Phase A → HARD BLOCK. Show the specific violation. Do not write. Operator revises the absorption plan or story edits before retrying.
- Phase B → SOFT BLOCK. Show the pre-existing commitment being removed. Operator may override with explicit acknowledgement, or revise the edits to restore the commitment.
- Phase C → HARD BLOCK. Operator must update `## Implementation Notes` with a corrected seam, then retry.

After all phases pass, proceed to write the edits to disk.

For acknowledged `resume-current-story`, update `story.md → Status:` only as needed to make implementation resumable:

- `✅ DONE` or `🟣 IN REVIEW` → `🔄 IN PROGRESS`.
- `🔄 IN PROGRESS` → unchanged.
- `⛔ BLOCKED`, TODO, missing, or unknown status → stop and revise the disposition or ask the operator for the owning lifecycle command; do not guess.

Record the before/after status in the feedback checkpoint and paired initiative receipt. The FB-tagged reopen checkpoint is the durable marker that the previous `## Implementation Review Receipt` is now historical. Leave that old receipt unchanged and do not treat its pre-reopen verdict/status as contradictory while current Status is active; only a fresh completed `/openspec-story-review` may replace it before the story becomes DONE again.

For every `amend-existing-story` and `resume-current-story`, append (or create `progress.md` and `## Progress Timeline` with) this concise checkpoint before the next owning command runs. Use `none` for status, contract sections, task changes, or plan transitions that did not occur; status-only resume and direct amendment are not exceptions.

```md
- <UTC ISO timestamp> Feedback absorption checkpoint
  - Feedback ID: FB-###
  - Source ID: <stable source id>
  - Source hash: sha256:<hex>
  - Disposition: <amend-existing-story | resume-current-story>
  - Status transition: <from> → <to or unchanged>
  - Contract sections updated: <sections or none>
  - Tasks updated: <task ids/rows or none>
  - Risk / miss category: <category or none>
  - Plan lane: <from> → <to or unchanged>
  - Required next action: <one state-correct owner>
```

For `queue-planning-feedback`, append or create `## Plan Review Log` in `story.md` with a request-changes entry and update the `Plan:` header field to `🟠 PLAN CHANGES REQUESTED`. Do not edit story spec sections in this disposition.

```md
- <UTC ISO timestamp> Planning feedback routed by `/openspec-feedback`
  - Source: <source URL or source ID>
  - Source ID: <stable source id>
  - Source hash: sha256:<hex>
  - Feedback ID: FB-###
  - Verdict: request_changes
  - Plan lane transition: <from> → 🟠 PLAN CHANGES REQUESTED
  - Status transition: <current status> → <current status>
  - Sections reviewed: <Actors, Scenarios / Behavior Examples, Acceptance, Verification, Design Sources, Design Element Trace, Scope, Locked Decisions, etc.>
  - Key findings:
    - <finding, including required matrix/proof updates when relevant>
  - Debt Friction: none | <decision + short title>
  - Next action: `/openspec-story-plan-resume <initiative> <story-slug>`
```

For `amend-existing-story`, edit only these story sections inside `story.md`:

- `## Acceptance`
- `## Verification` (including conditional subsections such as `### Design Sources` and `### Design Element Trace` — note that design sources and element trace may also live in `design.md`, so also edit `design.md` when needed)
- `## Actors`
- `## Scenarios / Behavior Examples`
- `## Scope`
- `## Out of Scope`
- `## Critical Files`
- `## Implementation Notes`
- `## Discovery Notes`
- `## Locked Decisions`

Also edit `design.md` when the amendment changes `### Design Sources` anchors/statuses or `### Design Element Trace` rows that live there rather than in `story.md`. Edit existing `tasks.md` when the amendment changes implementation decomposition, proof work, or invalidates a completed task; add or reopen only the smallest affected task rows and tag each changed row `[FB-###]`. If required task alignment cannot be represented safely, leave the plan in changes-requested and route to `/openspec-story-plan-resume`.

Keep story-body edits as the durable contract change. If the amendment changes any contract/proof section, update the `Plan:` header field in `story.md` to `🟠 PLAN CHANGES REQUESTED`. Offer the planning Converge wrapper plus Non-looped fresh `/openspec-story-plan-review` only when the amendment is fully blended, the resulting scaffold is structurally reviewable, and no unresolved finding remains. Otherwise offer the wrapper plus Non-looped `/openspec-story-plan-resume` when the remaining repair is safely resolvable; malformed, ambiguous, or unresolvable states remain singular. The paired initiative receipt is the durable source identity and deduplication record for both `amend-existing-story` and `resume-current-story`.

If feedback changes actors, scenarios, acceptance boundaries, proof surfaces, design sources, design element obligations, supported branches, input-boundary shape assumptions, fail-open risks, or activated risk lenses, fully blend those changes before recommending `/openspec-story-resume`:

- update `## Actors` in `story.md` when feedback changes who initiates, participates in, reviews, or is affected by the behavior
- update `## Scenarios / Behavior Examples` in `story.md` when feedback changes concrete flows or examples; every normative scenario must use exactly one `Covers: A<n>` and funnel into Acceptance and Verification
- update `## Acceptance` and `## Verification` in `story.md` together
- update `### Acceptance Proof Matrix` for every acceptance id and named variant/failure mode
- update `### Surface / Branch Proof Matrix` when surfaces, variants, modes, or orchestration branches are introduced or changed
- update `### Design Sources` in `design.md` (or `story.md` when it lives there) when feedback introduces, changes, supersedes, or reclassifies a design artifact; anchors must be durable/reviewable and every source must be marked `normative` or `orientation only`
- update `### Design Element Trace` when feedback exposes unmapped or changed normative visible elements/states; use only `required` or bounded `flexible`, do not add an `omitted`/`ignored` class for accepted normative designs, map every row through Scenario → Acceptance → Verification/proof row, and require rendered-surface proof for visibility, placement, navigation, copy, responsive behavior, and interaction-state obligations unless an explicit exception is recorded
- update `### Input Boundary Shape Risk` when raw input shape assumptions are introduced or changed
- update `### Fail-open Checks` when prompt/template fail-open risks are introduced or changed
- update or add `### Risk Lens Inventory` when feedback exposes async/event-loop, platform/API, external I/O, permissions/security, resource lifecycle, retries/timeouts, semantic invariant, or other domain risks not already covered
- update existing `tasks.md` when task decomposition or completion state no longer matches the feedback-amended contract; tag every changed or added row `[FB-###]` and never mark feedback work complete speculatively
- append the FB-tagged checkpoint to `progress.md → ## Progress Timeline` for every direct amendment and resume, whether contract-changing or status-only
- apply the `resume-current-story` status reopen rule above
- set `Plan:` header field in `story.md` to `🟠 PLAN CHANGES REQUESTED` after the validation gate passes; offer the planning wrapper plus Non-looped fresh plan-review only when all edits are fully blended, structurally reviewable, and leave no unresolved finding, otherwise use the wrapper plus Non-looped plan-resume when safely repairable; this command cannot approve its own contract edits

When contract/proof edits are fully blended, structurally reviewable, and have no unresolved finding, `/openspec-story-plan-review <initiative> <story-slug>` is mandatory before `/openspec-story-resume`. Otherwise `/openspec-story-plan-resume` owns the next non-looped repair pass (with the planning wrapper alternative when the state is valid and safely repairable). If plan review requests changes, the story re-enters the plan-converge loop through `/openspec-story-plan-resume` until `Plan:` returns to `🟢 PLAN APPROVED`.

Do not update `## PR State` in `progress.md` here; recommend `/openspec-pr` only when PR metadata or merge evidence itself needs refresh. Actionable PR feedback is absorbed here as review/contract coordination; when the acknowledged disposition is `resume-current-story`, this command updates `story.md` Status to `🔄 IN PROGRESS` so `/openspec-story-resume` can own the code changes. Legacy review artifacts in existing workspaces are tolerated but not authoritative; do not read or rewrite them for feedback authority.

For `new-story-candidate`, append or create this initiative-level section in `initiative.md`:

```md
## Feedback-Derived Story Candidates

### FB-### — <short title>
- Source: <source URL or source ID>
- Source ID: <stable source id>
- Source hash: sha256:<hex>
- Origin: <story slug or PR URL>
- Reason: <why this is separate from existing stories>
- Proposed story: <one-sentence user/system outcome>
- Acceptance sketch:
  - <one or two objective outcomes>
- Recommended next command: `/openspec-story-plan INITIATIVE="<slug>"` and reference `FB-###` during the interview
```

For `initiative-level-decision`, append to an existing initiative decision section if one exists. Otherwise create in `initiative.md`:

```md
## Feedback-Derived Decisions

### FB-### — <short title>
- Source: <source URL or source ID>
- Source ID: <stable source id>
- Source hash: sha256:<hex>
- Decision: <pithy decision>
- Rationale: <why this belongs at initiative level>
- Applies to: <stories or initiative-wide>
```

## Feedback Receipts

The canonical portable ledger for the whole invocation lives at `<receipt_root>/openspec/initiatives/<initiative-slug>/initiative.md → ## Feedback Receipts`. If the section does not exist, construct its creation with the first acknowledged receipt, but write it only after that item's disposition-owned edits succeed. Do not pre-seed an empty section. Append exactly one entry per stable identity, and never copy `<launch_root>` or `<receipt_root>` into the entry. Candidate and decision sections created in the same invocation live in this same initiative.md.

Immediately before appending, repeat the authoritative-ledger comparison selected in Phase 3:

- exact `Source ID` + `Source hash` match: reuse its Feedback ID and existing receipt; do not append or repeat owned edits
- same Source ID with a different Source hash: treat it as an edited, new identity and use its already allocated new Feedback ID
- no receipt but unambiguous same-item legacy evidence under `<receipt_root>`: uniformly reuse its FB ID for every disposition and append one backfill receipt after acknowledgement, naming already-completed artifacts and performing no repeated owned edit
- ambiguous or conflicting legacy evidence: stop without writing or allocating a replacement ID

Use this compact format:

```md
### FB-### — <short summary>
- Source ID: <stable source id>
- Source hash: sha256:<hex>
- Disposition: <queue-planning-feedback | amend-existing-story | resume-current-story | new-story-candidate | initiative-level-decision | defer-or-reject>
- Target: <story:<story-slug> | candidate:<initiative-slug>/feedback:<FB-###> | initiative:<initiative-slug>>
- Acknowledged reason / rationale: <why the operator accepted this routing>
- Changed artifacts: <comma-separated openspec-relative paths; `initiative.md receipt only` for defer-or-reject>
- Next owner: <one owning slash command, operator action, wait condition, or none>
```

`Changed artifacts` lists every successful disposition-owned edit (including `tasks.md` or the FB-tagged progress checkpoint when applicable) plus `openspec/initiatives/<initiative-slug>/initiative.md` for the receipt itself. Keep the receipt short; source bodies and raw review details stay at their source. Every acknowledged item, including `defer-or-reject`, must end with exactly one receipt after its owned edits succeed.

## Phase 6 — Final response

Report:

- feedback IDs processed
- files changed (with full paths under `openspec/`)
- disposition and target for each item
- any items skipped or left ambiguous
- any story status reopen performed, or none
- recurring risk / miss categories observed, or none
- receipt outcome for each item (`created`, `backfilled`, or `reused`) and its canonical initiative.md path
- the exact singular route or applicable planning/implementation workflow choice selected from final authoritative state; ensure each receipt's `Next owner` agrees with this final routing (or names the same pending operator choice for a multi-target batch)

End the response with exactly one block selected from the acknowledged disposition and authoritative final state:

```markdown
Suggested next action: <scalar route; leave empty only for a dual route>
- Converge wrapper: <command; dual routes only>
- Non-looped pass: <state-correct command; dual routes only>
Choose one; do not run both.
```

For a scalar route, put its value on the label line and omit the three dual-route lines. For a dual route, leave the label empty and render those three lines immediately after it.

- Before any wrapper/direct route, check `blocked.md` for every actionable story target. If any exists, use only the scalar operator action to resolve/remove the named blocker file(s); this hard gate takes precedence over all lane choices.
- For planning entry/re-entry, use the planning Converge wrapper plus Non-looped `/openspec-story-plan-review <initiative> <story-slug>` only when contract changes are fully blended, no unresolved Plan Review Log finding remains, and the scaffold is structurally reviewable. If unresolved findings or repairs remain, use Non-looped `/openspec-story-plan-resume <initiative> <story-slug>` instead.
- For `resume-current-story` with Plan approved and Status IN PROGRESS, offer **Converge wrapper:** `/openspec-story-converge <initiative> <story-slug>` and **Non-looped pass:** `/openspec-story-resume <initiative> <story-slug>`. Say to choose one and not run both because the wrapper delegates direct claim/resume passes.
- If authoritative Status is IN REVIEW, give only a fresh oblivious `/openspec-story-review` handoff; the wrapper never launches review.
- Keep `new-story-candidate`, `initiative-level-decision`, `defer-or-reject`, blocked, malformed/ambiguous, PR, archive, wait, and terminal routes singular.
- If the acknowledged batch leaves multiple actionable targets of any type, use only `Operator decision: choose which target to advance first: <typed-stable-target-list>.` The list must include every actionable target using `story:<story-slug> [FB-###,...]`, `initiative:<initiative-slug> [FB-###,...]`, or `candidate:<initiative-slug>/feedback:<FB-###>` as applicable. Never select one based on item order, recency, or status, and never append a wrapper/direct choice.

When `amend-existing-story` touched any contract/proof section, the Non-looped pass is fresh `/openspec-story-plan-review <initiative> <story-slug>` only if the amendment is fully blended, structurally reviewable, and has no unresolved finding. Otherwise use `/openspec-story-plan-resume <initiative> <story-slug>` when safely repairable, with the planning wrapper alternative; malformed/ambiguous/unresolvable state remains singular.

Keep the response short. Do not paste long feedback bodies; link or cite source IDs instead.
