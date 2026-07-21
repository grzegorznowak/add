#!/usr/bin/env bash
# Deterministic source-tree, metadata, link, schema, and review-packet checks.
set -euo pipefail

export LC_ALL=C
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

printf 'lint: shell syntax\n'
bash -n scripts/*.sh
printf 'ok   bash -n scripts/*.sh\n\n'

printf 'lint: repository structure\n'
python3 - "$REPO_ROOT" <<'PY'
import pathlib
import re
import subprocess
import sys
import tempfile
from typing import Any

import yaml

root = pathlib.Path(sys.argv[1]).resolve()
errors: list[str] = []
checks = 0


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


def packet_issues(text: str) -> list[str]:
    blocks = re.findall(r"^```ADD-REVIEW-PACKET/1\n(.*?)^```$", text, re.MULTILINE | re.DOTALL)
    if len(blocks) != 1:
        return [f"must have exactly one fenced schema (found {len(blocks)})"]
    expected = [
        "Review mode", "Review focus", "Subject", "Root", "Initiative", "Story",
        "Verdict", "Coverage", "Acceptance / proof assessment", "Verification run",
        "Red-first assessment", "Final stability recheck", "Finding count", "Findings",
        "Finding ID", "Severity", "Summary", "Evidence", "Impact",
        "Proof / verification", "Requested outcome", "Next step",
    ]
    lines = blocks[0].splitlines()
    labels = [line.split(":", 1)[0] for line in lines if ":" in line]
    issues = []
    if len(labels) != len(lines):
        issues.append("every packet schema line must be a field")
    if labels != expected:
        issues.append(f"field order/set mismatch: expected {expected}, got {labels}")
    return issues


# Exercise the production validators, not lookalike detector logic.
for bad in (
    "---\nname: x\nname: y\n---\n",
    "---\nname: x\n\"name\": y\n---\n",
    "---\nallowed-tools: 'Read Grep Glob\"\n---\n",
    "---\nname: [unterminated\n---\n",
):
    if not frontmatter_text(bad)[1]:
        errors.append("frontmatter validator accepted an invalid/duplicate YAML fixture")
valid_packet = "```ADD-REVIEW-PACKET/1\n" + "\n".join(f"{field}: value" for field in [
    "Review mode", "Review focus", "Subject", "Root", "Initiative", "Story", "Verdict",
    "Coverage", "Acceptance / proof assessment", "Verification run", "Red-first assessment",
    "Final stability recheck", "Finding count", "Findings", "Finding ID", "Severity", "Summary",
    "Evidence", "Impact", "Proof / verification", "Requested outcome", "Next step",
]) + "\n```\n"
if packet_issues(valid_packet):
    errors.append("packet validator rejected its valid fixture")
for bad_packet in (
    valid_packet.replace("Summary: value\n", ""),
    valid_packet.replace("Summary: value\n", "Receipt: forbidden\nSummary: value\n"),
    valid_packet.replace("Summary: value\nEvidence: value", "Evidence: value\nSummary: value"),
):
    if not packet_issues(bad_packet):
        errors.append("packet validator accepted missing, extra, or out-of-order fields")
ok("YAML frontmatter and packet-validator fixtures")

expected_canonical = [
    "grillme", "memorize", "merge-conflict-analysis", "openspec-archive",
    "openspec-feedback", "openspec-initiative-plan", "openspec-next-action",
    "openspec-pr", "openspec-story-claim", "openspec-story-converge",
    "openspec-story-plan", "openspec-story-plan-converge",
    "openspec-story-plan-resume", "openspec-story-plan-review",
    "openspec-story-resume", "openspec-story-review",
]
required = {"name", "description", "disable-model-invocation", "argument-hint", "allowed-tools"}
canonical: list[str] = []
for skill_dir in sorted((root / "claude/skills").iterdir()):
    if not skill_dir.is_dir():
        continue
    path = skill_dir / "SKILL.md"
    if not path.is_file():
        errors.append(f"{skill_dir.relative_to(root)}: missing SKILL.md")
        continue
    fields, issues = frontmatter(path)
    missing = sorted(required - fields.keys())
    if fields.get("name") != skill_dir.name:
        issues.append(f"name must equal directory name {skill_dir.name!r}")
    if fields.get("disable-model-invocation") is not True:
        issues.append("disable-model-invocation must be true")
    if missing:
        issues.append(f"missing fields: {', '.join(missing)}")
    if issues:
        errors.extend(f"{path.relative_to(root)}: {issue}" for issue in issues)
    else:
        canonical.append(skill_dir.name)
        ok(f"canonical metadata: {skill_dir.name}")
if canonical != expected_canonical:
    errors.append(f"canonical inventory mismatch: expected {expected_canonical}, got {canonical}")
else:
    ok("strict canonical skill inventory")

expected_fragments = [
    "memorize", "openspec-story-claim", "openspec-story-converge",
    "openspec-story-plan-converge", "openspec-story-plan-resume",
    "openspec-story-plan-review", "openspec-story-resume", "openspec-story-review",
]
actual_fragments = [path.stem for path in sorted((root / "pi-fragments").glob("*.md"))]
if actual_fragments != expected_fragments:
    errors.append(f"Pi fragment inventory mismatch: expected {expected_fragments}, got {actual_fragments}")
else:
    ok("strict Pi fragment inventory")
for path in sorted((root / "pi-fragments").glob("*.md")):
    text = path.read_text(encoding="utf-8")
    if text.startswith("---\n"):
        fields, issues = frontmatter(path)
        if fields.get("name") != path.stem:
            issues.append("replacement fragment name must equal filename")
    else:
        issues = [] if path.stem in canonical else ["append fragment has no canonical skill"]
    if issues:
        errors.extend(f"{path.relative_to(root)}: {issue}" for issue in issues)
    else:
        ok(f"Pi fragment structure: {path.name}")

# Runtime permissions are executable safety contracts, so these are exact.
capability_contracts = {
    "openspec-feedback": "Read Edit Write Grep Glob Bash(gh pr view:*) Bash(gh api:*) Bash(date -u:*) Bash(printf:*) Bash(sha256sum:*) Bash(shasum:*) Bash(git worktree list:*)",
    "openspec-initiative-plan": "Read Grep Glob Write Bash(mkdir -p:*) Bash(git status:*) Bash(git log:*)",
    "openspec-story-converge": "Read Grep Glob Task Bash(git status:*) Bash(git worktree list:*)",
    "openspec-story-plan-converge": "Read Edit Grep Glob Task Bash(git status:*) Bash(git worktree list:*)",
    "openspec-story-review": "Read Grep Glob",
}
for name, expected_tools in capability_contracts.items():
    fields, issues = frontmatter(root / f"claude/skills/{name}/SKILL.md")
    if issues or fields.get("allowed-tools") != expected_tools:
        errors.append(f"canonical {name}: exact allowed-tools contract drift")
    if name == "openspec-story-review" and fields.get("readonly") is not True:
        errors.append("canonical openspec-story-review: readonly must be true")
ok("exact canonical safety capability contracts")

review_text = (root / "claude/skills/openspec-story-review/SKILL.md").read_text(encoding="utf-8")
for issue in packet_issues(review_text):
    errors.append(f"canonical review packet: {issue}")
if not packet_issues(review_text):
    ok("exact canonical review-packet grammar")

# Schema artifact mappings are structured production configuration.
schema_path = root / "openspec/schemas/story-change/schema.yaml"
schema, schema_issues = yaml_mapping(schema_path.read_text(encoding="utf-8"), "story-change schema")
errors.extend(f"{schema_path.relative_to(root)}: {issue}" for issue in schema_issues)
expected_mappings = [
    ("proposal", "proposal.md", "proposal.md"), ("story", "story.md", "story.md"),
    ("design", "design.md", "design.md"), ("tasks", "tasks.md", "tasks.md"),
    ("specs", "specs/**/*.md", "spec.md"), ("progress", "progress.md", "progress.md"),
    ("blocked", "blocked.md", "blocked.md"),
]
actual_mappings = []
if not schema_issues:
    artifacts = schema.get("artifacts")
    if not isinstance(artifacts, list):
        errors.append("story-change schema: artifacts must be a list")
    else:
        for artifact in artifacts:
            if not isinstance(artifact, dict):
                errors.append("story-change schema: every artifact must be a mapping")
                continue
            mapping = (artifact.get("id"), artifact.get("generates"), artifact.get("template"))
            actual_mappings.append(mapping)
            template = artifact.get("template")
            if not isinstance(template, str) or not (schema_path.parent / "templates" / template).is_file():
                errors.append(f"story-change schema: missing template target for {artifact.get('id')!r}: {template!r}")
if actual_mappings != expected_mappings:
    errors.append(f"story-change schema artifact mapping drift: {actual_mappings}")
else:
    ok("schema generates/template mappings and targets")

link_pattern = re.compile(r"!?\[[^]]*\]\(([^)]+)\)")
command_pattern = re.compile(r"(?<![A-Za-z0-9_./-])/(openspec-[a-z0-9-]+)")
command_placeholders = {"openspec-story-<claim|resume>", "openspec-story-plan-<review|resume>"}
legacy_migration_line = "`/openspec-epic-plan` command, prune once explicitly:"


def link_issues(text: str, source: pathlib.Path) -> list[str]:
    found = []
    for line_no, line in enumerate(text.splitlines(), 1):
        for match in link_pattern.finditer(line):
            target = match.group(1).split()[0].strip("<>")
            if target.startswith(("https://", "http://", "mailto:", "#")):
                continue
            target_path = target.split("#", 1)[0]
            if not target_path:
                continue
            if target_path.startswith("/"):
                found.append(f"{line_no}: unsafe absolute local link: {target}")
                continue
            resolved = (source.parent / target_path).resolve()
            if not resolved.is_relative_to(root):
                found.append(f"{line_no}: local link escapes repository: {target}")
            elif not resolved.exists():
                found.append(f"{line_no}: broken local link: {target}")
    return found


def command_issues(text: str, source: pathlib.Path) -> list[str]:
    found = []
    for line_no, line in enumerate(text.splitlines(), 1):
        scan_line = line
        for placeholder in command_placeholders:
            scan_line = scan_line.replace(f"/{placeholder}", "")
        for command in command_pattern.findall(scan_line):
            if command in canonical:
                continue
            if (
                command == "openspec-epic-plan"
                and source == root / "README.md"
                and line == legacy_migration_line
            ):
                continue
            found.append(f"{line_no}: unknown slash-command /{command}")
    return found

# Invoke the same scanners on representative negative fixtures.
fixture_source = root / "docs/__lint_fixture__.md"
if not link_issues("[bad](../../../../etc/passwd)", fixture_source):
    errors.append("link validator accepted repository traversal fixture")
if not link_issues("[bad](definitely-missing.md)", fixture_source):
    errors.append("link validator accepted missing-target fixture")
if not link_issues("![bad](../../../../etc/passwd)", fixture_source):
    errors.append("image validator accepted repository traversal fixture")
if not link_issues("![bad](definitely-missing.png)", fixture_source):
    errors.append("image validator accepted missing-target fixture")
if not command_issues("Run /openspec-definitely-missing- next", fixture_source):
    errors.append("slash-command validator accepted unknown trailing-hyphen fixture")
if command_issues("Run /openspec-story-<claim|resume> next", fixture_source):
    errors.append("slash-command validator rejected an explicit placeholder fixture")
if command_issues(legacy_migration_line, root / "README.md"):
    errors.append("slash-command validator rejected the exact README migration reference")
if not command_issues(legacy_migration_line, fixture_source):
    errors.append("slash-command validator accepted the legacy command outside README")
if not command_issues(f"See {legacy_migration_line}", root / "README.md"):
    errors.append("slash-command validator accepted a non-exact README legacy reference")
ok("link, image, and slash-command validator fixtures")

tracked = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "--", "*.md"],
    cwd=root, text=True,
).splitlines()
for relative in tracked:
    if relative.startswith("archive/"):
        continue
    path = root / relative
    content = path.read_text(encoding="utf-8")
    errors.extend(f"{relative}:{issue}" for issue in link_issues(content, path))
    errors.extend(f"{relative}:{issue}" for issue in command_issues(content, path))
    if "cure_workspace" in content or re.search(r"/(?:home|Users)/[^\s`]+", content):
        errors.append(f"{relative}: machine-specific absolute path")
ok("active Markdown links/images, containment, slash commands, and path safety")

if errors:
    for error in errors:
        print(f"FAIL {error}", file=sys.stderr)
    print(f"lint-structure: FAILED ({len(errors)} findings)", file=sys.stderr)
    raise SystemExit(1)
print(f"lint-structure: PASSED ({checks} checks)")
PY
