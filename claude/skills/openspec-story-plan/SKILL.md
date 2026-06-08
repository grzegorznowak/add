---
name: openspec-story-plan
description: Interview-driven creation of a new OpenSpec change workspace — writes proposal.md, story.md, design.md, tasks.md, and delta specs into openspec/changes/<story-slug>/ after interactive planning with proof-contract validation. Use when starting a new story under an existing OpenSpec initiative.
disable-model-invocation: true
argument-hint: '[INITIATIVE="<slug>"]'
allowed-tools: Read Grep Glob Write Bash(git status:*) Bash(git log:*)
---

# OpenSpec Story Plan

Create a new OpenSpec change workspace for an existing initiative by interviewing the operator through the story spec sections, validating the proof contract, and writing all planning artifacts into `openspec/changes/<story-slug>/`. This command writes proposal.md, story.md, design.md, tasks.md, and delta specs; runtime artifacts (progress.md, reviews.md, blocked.md) are created by the commands that own them.

Argument: `$ARGUMENTS` — optional `[INITIATIVE="<slug>"]`. If provided, resolve that initiative directly. If omitted, list available initiatives under `<workspace_root>/openspec/initiatives/` and ask the operator to pick one.

## Important

This command writes planning artifacts under `openspec/changes/<story-slug>/` after an explicit checkpoint confirmation. It never touches:
- source code (product files, tests, configs)
- runtime artifacts (progress.md, reviews.md, blocked.md)
- existing change workspaces
- the old `agent_coordination/` flow

## Why operator-explicit selection

`/openspec-story-plan` does not auto-infer which initiative a new story lives under. The operator explicitly chooses by passing `INITIATIVE=<slug>` or by picking from the menu. Creating a change workspace mutates the file tree, so the initiative choice must never be guessed.

## Resolution

1. Parse `$ARGUMENTS` — extract `INITIATIVE` if present.
2. If `INITIATIVE` was provided:
   - Resolve `<workspace_root>/openspec/initiatives/<slug>/initiative.md`.
   - If missing, abort with: `initiative not found; run /openspec-epic-plan first`.
3. If `INITIATIVE` was not provided:
   - List every directory under `<workspace_root>/openspec/initiatives/` with an `initiative.md`.
   - Show: `<slug> — <title>`. If none, abort with: `no initiatives found; run /openspec-epic-plan first`.
   - Ask: `Pick an initiative (number or slug):`.
   - Set `INITIATIVE` accordingly.

## Read first

1. `<workspace_root>/AGENTS.md` first, then `CLAUDE.md` as fallback.
2. `<workspace_root>/openspec/initiatives/<slug>/initiative.md` — for story candidates, decisions, and external resources.
3. The change schema at `<workspace_root>/openspec/schemas/story-change/schema.yaml` — to confirm required artifact structure.
4. Existing change workspaces under `<workspace_root>/openspec/changes/` — for naming context and collision detection.
5. The most recent active change workspace — to learn conventions and tone.

## Source-of-truth hierarchy

1. `AGENTS.md` / `CLAUDE.md` — load-bearing project conventions.
2. `openspec/initiatives/<slug>/initiative.md` — initiative-level decisions, constraints, and external resources.
3. The OpenSpec schema — artifact shapes and templates.
4. The conversation with the operator — their stated intent.
5. The live codebase — feasibility, collision detection, Critical Files.

## Lean story rule

Each material fact has one canonical home: `## Acceptance` for required behavior, `## Verification` for proof actions, `## Actors` for role participants, `## Scenarios / Behavior Examples` for concrete examples funneling into acceptance, `## Scope` for boundaries, `## Critical Files` for paths, `## Implementation Notes` for execution brief, `## Locked Decisions` for decisions and rejected alternatives, `## Discovery Notes` for source-derived facts.

## Interview loop

Walk the operator through each question in order. For every question:
- Propose a recommended answer with trade-off explanation.
- Include a concrete example when helpful.
- Probe the codebase before asking if the answer can be derived from it.
- Escape hatches (`skip` / `draft now`) are available for optional sections only. Load-bearing contract sections (`## Actors`, `## Scenarios / Behavior Examples`, `## Acceptance`, `## Verification`) must be structurally complete before drafting.

### Question 1 — Story slug

Ask for the change workspace's short hyphenated slug, e.g. `refresh-token-issuance`. Check for collisions under `openspec/changes/` and `openspec/changes/archive/`. If the slug collides, push back.

### Question 2 — Proposal / Purpose

Ask: "what user-visible outcome does this change deliver?" Push back on vague phrasing. Propose a one-paragraph draft. This becomes `proposal.md → ## Goal / Context` and `story.md → ## Purpose`.

### Question 3 — Actors

Ask: "who initiates, participates in, reviews, or is affected by this story?" Require at least one `Primary:` actor. Use role bullets.

### Question 4 — Triggering Need

Ask: "why now? what prompted this story?" Probe `git log` for related work.

### Question 5 — Expected Prerequisites

Walk existing change workspaces under `openspec/changes/`. Propose candidate prerequisites based on keyword matches. The operator confirms or corrects.

### Question 6 — Scope and Out of Scope

Ask what is in scope. Drive toward atomic scope. Push back on multi-story scope. Also ask what is deliberately out of scope.

### Question 7 — Scenarios / Behavior Examples

Ask for concrete examples funneling into acceptance. Lightweight `S<n>` bullets, Given/When/Then preferred for procedural behavior. Also ask about design sources (mockups, wireframes, Figma). Capture anchors and classify as `normative` or `orientation only`.

### Question 8 — Acceptance criteria

Ask: "how will a reviewer know this story is done?" Every bullet: stable `A<n>` id, exactly one independently provable behavior, observable by command/file read/direct observation. Reject vague/compound criteria. Reconcile scenarios before leaving: every normative `S<n>` maps to exactly one `Covers: A<n>`.

### Question 9 — Verification contract

Build `## Verification` with three required subsections:
1. `### Verification Commands` — exact commands or manual actions.
2. `### Test Architecture Plan` — columns: `Row ID | Layer / Scope | Behavior / Acceptance Slice | Owning Suite / File(s) | Boundary Exercised | Assertions / Observability | Fixture / Test Data Strategy | CI Lane / Command | Fallback Plan | Split / Merge Rationale`. Stable `TAP-*` row ids, covers every added/changed test/proof surface, satisfies the TAP quality gate.
3. `### Acceptance Proof Matrix` — columns: `Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail`. Every `A<n>` appears, `Proof Maturity` is `final` or `provisional`.

Add conditional subsections when the story's risk surface requires them:
- `### Surface / Branch Proof Matrix`
- `### Design Sources` and `### Design Element Trace`
- `### Input Boundary Shape Risk`
- `### Fail-open Checks`
- `### Risk Lens Inventory`

### Question 10 — Critical Files

Probe the codebase: extract domain keywords from Purpose and Scope, search, propose candidate files with paths and roles. Mark files to be created as `(new)`.

### Question 11 — Implementation Notes

Ask for execution context: source-inspection focus, smallest likely red-first seam, phases, known constraints, explicit exception if red-first is infeasible.

### Question 12 — Locked Decisions

Ask: "what has been decided, and what alternatives were considered and rejected?" Cross-check against `AGENTS.md` and initiative-level decisions.

### Question 13 — Discovery Notes

Record source-derived facts that prevent rediscovery. If nothing material found: `None identified.`

### Question 14 — Tasks

Derive implementation tasks from the story contract. Each task is a concrete, verifiable unit of work organized under `## Setup & Prerequisites`, `## Core Implementation`, `## Verification & Proof`, and `## Integration & Cleanup`. Each task uses `- [ ] <description>` checkbox format.

### Question 15 — Delta specs

Ask whether the change modifies any behavior that should be captured as delta specs under `specs/`. If yes, walk the operator through ADDED/MODIFIED/REMOVED requirements per capability.

## Story draft

Assemble the change workspace artifacts:

### proposal.md

```md
# Proposal: <change-slug>

## Goal / Context
<from Q2>

## Story Candidates
<!-- Single story — this change is the full scope. -->

## Decisions & Constraints
<!-- Inherited from initiative or decided during planning. -->

## External Resources
<!-- Links to issues, PRs, tickets, design artifacts. -->
```

### story.md

Full story contract matching the `openspec/schemas/story-change/templates/story.md` shape with all answered sections. Do not create `<TODO: ...>` placeholders.

### design.md

Technical design decisions, architecture rationale, and implementation strategy derived from the interview.

### tasks.md

Implementation task checklist with checkbox format, organized by phase.

### specs/**/*.md

Delta specs for each capability domain when provided.

## Validation

Before the checkpoint:

1. Verify the change slug does not collide with any existing workspace under `openspec/changes/` or `openspec/changes/archive/`.
2. Validate the proof contract:
   - `## Actors` has role bullets with at least one `Primary:` actor
   - Every normative `S<n>` scenario has exactly one `Covers: A<n>`, every orientation-only scenario says `Orientation only`
   - Every acceptance bullet starts with `A<n>:`, is atomic, and observable
   - `## Verification` has all required subsections
   - Test Architecture Plan has required columns, stable `TAP-*` row ids, and meets the TAP quality gate
   - Acceptance Proof Matrix has required columns, covers every `A<n>`
   - Every `Proof Maturity` is `final` or `provisional`; provisional rows have non-blank `Open Detail`
   - Conditional subsections present when the story risk surface requires them
   - No `<TODO: ...>` placeholders in any spec section
3. Validate prerequisites resolve to real existing change workspaces or are explicitly external.
4. Validate tasks.md has at least one task per phase that has content.

Abort or continue the interview if validation fails.

## Checkpoint

Show the operator:
- Change workspace path: `<workspace_root>/openspec/changes/<story-slug>/`
- Artifacts to be created: proposal.md, story.md, design.md, tasks.md, specs/**/*.md
- Acceptance/proof validation summary
- The full drafted content of each artifact
- Initiative reference: `<slug>`

**CHECKPOINT**: explicit y/n before writing.

## Collision check

Re-verify that `<workspace_root>/openspec/changes/<story-slug>/` does not exist. If it does, abort with recovery hints.

## Write

1. Create `<workspace_root>/openspec/changes/<story-slug>/`.
2. Write proposal.md, story.md, design.md, tasks.md.
3. Create `specs/` subdirectory if any delta specs exist and write them.
4. Never seed runtime artifacts: progress.md, reviews.md, blocked.md.

## Final response

State:
- Change workspace path created
- Artifacts written
- Validation summary
- Suggested next action: `/openspec-story-plan-converge <initiative> <story-slug>` to converge the plan, or `/openspec-story-plan-review <initiative> <story-slug>` for a single review pass
