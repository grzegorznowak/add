#!/usr/bin/env bash
# install-pi.sh — compile pi-native skills from canonical Claude source + pi fragments.
# Strips Research Board transport sections, appends pi-specific fragments
# (or replaces full skill for converge rewrites), writes to ~/.pi/agent/skills/.
#
# Detection:
#   - Fragment starts with "---" (YAML frontmatter) → full replace
#   - Fragment starts with anything else        → append to stripped Claude base
#   - No fragment                               → stripped Claude base only

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS="$REPO_ROOT/claude/skills"
PI_FRAGMENTS="$REPO_ROOT/pi-fragments"
PI_DEST="${PI_SKILLS_DIR:-$HOME/.pi/agent/skills}"
FORCE="${ADD_INSTALL_FORCE:-0}"

usage() {
  cat <<'EOF'
Usage: install-pi.sh [--force]

Compile pi skills from claude/skills plus pi-fragments into PI_SKILLS_DIR
(default: ~/.pi/agent/skills). Existing generated files are overwritten only when
their content is unchanged; use --force to replace local edits or conflicts.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'error: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

strip_transport() {
  awk '
    /^## Shared Research Board Input$/ { skip=1; next }
    /^## /                            { skip=0 }
    !skip
  '
}

ensure_dir_path() {
  local path="$1"
  if [[ -L "$path" ]]; then
    if [[ "$FORCE" == "1" ]]; then
      printf 'warn: replacing symlink %s\n' "$path" >&2
      rm -f "$path"
    else
      printf 'error: refusing to replace existing symlink %s (use --force)\n' "$path" >&2
      return 1
    fi
  elif [[ -e "$path" && ! -d "$path" ]]; then
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
  tmp="$(mktemp "${TMPDIR:-/tmp}/pi-skill.XXXXXX")"
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

fragment_is_replace() {
  local fragment="$1" first_line=""
  IFS= read -r first_line < "$fragment" || true
  [[ "$first_line" == "---" ]]
}

compile_skill() {
  local skill_name="$1" skill_file="$2" fragment="$3"
  local stripped
  stripped="$(strip_transport < "$skill_file" | sed 's/$RUNTIME_NAME/pi/g')"

  if [[ -f "$fragment" ]]; then
    if fragment_is_replace "$fragment"; then
      cat "$fragment"
    else
      printf '%s\n\n' "$stripped"
      cat "$fragment"
    fi
  else
    printf '%s\n' "$stripped"
  fi
}

ensure_dir_path "$PI_DEST"

# Pass 1 — skills with a Claude base directory
for skill_dir in "$CLAUDE_SKILLS"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  fragment="$PI_FRAGMENTS/$skill_name.md"
  compiled="$(compile_skill "$skill_name" "$skill_file" "$fragment")"

  out_dir="$PI_DEST/$skill_name"
  ensure_dir_path "$out_dir"
  write_content_if_safe "$out_dir/SKILL.md" "$compiled"
  echo "  $skill_name -> $out_dir/SKILL.md"
done

# Pass 2 — orphan fragments (no Claude base directory)
for fragment in "$PI_FRAGMENTS"/*.md; do
  [[ -f "$fragment" ]] || continue
  skill_name="$(basename "$fragment" .md)"
  [[ -d "$CLAUDE_SKILLS/$skill_name" ]] && continue  # already handled

  compiled="$(sed 's/$RUNTIME_NAME/pi/g' < "$fragment")"
  out_dir="$PI_DEST/$skill_name"
  ensure_dir_path "$out_dir"
  write_content_if_safe "$out_dir/SKILL.md" "$compiled"
  echo "  $skill_name -> $out_dir/SKILL.md (orphan fragment)"
done

echo "pi skills installed to $PI_DEST"
