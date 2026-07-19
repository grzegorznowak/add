#!/usr/bin/env bash
# install-pi.sh — compile pi-native skills from canonical Claude source + pi fragments.
# Strips Research Board transport sections, appends pi-specific fragments
# (or replaces full skill for converge rewrites), writes to ~/.pi/agent/skills/.
#
# Detection:
#   - Fragment starts with "---" (YAML frontmatter) → full replace
#   - Fragment starts with anything else        → append to stripped Claude base
#   - No fragment                               → stripped Claude base only

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SKILLS="$REPO_ROOT/claude/skills"
PI_FRAGMENTS="$REPO_ROOT/pi-fragments"
PI_DEST="${PI_SKILLS_DIR:-$HOME/.pi/agent/skills}"
FORCE="${ADD_INSTALL_FORCE:-0}"
DRY_RUN="${ADD_INSTALL_DRY_RUN:-0}"
PRUNE_UNSUPPORTED=0

usage() {
  cat <<'EOF'
Usage: install-pi.sh [--force] [--prune-unsupported] [--dry-run]

Compile pi skills from claude/skills plus pi-fragments into PI_SKILLS_DIR
(default: ~/.pi/agent/skills). Existing generated files are overwritten only when
their content is unchanged; use --force to replace local edits or conflicts.
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

strip_transport() {
  awk '
    /^##+ Shared Research Board Input$/ { skip=1; next }
    /^## /                              { skip=0 }
    !skip
  '
}

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
  tmp="$(mktemp "${TMPDIR:-/tmp}/pi-skill.XXXXXX")"
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

fragment_is_replace() {
  local fragment="$1" first_line=""
  IFS= read -r first_line < "$fragment" || true
  [[ "$first_line" == "---" ]]
}

compile_skill() {
  local skill_name="$1" skill_file="$2" fragment="$3"
  local stripped
  stripped="$(strip_transport < "$skill_file" | sed 's/$RUNTIME_NAME/pi/g')"

  if [[ -f "$fragment" ]]; then
    if fragment_is_replace "$fragment"; then
      cat "$fragment"
    else
      printf '%s\n\n' "$stripped"
      cat "$fragment"
    fi
  else
    printf '%s\n' "$stripped"
  fi
}

declare -a UNSUPPORTED_PI_SKILLS=(
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

prune_unsupported_pi() {
  [[ "$PRUNE_UNSUPPORTED" == "1" ]] || return 0

  local name dir skill_md actual
  printf 'pi prune unsupported → %s\n' "$PI_DEST"
  for name in "${UNSUPPORTED_PI_SKILLS[@]}"; do
    dir="$PI_DEST/$name"
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

ensure_dir_path "$PI_DEST"

# Pass 1 — skills with a Claude base directory
for skill_dir in "$CLAUDE_SKILLS"/*/; do
  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  fragment="$PI_FRAGMENTS/$skill_name.md"
  compiled="$(compile_skill "$skill_name" "$skill_file" "$fragment")"

  out_dir="$PI_DEST/$skill_name"
  ensure_dir_path "$out_dir"
  write_content_if_safe "$out_dir/SKILL.md" "$compiled"
  echo "  $skill_name -> $out_dir/SKILL.md"
done

# Pass 2 — orphan fragments (no Claude base directory)
for fragment in "$PI_FRAGMENTS"/*.md; do
  [[ -f "$fragment" ]] || continue
  skill_name="$(basename "$fragment" .md)"
  [[ -d "$CLAUDE_SKILLS/$skill_name" ]] && continue  # already handled

  compiled="$(sed 's/$RUNTIME_NAME/pi/g' < "$fragment")"
  out_dir="$PI_DEST/$skill_name"
  ensure_dir_path "$out_dir"
  write_content_if_safe "$out_dir/SKILL.md" "$compiled"
  echo "  $skill_name -> $out_dir/SKILL.md (orphan fragment)"
done

prune_unsupported_pi

echo "pi skills installed to $PI_DEST"
