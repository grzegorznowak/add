"""Notebook naming, repository-key, and child-prompt contracts."""
from __future__ import annotations

import re

from protocol_lint.common import (
    HASH_COMMAND,
    OPTIONAL_NOTEBOOK,
    PAGE_EXACT,
    PAGE_START,
    REPO_CLAUSES,
    REPO_FRAGMENT_REFERENCE,
    REPO_TOOL_TOKENS,
    SPAWN_START,
    STALE_TRANSPORT,
    UNTRUSTED,
    BOUNDARY_PROOF,
    Error,
)


def require_exact(text: str, literal: str, count: int = 1, label: str = "contract") -> None:
    actual = text.count(literal)
    if actual != count:
        raise Error(f"{label}: expected {count} exact occurrence(s) of {literal!r}, got {actual}")


def require_repo_contract(text: str, label: str) -> None:
    for clause in (*REPO_CLAUSES, HASH_COMMAND, *OPTIONAL_NOTEBOOK):
        if clause not in text:
            raise Error(f"{label}: incomplete repository-key-v1 contract; missing {clause!r}")


def require_repo_tool(text: str, label: str) -> None:
    match = re.search(r"^allowed-tools:[^\n]*$", text, re.MULTILINE)
    if match is None:
        raise Error(f"{label}: repository-key derivation lacks allowed-tools")
    for token in REPO_TOOL_TOKENS:
        if token not in match.group(0):
            raise Error(f"{label}: repository-key derivation lacks exact tool token {token!r}")


def require_fragment_repo_reference(text: str, label: str) -> None:
    require_exact(text, REPO_FRAGMENT_REFERENCE, label=label)
    for clause in (
        "missing/invalid origin or key drift fails closed by skipping that notebook operation",
        "canonical artifacts and the canonical workflow continue as authority",
    ):
        if clause not in text:
            raise Error(f"{label}: incomplete optional-notebook gating; missing {clause!r}")
    if REPO_CLAUSES[0] in text:
        raise Error(f"{label}: Pi fragment duplicates the canonical repository-key-v1 algorithm")


def reject_stale_transport(text: str, label: str) -> None:
    lower = text.lower()
    for phrase in STALE_TRANSPORT:
        if phrase.lower() in lower:
            raise Error(f"{label}: stale broad notebook transport term {phrase!r}")


def require_order(text: str, clauses: tuple[str, ...], label: str) -> None:
    positions = [text.find(clause) for clause in clauses]
    if any(position < 0 for position in positions) or positions != sorted(positions):
        raise Error(f"{label}: required protocol ordering missing or out of order: {clauses!r}")


def page_prefixes(text: str, label: str) -> set[str]:
    found = {match.group("prefix") for match in PAGE_EXACT.finditer(text)}
    for start in PAGE_START.finditer(text):
        exact = PAGE_EXACT.match(text, start.start())
        if exact is None:
            excerpt = text[start.start() : start.start() + 140].splitlines()[0]
            raise Error(f"{label}: malformed/noncanonical page-family token {excerpt!r}")
        tail = text[exact.end() : exact.end() + 24]
        if re.match(r"[/_-](?:run|per-run|family|entry|page|[<A-Za-z0-9])", tail):
            raise Error(f"{label}: page-family token has forbidden suffix {tail!r}")
    return found


def reject_prompt_contradictions(prompt: str, label: str) -> None:
    lower = prompt.lower()
    bad = (
        r"\b(?:may|can|must|should|please)\s+(?:call|use)\s+(?:any\s+)?notebook",
        r"\b(?:call|use)\s+notebook_(?:read|write|index)",
        r"\b(?:retrieve|read|load)\s+(?:the\s+)?(?:named\s+)?notebook\s+(?:page|entry)",
        r"\bdo\s+not\s+(?:ignore|treat).{0,80}(?:page names|previews)",
        r"\b(?:may|can|should|must)\s+spawn\b",
        r"\bwrite\s+(?:the\s+)?(?:shared\s+)?notebook\s+page\b",
        r"\bnot\s+(?:forbidden|required)\s+to\s+(?:avoid\s+)?(?:spawn|use\s+notebook)",
    )
    for pattern in bad:
        if re.search(pattern, lower, re.S):
            raise Error(f"{label}: contradictory/unsafe prompt clause matches {pattern!r}")
    if SPAWN_START.search(prompt):
        raise Error(f"{label}: nested spawn call in child prompt")
    if re.search(r"(?:^|\s)/(?:openspec|skill:)[^\s\"]*", prompt):
        raise Error(f"{label}: embedded slash-command suffix")


def validate_converger_prompt(prompt: str, label: str, owner: str) -> None:
    skill_path = f"~/.pi/agent/skills/{owner}/SKILL.md"
    mandatory = (
        "Converger-child mode",
        skill_path,
        f"Use read exactly once on {skill_path}",
        "then apply that SKILL.md as the complete owning workflow",
        "do not call spawn or any notebook tool",
        "including notebook_read, notebook_write, notebook_index, or topic tools",
        UNTRUSTED,
        "focused research inline with ordinary read/search tools",
        "compact records already copied into this prompt",
        "Ref/Purpose/Expected anchors/Lookup",
        "Neutral ops payload",
        "Return sourced proposals and stale-record notes to the coordinator; never write a shared page.",
        BOUNDARY_PROOF,
    )
    for clause in mandatory:
        require_exact(prompt, clause, label=label)
    reject_prompt_contradictions(prompt, label)


def validate_review_prompt(prompt: str, label: str) -> None:
    mandatory = (
        "<fresh_review_run_token>",
        "<review_run_sentinel>",
        "Echo this exact token and sentinel",
        "Do not call any notebook tool",
        "including notebook_read, notebook_write, notebook_index, or topic tools",
        UNTRUSTED,
        "spawn another child",
        BOUNDARY_PROOF,
    )
    for clause in mandatory:
        require_exact(prompt, clause, label=label)
    for alias in (
        "notebook references/pages/lists/previews",
        "research",
        "ops or operational context",
        "handoff",
        "compact excerpts",
        "renamed selectors",
        "implementation summaries or context",
        "convergence summaries or context",
        "relabeled implementation context",
        "relabeled convergence context",
        "evidence bundles",
        "orientation",
        "digests",
        "briefings",
        "prior chat",
    ):
        require_exact(prompt, alias, label=label)
    reject_prompt_contradictions(prompt, label)
