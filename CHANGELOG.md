# Changelog

All notable changes to `add` (Agentic Driven Development) are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

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
