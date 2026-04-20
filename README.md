# add — Agentic Driven Development

A personal, pluggable collection of agent skills for managing
software work via the **epic / story** lifecycle. Authored once, installed
into both **Claude Code** (as Anthropic Skills) and **Codex** (as skills)
with one command.

## What this gives you

Nine coordinated workflow commands plus two small utilities:

| Command | What it does |
|---|---|
| `/epic-plan` | Interview-driven bootstrap for a new epic. Produces the `agent_coordination/epics/<slug>/MASTER.md` skeleton after a grillme-style walkthrough. Never overwrites an existing epic. |
| `/epic-story-plan` | Interview-driven draft of a new story plan for an existing epic. Produces a plan file in `~/.claude/plans/` with atomic acceptance IDs, a reviewer-facing proof matrix, and implementation notes that make red-first the default delivery method. |
| `/epic-story-save` | Scaffold a new story file from a plan file, preserving every research finding and acceptance/proof contract exactly. Fails instead of inventing malformed or incomplete proof structure. |
| `/epic-story-review` | Read-only review of a `⚪ TODO` story's plan against the live repo, with explicit scrutiny of acceptance quality, proof-matrix completeness, and proof-seam realism before `/epic-claim`. Records the verdict into the coordination file. |
| `/epic-claim` | Pick one ready, unclaimed story from an epic, claim it, inspect sources, start from the smallest focused red seam, execute it end-to-end, and leave a clean handoff for the next session. |
| `/epic-resume` | Resume one already-in-progress story (or one whose PR has requested changes) using the same red-first default or an explicit written exception. |
| `/epic-review` | Read-only review of one story's implementation against its spec, including whether the red-first path or explicit written exception was recorded correctly. Records the verdict back into the coordination file. |
| `/epic-pr` | Optional `IN REVIEW` → `IN PR` transition. Opens or attaches a GitHub PR with a **product-focused** body (not an implementation diary). |
| `/epic-squash` | Fold every `DONE` story of an epic into its merged `CONTRACT.md`, verifying claims against the codebase, then archive the stories. Supports bootstrap mode for first-time consolidation. |
| `/grillme` | Get the agent to interview you relentlessly about a plan or design until shared understanding is reached. |
| `/memorize` *(Codex only)* | Capture session knowledge into a proposed AGENTS.md / docs patch. |

The commands share a single status lifecycle and a single set of conventions
for the coordination files they read and write. See [`docs/epic-lifecycle.md`](docs/epic-lifecycle.md)
and [`docs/epic-conventions.md`](docs/epic-conventions.md).

## Install

There are two installation paths, and they coexist cleanly:

1. **Claude Code plugin** — for users who only want the Claude side and
   prefer the first-party `/plugin` flow. See
   [Plugin install](#plugin-install-claude-code-only) below.
2. **Paired installer** — the custom shell script in this repo. Installs
   both the Claude skills and the Codex skills in one pass, user-level or
   project-level. Required if you want the Codex side.

### Paired installer (Claude + Codex)

```bash
git clone https://github.com/grzegorznowak/add.git ~/.local/share/add
~/.local/share/add/scripts/install.sh
```

Run with no arguments on a TTY and the installer enters an **interactive
wizard** that asks:

1. Which agents to install for (Claude Code, Codex, or both)
2. User-level vs project-level scope (project mode prompts for a path)
3. A confirmation screen before any filesystem changes.

The installer creates symlinks at one or more of these locations:

- `claude/skills/<name>/` → `~/.claude/skills/<name>` (Claude user-level)
- `claude/skills/<name>/` → `<project>/.claude/skills/<name>` (Claude project)
- `codex/skills/<name>/` → `~/.codex/skills/<name>` (Codex user-level)
- `codex/skills/<name>/` → `<project>/.agents/skills/<name>` (Codex project)

It is idempotent and refuses to clobber non-symlink targets unless you pass
`--force`.

### Non-interactive install (CI / devcontainer)

When invoked with any flag, or when stdin is not a TTY, the installer runs
in scripted mode:

```bash
~/.local/share/add/scripts/install.sh \
  --yes \
  --agents both \
  --project /workspaces/myproject
```

Flags:

- `--agents claude|codex|both` — which runtimes (default: both)
- `--project <path>` — also link into `<path>/.claude/skills/` and
  `<path>/.agents/skills/` (unified across both runtimes)
- `--yes` — skip the confirmation prompt
- `--force` — overwrite non-symlink targets
- `--dry-run` — show what would happen, change nothing

### Devcontainer one-liner

Drop this into `.devcontainer/devcontainer.json`:

```json
{
  "postCreateCommand": "git clone https://github.com/grzegorznowak/add.git ~/.local/share/add && ~/.local/share/add/scripts/install.sh --yes --agents both"
}
```

Every fresh devcontainer comes up with the full epic flow installed.

### Plugin install (Claude Code only)

If you only use Claude Code and don't need the Codex side, you can
install via the first-party plugin flow. The repo ships a minimal
`.claude-plugin/plugin.json` manifest plus a `skills/` symlink pointing
at `claude/skills/`, so Claude Code's plugin loader discovers all the
skills at their expected `skills/<name>/SKILL.md` location.

```bash
/plugin install grzegorznowak/add@github
```

(Exact invocation depends on the marketplace / loader you use. For
local development, point Claude Code at a checkout of this repo.)

The Codex skills are **not** installed by the plugin path — that's
paired-installer-only. Mix freely: use `/plugin` for the Claude side and
`scripts/install.sh --agents codex` for the Codex side if that split matches
your workflow.

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
yourself is left untouched. Historical `~/.codex/prompts` symlinks from
older installs are cleaned up too.

## Lifecycle (one diagram)

```
                   (once per epic, not per story)
                   ┌──────────────┐
                   │  /epic-plan  │   creates agent_coordination/epics/<slug>/MASTER.md
                   └──────┬───────┘
                          │
                          │ (per story, from here down)
                          ▼
                ┌───────────────────┐
                │ /epic-story-plan  │   drafts ~/.claude/plans/<epic>-<slug>.md
                └─────────┬─────────┘
                          │
                          ▼
                ┌───────────────────┐
                │  /epic-story-save  │   writes story-NN-<slug>.md + MASTER.md row
                └─────────┬─────────┘
                          │
                          ▼
                ┌─────────────┐  ╌╌ review ╌╌▶  ┌──────────────────────┐
                │   ⚪ TODO   │                 │  /epic-story-review  │
                │             │  ◀╌ approve ╌╌  │     (optional)       │
                └──────┬──────┘                 └──────────┬───────────┘
                       │                                   │
                       │ /epic-claim            blocked    │
                       │                        verdict    ▼
                       │                             (⛔ BLOCKED)
                       ▼
                ┌─────────────┐◀── /epic-resume  ┌─────────────┐
                │ 🔄 IN PROG  │── impl done ───▶ │ 🟣 IN REV   │
                └──────┬──────┘                  └──────┬──────┘
                       ▲                                │ submit
                       │                                ▼
                       │                       ┌─────────────────┐
                       │                       │  /epic-review   │ ╌╌ blocked ╌╌▶ (⛔ BLOCKED)
                       │                       └──┬──────────┬───┘
                       │                          │          │
                       ╰╌╌ request_changes ╌╌╌╌╌╌╌╯       approve
                                                              │
                                                              ▼
                              ┌───────────────────┴───────────────────┐
                              │                                       │
                        no PR stage                          /epic-pr (optional)
                              │                                       │
                              │                                       ▼
                              │                              ┌─────────────┐
                              │                              │  🔵 IN PR   │ ◀──┐
                              │                              └──────┬──────┘    │
                              │                                     │           │
                              │                              ┌──────┴──────┐    │
                              │                              │             │    │
                              │                         PR merged    PR requests changes
                              │                              │             │    │
                              │                              ▼             ▼    │
                              │                      ┌─────────────┐  ┌─────────┘
                              │                      │  ✅ DONE    │  /epic-resume
                              │                      └─────────────┘  /epic-pr (resync)
                              │                              ▲
                              └──────────────────────────────┘

       ⛔ BLOCKED is a side-state reachable from any of the above when an
       external blocker prevents progress. /epic-story-review and
       /epic-review can each route a story directly to ⛔ BLOCKED.

       Dashed connectors  ╌╌╌  indicate optional transitions or verdict
       loopbacks. Solid connectors indicate the main flow.
```

Full transition rules: [`docs/epic-lifecycle.md`](docs/epic-lifecycle.md).

Planning note: the diagram intentionally shows only lifecycle transitions.
Before a story reaches `⚪ TODO`, `/epic-story-plan` must already produce an
implementation-ready `Acceptance` contract plus `Verification` proof matrix,
and `/epic-story-save` must fail instead of inventing missing proof structure.
Planning is proof-first; implementation is red-first. The plan defines the
owning proof surfaces, then `/epic-claim` or `/epic-resume` must inspect the
real code and tests, choose the smallest focused failing seam, and only
broaden verification after that seam turns green. If red-first is infeasible,
the session must record an explicit written exception before proceeding
differently.

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
**and** the Codex skill at `codex/skills/<name>/SKILL.md`, create
`codex/skills/<name>/agents/openai.yaml`, then run `scripts/lint.sh` until it
passes.

## Why "add"

`add` is short for **Agentic Driven Development** — the workflow this repo
encodes. It is also the smallest possible command to type before invoking
something useful, which is the entire point of a personal-tool repo.

## License

[MIT](LICENSE).
