# Changelog

All notable changes to `add` (Agentic Driven Development) are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- OpenSpec workflow skills are now the active workflow surface:
  `openspec-epic-plan`, `openspec-story-plan`, plan review/resume/converge,
  implementation claim/resume/review/converge, `openspec-story-pr`,
  `openspec-feedback`, and `openspec-archive`.
- `merge-conflict-analysis` joins `grillme` and `memorize` as a supported
  non-workflow utility skill.
- Runtime installers support explicit `--prune-unsupported` cleanup for
  recognized archived legacy workflow skills.
- Active OpenSpec lifecycle and artifact convention docs now replace the moved
  legacy lifecycle/conventions docs.

### Changed
- Active installs now include only OpenSpec workflow skills plus approved
  utility skills. Codex and pi generators compile from that active source set.
- Documentation and plugin metadata now describe the OpenSpec workflow as the
  first-class lifecycle instead of the old command set.
- OpenSpec feedback disposition wording now uses `initiative-level-decision` for
  initiative-wide policy or architecture decisions.
- Plugin metadata bumped to `0.2.0`.

### Removed
- Legacy `epic-*` workflow skills are no longer installed by default and were
  moved to `archive/skills/legacy-epic/` for provenance.

## [0.1.0] - 2026-04-22

### Added
- Baseline release of the paired Claude/Codex epic workflow skills.
- `epic-plan` for epic bootstrap.
- `epic-story-plan` for proof-first story planning.
- `epic-story-plan-review`, `epic-story-claim`, `epic-story-resume`,
  `epic-story-review`, `epic-story-pr`, and `epic-squash` for the story
  lifecycle.
- `grillme` and `memorize` utility skills.
- Installer, uninstaller, lint script, lifecycle docs, conventions docs, and
  Claude plugin metadata.
