#!/usr/bin/env bash
# install-opencode-agents.sh — link this repo's opencode agents into the
# correct opencode agent directory.
#
# Usage:
#   scripts/install-opencode-agents.sh
#   scripts/install-opencode-agents.sh --project PATH
#   scripts/install-opencode-agents.sh --force
#   scripts/install-opencode-agents.sh --dry-run
#
# Destinations:
#   user:    ~/.config/opencode/agent/<agent>.md
#   project: <project>/.opencode/agent/<agent>.md

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_SRC="${REPO_ROOT}/.opencode/agent"
USER_DEST="${HOME}/.config/opencode/agent"

PROJECT_PATH=""
FORCE=0
DRY_RUN=0

log() { printf '%s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; }
warn() { printf 'warn: %s\n' "$*" >&2; }

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    log "  would: $*"
  else
    "$@"
  fi
}

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      [[ $# -ge 2 ]] || { err "--project requires a path"; exit 2; }
      PROJECT_PATH="${2%/}"
      [[ -d "$PROJECT_PATH" ]] || { err "--project path does not exist: $PROJECT_PATH"; exit 2; }
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "unknown argument: $1"
      exit 2
      ;;
  esac
done

[[ -d "$AGENTS_SRC" ]] || { err "agent source directory does not exist: $AGENTS_SRC"; exit 1; }

DEST="$USER_DEST"
if [[ -n "$PROJECT_PATH" ]]; then
  DEST="${PROJECT_PATH}/.opencode/agent"
fi

log "opencode agents -> $DEST"
[[ $DRY_RUN -eq 1 ]] && log "(dry run - no filesystem changes)"
run mkdir -p "$DEST"

for agent_file in "$AGENTS_SRC"/*.md; do
  [[ -f "$agent_file" ]] || continue
  name="$(basename "$agent_file")"
  target="$DEST/$name"

  if [[ -e "$target" && "$target" -ef "$agent_file" ]]; then
    log "  ok    $target"
    continue
  fi

  if [[ -L "$target" ]]; then
    current="$(readlink "$target")"
    if [[ "$current" == "$agent_file" ]]; then
      log "  ok    $target"
      continue
    fi
    if [[ $FORCE -eq 1 ]]; then
      warn "replacing existing symlink $target -> $current"
      run rm "$target"
    else
      warn "skip  $target -> $current (existing symlink points elsewhere; use --force to replace)"
      continue
    fi
  elif [[ -e "$target" ]]; then
    if [[ $FORCE -eq 1 ]]; then
      warn "replacing existing target $target"
      run rm -rf "$target"
    else
      warn "skip  $target (exists and is not a symlink; use --force to replace)"
      continue
    fi
  fi

  log "  link  $target -> $agent_file"
  run ln -s "$agent_file" "$target"
done

log "done. Restart opencode or run /reload to load newly installed agents."
