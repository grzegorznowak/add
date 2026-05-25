#!/usr/bin/env bash
# install-pi.sh — compile pi-native skills from canonical Claude source + pi fragments.
# Strips Research Board / Research Events transport sections, appends pi-specific
# fragment (or replaces full skill for converge rewrites), writes to ~/.pi/skills/.
#
# Detection:
#   - Fragment starts with "---" (YAML frontmatter) → full replace
#   - Fragment starts with anything else        → append to stripped Claude base
#   - No fragment                               → stripped Claude base only

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS="$REPO_ROOT/claude/skills"
PI_FRAGMENTS="$REPO_ROOT/pi-fragments"
PI_DEST="${PI_SKILLS_DIR:-$HOME/.pi/skills}"

strip_transport() {
  awk '
    /^## Shared Research Board Input$/ { skip=1; next }
    /^## Research Events$/            { skip=1; next }
    /^## /                            { skip=0 }
    !skip
  '
}

mkdir -p "$PI_DEST"

# Pass 1 — skills with a Claude base directory
for skill_dir in "$CLAUDE_SKILLS"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  stripped=$(strip_transport < "$skill_file")
  fragment="$PI_FRAGMENTS/$skill_name.md"

  if [[ -f "$fragment" ]]; then
    if head -1 "$fragment" | grep -q '^---$'; then
      # replace mode: fragment IS the full skill
      cat "$fragment"
    else
      # append mode: stripped Claude + fragment
      printf '%s\n\n' "$stripped"
      cat "$fragment"
    fi
  else
    printf '%s\n' "$stripped"
  fi > /tmp/pi-skill-tmp.md

  out_dir="$PI_DEST/$skill_name"
  mkdir -p "$out_dir"
  mv /tmp/pi-skill-tmp.md "$out_dir/SKILL.md"
  echo "  $skill_name -> $out_dir/SKILL.md"
done

# Pass 2 — orphan fragments (no Claude base directory)
for fragment in "$PI_FRAGMENTS"/*.md; do
  [[ -f "$fragment" ]] || continue
  skill_name="$(basename "$fragment" .md)"
  [[ -d "$CLAUDE_SKILLS/$skill_name" ]] && continue  # already handled

  out_dir="$PI_DEST/$skill_name"
  mkdir -p "$out_dir"
  cp "$fragment" "$out_dir/SKILL.md"
  echo "  $skill_name -> $out_dir/SKILL.md (orphan fragment)"
done

echo "pi skills installed to $PI_DEST"
