# add — Agentic Driven Development

`add` is a pluggable skill pack for running software delivery through a
repo-local **OpenSpec initiative / change workspace** workflow. The active
commands create and maintain OpenSpec files under `openspec/`, then use fresh
agent sessions for planning, implementation, review, PR handling, feedback, and
archive gates.

Skills are authored once under `claude/skills/` and installed into **Claude
Code**, **Codex**, and **pi** with the runtime installer. The Claude plugin path
loads the same active OpenSpec skills for Claude Code only.

## The workflow model

Long agentic sessions drift: context fills up, earlier constraints become
compressed, and the same session that wrote the code is tempted to approve its
own work. `add` avoids that by making the lifecycle file-backed and
session-bounded.

For Pi users, ADD treats
[`pi-agenticoding`](https://github.com/agenticoding/pi-agenticoding) as a core
building block for getting the most out of these workflows. Its `spawn`,
`notebook`, and `handoff` primitives provide isolated subtasks, durable compact
grounding, and deliberate clean-context handoffs, while ADD's repo-local
OpenSpec files remain the workflow source of truth.

The durable model is:

```text
openspec/
├── initiatives/<initiative-slug>/initiative.md
└── changes/<story-slug>/
    ├── proposal.md
    ├── story.md
    ├── design.md
    ├── tasks.md
    ├── specs/**/*.md
    ├── progress.md      # created by implementation commands
    ├── reviews.md       # created by implementation review / feedback
    └── blocked.md       # existence is an explicit blocker gate
```

- **Initiative** — a durable context file (`initiative.md`) for a body of work:
  goal, constraints, decisions, resources, story candidates, and feedback logs.
- **Change workspace** — one story-sized OpenSpec change under
  `openspec/changes/<story-slug>/` with proposal, story contract, design notes,
  task checklist, and spec deltas.
- **Plan lane** — `story.md`'s `Plan:` header records whether the contract is
  draft, in review, approved, needs changes, or blocked.
- **Implementation status** — `story.md`'s `Status:` header records execution:
  TODO, in progress, in review, in PR, done, or blocked.
- **Runtime evidence** — `progress.md`, `reviews.md`, `tasks.md`, and optional
  `blocked.md` preserve handoff, proof, review findings, PR state, and blockers.

There is no central tracker table in the active workflow. Fresh sessions resume
from the OpenSpec artifacts themselves.

## Lifecycle at a glance

Use `/openspec-next-action` at any point to inspect the current or selected
OpenSpec initiative/change/spec state and get the next recommended command with
reasoning; it is read-only and never performs lifecycle transitions.

1. **Plan an initiative** — `/openspec-initiative-plan` creates
   `openspec/initiatives/<slug>/initiative.md` as the initiative-level planning
   counterpart to `/openspec-story-plan`.
2. **Plan a story-sized change** — `/openspec-story-plan INITIATIVE=<slug>`
   interviews the operator and writes the change workspace planning artifacts.
   It does not seed implementation runtime files.
3. **Converge the plan** — `/openspec-story-plan-review` independently checks
   the story contract, proof matrix, design trace, and repo reality;
   `/openspec-story-plan-resume` repairs planning gaps;
   `/openspec-story-plan-converge` loops fresh review/resume passes until the
   Plan lane is approved, blocked, or stopped.
4. **Implement red-first** — `/openspec-story-claim` claims a plan-approved,
   ready TODO story, including satisfied `## Expected Prerequisites`, writes
   `progress.md`, chooses the smallest credible failing seam, turns it green,
   records proof, and hands off. `/openspec-story-resume` continues in-progress
   work or applies review/PR-change feedback after the story is back in
   `🔄 IN PROGRESS`.
5. **Review independently** — `/openspec-story-review` is read-only for product
   code. It writes `reviews.md` and the `Status:` header, approving only when the
   implementation, tests, tasks, and OpenSpec contract line up.
6. **Converge implementation** — `/openspec-story-converge` orchestrates fresh
   claim/resume/review sessions for one change until local review approves,
   a blocker appears, no progress is made, or the cycle budget ends.
7. **Optional PR stage** — `/openspec-story-pr` creates, attaches, or refreshes a
   GitHub PR and records the durable PR state in `progress.md`. Merged PR
   evidence moves the story to `✅ DONE`; requested changes route back to resume.
8. **Absorb feedback** — `/openspec-feedback` routes PR, reviewer, tool, or
   operator feedback to the initiative log, plan review log, implementation
   review log, story candidates, or initiative-level decisions without touching
   product code.
9. **Archive completed changes** — `/openspec-archive` preflights DONE status,
   task completion, review approval, blocker absence, and PR/no-PR evidence,
   then delegates spec sync and the workspace move to OpenSpec's built-in
   `/opsx:archive <story-slug>` command.

See [`docs/openspec-lifecycle.md`](docs/openspec-lifecycle.md) for the full
ASCII state machine and command authority table, and
[`docs/openspec-conventions.md`](docs/openspec-conventions.md) for artifact
schemas, proof matrices, Debt Friction, and runtime section conventions.

## Commands

### OpenSpec workflow

| Command | Responsibility |
|---|---|
| `/openspec-initiative-plan` | Plan one OpenSpec initiative file under `openspec/initiatives/<slug>/`. |
| `/openspec-next-action` | Inspect current or selected OpenSpec state and recommend the next workflow command. |
| `/openspec-story-plan` | Create a new change workspace with proposal, story, design, tasks, and delta specs. |
| `/openspec-story-plan-review` | Independently review a change workspace's planning contract and Plan lane. |
| `/openspec-story-plan-resume` | Repair planning artifacts after feedback or incomplete sections. |
| `/openspec-story-plan-converge` | Loop fresh plan-review and plan-resume passes until the Plan lane resolves. |
| `/openspec-story-claim` | Claim one approved TODO story and begin red-first implementation. |
| `/openspec-story-resume` | Continue implementation, resolve blockers, or address review/PR feedback. |
| `/openspec-story-review` | Independently review implementation and update `reviews.md` plus `story.md → Status:`. |
| `/openspec-story-converge` | Loop fresh claim/resume/review passes until local implementation approval or stop. |
| `/openspec-story-pr` | Manage the optional GitHub PR stage and durable `progress.md → ## PR State`. |
| `/openspec-feedback` | Classify and absorb structured feedback into the right OpenSpec artifacts. |
| `/openspec-archive` | Preflight completion gates, then delegate spec sync and archive move to `/opsx:archive`. |

### Utilities

| Command | Responsibility |
|---|---|
| `/grillme` | Relentless interview about a plan or design until shared understanding. |
| `/memorize` | Reflect on session friction and propose durable doc/instruction patches. |
| `/merge-conflict-analysis` | Analyze merge conflicts by tracing changes back to PR/Jira/ticket-backed intent. |

The previous `epic-*` command family is retained only for provenance under
[`archive/skills/legacy-epic/`](archive/skills/legacy-epic/) and is not installed
by the active plugin or runtime installers.

## Install

There are two supported install paths:

1. **Claude Code plugin** — Claude-only, via the plugin marketplace or
   `--plugin-dir`.
2. **Runtime installer** — shell scripts in this repo. Installs Claude skills by
   symlink and compiles generated Codex/pi skills from `claude/skills/`.

### Runtime installer

```bash
git clone https://github.com/grzegorznowak/add.git ~/.local/share/add
~/.local/share/add/scripts/install.sh
```

With no arguments on a TTY, the installer opens an interactive wizard:

1. choose agents: Claude Code, Codex, pi, or all three;
2. choose user-level scope or project-level scope where supported;
3. confirm before filesystem changes.

Install targets:

- `claude/skills/<name>/` → `~/.claude/skills/<name>`
- `claude/skills/<name>/` → `<project>/.claude/skills/<name>`
- generated Codex skill → `~/.codex/skills/<snake_name>/`
- generated Codex skill → `<project>/.agents/skills/<snake_name>/`
- generated pi skill → `~/.pi/agent/skills/<name>/`

Pi context layer: when using generated pi skills, install
[`pi-agenticoding`](https://github.com/agenticoding/pi-agenticoding) separately
(`pi install npm:pi-agenticoding`). It supplies the `spawn`, `notebook`, and
`handoff` tools that make ADD's long OpenSpec loops practical; the ADD installer
only installs the ADD skill files.

Codex and pi outputs are generated at install time from the canonical Claude
skills. There is no committed `codex/skills/` source tree. Claude installs are
symlink-based and refuse to clobber non-symlink targets unless `--force` is
passed. Generated Codex/pi installers refuse to overwrite modified generated
files unless `--force` is passed.

### Non-interactive install

```bash
~/.local/share/add/scripts/install.sh \
  --yes \
  --agents all \
  --project /workspaces/myproject
```

Flags:

- `--agents claude|codex|pi|both|all` — selected runtimes. `both` means
  Claude+Codex; `all` includes pi.
- `--project <path>` — also install into project-level skill roots where the
  runtime supports them.
- `--yes` — skip confirmation; required for non-TTY installs that mutate files.
- `--force` — overwrite non-symlink Claude targets and modified generated
  Codex/pi files.
- `--prune-unsupported` — explicitly remove recognized unsupported workflow
  skills from selected install targets, including archived legacy commands and
  renamed command entries.
- `--dry-run` — show planned writes/prunes without changing files.

Pruning is never automatic. Use the correctly spelled `--prune-unsupported`
only when you intentionally want stale installed unsupported workflow skills
removed. The prune path is conservative: Claude removes only recognized
unsupported symlinks that point into this repo, while Codex/pi remove exact
recognized generated directories only after `SKILL.md` frontmatter matches the
expected unsupported name.

### Plugin install (Claude Code only)

```bash
# 1. Register the marketplace once
/plugin marketplace add grzegorznowak/add

# 2. Install the plugin
/plugin install add@grzegorznowak-add
```

Or load a clone for the current Claude session only:

```bash
git clone https://github.com/grzegorznowak/add.git ~/.local/share/add
claude --plugin-dir ~/.local/share/add
```

The plugin path does not install Codex or pi skills. Use `scripts/install.sh
--agents codex`, `--agents pi`, or `--agents all` when you want generated
runtime skills.

### opencode agents

This repo also ships opencode subagents in `.opencode/agent/`:

```bash
# User-level: ~/.config/opencode/agent/
~/.local/share/add/scripts/install-opencode-agents.sh

# Project-level: <project>/.opencode/agent/
~/.local/share/add/scripts/install-opencode-agents.sh --project /workspaces/myproject
```

Restart opencode or run `/reload` after installing.

## Updating

Claude symlinks update by `git pull`. Generated Codex/pi skills should be
recompiled after pulling changes:

```bash
cd ~/.local/share/add && git pull
scripts/install.sh --yes --agents all
```

If you previously installed the archived legacy workflow or the renamed
`/openspec-epic-plan` command, prune once explicitly:

```bash
scripts/install.sh --yes --agents all --prune-unsupported
```

## Uninstall

```bash
~/.local/share/add/scripts/uninstall.sh
```

Only symlinks pointing at this repo are removed. Anything you authored yourself
is left untouched. Generated Codex/pi directories are real files and can be
removed manually, or pruned for recognized unsupported workflow names during a
runtime install with `--prune-unsupported`.

## Contributing

To add or update a command, read
[`docs/adding-a-command.md`](docs/adding-a-command.md). Workflow commands should
fit the OpenSpec lifecycle and artifact conventions above. The short version:
write the canonical Claude Skill at `claude/skills/<name>/SKILL.md`, add a
`pi-fragments/<name>.md` fragment only when pi needs runtime-specific
instructions, then run `bash scripts/lint.sh`.

## Why "add"

`add` is short for **Agentic Driven Development** — the workflow this repo
encodes. It is also the smallest possible command to type before invoking
something useful, which is the point of a personal-tool repo.

## License

[MIT](LICENSE).
