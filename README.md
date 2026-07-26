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
    ├── progress.md      # runtime evidence; feedback publishes the current receipt
    └── blocked.md       # existence is an explicit blocker gate
```

- **Initiative** — a durable context file (`initiative.md`) for a body of work:
  goal, constraints, decisions, resources, story candidates, and feedback logs.
- **Change workspace** — one story-sized OpenSpec change under
  `openspec/changes/<story-slug>/` with proposal, story contract, design notes,
  task checklist, and spec deltas. Every present top-level
  `Initiative: <initiative-slug>` header occurs exactly once; it is required for
  new stories, while bounded pre-v3 compatibility requires zero Initiative or
  Initiative-like lines. A malformed present field is a conflict, never absence.
  That field, not prose or an `## Initiative` section, is the durable association.
- **Plan lane** — `story.md`'s `Plan:` header records whether the contract is
  draft, in review, approved, needs changes, or blocked.
- **Implementation status** — `story.md`'s `Status:` header records local
  execution: TODO, in progress, in review, done, or blocked.
- **Runtime evidence** — `progress.md`, `tasks.md`, and optional
  `blocked.md` preserve handoff, proof, the single current implementation-review
  receipt, PR delivery metadata, and blockers.

There is no central tracker table in the active workflow. Fresh sessions resume
from the OpenSpec artifacts themselves.

## Lifecycle at a glance

Use `/openspec-next-action` at any point to inspect the current or selected
OpenSpec initiative/change/spec state and get the next recommended command with
reasoning; it is read-only and never performs lifecycle transitions.

Every workflow response reports either one route:

```text
Suggested next action: <exact command | operator action | wait | None>
```

or, when both routes are valid, an explicit alternative:

```text
Suggested next action:
- Converge wrapper: <exact command | operator action | wait | None>
- Non-looped pass: <exact command | operator action | wait | None>
Choose one; do not run both.
```

A converge wrapper repeatedly launches fresh state-owning passes; a non-looped
pass runs one direct command and returns control to the operator. Planning
convergence alternates review and repair until approval or a stop. Implementation
convergence runs claim/resume only until `🟣 IN REVIEW` or a stop; it never runs
review. Implementation review remains a separate, completely fresh and
oblivious `/openspec-story-review` session.

`/openspec-story-review` authors the completed-review handoff; `/openspec-feedback` validates it and solely publishes the receipt, timeline transition, blocker, and Status. A detected valid-receipt DONE identity/task/proof contradiction also goes first through acknowledged ordinary feedback: routers preserve DONE and receipt bytes, feedback alone reopens to IN PROGRESS with FB provenance, resume repairs to IN REVIEW, and fresh read-only review resumes the normal publication flow.

1. **Plan an initiative** — `/openspec-initiative-plan` creates
   `openspec/initiatives/<slug>/initiative.md` as the initiative-level planning
   counterpart to `/openspec-story-plan`.
2. **Plan a story-sized change** — `/openspec-story-plan INITIATIVE=<slug>`
   interviews the operator and writes the change workspace planning artifacts,
   including the required top-level `story.md → Initiative: <slug>` binding. It
   does not seed implementation runtime files.
3. **Converge the plan** — `/openspec-story-plan-review` independently checks
   the story contract, proof matrix, design trace, and repo reality;
   `/openspec-story-plan-resume` repairs planning gaps;
   `/openspec-story-plan-converge` loops fresh review/resume passes until the
   Plan lane is approved, blocked, or stopped. Planning readers apply the same
   bound-DONE rule: a bound DONE story needs one well-formed current
   APPROVE/PASS receipt and is never treated as receipt-absent legacy.
4. **Implement red-first** — `/openspec-story-claim` claims a plan-approved,
   ready TODO story. A bound DONE prerequisite must have exact DONE Status, no
   blocker, and one well-formed current APPROVE/PASS receipt with a DONE
   transition and no later contradiction. Dependency readers do not recompute
   implementation identity. Only an unbound pre-v3 DONE prerequisite with zero
   Initiative-like lines and no receipt gets a warning-only exception. Claim
   writes `progress.md`, chooses the smallest
   credible failing seam, turns it green, records proof, and hands off. `/openspec-story-resume` continues in-progress
   work or applies review/feedback that `/openspec-feedback` routed back to the
   story.
5. **Review independently** — `/openspec-story-review` is read-only and must run
   from a completely fresh, oblivious session with no implementation-loop
   notebook, summary, operational notes, or prior chat context. It performs the
   substantive assessment and authors a state-bound completed-review handoff;
   it does not mutate product or coordination artifacts. `/openspec-feedback`
   validates that handoff against current bytes and safely maps reviewed paths,
   then publishes the blocker when required, the one current receipt and
   timeline transition, and top-level Status last. Without a validated handoff,
   feedback never constructs or repairs Implementation Review Receipt content.
6. **Converge implementation** — `/openspec-story-converge` orchestrates fresh
   claim/resume implementation sessions for one change until the story reaches
   `🟣 IN REVIEW`, a blocker appears, no progress is made, or the cycle budget
   ends. It then tells the operator to run `/openspec-story-review` from a fresh
   oblivious session; it does not launch review itself.
7. **PR delivery helper** — `/openspec-pr` creates, attaches, or refreshes a
   GitHub PR and records durable PR metadata/evidence in `progress.md` without
   owning story status. Before any write it recomputes `review-identity-v1` from
   the receipt bases/paths and records the matching digest and verification time
   in PR State. Merged PR evidence with matching verification supports archive;
   requested changes are absorbed through `/openspec-feedback`.
8. **Absorb feedback** — `/openspec-feedback` routes PR, reviewer, tool, or
   operator feedback to the Plan Review Log, story contract, progress checkpoint,
   story candidates, or initiative-level decisions without touching product
   code. Every acknowledged item, including defer/reject, gets one portable
   receipt in the selected initiative's `initiative.md → ## Feedback Receipts`.
   Initiative-only feedback first resolves one active initiative worktree:
   a unique initiative branch outranks launch, and ambiguity halts before the
   ledger write. No notebook API or notebook mirror is required. Every direct
   amendment or resume mutation also gets an FB-tagged `progress.md` checkpoint, including
   status-only or contract-unchanged mutations. When acknowledged feedback
   invalidates local completion, it can reopen the story to `🔄 IN PROGRESS` so
   `/openspec-story-resume` owns the fix.
9. **Archive completed changes** — `/openspec-archive` preflights DONE status,
   task completion, blocker absence, a valid current APPROVE/PASS receipt for a
   bound story, and PR/no-PR evidence. For a merged PR it trusts PR State only
   when its verified digest matches the current receipt; it recomputes
   `review-identity-v1` only for the explicit no-PR route. Only an unbound pre-v3
   DONE with zero Initiative-like lines and no receipt gets compatibility.
   Archive then delegates spec sync and the workspace move to OpenSpec's built-in
   `/opsx:archive <story-slug>` command. The rootless archive adapter redesign is
   deferred: if the active artifacts are in another worktree, rerun archive from
   that checkout rather than invoking the adapter against a remote root.

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
| `/openspec-story-resume` | Continue implementation, resolve blockers, or address review/feedback routed back to the story. |
| `/openspec-story-review` | Independently review implementation read-only from a fresh, oblivious session and author the completed-review handoff for `/openspec-feedback` to validate and publish. |
| `/openspec-story-converge` | Loop fresh claim/resume implementation passes until `🟣 IN REVIEW` or stop, then instruct the operator to run review separately. |
| `/openspec-pr` | Verify `review-identity-v1` before writes and manage optional GitHub PR delivery metadata/evidence in `progress.md → ## PR State`. |
| `/openspec-feedback` | Classify and absorb structured feedback, including acknowledged story reopens, into the right OpenSpec artifacts. |
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

Pull first, then update each installed runtime separately:

```bash
cd ~/.local/share/add && git pull
scripts/install.sh --yes --agents claude
scripts/install.sh --yes --agents codex --force
scripts/install.sh --yes --agents pi --force
```

Claude skills are symlinks into the clone and therefore update with `git pull`;
the Claude installer does not need `--force`. Codex and pi skills are generated
copies, so a source update changes their compiled content and requires
`--force` to refresh it. That flag also overwrites local edits or conflicting
files and does not create a backup, so copy any runtime-local changes you want
to keep before updating.

Avoid a blanket `--agents all --force`: it grants unnecessary clobber permission
to Claude targets while refreshing generated skills. Separate commands keep the
Claude symlink update conservative and apply `--force` only to Codex and pi.

Refresh only a project-scoped Codex installation by sending the Codex installer
directly to that project's destination (the umbrella installer would also select
its normal user scope):

```bash
CODEX_SKILLS_DIR=<project>/.agents/skills scripts/install-codex.sh --force
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
