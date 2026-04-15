# Changelog

All notable changes to `add` (Agentic Driven Development) are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- `epic-story-review` paired command (Claude Skill + Codex skill). Runs at
  `⚪ TODO` — before `/epic-claim` — to validate a story's plan against the
  live repo: Purpose / Acceptance / Verification / Critical Files / Locked
  Decisions. Records verdict in a new `## Plan Review Log` section on the
  story file. Opt-in; `/epic-claim` is unchanged.
- `## Plan Review Log` runtime section documented in
  `docs/epic-conventions.md`, owned exclusively by `/epic-story-review`.
- `docs/epic-lifecycle.md` clarifies that `⛔ BLOCKED` may be entered when
  `/epic-story-review` determines a plan is not implementable as specified,
  and adds an authority-table column for the new command.
- `codex/skills/<name>/` directory format per Codex CLI ≥ 0.117. Each skill
  has a `SKILL.md` (with `name` / `description` / `legacy-argument-hint`
  frontmatter) and `agents/openai.yaml` (`allow_implicit_invocation:
  false`). Nine skills migrated from `codex/prompts/`: `epic_claim`,
  `epic_new_story`, `epic_pr`, `epic_resume`, `epic_review`, `epic_squash`,
  `epic_story_review`, `grillme`, `memorize`.
- `scripts/regen-prompts.sh` generates the legacy `codex/prompts/<name>.md`
  files from the canonical `codex/skills/<name>/SKILL.md` files. `--check`
  mode for CI / lint integration.
- Install wizard: `scripts/install.sh` now runs an interactive wizard on a
  TTY, asking which agents to install, user-level vs project-level scope,
  and — for Codex — which flavor (legacy / new / both), with auto-detection
  against `codex --version`.
- Non-interactive install path: `--agents`, `--codex-flavor`, `--yes` flags
  for CI / devcontainer use. `--project <path>` is unified across runtimes
  and installs to `<path>/.claude/skills/` and `<path>/.agents/skills/`.

### Changed
- `codex/skills/<name>/SKILL.md` is now the single source of truth for
  Codex commands. The legacy `codex/prompts/<name>.md` files are
  auto-generated and must not be hand-edited. Lint fails on stale generated
  prompts.
- `scripts/lint.sh` now checks frontmatter on Codex skills, pairs Claude
  skills against Codex skills (not prompts), runs the prompt generator in
  check mode, and verifies `agents/openai.yaml` shape.
- `scripts/uninstall.sh` now scans `~/.codex/skills/` in addition to
  `~/.codex/prompts/`, and (with `--project <path>`) scans
  `<path>/.agents/skills/` in addition to `<path>/.claude/skills/`.

### Deprecated
- `~/.codex/prompts/` install path and the `codex/prompts/` source
  directory. Supported by the installer behind `--codex-flavor legacy` (or
  the wizard's legacy option) until pre-0.117 Codex is dead. No deletion
  date set.

### Fixed
- `codex/prompts/grillme.md` had a stale `name: grill-me` frontmatter field
  that did not match its filename. Normalized as part of the migration to
  the new skill format.
- `codex/prompts/memorize.md` had trailing whitespace on its frontmatter
  delimiter and was missing a blank line after the closing `---`.
  Normalized as part of the migration.

### Changed
- `epic-pr` now infers the active epic and story when invoked without
  arguments, matching the behavior of `epic-claim` / `epic-resume` /
  `epic-squash`. Explicit args still take precedence and skip inference.
- `epic-pr` additionally infers the PR URL from the resolved story's
  `## PR Tracking` section, then from `gh pr list --head <current branch>`
  in the project's git repo. Falls through to `OPEN` mode after operator
  confirmation if no existing PR is found.
- `epic-review` documents explicitly that its required-args contract is
  intentional friction (anti-bias forcing function), not a missing feature.
  Behavior unchanged.
- `docs/epic-conventions.md` adds an "Argument inference rules" table
  documenting auto-detection per command, including which commands
  deliberately reject inference and why.

### Added
- Initial repo bootstrap.
- 6 epic_* commands authored as Claude Skills (`claude/skills/<name>/SKILL.md`)
  and as Codex prompts (`codex/prompts/<name>.md`):
  `epic-claim`, `epic-resume`, `epic-review`, `epic-pr`, `epic-squash`,
  `epic-new-story`.
- `grillme` utility command in both Claude and Codex form.
- `memorize` Codex-only utility prompt.
- `scripts/install.sh` — idempotent symlink installer for both Claude Skills
  and Codex prompts.
- `scripts/uninstall.sh` — removes only symlinks installed by `install.sh`.
- `scripts/lint.sh` — frontmatter, pairing, drift, and path-leak checks.
- `docs/epic-lifecycle.md` — status state machine and transition rules.
- `docs/epic-conventions.md` — `MASTER.md` / `CONTRACT.md` / story file shapes.
- `docs/adding-a-command.md` — contributor guide for adding a new command.
- `.github/workflows/lint.yml` — CI lint on pull requests.
