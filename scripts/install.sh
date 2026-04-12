#!/usr/bin/env bash
# install.sh — symlink Claude Skills and Codex prompts from this repo into the
# user's agent runtime directories. Idempotent. Refuses to clobber non-symlink
# targets unless --force is passed.
#
# Usage:
#   scripts/install.sh                 # user-level install (default)
#   scripts/install.sh --project PATH  # also install Claude Skills into PATH/.claude/skills/
#   scripts/install.sh --force         # overwrite non-symlink targets at the destination
#   scripts/install.sh --dry-run       # show what would happen, change nothing

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS_SRC="${REPO_ROOT}/claude/skills"
CODEX_PROMPTS_SRC="${REPO_ROOT}/codex/prompts"

CLAUDE_DEST="${HOME}/.claude/skills"
CODEX_DEST="${HOME}/.codex/prompts"

FORCE=0
DRY_RUN=0
PROJECT_DEST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --project)
      [[ $# -ge 2 ]] || { echo "error: --project requires a path" >&2; exit 2; }
      PROJECT_DEST="${2%/}/.claude/skills"
      shift 2
      ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

log() { printf '%s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }
err() { printf 'error: %s\n' "$*" >&2; }

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    log "  would: $*"
  else
    "$@"
  fi
}

ensure_dir() {
  local d="$1"
  if [[ ! -d "$d" ]]; then
    log "creating $d"
    run mkdir -p "$d"
  fi
}

# $1 = source path, $2 = destination path, $3 = "dir" or "file"
link_one() {
  local src="$1" dest="$2" kind="$3"

  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    if [[ "$current" == "$src" ]]; then
      log "  ok    $dest"
      return 0
    fi
    if [[ $FORCE -eq 1 ]]; then
      warn "replacing existing symlink $dest -> $current"
      run rm "$dest"
    else
      warn "skip  $dest -> $current (existing symlink points elsewhere; use --force to replace)"
      return 0
    fi
  elif [[ -e "$dest" ]]; then
    if [[ $FORCE -eq 1 ]]; then
      warn "replacing existing $kind $dest"
      run rm -rf "$dest"
    else
      warn "skip  $dest (exists and is not a symlink; use --force to clobber)"
      return 0
    fi
  fi

  log "  link  $dest -> $src"
  run ln -s "$src" "$dest"
}

install_claude_into() {
  local dest_root="$1"
  ensure_dir "$dest_root"
  log "Claude Skills → $dest_root"
  for skill_dir in "$CLAUDE_SKILLS_SRC"/*/; do
    [[ -d "$skill_dir" ]] || continue
    local name
    name="$(basename "$skill_dir")"
    local skill_md="$skill_dir/SKILL.md"
    if [[ ! -f "$skill_md" ]]; then
      warn "skip  $name (no SKILL.md inside)"
      continue
    fi
    link_one "${skill_dir%/}" "$dest_root/$name" "dir"
  done
}

install_codex() {
  ensure_dir "$CODEX_DEST"
  log "Codex prompts → $CODEX_DEST"
  for prompt in "$CODEX_PROMPTS_SRC"/*.md; do
    [[ -f "$prompt" ]] || continue
    local name
    name="$(basename "$prompt")"
    link_one "$prompt" "$CODEX_DEST/$name" "file"
  done
}

log "add (Agentic Driven Development) — install"
log "repo: $REPO_ROOT"
[[ $DRY_RUN -eq 1 ]] && log "(dry run — no filesystem changes)"
log

install_claude_into "$CLAUDE_DEST"
log

if [[ -n "$PROJECT_DEST" ]]; then
  install_claude_into "$PROJECT_DEST"
  log
fi

install_codex
log
log "done."
