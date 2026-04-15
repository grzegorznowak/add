#!/usr/bin/env bash
# uninstall.sh — remove only the symlinks that point at this repo. Anything
# you authored yourself in ~/.claude/skills, ~/.codex/skills, or
# ~/.codex/prompts is left alone.
#
# Usage:
#   scripts/uninstall.sh
#   scripts/uninstall.sh --project PATH    # also remove from PATH/.claude/skills/
#                                          # and PATH/.agents/skills/
#   scripts/uninstall.sh --dry-run

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DEST="${HOME}/.claude/skills"
CODEX_PROMPTS_DEST="${HOME}/.codex/prompts"
CODEX_SKILLS_DEST="${HOME}/.codex/skills"

DRY_RUN=0
PROJECT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --project)
      [[ $# -ge 2 ]] || { echo "error: --project requires a path" >&2; exit 2; }
      PROJECT_PATH="${2%/}"
      shift 2
      ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

log() { printf '%s\n' "$*"; }
run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    log "  would: $*"
  else
    "$@"
  fi
}

# $1 = directory containing the symlinks to inspect
remove_links_pointing_at_repo() {
  local dir="$1"
  [[ -d "$dir" ]] || { log "(nothing at $dir)"; return 0; }
  log "scanning $dir"
  local count=0
  for entry in "$dir"/*; do
    [[ -L "$entry" ]] || continue
    local target
    target="$(readlink "$entry")"
    case "$target" in
      "$REPO_ROOT"/*)
        log "  unlink $entry"
        run rm "$entry"
        count=$((count + 1))
        ;;
    esac
  done
  log "  removed $count link(s)"
}

log "add — uninstall"
log "repo: $REPO_ROOT"
[[ $DRY_RUN -eq 1 ]] && log "(dry run — no filesystem changes)"
log

remove_links_pointing_at_repo "$CLAUDE_DEST"
remove_links_pointing_at_repo "$CODEX_PROMPTS_DEST"
remove_links_pointing_at_repo "$CODEX_SKILLS_DEST"
if [[ -n "$PROJECT_PATH" ]]; then
  remove_links_pointing_at_repo "${PROJECT_PATH}/.claude/skills"
  remove_links_pointing_at_repo "${PROJECT_PATH}/.agents/skills"
fi

log
log "done."
