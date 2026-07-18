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
DRY_RUN="${ADD_INSTALL_DRY_RUN:-0}"
PRUNE_UNSUPPORTED=0

usage() {
  cat <<'EOF'
Usage: install-codex.sh [--force] [--prune-unsupported] [--dry-run]

Compile Codex skills from claude/skills into CODEX_SKILLS_DIR (default: ~/.codex/skills).
Existing generated files are overwritten only when their content is unchanged;
use --force to replace local edits or other conflicting files.
Use --prune-unsupported to remove recognized unsupported workflow skills (archived legacy or renamed).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --prune-unsupported) PRUNE_UNSUPPORTED=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'error: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

ensure_dir_path() {
  local path="$1"
  if [[ -L "$path" ]]; then
    if [[ "$FORCE" == "1" ]]; then
      printf 'warn: replacing symlink %s\n' "$path" >&2
      if [[ "$DRY_RUN" == "1" ]]; then
        printf '  would: rm -f %s\n' "$path"
      else
        rm -f "$path"
      fi
    else
      if [[ "$DRY_RUN" == "1" ]]; then
        printf '  would refuse: existing symlink %s (use --force)\n' "$path"
        return 0
      fi
      printf 'error: refusing to replace existing symlink %s (use --force)\n' "$path" >&2
      return 1
    fi
  elif [[ -e "$path" && ! -d "$path" ]]; then
    if [[ "$FORCE" == "1" ]]; then
      printf 'warn: replacing conflicting path %s\n' "$path" >&2
      if [[ "$DRY_RUN" == "1" ]]; then
        printf '  would: rm -rf %s\n' "$path"
      else
        rm -rf "$path"
      fi
    else
      if [[ "$DRY_RUN" == "1" ]]; then
        printf '  would refuse: existing non-directory %s (use --force)\n' "$path"
        return 0
      fi
      printf 'error: refusing to replace existing non-directory %s (use --force)\n' "$path" >&2
      return 1
    fi
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    [[ -d "$path" ]] || printf '  would: mkdir -p %s\n' "$path"
  else
    mkdir -p "$path"
  fi
}

write_content_if_safe() {
  local dest="$1" content="$2"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/codex-skill.XXXXXX")"
  printf '%s\n' "$content" > "$tmp"

  if [[ -e "$dest" && ! -f "$dest" ]]; then
    if [[ "$FORCE" == "1" ]]; then
      printf 'warn: replacing conflicting path %s\n' "$dest" >&2
      if [[ "$DRY_RUN" == "1" ]]; then
        printf '  would: rm -rf %s\n' "$dest"
      else
        rm -rf "$dest"
      fi
    else
      rm -f "$tmp"
      if [[ "$DRY_RUN" == "1" ]]; then
        printf '  would refuse: existing non-file %s (use --force)\n' "$dest"
        return 0
      fi
      printf 'error: refusing to replace existing non-file %s (use --force)\n' "$dest" >&2
      return 1
    fi
  fi

  if [[ -f "$dest" ]] && ! cmp -s "$tmp" "$dest"; then
    if [[ "$FORCE" == "1" ]]; then
      printf 'warn: overwriting modified generated file %s\n' "$dest" >&2
    else
      rm -f "$tmp"
      if [[ "$DRY_RUN" == "1" ]]; then
        printf '  would refuse: modified file %s (use --force)\n' "$dest"
        return 0
      fi
      printf 'error: refusing to overwrite existing modified file %s (use --force)\n' "$dest" >&2
      return 1
    fi
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '  would: write %s\n' "$dest"
    rm -f "$tmp"
  else
    mv "$tmp" "$dest"
  fi
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
    openspec-archive)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> STORY=<slug>/'
      body_repl='s/\$ARGUMENTS/the INITIATIVE and STORY named variables/g'
      ;;
    openspec-initiative-plan)
      arg_line='s/^Argument:.*/Argument: [SLUG=<slug>]/'
      body_repl='s/\$ARGUMENTS/the SLUG named variable/g'
      ;;
    openspec-next-action)
      arg_line='s/^Argument:.*/Argument: [INITIATIVE=<slug>] [STORY=<slug>] [SPEC=<spec-or-path>] [--all]/'
      body_repl='s/\$ARGUMENTS/the INITIATIVE, STORY, SPEC, and --all selectors/g'
      ;;
    openspec-feedback)
      arg_line='s/^Argument:.*/Argument: INITIATIVE=<slug> [--pr <pr_url>] [feedback_or_file]/'
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
    openspec-pr)
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

frontmatter_name() {
  local file="$1"
  # Pruning is destructive, so accept only one top-level YAML name key whose
  # value is a simple scalar. YAML permits whitespace before ':' and quoted
  # keys; count those spellings together rather than letting the first win.
  awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    NR == 1 {
      if ($0 !~ /^---[[:space:]]*$/) exit 2
      fm = 1
      next
    }
    fm && /^---[[:space:]]*$/ { closed = 1; exit }
    fm {
      line = $0
      if (line ~ /^[[:space:]]+/) {
        sub(/^[[:space:]]+/, "", line)
        if (line ~ /^(name|"name|\047name)([[:space:]:"\047]|$)/) bad = 1
        next
      }
      if (line ~ /^(name|"name"|\047name\047)[[:space:]]*:/) {
        key = line
        sub(/:.*/, "", key)
        key = trim(key)
        rest = line
        sub(/^[^:]*:/, "", rest)
        rest = trim(rest)
        count++
        if (rest ~ /^[A-Za-z0-9_-]+$/) value = rest
        else if (rest ~ /^"[A-Za-z0-9_-]+"$/ || rest ~ /^\047[A-Za-z0-9_-]+\047$/)
          value = substr(rest, 2, length(rest) - 2)
        else bad = 1
        next
      }
      # A name-like token with broken quoting/delimiter is not safely
      # distinguishable from a malformed name key, so fail closed.
      if (line ~ /^(name|"name|\047name)([[:space:]:"\047]|$)/) bad = 1
    }
    END {
      if (!closed || count != 1 || bad || value == "") exit 2
      print value
    }
  ' "$file"
}

prune_unsupported_codex() {
  [[ "$PRUNE_UNSUPPORTED" == "1" ]] || return 0

  local name dir skill_md actual
  printf 'Codex prune unsupported → %s\n' "$CODEX_DEST"
  for name in "${UNSUPPORTED_CODEX_SKILLS[@]}"; do
    dir="$CODEX_DEST/$name"
    [[ -e "$dir" || -L "$dir" ]] || continue

    if [[ -L "$dir" || ! -d "$dir" ]]; then
      printf 'warn: skip  %s (unsupported workflow name exists but is not a directory)\n' "$dir" >&2
      continue
    fi

    skill_md="$dir/SKILL.md"
    if [[ ! -f "$skill_md" ]]; then
      printf 'warn: skip  %s (missing SKILL.md)\n' "$dir" >&2
      continue
    fi

    if ! actual="$(frontmatter_name "$skill_md")"; then
      printf 'warn: skip  %s (frontmatter must contain exactly one well-formed scalar name key matching %s)\n' "$dir" "$name" >&2
      continue
    fi
    if [[ "$actual" != "$name" ]]; then
      printf 'warn: skip  %s (frontmatter name is %s, expected %s)\n' "$dir" "${actual:-<missing>}" "$name" >&2
      continue
    fi

    printf '  prune %s\n' "$dir"
    if [[ "$DRY_RUN" == "1" ]]; then
      printf '  would: rm -rf %s\n' "$dir"
    else
      rm -rf "$dir"
    fi
  done
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

prune_unsupported_codex

echo "Codex skills installed to $CODEX_DEST"
