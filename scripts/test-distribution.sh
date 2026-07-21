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

capability_contracts = {
    "openspec-feedback": "Read Edit Write Grep Glob Bash(gh pr view:*) Bash(gh api:*) Bash(date -u:*) Bash(printf:*) Bash(sha256sum:*) Bash(shasum:*) Bash(git worktree list:*)",
    "openspec-initiative-plan": "Read Grep Glob Write Bash(mkdir -p:*) Bash(git status:*) Bash(git log:*)",
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
