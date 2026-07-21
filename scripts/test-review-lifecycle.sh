#!/usr/bin/env bash
# RED-first static contracts for the receiptless review lifecycle.
set -euo pipefail

export LC_ALL=C
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'test: receiptless review lifecycle coherence\n'
python3 - "$REPO_ROOT" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
errors: list[str] = []
checks = 0
contents: dict[str, str] = {}
missing: set[str] = set()


def text(relative: str) -> str:
    if relative in contents:
        return contents[relative]
    path = root / relative
    if not path.is_file():
        if relative not in missing:
            errors.append(f"{relative}: required file is missing")
            missing.add(relative)
        contents[relative] = ""
    else:
        contents[relative] = path.read_text(encoding="utf-8")
    return contents[relative]


def require(relative: str, pattern: str, contract: str) -> None:
    global checks
    checks += 1
    if not re.search(pattern, text(relative), re.IGNORECASE | re.MULTILINE | re.DOTALL):
        errors.append(f"{relative}: missing {contract}")


def forbid(relative: str, pattern: str, contract: str) -> None:
    global checks
    checks += 1
    match = re.search(pattern, text(relative), re.IGNORECASE | re.MULTILINE)
    if match:
        line = text(relative)[:match.start()].count("\n") + 1
        errors.append(f"{relative}:{line}: stale {contract}")


fixture_path = "tests/fixtures/review-lifecycle-contract.json"
try:
    fixture = json.loads(text(fixture_path))
except json.JSONDecodeError as exc:
    errors.append(f"{fixture_path}: invalid JSON: {exc}")
    fixture = {}
expected_cases = {
    "clean-current": "no-op",
    "legacy-current-receipt": "remove-receipt",
    "duplicate-receipt": "fail-closed",
    "malformed-receipt": "fail-closed",
    "ambiguous-binding": "fail-closed",
    "unbound-pre-v3-story": "untouched",
    "archived-story": "untouched",
    "second-run": "no-op",
}
if fixture.get("migration_cases") != expected_cases:
    errors.append(f"{fixture_path}: migration fixture matrix drift")
checks += 1

# Receiptless DONE must be an ordinary current state, not an impossible review repair route.
reader_contracts = {
    "claude/skills/openspec-next-action/SKILL.md": r"bound receiptless DONE.{0,800}(?:/openspec-pr|/openspec-archive)",
    "claude/skills/openspec-story-claim/SKILL.md": r"bound receiptless DONE.{0,800}(?:delivery|archive|terminal)",
    "claude/skills/openspec-story-resume/SKILL.md": r"bound receiptless DONE.{0,800}(?:delivery|archive|terminal)",
    "claude/skills/openspec-story-converge/SKILL.md": r"bound receiptless DONE.{0,800}(?:complete|completion|DONE)",
    "claude/skills/openspec-story-plan-review/SKILL.md": r"bound receiptless DONE.{0,800}(?:complete|feedback)",
    "claude/skills/openspec-story-plan-resume/SKILL.md": r"bound receiptless DONE.{0,800}(?:complete|feedback)",
    "claude/skills/openspec-story-plan-converge/SKILL.md": r"bound receiptless DONE.{0,800}(?:complete|feedback)",
}
for path, pattern in reader_contracts.items():
    require(path, pattern, "explicit bound receiptless-DONE route")

# Prerequisite qualification is state/current-artifact based; receipt evidence is inert.
for path in (
    "claude/skills/openspec-story-claim/SKILL.md",
    "claude/skills/openspec-story-resume/SKILL.md",
    "claude/skills/openspec-story-converge/SKILL.md",
    "claude/skills/openspec-story-review/SKILL.md",
):
    require(
        path,
        r"receipt (?:presence|absence).{0,160}(?:does not|must not).{0,160}prerequisite",
        "receipt-independent prerequisite acceptance",
    )
require(
    "openspec/schemas/story-change/templates/story.md",
    r"## Expected Prerequisites.{0,500}(?:receipt presence or absence|presence, absence).{0,160}(?:does not|must not|cannot).{0,160}(?:qualif|prerequisite)",
    "receipt-independent prerequisite template guidance",
)

# The evaluator must not mine inert receipts for concerns, verdicts, or migration work.
evaluator = "claude/skills/openspec-story-review/SKILL.md"
require(
    evaluator,
    r"legacy receipt.{0,240}(?:ignore|inert).{0,200}(?:must not|never|do not).{0,120}(?:mine|classify|extract|reassess).{0,100}(?:concern|finding|verdict)",
    "complete inert-receipt ignore contract",
)
forbid(
    evaluator,
    r"(?:classify|mine|extract|reassess).{0,120}(?:legacy )?(?:receipt|section).{0,120}(?:concern|finding|approval|verdict)|(?:legacy )?(?:receipt|section).{0,120}(?:classify|mine|extract|reassess).{0,120}(?:concern|finding|approval|verdict)",
    "legacy receipt concern mining",
)

for path, noun in (
    ("claude/skills/openspec-pr/SKILL.md", "PR"),
    ("claude/skills/openspec-archive/SKILL.md", "archive"),
):
    require(path, r"bound receiptless DONE.{0,800}(?:eligible|entry|qualif|deliver|archiv)", f"receiptless DONE {noun} entry")
    require(path, r"(?:stale|legacy) receipt.{0,240}(?:must not|does not|cannot).{0,160}(?:block|override|route)", f"stale receipt cannot block {noun}")

# Migration is a registered command with an explicit, bounded, repeatable contract.
migrate = "claude/skills/openspec-migrate/SKILL.md"
require(migrate, r"^name:\s*openspec-migrate\s*$", "migrate frontmatter registration")
require(migrate, r"openspec/changes/.{0,300}(?:archive|archived).{0,120}(?:untouched|never|exclude)", "active-only archive exclusion")
require(migrate, r"preview.{0,500}(?:confirm|confirmation)", "preview before explicit confirmation")
require(migrate, r"(?:idempotent|second run.{0,80}no-op|repeatable)", "idempotent rerun")
require(migrate, r"(?:duplicate|malformed|ambiguous).{0,300}(?:fail closed|abort|stop)", "fail-closed legacy ambiguity")
require(migrate, r"(?:do not|never).{0,100}(?:synthesi[sz]e|backfill).{0,100}(?:receipt|approval|packet)", "no synthetic review authority")
require(migrate, r"(?:preserve|leave).{0,160}(?:timeline|non-review)", "non-review progress preservation")
require(
    migrate,
    r"(?:(?:exclude|out of scope|untouched|must not migrate).{0,160}(?:unbound|zero Initiative).{0,160}(?:pre-v3|legacy)|(?:unbound|zero Initiative).{0,160}(?:pre-v3|legacy).{0,240}(?:exclude|out of scope|untouched|must not migrate))",
    "explicit unbound pre-v3 migration exclusion",
)
for path in ("README.md", "docs/openspec-conventions.md", "docs/openspec-lifecycle.md"):
    require(
        path,
        r"(?:/openspec-migrate.{0,160}(?:exclude|out of scope|leave untouched|must not migrate).{0,160}(?:unbound|zero Initiative).{0,160}(?:pre-v3|legacy)|(?:unbound|zero Initiative).{0,160}(?:pre-v3|legacy).{0,160}(?:is |are )?(?:exclude|out of scope|left untouched|must not migrate).{0,160}/openspec-migrate)",
        "documented unbound pre-v3 migration exclusion",
    )
require(
    "README.md",
    r"^\| `/openspec-migrate` \|[^\n]+\|$",
    "migrate command inventory row",
)
for path, pattern, contract in (
    ("scripts/lint-structure.sh", r'expected_canonical\s*=.*?"openspec-migrate"', "canonical inventory registration"),
    ("scripts/test-distribution.sh", r'"openspec_migrate"\s*:', "Codex distribution registration"),
    ("scripts/install-codex.sh", r"openspec-migrate\)", "Codex argument transform registration"),
):
    require(path, pattern, contract)

# Review Focus is a public schema field, not hidden implementation lore.
for path in ("README.md", "docs/openspec-conventions.md", "docs/openspec-lifecycle.md"):
    require(path, r"Review Focus:\s*\|", "documented Review Focus field")
    require(path, r"blank.{0,180}full review", "blank-focus full-review semantics")
    require(path, r"nonblank.{0,240}focus", "nonblank focused-review semantics")
require("docs/openspec-lifecycle.md", r"reviewer.{0,240}(?:widen|full review)", "reviewer widening authority")
require("docs/openspec-conventions.md", r"implementation.{0,200}(?:owns|owned|overwrite).{0,200}Review Focus|Review Focus.{0,200}implementation.{0,200}(?:owns|owned|overwrite)", "implementation ownership of Review Focus")

# One literal Session Handoff shape must be shared by template and both producers.
fields = fixture.get("session_handoff_fields", [])
statuses = fixture.get("session_handoff_statuses", [])
if not isinstance(fields, list) or not fields or any(not isinstance(field, str) for field in fields):
    errors.append(f"{fixture_path}: invalid session_handoff_fields")
elif not isinstance(statuses, list) or not statuses or any(not isinstance(status, str) for status in statuses):
    errors.append(f"{fixture_path}: invalid session_handoff_statuses")
else:
    for path in (
        "openspec/schemas/story-change/templates/progress.md",
        "claude/skills/openspec-story-claim/SKILL.md",
        "claude/skills/openspec-story-resume/SKILL.md",
    ):
        normalized = re.sub(r"<[^>\n]*>", "", text(path))
        normalized = re.sub(r"[ \t]+$", "", normalized, flags=re.MULTILINE)
        # Compare labels/order while allowing each source to supply different placeholders.
        block_match = re.search(r"^## Session Handoff\s*$\n(?P<body>(?:^- [^\n]+\n?)+)", normalized, re.MULTILINE)
        if not block_match:
            errors.append(f"{path}: missing literal Session Handoff field block")
            continue
        labels = []
        for line in block_match.group("body").splitlines():
            match = re.match(r"- ([^:]+):", line)
            if match:
                labels.append(match.group(1))
        if labels != fields:
            errors.append(f"{path}: Session Handoff fields/order drift: expected {fields}, got {labels}")
        status_match = re.search(r"^- Status:\s*(?P<values>[^\n]+)$", block_match.group("body"), re.MULTILINE)
        actual_statuses = [value.strip() for value in status_match.group("values").split("|")] if status_match else []
        if actual_statuses != statuses:
            errors.append(
                f"{path}: Session Handoff Status enum drift: expected {statuses}, got {actual_statuses}"
            )
        checks += 1

# Packet triage must reject semantic contradictions, preserve planning authority,
# and freshly qualify every gate immediately before publishing DONE.
feedback = "claude/skills/openspec-feedback/SKILL.md"
require(
    feedback,
    r"(?:contradict|inconsistent).{0,180}(?:Verdict|packet verdict).{0,180}(?:Final stability recheck|stability).{0,240}(?:reject|invalid|zero.write|fresh packet)",
    "contradictory packet verdict/stability rejection",
)
require(
    feedback,
    r"(?:contract|acceptance|proof).{0,180}(?:edit|change).{0,240}Plan:.{0,120}(?:PLAN CHANGES REQUESTED|PLAN DRAFT).{0,240}(?:cannot|must not|ineligible|forbid).{0,120}(?:DONE|clean completion)",
    "contract/proof edits downgrade Plan and forbid DONE",
)
require(
    feedback,
    r"immediately before.{0,240}(?:DONE|clean completion).{0,500}Plan.{0,160}(?:blocked\.md|blocker).{0,160}prerequisite.{0,160}task.{0,160}proof",
    "immediate pre-DONE Plan/blocker/prerequisite/task/proof recheck",
)

# A submitted packet is not cached authority. Immediately before DONE, feedback
# must replay the readonly evaluator over current implementation evidence and
# compare the fresh result with the submitted packet. This closes source drift
# without creating a durable packet identity or review ledger.
require(
    feedback,
    r"(?:immediately before|before).{0,240}(?:DONE|clean completion).{0,500}(?:freshly|fresh).{0,120}(?:re-evaluate|reassess|review).{0,240}(?:current implementation|implementation evidence).{0,500}(?:same|identical).{0,160}(?:readonly evaluator|/openspec-story-review|story-review).{0,120}semantics",
    "pre-DONE fresh replay of current evidence with readonly evaluator semantics",
)
require(
    feedback,
    r"(?:fresh|re-evaluat|reassess).{0,500}(?:semantically equivalent|semantic equivalence).{0,240}(?:submitted|supplied|input).{0,120}packet.{0,500}(?:mismatch|not semantically equivalent|drift).{0,240}(?:reject|halt|stop).{0,240}(?:zero writes|without writes|must not publish|ineligible for).{0,120}DONE",
    "fresh/submitted packet semantic-equivalence gate with zero-write mismatch rejection",
)
require(
    feedback,
    r"(?:fresh (?:assessment|evaluation|packet)|replay).{0,240}(?:transient|in.memory).{0,300}(?:do not|never|must not).{0,160}(?:persist|write|create).{0,160}(?:packet receipt|packet digest|review history|packet history|persisted packet)",
    "transient replay with no packet receipt/digest/history persistence",
)
for path in (
    feedback,
    "openspec/schemas/story-change/schema.yaml",
    "openspec/schemas/story-change/templates/story.md",
    "openspec/schemas/story-change/templates/progress.md",
):
    forbid(
        path,
        r"^(?:#{1,6}\s+|[-*]\s+)?(?:Review |Submitted )?Packet (?:Receipt|Digest|History):",
        "persisted packet receipt/digest/history field",
    )

# Fresh replay is a genuinely isolated evaluator invocation, not role-play in
# the feedback writer's context. Task is the only added orchestration power and
# the child receives only the readonly evaluator selectors/current evidence.
require(
    feedback,
    r"(?:fresh packet replay|fresh replay).{0,500}(?:isolated|fresh).{0,120}Task child.{0,500}(?:only|sole).{0,200}(?:readonly evaluator|/openspec-story-review).{0,240}(?:inputs|arguments|selectors).{0,400}(?:current artifacts|current implementation|readable live repository)",
    "isolated Task-child fresh replay with readonly-only inputs",
)
require(
    feedback,
    r"Task child.{0,500}(?:must not|do not|never).{0,180}(?:submitted packet|dispositions|confirmation|prior chat|implementation-session|parent context)",
    "fresh replay child context firewall",
)
require(
    feedback,
    r"^allowed-tools:[^\n]*\bTask\b",
    "Task capability for isolated feedback replay",
)

# Delivery is independently rebound after local DONE. PR records only the clean
# Git head audited against live GitHub; archive rechecks that non-review field.
pr_skill = "claude/skills/openspec-pr/SKILL.md"
archive_skill = "claude/skills/openspec-archive/SKILL.md"
require(
    pr_skill,
    r"Post.DONE delivery binding audit.{0,1200}(?:isolated|fresh).{0,120}Task child.{0,400}(?:read.only|readonly).{0,300}(?:delivery audit|audit).{0,500}(?:current artifacts|live repository)",
    "fresh isolated readonly PR delivery audit",
)
require(
    pr_skill,
    r"(?:git status|working tree).{0,240}clean.{0,500}(?:current )?(?:Git )?HEAD.{0,240}(?:equals|equal|match).{0,240}(?:live )?PR headRefOid",
    "clean current HEAD equal to live PR headRefOid",
)
require(pr_skill, r"^allowed-tools:[^\n]*\bTask\b", "Task capability for PR delivery audit")
require(
    pr_skill,
    r"## PR State.{0,700}^- Delivery head:\s*<sha",
    "PR State Delivery head example",
)

# Existing-PR attach/refresh is read-only until the complete delivery audit has
# succeeded. In particular, body publication cannot precede the clean
# current-HEAD/live-headRefOid equality check.
pr_text = text(pr_skill)
attach_start = pr_text.find("**Attach mode (default)**")
audit_start = pr_text.find("## Post-DONE delivery binding audit")
post_audit_mutation_start = pr_text.find("## Post-audit mutation")
checks += 1
if min(attach_start, audit_start, post_audit_mutation_start) < 0:
    errors.append(f"{pr_skill}: missing attach/audit/post-audit mutation ordering sections")
elif not attach_start < audit_start < post_audit_mutation_start:
    errors.append(f"{pr_skill}: existing-PR attach/audit/body mutation sections are out of order")
else:
    checks += 1
    if re.search(r"`gh pr edit\b", pr_text[attach_start:post_audit_mutation_start]):
        errors.append(f"{pr_skill}: gh pr edit occurs before the complete post-DONE delivery audit")
    require(
        pr_skill,
        r"Post-audit mutation.{0,800}(?:only after|after).{0,240}(?:child|delivery audit).{0,500}(?:working tree|git status).{0,300}(?:clean).{0,500}(?:HEAD).{0,300}(?:equal|match).{0,240}(?:live )?headRefOid.{0,500}`gh pr edit",
        "existing-PR body edit only after complete clean-HEAD/live-headRefOid audit",
    )

# Every executable attach/open/refresh query must return enough live head
# identity to enforce both repository binding and exact commit binding.
concrete_pr_views = [
    command
    for command in re.findall(r"`(gh pr view\b[^`\n]*--json\s+[^`\n]+)`", text(pr_skill))
    if "..." not in command
]
checks += 1
if len(concrete_pr_views) < 3:
    errors.append(f"{pr_skill}: expected concrete gh pr view commands for attach/open/refresh")
for command in concrete_pr_views:
    checks += 1
    if re.match(r"^gh pr view\s+--json\b", command):
        errors.append(f"{pr_skill}: concrete gh pr view command does not target the selected PR: {command}")
    fields = command.split("--json", 1)[1].strip().split()[0].split(",")
    missing_fields = [
        field
        for field in ("headRepository", "headRepositoryOwner", "headRefOid")
        if field not in fields
    ]
    if missing_fields:
        errors.append(
            f"{pr_skill}: concrete gh pr view command omits {','.join(missing_fields)}: {command}"
        )
require(
    archive_skill,
    r"gh pr view.{0,160}headRefOid.{0,500}(?:equals|equal|match).{0,240}(?:recorded )?Delivery head",
    "archive live merged head equals recorded Delivery head",
)
require(
    archive_skill,
    r"(?:no.PR|without a PR).{0,700}(?:immediately before|final pre.archive).{0,300}(?:isolated|fresh).{0,120}Task child.{0,400}(?:read.only|readonly).{0,200}(?:delivery audit|audit)",
    "immediate isolated readonly no-PR archive audit",
)
require(archive_skill, r"^allowed-tools:[^\n]*\bTask\b", "Task capability for no-PR archive audit")

# Delivery repository identity is resolved deterministically from the bounded
# Current Claim rather than guessed from cwd, the first surface, or a PR URL.
for path in (pr_skill, archive_skill):
    require(
        path,
        r"(?:bounded [`*]?(?:progress\.md.{0,80})?Current Claim[`*]?|Current Claim section).{0,500}Worktrees.{0,240}(?:and|/).{0,120}Primary write surfaces.{0,500}(?:product.repo|repository root)",
        "bounded Current Claim repository-root derivation",
    )
    require(
        path,
        r"(?:missing|malformed|ambiguous).{0,400}(?:Worktrees|Primary write surfaces|repository root).{0,400}(?:fail closed|halt|abort)",
        "fail-closed missing or ambiguous repository binding",
    )
require(
    pr_skill,
    r"exactly one.{0,180}(?:product.repo|repository root).{0,1200}(?:live )?PR.{0,240}(?:repository|repo).{0,300}(?:match|equal).{0,400}(?:headRefOid|head repository|head mapping)",
    "single-repository PR plus live repo/head mapping",
)
require(
    archive_skill,
    r"no.PR.{0,900}(?:(?:every|all).{0,160}(?:resolved )?(?:product.repo|repository root).{0,500}(?:Task child|delivery audit)|(?:Task child|delivery audit).{0,500}(?:every|all).{0,160}(?:resolved )?(?:product.repo|repository root))",
    "no-PR audit covers every resolved product repository",
)

for path in (
    "openspec/schemas/story-change/templates/progress.md",
    "README.md",
    "docs/openspec-conventions.md",
    "docs/openspec-lifecycle.md",
):
    require(path, r"Delivery head:", "documented non-review Delivery head field")
for path in (
    feedback,
    pr_skill,
    archive_skill,
    "openspec/schemas/story-change/schema.yaml",
    "openspec/schemas/story-change/templates/progress.md",
):
    forbid(
        path,
        r"^(?:#{1,6}\s+|[-*]\s+)?(?:Review |Packet )?Delivery (?:Receipt|Digest|Identity):",
        "delivery receipt/digest/identity field",
    )

# The isolated replay/equivalence gate is public lifecycle schema, not a hidden
# feedback implementation detail.
for path in (
    "README.md",
    "docs/openspec-conventions.md",
    "docs/openspec-lifecycle.md",
    "openspec/schemas/story-change/schema.yaml",
    "openspec/schemas/story-change/templates/story.md",
):
    require(
        path,
        r"(?:(?:isolated|fresh).{0,180}(?:replay|re-evaluat).{0,360}(?:immediately before|pre.DONE|before).{0,120}DONE|(?:immediately before|pre.DONE|before).{0,120}DONE.{0,240}(?:isolated|fresh).{0,120}(?:replay|re-evaluat))",
        "documented isolated pre-DONE replay gate",
    )
    require(
        path,
        r"(?:semantic equivalence|semantically\s+equivalent).{0,240}(?:submitted|input).{0,120}packet.{0,300}(?:mismatch|drift).{0,220}(?:reject|halt|no\s+DONE|must not publish)",
        "documented replay/submitted-packet equivalence gate",
    )

# IN REVIEW is not a blind review loop: repair evidence takes precedence, and a
# fresh evaluator route is valid only when no repair condition survives.
for path in (
    "claude/skills/openspec-archive/SKILL.md",
    "claude/skills/openspec-pr/SKILL.md",
    "claude/skills/openspec-story-plan-review/SKILL.md",
    "claude/skills/openspec-story-plan-resume/SKILL.md",
    "claude/skills/openspec-story-plan-converge/SKILL.md",
):
    forbid(
        path,
        r"IN REVIEW.{0,240}(?:review|story-review).{0,160}even when Plan contradicts|IN REVIEW.{0,240}even when Plan contradicts.{0,160}(?:review|story-review)",
        "blind IN-REVIEW review routing despite Plan contradiction",
    )
    require(
        path,
        r"IN REVIEW.{0,600}(?:repair|deficien|drift).{0,500}(?:preced|before|only when no repair|no repair condition).{0,400}(?:fresh|oblivious).{0,120}(?:story-review|review route)",
        "IN-REVIEW repair-before-review precedence",
    )

for path in (
    "claude/skills/openspec-archive/SKILL.md",
    "claude/skills/openspec-feedback/SKILL.md",
    "claude/skills/openspec-story-plan-review/SKILL.md",
    "claude/skills/openspec-story-plan-resume/SKILL.md",
):
    forbid(
        path,
        r"(?:IN REVIEW uses only|When Status is IN REVIEW, give only).{0,180}(?:fresh|oblivious).{0,120}(?:story-review|review route)",
        "blanket final IN-REVIEW fresh-review route",
    )
    require(
        path,
        r"(?:Final response|final route|final authoritative).{0,800}IN REVIEW.{0,500}(?:repair|deficien|drift).{0,500}(?:preced|first|only when no repair).{0,400}(?:fresh|oblivious).{0,120}(?:story-review|review route)",
        "final-route IN-REVIEW repair-first precedence",
    )

require(
    feedback,
    r"(?:Phase 6|Final response).{0,3000}IN REVIEW.{0,500}Plan.{0,160}scaffold.{0,160}blocker.{0,160}task.{0,160}proof.{0,500}(?:repair|deficien|drift).{0,300}(?:preced|first|before).{0,700}(?:fresh|oblivious).{0,120}(?:story-review|review route)",
    "ordinary-feedback final IN-REVIEW Plan/scaffold/blocker/task/proof repair precedence",
)

# CHANGELOG describes the shipped current authority and complete active command
# inventory rather than the superseded evaluator-writer model.
require(
    "CHANGELOG.md",
    r"OpenSpec workflow skills.{0,500}openspec-migrate",
    "migrate in active workflow inventory",
)
require(
    "CHANGELOG.md",
    r"story-review.{0,220}(?:readonly|read.only).{0,300}(?:packet).{0,500}openspec-feedback.{0,240}(?:publishes|publisher|Status.last)",
    "current readonly evaluator and feedback publisher authority",
)
forbid(
    "CHANGELOG.md",
    r"story-review.{0,100}owns local approval.{0,100}DONE",
    "superseded story-review DONE authority",
)

# Remove obsolete evaluator-writer, publisher-slice, and atomicity claims.
stale_patterns = {
    "review receipt publisher/normalizer wording": r"(?:story-)?review.{0,100}(?:writes?|replaces?|normaliz(?:e|es)|owns?).{0,100}(?:Implementation Review Receipt|receipt)",
    "publisher migration slice wording": r"publisher migration slice",
    "atomic packet-triage wording": r"(?:atomic.{0,80}(?:packet|triage|intake)|(?:packet|triage|intake).{0,80}atomic)",
    "review-owned DONE wording": r"DONE.{0,100}(?:via|by|after)\s+`?/openspec-story-review|story-review.{0,100}(?:marks|writes?|sets?|publishes?).{0,100}DONE",
}
wording_files = [
    "README.md", "docs/openspec-conventions.md", "docs/openspec-lifecycle.md",
    "openspec/schemas/story-change/schema.yaml",
    "openspec/schemas/story-change/templates/progress.md",
    "claude/skills/openspec-story-claim/SKILL.md",
    "claude/skills/openspec-story-resume/SKILL.md",
    "claude/skills/openspec-story-converge/SKILL.md",
    "claude/skills/openspec-feedback/SKILL.md",
    "claude/skills/openspec-next-action/SKILL.md",
    "claude/skills/openspec-pr/SKILL.md",
    "claude/skills/openspec-archive/SKILL.md",
]
for path in wording_files:
    for contract, pattern in stale_patterns.items():
        forbid(path, pattern, contract)

if errors:
    for error in errors:
        print(f"FAIL {error}", file=sys.stderr)
    print(f"test-review-lifecycle: FAILED ({len(errors)} findings, {checks} checks)", file=sys.stderr)
    raise SystemExit(1)
print(f"test-review-lifecycle: PASSED ({checks} checks)")
PY
