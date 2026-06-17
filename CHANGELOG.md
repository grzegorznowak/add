# Changelog

All notable changes to `add` (Agentic Driven Development) are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- `docs/openspec-lifecycle.md` now includes an ASCII OpenSpec state-machine
  diagram covering initiative, planning, local implementation review, PR delivery
  evidence, feedback, archive, and spec-sync states.
- README and lifecycle docs now reference `pi-agenticoding` as the Pi
  context-management building block (`spawn`, `notebook`, `handoff`) for ADD's
  session-bounded OpenSpec workflows.
- `openspec-next-action` recommends the next OpenSpec workflow command by
  inspecting current or selected initiative/change/spec artifacts without
  performing lifecycle transitions.
- OpenSpec workflow skills are now the active workflow surface:
  `openspec-initiative-plan`, `openspec-story-plan`, plan review/resume/converge,
  implementation claim/resume/review/converge, `openspec-pr`,
  `openspec-feedback`, and `openspec-archive`.
- `merge-conflict-analysis` joins `grillme` and `memorize` as a supported
  non-workflow utility skill.
- Runtime installers support explicit `--prune-unsupported` cleanup for
  recognized unsupported workflow skills, including archived legacy commands and
  renamed command entries.
- Active OpenSpec lifecycle and artifact convention docs now replace the moved
  legacy lifecycle/conventions docs.

### Changed
- Changed implementation convergence so `/openspec-story-converge` stops at
  `Status: 🟣 IN REVIEW` and instructs the operator to run
  `/openspec-story-review` from a completely fresh, oblivious session instead
  of launching review inside the implementation loop.
- Renamed the PR delivery helper from `openspec-story-pr` to `openspec-pr` and
  added the old generated names to unsupported-prune cleanup lists.
- Clarified OpenSpec command authority: implementation claim readiness includes
  completed expected prerequisites, `/openspec-story-review` owns local approval
  to `✅ DONE`, `/openspec-pr` records optional PR delivery evidence without
  mutating story status, and loopers may perform only documented
  safety-normalization writes.
- Removed the PR lifecycle status from the active OpenSpec story state machine;
  PR feedback is absorbed through `/openspec-feedback`, which may explicitly
  reopen story work for resume, while archive still requires merged PR evidence
  or explicit no-PR confirmation.
- Active installs now include only OpenSpec workflow skills plus approved
  utility skills. Codex and pi generators compile from that active source set.
- Documentation and plugin metadata now describe the OpenSpec workflow as the
  first-class lifecycle instead of the old command set.
- OpenSpec feedback disposition wording now uses `initiative-level-decision` for
  initiative-wide policy or architecture decisions.
- The initiative planning command is named `openspec-initiative-plan`, aligning
  it with `openspec-story-plan` and avoiding the legacy epic term.
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
