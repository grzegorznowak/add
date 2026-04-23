# add — Agentic Driven Development

A personal, pluggable collection of agent skills for managing software work via
the **epic / story** lifecycle. Authored once, installed into both **Claude
Code** and **Codex** with one command.

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
  `/epic-story-plan` requires a verification proof matrix — mapping every
  acceptance criterion to a concrete test seam — before the story can leave
  `⚪ TODO`. By the time `/epic-story-claim` starts writing code, the
  question is not "should we test this?" but "which failing seam do we turn
  green first?"

- **A rigid plan eliminates improvisation.** The story spec is an engineering
  blueprint, not a suggestion. Implementation has no room to drift because
  every behavior is pinned to an acceptance ID and a proof seam.
  `/epic-story-review` scrutinizes the implementation against that blueprint —
  not against a vague notion of "code quality" — which makes hallucinated or
  unexpected results immediately visible as contract violations.

The result: each agent run stays small, focused, and verifiable. The
coordination files accumulate the real state, not the conversation.

## What this gives you

Eight coordinated workflow commands plus two small utilities:

| Command | What it does |
|---|---|
| `/epic-plan` | Bootstrap a new epic via guided interview. Produces `MASTER.md`. |
| `/epic-story-plan` | Plan and publish a new `⚪ TODO` story with acceptance criteria and proof matrix. |
| `/epic-story-plan-review` | Review a `⚪ TODO` story's plan against the live repo before claiming. |
| `/epic-story-claim` | Claim an unclaimed story, find the smallest failing seam, and execute red-first. |
| `/epic-story-resume` | Resume an in-progress story or one with requested PR changes. |
| `/epic-story-review` | Review a story's implementation against its spec. Records the verdict. |
| `/epic-story-pr` | Open or attach a GitHub PR with a product-focused body. |
| `/epic-squash` | Merge all `DONE` stories into `CONTRACT.md` and archive them. |
| `/grillme` | Relentless interview about a plan or design until shared understanding. |
| `/memorize` *(Codex only)* | Capture session knowledge into an AGENTS.md / docs patch. |

The commands share a single status lifecycle and a single set of conventions for
the coordination files they read and write. See
[`docs/epic-lifecycle.md`](docs/epic-lifecycle.md) and
[`docs/epic-conventions.md`](docs/epic-conventions.md).

## Install

There are two installation paths, and they coexist cleanly:

1. **Claude Code plugin** — for users who only want the Claude side, via the
   marketplace or `--plugin-dir`. See [Plugin install](#plugin-install-claude-code-only).
2. **Paired installer** — the custom shell script in this repo. Installs both
   the Claude skills and the Codex skills in one pass, user-level or
   project-level. Required if you want the Codex side.

### Paired Installer

```bash
git clone https://github.com/grzegorznowak/add.git ~/.local/share/add
~/.local/share/add/scripts/install.sh
```

Run with no arguments on a TTY and the installer enters an interactive wizard
that asks:

1. Which agents to install for: Claude Code, Codex, or both
2. User-level vs project-level scope
3. A confirmation screen before any filesystem changes

The installer creates symlinks at one or more of these locations:

- `claude/skills/<name>/` -> `~/.claude/skills/<name>` (Claude user-level)
- `claude/skills/<name>/` -> `<project>/.claude/skills/<name>` (Claude project)
- `codex/skills/<name>/` -> `~/.codex/skills/<name>` (Codex user-level)
- `codex/skills/<name>/` -> `<project>/.agents/skills/<name>` (Codex project)

It is idempotent and refuses to clobber non-symlink targets unless you pass
`--force`.

### Non-Interactive Install

```bash
~/.local/share/add/scripts/install.sh \
  --yes \
  --agents both \
  --project /workspaces/myproject
```

Flags:

- `--agents claude|codex|both` — which runtimes (default: both)
- `--project <path>` — also link into `<path>/.claude/skills/` and
  `<path>/.agents/skills/`
- `--yes` — skip the confirmation prompt
- `--force` — overwrite non-symlink targets
- `--dry-run` — show what would happen, change nothing

### Plugin Install (Claude Code Only)

If you only use Claude Code and do not need the Codex side, install via the
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

The Codex skills are not installed by either plugin path. Use
`scripts/install.sh --agents codex` if you want to add the Codex side later.

## Updating

Symlinks mean updates are propagation-by-pull. No reinstall step:

```bash
cd ~/.local/share/add && git pull
```

## Uninstall

```bash
~/.local/share/add/scripts/uninstall.sh
```

Only symlinks pointing at this repo are removed. Anything you authored yourself
is left untouched.

## Lifecycle

```text
                   (once per epic — the container for related stories)
                   ┌──────────────┐
                   │  /epic-plan  │   creates agent_coordination/epics/<slug>/MASTER.md
                   └──────┬───────┘
                          │
                          │ (per story, from here down)
                          ▼
                ┌────────────────┐
                │   /grillme     │   stress-test the story's design before planning
                └───────┬────────┘
                        │ shared understanding reached
                        ▼
                ┌───────────────────┐
                │ /epic-story-plan  │   writes story-NN-<slug>.md + MASTER.md row
                └─────────┬─────────┘
                          │
                          ▼
                ┌─────────────┐  ╌╌ review ╌╌▶  ┌────────────────────────┐
                │   ⚪ TODO   │                 │ /epic-story-plan-review │
                │             │  ◀╌ approve ╌╌  │      (optional)        │
                └──────┬──────┘                 └──────────┬─────────────┘
                       │                                   │
                       │ /epic-story-claim            blocked
                       ▼                                   ▼
                ┌─────────────┐◀── /epic-story-resume  (⛔ BLOCKED)
                │ 🔄 IN PROG  │
                └──────┬──────┘
                       │ implementation done
                       ▼
                ┌─────────────┐
                │ 🟣 IN REV   │
                └──────┬──────┘
                       │
                       ▼
              ┌───────────────────┐ ╌╌ request_changes ╌╌▶ /epic-story-resume
              │ /epic-story-review │ ╌╌ blocked ╌╌▶ (⛔ BLOCKED)
              └──────┬────────────┘
                     │ approve
          ┌──────────┴──────────┐
          │                     │
     no PR stage          /epic-story-pr
          │                     │
          ▼                     ▼
     ┌─────────┐          ┌─────────┐
     │ ✅ DONE │          │ 🔵 IN PR│
     └─────────┘          └────┬────┘
                               │ merged / changes requested
                               ▼
                         ✅ DONE or /epic-story-resume
```

Full transition rules: [`docs/epic-lifecycle.md`](docs/epic-lifecycle.md).

Two principles govern the workflow:

- **Planning is proof-first** — every story needs an acceptance contract and
  proof matrix before it can reach `⚪ TODO`.
- **Implementation is red-first** — start from the smallest failing seam, turn
  it green, then broaden. If red-first is infeasible, record an explicit
  written exception before proceeding differently.

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
The short version: write the Claude Skill at `claude/skills/<name>/SKILL.md`
and the Codex skill at `codex/skills/<name>/SKILL.md`, create
`codex/skills/<name>/agents/openai.yaml`, then run `scripts/lint.sh` until it
passes.

## Why "add"

`add` is short for **Agentic Driven Development** — the workflow this repo
encodes. It is also the smallest possible command to type before invoking
something useful, which is the entire point of a personal-tool repo.

## License

[MIT](LICENSE).
