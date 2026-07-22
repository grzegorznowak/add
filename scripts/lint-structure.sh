#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lint.sh
source "$SCRIPT_DIR/lint.sh"
lint_suite_bootstrap || exit 1
lint_collect_source_inventory
lint_structure_main() {
  echo "lint: claude/skills/"
  declare -a CLAUDE_NAMES=()
  if [[ ! -d "$CLAUDE_SKILLS" ]]; then
    fail "missing directory: $CLAUDE_SKILLS"
  else
    for skill_dir in "$CLAUDE_SKILLS"/*/; do
      [[ -d "$skill_dir" ]] || continue
      dir_name="$(basename "$skill_dir")"
      skill_md="$skill_dir/SKILL.md"

      if in_array "$dir_name" "${UNSUPPORTED_SKILLS[@]}"; then
        fail "$skill_dir: unsupported workflow skill remains in active claude/skills/"
      elif ! is_supported_active_skill "$dir_name"; then
        fail "$skill_dir: active skill is neither openspec-* nor an approved utility"
      fi

      if [[ ! -f "$skill_md" ]]; then
        fail "$skill_dir: missing SKILL.md"
        continue
      fi

      check_frontmatter_fields "$skill_md" name description disable-model-invocation argument-hint allowed-tools
      check_frontmatter_unique_keys "$skill_md"
      check_frontmatter_yaml_scalar_safety "$skill_md"
      check_frontmatter_value "$skill_md" disable-model-invocation true

      declared_name="$(extract_name "$skill_md")"
      if [[ -z "$declared_name" ]]; then
        fail "$skill_md: empty or unparsable name field"
      elif [[ "$declared_name" != "$dir_name" ]]; then
        fail "$skill_md: name '$declared_name' does not match directory '$dir_name'"
      else
        ok "$dir_name"
        CLAUDE_NAMES+=("$dir_name")
      fi
    done
  fi

  declare -a OPENSPEC_WORKFLOW_SKILLS=()
  for skill_name in "${CLAUDE_NAMES[@]:-}"; do
    [[ "$skill_name" == openspec-* ]] && OPENSPEC_WORKFLOW_SKILLS+=("$skill_name")
  done

  # Keep the output-shape manifest honest: every listed name must be active, and
  # every active OpenSpec workflow must have exactly one shape classification.
  for skill_name in "${DUAL_CAPABLE_OPENSPEC_SKILLS[@]}" "${SCALAR_ONLY_OPENSPEC_SKILLS[@]}"; do
    if ! in_array "$skill_name" "${OPENSPEC_WORKFLOW_SKILLS[@]:-}"; then
      fail "OpenSpec output-shape manifest names non-active workflow '$skill_name'"
    fi
  done
  for skill_name in "${OPENSPEC_WORKFLOW_SKILLS[@]:-}"; do
    [[ -z "$skill_name" ]] && continue
    shape_count=0
    in_array "$skill_name" "${DUAL_CAPABLE_OPENSPEC_SKILLS[@]}" && shape_count=$((shape_count + 1))
    in_array "$skill_name" "${SCALAR_ONLY_OPENSPEC_SKILLS[@]}" && shape_count=$((shape_count + 1))
    if [[ "$shape_count" -ne 1 ]]; then
      fail "active OpenSpec workflow '$skill_name' must have exactly one output-shape classification (found $shape_count)"
    fi
  done

  echo
  echo "lint: pi-fragments/"
  declare -a PI_REPLACE_NAMES=()
  declare -a PI_APPEND_NAMES=()
  if [[ ! -d "$PI_FRAGMENTS" ]]; then
    fail "missing directory: $PI_FRAGMENTS"
  else
    for fragment in "$PI_FRAGMENTS"/*.md; do
      [[ -f "$fragment" ]] || continue
      frag_name="$(basename "$fragment" .md)"
      first_line="$(head -1 "$fragment")"

      if in_array "$frag_name" "${UNSUPPORTED_SKILLS[@]}"; then
        fail "$fragment: unsupported workflow fragment remains in active pi-fragments/"
      elif ! is_supported_pi_fragment "$frag_name"; then
        fail "$fragment: active pi fragment is neither openspec-* nor an approved utility fragment"
      fi

      if [[ "$first_line" == "---" ]]; then
        # Replace fragment: must have valid frontmatter and name field
        check_frontmatter_unique_keys "$fragment"
        check_frontmatter_yaml_scalar_safety "$fragment"
        declared_name="$(extract_name "$fragment")"
        if [[ -z "$declared_name" ]]; then
          fail "$fragment: replace fragment missing 'name:' in frontmatter"
        elif [[ "$declared_name" != "$frag_name" ]]; then
          fail "$fragment: name '$declared_name' does not match filename '$frag_name'"
        else
          ok "$frag_name (replace)"
          PI_REPLACE_NAMES+=("$frag_name")
        fi
      else
        # Append fragment: must have matching Claude skill
        if [[ -d "$CLAUDE_SKILLS/$frag_name" ]]; then
          ok "$frag_name (append)"
          PI_APPEND_NAMES+=("$frag_name")
        else
          fail "$fragment: append fragment has no matching claude/skills/$frag_name/"
        fi
      fi
    done
  fi

}

lint_repository_hygiene() {
  echo
  echo "lint: no cure_workspace absolute paths"
  if grep -RIn 'cure_workspace' "$CLAUDE_SKILLS" "$PI_FRAGMENTS" "$REPO_ROOT/docs" "$REPO_ROOT/README.md" 2>/dev/null; then
    fail "found 'cure_workspace' references (above) — strip project-specific paths"
  else
    ok "no cure_workspace leakage"
  fi
}

case "${1:-all}" in
  --main) lint_structure_main ;;
  --repository-hygiene) lint_repository_hygiene ;;
  all) lint_structure_main; lint_repository_hygiene ;;
  *) printf 'usage: %s [--main|--repository-hygiene]\n' "$0" >&2; exit 2 ;;
esac
exit "$FAIL"
