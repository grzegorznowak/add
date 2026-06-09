#!/usr/bin/env bash
# install-codex.sh — compile Codex skills from canonical Claude source.
# Renames kebab-case → snake_case, rewrites Claude argument syntax to
# Codex named variables, and writes to ~/.codex/skills/.
# No fragments — Codex doesn't use pi primitives.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS="$REPO_ROOT/claude/skills"
CODEX_DEST="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
FORCE="${ADD_INSTALL_FORCE:-0}"

usage() {
  cat <<'EOF'
Usage: install-codex.sh [--force]

Compile Codex skills from claude/skills into CODEX_SKILLS_DIR (default: ~/.codex/skills).
Existing generated files are overwritten only when their content is unchanged;
use --force to replace local edits or other conflicting files.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'error: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

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
  tmp="$(mktemp "${TMPDIR:-/tmp}/codex-skill.XXXXXX")"
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

# Transform Claude-specific positional $ARGUMENTS → Codex named-variable
# conventions.  The mapping is per-skill because the source paragraph
# describes different argument shapes per command.
codex_args() {
  local skill="$1"

  # Common replacements applied to every skill:
  # - $RUNTIME_NAME → Codex
  # - "Claimed by: Claude" / actor-identity text is already handled by
  #   $RUNTIME_NAME; any other hard-coded "Claude" in agent-identity
  #   context gets normalised.
  # - $ARGUMENTS (the Claude positional-arg variable) → Codex named vars
  #   appropriate for this skill.
  #
  # The Argument line is rewritten per skill. Body references to
  # $ARGUMENTS are replaced with each skill's Codex named variables.
  # OpenSpec mappings preserve auxiliary variables such as WORKTREE and
  # MAX_CYCLES so resolution instructions keep their own CLI contract.

  local arg_line body_repl

  case "$skill" in
    epic-story-claim)
      arg_line='s/^Argument:.*/Argument: EPIC=<name> [STORY=<step>] [WORKTREE="<basename>=<path>"].../'
      body_repl='s/\$ARGUMENTS/EPIC and STORY/g'
      ;;
    epic-story-resume)
      arg_line='s/^Argument:.*/Argument: EPIC=<name> [STORY=<step>] [WORKTREE="<basename>=<path>"].../'
      body_repl='s/\$ARGUMENTS/EPIC and STORY/g'
      ;;
    epic-story-review)
      arg_line='s/^Argument:.*/Argument: EPIC=<name> STORY=<step> [WORKTREE="<basename>=<path>"].../'
      body_repl='s/\$ARGUMENTS/EPIC and STORY/g'
      ;;
    epic-story-converge)
      arg_line='s/^Argument:.*/Argument: EPIC=<name> STORY=<step> [MAX_CYCLES=5] [WORKTREE="<basename>=<path>"].../'
      body_repl='s/\$ARGUMENTS/EPIC and STORY/g'
      ;;
    epic-story-plan-converge)
      arg_line='s/^Argument:.*/Argument: EPIC=<name> STORY=<step> [MAX_CYCLES=5]/'
      body_repl='s/\$ARGUMENTS/EPIC and STORY/g'
      ;;
    epic-story-plan-review)
      arg_line='s/^Argument:.*/Argument: EPIC=<name> STORY=<step>/'
      body_repl='s/\$ARGUMENTS/EPIC and STORY/g'
      ;;
    epic-story-plan-resume)
      arg_line='s/^Argument:.*/Argument: EPIC=<name> STORY=<step>/'
      body_repl='s/\$ARGUMENTS/EPIC and STORY/g'
      ;;
    epic-story-plan)
      arg_line='s/^Argument:.*/Argument: [EPIC=<name>]/'
      body_repl='s/\$ARGUMENTS/EPIC/g'
      ;;
    epic-plan)
      arg_line='s/^Argument:.*/Argument: [NAME=<slug>]/'
      body_repl='s/\$ARGUMENTS/the named variables/g'
      ;;
    epic-squash)
      arg_line='s/^Argument:.*/Argument: EPIC=<epic-path>/'
      body_repl='s/\$ARGUMENTS/EPIC/g'
      ;;
    epic-pr)
      arg_line='s/^Argument:.*/Argument: EPIC=<name-or-path> [<pr_url_or_OPEN=true>]/'
      body_repl='s/\$ARGUMENTS/EPIC/g'
      ;;
    epic-story-pr)
      arg_line='s/^Argument:.*/Argument: EPIC=<name> STORY=<step> [<pr_url_or_OPEN=true>]/'
      body_repl='s/\$ARGUMENTS/EPIC and STORY/g'
      ;;
    epic-feedback)
      arg_line='s/^Argument:.*/Argument: EPIC=<name-or-path> [--pr <pr_url>] [--latest|--all] [--since <source_id>] [feedback_or_file]/'
      body_repl='s/\$ARGUMENTS/EPIC/g'
      ;;
    openspec-archive)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> STORY=<slug>/'
      body_repl='s/\$ARGUMENTS/the INITIATIVE and STORY named variables/g'
      ;;
    openspec-epic-plan)
      arg_line='s/^Argument:.*/Argument: [SLUG=<slug>]/'
      body_repl='s/\$ARGUMENTS/the SLUG named variable/g'
      ;;
    openspec-feedback)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> [--pr <pr_url>] [--latest|--all] [--since <source_id>] [feedback_or_file]/'
      body_repl='s/\$ARGUMENTS/the INITIATIVE, feedback flags, and feedback payload named variables/g'
      ;;
    openspec-story-claim)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> [STORY=<slug>] [WORKTREE="<basename>=<path>"].../'
      body_repl='s/\$ARGUMENTS/the INITIATIVE, STORY, and WORKTREE named variables/g'
      ;;
    openspec-story-resume)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> [STORY=<slug>] [WORKTREE="<basename>=<path>"].../'
      body_repl='s/\$ARGUMENTS/the INITIATIVE, STORY, and WORKTREE named variables/g'
      ;;
    openspec-story-review)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> STORY=<slug> [WORKTREE="<basename>=<path>"].../'
      body_repl='s/\$ARGUMENTS/the INITIATIVE, STORY, and WORKTREE named variables/g'
      ;;
    openspec-story-converge)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> STORY=<slug> [MAX_CYCLES=5] [WORKTREE="<basename>=<path>"].../'
      body_repl='s/\$ARGUMENTS/the INITIATIVE, STORY, MAX_CYCLES, and WORKTREE named variables/g'
      ;;
    openspec-story-plan)
      arg_line='s/^Argument:.*/Argument: [INITIATIVE=<slug>]/'
      body_repl='s/\$ARGUMENTS/the INITIATIVE named variable/g'
      ;;
    openspec-story-plan-resume)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> STORY=<slug>/'
      body_repl='s/\$ARGUMENTS/the INITIATIVE and STORY named variables/g'
      ;;
    openspec-story-plan-review)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> STORY=<slug>/'
      body_repl='s/\$ARGUMENTS/the INITIATIVE and STORY named variables/g'
      ;;
    openspec-story-plan-converge)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> STORY=<slug> [MAX_CYCLES=5]/'
      body_repl='s/\$ARGUMENTS/the INITIATIVE, STORY, and MAX_CYCLES named variables/g'
      ;;
    openspec-story-pr)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> STORY=<slug> [<pr_url_or_OPEN=true>]/'
      body_repl='s/\$ARGUMENTS/the INITIATIVE, STORY, and PR selector named variables/g'
      ;;
    merge-conflict-analysis)
      # Already key-value pairs — keep the original line structure, just drop
      # the Claude-specific \$ARGUMENTS wrapper token.
      arg_line='s/`\$ARGUMENTS` — //'
      body_repl='s/\$ARGUMENTS/the named variables/g'
      ;;
    *)
      # Skills with no $ARGUMENTS — pass through unchanged
      arg_line=''
      body_repl=''
      ;;
  esac

  if [[ -n "$arg_line" ]]; then
    sed -E "$arg_line"
  else
    cat
  fi | sed -E "$body_repl" | sed 's/\$RUNTIME_NAME/Codex/g'
}

ensure_dir_path "$CODEX_DEST"

for skill_dir in "$CLAUDE_SKILLS"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  # Codex skills inherit the Claude notebook-reference protocol, so keep
  # executor-side notebook input contracts intact.
  stripped="$(cat "$skill_file" | codex_args "$skill_name")"
  codex_name="${skill_name//-/_}"

  # Transform only the first YAML frontmatter name: field to snake_case.
  stripped=$(printf '%s\n' "$stripped" | awk -v new_name="$codex_name" '
    NR == 1 && /^---$/ { fm=1; print; next }
    fm && /^---$/      { fm=0; done=1; print; next }
    fm && !done && /^name:/ { print "name: " new_name; next }
    { print }
  ')

  out_dir="$CODEX_DEST/$codex_name"
  ensure_dir_path "$out_dir"
  ensure_dir_path "$out_dir/agents"
  write_content_if_safe "$out_dir/SKILL.md" "$stripped"
  write_content_if_safe "$out_dir/agents/openai.yaml" $'policy:\n  allow_implicit_invocation: false'
  echo "  $skill_name -> $codex_name -> $out_dir/SKILL.md"
done

echo "Codex skills installed to $CODEX_DEST"
