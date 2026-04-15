---
description: Interview-driven bootstrap for a new epic — produces a MASTER.md skeleton under agent_coordination/epics/<slug>/.
argument-hint: [NAME="<slug>"]
---

# Epic Plan: $NAME

Bootstrap a new epic for this project by interviewing the operator through the epic's purpose, scope, constraints, and rough story roadmap — then write a clean `MASTER.md` skeleton to `agent_coordination/epics/<slug>/MASTER.md`. No stories are created here; `$epic_plan` only produces the coordination file that subsequent `$epic_story_plan` → `$epic_new_story` invocations append to.

Treat `$NAME` as an optional slug hint. If present, use it as the initial slug candidate and still confirm the human title during the interview. If absent, the very first interview question is "what should we call this epic?".

## Important

This command writes exactly one file: `<cwd>/agent_coordination/epics/<slug>/MASTER.md`, after an explicit checkpoint confirmation. It **never** touches:

- source code (product files, tests, configs)
- existing epic directories or their contents
- the `docs/` folder or any other repo metadata

If the resolved epic directory already exists (with or without a `MASTER.md`), the command aborts without writing. The operator has to remove the directory or pick a different slug.

## Preparation

1. Resolve the project root as `<cwd>`. Do not search parent dirs.
2. Resolve the coordination dir as `<cwd>/agent_coordination/epics/`. If it does not exist, abort with the hint that the operator should `mkdir -p agent_coordination/epics` themselves — this is a deliberate check that they are in the right project root.
3. Read the project's conventions file for context:
   - Try `<cwd>/AGENTS.md` first; if present, read it fully.
   - Otherwise try `<cwd>/CLAUDE.md`.
   - If neither exists, note it in the preparation output: `no AGENTS.md / CLAUDE.md found; recommendations will be generic`.
4. Probe existing epics under `<cwd>/agent_coordination/epics/` for naming context and collision checking. Summarize as `found N existing epics: <slug1>, <slug2>, ...` or `no existing epics` in the preparation output.
5. Use `git status` and a short `git log --oneline -20` to get a sense of what recent work in the project has been about — useful for proposing Goal/Context prose later.

## Source-of-truth hierarchy

1. The project's `AGENTS.md` / `CLAUDE.md` — load-bearing conventions the epic will inherit.
2. The conversation with the operator — their stated intent, in their words.
3. The live codebase — for feasibility, naming collisions, and recent-activity context.

Do not invent domain concepts the operator did not state. If a question cannot be answered from the three sources above, ask the operator.

## Interview loop

Walk the operator through each of the sections below in order. For every question:

- **Propose a recommended answer with a brief plain-language explanation of the trade-off.**
- **Where it helps ground the choice, include a concrete example, short snippet, or small ASCII diagram.**
- Probe the codebase before asking if the answer can be derived from it.
- **Every question offers two escape hatches the operator may invoke at any point:**
  - `skip` — use the proposed default for this section and move to the next question.
  - `draft now` — stop asking, jump to `## Draft MASTER.md` and fill in defaults for everything that was not answered yet.

### Question 1 — Epic slug and human title

(Skip this question if `$NAME` was passed — use it as the slug and confirm the human title in the drafting step.)

Ask the operator for:

- A short hyphenated slug (directory name) — e.g. `auth-service`, `telemetry-v2`, `cli-ergonomics`.
- A human-readable title — e.g. "Auth service refactor", "Telemetry v2 pipeline".

Probe the existing epic list for collisions. If the proposed slug matches an existing epic, push back with: "epic `<slug>` already exists; pick a different slug or run `$epic_story_plan EPIC=<slug>` to add stories to the existing epic."

### Question 2 — Goal / Context prose

Ask the operator for the one-paragraph reason the epic exists. Probe their initial answer with follow-ups: who benefits? what is the user-visible outcome? what does "done" look like at the epic level?

Propose a 3–5 sentence draft back to them, combining their answers with any relevant context you found in `AGENTS.md` or `git log`. Iterate until they are happy.

### Question 3 — Rough scope

Ask what kinds of stories will live under this epic. This is prose, not a tracker row count. Captured directly into the Goal/Context section of `MASTER.md`.

Important: **do not** populate the tracker table with these. They become `$epic_story_plan` invocations later, one per story. Tell the operator this explicitly so they understand the separation.

### Question 4 — Constraints and non-goals

Ask about epic-level locked-in decisions that every story will inherit:

- Technology stack constraints (languages, frameworks, versions)
- Compatibility promises (backwards-compat, API stability, migration constraints)
- Timeline / deadline constraints
- Stakeholders whose sign-off is required

Also ask what is **explicitly not** part of this epic — the "non-goals" list. Captured as a short prose section under Goal/Context.

### Question 5 — Risks and unknowns

Ask what could invalidate the epic's direction or scope. What you do not yet know that could change everything. What assumptions the operator is making.

Record as a short bullet list under Goal/Context. No need to resolve them here — the point is visibility, not a decision tree.

### Question 6 — Story roadmap sketch

Ask the operator for a rough list of the stories they expect to create under this epic. Informal. Three to ten bullets is typical. One-line per bullet.

Captured as a **prose list** in Goal/Context, clearly labeled as a roadmap sketch and **not** as tracker rows. Remind the operator: "these become `$epic_story_plan` invocations one at a time; the tracker table stays empty until then."

## Draft MASTER.md

Assemble the body to match the shape in `docs/epic-conventions.md` (Required sections: Header, Goal / Context, Legend, Story tracker):

```md
# Epic: <Human Title>

## Goal / Context

<3–5 sentence Goal/Context prose from Q2>

### Scope

<prose from Q3>

### Constraints and non-goals

<prose from Q4>

### Risks / unknowns

- <bullet from Q5>
- <bullet from Q5>

### Story roadmap sketch

(Informal list of planned stories — these become `$epic_story_plan` invocations later, one per story. The tracker table below stays empty until a story is actually drafted.)

- <bullet from Q6>
- <bullet from Q6>

## Legend

- ⚪ TODO
- 🔄 IN PROGRESS
- 🟣 IN REVIEW
- 🔵 IN PR
- ✅ DONE
- ⛔ BLOCKED

## Story tracker

| Step | Status | Deliverable | Depends | Spec |
|-----:|--------|------------|---------|------|
```

The tracker has a header row and a separator row only — zero data rows. Match the five-column standard even though the epic starts empty; future story creation will slot into those columns.

## Checkpoint

Show the operator the full drafted `MASTER.md` content, plus a short header line stating:

- Target path: `<cwd>/agent_coordination/epics/<slug>/MASTER.md`
- Slug source: passed as `$NAME` / chosen during interview
- Questions answered / skipped / defaulted

**CHECKPOINT**: explicit y/n before proceeding. If the operator rejects, return to the interview loop at the question they want to revisit. If they accept, continue to the collision check.

## Collision check

Re-verify (at write-time, not preparation-time) that `<cwd>/agent_coordination/epics/<slug>/` does not exist. This is a second check in case the filesystem changed during the interview.

If the directory exists, abort with:

```
abort: epic dir already exists at agent_coordination/epics/<slug>/
  (<summary of what's inside — MASTER.md presence, story count, mtime>)

$epic_plan does not overwrite existing epics. If you meant to:
  - add stories to this epic → $epic_story_plan EPIC=<slug>
  - restart from scratch     → rm -rf agent_coordination/epics/<slug>/
  - use a different slug     → re-run $epic_plan NAME="<different-slug>"
```

## Write

1. Create the epic directory with `mkdir -p <cwd>/agent_coordination/epics/<slug>/`
2. Write the drafted `MASTER.md` content to `<cwd>/agent_coordination/epics/<slug>/MASTER.md`

No other files are created. No tracker rows, no story files, no `CONTRACT.md`, no `archive/`. Those are the job of other commands.

## Final response

State clearly:

- Path of the created file: `<cwd>/agent_coordination/epics/<slug>/MASTER.md`
- Epic slug and human title
- Suggested next step: `$epic_story_plan EPIC=<slug>` to draft the first story for this epic

Keep it short — two or three sentences is enough. The operator can read the file themselves if they want the details.
