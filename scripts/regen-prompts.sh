#!/usr/bin/env bash
# regen-prompts.sh — generate legacy codex/prompts/<name>.md files from the
# canonical codex/skills/<name>/SKILL.md sources.
#
# Usage:
#   scripts/regen-prompts.sh           # rewrite codex/prompts/*.md in place
#   scripts/regen-prompts.sh --check   # exit 1 if any output would differ
#
# The skill SKILL.md frontmatter must have:
#   - name (matching the dir name)
#   - description
#   - legacy-argument-hint (optional; absent for grillme / memorize)
#
# The skill body must lead with a 7-line preamble produced by the migration:
#   line 1: This skill was migrated one-to-one from the former custom prompt `<name>.md`.
#   line 2: Invoke it explicitly with `$<name>`.
#   line 3: <blank>
#   line 4: Original argument hint: `<hint>`   OR   Original argument hint: *(none)*
#   line 5: <blank>
#   line 6: If the user supplies text alongside the explicit skill invocation, treat that text as additional context for the instructions below.
#   line 7: <blank>
# Anything before line 1 (typically a single blank line right after the
# closing `---`) is not part of the preamble and is also stripped.
#
# The generator emits codex/prompts/<name>.md with old-format frontmatter:
#   ---
#   description: <from skill>
#   argument-hint: <from skill, omit line if absent>
#   ---
#   <body bytes 8+ from skill, verbatim>

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${REPO_ROOT}/codex/skills"
PROMPTS_DIR="${REPO_ROOT}/codex/prompts"

CHECK=0
case "${1:-}" in
  --check) CHECK=1 ;;
  "") ;;
  *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
  echo "regen-prompts: python3 is required" >&2
  exit 2
fi

mkdir -p "$PROMPTS_DIR"

FAIL=0
DRIFT_FILES=()

for skill_dir in "$SKILLS_DIR"/*/; do
  [[ -d "$skill_dir" ]] || continue
  name="$(basename "$skill_dir")"
  skill_md="$skill_dir/SKILL.md"
  prompt_md="$PROMPTS_DIR/$name.md"

  if [[ ! -f "$skill_md" ]]; then
    echo "regen-prompts: $skill_md missing" >&2
    FAIL=1
    continue
  fi

  generated="$(python3 - "$skill_md" "$name" <<'PY'
# Trailing newline preserved via the X trick at the bottom.
import sys, re

skill_path, name = sys.argv[1], sys.argv[2]
with open(skill_path, 'r', encoding='utf-8') as f:
    raw = f.read()

if not raw.startswith('---\n'):
    sys.stderr.write(f"{skill_path}: missing opening frontmatter ---\n")
    sys.exit(3)

body_start = raw.find('\n---\n', 4)
if body_start < 0:
    sys.stderr.write(f"{skill_path}: missing closing frontmatter ---\n")
    sys.exit(3)

frontmatter_text = raw[4:body_start]
body = raw[body_start + len('\n---\n'):]

description = None
legacy_hint = None
for line in frontmatter_text.split('\n'):
    if line.startswith('description:'):
        description = line[len('description:'):].strip()
    elif line.startswith('legacy-argument-hint:'):
        v = line[len('legacy-argument-hint:'):].strip()
        if (v.startswith("'") and v.endswith("'")) or (v.startswith('"') and v.endswith('"')):
            v = v[1:-1]
        legacy_hint = v

if description is None:
    sys.stderr.write(f"{skill_path}: missing description in frontmatter\n")
    sys.exit(3)

# Strip the migration preamble from the body.
# Body shape: optional blank line(s), then the 7 fixed preamble lines, then
# the real prompt body.
lines = body.split('\n')

# Skip leading blank lines
i = 0
while i < len(lines) and lines[i] == '':
    i += 1

expected_line_1 = f"This skill was migrated one-to-one from the former custom prompt `{name}.md`."
expected_line_2 = f"Invoke it explicitly with `${name}`."
expected_line_3 = ""
expected_line_4_with = f"Original argument hint: `{legacy_hint}`" if legacy_hint else None
expected_line_4_none = "Original argument hint: *(none)*"
expected_line_5 = ""
expected_line_6 = "If the user supplies text alongside the explicit skill invocation, treat that text as additional context for the instructions below."
expected_line_7 = ""

def expect(idx, expected, label):
    if idx >= len(lines) or lines[idx] != expected:
        actual = lines[idx] if idx < len(lines) else "<EOF>"
        sys.stderr.write(
            f"{skill_path}: preamble line {label} mismatch.\n"
            f"  expected: {expected!r}\n"
            f"  actual:   {actual!r}\n"
        )
        sys.exit(3)

expect(i, expected_line_1, "1 (migration note)")
expect(i+1, expected_line_2, "2 (invoke note)")
expect(i+2, expected_line_3, "3 (blank)")

if legacy_hint:
    expect(i+3, expected_line_4_with, "4 (argument hint)")
else:
    expect(i+3, expected_line_4_none, "4 (argument hint *(none)*)")

expect(i+4, expected_line_5, "5 (blank)")
expect(i+5, expected_line_6, "6 (context note)")
expect(i+6, expected_line_7, "7 (blank)")

remaining = '\n'.join(lines[i+7:])

# Build the legacy prompt
out = ['---']
out.append(f'description: {description}')
if legacy_hint:
    out.append(f'argument-hint: {legacy_hint}')
out.append('---')
out.append('')
sys.stdout.write('\n'.join(out) + '\n' + remaining)
sys.stdout.write('__REGEN_END__')
PY
)"
  # Strip the sentinel that protects trailing newlines from $() stripping
  generated="${generated%__REGEN_END__}"
  if [[ $? -ne 0 ]]; then
    echo "regen-prompts: failed to generate $name" >&2
    FAIL=1
    continue
  fi

  if [[ $CHECK -eq 1 ]]; then
    if [[ ! -f "$prompt_md" ]]; then
      echo "regen-prompts: $prompt_md missing (run without --check to generate)" >&2
      DRIFT_FILES+=("$prompt_md")
      FAIL=1
      continue
    fi
    existing="$(cat "$prompt_md"; echo __REGEN_END__)"
    existing="${existing%__REGEN_END__}"
    if [[ "$generated" != "$existing" ]]; then
      DRIFT_FILES+=("$prompt_md")
      FAIL=1
    fi
  else
    printf '%s' "$generated" > "$prompt_md"
    echo "wrote $prompt_md"
  fi
done

if [[ $CHECK -eq 1 && ${#DRIFT_FILES[@]} -gt 0 ]]; then
  echo
  echo "regen-prompts: stale generated prompts (run scripts/regen-prompts.sh):"
  for f in "${DRIFT_FILES[@]}"; do
    echo "  - $f"
  done
fi

exit $FAIL
