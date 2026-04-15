#!/usr/bin/env bash
# lint.sh — validate that the repo is in a shippable state.
#
# Checks:
#   1. Frontmatter shape on every Claude SKILL.md and every Codex SKILL.md.
#   2. agents/openai.yaml present on every Codex skill with
#      allow_implicit_invocation: false.
#   3. Pairing — every Claude skill has a Codex skill counterpart and vice
#      versa, except for entries on the explicit known-singletons list.
#   4. Phase-heading parity between paired files (drift signal).
#   5. Codex skill directory name matches the `name:` field inside its
#      SKILL.md.
#   6. Generated codex/prompts/ files are fresh
#      (scripts/regen-prompts.sh --check).
#   7. No `cure_workspace` absolute paths anywhere.
#   8. Claude skill directory name matches the `name:` field inside its
#      SKILL.md.
#
# Exit codes:
#   0 — clean
#   1 — at least one finding

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS="${REPO_ROOT}/claude/skills"
CODEX_SKILLS="${REPO_ROOT}/codex/skills"
CODEX_PROMPTS="${REPO_ROOT}/codex/prompts"

# Singletons: entries that legitimately only exist on one side. Names use the
# Codex form (underscored). The Claude form is the same string with underscores
# converted to hyphens.
SINGLETONS_CODEX_ONLY=(memorize)
SINGLETONS_CLAUDE_ONLY=()

FAIL=0
fail() { printf 'FAIL %s\n' "$*" >&2; FAIL=1; }
ok()   { printf 'ok   %s\n' "$*"; }

# Convert "epic-claim" to "epic_claim"
hyphen_to_underscore() { printf '%s' "${1//-/_}"; }
# Convert "epic_claim" to "epic-claim"
underscore_to_hyphen() { printf '%s' "${1//_/-}"; }

in_array() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

# $1 = file, $2..$N = required field names
check_frontmatter_fields() {
  local file="$1"; shift
  local missing=()
  local field
  for field in "$@"; do
    if ! grep -Eq "^${field}:" "$file"; then
      missing+=("$field")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "$file: missing frontmatter field(s): ${missing[*]}"
  fi
}

# Extract the value of `name:` from a SKILL.md frontmatter
extract_name() {
  local file="$1"
  awk '
    /^---[[:space:]]*$/ { fm = !fm; next }
    fm && /^name:/ {
      sub(/^name:[[:space:]]*/, "")
      gsub(/^["'\'']|["'\'']$/, "")
      print
      exit
    }
  ' "$file"
}

# Extract the set of `## Phase N — ...` heading lines from a markdown file
extract_phase_headings() {
  local file="$1"
  grep -E '^## Phase [0-9]+ ' "$file" | sed 's/[[:space:]]*$//' || true
}

echo "lint: claude/skills/"
declare -a CLAUDE_NAMES=()
if [[ ! -d "$CLAUDE_SKILLS" ]]; then
  fail "missing directory: $CLAUDE_SKILLS"
else
  for skill_dir in "$CLAUDE_SKILLS"/*/; do
    [[ -d "$skill_dir" ]] || continue
    dir_name="$(basename "$skill_dir")"
    skill_md="$skill_dir/SKILL.md"

    if [[ ! -f "$skill_md" ]]; then
      fail "$skill_dir: missing SKILL.md"
      continue
    fi

    check_frontmatter_fields "$skill_md" name description disable-model-invocation argument-hint allowed-tools

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

echo
echo "lint: codex/skills/"
declare -a CODEX_NAMES=()
if [[ ! -d "$CODEX_SKILLS" ]]; then
  fail "missing directory: $CODEX_SKILLS"
else
  for skill_dir in "$CODEX_SKILLS"/*/; do
    [[ -d "$skill_dir" ]] || continue
    dir_name="$(basename "$skill_dir")"
    skill_md="$skill_dir/SKILL.md"
    openai_yaml="$skill_dir/agents/openai.yaml"

    if [[ ! -f "$skill_md" ]]; then
      fail "$skill_dir: missing SKILL.md"
      continue
    fi

    check_frontmatter_fields "$skill_md" name description

    declared_name="$(extract_name "$skill_md")"
    if [[ -z "$declared_name" ]]; then
      fail "$skill_md: empty or unparsable name field"
      continue
    elif [[ "$declared_name" != "$dir_name" ]]; then
      fail "$skill_md: name '$declared_name' does not match directory '$dir_name'"
      continue
    fi

    if [[ ! -f "$openai_yaml" ]]; then
      fail "$skill_dir: missing agents/openai.yaml"
      continue
    fi
    if ! grep -Eq '^[[:space:]]*allow_implicit_invocation:[[:space:]]*false' "$openai_yaml"; then
      fail "$openai_yaml: missing or wrong 'allow_implicit_invocation: false'"
      continue
    fi

    ok "$dir_name"
    CODEX_NAMES+=("$dir_name")
  done
fi

echo
echo "lint: pairing"
for cn in "${CLAUDE_NAMES[@]:-}"; do
  [[ -z "$cn" ]] && continue
  expected_codex="$(hyphen_to_underscore "$cn")"
  if in_array "$expected_codex" "${CODEX_NAMES[@]:-}"; then
    ok "$cn ↔ $expected_codex"
  elif in_array "$expected_codex" "${SINGLETONS_CLAUDE_ONLY[@]:-}"; then
    ok "$cn (claude-only singleton)"
  else
    fail "claude skill '$cn' has no codex counterpart (expected '$expected_codex')"
  fi
done
for cn in "${CODEX_NAMES[@]:-}"; do
  [[ -z "$cn" ]] && continue
  expected_claude="$(underscore_to_hyphen "$cn")"
  if in_array "$expected_claude" "${CLAUDE_NAMES[@]:-}"; then
    : # already reported in the previous loop
  elif in_array "$cn" "${SINGLETONS_CODEX_ONLY[@]:-}"; then
    ok "$cn (codex-only singleton)"
  else
    fail "codex prompt '$cn' has no claude counterpart (expected '$expected_claude')"
  fi
done

echo
echo "lint: phase-heading parity"
for cn in "${CLAUDE_NAMES[@]:-}"; do
  [[ -z "$cn" ]] && continue
  expected_codex="$(hyphen_to_underscore "$cn")"
  in_array "$expected_codex" "${CODEX_NAMES[@]:-}" || continue
  claude_md="$CLAUDE_SKILLS/$cn/SKILL.md"
  codex_md="$CODEX_SKILLS/$expected_codex/SKILL.md"
  claude_phases="$(extract_phase_headings "$claude_md" | sed -E 's/[[:space:]]+/ /g')"
  codex_phases="$(extract_phase_headings "$codex_md" | sed -E 's/[[:space:]]+/ /g')"
  if [[ "$claude_phases" != "$codex_phases" ]]; then
    fail "$cn: phase headings differ between claude and codex versions"
  else
    ok "$cn (phases aligned)"
  fi
done

echo
echo "lint: codex/prompts/ freshness"
if bash "$REPO_ROOT/scripts/regen-prompts.sh" --check >/dev/null 2>&1; then
  ok "codex/prompts/ in sync with codex/skills/"
else
  fail "codex/prompts/ is stale. Run: bash scripts/regen-prompts.sh"
  bash "$REPO_ROOT/scripts/regen-prompts.sh" --check 2>&1 | sed 's/^/  /' >&2 || true
fi

echo
echo "lint: no cure_workspace absolute paths"
if grep -RIn 'cure_workspace' "$CLAUDE_SKILLS" "$CODEX_SKILLS" "$CODEX_PROMPTS" "$REPO_ROOT/docs" "$REPO_ROOT/README.md" 2>/dev/null; then
  fail "found 'cure_workspace' references (above) — strip project-specific paths"
else
  ok "no cure_workspace leakage"
fi

echo
if [[ $FAIL -ne 0 ]]; then
  echo "lint: FAILED"
  exit 1
fi
echo "lint: PASSED"
