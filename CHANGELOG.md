# Changelog

All notable changes to `add` (Agentic Driven Development) are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- `epic-feedback` absorbs CURe, PR, or reviewer feedback into an epic-scoped
  routing log, story contract edits, implementation review findings, story
  candidates, or epic-level notes.
- `epic-pr` opens or refreshes an epic-level GitHub PR from `CONTRACT.md`
  plus current non-archived DONE stories, with a lightweight epic check-in
  before publishing.

### Changed
- `epic-story-plan` is now the direct story publication command. After the
  interview and checkpoint, it writes `story-NN-<slug>.md` and appends the
  `⚪ TODO` row to `MASTER.md`.
- `epic-story-pr` PR bodies now include detected original ticket/card links
  near the top when those links are available.
- Story planning now uses lean section ownership: acceptance owns behavior,
  verification owns proof, implementation notes are an execution brief, and
  discovery notes are source-derived facts rather than a catch-all transcript.
- `epic-story-plan-review` expects stories scaffolded directly by
  `epic-story-plan`.
- Plugin metadata bumped to `0.2.0`.

### Removed
- The standalone story publication command was removed. Story creation now
  happens in `epic-story-plan`.

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
