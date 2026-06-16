# Archived legacy epic workflow skills

This directory keeps the pre-OpenSpec `epic-*` workflow for provenance only. The active installer and plugin do **not** scan this archive; only `claude/skills/` and `pi-fragments/` are installed or compiled by default.

Use the OpenSpec workflow skills for new work. If an old user install still has legacy skills, run the runtime installer with `--prune-unsupported` to remove only recognized legacy workflow entries from the selected runtime targets.

## Replacement map

| Archived legacy skill | Preferred OpenSpec skill |
|---|---|
| `epic-plan` | `openspec-epic-plan` |
| `epic-story-plan` | `openspec-story-plan` |
| `epic-story-plan-review` | `openspec-story-plan-review` |
| `epic-story-plan-resume` | `openspec-story-plan-resume` |
| `epic-story-plan-converge` | `openspec-story-plan-converge` |
| `epic-story-claim` | `openspec-story-claim` |
| `epic-story-resume` | `openspec-story-resume` |
| `epic-story-review` | `openspec-story-review` |
| `epic-story-converge` | `openspec-story-converge` |
| `epic-story-pr` | `openspec-story-pr` |
| `epic-feedback` | `openspec-feedback` |
| `epic-squash` | `openspec-archive` |
| `epic-pr` | No exact OpenSpec equivalent; use story-level `openspec-story-pr` plus initiative/change status artifacts. |

## Contents

- `claude/skills/` — archived canonical Claude Skill sources.
- `pi-fragments/` — archived pi-specific fragments for legacy skills.
- `docs/` — archived lifecycle/conventions documentation for the legacy file layout.
