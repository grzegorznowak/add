---
name: openspec-story-plan-review
description: Review an OpenSpec change workspace's planning contract at any lifecycle point — validate Purpose / Actors / Scenarios / Acceptance / Verification / Critical Files / Locked Decisions against original intent, the live repo, and traceability gaps, then record a Plan Review verdict in the Plan lane.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug>"
allowed-tools: Read Edit Grep Glob Bash(git status:*) Bash(git log:*) Bash(git show:*) Bash(git worktree:*) Bash(gh issue view:*) Bash(gh pr view:*) Bash(jira issue view:*) Bash(git -C:* remote get-url --all origin) Bash(printf:*) Bash(sha256sum:*)
---

# OpenSpec Story Plan Review

Review one OpenSpec change workspace's **planning contract** against the live repository at any lifecycle point. This is the planning-side analog of `/openspec-story-review`: read-only for code, read-only for the story's spec sections, and writes only to a new `## Plan Review Log` entry on `story.md` plus the `Plan:` header field. The highest-leverage part of this review is the acceptance/proof contract: atomic acceptance ids plus a reviewer-facing proof matrix that is credible enough to drive red-first implementation without drifting into fake seams.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug>`. Both are required; if either is omitted, this command uses the explicit menu fallback in `## Resolution`.

## Important

This command only edits the resolved `story.md` file's `## Plan Review Log` section and `Plan:` header field. It **never** touches:

- source code (product files, tests, configs)
- the files listed in the story's `## Critical Files`
- any spec section of `story.md` (`## Purpose`, `## Actors`, `## Triggering Need`, `## Expected Prerequisites`, `## Scope`, `## Out of Scope`, `## Scenarios / Behavior Examples`, `## Acceptance`, `## Verification`, `## Discovery Notes`, `## Critical Files`, `## Implementation Notes`, `## Locked Decisions`)
- supporting planning artifacts (`proposal.md`, `design.md`, `tasks.md`, `specs/`)
- runtime artifacts (`progress.md`, `blocked.md`)
- the implementation `Status:` header field on `story.md` (`⚪ TODO`, `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `✅ DONE`, `⛔ BLOCKED`)

It may check whether `<change_dir>/blocked.md` exists during resolution, solely to honor the explicit block gate before writing a review lane transition. It must not read, create, edit, or remove `blocked.md`.

If you find the plan is wrong, say so in the log's `Key findings` and recommend the operator edit the spec sections themselves. Do not rewrite the plan inside the log.

## Why operator-explicit (arg or menu) selection

`/openspec-story-plan-review` never auto-infers the initiative or the story. The operator explicitly chooses — either by passing `<initiative-slug> <story-slug>` as arguments or by picking from the menu this skill shows when either is absent. The menu is **not** inference: it lists legal candidates and asks the operator to pick.

The reasoning: plan review must come from a fresh, independent perspective. The same session that just wrote the plan will rationalize it, not scrutinize it — it will read every section as evidence for the conclusions it already reached during planning. Auto-inferring "the current story" would silently pick whatever the session was last planning — exactly the coupling we want to avoid.

A gentle nudge: if you find yourself picking from the menu in the same session that wrote the plan, consider opening a fresh session for the review. The menu still makes it possible to run plan review from the planning session, but the friction is intentional and any future change that adds silent auto-inference here must be rejected.

## Resolution

1. Parse `$ARGUMENTS` as `<initiative-slug> <story-slug>` (both optional). Validate every provided slug against `^[a-z0-9]+(?:-[a-z0-9]+)*$` before resolving a path; abort invalid input with the corresponding lowercase-hyphenated-slug message. Record `<explicit_pair>` as true only when the operator supplied both positional slugs in this invocation; a menu selection or auto-default does not make an explicit pair.
2. Set `<workspace_root>` = `<cwd>` and build `<candidate_roots>` from `<workspace_root>` plus `git worktree list --porcelain`, deduplicated by real checkout path. This planning command accepts no `WORKTREE=` selector. `<openspec_root>` is selected only after a story is selected and is never persisted.
3. For menu/discovery scans, enumerate active `<root>/openspec/changes/*/story.md` workspaces across `<candidate_roots>`; never drive membership from initiative prose. Resolve duplicate copies of each story slug by root precedence: exactly one qualifying worktree other than launch on `refs/heads/<bound-or-associated-initiative>/<story-slug>` outranks launch, multiple qualifying branch worktrees halt, and no qualifying branch worktrees means fallback only to `<workspace_root>`. Ignore unrelated/non-branch copies. Inventory each selected story's top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line. Exactly one present line is valid only when its whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`; duplicate, empty, whitespace-before-colon, non-canonical, or otherwise malformed Initiative-like lines halt and are never reinterpreted as legacy absence. A menu may list a bound story or a zero-Initiative-line legacy story only when exactly one same-root `initiative.md → ## Story Candidates` section contains an exact association to its slug. Warn for every accepted legacy story and never backfill it; zero associations are excluded because a menu-selected initiative alone is not an operator-explicit pair, while multiple associations halt as ambiguity.
4. **INITIATIVE resolution (menu fallback):** If `<initiative-slug>` was not passed, group the discovered active stories needing plan review by their authoritative binding (or the one exact legacy association), requiring the corresponding `initiative.md` in the same root. Print `<slug> — <N stories needing plan review, last-touched YYYY-MM-DD>`. If empty, abort with: `no initiatives have stories needing plan review; pass an explicit initiative and story to re-review an approved plan`. Otherwise ask the operator to pick and validate the result.
5. **STORY resolution (menu fallback):** If `<story-slug>` was not passed, list only discovered bound stories and uniquely associated legacy stories for the selected initiative whose Plan lane is not `🟢 PLAN APPROVED` or is absent. Print `<story-slug> — <Plan> — <Status> — <Deliverable summary>`. If empty, abort with: `no stories needing plan review in initiative <slug>; pass a story explicitly to re-review an approved plan`. Otherwise ask the operator to pick and validate the result.
6. After both slugs are known, resolve root precedence in this order: because no explicit `WORKTREE=` selector is accepted, inspect registered worktrees other than `<workspace_root>` on `refs/heads/<initiative-slug>/<story-slug>` that contain both the selected initiative file and active story file. Exactly one qualifying branch worktree outranks launch; multiple qualifying branch worktrees halt for operator selection. Only when none qualifies, fall back to `<workspace_root>` and require both artifacts there. If active resolution fails, check archive locations across the discovered roots; an archived match halts as archived, otherwise route singularly to `/openspec-story-plan INITIATIVE=<initiative-slug>` only after relocation is ruled out.
7. Set `<initiative_dir>` = `<openspec_root>/openspec/initiatives/<initiative-slug>`, `<initiative_file>` = `<initiative_dir>/initiative.md`, `<change_dir>` = `<openspec_root>/openspec/changes/<story-slug>`, and `<story_file>` = `<change_dir>/story.md`. Missing initiative/story files halt with their exact paths; an existing directory without `story.md` requires restoration from version control or backup, not story creation.
8. Validate the selected story's durable initiative binding before lifecycle state or review writes:
   - Inventory the complete top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line. Exactly one present line is valid only when its whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`. Duplicate canonical headers, an empty value, whitespace before the colon (for example `Initiative : foo`), a non-canonical value, or any other malformed Initiative-like line halts without editing and reports every offending line. Never reinterpret malformed present input as zero-header legacy.
   - The one valid header must equal `<initiative-slug>`. A mismatch halts and reports both values; do not reinterpret membership from prose.
   - Only zero Initiative or Initiative-like lines is legacy. For that case, scan active initiative files in `<openspec_root>` for exact `<story-slug>` associations in `## Story Candidates`. Exactly one association is valid only when it equals `<initiative-slug>`; a different or multiple association halts. No association is accepted only when `<explicit_pair>` is true and the selected initiative file exists. Otherwise halt: a menu-selected or auto-defaulted initiative alone cannot bind a zero-reference legacy story. Print a compatibility warning for every accepted legacy story and never backfill the header.
9. If `<change_dir>/blocked.md` exists, abort with: `blocked.md gate file exists; the operator may edit it to record resolution notes, but must remove it before plan review can continue.` This is a singular operator-action gate; do not offer wrapper/direct choices.
10. Read authoritative `Status:`. If it is `🟣 IN REVIEW`, abort plan review with only this executable route even when Plan contradicts it: `Open a completely fresh, oblivious session and run /openspec-story-review <initiative-slug> <story-slug>.` The substantive implementation review owns any safe normalization of its current review state; this planning command does not.
11. Use `<story_file>` as the only plan review target. There is no `MASTER.md` in this flow; the `Plan:` header field in `story.md` is the authoritative planning lane and the `## Plan Review Log` section is the review history.

## Read first

1. the main repo `AGENTS.md` for the repo the plan will touch
2. `<initiative_dir>/initiative.md` — for Goal/Context, Story Candidates, Decisions & Constraints, External Resources, and Feedback-Derived Story Candidates / Decisions context
3. the resolved `<story_file>` — every section
4. `<change_dir>/proposal.md` — for Goal/Context and Decisions & Constraints
5. `<change_dir>/design.md` — for technical design context, architecture decisions, and implementation strategy
6. `<change_dir>/tasks.md` — for task breakdown and implementation plan
7. delta spec files under `<change_dir>/specs/` — for spec-level behavioral obligations
8. original intent artifacts explicitly linked or keyed from `<initiative_file>`, `<story_file>`, dependency workspaces, branch names, commit messages, or existing PR text: GitHub issues, GitHub PRs, Jira tickets, or stable ticket/card ids
9. design sources explicitly listed in `## Verification` (`### Design Sources`) when present; inspect only durable/reviewable anchors and treat orientation-only sources as context
10. dependency change workspace `story.md` files listed in the story's `## Expected Prerequisites`
11. materially relevant sibling change workspaces (from `## Story Candidates` in `initiative.md`) when they define the same shared interface, proof surface, actor flow, or locked decision

## Plan readiness check

Before doing the full plan review, abort fast with a concise reason if any of these hold:

- the implementation `Status:` header in `story.md` is `✅ DONE` — inventory all `<change_dir>/progress.md → ## Implementation Review Receipt` headings. When any receipt is present, require exactly one section/body with every canonical required field exactly once, `Decision: APPROVE`, `Approval gate: PASS`, and a `Status transition` ending in `✅ DONE`; duplicate, truncated, malformed, contradictory, stale, or non-approving content routes only to `Open a completely fresh, oblivious session and run /openspec-story-review <initiative-slug> <story-slug>.` Receipt absence is legacy compatibility only for a true unbound pre-v3 story with zero Initiative or Initiative-like header lines and zero receipt sections: warn and do not synthesize one. A bound modern DONE story without a receipt routes to the same fresh oblivious review, never legacy compatibility. After that receipt gate, inspect `Plan:` only to detect contradiction. If Plan is anything other than unambiguous `🟢 PLAN APPROVED`, stop with only `Operator action: investigate and reconcile the contradictory durable Status: ✅ DONE and Plan: <value> state before delivery or archive.` Do not recommend planning commands that reject DONE and do not invent a lifecycle owner. Only a consistent DONE with a qualifying receipt or the exact zero-Initiative/zero-receipt pre-v3 exception says "completed stories are not contract-reviewed in place; route new feedback through `/openspec-feedback` as a candidate or explicit reopen decision".
- the existing change workspace has repairable scaffold drift from `/openspec-story-plan` — say "story scaffold is incomplete; plan review assumes proposal.md, story.md, design.md, tasks.md plus Plan/Status/log anchors" and use the singular scalar route `/openspec-story-plan-resume <initiative-slug> <story-slug>`; do not offer the planning Converge wrapper. A genuinely absent workspace already routed to `/openspec-story-plan INITIATIVE=<initiative-slug>` during resolution.
- the story file is missing `## Purpose`, `## Acceptance`, or `## Verification` — say which section is missing and use the same singular scalar `/openspec-story-plan-resume <initiative-slug> <story-slug>` route without the planning Converge wrapper

Legacy compatibility: if `## Actors` and/or `## Scenarios / Behavior Examples` are fully absent, do not fail solely for that absence. If either section is present, review it for correctness and consistency with the full plan.

Resolve the planning lane before review:

- If the `Plan:` header field exists in `story.md`, use that value as the planning-lane authority.
- If the `Plan:` header field is missing, infer legacy planning state from the latest effective `## Plan Review Log` entry: the last appended review entry after applying any later addressed-entry references. Map `approve` -> `🟢 PLAN APPROVED`; unresolved `request_changes` or `not_reviewable` -> `🟠 PLAN CHANGES REQUESTED`; `blocked` -> `⛔ PLAN BLOCKED`; no entry -> `🟡 PLAN DRAFT`.
- If runtime artifacts exist (`progress.md`), enter **contract-review mode**. In this mode, validate only the story contract and proof plan; do not assess implementation completeness, do not read `progress.md` as proof that the contract is correct, and do not change implementation `Status:`.
- If runtime artifacts do not exist, enter normal pre-implementation plan-review mode.

Remember the pre-review `Plan:` value, then set the `Plan:` header field in `story.md` to `🟣 PLAN IN REVIEW` before the full review begins. The final verdict in this command must overwrite it with `🟢 PLAN APPROVED`, `🟠 PLAN CHANGES REQUESTED`, `⛔ PLAN BLOCKED`, or the remembered pre-review value for an unrecoverable `not_reviewable` verdict unless the command aborts before write-back.

## Source-of-truth hierarchy

1. the main repo `AGENTS.md`
2. `<initiative_file>` for initiative identity, constraints, decisions, and story candidate context
3. actual code and tests for already-implemented behavior, including but not limited to the files referenced by the story's `## Critical Files` (read-only probes only)
4. original issue/ticket/PR intent and acceptance criteria, when explicitly linkable and not superseded by decisions recorded in the initiative or story
5. durable design sources explicitly listed as `normative` in the resolved story's `### Design Sources`; orientation-only design sources are context only
6. the resolved `<story_file>`
7. dependency change workspace `story.md` files and materially relevant sibling change workspaces

There is no `CONTRACT.md` in the active OpenSpec workflow. The `initiative.md` file is the initiative-level context source for decisions, constraints, and cross-story commitments. If original ticket/PR/Jira intent conflicts with decisions recorded in `initiative.md`, do not silently prefer the ticket; the plan is not approvable unless it records an explicit reopen, scope-deviation, or initiative-update decision. If `initiative.md` context conflicts with the live codebase, the codebase wins and the finding should say the initiative context is stale and needs updating. Never invent linkage: if ticket/PR/Jira evidence is absent, inaccessible, weak, or contradictory, say so explicitly and review against the remaining initiative/story sources.

Do not infer identity from filename shape or naming conventions that are not explicitly recorded in `initiative.md` or `story.md`.

## Notebook mode contract

When notebook orientation or persistence is available and selected, Repository-key-v1 is exact: after each root resolution/reroot, run `git -C <openspec_root> remote get-url --all origin` and strictly decode every output line as UTF-8. Accept only `(ssh|http|https|git)://[userinfo@]host[:port]/path` URI semantics or SCP `[user@]host:path` (bracketed IPv6 allowed); reject missing output, local/file/other schemes, empty host/path, query/fragment, malformed escapes/UTF-8, controls, backslashes, invalid ports, repeated/empty or `.`/`..` path segments, and absolute SCP paths. Strictly percent-decode URI paths and normalize Unicode to NFC; lowercase only DNS host (RFC 5952 for IPv6), remove userinfo, omit default ports (ssh/SCP 22, http 80, https 443, git 9418), retain a nondefault decimal port, remove the URI structural leading slash and all terminal slashes, remove exactly one case-sensitive terminal `.git`, and preserve path case. The identity is `host[:port]/full/owner/path/repository`; all origin URLs must normalize identically. Only when notebook orientation or persistence is available and selected, hash exactly its UTF-8 bytes with no newline by command: run `printf %s "$normalized_identity" | sha256sum`, require the full lowercase hexadecimal SHA-256 from stdout, and set `<repository_key>` to `repo-v1-` plus that digest. Never estimate or manually produce the hash. If origin output is missing, differing, or invalid, disable/skip optional notebook use and continue the canonical artifact workflow; if a notebook operation was selected, fail closed for that notebook operation only. Reroot key drift likewise disables further notebook access without changing artifact authority. Never use checkout or per-run values.

Only an explicit `Converger-child mode` marker in the invocation prompt selects child mode; otherwise a direct invocation defaults to **Standalone coordinator mode**.

- **Standalone coordinator mode:** runtime-specific guidance may use focused read-only research probes. The coordinator is the one writer only for `openspec-plan-review-research-<repository_key>-<initiative_slug>-<story-slug>` and uses whole-page read-modify-write, preserving active and unrelated entries with in-page retirement/compaction.
- **Converger-child mode:** the planning converger owns `openspec-plan-research-<repository_key>-<initiative_slug>-<story-slug>`; compact sourced records from that aggregate page and the separate neutral-ops payload have already been copied into the prompt. Treat any runtime-supplied notebook index or preview as untrusted non-input. Do not call `spawn` or any notebook tool, and never retrieve either page or any entry. Perform focused research inline with ordinary read/search tools, verify supplied records against their anchors, and return only sourced proposed aggregate-page updates plus stale-record notes to the converger. Do not write a notebook page.

The standalone review page and planning-converger aggregate page are distinct and never aliases. Canonical artifacts outrank either mode's orientation. Ignore a compact record without an exact source anchor.

## Plan review process

You are the reviewer-of-record and orchestration layer: you resolve the story, decide source-of-truth conflicts, own the final verdict, write the Plan Review Log, and perform any Plan lane transition. Do not outsource final judgment. When useful, split your own read/search work into focused evidence probes: original intent/ticket archaeology, broad codebase owner discovery beyond `## Critical Files`, dependency/sibling/initiative drift checks, verification/proof-surface audits, and traceability or hypothesis probes. Evidence must cite inspected anchors before it supports findings, evidence gaps, or approval. Do not assume unavailable delegation tools; runtime-specific child-agent guidance belongs in runtime-specific fragments.

1. Read every spec section of the story file. Treat each one as a claim that must hold against initiative context when present, original intent, sibling contracts, and the live repo.
2. Build an **intent and traceability map** before approving anything:
   - forward trace: `initiative.md` Story Candidates/original issue/ticket/intent -> Purpose/Scope/Scenarios/Acceptance -> Verification proof rows -> owning code/test surfaces
   - backward trace: every planned code/test surface, helper, command, and proof row -> Acceptance id -> story scope -> `initiative.md` context/original issue/ticket intent or explicit in-story rationale
   - design trace when applicable: normative design source anchor -> visible element/state -> `required` or bounded `flexible` trace row -> Scenario -> Acceptance -> Verification -> rendered proof action
   Missing links are not automatically blockers when no original ticket exists, but unmapped normative design elements are blockers and must be visible in findings.
3. Mine original intent aggressively but only from explicit anchors: ticket/PR URLs, Jira keys, issue numbers, branch names, commit messages, `initiative.md` Story Candidates and External Resources, dependency workspace `story.md` files, PR bodies, or story prose. Use `gh issue view`, `gh pr view`, `jira issue view`, `git log`, and `git show` when available and relevant. If an external source cannot be accessed, record the exact missing source and do not invent its content. If external intent conflicts with `initiative.md` decisions or constraints, treat that as a conflict requiring an explicit decision rather than as a reason to override the initiative.
4. Use `Read`, `Grep`, and `Glob` to probe the repository beyond `## Critical Files` — confirm paths resolve, search for 2–4 domain terms, inspect existing tests, public APIs, similar helpers, deprecated duplicate owners, routing/callsite surfaces, and sibling story contracts. Confirm the domain the plan covers does not already have reusable implementations the plan missed, and confirm `## Locked Decisions` do not contradict `AGENTS.md`, initiative context, ticket intent, or established patterns.
5. Treat `## Scenarios / Behavior Examples`, `## Verification`, and `## Implementation Notes` as the behavior-funnel, proof-design, and implementation-method contract, not as proof that the implementation already exists. Do not run the planned tests expecting them to pass at this phase. Instead, validate whether scenarios funnel into acceptance, whether commands, seams, owning surfaces, branch decomposition, design traces, routing proofs, and fail-open checks are concrete, plausible, aimed at the real acceptance behavior rather than a mocked caricature of it, and specific enough to support red-first implementation after source inspection.
6. Use `git status` to confirm the worktree is not mid-implementation (if there are large pending changes, note it — plan review on a dirty worktree is a warning signal).
7. Use `git log` and, when useful, `git show` to skim recent related history for code movement, prior fixes, reverted approaches, hidden tests, or ticket references the plan should have referenced but did not.
8. Run adversarial lenses explicitly: requirements completeness, UI/design-source extraction, code-owner discovery, negative-space/missing cases, variant and branch coverage, activated risk lenses, behavior-vs-mechanics proof quality, rendered-surface proof quality, fail-open/default behavior, data-shape boundaries, migration/config/runtime impact, backward traceability, and alternatives to each major locked decision.
9. Never speculate about code, tests, tickets, or PRs you haven't read. If a claim in the plan can be checked, check it. If it cannot be checked, classify it as confirmed, inferred, unknown, or provisional.
10. Run a risk-lens plan check: identify which domain risks the story activates (for example async/event-loop, concurrency, platform/OS APIs, external I/O, permissions/security, persistence, resource lifecycle, retries/timeouts, generated artifacts, or naming-sensitive invariants) and verify the plan either proves each activated risk at the owning boundary or explicitly excludes it with rationale.
11. Run a Debt Friction check: ask whether the plan hides story-local friction from unclear ownership, duplicated behavior, weak or mocked tests, missing seams, hidden behavior, or unsafe structure. Only record a `Debt Friction` finding when there is a causal link: current story action -> concrete evidence -> delivery impact -> explicit decision.
12. If the plan looks structurally wrong, verdict is `request_changes` with a pointer to which sections to edit. Do not rewrite the plan inside the log.
13. Walk the full validation checklist below before settling on a verdict.

## Hypothesis triage and evidence grounding

Before final verdict, write a short private triage list and then carry only material items into findings or evidence gaps:

```md
- suspicious surface: <file/API/flow/ticket/plan section>; tentative issue: <possible plan failure>; next proof target: <source/ticket/test/code to check>
```

Every concrete finding must cite at least one inspected anchor: story section, ticket/PR/Jira anchor, `path:line` when available, command output excerpt, or exact missing source. Separate confirmed requirements from reviewer inference. A plan can be approved with known unknowns only when each unknown is explicitly bounded, does not undermine acceptance/proof, and has a follow-up path.

## Critical checks

Before approving, walk the grouped gate below. Treat blocker bullets as `request_changes` unless they are explicitly scoped out with safe rationale; warnings must still be named in the Plan Review Log when material.

### 1. Core planning contract

Blockers:
- `Purpose` is not concrete and user-visible, or `Triggering Need` lacks a real pain/source.
- `Scope` is not atomic, reads like multiple independent stories, or pulls in work not justified by the story.
- `Acceptance` bullets are missing stable `A<n>` ids, are vague, unobservable, or combine behaviors that can fail independently.
- Required spec sections contain `<TODO: ...>` placeholders.
- `Implementation Notes` do not make source inspection, smallest credible red seam, green implementation, and broadened verification the default path, or they permit red-first bypass without requiring a written exception.

Warnings unless they distort scope/proof:
- `Out of Scope` is missing or thin.
- Legacy `Actors` or `Scenarios / Behavior Examples` sections are absent. If present, they must be structurally valid and consistent with Purpose, Scope, Acceptance, and Verification.

### 2. Scenario, acceptance, and traceability funnel

Blockers:
- Any normative `S<n>` scenario lacks exactly one `Covers: A<n>` link, maps to acceptance wording that does not contain the scenario behavior, or lacks proof through the linked acceptance id.
- Orientation-only scenarios create implementation/proof obligations, or contradict required behavior.
- Named variants, modes, branches, fallback paths, examples, or failure cases inside an acceptance item are neither split into separate acceptance ids nor listed as separate proof obligations with evidence or explicit exclusions.
- Forward trace from `initiative.md` Story Candidates/original intent/source to Purpose/Scope/Scenarios/Acceptance/Verification is missing where a source exists and matters.
- Backward trace leaves planned helpers, APIs, test files, commands, config changes, TAP rows, proof rows, or implementation branches orphaned from acceptance ids and in-scope rationale.

### 3. Verification and TAP proof gate

Blockers:
- `## Verification` lacks exact `### Verification Commands`, `### Test Architecture Plan`, or `### Acceptance Proof Matrix` subsections.
- Verification commands are vague (`run the tests`), claim non-existent files, or fail to name reviewer-runnable commands/manual/file-read actions.
- `### Test Architecture Plan` lacks required columns: `Row ID | Layer / Scope | Behavior / Acceptance Slice | Owning Suite / File(s) | Boundary Exercised | Assertions / Observability | Fixture / Test Data Strategy | CI Lane / Command | Fallback Plan | Split / Merge Rationale`.
- TAP rows fail the TAP quality gate from `docs/openspec-conventions.md`: stable `TAP-*` ids; cheapest reliable real boundary; exact seam; behavior-facing assertion or reviewer-visible signal; fixture/data isolation and live-dependency policy; focused command/CI lane; fallback plan; and repo-convention split/merge rationale when behavior shares a file.
- Broad E2E/manual proof is used when an obvious lower-layer deterministic seam would provide equivalent confidence without an explicit rationale.
- Hidden live dependencies, slow/flaky/order-coupled fixtures, private-choreography assertions unless contractual, fake mocked-helper seams, or grab-bag test placement would make proof unreliable.
- `Acceptance Proof Matrix` omits any `A<n>` id, uses proof maturity outside `final|provisional`, leaves `Open Detail` blank for a provisional row, or combines ids/variants whose failure signal is not genuinely shared.
- Rows for changed tests/proof surfaces do not reference relevant `TAP-*` ownership when tests or proof surfaces change.

### 4. Conditional proof sections and risk lenses

Blockers when the condition applies:
- Multi-surface, variant, mode, or orchestration-branch stories lack `### Surface / Branch Proof Matrix`, omit an in-scope combination, or rely on helper proof when routing proof is required for supported callsites.
- Prompt/template/placeholder/string-substitution work lacks `### Fail-open Checks` proving no unresolved placeholders/raw tokens, enabled-path activation, and disabled/default-path baseline behavior.
- Raw persisted, external, framework, or generated input crosses stricter assumptions without proof at the raw boundary, an `### Input Boundary Shape Risk` matrix when needed, or explicit exclusions/unknowns with mitigation.
- Normative design sources lack durable anchors, `### Design Sources`, or complete `### Design Element Trace` rows using only `required` or bounded `flexible` obligations mapped through Scenario -> Acceptance -> Verification.
- Visibility, placement, navigation, copy, responsive, or interaction-state design obligations lack rendered-surface proof or an explicit narrower proof boundary.
- Material activated risk lenses (async/event-loop, concurrency, platform/OS APIs, external I/O, permissions/security, persistence, resource lifecycle, retries/timeouts, generated artifacts, prompt/template fail-open behavior, naming-sensitive invariants, etc.) are not proven at the owning boundary or explicitly excluded.
- External reality failure modes such as stale/not-found, permission/access denied, already-complete, timeout/cancellation, unsupported platform, or partial failure are omitted for platform/process/filesystem/network/subprocess/resource-lifecycle work without an exclusion.

### 5. Repo/source fit and ownership

Blockers:
- `Critical Files` paths do not resolve, omit obvious domain owners, or hide migrations/public APIs/existing tests/coupling that should affect the plan.
- Existing reusable code, tests, routes/callsites, fixtures, CLI/API entrypoints, generated artifacts, deprecated duplicate owners, or config/runtime surfaces are missed after domain-term search.
- Planned ownership remains ambiguous without a source-inspection step that will resolve it before code changes.
- `Locked Decisions` contradict `AGENTS.md`, initiative context, ticket intent, or established patterns; major decisions omit context, rejected alternatives, consequences, or architecture fit.
- Signature changes, parameter-wiring contracts, or output/report schemas are recorded only as advisory prose when a locked interface decision is required.
- Dependency/sibling change workspaces or `initiative.md` define shared actors, interfaces, verification conventions, or decisions that the plan silently drifts from.
- Ticket/initiative/code conflicts are not named with an explicit resolution. Respect the convention: codebase facts expose stale initiative context; initiative decisions supersede stale story/ticket intent unless the operator records a reopen or scoped deviation.

### 6. Evidence quality, debt, and findings

Blockers:
- Review evidence speculates about code, tests, tickets, PRs, or Jira sources that were not inspected or explicitly classified as inaccessible/unknown.
- Unknown or provisional evidence affects acceptance, route ownership, ticket intent, proof credibility, or contract drift without safe bounds and a follow-up path.
- Debt Friction that affects proof or scope is hidden instead of recorded with the `docs/openspec-conventions.md` shape. A plan is `blocked` for Debt Friction only when meaningful acceptance or proof planning is not possible.

Warnings:
- Non-blocking evidence gaps, repo-fit concerns, or optional follow-ups should be logged with severity and next action instead of silently ignored.

## Plan lane transitions

You may update the `Plan:` header field in `story.md` as part of this review. Never change the implementation `Status:` header field on `story.md` from this command.

- `approve` → set `Plan:` to `🟢 PLAN APPROVED`. Route from authoritative implementation `Status:`. For `⬜ TODO` or `⚪ TODO`, offer the Converge wrapper `/openspec-story-converge <initiative-slug> <story-slug>` or the Non-looped pass `/openspec-story-claim <initiative-slug> <story-slug>`. For `🔄 IN PROGRESS`, offer the same wrapper or the Non-looped pass `/openspec-story-resume <initiative-slug> <story-slug>`. Tell the operator to choose one and not run both because the wrapper delegates the direct claim/resume passes. For `🟣 IN REVIEW`, give only the fresh oblivious `/openspec-story-review` handoff; for `✅ DONE`, blocked, missing, malformed, or ambiguous state, give only the state-owning route.
- `request_changes` → set `Plan:` to `🟠 PLAN CHANGES REQUESTED`. Offer the Converge wrapper `/openspec-story-plan-converge <initiative-slug> <story-slug>` or the Non-looped pass `/openspec-story-plan-resume <initiative-slug> <story-slug>` to edit the specific spec sections named; tell the operator to choose one and not run both because the wrapper delegates the direct review/resume passes. After a Non-looped resume, re-check `Plan:` and run a fresh `/openspec-story-plan-review` when reviewable. For a ground-up rewrite before implementation starts, recommend deleting the change workspace and re-running `/openspec-story-plan` as the singular route.
- `blocked` → set `Plan:` to `⛔ PLAN BLOCKED`. Use this only when the plan is unsalvageable as written and the operator needs to pause on this story (e.g., the plan depends on an upstream story that does not exist, or a `## Locked Decision` directly contradicts the architecture and the plan cannot be minimally amended). Blocked routing is singular; do not offer a wrapper/direct choice.
- `not_reviewable` → set `Plan:` to `🟠 PLAN CHANGES REQUESTED` if missing context can be repaired in an otherwise reviewable story contract, then offer the same planning wrapper/Non-looped resume choice as `request_changes`. A missing or incomplete scaffold stops before review and gets only the singular `/openspec-story-plan-resume <initiative-slug> <story-slug>` route, never the planning Converge wrapper. If missing context cannot be repaired in the story contract, restore the pre-review `Plan:` value from before this command wrote `🟣 PLAN IN REVIEW` and say what context is missing as the singular route. Never leave the final lane at `🟣 PLAN IN REVIEW` for a completed `not_reviewable` verdict.

**Explicit prohibitions:** never move a story's `Plan:` header into `⚪ TODO`, `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `✅ DONE`, or implementation `⛔ BLOCKED` from this command. Those transitions are owned by `/openspec-story-claim`, `/openspec-story-resume`, and `/openspec-story-review`.

## Plan review log write-back

Append or create a `## Plan Review Log` section on the story file with a new entry:

```md
- <UTC ISO timestamp> Plan review run by fresh maintainer session
  - Verdict: approve | request_changes | blocked | not_reviewable
  - Plan lane transition: <from> -> <to>
  - Status transition: unchanged: <status> -> <status>
  - Sections reviewed: Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, Discovery Notes
  - Original intent checked: <issues/PRs/Jira/tickets/initiative sources or none found/inaccessible>
  - Traceability: forward <complete|gaps>; backward <complete|gaps>
  - Design trace: complete|gaps|not applicable
  - Code surfaces searched: <paths/patterns/entrypoints or none beyond Critical Files>
  - Risk lenses reviewed: <activated lenses and exclusions, or none material>
  - Evidence quality: confirmed <short>; inferred <short|none>; unknown <short|none>; provisional <short|none>
  - Finding closure: <disposition + fix proof + regression/side-effect check, or none>
  - Key findings:
    - <short bullet>
    - <short bullet>
  - Hypothesis triage: none | <material suspicious surface + proof target summary>
  - Debt Friction: none | <decision + short title>
  - Next action: <one concrete recommendation>
```

If a `Plan Review Log` section does not exist on `story.md`, create it at the end of the file. Append the new review entry during this command. Later `/openspec-story-plan-resume` may squash stale addressed history, but unresolved blockers, operator decisions, the latest disposition, Debt Friction, and material evidence anchors must remain recoverable.

## Output format

Start with findings, ordered by severity, with section references.

```markdown
**Decision**: [APPROVE | REQUEST CHANGES | BLOCKED | NOT REVIEWABLE]
**Reviewed Story**: <story-slug> / <change_dir>
**Plan coverage**: [sections present / missing / thin]
**Mode**: [pre-implementation plan review | contract review]
**Original Intent Used**: [issues/PRs/Jira/tickets/initiative sources inspected, none found, or inaccessible]
**Traceability**: [forward complete/gaps; backward complete/gaps]
**Design Trace**: [complete | gaps | not applicable]
**Risk Lenses**: [activated lenses reviewed, proof/exclusion gaps, or none material]
**Notebook context**: [standalone page read-modify-written and entries verified/retired | Converger-child proposed aggregate-page updates and stale-record notes returned, never pages written | none]

## Hypothesis Triage
- [suspicious surface -> tentative issue -> next proof target, or None]

## Evidence Gaps
- [unknown/inaccessible/weak evidence that matters, or None]

**Findings**
- [Severity] [section] issue with inspected anchor

**Summary**
- [2–4 short bullets]

**Plan Lane Transition**
- [🟡 PLAN DRAFT -> 🟢 PLAN APPROVED | 🟢 PLAN APPROVED -> 🟠 PLAN CHANGES REQUESTED | ...]

**Status Transition**
- [unchanged: <status> -> <status>]

Suggested next action: <scalar route; leave empty only for a dual route>
- Converge wrapper: <command; dual routes only>
- Non-looped pass: <state-correct command; dual routes only>
Choose one; do not run both.
```

For a scalar route, put its value on the label line and omit the three dual-route lines. For a dual route, leave the label empty and render those lines immediately after it. A non-reviewable STOP caused by a missing or incomplete scaffold uses only the scalar `/openspec-story-plan-resume <initiative-slug> <story-slug>` route; never offer `/openspec-story-plan-converge` there. Only for a reviewable scaffold may planning entry/re-entry use a dual route: `🟡 PLAN DRAFT` uses the planning Converge wrapper plus the Non-looped `/openspec-story-plan-review`, while `🟠 PLAN CHANGES REQUESTED` uses the planning Converge wrapper plus the Non-looped `/openspec-story-plan-resume`.

For implementation entry/re-entry, use **Converge wrapper:** `/openspec-story-converge <initiative-slug> <story-slug>` and **Non-looped pass:** TODO -> `/openspec-story-claim`, IN PROGRESS -> `/openspec-story-resume`; say to choose one and not run both because the wrapper delegates direct claim/resume passes.

When Status is IN REVIEW, give only this route: open a completely fresh, oblivious session and run `/openspec-story-review <initiative-slug> <story-slug>`; the wrapper never launches review. DONE with non-approved Plan uses only the operator action to investigate/reconcile the contradictory durable state and names no lifecycle owner. If there are no findings, say that explicitly.
