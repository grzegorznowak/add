---
name: openspec-story-review
description: Evaluate one implementation from a fresh, oblivious session and return a portable review packet without mutating code, OpenSpec artifacts, or notebook state.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug> [WORKTREE=\"<basename>=<path>\"]..."
allowed-tools: Read Grep Glob
readonly: true
---

# OpenSpec Story Review

Evaluate one story implementation against its current contract and live repository evidence. This command is an immutable evaluator: its only output is one portable packet for `/openspec-feedback`.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug> [WORKTREE="<basename>=<path>"]...`. Initiative and story slugs must match the canonical regex `^[a-z0-9]+(?:-[a-z0-9]+)*$`; reject non-canonical positional slugs before path resolution. Both positional values are recommended. If either is omitted, use the explicit menu fallback in `## Resolution`. `WORKTREE=` is an optional repeatable read target. Accept `WORKTREE="<basename>=<path>"`; accept legacy `WORKTREE="<path>"` only for exactly one target repository. Do not mix the forms.

## Immutable evaluator boundary

- Do not modify product files, OpenSpec artifacts, or notebook state; do not persist review output anywhere.
- Product files and OpenSpec artifacts are read-only for this evaluator.
- Do not write Status, receipts, timelines, or blocked.md.
- Do not disposition findings; `/openspec-feedback` owns disposition and durable publication.
- The direct next step for every packet verdict is `/openspec-feedback`.
- Use only `Read`, `Grep`, and `Glob`. Do not execute tests, git commands, external-service commands, child agents, or mutation tools. Inspect already-recorded command results and repository files instead; identify unavailable live proof in the packet.
- Do not accept parent/converger notebook references, implementation summaries, operational notes, prior chat context, or renamed implementation/convergence research as evidence.

## Resolution

1. Parse `$ARGUMENTS` for the positional arguments and every `WORKTREE=` selector. Validate each supplied or selected slug against `^[a-z0-9]+(?:-[a-z0-9]+)*$` before using it in a path. Record `<explicit_pair>` only when both positional slugs came from this invocation.
2. Set `<workspace_root>` to the current workspace and resolve `<openspec_root>` in memory. Inspect all explicit `WORKTREE=` values in either accepted form first. An explicit checkout qualifies only when it contains both `openspec/initiatives/<initiative-slug>/initiative.md` and `openspec/changes/<story-slug>/story.md`. If exactly one explicit candidate qualifies, set `<openspec_root>=<path>` immediately. If multiple qualify, return `NOT REVIEWABLE` and request an unambiguous selector. Only when no explicit candidate qualifies, inspect registered root-repo worktrees other than `<workspace_root>` for the story branch and both artifacts; that unique branch worktree outranks launch. If readable evidence cannot establish a unique candidate, fail closed rather than execute discovery commands. Otherwise use the current workspace only when both artifacts exist there. Never persist the resolved root.
3. When the initiative is omitted, use `Glob` and `Read` to list initiatives having legally bound active stories whose top-level `Status:` is exactly `🟣 IN REVIEW`; ask the operator to select one. For binding, a canonical top-level `Initiative:` header wins; otherwise only a unique exact `## Story Candidates` association binds the legacy workspace. Exclude malformed, conflicting, multiply-associated, and zero-reference legacy workspaces from this initiative menu because no explicit initiative has yet accepted them. Do not infer it from prior context.
4. When the story is omitted, list only active workspaces bound to the selected initiative whose top-level `Status:` is exactly `🟣 IN REVIEW`; ask the operator to select one. Enumerate only workspaces explicitly bound to it or uniquely candidate-associated with it. Never list an archived, malformed, conflicting, or differently bound workspace.
5. Resolve `<initiative_file>`, `<change_dir>`, and `<story_file>`. Missing artifacts produce `NOT REVIEWABLE` with the exact missing path. When the story workspace is genuinely absent, name `/openspec-story-plan INITIATIVE=<initiative-slug>` as the requested feedback-owned recovery route. An archived story is not reviewable.
6. Validate the top-level header region before the first `## ` heading. Exactly one line matching `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$` must agree with the selected initiative. Duplicate or malformed Initiative-like lines are conflicts. For a zero-header legacy story, scan exact candidate associations. If no initiative references it, accept only when `<explicit_pair>` is true; emit a compatibility warning and do not backfill the header. Reject every conflicting association.
7. The top-level `Status:` header is the only implementation lifecycle state. Missing, duplicate, malformed, or conflicting forms produce `NOT REVIEWABLE`.

## Exact entry gate

Proceed only when entry is exactly `Status: 🟣 IN REVIEW`.

Reject `✅ DONE` and every other entry Status as `NOT REVIEWABLE`; never perform a lifecycle review outside `🟣 IN REVIEW`.

A pre-existing sibling `blocked.md` is a read-only blocker input and produces `NOT REVIEWABLE`. The packet must identify the evidence and leave repair/disposition to `/openspec-feedback`.

Require top-level `Plan: 🟢 PLAN APPROVED`. A different or malformed Plan value is a gate finding and prevents `APPROVE`; continue only far enough to return a grounded packet for feedback.

## Read first

Read, in order:

1. applicable repository `AGENTS.md` files
2. `<initiative_file>`, including constraints, decisions, candidate context, and linked intent
3. all of `<story_file>`, especially Purpose, Actors, Triggering Need, Expected Prerequisites, Scope, Out of Scope, Scenarios / Behavior Examples, Acceptance, Verification, Critical Files, Implementation Notes, Locked Decisions, and Discovery Notes
4. `<change_dir>/proposal.md`, `design.md`, `tasks.md`, and delta specs under `specs/`
5. `<change_dir>/progress.md`, including Current Claim, Progress Timeline, Session Handoff, legacy Implementation Review Receipt input, and PR State
6. dependency story artifacts and materially constraining sibling story artifacts
7. implementation and tests at resolved target roots
8. explicitly linked durable issue, PR, ticket, or design-source material only when available through readable files

Do not retrieve notebook state. Current artifacts and live readable repository evidence are the complete review boundary.

## Prerequisite qualification

Apply this gate to every canonical prerequisite bullet before substantive review:

1. Require the dependency slug to match `^[a-z0-9]+(?:-[a-z0-9]+)*$`.
2. Resolve the active prerequisite first. Use archive only when the active copy is absent; active always outranks archive.
3. Require exactly one top-level `Status: ✅ DONE`.
4. A sibling `blocked.md` makes the prerequisite contradictory and unsatisfied in active or archive, regardless of DONE or receipt evidence.
5. Validate the Initiative header by the same exact-header rule. A bound modern prerequisite must have `progress.md` with exactly one `## Implementation Review Receipt` heading and one current body.
6. For that read-only legacy input, require every established field exactly once and require `Decision: APPROVE`, `Approval gate: PASS`, and a transition ending in DONE. Missing, duplicate, malformed, or non-approving evidence is unsatisfied. Do not normalize it.
7. Only an unbound pre-v3 prerequisite with DONE, no blocker input, zero Initiative-like headers, and zero receipt sections may pass under warned compatibility.
8. Treat the prerequisite verdict as legacy reader evidence; never recompute or freshness-check the story-scoped review identity against mutable repository state. During final gate recheck, never recompute a prerequisite's review identity.

Any unsatisfied prerequisite produces `NOT REVIEWABLE` with a finding naming the exact deficiency.

## Review readiness check

After the exact entry gate, parse this literal top-level shape:

```yaml
Review Focus: |
  <optional reviewer guidance on indented lines>
```

`Review Focus: |` is exactly one top-level field. Its content is the immediately following indented lines; the next top-level header terminates the block. No indented non-whitespace content means the block is blank. Malformed, duplicate, or conflicting Review Focus forms fail closed. Treat more than 1,000 whitespace-delimited units as over budget and fail closed. Keep nonblank Review Focus guidance roughly 500–1,000 tokens.

If the Review Focus block is blank, perform a full review.

If it is nonblank, a focused pass is allowed: read the actual content and inspect the focused surface and evidence. Resolve concrete paths, symbols, behaviors, risks, tests, and proof named by the guidance. Always inspect readiness, prerequisites, the complete diff inventory available in artifacts, the complete acceptance/proof map, actual focused implementation/tests, and directly connected callsites or invariants. Identify intentionally uninspected surfaces in the packet.

Widen the focused pass to a full review whenever baseline, scope, or risk is unclear. Also widen when guidance does not resolve to live evidence, the implementation escapes the claimed focus, proof crosses the focus boundary, a material risk points outside it, or focused evidence is inconclusive.

During review, `Review Focus: |` is read-only: review reads it but does not write it. Outside `🟣 IN REVIEW`, `Review Focus: |` is inert.

## Fresh-review firewall

The review must be fresh and oblivious. Allowed inputs are current OpenSpec artifacts, readable live repository/worktree evidence, read-only external material already linked from those artifacts, and explicit operator arguments.

Do not accept parent/converger notebook references under any alias. If inherited implementation-session context is supplied, stop with `NOT REVIEWABLE`. Explain that a fresh invocation with only artifact selectors is required and route the packet to `/openspec-feedback`.

A prior completed review section in `progress.md` is read-only legacy evidence. Classify each parseable concern as resolved, still open, superseded, or not assessable. Duplicate or malformed legacy sections are evidence-quality findings; never reconcile them.

## Worktree and evidence mapping

1. Read `progress.md → ## Current Claim` for `Worktrees:`, legacy singular `Worktree:`, and `Main-tree targets:`.
2. Apply an explicit `WORKTREE="<basename>=<path>"` only to the named target; explicit selectors outrank recorded paths. Apply legacy path form only when the story has exactly one target repository.
3. Require each effective path to exist and contain the expected implementation surfaces. With no command execution available, use readable `.git` metadata and artifacts as corroboration; if branch/base/diff identity cannot be established from readable evidence, record the limitation and do not approve.
4. Build `<project_root_map>` in memory. Route each product path to its selected root. Do not create a checkout or change any repository.
5. Inventory changed surfaces from readable patch/diff artifacts, commit metadata, proof matrices, and files. If a credible complete change inventory is unavailable, widen inspection and return a gate finding rather than assuming completeness.

## Review method

Build forward and backward traceability:

- initiative context and linked intent → story scope/scenarios/acceptance → final proof rows → implementation/tests
- every changed or claimed source, test, config, generated, and runtime surface → acceptance id and in-scope rationale or explicit exclusion
- normative design anchor → trace row → scenario/acceptance → proof → rendered observation when design obligations apply

Inspect owner callsites and existing idioms, not only named changed files. Check every named variant, fallback, malformed-input path, failure case, supported route, and raw-input boundary. Documentation is a hypothesis source, not implementation proof.

Classify evidence as confirmed, inferred, unknown, or provisional. Unknown or provisional evidence affecting acceptance, ownership, intent, contract drift, or proof credibility prevents `APPROVE`.

### Mandatory lenses

- requested outcome, every acceptance id, and every normative scenario
- scope/out-of-scope and locked decisions
- task state and final proof-matrix alignment
- test boundary quality and behavior-level assertions
- red-first delivery evidence: the focused failing seam used before implementation, or a documented exception with credible alternative proof when a red-first seam was infeasible
- correctness, regressions, architecture, duplication, maintainability, security, performance, packaging, and rollout where activated
- async/concurrency, process/resource lifecycle, filesystem/network/subprocess I/O, permissions, persistence, retries/timeouts, generated artifacts, and fail-open behavior where activated
- dependency and sibling-interface compatibility
- prior concern closure with fix and regression evidence
- debt friction only when this story has a concrete causal delivery impact

### Multipass threshold without child agents

Count concrete top-level items under `## Acceptance`. Six or more items requires 2–8 explicit focused passes. A readable implementation inventory over 30 files or 1500 changed lines also requires multipass. Because this evaluator cannot spawn children, perform each pass sequentially and independently in the same fresh session. Map every acceptance id and named case to a pass; an uncovered or inconclusive pass prevents `APPROVE`.

For each pass record internally: title, acceptance items, risks, files/symbols/tests inspected, searches and direct reads, surviving hypotheses, findings, proof notes, evidence quality, and result (`clean`, `findings`, or `inconclusive`). Synthesis must verify primary evidence, deduplicate root causes, and never convert uncertainty to approval.

### Red-first assessment

Assess whether the implementation used a red-first seam; when red-first was infeasible, require a documented exception or alternative proof.

Corroborate the assessment from current story, progress, test, and implementation evidence. A test that is merely present after implementation is not by itself proof of a red-first seam. If neither a focused seam nor an adequately justified exception/alternative proof is evidenced, report the gap and prevent `APPROVE`.

## Verdict rules

`Verdict` is exactly one of:

- `APPROVE`: all gates and acceptance/proof obligations pass, no blocking finding remains, and evidence is sufficient.
- `REQUEST CHANGES`: implementation, proof, contract, or quality defects require action.
- `BLOCKED`: substantive evaluation discovers an external blocker that prevents a reliable disposition.
- `NOT REVIEWABLE`: entry state, prerequisites, artifact integrity, target identity, or minimum evidence gates fail before a reliable substantive verdict.

Severity is one of `Critical`, `High`, `Medium`, `Low`, or `Info`. Every finding must have a stable local id, concise summary, direct `path:line` evidence, operator-facing impact, proof/verification, and a concrete requested outcome. Do not assign disposition or lifecycle publication fields.

`Finding count` includes every emitted finding block. An approval has zero blocking defects but may include informational findings only when they are genuinely actionable through feedback; otherwise keep the packet empty.

## Final stability gate

Immediately before packet emission, re-read entry `Status:`, `Review Focus: |`, sibling `blocked.md` existence, every prerequisite gate, and critical reviewed evidence.

Compare those fresh reads with the lifecycle, scope, target, acceptance/proof, verification, red-first, and finding evidence used to form the tentative verdict. If lifecycle or evidence drifted, do not emit `APPROVE` or `REQUEST CHANGES` from stale evidence; emit `NOT REVIEWABLE` with the drift details. Do not silently restart, repair, or persist anything.

Use the fresh reads to populate `Final stability recheck`. Populate the other packet assessments from inspected evidence, not from the finding count. Emit `Coverage`, `Acceptance / proof assessment`, `Verification run`, `Red-first assessment`, and `Final stability recheck` for every verdict, including when `Finding count: 0`.

## Final response

Return exactly one fenced `ADD-REVIEW-PACKET/1` packet as the entire final response, with no text before or after its matching closing fence.

Set `Finding count` to a base-10 nonnegative integer equal to the number of emitted finding blocks.

When `Finding count: 0`, emit exactly `Findings: none` and no finding blocks.

When `Finding count` is nonzero, omit `Findings: none` and emit exactly that many finding blocks.

The packet schema is:

```ADD-REVIEW-PACKET/1
Review mode: <full | focused>
Review focus: <focus summary | none>
Subject: <reviewed implementation>
Root: <resolved OpenSpec root>
Initiative: <initiative-slug>
Story: <story-slug>
Verdict: APPROVE | REQUEST CHANGES | BLOCKED | NOT REVIEWABLE
Coverage: <inspected surfaces and intentionally uninspected surfaces>
Acceptance / proof assessment: <acceptance and proof disposition>
Verification run: <commands and results inspected | not run with reason>
Red-first assessment: <red-first seam | documented exception | alternative proof>
Final stability recheck: <stable | drift details>
Finding count: <nonnegative integer>
Findings: none
Finding ID: <stable local ID>
Severity: <severity>
Summary: <concise finding>
Evidence: <path:line anchors>
Impact: <operator-facing consequence>
Proof / verification: <commands and results | not run with reason>
Requested outcome: <concrete correction or evidence needed>
Next step: /openspec-feedback
```

The schema displays both zero-finding and nonzero-finding conditional lines so their exact spelling is portable. In an actual packet, apply the count rules: retain only the applicable findings form, repeat the seven-line finding block from `Finding ID` through `Requested outcome` once per finding, and put `Next step: /openspec-feedback` exactly once at the end.

Each finding block is exactly seven lines, from `Finding ID` through `Requested outcome`.

Suggested next action: /openspec-feedback
