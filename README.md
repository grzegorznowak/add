# add — Agentic Driven Development

A personal, pluggable collection of agent skills for managing software work via
the **epic / story** lifecycle. Authored once, installed into both **Claude
Code** and **Codex** with one command.

## What this gives you

Eight coordinated workflow commands plus two small utilities:

| Command | What it does |
|---|---|
| `/epic-plan` | Interview-driven bootstrap for a new epic. Produces the `agent_coordination/epics/<slug>/MASTER.md` skeleton after a grillme-style walkthrough. Never overwrites an existing epic. |
| `/epic-story-plan` | Interview-driven creation of a new `⚪ TODO` story. Writes `story-NN-<slug>.md` and appends the `MASTER.md` tracker row after validating atomic acceptance IDs and the reviewer-facing proof matrix. |
| `/epic-story-plan-review` | Read-only review of a `⚪ TODO` story's plan against the live repo, with explicit scrutiny of acceptance quality, proof-matrix completeness, and proof-seam realism before `/epic-story-claim`. Records the verdict into the coordination file. |
| `/epic-story-claim` | Pick one ready, unclaimed story from an epic, claim it, inspect sources, start from the smallest focused red seam, execute it end-to-end, and leave a clean handoff for the next session. |
| `/epic-story-resume` | Resume one already-in-progress story, or one whose PR has requested changes, using the same red-first default or an explicit written exception. |
| `/epic-story-review` | Read-only review of one story's implementation against its spec, including whether the red-first path or explicit written exception was recorded correctly. Records the verdict back into the coordination file. |
| `/epic-story-pr` | Optional `IN REVIEW` -> `IN PR` transition. Opens or attaches a GitHub PR with a product-focused body, not an implementation diary. |
| `/epic-squash` | Fold every `DONE` story of an epic into its merged `CONTRACT.md`, verifying claims against the codebase, then archive the stories. Supports bootstrap mode for first-time consolidation. |
| `/grillme` | Get the agent to interview you relentlessly about a plan or design until shared understanding is reached. |
| `/memorize` *(Codex only)* | Capture session knowledge into a proposed AGENTS.md / docs patch. |

The commands share a single status lifecycle and a single set of conventions for
the coordination files they read and write. See
[`docs/epic-lifecycle.md`](docs/epic-lifecycle.md) and
[`docs/epic-conventions.md`](docs/epic-conventions.md).

## Install

There are two installation paths, and they coexist cleanly:

1. **Claude Code plugin** — for users who only want the Claude side and prefer
   the first-party `/plugin` flow. See [Plugin install](#plugin-install-claude-code-only).
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
first-party plugin flow. The repo ships a minimal `.claude-plugin/plugin.json`
manifest plus a `skills/` symlink pointing at `claude/skills/`.

```bash
/plugin install grzegorznowak/add@github
```

The Codex skills are not installed by the plugin path. Use
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
                   (once per epic, not per story)
                   ┌──────────────┐
                   │  /epic-plan  │   creates agent_coordination/epics/<slug>/MASTER.md
                   └──────┬───────┘
                          │
                          │ (per story, from here down)
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

Planning is proof-first; implementation is red-first. Before a story reaches
`⚪ TODO`, `/epic-story-plan` must create an implementation-ready `Acceptance`
contract plus `Verification` proof matrix. Then `/epic-story-claim` or
`/epic-story-resume` inspects the real code and tests, chooses the smallest
focused failing seam, turns it green, and only then broadens verification. If
red-first is infeasible, the session records an explicit written exception
before proceeding differently.

## Conventions

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
