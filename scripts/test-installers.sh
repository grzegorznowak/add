#!/usr/bin/env bash
# Temporary-filesystem integration tests for production installers.
set -uo pipefail

export LC_ALL=C
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRIVATE_TMPDIR="$(mktemp -d)" || exit 1
readonly TMPDIR="$PRIVATE_TMPDIR"
trap 'rm -rf -- "$TMPDIR"' EXIT
# Every invocation, including dry-run and unknown-option cases, is contained.
export HOME="$TMPDIR/home"
mkdir -p "$HOME"
FAIL=0
fail() { printf 'FAIL %s\n' "$*" >&2; FAIL=1; }
ok() { printf 'ok   %s\n' "$*"; }
hyphen_to_underscore() { printf '%s' "${1//-/_}"; }

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
cp -- "$codex_conflict/openspec_story_claim/SKILL.md" "$TMPDIR/codex-skill.baseline"
cp -- "$codex_conflict/openspec_story_claim/agents/openai.yaml" "$TMPDIR/codex-metadata.baseline"
codex_conflict_output=""
if codex_conflict_output="$(CODEX_SKILLS_DIR="$codex_conflict" "$REPO_ROOT/scripts/install-codex.sh" 2>&1)"; then
  fail "install-codex.sh accepted modified existing SKILL.md without --force"
elif ! cmp -s "$TMPDIR/codex-skill.baseline" "$codex_conflict/openspec_story_claim/SKILL.md" || \
     ! cmp -s "$TMPDIR/codex-metadata.baseline" "$codex_conflict/openspec_story_claim/agents/openai.yaml"; then
  fail "install-codex.sh changed conflict bytes before refusing overwrite"
elif ! grep -Fq 'refusing to overwrite existing modified file' <<<"$codex_conflict_output"; then
  fail "install-codex.sh conflict failed without the overwrite-refusal diagnostic"
else
  ok "install-codex.sh refuses overwrite and preserves original bytes"
fi
pi_conflict="$TMPDIR/pi-conflict"
mkdir -p "$pi_conflict/openspec-story-claim"
printf 'local pi edit\n' > "$pi_conflict/openspec-story-claim/SKILL.md"
cp -- "$pi_conflict/openspec-story-claim/SKILL.md" "$TMPDIR/pi-skill.baseline"
pi_conflict_output=""
if pi_conflict_output="$(PI_SKILLS_DIR="$pi_conflict" "$REPO_ROOT/scripts/install-pi.sh" 2>&1)"; then
  fail "install-pi.sh accepted modified existing SKILL.md without --force"
elif ! cmp -s "$TMPDIR/pi-skill.baseline" "$pi_conflict/openspec-story-claim/SKILL.md"; then
  fail "install-pi.sh changed conflict bytes before refusing overwrite"
elif ! grep -Fq 'refusing to overwrite existing modified file' <<<"$pi_conflict_output"; then
  fail "install-pi.sh conflict failed without the overwrite-refusal diagnostic"
else
  ok "install-pi.sh refuses overwrite and preserves original bytes"
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
echo "test: independent production prune manifests"
if python3 - "$REPO_ROOT" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
unsupported = [
    "epic-claim", "epic-feedback", "epic-new-story", "epic-plan", "epic-pr",
    "epic-resume", "epic-review", "epic-squash", "epic-story-claim",
    "epic-story-converge", "epic-story-plan", "epic-story-plan-converge",
    "epic-story-plan-resume", "epic-story-plan-review", "epic-story-pr",
    "epic-story-resume", "epic-story-review", "epic-story-save",
    "openspec-story-pr", "openspec-epic-plan",
]
active = {path.name for path in (root / "claude/skills").iterdir() if path.is_dir()}


def shell_array(path: pathlib.Path, name: str) -> list[str]:
    text = path.read_text(encoding="utf-8")
    match = re.search(rf"declare -a {name}=\(\n(.*?)\n\)", text, re.DOTALL)
    if not match:
        raise ValueError(f"{path.name}: missing {name}")
    return [line.strip().strip("'\"") for line in match.group(1).splitlines() if line.strip()]

contracts = [
    (root / "scripts/install.sh", "UNSUPPORTED_SKILLS", unsupported),
    (root / "scripts/install-pi.sh", "UNSUPPORTED_PI_SKILLS", unsupported),
    (root / "scripts/install-codex.sh", "UNSUPPORTED_CODEX_SKILLS", [name.replace("-", "_") for name in unsupported]),
]
def validate_manifest(actual: list[str], expected: list[str]) -> None:
    if actual != expected:
        raise ValueError("manifest differs from independent expected inventory")
    collision = sorted(active & {name.replace("_", "-") for name in actual})
    if collision:
        raise ValueError(f"prune manifest contains active skills: {collision}")


for path, array, expected in contracts:
    try:
        validate_manifest(shell_array(path, array), expected)
    except ValueError as exc:
        raise ValueError(f"{path.name}: {array}: {exc}") from exc

# Invoke the same validator with an active-skill mutation.
try:
    validate_manifest(unsupported + ["memorize"], unsupported + ["memorize"])
except ValueError:
    pass
else:
    raise ValueError("active-skill prune validator accepted memorize")
PY
then
  ok "production prune manifests match independent inventory and exclude active skills"
  ok "active-skill prune manifest detector fixture"
else
  fail "production prune manifest contract"
fi

echo
if [[ $FAIL -ne 0 ]]; then
  echo "test-installers: FAILED"
  exit 1
fi
echo "test-installers: PASSED"
