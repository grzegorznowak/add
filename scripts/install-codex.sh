#!/usr/bin/env bash
# install-codex.sh — compile Codex skills from canonical Claude source.
# Strips Research Board / Research Events transport sections, renames
# kebab-case → snake_case, writes to ~/.codex/skills/.
# No fragments — Codex doesn't use pi primitives.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS="$REPO_ROOT/claude/skills"
CODEX_DEST="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"

strip_transport() {
  awk '
    /^## Shared Research Board Input$/ { skip=1; next }
    /^## Research Events$/            { skip=1; next }
    /^## /                            { skip=0 }
    !skip
  '
}

mkdir -p "$CODEX_DEST"

for skill_dir in "$CLAUDE_SKILLS"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  stripped=$(strip_transport < "$skill_file")
  codex_name="${skill_name//-/_}"

  out_dir="$CODEX_DEST/$codex_name"
  mkdir -p "$out_dir/agents"
  printf '%s\n' "$stripped" > "$out_dir/SKILL.md"
  printf 'policy:\n  allow_implicit_invocation: false\n' > "$out_dir/agents/openai.yaml"
  echo "  $skill_name -> $codex_name -> $out_dir/SKILL.md"
done

echo "Codex skills installed to $CODEX_DEST"
