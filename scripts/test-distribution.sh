#!/usr/bin/env bash
# Execute production generators and validate their runtime distributions.
set -euo pipefail

export LC_ALL=C
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRIVATE_TMPDIR="$(mktemp -d)"
trap 'rm -rf -- "$PRIVATE_TMPDIR"' EXIT
CODEX_SKILLS="$PRIVATE_TMPDIR/codex-skills"
PI_SKILLS="$PRIVATE_TMPDIR/pi-skills"

printf 'test: production skill generators\n'
HOME="$PRIVATE_TMPDIR/home" CODEX_SKILLS_DIR="$CODEX_SKILLS" "$REPO_ROOT/scripts/install-codex.sh" >/dev/null
printf 'ok   install-codex.sh generated a temporary distribution\n'
HOME="$PRIVATE_TMPDIR/home" PI_SKILLS_DIR="$PI_SKILLS" "$REPO_ROOT/scripts/install-pi.sh" >/dev/null
printf 'ok   install-pi.sh generated a temporary distribution\n\n'

python3 - "$REPO_ROOT" "$CODEX_SKILLS" "$PI_SKILLS" <<'PY'
import pathlib
import re
import sys
from typing import Any

import yaml

root, codex_root, pi_root = (pathlib.Path(value) for value in sys.argv[1:])
errors: list[str] = []
checks = 2


def ok(message: str) -> None:
    global checks
    checks += 1
    print(f"ok   {message}")


class UniqueKeyLoader(yaml.SafeLoader):
    pass


def construct_unique_mapping(loader: UniqueKeyLoader, node: yaml.MappingNode, deep: bool = False) -> dict[Any, Any]:
    mapping: dict[Any, Any] = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise yaml.constructor.ConstructorError(
                "while constructing a mapping", node.start_mark,
                f"duplicate key: {key!r}", key_node.start_mark,
            )
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping


UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct_unique_mapping
)


def yaml_mapping(text: str, label: str) -> tuple[dict[str, Any], list[str]]:
    try:
        value = yaml.load(text, Loader=UniqueKeyLoader)
    except yaml.YAMLError as exc:
        return {}, [f"invalid YAML: {exc.problem or exc.__class__.__name__}"]
    if not isinstance(value, dict):
        return {}, [f"{label} must be a YAML mapping"]
    if any(not isinstance(key, str) for key in value):
        return {}, [f"{label} keys must be strings"]
    return value, []


def frontmatter_text(text: str) -> tuple[dict[str, Any], list[str]]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}, ["missing opening frontmatter fence"]
    try:
        closing = next(index for index, line in enumerate(lines[1:], 1) if line.strip() == "---")
    except StopIteration:
        return {}, ["missing closing frontmatter fence"]
    return yaml_mapping("\n".join(lines[1:closing]), "frontmatter")


def frontmatter(path: pathlib.Path) -> tuple[dict[str, Any], list[str]]:
    return frontmatter_text(path.read_text(encoding="utf-8"))


packet_fields = [
    "Review mode", "Review focus", "Subject", "Root", "Initiative", "Story", "Verdict",
    "Coverage", "Acceptance / proof assessment", "Verification run", "Red-first assessment",
    "Final stability recheck", "Finding count", "Findings", "Finding ID", "Severity", "Summary",
    "Evidence", "Impact", "Proof / verification", "Requested outcome", "Next step",
]


def packet_issues(text: str) -> list[str]:
    blocks = re.findall(r"^```ADD-REVIEW-PACKET/1\n(.*?)^```$", text, re.MULTILINE | re.DOTALL)
    if len(blocks) != 1:
        return [f"must have exactly one fenced schema (found {len(blocks)})"]
    lines = blocks[0].splitlines()
    labels = [line.split(":", 1)[0] for line in lines if ":" in line]
    issues = []
    if len(labels) != len(lines):
        issues.append("every packet schema line must be a field")
    if labels != packet_fields:
        issues.append(f"field order/set mismatch: got {labels}")
    return issues


def skill_issues(text: str, expected_name: str) -> list[str]:
    fields, issues = frontmatter_text(text)
    if fields.get("name") != expected_name:
        issues.append(f"name must equal directory {expected_name!r}")
    if not isinstance(fields.get("description"), str) or not fields.get("description"):
        issues.append("description is required")
    return issues


# Exercise the same generated-file validator with malformed YAML fixtures.
valid_fixture = "---\nname: fixture\ndescription: valid\n---\n"
if skill_issues(valid_fixture, "fixture"):
    errors.append("generated metadata validator rejected valid fixture")
for bad in (
    "---\nname: fixture\nname: duplicate\ndescription: x\n---\n",
    "---\nname: fixture\ndescription: 'unterminated\n---\n",
    "---\nname: [broken\ndescription: x\n---\n",
):
    if not skill_issues(bad, "fixture"):
        errors.append("generated metadata validator accepted bad YAML fixture")
valid_packet = "```ADD-REVIEW-PACKET/1\n" + "\n".join(f"{field}: value" for field in packet_fields) + "\n```\n"
for bad in (
    valid_packet.replace("Evidence: value\n", ""),
    valid_packet.replace("Evidence: value\n", "Receipt: forbidden\nEvidence: value\n"),
):
    if not packet_issues(bad):
        errors.append("generated packet validator accepted missing/extra field fixture")
ok("generated YAML and packet-validator fixtures")

canonical = sorted(path.name for path in (root / "claude/skills").iterdir() if path.is_dir())
expected_codex = sorted(name.replace("-", "_") for name in canonical)
actual_codex = sorted(path.name for path in codex_root.iterdir() if path.is_dir())
actual_pi = sorted(path.name for path in pi_root.iterdir() if path.is_dir())
if actual_codex != expected_codex:
    errors.append(f"Codex inventory mismatch: expected {expected_codex}, got {actual_codex}")
else:
    ok(f"Codex inventory and pairing ({len(actual_codex)} skills)")
if actual_pi != canonical:
    errors.append(f"Pi inventory mismatch: expected {canonical}, got {actual_pi}")
else:
    ok(f"Pi inventory and pairing ({len(actual_pi)} skills)")

for runtime, base, names in (("Codex", codex_root, actual_codex), ("Pi", pi_root, actual_pi)):
    for name in names:
        skill = base / name / "SKILL.md"
        if not skill.is_file():
            errors.append(f"{runtime} {name}: missing SKILL.md")
            continue
        errors.extend(f"{runtime} {name}: {issue}" for issue in skill_issues(skill.read_text(encoding="utf-8"), name))
        if runtime == "Codex":
            metadata = base / name / "agents/openai.yaml"
            if not metadata.is_file():
                errors.append(f"Codex {name}: missing agents/openai.yaml")
            else:
                values, issues = yaml_mapping(metadata.read_text(encoding="utf-8"), "Codex metadata")
                errors.extend(f"Codex {name}: {issue}" for issue in issues)
                if values != {"policy": {"allow_implicit_invocation": False}}:
                    errors.append(f"Codex {name}: strict invocation policy drift")
    ok(f"{runtime} generated metadata")

canonical_helper = root / "claude/skills/openspec-migrate/migrate.py"
for runtime, helper in (
    ("Codex", codex_root / "openspec_migrate/migrate.py"),
    ("Pi", pi_root / "openspec-migrate/migrate.py"),
):
    if not helper.is_file() or helper.is_symlink():
        errors.append(f"{runtime} migrate: missing regular non-symlink migrate.py")
    elif helper.read_bytes() != canonical_helper.read_bytes():
        errors.append(f"{runtime} migrate: helper bytes differ from canonical")
    generated_helpers = sorted(path.relative_to(helper.parents[1]).as_posix() for path in helper.parents[1].rglob("migrate.py"))
    if generated_helpers != [helper.relative_to(helper.parents[1]).as_posix()]:
        errors.append(f"{runtime} migrate: ancillary helper inventory drift: {generated_helpers}")
ok("exact migrate helper bytes and ancillary inventory across runtimes")

# The new active contract must not reintroduce obsolete review identity/digest
# fields in its blank progress artifact or current user-facing documentation.
stale_review_fields = (
    "Review identity:",
    "Review digest:",
    "Identity method:",
    "Identity digest:",
    "Identity bases:",
    "Identity paths:",
    "review-identity-v1",
)
identity_surfaces = [
    root / "openspec/schemas/story-change/templates/progress.md",
    root / "README.md",
    root / "docs/openspec-conventions.md",
    root / "docs/openspec-lifecycle.md",
    root / "docs/openspec-add-flow-design-book.svg",
]
for path in identity_surfaces:
    text = path.read_text(encoding="utf-8")
    present = [field for field in stale_review_fields if field in text]
    if present:
        errors.append(
            f"{path.relative_to(root)}: stale review digest/identity fields remain: {present}"
        )
ok("new progress template, docs, and SVG omit stale digest/identity fields")

capability_contracts = {
    "openspec-archive": "Read Grep Glob Edit Task Bash(git worktree:*) Bash(git status:*) Bash(git diff:*) Bash(git rev-parse:*) Bash(git ls-files:*) Bash(git hash-object:*) Bash(sha256sum:*) Bash(shasum:*) Bash(gh pr view:*) Bash(date -u:*)",
    "openspec-feedback": "Read Edit Write Grep Glob Task Bash(gh pr view:*) Bash(gh api:*) Bash(date -u:*) Bash(printf:*) Bash(sha256sum:*) Bash(shasum:*) Bash(git worktree list:*)",
    "openspec-pr": "Read Edit Write Grep Glob Task Bash(git status:*) Bash(git log:*) Bash(git branch:*) Bash(git rev-parse:*) Bash(git worktree:*) Bash(git diff:*) Bash(git ls-files:*) Bash(git hash-object:*) Bash(sha256sum:*) Bash(shasum:*) Bash(gh pr list:*) Bash(gh pr view:*) Bash(gh pr edit:*) Bash(gh pr create:*) Bash(curl:*)",
    "openspec-initiative-plan": "Read Grep Glob Write Bash(mkdir -p:*) Bash(git status:*) Bash(git log:*)",
    "openspec-migrate": "Bash(python3:*)",
    "openspec-story-converge": "Read Grep Glob Task Bash(git status:*) Bash(git worktree list:*)",
    "openspec-story-plan-converge": "Read Edit Grep Glob Task Bash(git status:*) Bash(git worktree list:*)",
    "openspec-story-review": "Read Grep Glob",
}
for runtime, base, transform in (
    ("canonical", root / "claude/skills", lambda name: name),
    ("Codex", codex_root, lambda name: name.replace("-", "_")),
    ("Pi", pi_root, lambda name: name),
):
    for name, expected_tools in capability_contracts.items():
        path = base / transform(name) / "SKILL.md"
        fields, issues = frontmatter(path)
        errors.extend(f"{runtime} {name}: {issue}" for issue in issues)
        if fields.get("allowed-tools") != expected_tools:
            errors.append(f"{runtime} {name}: exact allowed-tools contract drift")
        if name == "openspec-story-review" and fields.get("readonly") is not True:
            errors.append(f"{runtime} review: readonly must be true")
    review_path = base / transform("openspec-story-review") / "SKILL.md"
    errors.extend(f"{runtime} review packet: {issue}" for issue in packet_issues(review_path.read_text(encoding="utf-8")))
ok("exact safety capabilities and review-packet grammar across all runtimes")

# Pi fragments are compiler inputs and must retain their exact composition boundary.
for fragment in sorted((root / "pi-fragments").glob("*.md")):
    payload = fragment.read_text(encoding="utf-8").strip()
    generated = (pi_root / fragment.stem / "SKILL.md").read_text(encoding="utf-8").strip()
    if payload.startswith("---\n"):
        if generated != payload:
            errors.append(f"Pi replacement fragment drift: {fragment.name}")
    elif not generated.endswith(payload):
        errors.append(f"Pi append fragment drift: {fragment.name}")
ok("Pi fragment composition boundaries")

argument_lines = {
    "openspec_archive": "Argument: INITIATIVE=<slug> STORY=<slug>",
    "openspec_feedback": "Argument: INITIATIVE=<slug> [--pr <pr_url>] [feedback_or_file]",
    "openspec_initiative_plan": "Argument: [SLUG=<slug>]",
    "openspec_migrate": "Argument: INITIATIVE=<slug> [STORY=<slug>]",
    "openspec_next_action": "Argument: [INITIATIVE=<slug>] [STORY=<slug>] [SPEC=<spec-or-path>] [--all]",
    "openspec_pr": "Argument: INITIATIVE=<slug> STORY=<slug> [<pr_url_or_OPEN=true>]",
    "openspec_story_claim": 'Argument: INITIATIVE=<slug> [STORY=<slug>] [WORKTREE="<basename>=<path>"]...',
    "openspec_story_converge": 'Argument: INITIATIVE=<slug> STORY=<slug> [MAX_CYCLES=5] [WORKTREE="<basename>=<path>"]...',
    "openspec_story_plan": "Argument: [INITIATIVE=<slug>]",
    "openspec_story_plan_converge": "Argument: INITIATIVE=<slug> STORY=<slug> [MAX_CYCLES=5]",
    "openspec_story_plan_resume": "Argument: INITIATIVE=<slug> STORY=<slug>",
    "openspec_story_plan_review": "Argument: INITIATIVE=<slug> STORY=<slug>",
    "openspec_story_resume": 'Argument: INITIATIVE=<slug> [STORY=<slug>] [WORKTREE="<basename>=<path>"]...',
    "openspec_story_review": 'Argument: INITIATIVE=<slug> STORY=<slug> [WORKTREE="<basename>=<path>"]...',
}
body_rewrites = {
    "openspec_archive": "the INITIATIVE and STORY named variables",
    "openspec_feedback": "the INITIATIVE, feedback flags, and feedback payload named variables",
    "openspec_migrate": "the INITIATIVE and STORY named variables",
    "openspec_next_action": "the INITIATIVE, STORY, SPEC, and --all selectors",
    "openspec_pr": "the INITIATIVE, STORY, and PR selector named variables",
    "openspec_story_claim": "the INITIATIVE, STORY, and WORKTREE named variables",
    "openspec_story_converge": "the INITIATIVE, STORY, MAX_CYCLES, and WORKTREE named variables",
    "openspec_story_plan": "the INITIATIVE named variable",
    "openspec_story_plan_converge": "the INITIATIVE, STORY, and MAX_CYCLES named variables",
    "openspec_story_plan_resume": "the INITIATIVE and STORY named variables",
    "openspec_story_plan_review": "the INITIATIVE and STORY named variables",
    "openspec_story_review": "the INITIATIVE, STORY, and WORKTREE named variables",
}

# Full generated-body parity is intentionally independent of the production
# generators. These are the only compiler transformations allowed between a
# canonical Claude body and a runtime body.
codex_argument_transforms = {
    name.replace("_", "-"): (line, body_rewrites.get(name))
    for name, line in argument_lines.items()
}
codex_argument_transforms["openspec-initiative-plan"] = (
    argument_lines["openspec_initiative_plan"], "the SLUG named variable",
)
codex_argument_transforms["openspec-story-resume"] = (
    argument_lines["openspec_story_resume"],
    "the INITIATIVE, STORY, and WORKTREE named variables",
)
codex_argument_transforms["merge-conflict-analysis"] = (None, "the named variables")
# Codex exposes this frontmatter value as its invocation hint. This is the only
# skill-specific frontmatter rewrite allowed in addition to the name transform.
codex_frontmatter_transforms = {
    "openspec-migrate": (
        'argument-hint: "<initiative-slug> [<story-slug>]"',
        'argument-hint: "INITIATIVE=<slug> [STORY=<slug>]"',
    ),
}


def normalized_generated(text: str) -> str:
    # Both installers capture command output, which strips trailing newlines,
    # then write exactly one final newline.
    return text.rstrip("\n") + "\n"


def strip_pi_transport(text: str) -> str:
    output = []
    skipping = False
    for line in text.splitlines(keepends=True):
        heading = line.rstrip("\n")
        if re.fullmatch(r"##+ Shared Research Board Input", heading):
            skipping = True
            continue
        if re.match(r"^## ", heading):
            skipping = False
        if not skipping:
            output.append(line)
    return "".join(output)


def expected_codex(name: str, canonical_text: str) -> str:
    transformed = canonical_text
    transform = codex_argument_transforms.get(name)
    if transform is not None:
        argument_line, body_rewrite = transform
        if name == "merge-conflict-analysis":
            transformed = transformed.replace("`$ARGUMENTS` — ", "")
        elif argument_line is not None:
            transformed = re.sub(r"^Argument:.*$", argument_line, transformed, flags=re.MULTILINE)
        if body_rewrite is not None:
            transformed = transformed.replace("$ARGUMENTS", body_rewrite)
    transformed = transformed.replace("$RUNTIME_NAME", "Codex")
    frontmatter_transform = codex_frontmatter_transforms.get(name)
    if frontmatter_transform is not None:
        source_hint, codex_hint = frontmatter_transform
        if transformed.count(source_hint) != 1:
            errors.append(f"Codex {name}: canonical argument-hint transform source drift")
        transformed = transformed.replace(source_hint, codex_hint, 1)
    transformed = re.sub(
        r"^name:.*$", f"name: {name.replace('-', '_')}", transformed,
        count=1, flags=re.MULTILINE,
    )
    return normalized_generated(transformed)


def expected_pi(name: str, canonical_text: str) -> str:
    fragment = root / "pi-fragments" / f"{name}.md"
    stripped = strip_pi_transport(canonical_text).replace("$RUNTIME_NAME", "pi")
    if not fragment.is_file():
        return normalized_generated(stripped)
    fragment_text = fragment.read_text(encoding="utf-8")
    if fragment_text.startswith("---\n"):
        return normalized_generated(fragment_text)
    return normalized_generated(stripped.rstrip("\n") + "\n\n" + fragment_text)


def skill_parts(text: str) -> tuple[str, str]:
    match = re.match(r"^---\n.*?^---\n", text, flags=re.MULTILINE | re.DOTALL)
    if match is None:
        return "", text
    return text[:match.end()], text[match.end():]


def skill_body(text: str) -> str:
    return skill_parts(text)[1]


def frontmatter_parity_issue(label: str, expected: str, actual: str) -> str | None:
    expected_frontmatter, _ = skill_parts(expected)
    actual_frontmatter, _ = skill_parts(actual)
    if actual_frontmatter == expected_frontmatter:
        return None
    return f"{label}: generated frontmatter differs outside allowlisted transforms"


def phase_at(lines: list[str], line_number: int) -> str:
    for line in reversed(lines[:line_number]):
        if re.match(r"^#{1,6} ", line):
            return line.strip()
    return "<preamble>"


def body_parity_issue(label: str, expected: str, actual: str) -> str | None:
    expected_body = skill_body(expected)
    actual_body = skill_body(actual)
    if actual_body == expected_body:
        return None
    expected_lines = expected_body.splitlines()
    actual_lines = actual_body.splitlines()
    first = 0
    limit = min(len(expected_lines), len(actual_lines))
    while first < limit and expected_lines[first] == actual_lines[first]:
        first += 1
    expected_phase = phase_at(expected_lines, min(first + 1, len(expected_lines)))
    actual_phase = phase_at(actual_lines, min(first + 1, len(actual_lines)))
    expected_line = expected_lines[first] if first < len(expected_lines) else "<EOF>"
    actual_line = actual_lines[first] if first < len(actual_lines) else "<EOF>"
    return (
        f"{label}: generated body parity drift at line {first + 1}; "
        f"expected phase {expected_phase!r}, actual phase {actual_phase!r}; "
        f"expected {expected_line!r}, got {actual_line!r}"
    )


for name in canonical:
    canonical_text = (root / "claude/skills" / name / "SKILL.md").read_text(encoding="utf-8")
    runtime_name = name.replace("-", "_")
    codex_text = (codex_root / runtime_name / "SKILL.md").read_text(encoding="utf-8")
    pi_text = (pi_root / name / "SKILL.md").read_text(encoding="utf-8")
    codex_expected = expected_codex(name, canonical_text)
    pi_expected = expected_pi(name, canonical_text)
    for issue in (
        frontmatter_parity_issue(f"Codex {runtime_name}", codex_expected, codex_text),
        frontmatter_parity_issue(f"Pi {name}", pi_expected, pi_text),
        body_parity_issue(f"Codex {runtime_name}", codex_expected, codex_text),
        body_parity_issue(f"Pi {name}", pi_expected, pi_text),
    ):
        if issue is not None:
            errors.append(issue)
ok("canonical generated frontmatter/body parity under allowlisted compiler transforms")

# Prove the exact-body oracle rejects defects that the former spot checks
# accepted: truncation, a removed phase, and drift inside an allowed rewrite.
review_canonical = (root / "claude/skills/openspec-story-review/SKILL.md").read_text(encoding="utf-8")
review_expected = expected_codex("openspec-story-review", review_canonical)
review_body = skill_body(review_expected)
truncated = review_expected[:-(max(1, len(review_body) // 3))]
if body_parity_issue("truncated fixture", review_expected, truncated) is None:
    errors.append("generated-body parity validator accepted a truncated fixture")
phase_start = review_expected.index("## Review method")
phase_end = review_expected.index("## Verdict rules", phase_start)
removed_phase = review_expected[:phase_start] + review_expected[phase_end:]
removed_issue = body_parity_issue("removed-phase fixture", review_expected, removed_phase)
if removed_issue is None or "expected phase '## Review method'" not in removed_issue:
    errors.append("generated-body parity validator accepted a removed phase or lost phase diagnostics")
claim_canonical = (root / "claude/skills/openspec-story-claim/SKILL.md").read_text(encoding="utf-8")
claim_expected = expected_codex("openspec-story-claim", claim_canonical)
allowed_rewrite = "the INITIATIVE, STORY, and WORKTREE named variables"
if allowed_rewrite not in claim_expected:
    errors.append("generated-body parity rewrite fixture no longer exercises the allowlist")
else:
    altered_rewrite = claim_expected.replace(allowed_rewrite, "the WRONG named variables", 1)
    if body_parity_issue("rewrite fixture", claim_expected, altered_rewrite) is None:
        errors.append("generated-body parity validator accepted an altered allowed rewrite")
ok("generated-body parity negative mutation proofs and phase diagnostics")


def codex_transport_issues(name: str, text: str) -> list[str]:
    found = []
    expected_line = argument_lines[name]
    if text.splitlines().count(expected_line) != 1:
        found.append("expected exactly one transformed argument line")
    if "$ARGUMENTS" in text:
        found.append("raw $ARGUMENTS remains")
    expected_body = body_rewrites.get(name)
    if expected_body is not None and expected_body not in text:
        found.append(f"missing body rewrite {expected_body!r}")
    return found


for name in argument_lines:
    text = (codex_root / name / "SKILL.md").read_text(encoding="utf-8")
    errors.extend(f"Codex {name}: {issue}" for issue in codex_transport_issues(name, text))

# Independently pair the generated migrate frontmatter argument-hint with the
# variables its body tells Codex to parse, rather than trusting the parity
# allowlist alone.
migrate_codex = (codex_root / "openspec_migrate/SKILL.md").read_text(encoding="utf-8")
migrate_fields, migrate_frontmatter_issues = frontmatter_text(migrate_codex)
errors.extend(f"Codex migrate: {issue}" for issue in migrate_frontmatter_issues)
migrate_hint = migrate_fields.get("argument-hint", "")
if migrate_hint != "INITIATIVE=<slug> [STORY=<slug>]":
    errors.append(f"Codex migrate: unexpected argument-hint {migrate_hint!r}")
hint_variables = re.findall(r"\b([A-Z][A-Z_]*)=<", migrate_hint)
parse_match = re.search(
    r"Parse `the ([A-Z_, ]+(?:and [A-Z_]+)?) named variables` once",
    migrate_codex,
)
body_variables = re.findall(r"[A-Z][A-Z_]*", parse_match.group(1)) if parse_match else []
if hint_variables != ["INITIATIVE", "STORY"]:
    errors.append(f"Codex migrate: unexpected argument-hint variables {hint_variables}")
if body_variables != hint_variables:
    errors.append(
        "Codex migrate: argument-hint variables do not match named-variable body: "
        f"hint={hint_variables}, body={body_variables}"
    )
# Mutation proof: the independent frontmatter oracle must reject a positional
# hint even when the body remains otherwise correct.
positional_hint = migrate_codex.replace(
    'argument-hint: "INITIATIVE=<slug> [STORY=<slug>]"',
    'argument-hint: "<initiative-slug> [<story-slug>]"',
    1,
)
canonical_migrate_text = (root / "claude/skills/openspec-migrate/SKILL.md").read_text(encoding="utf-8")
if frontmatter_parity_issue(
    "migrate positional-hint fixture",
    expected_codex("openspec-migrate", canonical_migrate_text),
    positional_hint,
) is None:
    errors.append("Codex migrate: frontmatter parity accepted a positional argument-hint")
ok("Codex migrate named argument-hint matches its body and rejects positional drift")

runtime_lines = {
    "openspec_story_claim": "- Claimed by: Codex fresh session",
    "openspec_story_resume": "- Claimed by: Codex fresh session (resume)",
}
for name, expected_line in runtime_lines.items():
    text = (codex_root / name / "SKILL.md").read_text(encoding="utf-8")
    if text.splitlines().count(expected_line) != 1:
        errors.append(f"Codex {name}: expected exactly one runtime identity line {expected_line!r}")
for generated_file in codex_root.rglob("*"):
    if generated_file.is_file() and "$RUNTIME_NAME" in generated_file.read_text(encoding="utf-8"):
        errors.append(f"Codex {generated_file.relative_to(codex_root)}: raw $RUNTIME_NAME remains")

# Mutations invoke the same validators used above.
fixture_name = "openspec_story_claim"
fixture_text = (codex_root / fixture_name / "SKILL.md").read_text(encoding="utf-8")
mutant = fixture_text.replace(body_rewrites[fixture_name], "the WRONG selector")
if not codex_transport_issues(fixture_name, mutant):
    errors.append("Codex transport validator accepted a broken named-variable rewrite fixture")
runtime_mutant = fixture_text.replace(runtime_lines[fixture_name], "- Claimed by: $RUNTIME_NAME fresh session")
if runtime_mutant.splitlines().count(runtime_lines[fixture_name]) == 1 or "$RUNTIME_NAME" not in runtime_mutant:
    errors.append("Codex runtime-name validator accepted a broken generated-output fixture")
ok("Codex argument, named-variable, and runtime-name transformations")

if errors:
    for error in errors:
        print(f"FAIL {error}", file=sys.stderr)
    print(f"test-distribution: FAILED ({len(errors)} findings)", file=sys.stderr)
    raise SystemExit(1)
print(f"test-distribution: PASSED ({checks} checks)")
PY
