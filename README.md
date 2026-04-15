# add — Agentic Driven Development

A personal, pluggable collection of agent prompts and Skills for managing
software work via the **epic / story** lifecycle. Authored once, installed
into both **Claude Code** (as Anthropic Skills) and **Codex** (as skills,
with a legacy prompts fallback during the transition to Codex ≥ 0.117)
with one command.

## What this gives you

Seven coordinated workflow commands plus two small utilities:

| Command | What it does |
|---|---|
| `/epic-new-story` | Scaffold a new story file from the current Claude Code plan, preserving every research finding so implementation does not have to re-discover it. |
| `/epic-story-review` | Read-only review of a `⚪ TODO` story's plan (Purpose / Acceptance / Critical Files / Locked Decisions) against the live repo, before `/epic-claim`. Records the verdict into the coordination file. |
| `/epic-claim` | Pick one ready, unclaimed story from an epic, claim it, execute it end-to-end, and leave a clean handoff for the next session. |
| `/epic-resume` | Resume one already-in-progress story (or one whose PR has requested changes). |
| `/epic-review` | Read-only review of one story's implementation against its spec. Records the verdict back into the coordination file. |
| `/epic-pr` | Optional `IN REVIEW` → `IN PR` transition. Opens or attaches a GitHub PR with a **product-focused** body (not an implementation diary). |
| `/epic-squash` | Fold every `DONE` story of an epic into its merged `CONTRACT.md`, verifying claims against the codebase, then archive the stories. Supports bootstrap mode for first-time consolidation. |
| `/grillme` | Get the agent to interview you relentlessly about a plan or design until shared understanding is reached. |
| `/memorize` *(Codex only)* | Capture session knowledge into a proposed AGENTS.md / docs patch. |

The commands share a single status lifecycle and a single set of conventions
for the coordination files they read and write. See [`docs/epic-lifecycle.md`](docs/epic-lifecycle.md)
and [`docs/epic-conventions.md`](docs/epic-conventions.md).

## Install

```bash
git clone https://github.com/grzegorznowak/add.git ~/.local/share/add
~/.local/share/add/scripts/install.sh
```

Run with no arguments on a TTY and the installer enters an **interactive
wizard** that asks:

1. Which agents to install for (Claude Code, Codex, or both)
2. User-level vs project-level scope (project mode prompts for a path)
3. For Codex: which **flavor** to install — `legacy` (`~/.codex/prompts/`,
   for Codex pre-0.117), `new` (`~/.codex/skills/` plus per-project
   `.agents/skills/`, for Codex ≥ 0.117), or `both`. The wizard runs
   `codex --version` and pre-selects the right answer.
4. A confirmation screen before any filesystem changes.

The installer creates symlinks at one or more of these locations:

- `claude/skills/<name>/` → `~/.claude/skills/<name>` (Claude user-level)
- `claude/skills/<name>/` → `<project>/.claude/skills/<name>` (Claude project)
- `codex/skills/<name>/` → `~/.codex/skills/<name>` (Codex new, user-level)
- `codex/skills/<name>/` → `<project>/.agents/skills/<name>` (Codex new, project)
- `codex/prompts/<name>.md` → `~/.codex/prompts/<name>.md` (Codex legacy)

It is idempotent and refuses to clobber non-symlink targets unless you pass
`--force`.

### Non-interactive install (CI / devcontainer)

When invoked with any flag, or when stdin is not a TTY, the installer runs
in scripted mode:

```bash
~/.local/share/add/scripts/install.sh \
  --yes \
  --agents both \
  --codex-flavor new \
  --project /workspaces/myproject
```

Flags:

- `--agents claude|codex|both` — which runtimes (default: both)
- `--codex-flavor legacy|new|both` — which Codex format (default: new)
- `--project <path>` — also link into `<path>/.claude/skills/` and
  `<path>/.agents/skills/` (unified across both runtimes)
- `--yes` — skip the confirmation prompt
- `--force` — overwrite non-symlink targets
- `--dry-run` — show what would happen, change nothing

### Devcontainer one-liner

Drop this into `.devcontainer/devcontainer.json`:

```json
{
  "postCreateCommand": "git clone https://github.com/grzegorznowak/add.git ~/.local/share/add && ~/.local/share/add/scripts/install.sh --yes --agents both --codex-flavor new"
}
```

Every fresh devcontainer comes up with the full epic flow installed.

## Updating

Symlinks mean updates are propagation-by-pull. No reinstall step:

```bash
cd ~/.local/share/add && git pull
```

## Uninstall

```bash
~/.local/share/add/scripts/uninstall.sh
```

Only symlinks pointing at this repo are removed. Anything you authored
yourself is left untouched.

## Lifecycle (one diagram)

```
                         ┌─────────────┐  ◀─── /epic-story-review (optional, logs verdict)
                         │   ⚪ TODO    │
                         └──────┬──────┘
                                │ /epic-claim
                                ▼
                         ┌─────────────┐  ◀─── /epic-resume
                         │ 🔄 IN PROG  │
                         └──────┬──────┘
                                │ implementation done
                                ▼
                         ┌─────────────┐
                         │ 🟣 IN REV   │
                         └──────┬──────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
        no PR stage                      /epic-pr (optional)
                │                               │
                │                               ▼
                │                       ┌─────────────┐
                │                       │  🔵 IN PR   │ ◀──┐
                │                       └──────┬──────┘    │
                │                              │           │
                │                       ┌──────┴──────┐    │
                │                       │             │    │
                │                  PR merged   PR requests changes
                │                       │             │    │
                │                       ▼             ▼    │
                │               ┌─────────────┐  ┌─────────┘
                │               │  ✅ DONE     │  /epic-resume
                │               └─────────────┘  /epic-pr (resync)
                │                       ▲
                └───────────────────────┘

       ⛔ BLOCKED is a side-state reachable from any of the above
       when an external blocker prevents progress.
```

Full transition rules: [`docs/epic-lifecycle.md`](docs/epic-lifecycle.md).

## Conventions

The commands all read and write a small set of well-defined files inside
`agent_coordination/epics/<epic-name>/`:

- `MASTER.md` — the tracker and source of truth for status
- `story-NN-<slug>.md` — one file per story, with sections like `## Active Claim`, `## Progress Log`, `## Session Handoff`, `## Review Log`, `## PR Tracking`
- `CONTRACT.md` — the merged authoritative contract, written by `/epic-squash`
- `archive/` — archived story files after a successful squash

See [`docs/epic-conventions.md`](docs/epic-conventions.md) for the full schema.

## Contributing

To add a new command, see [`docs/adding-a-command.md`](docs/adding-a-command.md).
The short version: write the Claude Skill at `claude/skills/<name>/SKILL.md`
**and** the Codex skill at `codex/skills/<name>/SKILL.md` (with a
`legacy-argument-hint:` frontmatter field), create
`codex/skills/<name>/agents/openai.yaml`, then run
`scripts/regen-prompts.sh` followed by `scripts/lint.sh` until it passes.
The legacy `codex/prompts/<name>.md` files are auto-generated from the
canonical Codex skills — never hand-edit them.

## Why "add"

`add` is short for **Agentic Driven Development** — the workflow this repo
encodes. It is also the smallest possible command to type before invoking
something useful, which is the entire point of a personal-tool repo.

## License

[MIT](LICENSE).
