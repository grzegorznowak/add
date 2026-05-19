# Adding a New Command

This repo holds **paired** commands: every workflow ships as both a Claude
Code Skill and a Codex skill so the same operation works on whichever
runtime the operator is using. Adding a command means writing both halves
and getting `scripts/lint.sh` to pass.

## When to add one

Add a command when you have an agentic workflow you keep re-typing or
re-explaining across sessions, and the workflow is structured enough to
encode as deterministic prose. If you find yourself hand-walking an agent
through the same checkpoints twice, that's the signal.

Don't add a command for one-off tasks, exploratory work, or anything where
the steps will change every time you run it. Skills are for **repeatable
process**, not for thinking out loud.

## File checklist

A new command called `<name>` (using the Claude hyphenated form) requires:

1. `claude/skills/<name>/SKILL.md` — Anthropic Skill format
2. `codex/skills/<name_with_underscores>/SKILL.md` — Codex skill format
3. `codex/skills/<name_with_underscores>/agents/openai.yaml` — Codex policy
   file (`allow_implicit_invocation: false`)

All three files. No exceptions, except for the explicit known-singletons
list in `scripts/lint.sh` (currently just `memorize`, which is Codex-only).

## Claude Skill template

```md
---
name: <name>
description: <one-sentence description that ends with "Use when ...">
disable-model-invocation: true
argument-hint: "<arg-shape>"
allowed-tools: Read Edit Write Grep Glob Bash
---

# <Title>

<one paragraph summary>

Argument: `$ARGUMENTS` — <what the user passes>.

## Workflow
1. ...
2. ...

## ...
```

### Frontmatter rules

- **`name:`** must match the directory name (`claude/skills/<name>/`).
  `lint.sh` enforces this.
- **`description:`** is read by Claude when deciding whether to surface the
  Skill. It must describe both **what** the Skill does and **when** to use
  it. Slash commands like `/<name>` will discover it via the description.
- **`disable-model-invocation: true`** is the default for everything in this
  repo. These are operator-driven workflows with explicit checkpoints, not
  background capabilities Claude should auto-launch.
- **`argument-hint:`** is the hint shown in the `/` autocomplete picker.
  Mirror the Codex side's documented argument shape so the two stay aligned.
- **`allowed-tools:`** lists only what the Skill actually uses. Be
  conservative — narrow `Bash(...)` patterns are fine and reduce permission
  prompts. Read-only commands should not list `Edit` / `Write`.

### Body conventions

- Lead with a one-paragraph summary followed by `Argument:` and `## Workflow`.
- Use `## Phase N — <name>` headings for multi-step workflows. The lint
  script checks that the Claude and Codex sides have the same set of phase
  headings.
- Use explicit checkpoints (`**CHECKPOINT N**`) for any irreversible or
  high-blast-radius action.
- State the source-of-truth hierarchy explicitly. The codebase wins over
  documents; documents win over assumptions.
- For commands that govern implementation work, encode proof-first planning and
  red-first execution explicitly. Do not leave test-first sequencing implicit;
  require a written exception path when red-first is infeasible.
- For looper/orchestrator commands, preserve delegated command ownership: run
  fresh sessions, pass neutral operational context plus sourced Research Board
  entries only, document hard stops and no-progress gates, and avoid persuasive
  verdict framing. If they pass a session Research Board, require exact source
  anchors, treat it as orientation only, make the looper responsible for keeping
  it relevant, tell executor sessions to verify present facts with direct
  reads/search against cited anchors before rerunning expensive research, require
  board-refresh signals when provided entries do not verify, ask before
  compacting it, and never persist it.
- End with a `## Final response` section describing what the operator
  should see when the command finishes.

## Codex skill template

Codex discovers skills from `.agents/skills/` per project root. Each skill is
a directory with two files:

```
codex/skills/<name>/
├── SKILL.md
└── agents/
    └── openai.yaml
```

`SKILL.md` template:

```md
---
name: <name>
description: <one-sentence description>
---

<Title>: $ARG1 / $ARG2

<one paragraph summary>

Treat `$ARG1` as ...

## Workflow
1. ...
```

`agents/openai.yaml`:

```yaml
policy:
  allow_implicit_invocation: false
```

### Frontmatter rules

- **`name:`** must match the directory name (`codex/skills/<name>/`).
  `lint.sh` enforces this.
- **`description:`** the short Codex form (existing convention is shorter
  than the Claude side; lint does not enforce parity).

### Body conventions

- Same phase headings as the Claude side (when present). The lint script
  enforces phase-heading parity between the two sides.
- Use `$ARG1`, `$ARG2`, etc. for argument substitution instead of
  `$ARGUMENTS`.
- If the skill takes arguments, explain them near the top of the body in the
  same concrete style you expect the operator to invoke.
- Use Codex's name where Claude says "Claude" (e.g. "Codex fresh session").

## Pairing the two

The base name normalization is hyphen ↔ underscore: a Claude Skill named
`epic-story-claim` pairs with a Codex skill named `epic_story_claim`. The lint
script does this conversion automatically.

Singletons (Codex-only or Claude-only) must be added to the relevant
`SINGLETONS_*_ONLY` array in `scripts/lint.sh`. Don't ship a singleton
silently — the explicit list is the documentation.

## Lint and ship

```bash
bash scripts/lint.sh             # validate everything
```

If lint exits 0, you can commit. If not, fix the reported items — they are
exactly the conditions a reviewer would call out.

For additional cross-runtime conventions (lifecycle, MASTER.md schema,
story file shapes), see [`epic-lifecycle.md`](epic-lifecycle.md) and
[`epic-conventions.md`](epic-conventions.md).
