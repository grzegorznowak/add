#!/usr/bin/env bash
# install-codex.sh — compile Codex skills from canonical Claude source.
# Renames kebab-case → snake_case and writes to ~/.codex/skills/.
# No fragments — Codex doesn't use pi primitives.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS="$REPO_ROOT/claude/skills"
CODEX_DEST="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
FORCE="${ADD_INSTALL_FORCE:-0}"

usage() {
  cat <<'EOF'
Usage: install-codex.sh [--force]

Compile Codex skills from claude/skills into CODEX_SKILLS_DIR (default: ~/.codex/skills).
Existing generated files are overwritten only when their content is unchanged;
use --force to replace local edits or other conflicting files.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'error: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

ensure_dir_path() {
  local path="$1"
  if [[ -e "$path" && ( -L "$path" || ! -d "$path" ) ]]; then
    if [[ "$FORCE" == "1" ]]; then
      printf 'warn: replacing conflicting path %s\n' "$path" >&2
      rm -rf "$path"
    else
      printf 'error: refusing to replace existing non-directory %s (use --force)\n' "$path" >&2
      return 1
    fi
  fi
  mkdir -p "$path"
}

write_content_if_safe() {
  local dest="$1" content="$2"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/codex-skill.XXXXXX")"
  printf '%s\n' "$content" > "$tmp"

  if [[ -e "$dest" && ! -f "$dest" ]]; then
    if [[ "$FORCE" == "1" ]]; then
      printf 'warn: replacing conflicting path %s\n' "$dest" >&2
      rm -rf "$dest"
    else
      rm -f "$tmp"
      printf 'error: refusing to replace existing non-file %s (use --force)\n' "$dest" >&2
      return 1
    fi
  fi

  if [[ -f "$dest" ]] && ! cmp -s "$tmp" "$dest"; then
    if [[ "$FORCE" == "1" ]]; then
      printf 'warn: overwriting modified generated file %s\n' "$dest" >&2
    else
      rm -f "$tmp"
      printf 'error: refusing to overwrite existing modified file %s (use --force)\n' "$dest" >&2
      return 1
    fi
  fi

  mv "$tmp" "$dest"
}

ensure_dir_path "$CODEX_DEST"

for skill_dir in "$CLAUDE_SKILLS"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  # Codex convergers inherit the Claude Research Board handoff protocol, so keep
  # executor-side board input and Research Events sections intact.
  stripped="$(cat "$skill_file")"
  codex_name="${skill_name//-/_}"

  # Transform only the first YAML frontmatter name: field to snake_case.
  stripped=$(printf '%s\n' "$stripped" | awk -v new_name="$codex_name" '
    NR == 1 && /^---$/ { fm=1; print; next }
    fm && /^---$/      { fm=0; done=1; print; next }
    fm && !done && /^name:/ { print "name: " new_name; next }
    { print }
  ')

  out_dir="$CODEX_DEST/$codex_name"
  ensure_dir_path "$out_dir"
  ensure_dir_path "$out_dir/agents"
  write_content_if_safe "$out_dir/SKILL.md" "$stripped"
  write_content_if_safe "$out_dir/agents/openai.yaml" $'policy:\n  allow_implicit_invocation: false'
  echo "  $skill_name -> $codex_name -> $out_dir/SKILL.md"
done

echo "Codex skills installed to $CODEX_DEST"
