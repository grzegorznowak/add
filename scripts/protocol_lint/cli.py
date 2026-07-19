"""Command-line orchestration for the exact notebook protocol manifest."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from protocol_lint.common import Error, read_utf8
from protocol_lint.lifecycle import validate_file
from protocol_lint.manifest import MANIFEST, AuditRoots
from protocol_lint.mutations import self_test
from protocol_lint.pairing import AuditResult, compare_generated


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audit the complete exact-file OpenSpec notebook protocol manifest."
    )
    parser.add_argument("--repository-root", required=True, type=Path)
    parser.add_argument("--codex-root", required=True, type=Path)
    parser.add_argument("--pi-root", required=True, type=Path)
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args(argv)


def run(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        roots = AuditRoots(
            repository=args.repository_root.resolve(strict=True),
            codex=args.codex_root.resolve(strict=True),
            pi=args.pi_root.resolve(strict=True),
        )
        results: dict[str, AuditResult] = {}
        for entry in MANIFEST:
            results[entry.name] = validate_file(entry, roots)
        compare_generated(MANIFEST, results)
        if args.self_test:
            implementation = results["implementation fragment"][1]
            review = results["review fragment"][1]
            if implementation is None or review is None:
                raise Error("self-test manifest lacks implementation/review prompts")
            self_test(
                implementation,
                results["implementation fragment"][0],
                results["planning fragment"][0],
                review,
                results["review fragment"][0],
                read_utf8(
                    next(
                        entry.resolve(roots)
                        for entry in MANIFEST
                        if entry.name == "plan-resume owner"
                    )
                ),
            )
    except (Error, OSError, UnicodeError) as exc:
        print(f"FAIL notebook protocol: {exc}", file=sys.stderr)
        return 1
    print(
        "ok   notebook protocol: exact manifest, fenced prompts, runtime boundary, "
        "families, generated parity, mutations"
    )
    return 0
