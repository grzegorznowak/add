"""Declarative exact-file manifest for notebook protocol auditing."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class AuditFile:
    """One exact audited file and its protocol role."""

    name: str
    root: str
    relative: str
    kind: str
    expected_prefixes: frozenset[str]
    fragment: bool = False
    pair: str | None = None

    def resolve(self, roots: AuditRoots) -> Path:
        by_name = {"repository": roots.repository, "codex": roots.codex, "pi": roots.pi}
        try:
            root = by_name[self.root]
        except KeyError as exc:
            raise ValueError(f"unknown manifest root {self.root!r}") from exc
        return root / self.relative


@dataclass(frozen=True)
class AuditRoots:
    """Roots for repository sources and generated installer output."""

    repository: Path
    codex: Path
    pi: Path


R = "repository"
C = "codex"
P = "pi"
RESEARCH = frozenset({"research"})
IMPLEMENTATION = frozenset({"research", "ops"})
PLANNING = frozenset({"plan-research", "plan-ops"})
REVIEW = frozenset({"review"})
PLAN_REVIEW = frozenset({"plan-review-research", "plan-research"})
ALL_PREFIXES = frozenset(
    {"research", "ops", "plan-research", "plan-ops", "plan-review-research", "review"}
)

# Exact ownership is declared here rather than inferred from path substrings.
MANIFEST: tuple[AuditFile, ...] = (
    AuditFile("implementation fragment", R, "pi-fragments/openspec-story-converge.md", "implementation", IMPLEMENTATION, True, "implementation"),
    AuditFile("implementation generated", P, "openspec-story-converge/SKILL.md", "implementation", IMPLEMENTATION, pair="implementation"),
    AuditFile("planning fragment", R, "pi-fragments/openspec-story-plan-converge.md", "planning", PLANNING, True, "planning"),
    AuditFile("planning generated", P, "openspec-story-plan-converge/SKILL.md", "planning", PLANNING, pair="planning"),
    AuditFile("review fragment", R, "pi-fragments/openspec-story-review.md", "review", REVIEW, True, "review"),
    AuditFile("review generated", P, "openspec-story-review/SKILL.md", "review", REVIEW, pair="review"),
    AuditFile("claim fragment", R, "pi-fragments/openspec-story-claim.md", "producer", RESEARCH, True, "claim"),
    AuditFile("claim generated", P, "openspec-story-claim/SKILL.md", "producer", RESEARCH, pair="claim"),
    AuditFile("resume fragment", R, "pi-fragments/openspec-story-resume.md", "producer", RESEARCH, True, "resume"),
    AuditFile("resume generated", P, "openspec-story-resume/SKILL.md", "producer", frozenset({"research", "review"}), pair="resume"),
    AuditFile("plan-resume fragment", R, "pi-fragments/openspec-story-plan-resume.md", "producer", frozenset({"plan-research"}), True, "plan-resume"),
    AuditFile("plan-resume generated", P, "openspec-story-plan-resume/SKILL.md", "producer", frozenset({"plan-research", "review"}), pair="plan-resume"),
    AuditFile("plan-review fragment", R, "pi-fragments/openspec-story-plan-review.md", "producer", PLAN_REVIEW, True, "plan-review"),
    AuditFile("plan-review generated", P, "openspec-story-plan-review/SKILL.md", "producer", PLAN_REVIEW, pair="plan-review"),
    AuditFile("claim owner", R, "claude/skills/openspec-story-claim/SKILL.md", "owner", frozenset(), pair="claim"),
    AuditFile("claim Codex owner", C, "openspec_story_claim/SKILL.md", "owner", frozenset(), pair="claim"),
    AuditFile("resume owner", R, "claude/skills/openspec-story-resume/SKILL.md", "owner", REVIEW, pair="resume"),
    AuditFile("resume Codex owner", C, "openspec_story_resume/SKILL.md", "owner", REVIEW, pair="resume"),
    AuditFile("plan-resume owner", R, "claude/skills/openspec-story-plan-resume/SKILL.md", "owner", REVIEW, pair="plan-resume"),
    AuditFile("plan-resume Codex owner", C, "openspec_story_plan_resume/SKILL.md", "owner", REVIEW, pair="plan-resume"),
    AuditFile("plan-review owner", R, "claude/skills/openspec-story-plan-review/SKILL.md", "owner", PLAN_REVIEW, pair="plan-review"),
    AuditFile("plan-review Codex owner", C, "openspec_story_plan_review/SKILL.md", "owner", PLAN_REVIEW, pair="plan-review"),
    AuditFile("implementation canonical", R, "claude/skills/openspec-story-converge/SKILL.md", "canonical", IMPLEMENTATION, pair="implementation"),
    AuditFile("planning canonical", R, "claude/skills/openspec-story-plan-converge/SKILL.md", "canonical", PLANNING, pair="planning"),
    AuditFile("review canonical", R, "claude/skills/openspec-story-review/SKILL.md", "canonical", REVIEW, pair="review"),
    AuditFile("adding-command docs", R, "docs/adding-a-command.md", "docs", ALL_PREFIXES, pair="adding-command"),
    AuditFile("conventions docs", R, "docs/openspec-conventions.md", "docs", ALL_PREFIXES, pair="conventions"),
    AuditFile("lifecycle docs", R, "docs/openspec-lifecycle.md", "docs", ALL_PREFIXES, pair="lifecycle"),
)
