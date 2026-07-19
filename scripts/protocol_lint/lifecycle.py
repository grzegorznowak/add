"""Lifecycle Mode A/B/C, ordering, and per-role file checks."""
from __future__ import annotations

from protocol_lint.common import HASH_COMMAND, STANDALONE_DEFAULT, Error, read_utf8
from protocol_lint.contracts import (
    page_prefixes,
    reject_stale_transport,
    require_fragment_repo_reference,
    require_order,
    require_repo_contract,
    require_repo_tool,
    validate_converger_prompt,
    validate_review_prompt,
)
from protocol_lint.manifest import AuditFile, AuditRoots
from protocol_lint.markdown import parse_markdown, spawn_prompts


def validate_file(entry: AuditFile, roots: AuditRoots) -> tuple[str, str | None]:
    path = entry.resolve(roots)
    label = str(path)
    kind = entry.kind
    raw = read_utf8(path)
    md = parse_markdown(raw, label)
    expected = set(entry.expected_prefixes)
    found = page_prefixes(md.active, label)
    if found != expected:
        raise Error(f"{label}: page-family parity expected {sorted(expected)}, got {sorted(found)}")
    is_fragment = entry.fragment
    reject_stale_transport(md.active, label)
    if kind != "docs" and is_fragment:
        require_fragment_repo_reference(md.active, label)
    elif kind != "docs":
        require_repo_contract(md.active, label)
        require_repo_tool(raw, label)
    elif entry.pair == "conventions":
        for clause in (
            "git -C <openspec_root> remote get-url --all origin",
            "SCP form",
            "absolute `ssh`, `http`, `https`, or `git` URI",
            "default port",
            "nondefault port",
            "preserve path case",
            "terminal `.git`",
            "normalize to exactly the same nonempty identity",
            "UTF-8 bytes, with no newline",
            "full lowercase hexadecimal SHA-256",
            HASH_COMMAND,
            "Missing/differing/invalid identities or reroot key drift disable or fail closed",
            "canonical artifact workflow continues",
        ):
            if clause not in md.active:
                raise Error(f"{label}: incomplete normative repository-key-v1 contract; missing {clause!r}")
    elif not all(word in md.active.lower() for word in ("exact normative", "repository-key-v1", "openspec-conventions.md")):
        raise Error(f"{label}: must reference the exact normative repository-key-v1 contract")

    if kind in {"implementation", "planning", "review"}:
        prompts = spawn_prompts(md, label)
        if len(prompts) != 1:
            raise Error(f"{label}: expected exactly one active fenced spawn, got {len(prompts)}")
        prompt = prompts[0]
        if kind == "implementation":
            validate_converger_prompt(prompt, label, "openspec-story-<claim|resume>")
            if is_fragment:
                require_order(md.active, (
                    "Hold accepted proposals in memory and perform no notebook read, merge, or write yet.",
                    "First refresh/recompute the OpenSpec root and every artifact path",
                    "If optional notebook persistence remains enabled, rederive repository-key-v1",
                    "Only after equality succeeds may `notebook_read` read the current stable page",
                ), label)
            else:
                require_order(md.active, (
                    "Hold all returned proposals and mismatch notes in memory.",
                    "After selecting the refreshed root",
                    "If notebook persistence was selected and remains available, rederive repository-key-v1",
                    "Only after a successful equality check may the coordinator read the current stable research record",
                ), label)
        elif kind == "planning":
            validate_converger_prompt(prompt, label, "openspec-story-plan-<review|resume>")
            for clause in (
                "targeted edits in every affected authoritative planning artifact/section",
                "A mandatory line anchor or one spec section alone is insufficient",
                "Mode B — structural repair",
                "exact pre/post evidence",
            ):
                if clause not in md.active:
                    raise Error(f"{label}: incomplete mode-specific resume gate; missing {clause!r}")
            require_order(md.active, (
                "Before spawn, and only when optional notebook orientation is available and selected",
                "Then launch exactly one fresh child:",
                "After return, hold every proposal and mismatch note in memory",
                "Refresh/recompute the OpenSpec root and every artifact path",
                "Immediately after **every** resume",
                "Only after refreshed artifacts and the applicable gate pass",
                "Equality permits `notebook_read`",
            ), label)
        else:
            validate_review_prompt(prompt, label)
            for clause in (
                "Current Pi spawn exposes notebook tools and automatic notebook page-name/preview material",
                "do not launch the optional review-orientation child",
                "child's self-attested runtime-boundary statement does not prove isolation",
                "Review current canonical artifacts and live paths directly instead",
            ):
                if clause not in md.active:
                    raise Error(f"{label}: incomplete review isolation limit; missing {clause!r}")
        return raw, prompt

    if kind == "producer" and is_fragment:
        for clause in (
            "canonical `## Notebook mode contract` in this installed skill is the sole authority",
            "this Pi fragment does not redeclare those semantics",
            "Pi-specific stable-page tooling uses",
            "whole-page read-modify-write operations with preservation",
            "automatically supply notebook page names and first-line previews",
            "untrusted non-input",
        ):
            if clause not in md.active:
                raise Error(f"{label}: incomplete Pi-specific producer fragment: {clause!r}")
        for duplicate in (
            STANDALONE_DEFAULT,
            "- **Standalone coordinator mode:**",
            "- **Converger-child mode:**",
        ):
            if duplicate in md.active:
                raise Error(f"{label}: fragment duplicates canonical mode declaration {duplicate!r}")

    if kind in {"producer", "owner"} and not is_fragment:
        clauses = (
            STANDALONE_DEFAULT,
            "Standalone coordinator mode",
            "Converger-child mode",
            "untrusted non-input",
            "Do not call `spawn` or any notebook tool",
            "never retrieve",
            "focused research inline",
            "proposed",
            "stale-record notes",
            "Do not write a notebook page",
        )
        lower = md.active.lower()
        for clause in clauses:
            if clause.lower() not in lower:
                raise Error(f"{label}: incomplete owner mode contract; missing {clause!r}")
    if kind in {"producer", "owner"}:
        if entry.pair == "plan-review":
            for family in ("openspec-plan-review-research-", "openspec-plan-research-"):
                if family not in md.active:
                    raise Error(f"{label}: plan-review page ownership is ambiguous")
        if entry.pair == "plan-resume":
            for clause in (
                "IN REVIEW planning-repair-only",
                "retain `Status: 🟣 IN REVIEW`",
                "Do not perform implementation work",
                "Mode C — Verified IN REVIEW targeted repair",
                "REPAIR_REF=<planning-path>#<anchor>",
                "Mode C overrides every generic Plan-lane downgrade or output rule",
                "preserves `Plan: 🟢 PLAN APPROVED` and `Status: 🟣 IN REVIEW`",
                "exact pre/post evidence that the defect is gone",
                "do not launch review or route through plan-converge/plan-review",
            ):
                if clause.lower() not in md.active.lower():
                    raise Error(f"{label}: incomplete IN REVIEW direct repair contract; missing {clause!r}")
        return raw, None

    if kind == "canonical":
        for clause in (
            "single coordinator writer",
            "read-modify-write",
            "in-page retirement",
            "in-page compaction",
        ):
            if clause not in md.active:
                raise Error(f"{label}: incomplete canonical coordinator contract: {clause!r}")
        if entry.pair == "planning":
            for clause in (
                "always stop before the planning loop and never launch plan-review, plan-resume, implementation work, or review",
                "executable direct repair route `/openspec-story-plan-resume",
                "REPAIR_REF=<planning-path>#<anchor>",
                "planning-contract/scaffold-only repair",
                "targeted edits in every affected authoritative planning artifact/section",
                "Before any approved Plan/log shortcut",
            ):
                if clause not in md.active:
                    raise Error(f"{label}: incomplete executable IN REVIEW/mode gate: {clause!r}")
            require_order(md.active, (
                "Before any approved Plan/log shortcut",
                "Only after that scaffold/artifact-shape gate passes, if the `Plan:` header field is `🟢 PLAN APPROVED`",
            ), label)
            require_order(md.active, (
                "Optional notebook orientation happens now, before child-prompt dispatch.",
                "After optional extraction, build the fresh child task prompt",
                "capture the exact pre-resume snapshot immediately before launch",
                "Immediately after it finishes, before any plan-review launch",
                "hold all returned notebook proposals and mismatch notes in memory",
                "Refresh worktree/root resolution, recompute every artifact path",
                "run the Mode A gate against the captured snapshot",
                "Only after this artifact gate passes, and only if optional notebook persistence remains available and selected",
                "Only after any applicable immediate Mode A or Mode B post-resume gate has passed",
            ), label)
        elif entry.pair == "implementation":
            require_order(md.active, (
                "Hold all returned proposals and mismatch notes in memory.",
                "After selecting the refreshed root",
                "If notebook persistence was selected and remains available, rederive repository-key-v1",
                "Only after a successful equality check may the coordinator read the current stable research record",
            ), label)
        elif entry.pair == "review":
            for clause in (
                "planning-contract/scaffold-only repair",
                "exact verified `REPAIR_REF=<planning-path>#<anchor>`",
                "/openspec-story-plan-resume <initiative-slug> <story-slug> REPAIR_REF=<verified-planning-path>#<verified-anchor>",
                "scalar **Suggested next action:** line",
            ):
                if clause not in md.active:
                    raise Error(f"{label}: review lacks executable non-looping IN REVIEW planning repair route: {clause!r}")
        return raw, None

    if kind == "docs":
        for clause in ("read-modify-write", "in-page retirement", "<repository_key>"):
            if clause not in md.active:
                raise Error(f"{label}: incomplete notebook documentation: {clause!r}")
        return raw, None
    raise Error(f"{label}: unknown audit kind {kind}")
