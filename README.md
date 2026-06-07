# add — Agentic Driven Development

A personal, pluggable collection of agent skills for managing software work via
the **epic / story** lifecycle. Authored once, installed into **Claude
Code**, **Codex**, and **pi** with one command.

## Why this works

Long agentic sessions drift. The context window fills up, the model starts
hallucinating file paths, earlier instructions get compressed away, and a
single bad decision cascades because the agent never gets a clean slate.

`add` sidesteps this by treating the workflow as a **state machine where each
transition is a fresh session**:

- **File-based state, not memory.** Status lives in `MASTER.md` tracker rows
  and structured story files — not in conversation history. Any session can
  pick up where the last one left off by reading the coordination files.
- **One command, one job, one session.** `/epic-story-plan` only plans.
  `/epic-story-claim` only implements. `/epic-story-review` only reviews — and
  explicitly warns against reviewing in the same session that wrote the code,
  because the same context that produced the work will rationalize it rather
  than scrutinize it.
- **Structured handoff between sessions.** Each implementation session writes
  `## Session Handoff` with what changed, what's left, and the exact next
  step. The next fresh session reads that instead of inheriting a stale
  context window.
- **TDD is a planning constraint, not an implementation afterthought.**
   `/epic-story-plan` requires a verification proof matrix and a Test
   Architecture Plan — mapping every acceptance criterion to a concrete proof
   seam, owning test layer/file, assertion/observable signal, fixture strategy,
   fallback plan, and CI lane — before the story can leave `⚪ TODO`. By the time `/epic-story-claim` starts writing
   code, the question is not "should we test this?" but "which planned failing
   seam do we turn green first, and where does that proof belong in the suite?"

- **Scenarios funnel into acceptance.** Modern stories capture lightweight
  actor roles and concrete behavior examples. Scenarios are not a parallel
  requirements list: a normative example maps to an acceptance id, and that
  acceptance id maps to verification evidence.

- **A rigid plan eliminates improvisation.** The story spec is an engineering
  blueprint, not a suggestion. Implementation has no room to drift because
  every behavior is pinned to an acceptance ID and a proof seam.
  `/epic-story-review` scrutinizes the implementation against that blueprint —
  not against a vague notion of "code quality" — which makes hallucinated or
  unexpected results immediately visible as contract violations.

- **The system improves itself.** `/memorize` closes the feedback loop — at
  the end of a session the agent reflects on what was hard to understand,
  rates friction points, and proposes patches to `AGENTS.md` or docs so the
  next session starts with better context. `/epic-squash` does the same at the
  story level, consolidating finished specs into `CONTRACT.md`. Both prevent
  future sessions from re-learning what a past session already figured out.

The result: each agent run stays small, focused, and verifiable. The
coordination files accumulate the real state, not the conversation.

The entire system is fourteen skills and a handful of markdown files — no
framework, no service orchestrator, no configuration to tune. You learn the
lifecycle once and the commands do the rest.

## What this gives you

Twelve coordinated workflow commands plus two small utilities:

| Command | What it does |
|---|---|
| `/epic-plan` | Bootstrap a new epic via guided interview. Produces `MASTER.md`. |
| `/epic-story-plan` | Plan and publish a new `⚪ TODO` story with actors, scenario examples, acceptance criteria, proof matrix, and Test Architecture Plan. |
| `/epic-story-plan-review` | Review a `⚪ TODO` story's plan against the live repo before claiming. |
| `/epic-story-plan-converge` | Loop fresh plan-review and plan-resume sessions for one `⚪ TODO` story until approved, blocked, or stopped; carries session-only sourced research forward. |
| `/epic-story-claim` | Claim an unclaimed story, find the smallest failing seam, and execute red-first. |
| `/epic-story-resume` | Resume an in-progress story or one with requested PR changes. |
| `/epic-story-review` | Review a story's implementation against its spec. Records the verdict. |
| `/epic-story-converge` | Loop fresh claim/resume/review sessions for one story until local implementation approval, DONE, blocked, or stopped; carries session-only sourced research forward. |
| `/epic-story-pr` | Open or attach a GitHub PR with a product-focused body. |
| `/epic-feedback` | Absorb CURe, PR, or reviewer feedback into story edits, review rework, story candidates, or epic notes. |
| `/epic-pr` | Open or refresh an epic-level GitHub PR from the contract and current DONE stories. |
| `/epic-squash` | Merge all `DONE` stories into `CONTRACT.md` and archive them. |
| `/grillme` | Relentless interview about a plan or design until shared understanding. |
| `/memorize` | Reflect on session friction and propose doc patches for future sessions. |

The commands share a single status lifecycle and a single set of conventions for
the coordination files they read and write. See
[`docs/epic-lifecycle.md`](docs/epic-lifecycle.md) and
[`docs/epic-conventions.md`](docs/epic-conventions.md).

## Install

There are two main skill installation paths, and they coexist cleanly:

1. **Claude Code plugin** — for users who only want the Claude side, via the
   marketplace or `--plugin-dir`. See [Plugin install](#plugin-install-claude-code-only).
2. **Runtime installer** — the custom shell script in this repo. Installs
   Claude skills by symlink and compiles generated Codex/pi skills from the
   canonical `claude/skills/` source, user-level or project-level where the
   runtime supports it. Required if you want Codex or pi skills.

### Runtime Installer

```bash
git clone https://github.com/grzegorznowak/add.git ~/.local/share/add
~/.local/share/add/scripts/install.sh
```

Run with no arguments on a TTY and the installer enters an interactive wizard
that asks:

1. Which agents to install for: Claude Code, Codex, pi, or all three
2. User-level vs project-level scope
3. A confirmation screen before any filesystem changes

The installer writes to one or more of these locations:

- `claude/skills/<name>/` -> `~/.claude/skills/<name>` (Claude user-level symlink)
- `claude/skills/<name>/` -> `<project>/.claude/skills/<name>` (Claude project symlink)
- generated Codex skill -> `~/.codex/skills/<snake_name>/` (Codex user-level)
- generated Codex skill -> `<project>/.agents/skills/<snake_name>/` (Codex project)
- generated pi skill -> `~/.pi/agent/skills/<name>/` (pi user-level)

Codex and pi outputs are generated from `claude/skills/` at install time; there
is no committed `codex/skills/` source tree to maintain. Claude installs remain
symlink-based and refuse to clobber non-symlink targets unless you pass
`--force`. Generated Codex/pi installers also refuse to overwrite modified
existing `SKILL.md` or `agents/openai.yaml` files unless `--force` is set.

### Non-Interactive Install

```bash
~/.local/share/add/scripts/install.sh \
  --yes \
  --agents all \
  --project /workspaces/myproject
```

Flags:

- `--agents claude|codex|pi|both|all` — which runtimes (default: `both`, meaning Claude+Codex; `all` includes pi)
- `--project <path>` — also install into `<path>/.claude/skills/` and
  `<path>/.agents/skills/` for runtimes with project-level skill roots
- `--yes` — skip the confirmation prompt; required for non-TTY installs that mutate files
- `--force` — overwrite non-symlink Claude targets and modified generated Codex/pi files
- `--dry-run` — show what would happen, change nothing

### opencode Agents

This repo also ships opencode subagents in `.opencode/agent/`. Install them
with the small companion script:

```bash
# User-level: ~/.config/opencode/agent/
~/.local/share/add/scripts/install-opencode-agents.sh

# Project-level: <project>/.opencode/agent/
~/.local/share/add/scripts/install-opencode-agents.sh --project /workspaces/myproject
```

Restart opencode or run `/reload` after installing.

### Plugin Install (Claude Code Only)

If you only use Claude Code and do not need the Codex or pi side, install via the
plugin marketplace. The repo ships `.claude-plugin/plugin.json` and a
`marketplace.json` manifest.

```bash
# 1. Register the marketplace (once)
/plugin marketplace add grzegorznowak/add

# 2. Install the plugin
/plugin install add@grzegorznowak-add
```

Alternatively, clone and point Claude at the repo directly:

```bash
git clone https://github.com/grzegorznowak/add.git ~/.local/share/add
claude --plugin-dir ~/.local/share/add
```

The `--plugin-dir` flag loads skills for the current session only.

The Codex and pi skills are not installed by either plugin path. Use
`scripts/install.sh --agents codex`, `--agents pi`, or `--agents all` if you
want to add generated runtime skills later.

## Updating

Claude symlinks update by pull. Generated Codex/pi skills should be recompiled
after pulling changes:

```bash
cd ~/.local/share/add && git pull
scripts/install.sh --yes --agents all
```

## Uninstall

```bash
~/.local/share/add/scripts/uninstall.sh
```

Only symlinks pointing at this repo are removed. Anything you authored yourself
is left untouched. Generated Codex/pi directories are real files and can be
removed manually from `~/.codex/skills/` or `~/.pi/agent/skills/` if needed.

## Lifecycle

The epic artifact flow and the per-story status state machine are separate
views. In both diagrams, `[/<skill>]` labels a runnable skill command.

### Epic Artifact Lifecycle

This view shows coordination artifacts: planning, story publication, feedback
absorption, squashing, and epic-level PR creation.

```text
              ┌────────────────────┐
              │ no epic files yet  │
              └─────────┬──────────┘
                        │ [/epic-plan]
                        ▼
              ┌────────────────────┐
              │ MASTER.md          │
              │ epic coordination  │
              └─────────┬──────────┘
                        │ [/epic-story-plan]
                        ▼
              ┌────────────────────┐
              │ story files        │
              │ + MASTER.md rows   │
              └─────────┬──────────┘
                        │ completed story work
                        ▼
              ┌────────────────────┐
              │ current ✅ DONE    │
              │ non-archived scope │
              └────┬─────────┬─────┘
                   │         │
       [/epic-squash]        │ included by [/epic-pr]
                   │         │
                   ▼         │
       ┌────────────────┐    │
       │ CONTRACT.md    │    │
       │ + archive/     │    │
       └────────┬───────┘    │
                │            │
                └────┬───────┘
                     ▼
       ┌────────────────────┐
       │ reviewable scope   │
       │ contract + current │
       └────────┬───────────┘
                │ [/epic-pr]
                ▼
       ┌────────────────────┐
       │ GitHub PR          │
       │ + Epic PR Tracking │
       └────────────────────┘

[/epic-pr] blocks on gaps/conflicts; repair, then rerun [/epic-pr].
```

Feedback is a side flow into the same epic/story coordination files:

```text
        PR / CURe / reviewer feedback
                    │
                    │ [/epic-feedback]
                    ▼
        ┌───────────────────────────┐
        │ MASTER.md                 │
        │ Feedback Absorption Log   │
        └──────┬────────┬───────────┘
               │        │
               │        ├─ new future work
               │        │      -> Feedback-Derived Story Candidates
               │        │      -> [/epic-story-plan]
               │        │
               │        └─ epic-level decision
               │               -> Feedback-Derived Decisions
               │
               ├─ existing story refinement
               │      -> story body + tiny story receipt
               │
               └─ implementation rework
                      -> story Review Log
                      -> [/epic-story-resume]
```

### Story State Lifecycle

This view shows the status machine for each story row.

```text
                 ┌─────────────┐
                 │   ⚪ TODO   │
                 └──────┬──────┘
                        │ optional plan loop:
                        │ [/epic-story-plan-review]
                        │ or [/epic-story-plan-converge]
                        │ claim: [/epic-story-claim]
                        ▼
                 ┌─────────────┐
                 │ 🔄 IN PROG  │
                 └──────┬──────┘
                        │ implementation complete:
                        │ [/epic-story-claim] or [/epic-story-resume]
                        │ or [/epic-story-review]
                        │ looper: [/epic-story-converge]
                        ▼
                 ┌─────────────┐
                 │ 🟣 IN REV   │
                 └──────┬──────┘
                        │
               ┌────────┴────────┐
               │                 │
               │ no PR stage     │ PR stage: [/epic-story-pr]
               │ approve via     │
               │ [/epic-story-review]
               │ or [/epic-story-resume]
               ▼                 ▼
          ┌─────────┐      ┌──────────┐
          │ ✅ DONE │      │ 🔵 IN PR │
          └────┬────┘      └────┬─────┘
               │               ├─ merged: [/epic-story-pr] -> ✅ DONE
               │               └─ changes requested:
               │                     [/epic-story-pr]
               │                     -> 🔄 IN PROG
               │
               ├─ late unmerged PR: [/epic-story-pr] -> 🔵 IN PR
               └─ late merged PR metadata: [/epic-story-pr] -> ✅ DONE

                 ⛔ BLOCKED
                 entered by [/epic-story-claim],
                 [/epic-story-plan-review], or [/epic-story-review];
                 fix the issue, then rerun the appropriate skill.
```

Planning helper: `[/grillme]` can stress-test a plan or design before an epic,
between stories, or whenever the operator wants a sharper interview. It is
exploratory/non-binding: design discussion becomes story contract only when the
operator copies it into `Scenarios`, `Acceptance`, or `Verification` (including
`Design Sources` / `Design Element Trace`).

Feedback helper: `[/epic-feedback]` can absorb the latest unprocessed PR review
comment, a CURe feedback block, or pasted reviewer notes into the epic without
turning that feedback into unstructured story text.

Looper helpers: `[/epic-story-plan-converge]` and `[/epic-story-converge]`
do not own status transitions. They babysit repeated fresh sessions and delegate
all writes to the underlying lifecycle commands. They may carry neutral
in-memory notes about blockers, hotspots, repeated tool friction, and a
session-only Research Board of sourced facts.
The Research Board is passed to fresh agents as orientation only, requires exact
source anchors, and is never persisted as a physical cache. The looper owns
keeping that board relevant for later passes; executor agents only decide
whether the needed fact is present in the provided board. When it is present,
they verify it with direct reads/search against the cited anchors instead of
rerunning expensive research. If direct verification shows a provided entry no
longer supports its claim, the executor reports a board-refresh signal with the
entry id and live-source anchors; the looper decides how to update, replace, or
retire that board entry. Loopers pass the full board unless the operator
approves compaction.
Looper final reports are structured operational handoffs only, not thinking
logs; `DONE` means the authoritative story status is `✅ DONE`, while local
approval that still awaits the optional PR stage is reported as `APPROVED`.

Full transition rules: [`docs/epic-lifecycle.md`](docs/epic-lifecycle.md).

Three principles govern the workflow:

- **Planning is proof-first and test-architecture-aware** — every story needs
  an acceptance contract, Test Architecture Plan, and proof matrix before it can
  reach `⚪ TODO`.
- **Implementation is red-first** — start from the smallest failing seam, turn
  it green, then broaden. If red-first is infeasible, record an explicit
  written exception before proceeding differently.
- **Tech debt is surfaced, not ignored.** Every skill in the pipeline — from
  planning through review — runs a Debt Friction check: is the current story
  being made harder by unclear ownership, duplicated behavior, weak tests, or
  missing seams? When it is, the friction is recorded with a causal link
  (action → evidence → impact → decision) and an explicit disposition:
  `fix-now` for enabling cleanup, `split-story` to spin off a follow-up, or
  `defer-explicitly` with a reason. No silent accumulation.

## Conventions

An **epic** is a container — a product-level silo that groups related stories
around a module, feature area, or initiative. It defines scope and constraints
but carries no implementation detail itself. All the engineering specificity
lives in the **stories**, which are the atomic units of planned, implemented,
and reviewed work.

As stories complete, the epic also accumulates a **`CONTRACT.md`** — a merged,
codebase-verified contract produced by `/epic-squash`. This is what makes the
approach scale. Without squashing, finished specs pile up and every new session
has to sift through a growing stack of stale story files to understand what the
epic actually delivered. Squashing solves this: `/epic-squash` verifies every
claim in the done stories against the live codebase (not the story text — the
code is the source of truth), folds the verified facts into one authoritative
document organized by domain, and archives the originals. The result is a
single contract that stays current and that future planning sessions can trust
without re-reading dozens of individual stories.

The commands read and write a small set of files inside
`agent_coordination/epics/<epic-name>/`:

- `MASTER.md` — the tracker and source of truth for status
- `story-NN-<slug>.md` — one file per story
- `CONTRACT.md` — the merged authoritative contract, written by `/epic-squash`
- `archive/` — archived story files after a successful squash

See [`docs/epic-conventions.md`](docs/epic-conventions.md) for the full schema.

## Contributing

To add a new command, see [`docs/adding-a-command.md`](docs/adding-a-command.md).
The short version: write the canonical Claude Skill at
`claude/skills/<name>/SKILL.md`, add a `pi-fragments/<name>.md` fragment only
when pi needs runtime-specific instructions, then run `scripts/lint.sh` until
it passes. Codex skills and `agents/openai.yaml` files are generated by
`scripts/install-codex.sh`.

## Why "add"

`add` is short for **Agentic Driven Development** — the workflow this repo
encodes. It is also the smallest possible command to type before invoking
something useful, which is the entire point of a personal-tool repo.

## License

[MIT](LICENSE).
