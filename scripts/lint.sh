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
#   20. Active OpenSpec workflow outputs use the canonical suggested-next-action label.
#   21. Approved OpenSpec lifecycle semantics survive canonical, Codex, and Pi generation.
#   22. Pi implementation/planning convergence prompts end with their owning slash command.
#   23. Recognized stale install inventory is explicitly and safely prunable.
#
# Exit codes:
#   0 — clean
#   1 — at least one finding

set -uo pipefail

export LC_ALL=C
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS="${REPO_ROOT}/claude/skills"
PI_FRAGMENTS="${REPO_ROOT}/pi-fragments"

lint_render_message() {
  local message="$1"
  if [[ -n "${LINT_SUITE_TMPDIR:-}" && -n "${LINT_AGGREGATE_TMP_ROOT:-}" ]]; then
    message="${message//"$LINT_SUITE_TMPDIR"/"$LINT_AGGREGATE_TMP_ROOT"}"
  fi
  printf '%s' "$message"
}
fail() { printf 'FAIL %s\n' "$(lint_render_message "$*")" >&2; FAIL=1; }
ok()   { printf 'ok   %s\n' "$(lint_render_message "$*")"; }

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
  epic-claim
  epic-feedback
  epic-new-story
  epic-plan
  epic-pr
  epic-resume
  epic-review
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
  epic-story-save
  openspec-story-pr
  openspec-epic-plan
)

declare -a UNSUPPORTED_CODEX_SKILLS=(
  epic_claim
  epic_feedback
  epic_new_story
  epic_plan
  epic_pr
  epic_resume
  epic_review
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
  epic_story_save
  openspec_story_pr
  openspec_epic_plan
)

# Output-shape classifications. Active OpenSpec workflows are derived from
# CLAUDE_NAMES below; these lists must partition that derived set exactly.
declare -a DUAL_CAPABLE_OPENSPEC_SKILLS=(
  openspec-archive
  openspec-feedback
  openspec-next-action
  openspec-pr
  openspec-story-claim
  openspec-story-converge
  openspec-story-plan
  openspec-story-plan-converge
  openspec-story-plan-resume
  openspec-story-plan-review
  openspec-story-resume
  openspec-story-review
)
declare -a SCALAR_ONLY_OPENSPEC_SKILLS=(
  openspec-initiative-plan
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

# Extract a field value from the first YAML frontmatter block. YAML permits
# quoted keys and whitespace before the colon; normalize those valid spellings.
frontmatter_value() {
  local file="$1" field="$2"
  awk -v field="$field" '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
    NR == 1 { exit }
    fm && /^---[[:space:]]*$/ { exit }
    fm {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      colon = index(line, ":")
      if (!colon) next
      key = trim(substr(line, 1, colon - 1))
      if ((key ~ /^"[A-Za-z0-9_-]+"$/) || (key ~ /^\047[A-Za-z0-9_-]+\047$/))
        key = substr(key, 2, length(key) - 2)
      if (key == field) {
        value = trim(substr(line, colon + 1))
        if ((value ~ /^".*"$/) || (value ~ /^\047.*\047$/))
          value = substr(value, 2, length(value) - 2)
        print value
        exit
      }
    }
  ' "$file"
}

frontmatter_has_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
    NR == 1 { exit 1 }
    fm && /^---[[:space:]]*$/ { exit 1 }
    fm {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      colon = index(line, ":")
      if (!colon) next
      key = trim(substr(line, 1, colon - 1))
      if ((key ~ /^"[A-Za-z0-9_-]+"$/) || (key ~ /^\047[A-Za-z0-9_-]+\047$/))
        key = substr(key, 2, length(key) - 2)
      if (key == field) { found = 1; exit 0 }
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

frontmatter_duplicate_keys() {
  local file="$1"
  awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
    NR == 1 { exit }
    fm && /^---[[:space:]]*$/ { exit }
    fm {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      colon = index(line, ":")
      if (!colon) next
      key = trim(substr(line, 1, colon - 1))
      if (key ~ /^[A-Za-z0-9_-]+$/) normalized = key
      else if (key ~ /^"[A-Za-z0-9_-]+"$/ || key ~ /^\047[A-Za-z0-9_-]+\047$/)
        normalized = substr(key, 2, length(key) - 2)
      else next
      if (++seen[normalized] == 2) print normalized
    }
  ' "$file"
}

check_frontmatter_unique_keys() {
  local file="$1" duplicates
  duplicates="$(frontmatter_duplicate_keys "$file")"
  if [[ -n "$duplicates" ]]; then
    fail "$file: duplicate YAML frontmatter key(s): $(tr '\n' ' ' <<<"$duplicates" | sed 's/[[:space:]]*$//')"
  fi
}

check_frontmatter_duplicate_detector() {
  local duplicate="$TMPDIR/frontmatter-duplicate.md" unique="$TMPDIR/frontmatter-unique.md"
  local whitespace="$TMPDIR/frontmatter-duplicate-whitespace.md" quoted="$TMPDIR/frontmatter-duplicate-quoted.md"
  printf '%s\n' '---' 'name: sample' 'allowed-tools: Read' 'allowed-tools: Write' '---' >"$duplicate"
  printf '%s\n' '---' 'name: sample' 'allowed-tools: Read Write' '---' >"$unique"
  printf '%s\n' '---' 'name: sample' 'name : other' '---' >"$whitespace"
  printf '%s\n' '---' 'name: sample' '"name": other' '---' >"$quoted"
  if [[ "$(frontmatter_duplicate_keys "$duplicate")" == allowed-tools ]] &&
     [[ "$(frontmatter_duplicate_keys "$whitespace")" == name ]] &&
     [[ "$(frontmatter_duplicate_keys "$quoted")" == name ]] &&
     [[ -z "$(frontmatter_duplicate_keys "$unique")" ]]; then
    ok "YAML frontmatter detector rejects plain, whitespace-before-colon, and quoted duplicate keys"
  else
    fail "YAML frontmatter duplicate-key detector is not fail-closed for valid YAML key spellings"
  fi
}

check_frontmatter_yaml_scalar_safety() {
  local file="$1" output
  if ! output="$(awk '
    NR == 1 && /^---[[:space:]]*$/ { fm = 1; next }
    NR == 1 { exit 0 }
    fm && /^---[[:space:]]*$/ { exit 0 }
    fm && /^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*/ {
      line = $0
      value = line
      sub(/^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*/, "", value)
      trimmed = value
      sub(/^[[:space:]]*/, "", trimmed)
      if (trimmed == "") next
      first = substr(trimmed, 1, 1)
      if (first == "\"" || first == "\047" || first == "[" || first == "{" || first == "|" || first == ">") next
      if (trimmed ~ /:[[:space:]]/) {
        print FILENAME ":" NR ": quote frontmatter scalar values that contain colon-space (: )"
        bad = 1
      }
    }
    END { exit bad ? 1 : 0 }
  ' "$file")"; then
    fail "$file: YAML frontmatter contains an unsafe unquoted scalar"
    printf '%s\n' "$output" | sed 's/^/  /' >&2
  fi
}

# Strip inactive HTML comments before semantic checks. This keeps examples and
# fenced contracts active while preventing commented-out prose from satisfying
# or tripping whole-file guards.
markdown_without_comments() {
  local file="$1"
  awk '
    {
      line = $0
      out = ""
      while (1) {
        if (in_comment) {
          end = index(line, "-->")
          if (!end) { line = ""; break }
          line = substr(line, end + 3)
          in_comment = 0
          continue
        }
        start = index(line, "<!--")
        if (!start) { out = out line; break }
        out = out substr(line, 1, start - 1)
        line = substr(line, start + 4)
        in_comment = 1
      }
      if (!in_comment || out != "") print out
    }
  ' "$file"
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

# Extract the final-response/output instructions through the end of the skill.
extract_final_output_contract() {
  local file="$1"
  awk '
    {
      heading = tolower($0)
      if (heading ~ /^## final response[[:space:]]*$/ ||
          heading ~ /^## phase [0-9]+ — final response[[:space:]]*$/ ||
          heading ~ /^## status and output[[:space:]]*$/ ||
          heading ~ /^## output format[[:space:]]*$/) {
        found = 1
      }
      if (found) print
    }
    END { exit found ? 0 : 1 }
  ' "$file"
}

check_suggested_next_action_contract() {
  local label="$1" file="$2" dual_capable="$3" contract
  local suggested_count empty_count converge_count pass_count choice_count dual_block_count
  if ! contract="$(extract_final_output_contract "$file")"; then
    fail "$label: missing final-response/output contract section"
    return
  fi

  suggested_count="$(grep -Ec '^Suggested next action:' <<<"$contract" || true)"
  if [[ "$suggested_count" -eq 1 ]]; then
    ok "$label: declares exactly one anchored Suggested next action: line"
  else
    fail "$label: final-response/output contract must contain exactly one unformatted line beginning 'Suggested next action:' (found $suggested_count)"
  fi

  if grep -Eiq 'Suggested[[:space:]]+next[[:space:]]+step' <<<"$contract"; then
    fail "$label: final-response/output contract uses competing 'Suggested next step:' label"
  fi
  if grep -Eq '^#{1,6}[[:space:]]+Next[[:space:]]+Action([[:space:]]*:)?[[:space:]]*$|^[[:space:]]*([-*][[:space:]]+)?(\*\*Next[[:space:]]+Action(:)?\*\*([[:space:]]*:)?|Next[[:space:]]+Action[[:space:]]*:)([[:space:]].*)?$' <<<"$contract"; then
    fail "$label: final-response/output contract uses a competing markdown/plain Next Action heading or field"
  fi

  empty_count="$(grep -Ec '^Suggested next action:[[:space:]]*$' <<<"$contract" || true)"
  converge_count="$(grep -Ec '^- Converge wrapper:' <<<"$contract" || true)"
  pass_count="$(grep -Ec '^- Non-looped pass:' <<<"$contract" || true)"
  choice_count="$(grep -Fxc 'Choose one; do not run both.' <<<"$contract" || true)"
  dual_block_count="$(awk '
    /^Suggested next action:/ { state = 1; next }
    state == 1 && /^- Converge wrapper:/ { state = 2; next }
    state == 2 && /^- Non-looped pass:/ { state = 3; next }
    state == 3 && $0 == "Choose one; do not run both." { blocks++; state = 0; next }
    { state = 0 }
    END { print blocks + 0 }
  ' <<<"$contract")"

  if [[ "$dual_capable" == true ]]; then
    if [[ "$converge_count" -ne 1 || "$pass_count" -ne 1 || "$choice_count" -ne 1 || "$dual_block_count" -ne 1 ]]; then
      fail "$label: dual-capable contract requires exactly one contiguous ordered block of anchored 'Suggested next action:', '- Converge wrapper:', '- Non-looped pass:', and 'Choose one; do not run both.' lines (markers: $converge_count/$pass_count/$choice_count; blocks: $dual_block_count)"
    else
      ok "$label: dual-route block is complete, contiguous, and ordered"
    fi
  elif [[ "$converge_count" -ne 0 || "$pass_count" -ne 0 || "$choice_count" -ne 0 || "$dual_block_count" -ne 0 ]]; then
    fail "$label: scalar-only contract contains an unexpected full or partial dual-route block (markers: $converge_count/$pass_count/$choice_count; blocks: $dual_block_count)"
  fi

  if [[ "$empty_count" -gt 0 && "$dual_block_count" -ne 1 ]]; then
    fail "$label: empty Suggested next action: placeholder is allowed only as the first line of a contiguous complete dual-route block"
  fi
}

check_pi_converge_dispatch() {
  local label="$1" file="$2" prompt_marker="$3" final_command="$4" forbidden_command="$5"
  local prompt_count marker_count final_count final_line prompt_block

  if [[ ! -f "$file" ]]; then
    fail "$label: missing Pi convergence dispatch contract at $file"
    return
  fi

  prompt_count="$(grep -Ec '^[[:space:]]*prompt[[:space:]]*:' "$file" || true)"
  prompt_block="$(awk '
    /^[[:space:]]*prompt[[:space:]]*:/ {
      if (in_prompt) exit
      in_prompt = 1
    }
    in_prompt && /^[[:space:]]*thinking[[:space:]]*:/ { exit }
    in_prompt { print }
  ' "$file")"
  marker_count="$(grep -Fc -- "$prompt_marker" <<<"$prompt_block" || true)"
  final_count="$(grep -Fc -- "$final_command" <<<"$prompt_block" || true)"
  final_line="$(awk '
    {
      line = $0
      sub(/^[[:space:]]*prompt[[:space:]]*:[[:space:]]*/, "", line)
      sub(/^[[:space:]]*/, "", line)
      sub(/^[[]/, "", line)
      sub(/^[[:space:]]*/, "", line)
      sub(/^"/, "", line)
      sub(/",?[[:space:]]*$/, "", line)
      sub(/^[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      if (line == "" || line ~ /^[]][.]join[(]/) next
      last = line
    }
    END { print last }
  ' <<<"$prompt_block")"

  if [[ "$prompt_count" -ne 1 || "$marker_count" -ne 1 ]]; then
    fail "$label: Pi convergence must contain exactly one owning workflow spawn prompt (prompt keys: $prompt_count; in-prompt markers: $marker_count)"
  elif [[ "$final_count" -ne 1 || "$final_line" != "$final_command" ]]; then
    fail "$label: Pi convergence spawn prompt must end with exact slash command '$final_command' (occurrences: $final_count; got '${final_line:-<missing>}')"
  elif [[ -n "$forbidden_command" ]] && grep -Fq -- "$forbidden_command" <<<"$prompt_block"; then
    fail "$label: Pi convergence spawn contract must not dispatch $forbidden_command"
  else
    ok "$label: Pi convergence dispatch ends with the exact owning slash command"
  fi
}

require_literal() {
  local label="$1" file="$2" literal="$3"
  if [[ ! -f "$file" ]]; then
    fail "$label: missing file $file"
  elif ! grep -Fq -- "$literal" "$file"; then
    fail "$label: missing required literal in $file"
  else
    ok "$label: $file"
  fi
}

forbid_literal() {
  local label="$1" file="$2" literal="$3"
  if [[ ! -f "$file" ]]; then
    fail "$label: missing file $file"
  elif grep -Fq -- "$literal" < <(markdown_without_comments "$file"); then
    fail "$label: forbidden active literal remains in $file"
  else
    ok "$label: $file"
  fi
}

require_workflow_literal() {
  local label="$1" skill="$2" literal="$3" codex_skill runtime file
  local missing=()
  codex_skill="$(hyphen_to_underscore "$skill")"
  for runtime in canonical codex pi; do
    case "$runtime" in
      canonical) file="$CLAUDE_SKILLS/$skill/SKILL.md" ;;
      codex) file="$CODEX_SKILLS/$codex_skill/SKILL.md" ;;
      pi) file="$PI_SKILLS/$skill/SKILL.md" ;;
    esac
    [[ -f "$file" ]] && grep -Fq -- "$literal" < <(markdown_without_comments "$file") || missing+=("$runtime")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "$label: required literal missing from ${missing[*]}"
  else
    ok "$label: canonical + generated Codex/Pi"
  fi
}

forbid_workflow_literal() {
  local label="$1" skill="$2" literal="$3" codex_skill runtime file
  local present=()
  codex_skill="$(hyphen_to_underscore "$skill")"
  for runtime in canonical codex pi; do
    case "$runtime" in
      canonical) file="$CLAUDE_SKILLS/$skill/SKILL.md" ;;
      codex) file="$CODEX_SKILLS/$codex_skill/SKILL.md" ;;
      pi) file="$PI_SKILLS/$skill/SKILL.md" ;;
    esac
    if [[ ! -f "$file" ]] || grep -Fq -- "$literal" < <(markdown_without_comments "$file"); then
      present+=("$runtime")
    fi
  done
  if [[ ${#present[@]} -gt 0 ]]; then
    fail "$label: forbidden literal present (or output missing) in ${present[*]}"
  else
    ok "$label: canonical + generated Codex/Pi"
  fi
}

check_workflow_contract() {
  local label="$1" skill="$2" codex_skill runtime file literal
  local missing=()
  shift 2
  codex_skill="$(hyphen_to_underscore "$skill")"
  for runtime in canonical codex pi; do
    case "$runtime" in
      canonical) file="$CLAUDE_SKILLS/$skill/SKILL.md" ;;
      codex) file="$CODEX_SKILLS/$codex_skill/SKILL.md" ;;
      pi) file="$PI_SKILLS/$skill/SKILL.md" ;;
    esac
    if [[ ! -f "$file" ]]; then
      missing+=("$runtime:file")
      continue
    fi
    for literal in "$@"; do
      grep -Fq -- "$literal" < <(markdown_without_comments "$file") || missing+=("$runtime:$literal")
    done
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "$label: missing fixed contract token(s): ${missing[*]}"
  else
    ok "$label: canonical + generated Codex/Pi"
  fi
}

allowed_tool_tokens() {
  local file="$1" rest token
  local -a seen=()
  [[ -f "$file" ]] || return 1
  if ! rest="$(frontmatter_value "$file" allowed-tools)" || [[ -z "$rest" ]]; then
    return 1
  fi
  while :; do
    rest="${rest#"${rest%%[![:space:]]*}"}"
    [[ -n "$rest" ]] || return 0
    # Bare tools are identifiers. Scoped Bash permissions require one
    # nonblank, non-parenthesized command pattern and an exact token boundary.
    if [[ "$rest" =~ ^(Bash\([^\(\)[:space:]]([^\(\)]*[^\(\)[:space:]])?\))([[:space:]]|$) ]]; then
      token="${BASH_REMATCH[1]}"
    elif [[ "$rest" =~ ^([A-Za-z_][A-Za-z0-9_-]*)([[:space:]]|$) ]]; then
      token="${BASH_REMATCH[1]}"
    else
      return 1
    fi
    in_array "$token" "${seen[@]:-}" && return 1
    seen+=("$token")
    printf '%s\n' "$token"
    rest="${rest#"$token"}"
  done
}

# Required tools are exact frontmatter tokens, but token order and additional
# runtime-specific tools are intentionally irrelevant. Any un-tokenizable junk
# invalidates the complete scalar rather than becoming a misleading token.
check_allowed_tools_contract() {
  local skill="$1" codex_skill file runtime required token_output
  local missing=() invalid=() actual_tokens=()
  shift
  codex_skill="$(hyphen_to_underscore "$skill")"
  for runtime in canonical codex pi; do
    case "$runtime" in
      canonical) file="$CLAUDE_SKILLS/$skill/SKILL.md" ;;
      codex) file="$CODEX_SKILLS/$codex_skill/SKILL.md" ;;
      pi) file="$PI_SKILLS/$skill/SKILL.md" ;;
    esac
    if ! token_output="$(allowed_tool_tokens "$file")"; then
      invalid+=("$runtime")
      continue
    fi
    actual_tokens=()
    [[ -z "$token_output" ]] || mapfile -t actual_tokens <<<"$token_output"
    for required in "$@"; do
      if ! in_array "$required" "${actual_tokens[@]:-}"; then
        missing+=("$runtime:$required")
      fi
    done
  done
  if [[ ${#invalid[@]} -gt 0 || ${#missing[@]} -gt 0 ]]; then
    fail "tool contract $skill: invalid allowed-tools scalar(s): ${invalid[*]:-none}; missing exact token(s): ${missing[*]:-none}"
  else
    ok "tool contract $skill: exact required membership in canonical + generated Codex/Pi"
  fi
}

check_allowed_tools_exact() {
  local skill="$1" codex_skill file runtime token_output actual expected
  local bad=()
  shift
  expected="$(printf '%s\n' "$@" | sort)"
  codex_skill="$(hyphen_to_underscore "$skill")"
  for runtime in canonical codex pi; do
    case "$runtime" in
      canonical) file="$CLAUDE_SKILLS/$skill/SKILL.md" ;;
      codex) file="$CODEX_SKILLS/$codex_skill/SKILL.md" ;;
      pi) file="$PI_SKILLS/$skill/SKILL.md" ;;
    esac
    if ! token_output="$(allowed_tool_tokens "$file")"; then
      bad+=("$runtime:invalid")
      continue
    fi
    actual="$(printf '%s\n' "$token_output" | sed '/^$/d' | sort)"
    [[ "$actual" == "$expected" ]] || bad+=("$runtime:set-mismatch")
  done
  if [[ ${#bad[@]} -gt 0 ]]; then
    fail "tool contract $skill: expected exact allowed-tools set; ${bad[*]}"
  else
    ok "tool contract $skill: exact narrowed set in canonical + generated Codex/Pi"
  fi
}

check_allowed_tool_tokenizer() {
  local valid="$TMPDIR/tokenizer-valid.md" invalid tokens case_value
  printf '%s\n' '---' 'allowed-tools: Read Bash(git status:*) Write' '---' >"$valid"
  if ! tokens="$(allowed_tool_tokens "$valid")" ||
     [[ "$tokens" != $'Read\nBash(git status:*)\nWrite' ]]; then
    fail "allowed-tools tokenizer rejects a valid exact token sequence"
    return
  fi
  for case_value in \
    'Read Bash(git status:*)JUNK Write' \
    'Read Bash() Write' \
    'Read Bash( git status:*) Write' \
    'Read Bash(git (status):*) Write' \
    'Read,Write' \
    'Read Read'; do
    invalid="$TMPDIR/tokenizer-invalid-${RANDOM}.md"
    printf '%s\n' '---' "allowed-tools: $case_value" '---' >"$invalid"
    if allowed_tool_tokens "$invalid" >/dev/null; then
      fail "allowed-tools tokenizer accepted malformed or duplicate tokens: $case_value"
      return
    fi
  done
  ok "allowed-tools tokenizer enforces exact, nonduplicate token grammar"
}

markdown_section() {
  local file="$1" heading="$2"
  awk -v heading="$heading" '
    $0 == heading { found = 1 }
    found && $0 ~ /^## / && $0 != heading { exit }
    found { print }
  ' "$file"
}

require_exact_line() {
  local label="$1" file="$2" line="$3"
  if [[ ! -f "$file" ]]; then
    fail "$label: missing file $file"
  elif ! grep -Fxq -- "$line" < <(markdown_without_comments "$file"); then
    fail "$label: missing exact active line '$line' in $file"
  else
    ok "$label: $file"
  fi
}

has_all_runtime_force_guidance() {
  local file="$1"
  markdown_without_comments "$file" | awk '
    function normalize(text, lower) {
      lower = tolower(text)
      # Normalize ordinary and ANSI-C shell quoting without leaving the `$`
      # from `$'"'"'word'"'"'` attached to the following option.
      gsub(/\$\047/, "", lower)
      gsub(/["\047]/, "", lower)
      gsub(/\$/, "", lower)
      return lower
    }
    function is_command(text, command) {
      command = normalize(text)
      sub(/^[[:space:]]*/, "", command)
      sub(/^([-*+]|[0-9]+[.)])[[:space:]]+/, "", command)
      sub(/^(\$|>)[[:space:]]+/, "", command)
      sub(/^env[[:space:]]+/, "", command)
      while (command ~ /^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+/)
        sub(/^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+/, "", command)
      return command ~ /^(\.\/)?scripts\/install\.sh([[:space:]]|$)/
    }
    function inspect(text, command) {
      if (!is_command(text)) return
      command = normalize(text)
      if (command ~ /--agents([=[:space:]]+)all([^a-z0-9_-]|$)/ &&
          command ~ /(^|[^a-z0-9_-])--force([^a-z0-9_-]|$)/) bad = 1
    }
    function inspect_inline(text, rest, start, tail, finish, code) {
      rest = text
      while ((start = index(rest, "`")) != 0) {
        tail = substr(rest, start + 1)
        finish = index(tail, "`")
        if (!finish) break
        code = substr(tail, 1, finish - 1)
        inspect(code)
        rest = substr(tail, finish + 1)
      }
    }
    {
      line = $0
      if (line ~ /^[[:space:]]*```/) {
        if (continued) {
          inspect(logical)
          logical = ""
          continued = 0
        }
        in_fence = !in_fence
        next
      }

      # Inline code is executable-looking even when surrounding prose says
      # "do not"; prose outside code spans is deliberately not scanned.
      inspect_inline(line)

      if (continued) logical = logical " " line
      else if (in_fence || is_command(line)) logical = line
      else next

      if (line ~ /\\[[:space:]]*$/) {
        sub(/\\[[:space:]]*$/, "", logical)
        continued = 1
        next
      }
      inspect(logical)
      logical = ""
      continued = 0
    }
    END {
      if (continued || logical != "") inspect(logical)
      exit bad ? 0 : 1
    }
  '
}

check_no_all_runtime_force_guidance() {
  local file="$1" sample="$TMPDIR/all-runtime-force.md" command
  if has_all_runtime_force_guidance "$file"; then
    fail "$file: blanket all-runtime --force command is forbidden regardless of quoting or flag ordering"
  else
    ok "$file has no executable blanket all-runtime force command"
  fi
  for command in \
    'scripts/install.sh --yes --agents all --force' \
    'scripts/install.sh --force --agents=all --yes' \
    "'scripts/install.sh' '--agents' 'all' '--yes' '--force'" \
    '"scripts/install.sh" "--yes" "--force" "--agents=all"' \
    '$'"'"'scripts/install.sh'"'"' $'"'"'--force'"'"' $'"'"'--yes'"'"' $'"'"'--agents'"'"' $'"'"'all'"'"'' \
    'Do not run `scripts/install.sh --agents all --force`.' \
    $'```bash\nscripts/install.sh --agents=all --yes --force\n```' \
    $'scripts/install.sh \\\n  --force \\\n  --yes \\\n  --agents all'; do
    printf '%s\n' "$command" >"$sample"
    if ! has_all_runtime_force_guidance "$sample"; then
      fail "all-runtime force detector missed executable command: $command"
      return
    fi
  done
  printf '%s\n' 'Do not recommend scripts/install.sh --agents all --force in prose.' >"$sample"
  if has_all_runtime_force_guidance "$sample"; then
    fail "all-runtime force detector scanned non-code prose as an executable command"
  fi
}

check_feedback_receipt_contract() {
  local skill=openspec-feedback codex_skill runtime file section field disposition
  local missing=()
  codex_skill="$(hyphen_to_underscore "$skill")"
  for runtime in canonical codex pi; do
    case "$runtime" in
      canonical) file="$CLAUDE_SKILLS/$skill/SKILL.md" ;;
      codex) file="$CODEX_SKILLS/$codex_skill/SKILL.md" ;;
      pi) file="$PI_SKILLS/$skill/SKILL.md" ;;
    esac
    section="$(markdown_section "$file" '## Feedback Receipts')"
    if [[ -z "$section" ]]; then
      missing+=("$runtime:section")
      continue
    fi
    for field in 'Feedback ID' 'Source ID' 'Source hash' 'Disposition' 'Target' 'Acknowledged reason' 'Changed artifacts' 'Next owner'; do
      grep -Fq "$field" <<<"$section" || missing+=("$runtime:field:$field")
    done
    for disposition in queue-planning-feedback amend-existing-story resume-current-story new-story-candidate initiative-level-decision defer-or-reject; do
      grep -Fq "$disposition" <<<"$section" || missing+=("$runtime:disposition:$disposition")
    done
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "portable feedback receipt: incomplete contract(s): ${missing[*]}"
  else
    ok "portable feedback receipt: fields cover every disposition in canonical + generated Codex/Pi"
  fi
}

check_no_persisted_root_writes() {
  local file="$1"
  markdown_without_comments "$file" | awk '
    function normalize(text, normalized) {
      normalized = tolower(text)
      gsub(/[*`]/, "", normalized)
      return normalized
    }
    function has_artifact(text) {
      return text ~ /(^|[^a-z])(story|progress|initiative|blocked)\.md([^a-z]|$)/
    }
    function has_write_verb(text) {
      return text ~ /(^|[^a-z])(document|store|persist|write|add|record|include|keep|save)([^a-z]|$)/
    }
    function is_negative(text) {
      return text ~ /(^|[^a-z])(do not|don.t|never|must not|may not|cannot|can.t|forbid|prohibit)([^a-z]|$)/ ||
        text ~ /(^|[^a-z])no[[:space:]]+[^.;]*(document|store|persist|write|add|record|include|keep|save)([^a-z]|$)/ ||
        text ~ /without[[:space:]]+[^.;]*root/ ||
        text ~ /not[[:space:]]+(be[[:space:]]+)?(documented|stored|persisted|written|added|recorded|included|kept|saved)/
    }
    function has_root_value(text) {
      return text ~ /<openspec[_-]root>/
    }
    function has_root_label(text) {
      return text ~ /((openspec|artifact|coordination|active|selected|workspace)[ -]+(artifact[ -]+)?(root|checkout|check-out)|artifact[ -]+(root|checkout|check-out|location|base|anchor)|coordination[ -]+(root|anchor|base|checkout|check-out|location))[[:space:]]*:/
    }
    function root_is_path(text) {
      return text ~ /<openspec[_-]root>[[:space:]]*\//
    }
    function direct_persistence(text, root) {
      if (!has_artifact(text) || !has_write_verb(text)) return 0
      root = "(<openspec[_-]root>|((openspec|artifact|coordination|active|selected|workspace)[ -]+(artifact[ -]+)?(root|checkout|check-out)|artifact[ -]+(root|checkout|check-out|location|base|anchor)|coordination[ -]+(root|anchor|base|checkout|check-out|location))[[:space:]]*:)"
      if (has_root_value(text) && root_is_path(text)) return 0
      return text ~ ("(document|store|persist|write|add|record|include|keep|save)[^.;]*" root "[^.;]*(into|inside|in|to|on|under)[^.;]*(story|progress|initiative|blocked)\\.md") ||
        text ~ ("(document|store|persist|write|add|record|include|keep|save)[^.;]*(story|progress|initiative|blocked)\\.md[^.;]*(with|containing|field|label|anchor|location|value|:)[^.;]*" root)
    }
    function report(raw, line_number) {
      print line_number ":" raw
      bad = 1
    }
    function inspect_clause(raw, line_number, clause, prior_context) {
      clause = normalize(raw)
      sub(/^[[:space:]]+/, "", clause)
      sub(/[[:space:]]+$/, "", clause)
      if (clause == "") return

      prior_context = context
      if (!is_negative(clause) && direct_persistence(clause))
        report(raw, line_number)
      else if (prior_context != "" && !is_negative(prior_context) &&
               has_artifact(prior_context) && has_write_verb(prior_context) &&
               ((has_root_value(clause) && !root_is_path(clause)) || has_root_label(clause)))
        report(raw, line_number)

      # Keep an affirmative artifact-writing introduction across blank lines
      # and a fence delimiter, but consume it at the next substantive clause.
      if (has_artifact(clause) && has_write_verb(clause) && !is_negative(clause))
        context = clause
      else
        context = ""
    }
    function inspect_line(raw, line_number, start, i, char, following, clause) {
      start = 1
      for (i = 1; i <= length(raw); i++) {
        char = substr(raw, i, 1)
        following = substr(raw, i + 1, 1)
        # Periods terminate prose clauses only at whitespace/end, preserving
        # artifact names such as story.md. Semicolons always split clauses.
        if (char == ";" || (char == "." && (following == "" || following ~ /[[:space:]]/))) {
          clause = substr(raw, start, i - start)
          inspect_clause(clause, line_number)
          start = i + 1
        }
      }
      inspect_clause(substr(raw, start), line_number)
    }
    {
      raw = $0
      if (raw ~ /^[[:space:]]*```/) {
        in_fence = !in_fence
        next
      }
      if (raw ~ /^[[:space:]]*$/) next
      inspect_line(raw, FNR)
    }
    END { exit bad ? 0 : 1 }
  '
}

check_persisted_root_detector() {
  local sample expected
  local -a bad_samples=(
    $'Write the following field to story.md:\n\n```md\n**OpenSpec root:** `<openspec_root>`\n```'
    $'Add this field to progress.md:\n**Artifact check-out:** `<openspec_root>`'
    'Record `<openspec_root>` into initiative.md for later sessions.'
    'Include blocked.md with a Coordination root label containing `<openspec_root>`.'
    'Document the active checkout anchor `<openspec_root>` in story.md.'
    'Store a Coordination anchor in progress.md: `<openspec_root>`.'
    'Do not persist `<openspec_root>` in story.md; save `<openspec_root>` in progress.md.'
    'Never document `<openspec_root>` in blocked.md. Keep `<openspec_root>` in initiative.md.'
  )
  local -a good_samples=(
    'Never record `<openspec_root>` in story.md.'
    'Do not include an Artifact root field in progress.md.'
    'You must never document `<openspec_root>` in blocked.md.'
    'Read and write story.md at `<openspec_root>/openspec/changes/<slug>/story.md`.'
    'Include `<openspec_root>` in the in-memory candidate root set.'
  )
  expected=0
  for sample in "${bad_samples[@]}"; do
    printf '%s\n' "$sample" >"$TMPDIR/persisted-root-$expected.md"
    check_no_persisted_root_writes "$TMPDIR/persisted-root-$expected.md" >/dev/null || {
      fail "persisted-root detector missed affirmative sample: $sample"
      return
    }
    expected=$((expected + 1))
  done
  for sample in "${good_samples[@]}"; do
    printf '%s\n' "$sample" >"$TMPDIR/persisted-root-$expected.md"
    if check_no_persisted_root_writes "$TMPDIR/persisted-root-$expected.md" >/dev/null; then
      fail "persisted-root detector flagged prohibition or path routing: $sample"
      return
    fi
    expected=$((expected + 1))
  done
  ok "persisted-root detector splits prose clauses, catches fenced fields, and excludes prohibitions/path routing"
}

check_blocked_write_order() {
  local skill=openspec-story-review codex_skill runtime file section order
  local bad=()
  codex_skill="$(hyphen_to_underscore "$skill")"
  for runtime in canonical codex pi; do
    case "$runtime" in
      canonical) file="$CLAUDE_SKILLS/$skill/SKILL.md" ;;
      codex) file="$CODEX_SKILLS/$codex_skill/SKILL.md" ;;
      pi) file="$PI_SKILLS/$skill/SKILL.md" ;;
    esac
    section="$(markdown_section "$file" '## Status transitions')"
    order="$(awk '
      {
        lower = tolower($0)
        if (!block && lower ~ /blocked\.md/ && lower ~ /create or update/ && lower ~ /first/) block = NR
        if (!status && lower ~ /status/ && lower ~ /last/ && lower ~ /blocked/) status = NR
      }
      END {
        if (block && status && block < status) print "ok"
        else print (block + 0) ":" (status + 0)
      }
    ' <<<"$section")"
    [[ "$order" == ok ]] || bad+=("$runtime:$order")
  done
  if [[ ${#bad[@]} -gt 0 ]]; then
    fail "implementation review blocker order: blocked.md creation/update must precede BLOCKED Status write (${bad[*]})"
  else
    ok "implementation review blocker order: receipt precedes Status transition"
  fi
}

schema_artifact_block() {
  local artifact="$1"
  awk -v artifact="$artifact" '
    $0 == "  - id: " artifact { found = 1 }
    found && $0 ~ /^  - id: / && $0 != "  - id: " artifact { exit }
    found { print }
  ' "$REPO_ROOT/openspec/schemas/story-change/schema.yaml"
}

require_schema_writer() {
  local artifact="$1" writer="$2" block
  block="$(schema_artifact_block "$artifact")"
  if [[ -z "$block" ]]; then
    fail "writer metadata: schema artifact '$artifact' is missing"
  elif ! grep -Fq -- "$writer" <<<"$block"; then
    fail "writer metadata: schema artifact '$artifact' omits $writer"
  else
    ok "writer metadata: $artifact includes $writer"
  fi
}

require_template_writer() {
  local artifact="$1" writer="$2" file
  file="$REPO_ROOT/openspec/schemas/story-change/templates/$artifact.md"
  if [[ ! -f "$file" ]]; then
    fail "writer metadata: template '$artifact.md' is missing"
  elif ! grep -Fq -- "$writer" "$file"; then
    fail "writer metadata: template '$artifact.md' omits $writer"
  else
    ok "writer metadata: $artifact.md includes $writer"
  fi
}

extract_shell_array() {
  local file="$1" array_name="$2"
  awk -v target="$array_name" '
    $0 ~ "^[[:space:]]*declare[[:space:]]+-a[[:space:]]+" target "=\\([[:space:]]*$" { inside = 1; next }
    inside && /^[[:space:]]*\)[[:space:]]*(#.*)?$/ { found = 1; exit }
    inside {
      line = $0
      sub(/[[:space:]]+#.*/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      gsub(/^['\''\"]|['\''\"]$/, "", line)
      if (line != "") print line
    }
    END { if (!found) exit 1 }
  ' "$file"
}

prune_manifest_matches_and_is_safe() {
  local file="$1" array_name="$2" expected_name="$3" active_name="$4"
  local actual_text expected_text item
  local -a actual=()
  local -n expected_ref="$expected_name"
  local -n active_ref="$active_name"
  if ! actual_text="$(extract_shell_array "$file" "$array_name")"; then
    return 1
  fi
  [[ -z "$actual_text" ]] || mapfile -t actual <<<"$actual_text"
  expected_text="$(printf '%s\n' "${expected_ref[@]}" | sort)"
  [[ "$(printf '%s\n' "${actual[@]:-}" | sed '/^$/d' | sort)" == "$expected_text" ]] || return 1
  for item in "${active_ref[@]:-}"; do
    [[ -z "$item" ]] && continue
    in_array "$item" "${actual[@]:-}" && return 1
  done
  return 0
}

check_production_prune_manifests() {
  local mutated="$TMPDIR/install-prune-mutation.sh"
  if prune_manifest_matches_and_is_safe "$REPO_ROOT/scripts/install.sh" UNSUPPORTED_SKILLS UNSUPPORTED_SKILLS CLAUDE_NAMES; then
    ok "Claude production prune manifest exactly matches lint inventory and excludes active skills"
  else
    fail "scripts/install.sh complete UNSUPPORTED_SKILLS manifest differs from lint inventory or includes an active skill"
  fi
  if prune_manifest_matches_and_is_safe "$REPO_ROOT/scripts/install-codex.sh" UNSUPPORTED_CODEX_SKILLS UNSUPPORTED_CODEX_SKILLS CODEX_NAMES; then
    ok "Codex production prune manifest exactly matches lint inventory and excludes active skills"
  else
    fail "scripts/install-codex.sh complete UNSUPPORTED_CODEX_SKILLS manifest differs from lint inventory or includes an active skill"
  fi
  if prune_manifest_matches_and_is_safe "$REPO_ROOT/scripts/install-pi.sh" UNSUPPORTED_PI_SKILLS UNSUPPORTED_SKILLS PI_GEN_NAMES; then
    ok "Pi production prune manifest exactly matches lint inventory and excludes active skills"
  else
    fail "scripts/install-pi.sh complete UNSUPPORTED_PI_SKILLS manifest differs from lint inventory or includes an active skill"
  fi

  # Prove that matching the expected stale names is not enough: introducing an
  # active utility into a production prune array must invalidate the manifest.
  awk '
    { print }
    /^declare -a UNSUPPORTED_SKILLS=\(/ && !added { print "  memorize"; added = 1 }
  ' "$REPO_ROOT/scripts/install.sh" >"$mutated"
  if prune_manifest_matches_and_is_safe "$mutated" UNSUPPORTED_SKILLS UNSUPPORTED_SKILLS CLAUDE_NAMES; then
    fail "prune-manifest mutation adding active skill memorize was not rejected"
  else
    ok "prune-manifest mutation adding memorize is rejected"
  fi
}

lint_suite_bootstrap() {
  local assigned_tmp="" assigned_root=""
  FAIL=0
  LINT_USING_AGGREGATE_ROOT=0

  if [[ -n "${LINT_SUITE_TMPDIR+x}" || -n "${LINT_AGGREGATE_TMP_ROOT+x}" ]]; then
    if [[ -z "${LINT_SUITE_TMPDIR:-}" || -z "${LINT_AGGREGATE_TMP_ROOT:-}" || \
          ! -d "$LINT_SUITE_TMPDIR" || -L "$LINT_SUITE_TMPDIR" || \
          ! -d "$LINT_AGGREGATE_TMP_ROOT" || -L "$LINT_AGGREGATE_TMP_ROOT" ]]; then
      printf 'FAIL unable to create private lint temporary directory\n' >&2
      return 1
    fi
    assigned_tmp="$(cd -- "$LINT_SUITE_TMPDIR" && pwd -P)" || assigned_tmp=""
    assigned_root="$(cd -- "$LINT_AGGREGATE_TMP_ROOT" && pwd -P)" || assigned_root=""
    if [[ -z "$assigned_tmp" || -z "$assigned_root" || "$assigned_tmp" != "$assigned_root" ]]; then
      printf 'FAIL unable to create private lint temporary directory\n' >&2
      return 1
    fi
    PRIVATE_TMPDIR="$assigned_tmp"
    LINT_USING_AGGREGATE_ROOT=1
  else
    if ! PRIVATE_TMPDIR="$(mktemp -d)" || [[ -z "$PRIVATE_TMPDIR" || ! -d "$PRIVATE_TMPDIR" ]]; then
      printf 'FAIL unable to create private lint temporary directory\n' >&2
      return 1
    fi
    trap 'rm -rf -- "$TMPDIR"' EXIT
  fi

  readonly TMPDIR="$PRIVATE_TMPDIR"
  export TMPDIR
  CODEX_SKILLS="$TMPDIR/codex-skills"
  PI_SKILLS="$TMPDIR/pi-skills"
}

lint_collect_source_inventory() {
  local skill_dir skill_md dir_name skill_name
  CLAUDE_NAMES=()
  if [[ -d "$CLAUDE_SKILLS" ]]; then
    for skill_dir in "$CLAUDE_SKILLS"/*/; do
      [[ -d "$skill_dir" ]] || continue
      dir_name="$(basename "$skill_dir")"
      skill_md="$skill_dir/SKILL.md"
      [[ -f "$skill_md" ]] || continue
      [[ "$(extract_name "$skill_md")" == "$dir_name" ]] && CLAUDE_NAMES+=("$dir_name")
    done
  fi
  OPENSPEC_WORKFLOW_SKILLS=()
  for skill_name in "${CLAUDE_NAMES[@]:-}"; do
    [[ "$skill_name" == openspec-* ]] && OPENSPEC_WORKFLOW_SKILLS+=("$skill_name")
  done
}

lint_generate_silently() {
  local generation_rc=0
  CODEX_SKILLS_DIR="$CODEX_SKILLS" "$REPO_ROOT/scripts/install-codex.sh" >/dev/null 2>&1 || generation_rc=1
  PI_SKILLS_DIR="$PI_SKILLS" "$REPO_ROOT/scripts/install-pi.sh" >/dev/null 2>&1 || generation_rc=1
  return "$generation_rc"
}

lint_collect_generated_inventory() {
  local skill_dir dir_name skill_md openai_yaml declared_name
  CODEX_NAMES=()
  for skill_dir in "$CODEX_SKILLS"/*/; do
    [[ -d "$skill_dir" ]] || continue
    dir_name="$(basename "$skill_dir")"
    skill_md="$skill_dir/SKILL.md"
    openai_yaml="$skill_dir/agents/openai.yaml"
    [[ -f "$skill_md" ]] || continue
    declared_name="$(extract_name "$skill_md")"
    [[ -n "$declared_name" && "$declared_name" == "$dir_name" ]] || continue
    [[ -f "$openai_yaml" ]] || continue
    grep -Eq '^[[:space:]]*allow_implicit_invocation:[[:space:]]*false' "$openai_yaml" || continue
    CODEX_NAMES+=("$dir_name")
  done
  PI_GEN_NAMES=()
  for skill_dir in "$PI_SKILLS"/*/; do
    [[ -d "$skill_dir" ]] || continue
    dir_name="$(basename "$skill_dir")"
    skill_md="$skill_dir/SKILL.md"
    [[ -f "$skill_md" ]] || continue
    declared_name="$(extract_name "$skill_md")"
    [[ -n "$declared_name" && "$declared_name" == "$dir_name" ]] || continue
    PI_GEN_NAMES+=("$dir_name")
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Aggregate allocation is never delegated by its caller. Child suites share
  # that exact root, matching the monolith's generated and scratch paths.
  unset LINT_SUITE_TMPDIR LINT_AGGREGATE_TMP_ROOT LINT_AGGREGATE_GENERATED_READY
  lint_suite_bootstrap || exit 1
  readonly LINT_AGGREGATE_TMP_ROOT="$TMPDIR"
  export LINT_AGGREGATE_TMP_ROOT
  export LINT_SUITE_TMPDIR="$LINT_AGGREGATE_TMP_ROOT"

  aggregate_fail=0
  bash "$REPO_ROOT/scripts/lint-structure.sh" --main || aggregate_fail=1
  bash "$REPO_ROOT/scripts/test-distribution.sh" --primary || aggregate_fail=1
  # Primary owns both generator attempts and their diagnostics. Every later
  # generated-content suite inventories the shared trees without regenerating.
  export LINT_AGGREGATE_GENERATED_READY=1
  bash "$REPO_ROOT/scripts/lint-workflow-contracts.sh" || aggregate_fail=1
  bash "$REPO_ROOT/scripts/test-distribution.sh" --generated || aggregate_fail=1
  bash "$REPO_ROOT/scripts/test-installers.sh" || aggregate_fail=1
  bash "$REPO_ROOT/scripts/test-distribution.sh" --content-hygiene || aggregate_fail=1
  bash "$REPO_ROOT/scripts/lint-structure.sh" --repository-hygiene || aggregate_fail=1
  bash "$REPO_ROOT/scripts/test-distribution.sh" --content-contracts || aggregate_fail=1
  echo
  if [[ $aggregate_fail -ne 0 ]]; then
    echo "lint: FAILED"
    exit 1
  fi
  echo "lint: PASSED"
fi
