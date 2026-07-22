#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lint.sh
source "$SCRIPT_DIR/lint.sh"
lint_suite_bootstrap || exit 1
lint_collect_source_inventory
lint_distribution_primary() {
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
  CODEX_NAMES=()
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
  PI_GEN_NAMES=()
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
}

lint_distribution_generated() {
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

}

lint_distribution_content_hygiene() {
  echo
  echo "lint: codex skill content hygiene"
  if grep -RInE '^(legacy-argument-hint:)|^This skill was migrated one-to-one from the former custom prompt|^Original argument hint:' "$CODEX_SKILLS" >/dev/null 2>&1; then
    fail "prompt-era Codex scaffolding found in generated codex skills (matches below)"
    grep -RInE '^(legacy-argument-hint:)|^This skill was migrated one-to-one from the former custom prompt|^Original argument hint:' "$CODEX_SKILLS" 2>&1 | sed 's/^/  /' >&2 || true
  else
    ok "no prompt-era Codex scaffolding"
  fi

}

lint_distribution_content_contracts() {

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

}

prepare_generated() {
  # Aggregate downstream segments reuse the trees generated and diagnosed by
  # --primary. A standalone segment still prepares its own private root.
  if [[ "$LINT_USING_AGGREGATE_ROOT" != 1 || "${LINT_AGGREGATE_GENERATED_READY:-}" != 1 ]]; then
    lint_generate_silently || true
  fi
  lint_collect_generated_inventory
}
case "${1:-all}" in
  --primary) lint_distribution_primary ;;
  --generated) prepare_generated; lint_distribution_generated ;;
  --content-hygiene) prepare_generated; lint_distribution_content_hygiene ;;
  --content-contracts) prepare_generated; lint_distribution_content_contracts ;;
  all)
    lint_distribution_primary
    lint_distribution_generated
    lint_distribution_content_hygiene
    lint_distribution_content_contracts
    ;;
  *) printf 'usage: %s [--primary|--generated|--content-hygiene|--content-contracts]\n' "$0" >&2; exit 2 ;;
esac
exit "$FAIL"
