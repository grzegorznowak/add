"""Exact source/generated pairing policy."""
from __future__ import annotations

from collections.abc import Mapping

from protocol_lint.common import STANDALONE_DEFAULT, Error
from protocol_lint.contracts import require_exact
from protocol_lint.manifest import AuditFile

AuditResult = tuple[str, str | None]


def validate_generated_pair(
    label: str,
    fragment: AuditResult,
    generated: AuditResult,
    *,
    assert_single_mode_contract: bool = False,
) -> None:
    """Require installed Pi output to end with its exact source fragment."""
    fragment_raw, fragment_prompt = fragment
    generated_raw, generated_prompt = generated
    if fragment_prompt != generated_prompt:
        raise Error(f"{label}: generated Pi prompt differs from fragment")
    if not generated_raw.rstrip().endswith(fragment_raw.rstrip()):
        raise Error(f"{label}: generated Pi output does not end with exact fragment content")
    if assert_single_mode_contract:
        require_exact(generated_raw, STANDALONE_DEFAULT, label=label)
        require_exact(generated_raw, "- **Standalone coordinator mode:**", label=label)
        require_exact(generated_raw, "- **Converger-child mode:**", label=label)


def compare_generated(
    entries: tuple[AuditFile, ...], results: Mapping[str, AuditResult]
) -> None:
    """Pair exact manifest roles without path-derived naming heuristics."""
    for pair in ("implementation", "planning", "review"):
        relevant = [entry for entry in entries if entry.pair == pair and entry.kind == pair]
        _compare_one(pair, relevant, results)

    for pair in ("claim", "resume", "plan-resume", "plan-review"):
        relevant = [entry for entry in entries if entry.pair == pair and entry.kind == "producer"]
        _compare_one(pair, relevant, results, assert_single_mode_contract=True)


def _compare_one(
    label: str,
    entries: list[AuditFile],
    results: Mapping[str, AuditResult],
    *,
    assert_single_mode_contract: bool = False,
) -> None:
    fragments = [entry for entry in entries if entry.fragment]
    generated = [entry for entry in entries if not entry.fragment]
    if len(fragments) != 1 or len(generated) != 1:
        raise Error(
            f"{label}: manifest requires exactly one fragment/generated pair, "
            f"got {len(fragments)}/{len(generated)}"
        )
    validate_generated_pair(
        label,
        results[fragments[0].name],
        results[generated[0].name],
        assert_single_mode_contract=assert_single_mode_contract,
    )
