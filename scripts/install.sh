#!/usr/bin/env bash
# install.sh — install Claude, Codex, and pi skills from this repo into the
# user's agent runtime directories. Idempotent.
#
# Two modes:
#   - Wizard (default on TTY, no args): asks which agents and scope to install.
#   - Scripted (any args, or non-TTY): flag-driven for CI / devcontainers.
#
# Scripted-mode flags:
#   --agents <claude|codex|pi|both|all>
#                                    runtimes to install (default: both;
#                                    both = Claude+Codex, all includes pi)
#   --project <path>                 also install into project scope
#                                    (<path>/.claude/skills/ for Claude,
#                                     <path>/.agents/skills/ for Codex)
#   --yes                            skip the confirmation prompt
#   --force                          overwrite non-symlink Claude targets and
#                                    modified generated Codex/pi files
#   --prune-unsupported              remove recognized unsupported workflow skills
#                                    (archived legacy or renamed)
#   --dry-run                        show what would happen, change nothing
#   --help                           show this message

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS_SRC="${REPO_ROOT}/claude/skills"

CLAUDE_USER_DEST="${HOME}/.claude/skills"
CODEX_SKILLS_USER_DEST="${HOME}/.codex/skills"
PI_SKILLS_USER_DEST="${HOME}/.pi/agent/skills"

AGENTS=""           # claude | codex | pi | both | all
PROJECT_PATH=""
YES=0
FORCE=0
PRUNE_UNSUPPORTED=0
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

agent_selected() {
  local agent="$1"
  [[ "$AGENTS" == "all" ]] && return 0
  [[ "$AGENTS" == "$agent" ]] && return 0
  [[ "$AGENTS" == "both" && ( "$agent" == "claude" || "$agent" == "codex" ) ]] && return 0
  return 1
}

declare -a UNSUPPORTED_SKILLS=(
  epic-feedback
  epic-plan
  epic-pr
  epic-squash
  epic-story-claim
  epic-story-converge
  epic-story-plan
  epic-story-plan-converge
  epic-story-plan-resume
  epic-story-plan-review
  epic-story-pr
  epic-story-resume
  epic-story-review
  openspec-epic-plan
)

resolve_symlink_target() {
  local link_path="$1" target link_dir
  target="$(readlink "$link_path")" || return 1
  if [[ "$target" != /* ]]; then
    link_dir="$(cd "$(dirname "$link_path")" && pwd -P)" || return 1
    target="$link_dir/$target"
  fi
  realpath -m "$target"
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
  if [[ $PRUNE_UNSUPPORTED -eq 1 ]]; then
    prune_claude_unsupported_into "$dest_root"
  fi
}

prune_claude_unsupported_into() {
  local dest_root="$1" name dest resolved
  log "Claude prune unsupported → $dest_root"
  if [[ ! -d "$dest_root" ]]; then
    log "  skip  $dest_root (not present)"
    return 0
  fi

  for name in "${UNSUPPORTED_SKILLS[@]}"; do
    dest="$dest_root/$name"
    [[ -e "$dest" || -L "$dest" ]] || continue

    if [[ ! -L "$dest" ]]; then
      warn "skip  $dest (unsupported workflow name exists but is not a symlink)"
      continue
    fi

    resolved="$(resolve_symlink_target "$dest" 2>/dev/null || true)"
    if [[ "$resolved" == "$REPO_ROOT" || "$resolved" == "$REPO_ROOT/"* ]]; then
      log "  prune $dest"
      run rm "$dest"
    else
      warn "skip  $dest (symlink points outside this repo: ${resolved:-unresolved})"
    fi
  done
}

install_codex_skills_into() {
  local dest_root="$1"
  local args=()
  [[ $PRUNE_UNSUPPORTED -eq 1 ]] && args+=(--prune-unsupported)
  [[ $DRY_RUN -eq 1 ]] && args+=(--dry-run)

  ensure_dir "$dest_root"
  log "Codex skills (generated) → $dest_root"
  log "  compiler $REPO_ROOT/scripts/install-codex.sh ${args[*]:-}"
  if ! env "CODEX_SKILLS_DIR=$dest_root" "ADD_INSTALL_FORCE=$FORCE" "ADD_INSTALL_DRY_RUN=$DRY_RUN" "$REPO_ROOT/scripts/install-codex.sh" "${args[@]}"; then
    err "install-codex.sh failed"
    exit 1
  fi
}

install_pi_skills_into() {
  local dest_root="$1"
  local args=()
  [[ $PRUNE_UNSUPPORTED -eq 1 ]] && args+=(--prune-unsupported)
  [[ $DRY_RUN -eq 1 ]] && args+=(--dry-run)

  ensure_dir "$dest_root"
  log "pi skills (generated) → $dest_root"
  log "  compiler $REPO_ROOT/scripts/install-pi.sh ${args[*]:-}"
  if ! env "PI_SKILLS_DIR=$dest_root" "ADD_INSTALL_FORCE=$FORCE" "ADD_INSTALL_DRY_RUN=$DRY_RUN" "$REPO_ROOT/scripts/install-pi.sh" "${args[@]}"; then
    err "install-pi.sh failed"
    exit 1
  fi
}

# ---------- Wizard ----------

# $1 = prompt, $2 = options string (e.g. "1=foo  2=bar"), $3 = default key,
# $4 = allowed keys regex alternation (e.g. "1|2|3"). Echoes chosen key.
ask_choice() {
  local prompt="$1" options="$2" default="$3" allowed="${4:-1|2|3}"
  local reply
  while true; do
    printf '\n%s\n' "$prompt"
    printf '%s\n' "$options"
    printf '[default: %s] > ' "$default"
    if ! IFS= read -r reply; then
      reply=""
    fi
    [[ -z "$reply" ]] && reply="$default"
    if [[ "$reply" =~ ^($allowed)$ ]]; then
      printf '%s' "$reply"
      return 0
    fi
    printf '  unrecognized choice; try again\n' >&2
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
  3) pi only
  4) All (Claude Code + Codex + pi)" "4" "1|2|3|4")"
  case "$choice" in
    1) AGENTS="claude" ;;
    2) AGENTS="codex" ;;
    3) AGENTS="pi" ;;
    4) AGENTS="all" ;;
  esac

  # Q2: scope
  choice="$(ask_choice "Install scope?" \
    "  1) User-level (~/.claude/skills, ~/.codex/skills, ~/.pi/agent/skills)
  2) Project-level (also link into <project>/.claude/skills and <project>/.agents/skills; pi remains user-level)" "1" "1|2")"
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
  if [[ $PRUNE_UNSUPPORTED -eq 1 ]]; then
    log "  prune:        recognized unsupported workflow skills"
  else
    log "  prune:        no"
  fi
  log
  log "Targets:"
  if agent_selected claude; then
    log "  - $CLAUDE_USER_DEST/<skill>"
    [[ -n "$PROJECT_PATH" ]] && log "  - $PROJECT_PATH/.claude/skills/<skill>"
  fi
  if agent_selected codex; then
    log "  - $CODEX_SKILLS_USER_DEST/<skill>"
    [[ -n "$PROJECT_PATH" ]] && log "  - $PROJECT_PATH/.agents/skills/<skill>"
  fi
  if agent_selected pi; then
    log "  - $PI_SKILLS_USER_DEST/<skill>"
    [[ -n "$PROJECT_PATH" ]] && log "    (pi project-level skills are not supported; using user-level only)"
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
          claude|codex|pi|both|all) AGENTS="$2" ;;
          *) err "--agents must be claude|codex|pi|both|all"; exit 2 ;;
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
      --prune-unsupported) PRUNE_UNSUPPORTED=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help)
        awk '
          NR == 1 { next }
          /^#/ { sub(/^# ?/, ""); print; next }
          { exit }
        ' "$0"
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

if [[ ! -t 0 && $YES -ne 1 && $DRY_RUN -ne 1 ]]; then
  err "non-interactive installs require --yes (or --dry-run)"
  exit 2
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
if agent_selected claude; then
  install_claude_into "$CLAUDE_USER_DEST"
  log
  if [[ -n "$PROJECT_PATH" ]]; then
    install_claude_into "${PROJECT_PATH}/.claude/skills"
    log
  fi
fi

# Codex
if agent_selected codex; then
  install_codex_skills_into "$CODEX_SKILLS_USER_DEST"
  log
  if [[ -n "$PROJECT_PATH" ]]; then
    install_codex_skills_into "${PROJECT_PATH}/.agents/skills"
    log
  fi
fi

# pi
if agent_selected pi; then
  install_pi_skills_into "$PI_SKILLS_USER_DEST"
  log
fi

log "done."
