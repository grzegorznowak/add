#!/usr/bin/env bash
# install.sh — install Claude Skills and Codex skills from this repo into the
# user's agent runtime directories. Idempotent.
#
# Two modes:
#   - Wizard (default on TTY, no args): asks which agents and scope to install.
#   - Scripted (any args, or non-TTY): flag-driven for CI / devcontainers.
#
# Scripted-mode flags:
#   --agents <claude|codex|both>     which runtimes to install (default: both)
#   --project <path>                 also install into project scope
#                                    (<path>/.claude/skills/ for Claude,
#                                     <path>/.agents/skills/ for Codex)
#   --yes                            skip the confirmation prompt
#   --force                          overwrite non-symlink targets
#   --dry-run                        show what would happen, change nothing
#   --help                           show this message

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS_SRC="${REPO_ROOT}/claude/skills"
CODEX_SKILLS_SRC="${REPO_ROOT}/codex/skills"

CLAUDE_USER_DEST="${HOME}/.claude/skills"
CODEX_SKILLS_USER_DEST="${HOME}/.codex/skills"

AGENTS=""           # claude | codex | both
PROJECT_PATH=""
YES=0
FORCE=0
DRY_RUN=0
HAVE_FLAGS=0

log()  { printf '%s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }
err()  { printf 'error: %s\n' "$*" >&2; }
banner() {
  printf '\n=== %s ===\n' "$*"
}

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

# ---------- Installers ----------

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

install_codex_skills_into() {
  local dest_root="$1"
  ensure_dir "$dest_root"
  log "Codex skills → $dest_root"
  for skill_dir in "$CODEX_SKILLS_SRC"/*/; do
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

# ---------- Wizard ----------

# $1 = prompt, $2 = options string (e.g. "1=foo  2=bar"), $3 = default key
# Echoes the chosen key on stdout.
ask_choice() {
  local prompt="$1" options="$2" default="$3"
  local reply
  while true; do
    printf '\n%s\n' "$prompt"
    printf '%s\n' "$options"
    printf '[default: %s] > ' "$default"
    if ! IFS= read -r reply; then
      reply=""
    fi
    [[ -z "$reply" ]] && reply="$default"
    case "$reply" in
      1|2|3) printf '%s' "$reply"; return 0 ;;
      *) printf '  unrecognized choice; try again\n' >&2 ;;
    esac
  done
}

ask_yes_no() {
  local prompt="$1" default="$2"  # default = "y" or "n"
  local reply
  printf '\n%s [%s] > ' "$prompt" "$default"
  if ! IFS= read -r reply; then
    reply=""
  fi
  [[ -z "$reply" ]] && reply="$default"
  [[ "$reply" =~ ^[Yy] ]]
}

ask_path() {
  local prompt="$1" reply
  while true; do
    printf '\n%s\n> ' "$prompt"
    if ! IFS= read -r reply; then
      reply=""
    fi
    if [[ -z "$reply" ]]; then
      printf '  path is required; try again\n' >&2
      continue
    fi
    if [[ ! -d "$reply" ]]; then
      printf '  path does not exist or is not a directory; try again\n' >&2
      continue
    fi
    printf '%s' "$reply"
    return 0
  done
}

run_wizard() {
  banner "add (Agentic Driven Development) — install wizard"
  log "repo: $REPO_ROOT"

  local choice

  # Q1: agents
  choice="$(ask_choice "Install for which agents?" \
    "  1) Claude Code only
  2) Codex only
  3) Both (Claude Code + Codex)" "3")"
  case "$choice" in
    1) AGENTS="claude" ;;
    2) AGENTS="codex" ;;
    3) AGENTS="both" ;;
  esac

  # Q2: scope
  choice="$(ask_choice "Install scope?" \
    "  1) User-level (~/.claude/skills, ~/.codex/skills)
  2) Project-level (also link into <project>/.claude/skills and <project>/.agents/skills)" "1")"
  if [[ "$choice" == "2" ]]; then
    PROJECT_PATH="$(ask_path "Project path:")"
  fi

  # Confirmation
  banner "Confirmation"
  print_install_plan
  if ! ask_yes_no "Proceed?" "y"; then
    log "aborted by user"
    exit 0
  fi
  YES=1
}

# ---------- Plan printer ----------

print_install_plan() {
  log "  agents:        $AGENTS"
  if [[ -n "$PROJECT_PATH" ]]; then
    log "  project path:  $PROJECT_PATH"
  fi
  log
  log "Targets:"
  if [[ "$AGENTS" == "claude" || "$AGENTS" == "both" ]]; then
    log "  - $CLAUDE_USER_DEST/<skill>"
    [[ -n "$PROJECT_PATH" ]] && log "  - $PROJECT_PATH/.claude/skills/<skill>"
  fi
  if [[ "$AGENTS" == "codex" || "$AGENTS" == "both" ]]; then
    log "  - $CODEX_SKILLS_USER_DEST/<skill>"
    [[ -n "$PROJECT_PATH" ]] && log "  - $PROJECT_PATH/.agents/skills/<skill>"
  fi
  log
}

# ---------- Scripted-mode argument parsing ----------

parse_flags() {
  while [[ $# -gt 0 ]]; do
    HAVE_FLAGS=1
    case "$1" in
      --agents)
        [[ $# -ge 2 ]] || { err "--agents requires a value"; exit 2; }
        case "$2" in
          claude|codex|both) AGENTS="$2" ;;
          *) err "--agents must be claude|codex|both"; exit 2 ;;
        esac
        shift 2
        ;;
      --project)
        [[ $# -ge 2 ]] || { err "--project requires a path"; exit 2; }
        PROJECT_PATH="${2%/}"
        if [[ ! -d "$PROJECT_PATH" ]]; then
          err "--project path does not exist: $PROJECT_PATH"; exit 2
        fi
        shift 2
        ;;
      --yes|-y) YES=1; shift ;;
      --force)  FORCE=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help)
        sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      *)
        err "unknown argument: $1"; exit 2 ;;
    esac
  done
  # Defaults for scripted mode (any unset value)
  [[ -z "$AGENTS" ]] && AGENTS="both"
}

# ---------- Main ----------

if [[ $# -eq 0 && -t 0 ]]; then
  run_wizard
else
  parse_flags "$@"
fi

if [[ $YES -ne 1 && $DRY_RUN -ne 1 ]]; then
  banner "Install plan"
  print_install_plan
  if ! ask_yes_no "Proceed?" "y"; then
    log "aborted by user"
    exit 0
  fi
fi

[[ $DRY_RUN -eq 1 ]] && log "(dry run — no filesystem changes)"
log

# Claude
if [[ "$AGENTS" == "claude" || "$AGENTS" == "both" ]]; then
  install_claude_into "$CLAUDE_USER_DEST"
  log
  if [[ -n "$PROJECT_PATH" ]]; then
    install_claude_into "${PROJECT_PATH}/.claude/skills"
    log
  fi
fi

# Codex
if [[ "$AGENTS" == "codex" || "$AGENTS" == "both" ]]; then
  install_codex_skills_into "$CODEX_SKILLS_USER_DEST"
  log
  if [[ -n "$PROJECT_PATH" ]]; then
    install_codex_skills_into "${PROJECT_PATH}/.agents/skills"
    log
  fi
fi

log "done."
