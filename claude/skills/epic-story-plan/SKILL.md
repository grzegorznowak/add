---
name: epic-story-plan
description: Interview-driven draft of a new story plan for an existing epic — produces a plan file in ~/.claude/plans/ matching the shape /epic-story-save consumes. Use when you want to add a new story to an epic but don't yet have a plan file to feed into /epic-story-save.
disable-model-invocation: true
argument-hint: '[EPIC="<epic_name>"]'
allowed-tools: Read Grep Glob Write Bash(git status:*) Bash(git log:*)
---

# Epic Story Plan

Draft a new story plan for an existing epic by interviewing the operator through the spec sections `/epic-story-save` consumes (`Purpose`, `Triggering Need`, `Expected Prerequisites`, `Scope`, `Out of Scope`, `Acceptance`, `Verification`, `Discovery Notes`, `Critical Files`, `Implementation Notes`, `Locked Decisions`). The output is a plan file at `~/.claude/plans/<epic>-<story-slug>.md` that already contains the implementation-ready acceptance/proof contract `/epic-story-save` will persist verbatim into the story file and tracker row.

Argument: `$ARGUMENTS` — optional `[EPIC="<epic_name>"]`. If provided, the skill resolves that epic directly. If omitted, the skill lists the available epics under `<cwd>/agent_coordination/epics/` and asks the operator to pick one.

## Important

This command writes exactly one file: `~/.claude/plans/<epic>-<story-slug>.md`, after an explicit checkpoint confirmation. It **never** touches:

- source code (product files, tests, configs)
- the epic's `MASTER.md` tracker or any existing story files
- the `agent_coordination/` directory at all
- plan files other than the one it is writing

`MASTER.md` updates and story-file scaffolding are the job of `/epic-story-save`, which consumes the plan this command produces. Keep the concerns separate.

## Why operator-explicit (arg or menu) selection

`/epic-story-plan` does not auto-infer which epic a new story should live under. The operator explicitly chooses — either by passing `EPIC=<slug>` as an argument or by picking from the menu this skill shows when the arg is absent. The menu is **not** inference: it lists every epic and asks the operator to select.

The reasoning is simple. Creating a new story is a decision about where it belongs. Auto-inferring "the active epic" guesses at that decision, and a wrong guess silently drops a plan file into the wrong epic's namespace — a hassle to catch because the plan file lives in `~/.claude/plans/` and does not immediately reveal which epic it was meant for. Explicit operator choice — arg or menu — eliminates that class of bug while keeping the interaction cheap.

A gentle nudge: if you find yourself picking from the menu in the same session that wrote the implementation of an earlier story, consider opening a fresh session. Planning from a fresh session tends to produce better-scoped stories than planning from the tail of an in-flight implementation context.

## Resolution

1. Parse `$ARGUMENTS` — extract `EPIC` if present.
2. If `EPIC` was provided:
   - Resolve the epic directory as `<cwd>/agent_coordination/epics/<epic>/`.
   - Verify `<epic>/MASTER.md` exists.
   - If missing, abort with: `epic dir not found at <path>; run /epic-plan NAME="<epic>" first to bootstrap it`.
3. If `EPIC` was not provided:
   - List every directory under `<cwd>/agent_coordination/epics/` that contains a `MASTER.md`.
   - For each, show one line: `<slug> — <N stories, M done, last-touched YYYY-MM-DD>`.
   - If the list is empty, abort with: `no epics found under <cwd>/agent_coordination/epics/; run /epic-plan first to bootstrap one`.
   - Ask the operator: `Pick an epic for this story (number or slug):`.
   - Read their choice and set `EPIC` accordingly. Loop until the input resolves to a valid epic.

## Read first

Once the epic is resolved, read the following before the interview starts:

1. The project's `AGENTS.md` first, then `CLAUDE.md` as a fallback. If neither exists, note it: `no AGENTS.md / CLAUDE.md found; recommendations will be generic`.
2. `<epic>/MASTER.md` — the tracker, so the interview can surface existing stories as prerequisite candidates.
3. The most recent existing story file in the epic (highest `Step` number; prefer non-archived). Read it to learn the epic's conventions and tone.
4. `<epic>/CONTRACT.md` if present — anything locked in by the squash step overrides contradictory planning assumptions.

## Source-of-truth hierarchy

1. The project's `AGENTS.md` / `CLAUDE.md` — load-bearing project conventions.
2. `<epic>/CONTRACT.md` — epic-level locked facts (if present).
3. `<epic>/MASTER.md` — tracker state, prerequisite resolution.
4. The conversation with the operator — their stated intent for this specific story.
5. The live codebase — for feasibility, collision detection, and locating Critical Files.

Do not infer identity from filename shape or naming conventions that are not explicitly recorded in `MASTER.md` or the project's conventions file.

## Interview loop

Walk the operator through each of the questions below in order. For every question:

- **Propose a recommended answer with a brief plain-language explanation of the trade-off.**
- **Where it helps ground the choice, include a concrete example, short snippet, or small ASCII diagram.**
- Probe the codebase (via `Read`, `Grep`, `Glob`, `git log`) before asking if the answer can be derived from it.
- **Every question offers two escape hatches the operator may invoke at any point, except for `Acceptance` and `Verification`:**
  - `skip` — use the proposed default for this section and move to the next question.
  - `draft now` — stop asking, jump to `## Draft plan file` and fill in `<TODO: ...>` placeholders for everything that was not answered yet.
- `## Acceptance` and `## Verification` are load-bearing contract sections. Keep interviewing until they are structurally complete. Do not write the plan file with placeholders or missing coverage in either section.
- **Exception:** `skip` / `draft now` are NOT allowed for `## Acceptance` or `## Verification`. The plan file cannot be written until those two sections are structurally complete.

### Question 1 — Story slug and one-line title

Ask the operator for the story's short hyphenated slug (e.g. `refresh-token-issuance`) and a one-line human title. Probe `MASTER.md` for the highest existing `Step` number and report "next free Step would be `NN`" — but do not claim that number. Numbering is `/epic-story-save`'s job; this command only produces the plan file.

### Question 2 — Purpose

Ask: "what user-visible outcome does this story deliver?" Push back on vague phrasing. "Improve X", "refactor Y", "clean up Z" are not Purpose — they describe activity, not outcome. Ask follow-ups until the answer names a concrete observable.

Propose a one-paragraph draft back to the operator and iterate until they accept it.

### Question 3 — Triggering Need

Ask: "why now? what prompted this story?" If the answer is thin ("because it's overdue", "because we need it"), probe `git log` for the last ~50 commits and look for related work, recent bug reports, or incident-like commit messages. Offer the operator concrete triggers you found ("the auth middleware was last touched 6 weeks ago; is that the driver?") and let them confirm or correct.

### Question 4 — Expected Prerequisites

Walk the `MASTER.md` tracker. For each `⚪ TODO`, `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `🔵 IN PR`, or `✅ DONE` row, ask yourself: could this story legitimately depend on that one? Propose candidate prerequisites based on fuzzy keyword match between the domain terms in the operator's Purpose answer and the tracker row titles.

Format: `DEPENDS = 03, 05 (if either: explain why you think so)`. The operator confirms or corrects.

If the proposed prerequisite is not yet `✅ DONE`, flag it — but do not reject. A `⚪ TODO` story legitimately depending on another `⚪ TODO` story is valid, per `docs/epic-conventions.md`.

### Question 5 — Scope and Out of Scope

Ask what is in scope for this story — the work the implementer will actually do. Drive toward atomic: if the operator's Scope reads like two or three independent stories, push back with a split proposal: "this sounds like Story A (the rename) + Story B (the migration) + Story C (the deprecation). Do you want to split? I can help you pick which of those is this story."

Also ask what is deliberately **out of scope**. A non-empty Out of Scope section is a signal of clear thinking; a missing one is a warning.

### Question 6 — Acceptance criteria

Ask: "how will a reviewer know this story is done?" Every acceptance bullet must be checkable by a command, a file read, or a direct observation. Every bullet must start with a stable id (`A1`, `A2`, ...) and cover exactly one independently provable behavior. Reject:

- "works correctly" (not observable)
- "is performant" (no threshold)
- "is clean" (subjective)
- "tests pass" (which tests? on what command?)
- compound bullets that hide multiple independently failing behaviors

Propose observable rewrites: "A1: the existing test suite under `tests/auth/` passes with zero failures when run with `bun test tests/auth/`". Iterate until every bullet names a concrete check, uses an `A<n>` id, and stays atomic.

### Question 7 — Verification contract

Build `## Verification` in two parts:

1. `### Verification Commands`
   - Ask for the exact commands or exact manual/file-read actions a reviewer can run.
   - Confirm any existing test files or named surfaces actually exist when they are claimed as current seams.
   - Build this section so implementation can start red-first after source inspection. Anchor the real owning test/proof surfaces and the focused area the implementer should inspect first.
2. `### Acceptance Proof Matrix`
   - Every acceptance id must have at least one row before the plan can be saved.
   - Required columns: `Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail`
   - `Proof Maturity` must be `final` or `provisional`.
   - `Open Detail` may be blank for `final` rows and is required for `provisional` rows.
   - A row may cover multiple acceptance ids only as an exception when the same proof action and failure signal genuinely cover all of them.

Do not accept vague proof like "run the relevant tests" or fake seams that only validate heavily mocked helpers instead of the real acceptance surface. Provisional rows are allowed, but every acceptance id still needs a row and every provisional row must state what remains undecided. Do not fake precision about the exact first failing command when the current repo facts do not support it; the plan sets the red-first method and proof surfaces, and the implementer chooses the exact first seam after reading sources.

### Question 8 — Critical Files

This is the highest-leverage question in the interview. Actively probe the codebase:

1. Extract 3–5 domain keywords from the Purpose and Scope answers.
2. `Grep` for those keywords across the project.
3. Propose candidate files with line refs: `src/auth/session.ts:142`, `src/auth/refresh.ts (new)`, `tests/auth/session.test.ts:88`.
4. Let the operator confirm, correct, or add.

Do **not** ask the operator to list Critical Files from memory. Ask them to react to your probe results. Operators are much better at "no, not that one — but you missed `src/middleware/auth.ts`" than at "list every file you will touch".

For files the operator says need to be created (that do not yet exist in the codebase), mark them explicitly: `src/auth/refresh.ts (new, does not yet exist)`.

### Question 9 — Implementation Notes

Ask for the approach. Strategy, phases, alternatives considered. Free-form prose; this is the section that preserves design context for the implementer.

Push back if the operator leaves out the "alternatives considered" angle — the Locked Decisions section depends on knowing what was rejected, and those two sections pair tightly.

Require the implementation method to be explicit: after source inspection, implementation starts red-first from the smallest focused seam it can make fail, turns that seam green, then broadens verification. If the operator already knows red-first may be infeasible in some part of the work, require the notes to say that the implementer must record an explicit written exception before proceeding differently.

Also ask whether any acceptance proof rows are expected to remain `provisional` through planning, and if so whether the operator has already identified what implementation discovery will need to resolve. This is not a substitute for the matrix row itself; it is supporting context for the implementer.

### Question 10 — Locked Decisions

Ask: "what has been decided, and what alternatives were considered and rejected?" Cross-check each decision against the project's `AGENTS.md`. If a decision contradicts a stated convention in `AGENTS.md`, flag it and ask the operator whether they want to revise the decision or edit `AGENTS.md` (the latter is a separate task, outside the scope of this command).

### Question 11 — Discovery Notes

Catch-all for code smells, reusable existing code, gotchas, and anything else that came up during the interview that does not fit cleanly elsewhere. Explicitly ask: "did the codebase probes in Q8 surface any gotchas, patterns, or reusable helpers that should land here so the implementer does not have to re-discover them?"

Re-use the grep output from Q8 to populate Discovery Notes with paths and names the operator should preserve verbatim.

## Draft plan file

Assemble the plan file body with section names matching `docs/epic-conventions.md` story-file section names **verbatim**. This gives `/epic-story-save`'s Phase 3 parser an exact-match path through its mapping table (no fuzzy matching required):

```md
# <human title from Q1>

## Purpose
<paragraph from Q2>

## Triggering Need
<paragraph from Q3>

## Expected Prerequisites
<bullets from Q4>

## Scope
<bullets from Q5>

## Out of Scope
<bullets from Q5>

## Acceptance
- A1: <observable bullet from Q6>

## Verification
### Verification Commands
- <concrete command or exact manual/file-read action from Q7>

### Acceptance Proof Matrix
| Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail |
|---|---|---|---|---|---|---|
| A1 | final | file-read | <exact reviewer action> | <exact expected evidence> | <paths / commands / surfaces> | |
| A2 | provisional | automated | <exact reviewer action> | <red/green or equivalent evidence> | <paths / commands / surfaces> | <what remains undecided> |

## Discovery Notes
<code smells, reusable code, gotchas from Q8 and Q11>

## Critical Files
<file paths with line refs from Q8>

## Implementation Notes
<approach / strategy / phases from Q9>

## Locked Decisions
<decisions + alternatives from Q10>
```

For sections where the operator `skip`ped or `draft now`-ed before answering, insert an explicit `<TODO: missing from interview — ...>` placeholder. Do not omit the section.

Exception: `## Acceptance` and `## Verification` must never contain placeholders. If they are incomplete, keep interviewing instead of drafting the file.

## Checkpoint

Show the operator:

- Target path: `~/.claude/plans/<epic>-<story-slug>.md`
- The full drafted plan file content
- Section list with a note next to each indicating whether it came from a real answer, a `skip` default, or a `draft now` placeholder
- Acceptance/proof coverage check: every acceptance id listed, whether it has at least one matrix row, and whether any rows remain `provisional`
- Next-step reminder: "after confirming, the next command is `/epic-story-save EPIC=<epic>` to scaffold the story file and tracker row"

**CHECKPOINT**: explicit y/n before proceeding. If the operator rejects, return to the interview loop at the question they want to revisit. If they accept, continue to the write step.

## Write

1. Resolve the write path: `${HOME}/.claude/plans/<epic>-<story-slug>.md`
2. If a file already exists at that path, abort with: `plan file already exists at <path>; rename or remove it and re-run`.
3. Before writing, validate the acceptance/proof contract:
   - every acceptance bullet begins with `A<n>:`
   - every acceptance bullet is covered by at least one matrix row
   - the matrix uses the required columns
   - every `Proof Maturity` value is `final` or `provisional`
   - every `provisional` row has non-blank `Open Detail`
   - there are no `<TODO: ...>` placeholders in `## Acceptance` or `## Verification`
   If any check fails, abort with a concise explanation and continue the interview rather than writing a malformed plan.
4. `Write` the drafted plan file content to that path.

No other files are created. `MASTER.md` is not touched. No story file is created. The operator's next command produces those.

## Final response

State clearly:

- Path of the written plan file
- Epic slug and story title
- Exact next command to run: `/epic-story-save EPIC=<epic>`
- Note that the operator can review or edit the plan file before running `/epic-story-save`, and that `/epic-story-save` will pick it up from `~/.claude/plans/` by mtime if no `PLAN` arg is passed.

Keep it short — three or four sentences is enough.
