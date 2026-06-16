#!/usr/bin/env bash
# lint.sh — validate that the repo is in a shippable state.
#
# Checks:
#   1. Frontmatter shape on every Claude SKILL.md.
#   2. Claude skill directory name matches the `name:` field.
#   3. pi-fragments/: append fragments have no YAML frontmatter;
#      replace fragments DO have YAML frontmatter; names match.
#   4. install-codex.sh and install-pi.sh run cleanly against claude/skills/.
#   5. Frontmatter shape on generated Codex SKILL.md and generated Pi SKILL.md.
#   6. Generated Codex skills have valid agents/openai.yaml.
#   7. Generated Codex skills preserve Shared Research Board Input contracts.
#   8. Generated Pi skills have no Shared Research Board Input sections.
#   9. OpenSpec skills use notebook terminology instead of Research Board terminology.
#   10. Pairing — every Claude skill has a Codex and Pi counterpart.
#   11. Phase-heading parity between Claude and generated Codex skills.
#   12. Main installer Codex dry-run uses the generated compiler path.
#   13. Non-TTY installer mutation requires explicit --yes.
#   14. Generated installers protect modified existing files unless forced.
#   15. Codex skills do not carry prompt-era compatibility scaffolding.
#   16. No `cure_workspace` absolute paths anywhere.
#   17. Generated Codex OpenSpec skills preserve every auxiliary argument contract.
#   18. Pi OpenSpec fragments do not persist review/proof/lifecycle authority to notebooks.
#   19. OpenSpec skills do not require the removed research-event response section.
#
# Exit codes:
#   0 — clean
#   1 — at least one finding

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS="${REPO_ROOT}/claude/skills"
PI_FRAGMENTS="${REPO_ROOT}/pi-fragments"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
CODEX_SKILLS="$TMPDIR/codex-skills"
PI_SKILLS="$TMPDIR/pi-skills"

FAIL=0
fail() { printf 'FAIL %s\n' "$*" >&2; FAIL=1; }
ok()   { printf 'ok   %s\n' "$*"; }

# Convert "epic-story-claim" to "epic_story_claim"
hyphen_to_underscore() { printf '%s' "${1//-/_}"; }
# Convert "epic_story_claim" to "epic-story-claim"
underscore_to_hyphen() { printf '%s' "${1//_/-}"; }

in_array() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
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

declare -a UNSUPPORTED_CODEX_SKILLS=(
  epic_feedback
  epic_plan
  epic_pr
  epic_squash
  epic_story_claim
  epic_story_converge
  epic_story_plan
  epic_story_plan_converge
  epic_story_plan_resume
  epic_story_plan_review
  epic_story_pr
  epic_story_resume
  epic_story_review
  openspec_epic_plan
)

is_supported_active_skill() {
  local name="$1"
  [[ "$name" == openspec-* ]] && return 0
  case "$name" in
    grillme|memorize|merge-conflict-analysis) return 0 ;;
    *) return 1 ;;
  esac
}

is_supported_pi_fragment() {
  local name="$1"
  [[ "$name" == openspec-* || "$name" == memorize ]]
}

# Extract a field value from the first YAML frontmatter block.
frontmatter_value() {
  local file="$1" field="$2"
  awk -v field="$field" '
    NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
    NR == 1 { exit }
    fm && /^---[[:space:]]*$/ { exit }
    fm {
      pattern = "^" field ":[[:space:]]*"
      if ($0 ~ pattern) {
        sub(pattern, "")
        gsub(/^["'\''"]|["'\''"]$/, "")
        print
        exit
      }
    }
  ' "$file"
}

frontmatter_has_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
    NR == 1 { exit 1 }
    fm && /^---[[:space:]]*$/ { exit 1 }
    fm {
      pattern = "^" field ":[[:space:]]*"
      if ($0 ~ pattern) { found = 1; exit 0 }
    }
    END { exit found ? 0 : 1 }
  ' "$file"
}

# $1 = file, $2..$N = required field names
check_frontmatter_fields() {
  local file="$1"; shift
  local missing=()
  local field
  for field in "$@"; do
    if ! frontmatter_has_field "$file" "$field"; then
      missing+=("$field")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "$file: missing frontmatter field(s): ${missing[*]}"
  fi
}

check_frontmatter_value() {
  local file="$1" field="$2" expected="$3" actual
  actual="$(frontmatter_value "$file" "$field")"
  if [[ "$actual" != "$expected" ]]; then
    fail "$file: frontmatter field '$field' must be '$expected' (got '${actual:-<missing>}')"
  fi
}

# Extract the value of `name:` from a SKILL.md frontmatter
extract_name() {
  frontmatter_value "$1" name
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

echo
echo "lint: generating codex skills (install-codex.sh)"
if ! CODEX_SKILLS_DIR="$CODEX_SKILLS" "$REPO_ROOT/scripts/install-codex.sh" >/dev/null 2>&1; then
  fail "install-codex.sh failed"
else
  ok "install-codex.sh succeeded"
fi

echo
echo "lint: generating pi skills (install-pi.sh)"
if ! PI_SKILLS_DIR="$PI_SKILLS" "$REPO_ROOT/scripts/install-pi.sh" >/dev/null 2>&1; then
  fail "install-pi.sh failed"
else
  ok "install-pi.sh succeeded"
fi

echo
echo "lint: generated codex/skills/"
declare -a CODEX_NAMES=()
for skill_dir in "$CODEX_SKILLS"/*/; do
  [[ -d "$skill_dir" ]] || continue
  dir_name="$(basename "$skill_dir")"
  skill_md="$skill_dir/SKILL.md"
  openai_yaml="$skill_dir/agents/openai.yaml"

  if in_array "$dir_name" "${UNSUPPORTED_CODEX_SKILLS[@]}"; then
    fail "$skill_dir: unsupported workflow skill was generated for Codex"
  elif ! is_supported_active_skill "$(underscore_to_hyphen "$dir_name")"; then
    fail "$skill_dir: generated Codex skill is neither openspec_* nor an approved utility"
  fi

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

echo
echo "lint: generated pi/skills/"
declare -a PI_GEN_NAMES=()
for skill_dir in "$PI_SKILLS"/*/; do
  [[ -d "$skill_dir" ]] || continue
  dir_name="$(basename "$skill_dir")"
  skill_md="$skill_dir/SKILL.md"

  if in_array "$dir_name" "${UNSUPPORTED_SKILLS[@]}"; then
    fail "$skill_dir: unsupported workflow skill was generated for pi"
  elif ! is_supported_active_skill "$dir_name"; then
    fail "$skill_dir: generated pi skill is neither openspec-* nor an approved utility"
  fi

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

  ok "$dir_name"
  PI_GEN_NAMES+=("$dir_name")
done

echo
echo "lint: research board contracts in generated skills"
for cn in "${CLAUDE_NAMES[@]:-}"; do
  [[ -z "$cn" ]] && continue
  expected_codex="$(hyphen_to_underscore "$cn")"
  claude_md="$CLAUDE_SKILLS/$cn/SKILL.md"
  codex_md="$CODEX_SKILLS/$expected_codex/SKILL.md"
  [[ -f "$codex_md" ]] || continue
  if grep -qE '^##+ Shared Research Board Input$' "$claude_md"; then
    if grep -qE '^##+ Shared Research Board Input$' "$codex_md"; then
      ok "codex: $expected_codex preserves Shared Research Board Input"
    else
      fail "$expected_codex: missing generated Codex Shared Research Board Input section"
    fi
  fi
done
if grep -RlE '^##+ Shared Research Board Input$' "$PI_SKILLS" 2>/dev/null; then
  fail "generated pi skills still contain Shared Research Board Input section"
else
  ok "pi: no Shared Research Board Input"
fi

echo
echo "lint: OpenSpec notebook terminology"
if grep -RInE 'Shared Research Board|Research Board|board-refresh|board entries|board entry|provided board' "$CLAUDE_SKILLS"/openspec-* "$PI_FRAGMENTS"/openspec-*.md "$CODEX_SKILLS"/openspec_* "$PI_SKILLS"/openspec-* 2>/dev/null; then
  fail "OpenSpec source, fragments, or generated skills still use Research Board terminology (matches above)"
else
  ok "OpenSpec skills use notebook terminology"
fi

echo
echo "lint: OpenSpec notebook prompt boundaries"
bad_notebook_prompt_pattern='complete inline note''book snap''shot|whole relevant note''book con''text|inline the note''book|f''ull note''book|note''book con''text becomes too large to pass in f''ull'
if grep -RInE "$bad_notebook_prompt_pattern" "$CLAUDE_SKILLS"/openspec-* "$PI_FRAGMENTS"/openspec-*.md "$CODEX_SKILLS"/openspec_* "$PI_SKILLS"/openspec-* 2>/dev/null; then
  fail "OpenSpec source, fragments, or generated skills ask for oversized notebook prompt context (matches above)"
else
  ok "OpenSpec notebook prompts use references or compact excerpts"
fi

echo
echo "lint: OpenSpec removed research-event response contract"
bad_research_event_pattern='Research Ev''ents|research ev''ents'
if grep -RInE "$bad_research_event_pattern" "$CLAUDE_SKILLS"/openspec-* "$PI_FRAGMENTS"/openspec-*.md "$CODEX_SKILLS"/openspec_* "$PI_SKILLS"/openspec-* 2>/dev/null; then
  fail "OpenSpec source, fragments, or generated skills still require removed research-event response contract (matches above)"
else
  ok "OpenSpec skills avoid the removed research-event response contract"
fi

echo
echo "lint: pairing (claude ↔ codex)"
for cn in "${CLAUDE_NAMES[@]:-}"; do
  [[ -z "$cn" ]] && continue
  expected="$(hyphen_to_underscore "$cn")"
  if in_array "$expected" "${CODEX_NAMES[@]:-}"; then
    ok "$cn ↔ $expected"
  else
    fail "claude skill '$cn' has no generated codex counterpart (expected '$expected')"
  fi
done

echo
echo "lint: pairing (claude ↔ pi)"
for cn in "${CLAUDE_NAMES[@]:-}"; do
  [[ -z "$cn" ]] && continue
  if in_array "$cn" "${PI_GEN_NAMES[@]:-}"; then
    ok "$cn ↔ $cn"
  else
    fail "claude skill '$cn' has no generated pi counterpart"
  fi
done

echo
echo "lint: phase-heading parity (claude ↔ codex)"
for cn in "${CLAUDE_NAMES[@]:-}"; do
  [[ -z "$cn" ]] && continue
  expected_codex="$(hyphen_to_underscore "$cn")"
  in_array "$expected_codex" "${CODEX_NAMES[@]:-}" || continue
  claude_md="$CLAUDE_SKILLS/$cn/SKILL.md"
  codex_md="$CODEX_SKILLS/$expected_codex/SKILL.md"
  claude_phases="$(extract_phase_headings "$claude_md" | sed -E 's/[[:space:]]+/ /g')"
  codex_phases="$(extract_phase_headings "$codex_md" | sed -E 's/[[:space:]]+/ /g')"
  if [[ "$claude_phases" != "$codex_phases" ]]; then
    fail "$cn: phase headings differ between claude and generated codex versions"
  else
    ok "$cn (phases aligned)"
  fi
done

echo
echo "lint: main installer dry-run (codex)"
installer_dry_run_output=""
if ! installer_dry_run_output="$("$REPO_ROOT/scripts/install.sh" --agents codex --yes --dry-run 2>&1)"; then
  fail "scripts/install.sh --agents codex --yes --dry-run failed"
elif grep -Fq "$REPO_ROOT/codex/skills" <<<"$installer_dry_run_output"; then
  fail "scripts/install.sh codex dry-run still references deleted $REPO_ROOT/codex/skills"
elif ! grep -Fq "install-codex.sh" <<<"$installer_dry_run_output"; then
  fail "scripts/install.sh codex dry-run did not route through install-codex.sh"
else
  ok "install.sh codex dry-run uses install-codex.sh"
fi

echo
echo "lint: non-tty installer safety"
non_tty_output=""
if non_tty_output="$(HOME="$TMPDIR/non-tty-home" "$REPO_ROOT/scripts/install.sh" </dev/null 2>&1)"; then
  fail "scripts/install.sh </dev/null succeeded without --yes"
elif grep -Fq "non-interactive installs require --yes" <<<"$non_tty_output"; then
  ok "non-tty install requires --yes"
else
  fail "scripts/install.sh </dev/null failed for an unexpected reason: $non_tty_output"
fi

echo
echo "lint: generated installer overwrite safety"
codex_conflict="$TMPDIR/codex-conflict"
mkdir -p "$codex_conflict/openspec_story_claim/agents"
printf 'local codex edit\n' > "$codex_conflict/openspec_story_claim/SKILL.md"
printf 'policy:\n  allow_implicit_invocation: false\n' > "$codex_conflict/openspec_story_claim/agents/openai.yaml"
if CODEX_SKILLS_DIR="$codex_conflict" "$REPO_ROOT/scripts/install-codex.sh" >/dev/null 2>&1; then
  fail "install-codex.sh overwrote modified existing SKILL.md without --force"
else
  ok "install-codex.sh protects modified existing SKILL.md"
fi
pi_conflict="$TMPDIR/pi-conflict"
mkdir -p "$pi_conflict/openspec-story-claim"
printf 'local pi edit\n' > "$pi_conflict/openspec-story-claim/SKILL.md"
if PI_SKILLS_DIR="$pi_conflict" "$REPO_ROOT/scripts/install-pi.sh" >/dev/null 2>&1; then
  fail "install-pi.sh overwrote modified existing SKILL.md without --force"
else
  ok "install-pi.sh protects modified existing SKILL.md"
fi

echo
echo "lint: explicit unsupported prune"
codex_no_prune="$TMPDIR/codex-no-prune"
mkdir -p "$codex_no_prune/epic_story_claim/agents"
printf '%s\n' '---' 'name: epic_story_claim' 'description: legacy' '---' > "$codex_no_prune/epic_story_claim/SKILL.md"
printf 'policy:\n  allow_implicit_invocation: false\n' > "$codex_no_prune/epic_story_claim/agents/openai.yaml"
if CODEX_SKILLS_DIR="$codex_no_prune" "$REPO_ROOT/scripts/install-codex.sh" >/dev/null 2>&1 && [[ -d "$codex_no_prune/epic_story_claim" ]]; then
  ok "install-codex.sh leaves unsupported dirs without --prune-unsupported"
else
  fail "install-codex.sh pruned or failed on unsupported dir without --prune-unsupported"
fi

codex_prune="$TMPDIR/codex-prune"
mkdir -p "$codex_prune/epic_story_claim/agents" "$codex_prune/epic_story_resume/agents" "$codex_prune/openspec_epic_plan/agents"
printf '%s\n' '---' 'name: epic_story_claim' 'description: legacy' '---' > "$codex_prune/epic_story_claim/SKILL.md"
printf '%s\n' '---' 'name: not_epic_story_resume' 'description: local' '---' > "$codex_prune/epic_story_resume/SKILL.md"
printf '%s\n' '---' 'name: openspec_epic_plan' 'description: renamed' '---' > "$codex_prune/openspec_epic_plan/SKILL.md"
printf 'policy:\n  allow_implicit_invocation: false\n' > "$codex_prune/epic_story_claim/agents/openai.yaml"
if CODEX_SKILLS_DIR="$codex_prune" "$REPO_ROOT/scripts/install-codex.sh" --prune-unsupported >/dev/null 2>&1; then
  if [[ ! -e "$codex_prune/epic_story_claim" && ! -e "$codex_prune/openspec_epic_plan" && -d "$codex_prune/epic_story_resume" ]]; then
    ok "install-codex.sh --prune-unsupported removes only verified unsupported dirs"
  else
    fail "install-codex.sh --prune-unsupported did not prune/skip expected Codex dirs"
  fi
else
  fail "install-codex.sh --prune-unsupported failed"
fi

pi_no_prune="$TMPDIR/pi-no-prune"
mkdir -p "$pi_no_prune/epic-story-claim"
printf '%s\n' '---' 'name: epic-story-claim' 'description: legacy' '---' > "$pi_no_prune/epic-story-claim/SKILL.md"
if PI_SKILLS_DIR="$pi_no_prune" "$REPO_ROOT/scripts/install-pi.sh" >/dev/null 2>&1 && [[ -d "$pi_no_prune/epic-story-claim" ]]; then
  ok "install-pi.sh leaves unsupported dirs without --prune-unsupported"
else
  fail "install-pi.sh pruned or failed on unsupported dir without --prune-unsupported"
fi

pi_prune="$TMPDIR/pi-prune"
mkdir -p "$pi_prune/epic-story-claim" "$pi_prune/epic-story-resume" "$pi_prune/openspec-epic-plan"
printf '%s\n' '---' 'name: epic-story-claim' 'description: legacy' '---' > "$pi_prune/epic-story-claim/SKILL.md"
printf '%s\n' '---' 'name: not-epic-story-resume' 'description: local' '---' > "$pi_prune/epic-story-resume/SKILL.md"
printf '%s\n' '---' 'name: openspec-epic-plan' 'description: renamed' '---' > "$pi_prune/openspec-epic-plan/SKILL.md"
if PI_SKILLS_DIR="$pi_prune" "$REPO_ROOT/scripts/install-pi.sh" --prune-unsupported >/dev/null 2>&1; then
  if [[ ! -e "$pi_prune/epic-story-claim" && ! -e "$pi_prune/openspec-epic-plan" && -d "$pi_prune/epic-story-resume" ]]; then
    ok "install-pi.sh --prune-unsupported removes only verified unsupported dirs"
  else
    fail "install-pi.sh --prune-unsupported did not prune/skip expected pi dirs"
  fi
else
  fail "install-pi.sh --prune-unsupported failed"
fi

codex_dry_prune="$TMPDIR/codex-dry-prune"
mkdir -p "$codex_dry_prune/epic_story_claim/agents"
printf '%s\n' '---' 'name: epic_story_claim' 'description: legacy' '---' > "$codex_dry_prune/epic_story_claim/SKILL.md"
codex_dry_prune_output=""
if codex_dry_prune_output="$(CODEX_SKILLS_DIR="$codex_dry_prune" "$REPO_ROOT/scripts/install-codex.sh" --dry-run --prune-unsupported 2>&1)" && [[ -d "$codex_dry_prune/epic_story_claim" ]] && grep -Fq "would: rm -rf $codex_dry_prune/epic_story_claim" <<<"$codex_dry_prune_output"; then
  ok "install-codex.sh --dry-run --prune-unsupported reports prune without mutating"
else
  fail "install-codex.sh --dry-run --prune-unsupported did not report prune safely"
fi

pi_dry_prune="$TMPDIR/pi-dry-prune"
mkdir -p "$pi_dry_prune/epic-story-claim"
printf '%s\n' '---' 'name: epic-story-claim' 'description: legacy' '---' > "$pi_dry_prune/epic-story-claim/SKILL.md"
pi_dry_prune_output=""
if pi_dry_prune_output="$(PI_SKILLS_DIR="$pi_dry_prune" "$REPO_ROOT/scripts/install-pi.sh" --dry-run --prune-unsupported 2>&1)" && [[ -d "$pi_dry_prune/epic-story-claim" ]] && grep -Fq "would: rm -rf $pi_dry_prune/epic-story-claim" <<<"$pi_dry_prune_output"; then
  ok "install-pi.sh --dry-run --prune-unsupported reports prune without mutating"
else
  fail "install-pi.sh --dry-run --prune-unsupported did not report prune safely"
fi

prune_home="$TMPDIR/prune-home"
mkdir -p "$prune_home/.claude/skills"
ln -s "$REPO_ROOT/archive/skills/legacy-epic/claude/skills/epic-story-claim" "$prune_home/.claude/skills/epic-story-claim"
if HOME="$prune_home" "$REPO_ROOT/scripts/install.sh" --agents claude --yes --prune-unsupported >/dev/null 2>&1; then
  if [[ ! -e "$prune_home/.claude/skills/epic-story-claim" && ! -L "$prune_home/.claude/skills/epic-story-claim" ]]; then
    ok "install.sh --prune-unsupported prunes Claude legacy symlinks"
  else
    fail "install.sh --prune-unsupported did not prune Claude legacy symlink"
  fi
else
  fail "install.sh --agents claude --prune-unsupported failed"
fi

outside_prune_home="$TMPDIR/outside-prune-home"
outside_target="$TMPDIR/outside-legacy-target"
mkdir -p "$outside_prune_home/.claude/skills" "$outside_target"
ln -s "$outside_target" "$outside_prune_home/.claude/skills/epic-story-claim"
if HOME="$outside_prune_home" "$REPO_ROOT/scripts/install.sh" --agents claude --yes --prune-unsupported >/dev/null 2>&1; then
  if [[ -L "$outside_prune_home/.claude/skills/epic-story-claim" ]]; then
    ok "install.sh --prune-unsupported skips Claude legacy symlinks outside this repo"
  else
    fail "install.sh --prune-unsupported removed a Claude legacy symlink outside this repo"
  fi
else
  fail "install.sh --agents claude --prune-unsupported failed with outside symlink"
fi

dry_prune_home="$TMPDIR/dry-prune-home"
mkdir -p "$dry_prune_home/.claude/skills"
ln -s "$REPO_ROOT/archive/skills/legacy-epic/claude/skills/epic-story-claim" "$dry_prune_home/.claude/skills/epic-story-claim"
dry_prune_output=""
if dry_prune_output="$(HOME="$dry_prune_home" "$REPO_ROOT/scripts/install.sh" --agents claude --yes --dry-run --prune-unsupported 2>&1)" && [[ -L "$dry_prune_home/.claude/skills/epic-story-claim" ]] && grep -Fq "prune $dry_prune_home/.claude/skills/epic-story-claim" <<<"$dry_prune_output"; then
  ok "install.sh --dry-run --prune-unsupported reports Claude prune without mutating"
else
  fail "install.sh --dry-run --prune-unsupported did not report prune safely"
fi

forward_home="$TMPDIR/forward-prune-home"
mkdir -p "$forward_home/.codex/skills/epic_story_claim" "$forward_home/.pi/agent/skills/epic-story-claim"
printf '%s\n' '---' 'name: epic_story_claim' 'description: legacy' '---' > "$forward_home/.codex/skills/epic_story_claim/SKILL.md"
printf '%s\n' '---' 'name: epic-story-claim' 'description: legacy' '---' > "$forward_home/.pi/agent/skills/epic-story-claim/SKILL.md"
if HOME="$forward_home" "$REPO_ROOT/scripts/install.sh" --agents codex --yes --prune-unsupported >/dev/null 2>&1 && HOME="$forward_home" "$REPO_ROOT/scripts/install.sh" --agents pi --yes --prune-unsupported >/dev/null 2>&1; then
  if [[ ! -e "$forward_home/.codex/skills/epic_story_claim" && ! -e "$forward_home/.pi/agent/skills/epic-story-claim" ]]; then
    ok "install.sh forwards --prune-unsupported to generated installers"
  else
    fail "install.sh did not forward --prune-unsupported to generated installers"
  fi
else
  fail "install.sh generated-installer prune forwarding failed"
fi

if "$REPO_ROOT/scripts/install.sh" --prune-unsuported --dry-run >/dev/null 2>&1; then
  fail "install.sh accepted misspelled --prune-unsuported"
else
  ok "install.sh rejects misspelled --prune-unsuported"
fi

if "$REPO_ROOT/scripts/install-codex.sh" --prune-unsuported >/dev/null 2>&1; then
  fail "install-codex.sh accepted misspelled --prune-unsuported"
else
  ok "install-codex.sh rejects misspelled --prune-unsuported"
fi

if "$REPO_ROOT/scripts/install-pi.sh" --prune-unsuported >/dev/null 2>&1; then
  fail "install-pi.sh accepted misspelled --prune-unsuported"
else
  ok "install-pi.sh rejects misspelled --prune-unsuported"
fi

echo
echo "lint: codex skill content hygiene"
if grep -RInE '^(legacy-argument-hint:)|^This skill was migrated one-to-one from the former custom prompt|^Original argument hint:' "$CODEX_SKILLS" >/dev/null 2>&1; then
  fail "prompt-era Codex scaffolding found in generated codex skills (matches below)"
  grep -RInE '^(legacy-argument-hint:)|^This skill was migrated one-to-one from the former custom prompt|^Original argument hint:' "$CODEX_SKILLS" 2>&1 | sed 's/^/  /' >&2 || true
else
  ok "no prompt-era Codex scaffolding"
fi

echo
echo "lint: no cure_workspace absolute paths"
if grep -RIn 'cure_workspace' "$CLAUDE_SKILLS" "$PI_FRAGMENTS" "$REPO_ROOT/docs" "$REPO_ROOT/README.md" 2>/dev/null; then
  fail "found 'cure_workspace' references (above) — strip project-specific paths"
else
  ok "no cure_workspace leakage"
fi

echo

echo "lint: codex argument contracts"
expect_codex_contains() {
  local skill="$1" expected="$2" file
  file="$CODEX_SKILLS/$skill/SKILL.md"
  if [[ ! -f "$file" ]]; then
    fail "$skill: missing generated Codex skill for argument-contract check"
  elif grep -Fq "$expected" "$file"; then
    ok "$skill: preserves $expected"
  else
    fail "$skill: generated Codex body missing '$expected'"
  fi
}
expect_codex_argument_line() {
  local skill="$1" expected="$2" file
  file="$CODEX_SKILLS/$skill/SKILL.md"
  if [[ ! -f "$file" ]]; then
    fail "$skill: missing generated Codex skill for argument-line check"
  elif grep -Fxq "$expected" "$file"; then
    ok "$skill: argument line preserves contract"
  else
    fail "$skill: generated Codex argument line missing exact '$expected'"
  fi
}

expect_codex_argument_line openspec_archive 'Argument: INITIATIVE=<slug> STORY=<slug>'
expect_codex_argument_line openspec_initiative_plan 'Argument: [SLUG=<slug>]'
expect_codex_argument_line openspec_next_action 'Argument: [INITIATIVE=<slug>] [STORY=<slug>] [SPEC=<spec-or-path>] [--all]'
expect_codex_argument_line openspec_feedback 'Argument: INITIATIVE=<slug> [--pr <pr_url>] [--latest|--all] [--since <source_id>] [feedback_or_file]'
expect_codex_argument_line openspec_story_claim 'Argument: INITIATIVE=<slug> [STORY=<slug>] [WORKTREE="<basename>=<path>"]...'
expect_codex_argument_line openspec_story_resume 'Argument: INITIATIVE=<slug> [STORY=<slug>] [WORKTREE="<basename>=<path>"]...'
expect_codex_argument_line openspec_story_review 'Argument: INITIATIVE=<slug> STORY=<slug> [WORKTREE="<basename>=<path>"]...'
expect_codex_argument_line openspec_story_converge 'Argument: INITIATIVE=<slug> STORY=<slug> [MAX_CYCLES=5] [WORKTREE="<basename>=<path>"]...'
expect_codex_argument_line openspec_story_plan 'Argument: [INITIATIVE=<slug>]'
expect_codex_argument_line openspec_story_plan_resume 'Argument: INITIATIVE=<slug> STORY=<slug>'
expect_codex_argument_line openspec_story_plan_review 'Argument: INITIATIVE=<slug> STORY=<slug>'
expect_codex_argument_line openspec_story_plan_converge 'Argument: INITIATIVE=<slug> STORY=<slug> [MAX_CYCLES=5]'
expect_codex_argument_line openspec_story_pr 'Argument: INITIATIVE=<slug> STORY=<slug> [<pr_url_or_OPEN=true>]'

expect_codex_contains openspec_next_action "the INITIATIVE, STORY, SPEC, and --all selectors"
expect_codex_contains openspec_feedback "the INITIATIVE, feedback flags, and feedback payload named variables"
expect_codex_contains openspec_story_claim "the INITIATIVE, STORY, and WORKTREE named variables"
expect_codex_contains openspec_story_review "the INITIATIVE, STORY, and WORKTREE named variables"
expect_codex_contains openspec_story_converge "the INITIATIVE, STORY, MAX_CYCLES, and WORKTREE named variables"
expect_codex_contains openspec_story_plan_converge "the INITIATIVE, STORY, and MAX_CYCLES named variables"
expect_codex_contains openspec_story_pr "the INITIATIVE, STORY, and PR selector named variables"

expect_codex_contains openspec_story_claim "Claimed by: Codex fresh session"
expect_codex_contains openspec_story_resume "Claimed by: Codex fresh session (resume)"

if grep -RIn '\$ARGUMENTS' "$CODEX_SKILLS"/openspec_* 2>/dev/null; then
  fail "generated Codex OpenSpec skills still contain raw \$ARGUMENTS"
else
  ok "generated Codex OpenSpec skills have no raw \$ARGUMENTS"
fi

if grep -RIn 'Claimed by: pi' "$CODEX_SKILLS"/openspec_* 2>/dev/null; then
  fail "generated Codex OpenSpec skills contain hard-coded pi claimant identity"
else
  ok "generated Codex OpenSpec skills avoid hard-coded pi claimant identity"
fi

echo

echo "lint: openspec pi fragment authority boundary"
if grep -RInE 'Persist review verdict|Review findings → notebook|Proof tracking → notebook|approval evidence.*notebook_write|lifecycle.*notebook_write' "$PI_FRAGMENTS"/openspec-*.md 2>/dev/null; then
  fail "OpenSpec Pi fragments persist review/proof/lifecycle authority to notebooks (matches above)"
else
  ok "OpenSpec Pi fragments keep review/proof/lifecycle authority in canonical artifacts"
fi

echo
if [[ $FAIL -ne 0 ]]; then
  echo "lint: FAILED"
  exit 1
fi
echo "lint: PASSED"
