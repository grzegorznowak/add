---
name: openspec-initiative-plan
description: Interview-driven OpenSpec initiative planning — creates openspec/initiatives/<slug>/initiative.md with goal, context, story candidates, decisions, constraints, and external resources. Use when starting a new body of work that needs an OpenSpec-backed initiative before any change workspaces can be drafted.
disable-model-invocation: true
argument-hint: '[SLUG="<slug>"]'
allowed-tools: Read Grep Glob Write Bash(git status:*) Bash(git log:*)
---

# OpenSpec Initiative Plan

Plan a new OpenSpec-backed initiative by interviewing the operator through purpose, scope, constraints, and rough story roadmap — then write `openspec/initiatives/<slug>/initiative.md`. No change workspaces are created here; `/openspec-initiative-plan` only produces the initiative file that subsequent `/openspec-story-plan` invocations read.

Argument: `$ARGUMENTS` — optional `[SLUG="<slug>"]`. If provided, the interview uses it as the initial slug candidate and may still confirm or tweak it. If omitted, the first interview question asks for the slug.

## Important

This command writes exactly one file: `<workspace_root>/openspec/initiatives/<slug>/initiative.md`, after an explicit checkpoint confirmation. It never touches:
- source code (product files, tests, configs)
- existing initiative directories or their contents
- change workspaces under `openspec/changes/`
- non-OpenSpec coordination artifacts outside `openspec/`

If the resolved initiative directory already exists (with or without an `initiative.md`), the command aborts without writing.

## Preparation

1. Resolve `<workspace_root>` = `<cwd>`. Do not search parent dirs.
2. Verify `<workspace_root>/openspec/` exists — the operator must `mkdir -p openspec/initiatives` themselves if it does not. Abort with a hint if absent.
3. Read `<workspace_root>/AGENTS.md` first, then `<workspace_root>/CLAUDE.md` as fallback. If neither exists, note: `no AGENTS.md / CLAUDE.md found; recommendations will be generic`.
4. Probe existing initiatives under `<workspace_root>/openspec/initiatives/` for naming context and collision checking. Summarize.
5. Use `git status` and a short `git log --oneline -20` for recent-activity context.

## Source-of-truth hierarchy

1. `AGENTS.md` / `CLAUDE.md` — load-bearing conventions the initiative will inherit.
2. The conversation with the operator — their stated intent, in their words.
3. The live codebase — for feasibility, naming collisions, and recent-activity context.

## Interview loop

Walk the operator through each section below in order. For every question:
- Propose a recommended answer with a brief plain-language explanation of the trade-off.
- Include a concrete example, short snippet, or small ASCII diagram when it clarifies the choice.
- Probe the codebase before asking if the answer can be derived from it.
- Every question offers two escape hatches the operator may invoke at any point:
  - `skip` — use the proposed default for this section and move to the next question.
  - `draft now` — stop asking, jump to `## Draft initiative.md` and fill in defaults for everything not yet answered.

### Question 1 — Initiative slug and human title

(Skip if `SLUG` was passed as an argument — validate it against the slug rule below, then use it as the slug and confirm the human title in the drafting step.)

Ask for:
- A short hyphenated slug (directory name) — e.g. `auth-service`, `telemetry-v2`. Must match `[a-z0-9][a-z0-9-]+` — reject slugs with path separators (`/`, `..`), spaces, or non-slug characters.
- A human-readable title — e.g. "Auth service refactor", "Telemetry v2 pipeline".

Probe existing initiatives for collisions. If the proposed slug matches an existing one, push back.

### Question 2 — Source of truth

Ask: "is the primary source of truth for this initiative internal (this codebase's specs and docs) or external (a ticket system, design doc, product spec)?" Record as `source_of_truth: internal | external` in the header. This flags whether external resources should be treated as primary authority.

### Question 3 — Goal / Context prose

Ask for the one-paragraph reason the initiative exists. Probe: who benefits? what is the user-visible outcome? what does "done" look like at the initiative level? Propose a 3–5 sentence draft.

### Question 4 — Rough story candidates

Ask what kinds of change workspaces will live under this initiative. This is prose, not a numbered tracker. Captured in `## Story Candidates`. These become `/openspec-story-plan` invocations later.

### Question 5 — Decisions & Constraints

Ask about initiative-level locked-in decisions that every story will inherit: technology stack constraints, compatibility promises, timeline/deadline constraints, stakeholders whose sign-off is required. Also ask what is explicitly NOT part of this initiative.

### Question 6 — External Resources

Ask for links to issues, PRs, tickets, design docs, or other artifacts that inform this initiative. These are links only; never summarize or quote external ticket text.

### Question 7 — Risks and unknowns

Ask what could invalidate the initiative's direction or scope. Record as bullets under `## Goal / Context`.

## Draft initiative.md

Assemble:

```md
# <Human Title>

source_of_truth: <internal | external>

## Goal / Context
<3–5 sentence prose from Q3>

### Risks / unknowns
- <bullet from Q7>

## Story Candidates
<prose from Q4 — informal list; these become /openspec-story-plan invocations>

## Decisions & Constraints
<prose from Q5>

## External Resources
- <optional label>: <url>
```

Do not seed `## Feedback-Derived Story Candidates` or `## Feedback-Derived Decisions` — those are created by `/openspec-feedback` on first use.

## Checkpoint

Show the full drafted content plus:
- Target path: `<workspace_root>/openspec/initiatives/<slug>/initiative.md`
- Slug source: passed as arg / chosen during interview
- Questions answered / skipped / defaulted

**CHECKPOINT**: explicit y/n before proceeding.

## Collision check

Re-verify that `<workspace_root>/openspec/initiatives/<slug>/` does not exist. If it does, abort with recovery hints.

## Write

1. Create the initiative directory with `mkdir -p <workspace_root>/openspec/initiatives/<slug>/`.
2. Write the drafted content to `initiative.md`.

## Final response

State:
- Path of the created file
- Initiative slug and human title
- Source of truth setting

Suggested next action: `/openspec-story-plan INITIATIVE=<slug>` to create the first change workspace
