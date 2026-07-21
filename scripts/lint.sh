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
#   24. The read-only implementation evaluator emits complete, stable review evidence.
#
# Exit codes:
#   0 — clean
#   1 — at least one finding

set -uo pipefail

export LC_ALL=C
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS="${REPO_ROOT}/claude/skills"
PI_FRAGMENTS="${REPO_ROOT}/pi-fragments"
if ! PRIVATE_TMPDIR="$(mktemp -d)" || [[ -z "$PRIVATE_TMPDIR" || ! -d "$PRIVATE_TMPDIR" ]]; then
  printf 'FAIL unable to create private lint temporary directory\n' >&2
  exit 1
fi
readonly TMPDIR="$PRIVATE_TMPDIR"
export TMPDIR
trap 'rm -rf -- "$TMPDIR"' EXIT
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
)
declare -a SCALAR_ONLY_OPENSPEC_SKILLS=(
  openspec-initiative-plan
  openspec-story-review
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

# Completion protocols are checked inside their owning workflow section rather
# than by whole-file presence, so explanatory prose cannot satisfy an
# operational checklist contract. Generated variants must retain the same
# heading and controlled prose.
check_workflow_section_contract() {
  local label="$1" skill="$2" heading="$3" codex_skill runtime file literal section
  local missing=()
  shift 3
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
    section="$(markdown_without_comments "$file" | awk -v heading="$heading" '
      $0 == heading { found = 1; print; next }
      found && /^##[[:space:]]/ { exit }
      found { print }
    ')"
    if [[ -z "$section" ]]; then
      missing+=("$runtime:section=$heading")
      continue
    fi
    for literal in "$@"; do
      grep -Fq -- "$literal" <<<"$section" || missing+=("$runtime:$literal")
    done
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "$label: missing fixed section contract token(s): ${missing[*]}"
  else
    ok "$label: canonical + generated Codex/Pi"
  fi
}

check_workflow_adjacent_lines_contract() {
  local label="$1" skill="$2" first="$3" second="$4" codex_skill runtime file
  local missing=()
  codex_skill="$(hyphen_to_underscore "$skill")"
  for runtime in canonical codex pi; do
    case "$runtime" in
      canonical) file="$CLAUDE_SKILLS/$skill/SKILL.md" ;;
      codex) file="$CODEX_SKILLS/$codex_skill/SKILL.md" ;;
      pi) file="$PI_SKILLS/$skill/SKILL.md" ;;
    esac
    if [[ ! -f "$file" ]] || ! markdown_without_comments "$file" | awk -v first="$first" -v second="$second" '
      previous == first && $0 == second { found = 1 }
      { previous = $0 }
      END { exit found ? 0 : 1 }
    '; then
      missing+=("$runtime")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "$label: missing exact adjacent-line block in ${missing[*]}"
  else
    ok "$label: canonical + generated Codex/Pi"
  fi
}

review_focus_template_issues() {
  local file="$1"
  markdown_without_comments "$file" | awk '
    function unwrap(line,    previous) {
      gsub(/\r/, "", line)
      do {
        previous = line
        sub(/^[[:space:]]*>[[:space:]]*/, "", line)
        sub(/^[[:space:]]*([-+*]|[0-9]+[.)])[[:space:]]+/, "", line)
        sub(/^[[:space:]]*##*[[:space:]]+/, "", line)
        sub(/^[[:space:]]*\|[[:space:]]*/, "", line)
      } while (line != previous)
      gsub(/[*_`]/, "", line)
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      return tolower(line)
    }
    /^#[[:space:]]+/ && !saw_title { saw_title = 1; next }
    /^[[:space:]]*(```|~~~)/ { in_fence = !in_fence; next }
    /^##[[:space:]]+/ && saw_title { metadata_done = 1 }
    {
      normalized = unwrap($0)
      field_like = (normalized ~ /^review[ _-]*focus[[:space:]]*(:|\||$)/)
      canonical = ($0 == "Review Focus: |" && saw_title && !metadata_done && !in_fence)
      if (canonical) canonical_count++
      if (field_like && !canonical) {
        extra_count++
        extra_lines = extra_lines (extra_lines ? "," : "") FNR
      }
    }
    END {
      if (canonical_count != 1) print "canonical-metadata-count=" (canonical_count + 0)
      if (extra_count) print "extra-field-like-lines=" extra_lines
    }
  '
}

check_review_focus_template_detector() {
  local sample="$TMPDIR/review-focus-template.md" wrapped
  printf '# Story\n\nReview Focus: |\n\n## Purpose\n' >"$sample"
  if [[ -n "$(review_focus_template_issues "$sample")" ]]; then
    fail "Review Focus template detector rejected its canonical fixture"
    return
  fi
  local -a wrapped_fields=(
    '> Review Focus: |'
    '- Review Focus: |'
    '1. Review Focus: |'
    '`Review Focus: |`'
    '**Review Focus: |**'
    '## Review Focus'
    '| Review Focus | guidance |'
  )
  for wrapped in "${wrapped_fields[@]}"; do
    printf '# Story\n\nReview Focus: |\n\n## Purpose\n%s\n' "$wrapped" >"$sample"
    if [[ -z "$(review_focus_template_issues "$sample")" ]]; then
      fail "Review Focus template detector accepted wrapped/extra field: $wrapped"
      return
    fi
  done
  printf '# Story\n\n```yaml\nReview Focus: |\n```\n\n## Purpose\n' >"$sample"
  if [[ -z "$(review_focus_template_issues "$sample")" ]]; then
    fail "Review Focus template detector accepted a fenced field"
    return
  fi
  ok "Review Focus template detector rejects wrapped, fenced, and extra field-like headers"
}

check_review_focus_mention_ownership() {
  local skill codex_skill runtime file findings
  local -a bad=()
  for skill in "${OPENSPEC_WORKFLOW_SKILLS[@]:-}"; do
    [[ -n "$skill" ]] || continue
    case "$skill" in
      openspec-story-claim|openspec-story-resume|openspec-story-review) continue ;;
    esac
    codex_skill="$(hyphen_to_underscore "$skill")"
    for runtime in canonical codex pi; do
      case "$runtime" in
        canonical) file="$CLAUDE_SKILLS/$skill/SKILL.md" ;;
        codex) file="$CODEX_SKILLS/$codex_skill/SKILL.md" ;;
        pi) file="$PI_SKILLS/$skill/SKILL.md" ;;
      esac
      if [[ ! -f "$file" ]]; then
        bad+=("$runtime:$skill:missing-file")
        continue
      fi
      if [[ "$skill" == openspec-feedback ]]; then
        findings="$(markdown_without_comments "$file" | awk '{ gsub(/`Review focus:`/, ""); print }' | grep -inF -- 'review focus' || true)"
      else
        findings="$(grep -inF -- 'review focus' < <(markdown_without_comments "$file") || true)"
      fi
      [[ -z "$findings" ]] || bad+=("$runtime:$skill:lines=$(cut -d: -f1 <<<"$findings" | paste -sd, -)")
    done
  done
  if [[ ${#bad[@]} -gt 0 ]]; then
    fail "active Review Focus mentions are permitted only in claim, resume, review, and feedback's exact packet scalar: ${bad[*]}"
  else
    ok "active Review Focus mentions occur only in claim, resume, review, and feedback's exact packet scalar across canonical + generated Codex/Pi"
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

has_positive_packet_ledger_write() {
  local text
  text="$(markdown_without_comments /dev/stdin)"
  awk '
    { text = text " " tolower($0) }
    END {
      # Protect Markdown path suffixes so sentence splitting keeps the path and
      # its surrounding writer/object phrase in one candidate.
      gsub(/\.md/, "__markdown_suffix__", text)
      count = split(text, clause, /[.;]|[[:space:]]+(but|however)[[:space:]]+/)
      for (i = 1; i <= count; i++) {
        candidate = clause[i]
        gsub(/__markdown_suffix__/, ".md", candidate)
        gsub(/(instead of|rather than)[[:space:]]+(a[[:space:]]+|the[[:space:]]+)?(review packet|packet metadata|packet.s metadata|feedback receipts?|review cycles?|identity digests?|review (history|timeline)|publication log)/, "", candidate)
        gsub(/retains?[[:space:]]+the[[:space:]]+existing[[:space:]]+receipt-based[[:space:]]+compatibility[[:space:]]+contract/, "", candidate)
        packet_ledger = candidate ~ /(review packet|packet metadata|packet.s metadata|feedback receipts?|review cycles?|identity digests?|review (history|timeline)|publication log)/
        addition = candidate ~ /(^|[^a-z])(save|saves|saved|saving|copy|copies|copied|copying|store|stores|stored|storing|persist|persists|persisted|persisting|write|writes|wrote|written|writing|append|appends|appended|appending|create|creates|created|creating|emit|emits|emitted|emitting|record|records|recorded|recording|log|logs|logged|logging|retain|retains|retained|retaining|mirror|mirrors|mirrored|mirroring|update|updates|updated|updating|maintain|maintains|maintained|maintaining)([^a-z]|$)/
        negative = candidate ~ /(^|[^a-z])(do not|don.t|must not|never|no new|without|forbid|forbids|forbidden)([^a-z]|$)/
        if (packet_ledger && addition && !negative) found = 1
      }
      exit found ? 0 : 1
    }
  ' <<<"$text"
}

has_stale_story_review_writer_claim() {
  awk '
    function stale_paragraph(text, count, clause, i, candidate, writer_candidate,
                             explicit_writer, other_writer, artifact, mutation,
                             negative, writer_context) {
      text = tolower(text)
      # Template comments are contractual prose, and .md path dots are not
      # sentence boundaries.
      gsub(/\.md/, "__markdown_suffix__", text)
      count = split(text, clause, /[.;]|[[:space:]]+(but|however)[[:space:]]+/)
      writer_context = 0
      for (i = 1; i <= count; i++) {
        candidate = clause[i]
        gsub(/__markdown_suffix__/, ".md", candidate)
        writer_candidate = candidate
        gsub(/implementation review receipt/, "receipt", writer_candidate)
        explicit_writer = writer_candidate ~ /(\/openspec-story-review|implementation review|readonly review)/
        other_writer = candidate ~ /\/openspec-feedback/ || (candidate ~ /\/openspec-/ && !explicit_writer)
        if (explicit_writer) writer_context = 1
        else if (other_writer) writer_context = 0
        artifact = candidate ~ /(receipt|status|timeline|blocked\.md|progress\.md|story\.md)/
        mutation = candidate ~ /(^|[^a-z])(own|owns|write|writes|wrote|written|writing|create|creates|created|creating|append|appends|appended|appending|publish|publishes|published|publishing|record|records|recorded|recording|replace|replaces|replaced|replacing|update|updates|updated|updating)([^a-z]|$)/
        negative = candidate ~ /(^|[^a-z])(do not|does not|must not|never|no[[:space:]]+(write|status|receipt|timeline|blocked)|owns?[[:space:]]+no|without|only reads|reader compatibility|not evaluator-owned)([^a-z]|$)/
        if (!other_writer && (explicit_writer || writer_context) && artifact && mutation && !negative) return 1
      }
      return 0
    }
    /^[[:space:]]*$/ {
      if (stale_paragraph(paragraph)) found = 1
      paragraph = ""
      next
    }
    { paragraph = paragraph " " $0 }
    END {
      if (stale_paragraph(paragraph)) found = 1
      exit found ? 0 : 1
    }
  '
}

has_exact_consumer_finding_manifest() {
  grep -Fq -- 'The exact consumer finding-field manifest is: `Finding ID:`, `Severity:`, `Summary:`, `Evidence:`, `Impact:`, `Proof / verification:`, `Requested outcome:`.'
}

has_exact_malformed_packet_fallback_contract() {
  local text
  text="$(cat)"
  grep -Fq -- 'A malformed, truncated, or internally stale packet fails these grammar/intake gates with zero writes and requires a fresh complete packet.' <<<"$text" &&
    grep -Fq -- 'Packet-like input that fails this contract never falls through to ordinary feedback mode.' <<<"$text"
}

check_feedback_review_packet_triage_contract() {
  local skill=openspec-feedback producer=openspec-story-review codex_skill producer_codex
  local runtime file producer_file section whole key pattern scalar packet_schema
  local actual_packet_labels expected_packet_labels mutated_section finding_field needle
  local -a missing=()
  local -a section_contracts=(
    validation-section '### Validate and bind before triage'
    decision-section '### Build one complete triage decision'
    confirmation-section '### Single confirmation and zero-write exits'
    publication-section '### Apply, verify, and publish'
  )
  local -a relationships=(
    pair-root-label '**Pair-qualified root contract.**'
    pair-root-artifacts 'both the packet initiative artifact and packet story artifact'
    pair-root-precedence 'explicit selector, then the unique exact initiative/story branch worktree, then launch root'
    explicit-root-unregistered 'An explicit `WORKTREE=` path may qualify whether or not it is registered'
    legacy-binding-label '**Packet legacy-binding compatibility.**'
    legacy-binding-unique 'exactly one unique exact `## Story Candidates` association'
    legacy-binding-explicit-pair 'the packet’s explicit `Initiative:`/`Story:` pair is the compatibility fallback'
    legacy-binding-conflict 'different or multiple exact associations'
    legacy-binding-confirmed-repair 'canonical header edit is part of the complete confirmed triage set'
    grammar-qualification-separation 'Packet grammar validation is separate from artifact qualification'
    not-reviewable-routing-only 'routing-only, zero-write branch'
    not-reviewable-all-findings 'Disposition every packet and operator-added finding together'
    not-reviewable-owner-route 'route the failed prerequisite to its owning workflow'
    initial-state '`Status: 🟣 IN REVIEW`'
    dispositions '`accept`, `reject-or-waive`, `defer`, or `re-scope`'
    atomic-confirmation 'complete triage set'
    zero-write 'zero writes'
    bounded-destination-label '**Bounded destination contract.**'
    bounded-destination 'writes stay inside the bound current story and current initiative'
    blocker-label '**Blocker publication contract.**'
    blocker-existing 'exactly matches the planned final bytes'
    blocker-conflict 'conflicting existing `blocked.md`'
    blocked-verdict-external '`BLOCKED` packet with an accepted external blocker'
    blocked-verdict-current '`BLOCKED` packet with accepted current-story correction'
    blocked-verdict-unresolved '`BLOCKED` packet with neither accepted outcome'
    completion-verdicts 'Only `APPROVE` and `REQUEST CHANGES` packets'
    rerun-label '**Rerun contract.**'
    rerun-state 'Status remains `🟣 IN REVIEW`'
    status-last 'Status remains the final operation'
    no-ledger 'must not create or append feedback receipts, review cycles, identity digests, or review history'
    ordinary-compatibility 'ordinary mode retains the existing receipt-based compatibility contract'
  )
  local -a packet_scalars=(
    'Review mode' 'Review focus' 'Subject' 'Root' 'Initiative' 'Story' 'Verdict'
    'Coverage' 'Acceptance / proof assessment' 'Verification run'
    'Red-first assessment' 'Final stability recheck' 'Finding count'
  )
  local -a consumer_finding_fields=(
    'Finding ID' 'Severity' 'Summary' 'Evidence' 'Impact'
    'Proof / verification' 'Requested outcome'
  )
  expected_packet_labels="$(cat <<'EOF'
Review mode
Review focus
Subject
Root
Initiative
Story
Verdict
Coverage
Acceptance / proof assessment
Verification run
Red-first assessment
Final stability recheck
Finding count
Findings
Finding ID
Severity
Summary
Evidence
Impact
Proof / verification
Requested outcome
Next step
EOF
)"

  codex_skill="$(hyphen_to_underscore "$skill")"
  producer_codex="$(hyphen_to_underscore "$producer")"
  for runtime in canonical codex pi; do
    case "$runtime" in
      canonical)
        file="$CLAUDE_SKILLS/$skill/SKILL.md"
        producer_file="$CLAUDE_SKILLS/$producer/SKILL.md"
        ;;
      codex)
        file="$CODEX_SKILLS/$codex_skill/SKILL.md"
        producer_file="$CODEX_SKILLS/$producer_codex/SKILL.md"
        ;;
      pi)
        file="$PI_SKILLS/$skill/SKILL.md"
        producer_file="$PI_SKILLS/$producer/SKILL.md"
        ;;
    esac
    whole="$(markdown_without_comments "$file")"
    section="$(markdown_section /dev/stdin '## Review packet triage mode' <<<"$whole")"
    packet_schema="$(awk '/^```ADD-REVIEW-PACKET\/1$/ { inside=1; next } inside && /^```$/ { exit } inside { print }' "$producer_file")"
    actual_packet_labels="$(awk -F': ' 'NF { print $1 }' <<<"$packet_schema")"
    [[ "$actual_packet_labels" == "$expected_packet_labels" ]] || missing+=("$runtime:producer-schema-order-or-extra")
    if [[ -z "$section" ]]; then
      missing+=("$runtime:section")
      continue
    fi
    if ! awk '/^## Mode router$/ { router=NR } /^## Important$/ { important=NR } END { exit !(router && important && router < important) }' <<<"$whole"; then
      missing+=("$runtime:router-order")
    fi
    for ((i = 0; i < ${#section_contracts[@]}; i += 2)); do
      key="${section_contracts[i]}"
      pattern="${section_contracts[i + 1]}"
      grep -Fq -- "$pattern" <<<"$section" || missing+=("$runtime:$key")
    done
    for ((i = 0; i < ${#relationships[@]}; i += 2)); do
      key="${relationships[i]}"
      pattern="${relationships[i + 1]}"
      grep -Fqi -- "$pattern" <<<"$section" || missing+=("$runtime:$key")
    done
    for scalar in "${packet_scalars[@]}"; do
      grep -Eq "^${scalar}:" "$producer_file" || missing+=("$runtime:producer-scalar:$scalar")
      grep -Fq -- "\`$scalar:\`" <<<"$section" || missing+=("$runtime:consumer-scalar:$scalar")
    done
    has_exact_consumer_finding_manifest <<<"$section" || missing+=("$runtime:consumer-finding-field-manifest")
    for finding_field in "${consumer_finding_fields[@]}"; do
      needle="\`$finding_field:\`"
      mutated_section="${section/"$needle"/\`MISSING FIELD:\`}"
      if has_exact_consumer_finding_manifest <<<"$mutated_section"; then
        missing+=("$runtime:mutation-missing-consumer-field:$finding_field")
      fi
    done
    has_exact_malformed_packet_fallback_contract <<<"$section" || missing+=("$runtime:malformed-packet-fallback")
    mutated_section="${section/never falls through to ordinary feedback mode/may fall through to ordinary feedback mode}"
    if has_exact_malformed_packet_fallback_contract <<<"$mutated_section"; then
      missing+=("$runtime:mutation-malformed-packet-fallback")
    fi
    for pattern in 'Critical' 'High' 'Medium' 'Low' 'Info'; do
      grep -Fq -- "\`$pattern\`" <<<"$section" || missing+=("$runtime:severity:$pattern")
    done
    grep -Fq 'reject every unrecognized, additional, duplicated, or out-of-order line' <<<"$section" || missing+=("$runtime:reject-extra-lines")
    if has_positive_packet_ledger_write <<<"$section"; then
      missing+=("$runtime:packet-ledger-addition")
    fi
  done

  if ! has_positive_packet_ledger_write <<'EOF'
Review packet mode must not create feedback receipts; however append review history after completion.
EOF
  then
    missing+=("detector:mixed-positive-negative")
  fi
  if ! has_positive_packet_ledger_write <<'EOF'
Store review history after completion.
EOF
  then
    missing+=("detector:store-positive")
  fi
  if ! has_positive_packet_ledger_write <<'EOF'
Save/copy the review packet into story.md.
EOF
  then
    missing+=("detector:save-copy-packet")
  fi
  if ! has_positive_packet_ledger_write <<'EOF'
Persist packet
metadata in progress.md.
EOF
  then
    missing+=("detector:wrapped-packet-metadata")
  fi
  if ! has_positive_packet_ledger_write <<'EOF'
Write to progress.md the review packet.
EOF
  then
    missing+=("detector:path-before-review-packet")
  fi
  if ! has_positive_packet_ledger_write <<'EOF'
Record in story.md the packet metadata.
EOF
  then
    missing+=("detector:path-before-packet-metadata")
  fi
  if ! has_positive_packet_ledger_write <<'EOF'
Retain the review packet in progress.md.
EOF
  then
    missing+=("detector:retain-review-packet")
  fi
  if ! has_positive_packet_ledger_write <<'EOF'
Mirror the review packet into initiative.md.
EOF
  then
    missing+=("detector:mirror-review-packet")
  fi
  if has_positive_packet_ledger_write <<'EOF'
Record canonical rationale instead of review history.
EOF
  then
    missing+=("detector:negative-comparison")
  fi
  if has_positive_packet_ledger_write <<'EOF'
<!-- Store review history while debugging this checker. -->
Review packet mode must not create or append feedback receipts, review cycles, identity digests, or review history.
EOF
  then
    missing+=("detector:comments-or-negative")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "feedback review-packet triage: incomplete contract(s): ${missing[*]}"
  else
    ok "feedback review-packet triage: producer-coupled grammar, bounded routing, atomic publication, and lifecycle contracts in canonical + generated Codex/Pi"
  fi
}

check_readonly_review_write_ownership_docs() {
  local file findings sample
  local -a bad=()
  for file in "$README_DOC" "$LIFECYCLE_DOC" "$CONVENTIONS_DOC" "$STORY_SCHEMA" "$STORY_TEMPLATE" "$PROGRESS_TEMPLATE" "$BLOCKED_TEMPLATE"; do
    findings="$(has_stale_story_review_writer_claim <"$file" && printf stale || true)"
    [[ -z "$findings" ]] || bad+=("$file")
  done
  sample='Implementation review writes the receipt and Status last.'
  has_stale_story_review_writer_claim <<<"$sample" || bad+=("detector:missed-positive")
  sample='<!-- /openspec-story-review writes the review receipt. -->'
  has_stale_story_review_writer_claim <<<"$sample" || bad+=("detector:missed-comment-positive")
  sample='Readonly review writes Status.'
  has_stale_story_review_writer_claim <<<"$sample" || bad+=("detector:missed-readonly-positive")
  sample='Implementation review updates progress.md with the receipt.'
  has_stale_story_review_writer_claim <<<"$sample" || bad+=("detector:missed-path-positive")
  sample='/openspec-story-review is read-only. Every completed verdict writes Status and the receipt.'
  has_stale_story_review_writer_claim <<<"$sample" || bad+=("detector:missed-anaphoric-positive")
  sample='Readonly /openspec-story-review only reads legacy receipts and owns no Status write.'
  if has_stale_story_review_writer_claim <<<"$sample"; then
    bad+=("detector:false-positive")
  fi
  if [[ ${#bad[@]} -gt 0 ]]; then
    fail "readonly review write ownership: stale writer claim(s): ${bad[*]}"
  else
    ok "readonly review write ownership: README/docs/schema and story/progress/blocked templates exclude evaluator mutation claims"
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

review_runtime_file() {
  local runtime="$1"
  case "$runtime" in
    canonical) printf '%s\n' "$CLAUDE_SKILLS/openspec-story-review/SKILL.md" ;;
    codex) printf '%s\n' "$CODEX_SKILLS/openspec_story_review/SKILL.md" ;;
    pi) printf '%s\n' "$PI_SKILLS/openspec-story-review/SKILL.md" ;;
    *) return 1 ;;
  esac
}

review_packet_block() {
  local file="$1"
  awk '
    $0 == "```ADD-REVIEW-PACKET/1" { inside = 1; next }
    inside && $0 == "```" { exit }
    inside { print }
  ' "$file"
}

review_packet_fence_shape() {
  local file="$1"
  awk '
    $0 == "```ADD-REVIEW-PACKET/1" {
      openings++
      inside = 1
      next
    }
    inside && $0 == "```" {
      closings++
      inside = 0
    }
    END { print openings + 0 ":" closings + 0 ":" inside + 0 }
  ' "$file"
}

review_publication_lines() {
  local file="$1"
  markdown_without_comments "$file" | awk '
    function normalize(text, normalized) {
      normalized = tolower(text)
      gsub(/[*`_]/, "", normalized)
      return normalized
    }
    function has_target(text) {
      return text ~ /(^|[^a-z])(status|receipt|timeline|blocked\.md|product[ -]+(source|code|files?|artifacts?)|openspec[ -]+artifacts?|notebook[ -]+(state|pages?|findings|memory)|story\.md|progress\.md|initiative\.md|proposal\.md|design\.md|tasks\.md)([^a-z]|$)/
    }
    function is_prohibition(text) {
      return text ~ /(^|[^a-z])(do not|don.t|never|must not|may not|cannot|can.t|forbid|prohibit|leave unchanged)([^a-z]|$)/ ||
        text ~ /(^|[^a-z])no[[:space:]]+[^.;]*(writes?|writing|edits?|editing|modif(y|ies|ying|ied)|updates?|updating|creates?|creating|appends?|appending|persists?|persisting|publishes?|publishing|saves?|saving|stores?|storing|deletes?|deleting|removes?|removing|replaces?|replacing|normalizes?|normalizing|reconciles?|reconciling|changes?|changing|backfills?|backfilling)([^a-z]|$)/ ||
        text ~ /without[[:space:]]+[^.;]*(writing|editing|modifying|updating|creating|appending|persisting|publishing|saving|storing|deleting|removing|replacing|normalizing|reconciling|changing|backfilling)/ ||
        text ~ /read[- ]only[[:space:]]+(for|on)[[:space:]]+[^.;]*$/
    }
    function is_current_record_predicate(text) {
      return text ~ /^(the[[:space:]]+)?receipt[[:space:]]+is[[:space:]]+the[[:space:]]+current[[:space:]]+record[[:space:]]*[,.:;!?]*$/
    }
    function mutation_near_target(text, rest, offset, position, window) {
      rest = text
      offset = 0
      while (match(rest, /(^|[^a-z])(write|writes|writing|wrote|written|edit|edits|editing|edited|modify|modifies|modifying|modified|update|updates|updating|updated|create|creates|creating|created|append|appends|appending|appended|persist|persists|persisting|persisted|publish|publishes|publishing|published|save|saves|saving|saved|store|stores|storing|stored|set|sets|setting|record|records|recording|recorded|delete|deletes|deleting|deleted|remove|removes|removing|removed|replace|replaces|replacing|replaced|normalize|normalizes|normalizing|normalized|reconcile|reconciles|reconciling|reconciled|backfill|backfills|backfilling|backfilled)([^a-z]|$)/)) {
        position = offset + RSTART
        window = substr(text, position > 180 ? position - 180 : 1, RLENGTH + 360)
        if (has_target(window)) return 1
        offset += RSTART + RLENGTH - 1
        rest = substr(rest, RSTART + RLENGTH)
      }
      return 0
    }
    function inspect(raw, line_number, clause) {
      clause = normalize(raw)
      sub(/^[[:space:]]+/, "", clause)
      sub(/[[:space:]]+$/, "", clause)
      if (clause == "" || is_prohibition(clause)) return
      if (match(clause, /^set[[:space:]]+<[^>]+>[[:space:]]*=/))
        clause = substr(clause, RLENGTH + 1)
      if (is_current_record_predicate(clause)) return
      if (mutation_near_target(clause)) {
        print line_number ":" raw
        bad = 1
      }
    }
    function inspect_line(raw, line_number, start, i, char, following, lower, word, before, after) {
      start = 1
      lower = tolower(raw)
      for (i = 1; i <= length(raw); i++) {
        char = substr(raw, i, 1)
        following = substr(raw, i + 1, 1)
        word = ""
        if (substr(lower, i, 3) == "but") word = "but"
        else if (substr(lower, i, 7) == "however") word = "however"
        if (word != "") {
          before = i == 1 ? "" : substr(lower, i - 1, 1)
          after = substr(lower, i + length(word), 1)
          if ((before == "" || before !~ /[a-z]/) && (after == "" || after !~ /[a-z]/)) {
            inspect(substr(raw, start, i - start), line_number)
            i += length(word) - 1
            start = i + 1
            continue
          }
        }
        if (char == ";" || (char == "." && (following == "" || following ~ /[[:space:]]/))) {
          inspect(substr(raw, start, i - start), line_number)
          start = i + 1
        }
      }
      inspect(substr(raw, start), line_number)
    }
    { inspect_line($0, FNR) }
    END { exit bad ? 0 : 1 }
  '
}

check_review_publication_detector() {
  local sample index=0
  local -a bad_samples=(
    'Write the top-level Status last.'
    'Reconcile every Implementation Review Receipt before returning.'
    'Append one verdict entry to the progress timeline.'
    'Create or update blocked.md first.'
    'Modify product files only when the fix is obvious.'
    'Publish the verdict in OpenSpec artifacts.'
    'Persist supplemental findings to notebook state.'
    'Do not edit product files; save the result to a notebook page.'
    'Do not edit product files, but save the result to a notebook page.'
    'Do not edit product files, however, save the result to a notebook page.'
    'Do not edit product files; however, save the result to a notebook page.'
    'Set Status to DONE.'
    'Record the verdict in progress.md.'
  )
  local -a good_samples=(
    'Do not write Status, receipts, timelines, or blocked.md.'
    'Product files and OpenSpec artifacts are read-only for this evaluator.'
    'Read story.md Status and inspect progress.md for a legacy prerequisite receipt.'
    'A sibling blocked.md makes the prerequisite unsatisfied.'
    'Require a legacy prerequisite to have exactly one receipt; never normalize it.'
    'Do not modify product files or OpenSpec artifacts; do not persist notebook state.'
    'Resolve active <openspec_root>/openspec/changes/<prerequisite-slug>/story.md first.'
    'Set <story_file> = .../story.md.'
    'The receipt is the current record.'
  )
  for sample in "${bad_samples[@]}"; do
    printf '%s\n' "$sample" >"$TMPDIR/review-publication-$index.md"
    if ! review_publication_lines "$TMPDIR/review-publication-$index.md" >/dev/null; then
      fail "review publication detector missed affirmative sample: $sample"
      return
    fi
    index=$((index + 1))
  done
  for sample in "${good_samples[@]}"; do
    printf '%s\n' "$sample" >"$TMPDIR/review-publication-$index.md"
    if review_publication_lines "$TMPDIR/review-publication-$index.md" >/dev/null; then
      fail "review publication detector flagged prohibition/read-only input: $sample"
      return
    fi
    index=$((index + 1))
  done
  ok "review publication detector catches controlled-prose writes and preserves prohibitions/read-only legacy inputs"
}

check_review_readonly_evaluator_contract() {
  local runtime file readonly_count fence_shape packet missing forbidden required publication
  local -a bad=()
  check_review_publication_detector
  for runtime in canonical codex pi; do
    file="$(review_runtime_file "$runtime")"
    readonly_count="$(awk '
      NR == 1 && $0 == "---" { frontmatter = 1; next }
      frontmatter && $0 == "---" { exit }
      frontmatter && $0 == "readonly: true" { count++ }
      END { print count + 0 }
    ' "$file")"
    [[ "$readonly_count" -eq 1 ]] || bad+=("$runtime:readonly=$readonly_count")

    publication="$(review_publication_lines "$file" || true)"
    [[ -z "$publication" ]] || bad+=("$runtime:publication-lines=$(wc -l <<<"$publication" | tr -d ' ')")

    fence_shape="$(review_packet_fence_shape "$file")"
    if [[ "$fence_shape" != "1:1:0" ]]; then
      bad+=("$runtime:packet-fences=$fence_shape")
      continue
    fi
    packet="$(review_packet_block "$file")"
    missing=()
    for required in \
      'Review mode: <full | focused>' \
      'Review focus: <focus summary | none>' \
      'Subject: <reviewed implementation>' \
      'Root: <resolved OpenSpec root>' \
      'Initiative: <initiative-slug>' \
      'Story: <story-slug>' \
      'Verdict: APPROVE | REQUEST CHANGES | BLOCKED | NOT REVIEWABLE' \
      'Coverage: <inspected surfaces and intentionally uninspected surfaces>' \
      'Acceptance / proof assessment: <acceptance and proof disposition>' \
      'Verification run: <commands and results inspected | not run with reason>' \
      'Red-first assessment: <red-first seam | documented exception | alternative proof>' \
      'Final stability recheck: <stable | drift details>' \
      'Finding count: <nonnegative integer>' \
      'Findings: none' \
      'Finding ID: <stable local ID>' \
      'Severity: <severity>' \
      'Summary: <concise finding>' \
      'Evidence: <path:line anchors>' \
      'Impact: <operator-facing consequence>' \
      'Proof / verification: <commands and results | not run with reason>' \
      'Requested outcome: <concrete correction or evidence needed>' \
      'Next step: /openspec-feedback'; do
      grep -Fxq -- "$required" <<<"$packet" || missing+=("$required")
    done
    [[ ${#missing[@]} -eq 0 ]] || bad+=("$runtime:packet-schema-missing=${#missing[@]}")

    forbidden="$(grep -Ein -- '(^|[^[:alnum:]_])(cycle[ _-]*id|fingerprint|digest|lock|cas|receipt|timeline|blocked\.md|status[[:space:]]*(transition|publication|write))([^[:alnum:]_]|$)' <<<"$packet" || true)"
    [[ -z "$forbidden" ]] || bad+=("$runtime:forbidden-packet-field")
  done

  if [[ ${#bad[@]} -gt 0 ]]; then
    fail "readonly implementation-review evaluator contract: ${bad[*]}"
  else
    ok "readonly implementation-review evaluator has exact metadata, lifecycle entry, and one portable final-response packet"
  fi

  check_workflow_contract \
    "implementation review exact entry state" openspec-story-review \
    'Proceed only when entry is exactly `Status: 🟣 IN REVIEW`.' \
    'Reject `✅ DONE` and every other entry Status as `NOT REVIEWABLE`; never perform a lifecycle review outside `🟣 IN REVIEW`.'
  check_workflow_contract \
    "implementation review immutable final response" openspec-story-review \
    'Return exactly one fenced `ADD-REVIEW-PACKET/1` packet as the entire final response, with no text before or after its matching closing fence.' \
    'Set `Finding count` to a base-10 nonnegative integer equal to the number of emitted finding blocks.' \
    'When `Finding count: 0`, emit exactly `Findings: none` and no finding blocks.' \
    'When `Finding count` is nonzero, omit `Findings: none` and emit exactly that many finding blocks.' \
    'Do not modify product files, OpenSpec artifacts, or notebook state; do not persist review output anywhere.' \
    'Do not disposition findings; `/openspec-feedback` owns disposition and durable publication.' \
    'The direct next step for every packet verdict is `/openspec-feedback`.'

  check_workflow_contract \
    "implementation review hardened evidence and stability contract" openspec-story-review \
    'Assess whether the implementation used a red-first seam; when red-first was infeasible, require a documented exception or alternative proof.' \
    'Immediately before packet emission, re-read entry `Status:`, `Review Focus: |`, sibling `blocked.md` existence, every prerequisite gate, and critical reviewed evidence.' \
    'If lifecycle or evidence drifted, do not emit `APPROVE` or `REQUEST CHANGES` from stale evidence; emit `NOT REVIEWABLE` with the drift details.' \
    'Emit `Coverage`, `Acceptance / proof assessment`, `Verification run`, `Red-first assessment`, and `Final stability recheck` for every verdict, including when `Finding count: 0`.' \
    'Each finding block is exactly seven lines, from `Finding ID` through `Requested outcome`.'
  forbid_workflow_literal \
    "implementation review has no six-line finding-block contract" openspec-story-review \
    'repeat the six-line finding block'

  forbid_workflow_literal \
    "implementation review has no notebook persistence API" \
    openspec-story-review notebook_write
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

forbid_schema_writer() {
  local artifact="$1" writer="$2" block
  block="$(schema_artifact_block "$artifact")"
  if [[ -z "$block" ]]; then
    fail "writer metadata: schema artifact '$artifact' is missing"
  elif grep -Fq -- "$writer" <<<"$block"; then
    fail "writer metadata: schema artifact '$artifact' still names readonly evaluator $writer"
  else
    ok "writer metadata: $artifact excludes readonly evaluator $writer"
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

forbid_template_writer() {
  local artifact="$1" writer="$2" file
  file="$REPO_ROOT/openspec/schemas/story-change/templates/$artifact.md"
  if [[ ! -f "$file" ]]; then
    fail "writer metadata: template '$artifact.md' is missing"
  elif grep -Fq -- "$writer" "$file"; then
    fail "writer metadata: template '$artifact.md' still names readonly evaluator $writer"
  else
    ok "writer metadata: $artifact.md excludes readonly evaluator $writer"
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
  check_frontmatter_unique_keys "$skill_md"
  check_frontmatter_yaml_scalar_safety "$skill_md"

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
  check_frontmatter_unique_keys "$skill_md"
  check_frontmatter_yaml_scalar_safety "$skill_md"

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
check_production_prune_manifests

echo
echo "lint: OpenSpec lifecycle semantic invariants"

CANONICAL_SLUG_REGEX='^[a-z0-9]+(?:-[a-z0-9]+)*$'
README_DOC="$REPO_ROOT/README.md"
STORY_SCHEMA="$REPO_ROOT/openspec/schemas/story-change/schema.yaml"
STORY_TEMPLATE="$REPO_ROOT/openspec/schemas/story-change/templates/story.md"
PROGRESS_TEMPLATE="$REPO_ROOT/openspec/schemas/story-change/templates/progress.md"
BLOCKED_TEMPLATE="$REPO_ROOT/openspec/schemas/story-change/templates/blocked.md"
CONVENTIONS_DOC="$REPO_ROOT/docs/openspec-conventions.md"
LIFECYCLE_DOC="$REPO_ROOT/docs/openspec-lifecycle.md"

# Exact frontmatter key/token parsing is itself an invariant: duplicate keys or
# malformed suffixes must not silently select a permissive value/token prefix.
check_frontmatter_duplicate_detector
check_allowed_tool_tokenizer

# Story binding and operator-explicit review menus use story.md as authority.
# Zero-reference legacy acceptance is permitted only after an initiative is
# explicit/menu-selected; initiative discovery itself lists only bound stories.
require_literal "initiative binding template" "$STORY_TEMPLATE" 'Initiative: <initiative-slug>'
require_schema_writer story 'Initiative:'
require_workflow_literal "initiative binding writer" openspec-story-plan 'Initiative: <initiative-slug>'
check_workflow_contract \
  "implementation review bound-story menu" openspec-story-review \
  'a canonical top-level `Initiative:` header wins; otherwise only a unique exact `## Story Candidates` association binds the legacy workspace.' \
  'Exclude malformed, conflicting, multiply-associated, and zero-reference legacy workspaces from this initiative menu because no explicit initiative has yet accepted them.' \
  'Enumerate only workspaces explicitly bound to it or uniquely candidate-associated with it.' \
  'If no initiative references it, accept only when `<explicit_pair>` is true; emit a compatibility warning and do not backfill the header.'
check_workflow_contract \
  "planning review bound-story menu" openspec-story-plan-review \
  'For menu/discovery scans, enumerate active `<root>/openspec/changes/*/story.md` workspaces across `<candidate_roots>`; never drive membership from initiative prose.' \
  'Inventory the complete top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line.' \
  'any other malformed Initiative-like line halts without editing and reports every offending line. Never reinterpret malformed present input as zero-header legacy.' \
  'No association is accepted only when `<explicit_pair>` is true and the selected initiative file exists.'
require_literal "legacy initiative binding policy" "$CONVENTIONS_DOC" 'Legacy stories without an `Initiative:` header'
check_workflow_contract \
  "feedback uniform explicit-pair legacy qualification" openspec-feedback \
  'Duplicate headers, empty values, malformed header syntax, or noncanonical values are hard conflicts, not legacy input; halt without relabeling or repair.' \
  'Every no-header target qualifies for any story disposition, including status-only resume or receipt backfill, only after the operator acknowledges a plan that names the exact `<initiative-slug>` + `<story-slug>` pair' \
  'a refreshed scan proves that no other initiative has an exact Story Candidates reference.'
check_workflow_contract \
  "feedback initiative-only authoritative root" openspec-feedback \
  'Set `<receipt_root>` exactly once for the invocation.' \
  'Never default an initiative-only batch blindly to `<launch_root>`.' \
  'including an initiative-only batch, refresh `git worktree list --porcelain`, rerun Phase 0' \
  're-read `<receipt_root>/openspec/initiatives/<initiative-slug>/initiative.md` and revalidate every initiative-only disposition against that authoritative context'

# Next-action resolves selected and broad-scan stories across candidate roots
# before lifecycle routing and never silently chooses a stale duplicate.
check_workflow_contract \
  "next-action transient root" openspec-next-action \
  'Build `<candidate_roots>` before declaring any target missing.' \
  'First inspect explicit `WORKTREE=` paths that are `<workspace_root>` or registered worktrees and contain the selected story plus its bound/associated initiative file.' \
  'Only when no explicit path qualifies, inspect registered worktrees other than `<workspace_root>`' \
  'Recompute all paths after selection.' \
  'aggregate active `openspec/changes/*/story.md` workspaces across `<candidate_roots>`'
check_workflow_contract \
  "implementation review explicit-root precedence" openspec-story-review \
  'Inspect all explicit `WORKTREE=` values in either accepted form first.' \
  'If exactly one explicit candidate qualifies, set `<openspec_root>=<path>` immediately' \
  'Only when no explicit candidate qualifies, inspect registered root-repo worktrees other than `<workspace_root>`' \
  'that unique branch worktree outranks launch.'
check_workflow_contract \
  "next-action exact Initiative-like binding validation" openspec-next-action \
  'Inventory the complete top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line.' \
  'any other malformed Initiative-like line halts and reports every offending line. Never reinterpret malformed present input as a zero-header legacy story.' \
  'Only zero Initiative or Initiative-like lines is legacy.'
check_workflow_contract \
  "next-action story-scoped DONE receipt and PR verification" openspec-next-action \
  'A modern DONE receipt qualifies only when exactly one section contains every canonical field exactly once' \
  'recompute canonical `review-identity-v1` from exactly the receipt-recorded `Identity bases` and `Identity paths` and require the result to equal `Identity digest`.' \
  'A bound modern DONE without a receipt routes only to the same fresh oblivious review.' \
  'whether the sole `## PR State` has exactly one non-placeholder `Verified implementation digest` equal to the receipt digest and one non-placeholder `Verified at` timestamp.'
check_workflow_contract \
  "PR canonical story-scoped receipt identity and PR State write-back" openspec-pr \
  'A modern bound story requires exactly one complete canonical `progress.md → ## Implementation Review Receipt`' \
  'recompute the story-scoped identity with canonical `review-identity-v1` using exactly the receipt-recorded `Identity bases` and `Identity paths`.' \
  'Save the matching digest and the last pre-mutation UTC verification timestamp in memory for PR State write-back.' \
  'A bound modern DONE with an absent receipt routes only to the same fresh oblivious review' \
  'For a modern receipt, the verified digest must exactly equal its `Identity digest`; never carry forward an older verification timestamp or digest.'
check_workflow_contract \
  "archive route-scoped receipt identity and PR State verification" openspec-archive \
  'At this phase validate receipt shape and remember its digest but do not recompute identity or mutate PR State' \
  'A bound modern DONE with an absent receipt routes only to fresh oblivious review.' \
  'The verified digest must exactly equal the current receipt'"'"'s `Identity digest`' \
  'Do not recompute identity in archive'"'"'s merged-PR route.' \
  'Only when `<archive_route>=no-pr` and a modern receipt exists, immediately before the first archive mutation' \
  'recompute canonical `review-identity-v1` from exactly its recorded `Identity bases` and `Identity paths`.'

# A transient root may be reported operationally, but no artifact template or
# artifact-writing command (including planning writers) may persist it.
check_persisted_root_detector
for artifact_template in "$REPO_ROOT"/openspec/schemas/story-change/templates/*.md; do
  if grep -Fq -- '<openspec_root>' "$artifact_template"; then
    fail "artifact template contains forbidden literal <openspec_root>: $artifact_template"
  elif awk '{ line=tolower($0); gsub(/[*_`]/, "", line); if (line ~ /openspec([ -]+artifact)?[ -]+root[[:space:]]*:/) bad=1 } END { exit bad ? 0 : 1 }' "$artifact_template"; then
    fail "artifact template persists an OpenSpec root field: $artifact_template"
  else
    ok "artifact template has no root literal or persisted OpenSpec root field: $artifact_template"
  fi
done
for skill_name in "${OPENSPEC_WORKFLOW_SKILLS[@]:-}"; do
  [[ -z "$skill_name" ]] && continue
  codex_name="$(hyphen_to_underscore "$skill_name")"
  for artifact_writer in \
    "$CLAUDE_SKILLS/$skill_name/SKILL.md" \
    "$CODEX_SKILLS/$codex_name/SKILL.md" \
    "$PI_SKILLS/$skill_name/SKILL.md"; do
    root_write_findings=""
    if root_write_findings="$(check_no_persisted_root_writes "$artifact_writer")"; then
      fail "artifact write clause persists OpenSpec root: $artifact_writer"
      printf '%s\n' "$root_write_findings" | sed 's/^/  /' >&2
    fi
  done
done

# Prerequisite lookup is a fixed ordered policy, avoiding slow prose-spanning
# regular expressions and preventing archive from overriding an active copy.
check_workflow_contract \
  "archived prerequisite fallback without mutable identity freshness" openspec-story-claim \
  'Resolve the active prerequisite first at `<openspec_root>/openspec/changes/<slug>/story.md`.' \
  'The active prerequisite is authoritative whenever that file exists' \
  'Only when the active prerequisite file is absent, fall back to `<openspec_root>/openspec/changes/archive/<slug>/story.md`.' \
  'Never let an archived DONE copy override an existing active prerequisite.' \
  'Check sibling `blocked.md` before trusting DONE: its existence makes the prerequisite contradictory and unsatisfied in both active and archived locations' \
  'A bound modern prerequisite must have `progress.md` containing exactly one `## Implementation Review Receipt` heading and one current body.' \
  'Missing, duplicate, malformed, or non-approving receipt evidence is unsatisfied.' \
  'never recompute or freshness-check the story-scoped review identity against mutable repository state.' \
  'Only an unbound pre-v3 prerequisite with `Status: ✅ DONE`, no `blocked.md`, zero Initiative headers, and zero receipt sections may satisfy without a receipt'
check_workflow_contract \
  "review prerequisite blocker/receipt reader compatibility" openspec-story-review \
  'A sibling `blocked.md` makes the prerequisite contradictory and unsatisfied in active or archive, regardless of DONE or receipt evidence.' \
  'A bound modern prerequisite must have `progress.md` with exactly one `## Implementation Review Receipt` heading and one current body.' \
  'never recompute or freshness-check the story-scoped review identity against mutable repository state.' \
  'never recompute a prerequisite'"'"'s review identity.'
for prerequisite_reader in openspec-story-resume openspec-story-converge; do
  check_workflow_contract \
    "prerequisite blocker/receipt/no-identity-freshness: $prerequisite_reader" "$prerequisite_reader" \
    'A sibling `blocked.md` makes the prerequisite contradictory and unsatisfied' \
    'A bound modern prerequisite must have `progress.md` with exactly one `## Implementation Review Receipt` heading and one current body.' \
    'never recompute or freshness-check the story-scoped review identity against mutable repository state.' \
    'Only an unbound pre-v3 prerequisite with DONE, no `blocked.md`, zero Initiative headers, and zero receipt sections may satisfy without a receipt'
done

# The receipt is one replace-in-place current record. Review validates in memory,
# writes blocked.md when needed, writes the receipt, and writes Status last. For
# non-DONE lanes a superseded receipt remains historical context only.
require_literal "implementation review receipt template" "$PROGRESS_TEMPLATE" '## Implementation Review Receipt'
forbid_literal "implementation review receipt is not in story template" "$STORY_TEMPLATE" '## Implementation Review Receipt'
require_schema_writer progress 'Implementation Review Receipt'
require_literal "single current receipt template" "$PROGRESS_TEMPLATE" 'Exactly one compact current completed-verdict body'
require_literal "historical receipt for non-DONE template" "$PROGRESS_TEMPLATE" 'Status controls non-DONE routing, where an older receipt may be'
CANONICAL_RECEIPT_FIELD_LIST='`Reviewed at`, `Decision`, `Approval gate`, `Status transition`, `Evidence reviewed`, `Identity method`, `Identity digest`, `Identity bases`, `Identity paths`, `Findings`, `Proof`, and `Next owner`'
for receipt_reader in \
  openspec-story-claim openspec-story-resume openspec-story-converge; do
  require_workflow_literal \
    "canonical implementation receipt fields: $receipt_reader" \
    "$receipt_reader" \
    "$CANONICAL_RECEIPT_FIELD_LIST"
  for legacy_receipt_field in \
    'Review identity'" version" 'Review base'"/range" 'Review identity'" digest"; do
    forbid_workflow_literal \
      "no legacy implementation receipt field in $receipt_reader" \
      "$receipt_reader" \
      "$legacy_receipt_field"
  done
done
# Review evaluates only. Feedback owns durable publication in a later slice.
check_review_readonly_evaluator_contract
check_workflow_contract \
  "planning review modern DONE receipt gate" openspec-story-plan-review \
  'inventory all `<change_dir>/progress.md → ## Implementation Review Receipt` headings.' \
  'A bound modern DONE story without a receipt routes to the same fresh oblivious review, never legacy compatibility.' \
  'Only a consistent DONE with a qualifying receipt or the exact zero-Initiative/zero-receipt pre-v3 exception' \
  'Do not recommend planning commands that reject DONE and do not invent a lifecycle owner.'
check_workflow_contract \
  "historical receipt routing: openspec-story-converge" openspec-story-converge \
  'One well-formed unsuperseded section is current' \
  'historical' \
  'non-DONE'
check_workflow_contract \
  "historical receipt routing: openspec-story-resume" openspec-story-resume \
  'One well-formed unsuperseded section is current.' \
  'historical context' \
  'non-DONE'

# Feedback uses one invocation-wide receipt root, deterministic source identity
# and FB allocation, Write for missing owned anchors, FB-tagged task/checkpoint
# edits, and a receipt-only recovery path after a partial append failure.
forbid_workflow_literal "initiative planning does not seed feedback receipts" openspec-initiative-plan '## Feedback Receipts'
check_workflow_contract \
  "feedback rooted deterministic receipts" openspec-feedback \
  'Set `<receipt_root>` exactly once for the invocation.' \
  'Allocate new identities in their normalized input order.' \
  'The same Source ID with a different hash is a new identity.' \
  '`Write` is permitted only when a missing `progress.md`, `## Progress Timeline`, or `initiative.md → ## Feedback Receipts` section must be created' \
  'Any changed or added `tasks.md` row also includes `[FB-###]`' \
  'Receipt append failed after owned edits for FB-###.' \
  'reuse the same FB ID' \
  'construct its creation with the first acknowledged receipt' \
  'Append exactly one entry per stable identity'
check_workflow_contract \
  "feedback receipt failure rollback/recovery" openspec-feedback \
  'If any owned edit or marker fails, stop before its receipt and later items.' \
  'Best-effort restore every file already written for that item from the retained item-baseline bytes, then verify every restored hash.' \
  'If rollback is incomplete, report every exact partially changed path with its current hash, expected item-baseline hash, and expected post-edit hash.' \
  'If a receipt append fails after owned edits succeeded, stop immediately; do not process later items, roll back or reapply successful owned edits, or allocate a different ID.' \
  'expected pre/post-receipt hashes so retry can reconcile a partial append.' \
  'Backfill only: reuse FB-### from the named FB marker under <receipt_root>; do not reapply owned edits.' \
  'reconcile any reported partial file first, and produce a receipt-only backfill plan.'
require_literal "feedback receipt lifecycle contract" "$LIFECYCLE_DOC" '## Feedback Receipts'
check_feedback_review_packet_triage_contract
check_feedback_receipt_contract
check_readonly_review_write_ownership_docs

# Canonical/Codex feedback cannot require a notebook API. Pi may add optional
# notebook orientation, but every disposition is already durable above.
for portable_feedback_file in \
  "$CLAUDE_SKILLS/openspec-feedback/SKILL.md" \
  "$CODEX_SKILLS/openspec_feedback/SKILL.md"; do
  mapfile -t portable_feedback_tools < <(allowed_tool_tokens "$portable_feedback_file")
  for notebook_tool in notebook_index notebook_read notebook_write; do
    if in_array "$notebook_tool" "${portable_feedback_tools[@]:-}"; then
      fail "portable feedback has unconditional canonical notebook tool $notebook_tool: $portable_feedback_file"
    fi
  done
  if awk '
    {
      lower = tolower($0)
      if (lower ~ /notebook_(index|read|write)/ &&
          lower ~ /(use|scan|read|write|persist|required|must|abort|unavailable|not available)/ &&
          lower !~ /(optional|if available|when available|may use|may write)/) bad = 1
    }
    END { exit bad ? 0 : 1 }
  ' "$portable_feedback_file"; then
    fail "portable feedback has unconditional canonical notebook API instructions: $portable_feedback_file"
  fi
  if grep -Fq 'run this skill from a pi session' "$portable_feedback_file"; then
    fail "portable feedback has a Pi-only rerun requirement: $portable_feedback_file"
  fi
done
forbid_workflow_literal "portable feedback rejects no-receipt disposition" openspec-feedback 'No durable artifact write needed'

# Pi may gather review-session evidence, but it may not import implementation
# convergence context into a fresh implementation review.
require_workflow_literal \
  "fresh implementation review firewall" \
  openspec-story-review \
  'Do not accept parent/converger notebook references'
forbid_literal \
  "Pi review firewall fragment" \
  "$PI_FRAGMENTS/openspec-story-review.md" \
  'openspec-research-<initiative_slug>-<story_slug>'
forbid_literal \
  "Pi review firewall generated skill" \
  "$PI_SKILLS/openspec-story-review/SKILL.md" \
  'openspec-research-<initiative_slug>-<story_slug>'

# blocked.md remains an input gate; resume may normalize stale BLOCKED only after absence.
require_workflow_literal \
  "resume unblock signal" \
  openspec-story-resume \
  'If `blocked.md` is absent but `story.md → Status:` contains `⛔ BLOCKED`'

# Canonical lifecycle/header spelling is intentionally scoped to the commands
# that currently read or write those anchors. Positive top-level-only wording
# prevents a stale alternate-section ban from being the sole guard.
require_literal "canonical story Status template" "$STORY_TEMPLATE" 'Status: ⚪ TODO'
check_review_focus_template_detector
review_focus_template_findings="$(review_focus_template_issues "$STORY_TEMPLATE" | paste -sd, -)"
if [[ -n "$review_focus_template_findings" ]]; then
  fail "canonical story Review Focus template requires exactly one raw top-level 'Review Focus: |' metadata field and no wrapped, malformed, duplicate, or example field ($review_focus_template_findings)"
else
  ok "canonical story Review Focus template has exactly one raw top-level metadata field"
fi
check_review_focus_mention_ownership
REVIEW_FOCUS_HANDOFF_CONTRACT='On every implementation handoff to `🟣 IN REVIEW`, overwrite the top-level `Review Focus: |` block with current reviewer guidance; write a blank block when no focus is needed.'
REVIEW_FOCUS_SHAPE_HEADER='Review Focus: |'
REVIEW_FOCUS_SHAPE_CONTENT='  <optional reviewer guidance on indented lines>'
REVIEW_FOCUS_GRAMMAR='`Review Focus: |` is exactly one top-level field. Its content is the immediately following indented lines; the next top-level header terminates the block.'
REVIEW_FOCUS_BLANK_GRAMMAR='No indented non-whitespace content means the block is blank.'
REVIEW_FOCUS_FAIL_CLOSED='Malformed, duplicate, or conflicting Review Focus forms fail closed.'
REVIEW_FOCUS_BUDGET='Keep nonblank Review Focus guidance roughly 500–1,000 tokens.'
REVIEW_FOCUS_PREPARE_ORDER='Prepare and write the complete `Review Focus: |` block before making `Status: 🟣 IN REVIEW` visible in either `story.md` or `progress.md → ## Session Handoff`; publish the focus and both status surfaces as one completion handoff.'
REVIEW_FOCUS_REREAD='Re-read the focus block and both status surfaces before reporting completion; never leave or report `🟣 IN REVIEW` with stale Review Focus content.'

for review_focus_writer in openspec-story-claim openspec-story-resume; do
  check_workflow_adjacent_lines_contract \
    "Review Focus literal YAML shape: $review_focus_writer" "$review_focus_writer" \
    "$REVIEW_FOCUS_SHAPE_HEADER" "$REVIEW_FOCUS_SHAPE_CONTENT"
  check_workflow_contract \
    "Review Focus handoff writer contract: $review_focus_writer" "$review_focus_writer" \
    "$REVIEW_FOCUS_HANDOFF_CONTRACT" \
    "$REVIEW_FOCUS_GRAMMAR" \
    "$REVIEW_FOCUS_BLANK_GRAMMAR" \
    "$REVIEW_FOCUS_FAIL_CLOSED" \
    "$REVIEW_FOCUS_BUDGET"
done
check_workflow_section_contract \
  "Review Focus concrete claim completion transaction" openspec-story-claim '## Finish protocol' \
  "$REVIEW_FOCUS_PREPARE_ORDER" \
  "$REVIEW_FOCUS_REREAD"
check_workflow_section_contract \
  "Review Focus concrete resume completion transaction" openspec-story-resume '## Phase 4 — Finish Protocol' \
  "$REVIEW_FOCUS_PREPARE_ORDER" \
  "$REVIEW_FOCUS_REREAD"
check_workflow_adjacent_lines_contract \
  "Review Focus literal YAML shape: openspec-story-review" openspec-story-review \
  "$REVIEW_FOCUS_SHAPE_HEADER" "$REVIEW_FOCUS_SHAPE_CONTENT"
check_workflow_contract \
  "Review Focus deterministic reader grammar" openspec-story-review \
  "$REVIEW_FOCUS_GRAMMAR" \
  "$REVIEW_FOCUS_BLANK_GRAMMAR" \
  "$REVIEW_FOCUS_FAIL_CLOSED" \
  "$REVIEW_FOCUS_BUDGET"
check_workflow_section_contract \
  "Review Focus operational review choice" openspec-story-review '## Review readiness check' \
  'If the Review Focus block is blank, perform a full review.' \
  'If it is nonblank, a focused pass is allowed: read the actual content and inspect the focused surface and evidence.' \
  'Widen the focused pass to a full review whenever baseline, scope, or risk is unclear.' \
  'During review, `Review Focus: |` is read-only: review reads it but does not write it.' \
  'Outside `🟣 IN REVIEW`, `Review Focus: |` is inert.'
require_workflow_literal \
  "implementation review requires top-level Status header" \
  openspec-story-review \
  'top-level `Status:` header'
forbid_workflow_literal \
  "implementation review rejects alternate Status section" \
  openspec-story-review \
  'has an equivalent (e.g., an `## Status` section'
require_literal "canonical Acceptance template" "$STORY_TEMPLATE" '## Acceptance'
for skill_name in openspec-story-claim openspec-story-resume; do
  require_workflow_literal "canonical Acceptance reader: $skill_name" "$skill_name" '## Acceptance'
  forbid_workflow_literal "no stale Acceptance Criteria heading: $skill_name" "$skill_name" '## Acceptance Criteria'
done

# Slugs and executable tool permissions are exact contracts, not prose hints.
for skill_name in "${OPENSPEC_WORKFLOW_SKILLS[@]:-}"; do
  [[ -z "$skill_name" ]] && continue
  require_workflow_literal "canonical slug regex: $skill_name" "$skill_name" "$CANONICAL_SLUG_REGEX"
done
check_allowed_tools_contract \
  openspec-initiative-plan \
  Read Grep Glob Write 'Bash(mkdir -p:*)' 'Bash(git status:*)' 'Bash(git log:*)'
check_allowed_tools_contract \
  openspec-feedback \
  Read Edit Grep Glob 'Bash(gh pr view:*)' 'Bash(gh api:*)' 'Bash(date -u:*)' 'Bash(printf:*)' 'Bash(sha256sum:*)' 'Bash(shasum:*)'
check_allowed_tools_exact \
  openspec-story-plan-converge \
  Read Edit Grep Glob Task 'Bash(git status:*)' 'Bash(git worktree list:*)'
check_allowed_tools_exact \
  openspec-story-converge \
  Read Grep Glob Task 'Bash(git status:*)' 'Bash(git worktree list:*)'
check_allowed_tools_exact \
  openspec-story-review \
  Read Grep Glob

# Schema and template ownership must name the complete current writer set.
for writer in /openspec-story-plan /openspec-story-plan-resume; do
  require_schema_writer proposal "$writer"
  require_template_writer proposal "$writer"
  require_schema_writer specs "$writer"
  require_template_writer spec "$writer"
done
for writer in \
  /openspec-story-plan /openspec-story-plan-review /openspec-story-plan-resume \
  /openspec-story-claim /openspec-story-resume /openspec-feedback; do
  require_schema_writer story "$writer"
  require_template_writer story "$writer"
done
for writer in /openspec-story-plan /openspec-story-plan-resume /openspec-feedback; do
  require_schema_writer design "$writer"
  require_template_writer design "$writer"
done
for writer in \
  /openspec-story-plan /openspec-story-plan-resume /openspec-story-claim \
  /openspec-story-resume /openspec-feedback; do
  require_schema_writer tasks "$writer"
  require_template_writer tasks "$writer"
done
require_schema_writer specs '/opsx:archive'
for writer in \
  /openspec-story-claim /openspec-story-resume /openspec-feedback /openspec-pr; do
  require_schema_writer progress "$writer"
  require_template_writer progress "$writer"
done
for writer in /openspec-story-claim /openspec-story-resume /openspec-feedback; do
  require_schema_writer blocked "$writer"
  require_template_writer blocked "$writer"
done
for readonly_artifact in story progress blocked; do
  forbid_schema_writer "$readonly_artifact" /openspec-story-review
  forbid_template_writer "$readonly_artifact" /openspec-story-review
done

# Resume may use notebooks for sourced orientation only; artifacts settle any
# conflict and carry the implementation/review/feedback authority.
require_workflow_literal \
  "artifact-over-notebook resume authority" \
  openspec-story-resume \
  'Canonical artifacts outrank notebook orientation.'
forbid_workflow_literal \
  "artifact-over-notebook removes notebook precedence" \
  openspec-story-resume \
  'the contract and notebook take precedence'
forbid_workflow_literal \
  "artifact-over-notebook removes notebook conflict prompt" \
  openspec-story-resume \
  'If notebook orientation conflicts with the change workspace artifacts, flag the conflict and ask the operator to resolve.'

# PR extraction must use the full canonical selector to the actual level-three
# subsection; checking an isolated backticked heading misses stale prose paths.
for heading in 'Verification Commands' 'Test Architecture Plan' 'Acceptance Proof Matrix'; do
  require_workflow_literal \
    "PR canonical full selector: $heading" \
    openspec-pr \
    "story.md → ## Verification → ### $heading"
  forbid_workflow_literal \
    "PR stale full selector: $heading" \
    openspec-pr \
    "story.md → ## Verification → ## $heading"
done

# PR descriptions must orient a cold reader with an evidence-backed catalyst and
# causal boundary without displacing the product verification contract.
check_workflow_contract \
  "PR catalyst-first cold-reader summary" openspec-pr \
  '`story.md → ## Triggering Need` → Summary' \
  '`proposal.md → ## Goal / Context` → Summary' \
  'Start with the source-supported catalyst' \
  'State the observable before state and the user-visible after state' \
  'If the artifacts state no catalyst, lead with the strongest source-supported Goal, Purpose, or outcome without inventing a gap, history, or causality.' \
  'source-supported catalyst context, user-visible before/after state, and external compatibility facts belong when they remain true regardless of implementation.' \
  'Never infer chronology or causality' \
  'define it only from source-supported context' \
  'Do not let the Summary replace or weaken Requirements, Acceptance criteria, Contract changes, Out of scope, or How to verify.'
forbid_workflow_literal \
  "PR removes outcome-only summary template" openspec-pr \
  '<one short paragraph in product language — the user-visible outcome this PR delivers>'

# Rootless archive mutation is forbidden: a remote active root produces an exact
# cd-and-rerun handoff. Broad PR discovery filters unrelated bound stories while
# still halting a conflict on an explicitly selected story.
check_workflow_contract \
  "archive remote-root rerun" openspec-archive \
  'If the selected or identified active checkout differs from `<workspace_root>`, halt before any PR refresh, artifact edit, `/opsx:archive`, or initiative update.' \
  'Print the exact two-step rerun: `cd <active-root>` followed by `/openspec-archive <initiative-slug> <story-slug>`.' \
  'The current rootless adapter is never invoked against a different checkout'
check_workflow_contract \
  "PR unrelated story filtering" openspec-pr \
  'filter a well-formed story bound to another initiative as unrelated instead of halting the PR scan' \
  'filter well-formed stories bound to other initiatives as unrelated rather than halting' \
  'A conflict on an explicitly selected story still halts.'

# Every IN REVIEW diagnostic names an executable fresh-review command; it does
# not return a prose-only owner or send implementation review through a wrapper.
check_workflow_contract \
  "next-action IN REVIEW executable route" openspec-next-action \
  '/openspec-story-review <initiative> <story-slug>' \
  'The current Status owns this route'
check_workflow_contract \
  "archive IN REVIEW executable route" openspec-archive \
  '/openspec-story-review <initiative-slug> <story-slug>' \
  'If `Status: 🟣 IN REVIEW`'
check_workflow_contract \
  "PR IN REVIEW executable route" openspec-pr \
  '/openspec-story-review <initiative> <story-slug>' \
  '`Status: 🟣 IN REVIEW` -> one fresh, oblivious'
check_workflow_contract \
  "plan-review IN REVIEW executable route" openspec-story-plan-review \
  '/openspec-story-review <initiative-slug> <story-slug>' \
  'If it is `🟣 IN REVIEW`, abort plan review'

# A genuinely absent story routes to creation; incomplete existing workspaces
# route to repair. These exact creation routes avoid a resume dead end.
require_workflow_literal \
  "missing story recovery: next-action" \
  openspec-next-action \
  '/openspec-story-plan INITIATIVE=<initiative>'
require_workflow_literal \
  "missing story recovery: openspec-story-plan-converge" \
  openspec-story-plan-converge \
  '/openspec-story-plan INITIATIVE=<initiative>'
for skill_name in \
  openspec-story-plan-resume openspec-story-plan-review \
  openspec-story-resume openspec-story-review; do
  require_workflow_literal \
    "missing story recovery: $skill_name" \
    "$skill_name" \
    '/openspec-story-plan INITIATIVE=<initiative-slug>'
done

require_exact_line \
  "README Claude update guidance does not force symlinks" \
  "$REPO_ROOT/README.md" \
  'scripts/install.sh --yes --agents claude'
require_exact_line \
  "README Codex update guidance forces generated refresh" \
  "$REPO_ROOT/README.md" \
  'scripts/install.sh --yes --agents codex --force'
require_exact_line \
  "README Pi update guidance forces generated refresh" \
  "$REPO_ROOT/README.md" \
  'scripts/install.sh --yes --agents pi --force'
check_no_all_runtime_force_guidance "$REPO_ROOT/README.md"

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
echo "lint: OpenSpec suggested-next-action output contract"
for skill_name in "${OPENSPEC_WORKFLOW_SKILLS[@]:-}"; do
  [[ -z "$skill_name" ]] && continue
  codex_name="$(hyphen_to_underscore "$skill_name")"
  dual_capable=false
  in_array "$skill_name" "${DUAL_CAPABLE_OPENSPEC_SKILLS[@]}" && dual_capable=true
  check_suggested_next_action_contract "claude: $skill_name" "$CLAUDE_SKILLS/$skill_name/SKILL.md" "$dual_capable"
  check_suggested_next_action_contract "codex: $codex_name" "$CODEX_SKILLS/$codex_name/SKILL.md" "$dual_capable"
  check_suggested_next_action_contract "pi: $skill_name" "$PI_SKILLS/$skill_name/SKILL.md" "$dual_capable"
done

check_pi_converge_dispatch \
  "Pi implementation convergence fragment" \
  "$PI_FRAGMENTS/openspec-story-converge.md" \
  "You are executing the openspec-story-<claim|resume> workflow for openspec/<initiative_slug>/<story_slug>." \
  "/openspec-story-<claim|resume> <initiative_slug> <story_slug> [WORKTREE=...]" \
  "/openspec-story-review"
check_pi_converge_dispatch \
  "generated Pi implementation convergence" \
  "$PI_SKILLS/openspec-story-converge/SKILL.md" \
  "You are executing the openspec-story-<claim|resume> workflow for openspec/<initiative_slug>/<story_slug>." \
  "/openspec-story-<claim|resume> <initiative_slug> <story_slug> [WORKTREE=...]" \
  "/openspec-story-review"
check_pi_converge_dispatch \
  "Pi planning convergence fragment" \
  "$PI_FRAGMENTS/openspec-story-plan-converge.md" \
  "You are executing the openspec-story-plan-<review|resume> workflow for openspec/<initiative_slug>/<story_slug>." \
  "/openspec-story-plan-<review|resume> <initiative_slug> <story_slug>" \
  "/openspec-story-review"
check_pi_converge_dispatch \
  "generated Pi planning convergence" \
  "$PI_SKILLS/openspec-story-plan-converge/SKILL.md" \
  "You are executing the openspec-story-plan-<review|resume> workflow for openspec/<initiative_slug>/<story_slug>." \
  "/openspec-story-plan-<review|resume> <initiative_slug> <story_slug>" \
  "/openspec-story-review"

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
mkdir -p "$codex_prune/epic_story_claim/agents" "$codex_prune/epic_story_resume/agents" \
  "$codex_prune/epic_story_review/agents" "$codex_prune/epic_story_plan/agents" "$codex_prune/openspec_epic_plan/agents"
printf '%s\n' '---' 'name: epic_story_claim' 'description: legacy' '---' > "$codex_prune/epic_story_claim/SKILL.md"
printf '%s\n' '---' 'name: not_epic_story_resume' 'description: local' '---' > "$codex_prune/epic_story_resume/SKILL.md"
printf '%s\n' '---' 'name: epic_story_review' '"name": epic_story_review' '---' > "$codex_prune/epic_story_review/SKILL.md"
printf '%s\n' '---' 'name: [epic_story_plan]' '---' > "$codex_prune/epic_story_plan/SKILL.md"
printf '%s\n' '---' 'name: openspec_epic_plan' 'description: renamed' '---' > "$codex_prune/openspec_epic_plan/SKILL.md"
printf 'policy:\n  allow_implicit_invocation: false\n' > "$codex_prune/epic_story_claim/agents/openai.yaml"
if CODEX_SKILLS_DIR="$codex_prune" "$REPO_ROOT/scripts/install-codex.sh" --prune-unsupported >/dev/null 2>&1; then
  if [[ ! -e "$codex_prune/epic_story_claim" && ! -e "$codex_prune/openspec_epic_plan" && \
        -d "$codex_prune/epic_story_resume" && -d "$codex_prune/epic_story_review" && -d "$codex_prune/epic_story_plan" ]]; then
    ok "install-codex.sh --prune-unsupported removes only exactly verified unsupported dirs"
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
mkdir -p "$pi_prune/epic-story-claim" "$pi_prune/epic-story-resume" \
  "$pi_prune/epic-story-review" "$pi_prune/epic-story-plan" "$pi_prune/openspec-epic-plan"
printf '%s\n' '---' 'name: epic-story-claim' 'description: legacy' '---' > "$pi_prune/epic-story-claim/SKILL.md"
printf '%s\n' '---' 'name: not-epic-story-resume' 'description: local' '---' > "$pi_prune/epic-story-resume/SKILL.md"
printf '%s\n' '---' 'name: epic-story-review' 'name : epic-story-review' '---' > "$pi_prune/epic-story-review/SKILL.md"
printf '%s\n' '---' 'name: {epic-story-plan}' '---' > "$pi_prune/epic-story-plan/SKILL.md"
printf '%s\n' '---' 'name: openspec-epic-plan' 'description: renamed' '---' > "$pi_prune/openspec-epic-plan/SKILL.md"
if PI_SKILLS_DIR="$pi_prune" "$REPO_ROOT/scripts/install-pi.sh" --prune-unsupported >/dev/null 2>&1; then
  if [[ ! -e "$pi_prune/epic-story-claim" && ! -e "$pi_prune/openspec-epic-plan" && \
        -d "$pi_prune/epic-story-resume" && -d "$pi_prune/epic-story-review" && -d "$pi_prune/epic-story-plan" ]]; then
    ok "install-pi.sh --prune-unsupported removes only exactly verified unsupported dirs"
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

# Names observed in old active installs but absent from the original prune
# inventory. Exact frontmatter/symlink safety still applies; this only proves
# that the complete recognized stale inventory is reachable by each installer.
declare -a STALE_PRUNE_SKILLS=(
  epic-claim
  epic-new-story
  epic-resume
  epic-review
  epic-story-save
)
stale_codex_prune="$TMPDIR/stale-codex-prune"
stale_pi_prune="$TMPDIR/stale-pi-prune"
stale_claude_home="$TMPDIR/stale-claude-home"
mkdir -p "$stale_codex_prune" "$stale_pi_prune" "$stale_claude_home/.claude/skills"
for stale_name in "${STALE_PRUNE_SKILLS[@]}"; do
  stale_codex_name="$(hyphen_to_underscore "$stale_name")"
  mkdir -p "$stale_codex_prune/$stale_codex_name/agents" "$stale_pi_prune/$stale_name"
  printf '%s\n' '---' "name: $stale_codex_name" 'description: recognized stale workflow' '---' > "$stale_codex_prune/$stale_codex_name/SKILL.md"
  printf '%s\n' '---' "name: $stale_name" 'description: recognized stale workflow' '---' > "$stale_pi_prune/$stale_name/SKILL.md"
  ln -s "$REPO_ROOT/archive" "$stale_claude_home/.claude/skills/$stale_name"
done

if CODEX_SKILLS_DIR="$stale_codex_prune" "$REPO_ROOT/scripts/install-codex.sh" --prune-unsupported >/dev/null 2>&1; then
  stale_remaining=()
  for stale_name in "${STALE_PRUNE_SKILLS[@]}"; do
    stale_codex_name="$(hyphen_to_underscore "$stale_name")"
    [[ -e "$stale_codex_prune/$stale_codex_name" ]] && stale_remaining+=("$stale_codex_name")
  done
  if [[ ${#stale_remaining[@]} -eq 0 ]]; then
    ok "install-codex.sh prunes the complete recognized stale inventory"
  else
    fail "install-codex.sh stale prune inventory is incomplete: ${stale_remaining[*]}"
  fi
else
  fail "install-codex.sh failed while pruning the recognized stale inventory"
fi

if PI_SKILLS_DIR="$stale_pi_prune" "$REPO_ROOT/scripts/install-pi.sh" --prune-unsupported >/dev/null 2>&1; then
  stale_remaining=()
  for stale_name in "${STALE_PRUNE_SKILLS[@]}"; do
    [[ -e "$stale_pi_prune/$stale_name" ]] && stale_remaining+=("$stale_name")
  done
  if [[ ${#stale_remaining[@]} -eq 0 ]]; then
    ok "install-pi.sh prunes the complete recognized stale inventory"
  else
    fail "install-pi.sh stale prune inventory is incomplete: ${stale_remaining[*]}"
  fi
else
  fail "install-pi.sh failed while pruning the recognized stale inventory"
fi

if HOME="$stale_claude_home" "$REPO_ROOT/scripts/install.sh" --agents claude --yes --prune-unsupported >/dev/null 2>&1; then
  stale_remaining=()
  for stale_name in "${STALE_PRUNE_SKILLS[@]}"; do
    if [[ -e "$stale_claude_home/.claude/skills/$stale_name" || -L "$stale_claude_home/.claude/skills/$stale_name" ]]; then
      stale_remaining+=("$stale_name")
    fi
  done
  if [[ ${#stale_remaining[@]} -eq 0 ]]; then
    ok "install.sh prunes the complete recognized stale Claude inventory"
  else
    fail "install.sh stale Claude prune inventory is incomplete: ${stale_remaining[*]}"
  fi
else
  fail "install.sh failed while pruning the recognized stale Claude inventory"
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
expect_codex_argument_line openspec_feedback 'Argument: INITIATIVE=<slug> [--pr <pr_url>] [feedback_or_file]'
expect_codex_argument_line openspec_story_claim 'Argument: INITIATIVE=<slug> [STORY=<slug>] [WORKTREE="<basename>=<path>"]...'
expect_codex_argument_line openspec_story_resume 'Argument: INITIATIVE=<slug> [STORY=<slug>] [WORKTREE="<basename>=<path>"]...'
expect_codex_argument_line openspec_story_review 'Argument: INITIATIVE=<slug> STORY=<slug> [WORKTREE="<basename>=<path>"]...'
expect_codex_argument_line openspec_story_converge 'Argument: INITIATIVE=<slug> STORY=<slug> [MAX_CYCLES=5] [WORKTREE="<basename>=<path>"]...'
expect_codex_argument_line openspec_story_plan 'Argument: [INITIATIVE=<slug>]'
expect_codex_argument_line openspec_story_plan_resume 'Argument: INITIATIVE=<slug> STORY=<slug>'
expect_codex_argument_line openspec_story_plan_review 'Argument: INITIATIVE=<slug> STORY=<slug>'
expect_codex_argument_line openspec_story_plan_converge 'Argument: INITIATIVE=<slug> STORY=<slug> [MAX_CYCLES=5]'
expect_codex_argument_line openspec_pr 'Argument: INITIATIVE=<slug> STORY=<slug> [<pr_url_or_OPEN=true>]'

expect_codex_contains openspec_next_action "the INITIATIVE, STORY, SPEC, and --all selectors"
expect_codex_contains openspec_feedback "the INITIATIVE, feedback flags, and feedback payload named variables"
expect_codex_contains openspec_story_claim "the INITIATIVE, STORY, and WORKTREE named variables"
expect_codex_contains openspec_story_review "the INITIATIVE, STORY, and WORKTREE named variables"
expect_codex_contains openspec_story_converge "the INITIATIVE, STORY, MAX_CYCLES, and WORKTREE named variables"
expect_codex_contains openspec_story_plan_converge "the INITIATIVE, STORY, and MAX_CYCLES named variables"
expect_codex_contains openspec_pr "the INITIATIVE, STORY, and PR selector named variables"

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
