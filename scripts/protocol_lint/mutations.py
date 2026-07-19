"""Adversarial mutation suite for the notebook protocol lint."""
from __future__ import annotations

import json
from collections.abc import Callable

from protocol_lint.common import (
    HASH_COMMAND,
    OPTIONAL_NOTEBOOK,
    REPO_CLAUSES,
    REPO_FRAGMENT_REFERENCE,
    STANDALONE_DEFAULT,
    Error,
)
from protocol_lint.contracts import (
    page_prefixes,
    reject_stale_transport,
    require_exact,
    require_fragment_repo_reference,
    require_order,
    require_repo_contract,
    require_repo_tool,
    validate_converger_prompt,
    validate_review_prompt,
)
from protocol_lint.markdown import parse_markdown, spawn_prompts
from protocol_lint.pairing import validate_generated_pair


def expect_rejected(label: str, callback: Callable[[], object]) -> None:
    try:
        callback()
    except Error:
        return
    raise Error(f"self-test mutation was not rejected: {label}")


def self_test(
    implementation: str,
    implementation_raw: str,
    planning_raw: str,
    review: str,
    review_raw: str,
    plan_resume_raw: str,
) -> None:
    # Prompt-level polarity, duplicate, broad-retrieval, and nested-spawn mutations.
    owner = "openspec-story-<claim|resume>"
    skill_path = f"~/.pi/agent/skills/{owner}/SKILL.md"
    mutations = {
        "direct read omission": implementation.replace(
            f"Use read exactly once on {skill_path}", "Consult the owning workflow"
        ),
        "direct apply omission": implementation.replace(
            "then apply that SKILL.md as the complete owning workflow",
            "then continue with the workflow",
        ),
        "slash-command suffix": implementation.replace(
            "Execute independently", "/openspec-story-review; Execute independently"
        ),
        "negated spawn prohibition": implementation.replace(
            "do not call spawn or any notebook tool", "not forbidden to call spawn or any notebook tool"
        ),
        "alias polarity": implementation.replace(
            "do not use them", "may use notebook previews"
        ),
        "broad retrieval": implementation.replace(
            "Perform all required focused research inline", "Retrieve the named notebook page, then perform focused research inline"
        ),
        "nested spawn": implementation.replace(
            "Execute independently", "spawn({ prompt: \\\"nested\\\" }); Execute independently"
        ),
    }
    for label, candidate in mutations.items():
        def reject_converger(value: str = candidate, item: str = label) -> None:
            validate_converger_prompt(value, item, owner)

        expect_rejected(label, reject_converger)

    review_mutations = {
        "review contradiction": review.replace("Do not call any notebook tool", "May call any notebook tool"),
        "review stale token": review.replace("<review_run_sentinel>", "stale"),
        "review nested spawn": review.replace("spawn another child", "spawn({ another child"),
    }
    for label, candidate in review_mutations.items():
        def reject_review(value: str = candidate, item: str = label) -> None:
            validate_review_prompt(value, item)

        expect_rejected(label, reject_review)

    expect_rejected(
        "hash command omission",
        lambda: require_repo_contract(
            implementation_raw.replace(HASH_COMMAND, "manually calculate SHA-256", 1),
            "hash command omission",
        ),
    )
    expect_rejected(
        "sha256sum tool omission",
        lambda: require_repo_tool(
            implementation_raw.replace(" Bash(sha256sum:*)", "", 1),
            "sha256sum tool omission",
        ),
    )
    expect_rejected(
        "optional notebook gating omission",
        lambda: require_repo_contract(
            implementation_raw.replace(OPTIONAL_NOTEBOOK[0], "Always derive the repository key", 1),
            "optional notebook gating omission",
        ),
    )
    immediate_gate = (
        "Immediately after it finishes, before any plan-review launch",
        "run the Mode A gate against the captured snapshot",
        "Only after any applicable immediate Mode A or Mode B post-resume gate has passed",
    )
    expect_rejected(
        "plan review before immediate resume gate",
        lambda: require_order(
            planning_raw.replace(immediate_gate[0], immediate_gate[-1], 1),
            immediate_gate,
            "plan review before immediate resume gate",
        ),
    )
    mode_c_evidence = "exact pre/post evidence that the defect is gone"
    expect_rejected(
        "Mode C durable evidence omission",
        lambda: require_exact(
            plan_resume_raw.replace(mode_c_evidence, "operator says the defect is fixed", 1),
            mode_c_evidence,
            label="Mode C durable evidence omission",
        ),
    )
    mode_c_override = "Mode C overrides every generic Plan-lane downgrade or output rule"
    expect_rejected(
        "Mode C generic downgrade override omission",
        lambda: require_exact(
            plan_resume_raw.replace(mode_c_override, "Generic downgrade rules still apply", 1),
            mode_c_override,
            label="Mode C generic downgrade override omission",
        ),
    )
    review_repair_ref = (
        "/openspec-story-plan-resume <initiative-slug> <story-slug> "
        "REPAIR_REF=<verified-planning-path>#<verified-anchor>"
    )
    expect_rejected(
        "review semantic repair selector omission",
        lambda: require_exact(
            review_raw.replace(review_repair_ref, "Suggested next action: plan-resume", 1),
            review_repair_ref,
            label="review semantic repair selector omission",
        ),
    )
    mode_zero_route = (
        "For `Status: 🟣 IN REVIEW`, retain `Status: 🟣 IN REVIEW` and stop singularly "
        "with fresh `/openspec-story-review <initiative-slug> <story-slug>` from a new "
        "oblivious session; never route through plan-converge or plan-review."
    )
    expect_rejected(
        "Mode 0 IN REVIEW planning loop",
        lambda: require_exact(
            plan_resume_raw.replace(mode_zero_route, "Route Mode 0 through plan-converge.", 1),
            mode_zero_route,
            label="Mode 0 IN REVIEW planning loop",
        ),
    )
    isolation_limit = "Current Pi spawn exposes notebook tools and automatic notebook page-name/preview material"
    expect_rejected(
        "review spawn self-attestation treated as isolation",
        lambda: require_exact(
            review_raw.replace(isolation_limit, "Current Pi spawn is isolated", 1),
            isolation_limit,
            label="review spawn self-attestation treated as isolation",
        ),
    )

    owner_mode = STANDALONE_DEFAULT + "\nStandalone coordinator mode\nConverger-child mode"
    expect_rejected(
        "standalone default omission",
        lambda: require_exact(
            owner_mode.replace(STANDALONE_DEFAULT, "Invocation chooses a mode."),
            STANDALONE_DEFAULT,
            label="standalone default omission",
        ),
    )
    ordering_clauses = (
        "Hold accepted proposals in memory and perform no notebook read, merge, or write yet.",
        "First refresh/recompute the OpenSpec root and every artifact path",
        "If optional notebook persistence remains enabled, rederive repository-key-v1",
        "Only after equality succeeds may `notebook_read` read the current stable page",
    )
    expect_rejected(
        "notebook merge before reroot",
        lambda: require_order(
            implementation_raw.replace(ordering_clauses[0], ordering_clauses[-1], 1),
            ordering_clauses,
            "notebook merge before reroot",
        ),
    )
    expect_rejected(
        "stale bare-page transport",
        lambda: reject_stale_transport("Pass sourced notebook page names.", "stale transport"),
    )
    expect_rejected(
        "fragment repository algorithm duplication",
        lambda: require_fragment_repo_reference(
            REPO_FRAGMENT_REFERENCE + "\n" + REPO_CLAUSES[0],
            "fragment repository algorithm duplication",
        ),
    )

    # Parser fixtures cover comments, fences, renamed keys/prose decoys, and extras.
    quoted = json.dumps(implementation, ensure_ascii=False)
    valid = f"```js\nspawn({{prompt: {quoted}, thinking: \"medium\"}})\n```\n"
    parsed = parse_markdown(valid, "valid fixture")
    fixture_prompts = spawn_prompts(parsed, "valid fixture")
    if fixture_prompts != [implementation]:
        raise Error("self-test valid JSON prompt decoding drifted")
    validate_converger_prompt(fixture_prompts[0], "valid prohibition fixture", owner)
    fixtures = {
        "commented contract": f"<!-- {valid} -->",
        "unclosed comment": "<!-- spawn({ prompt: \"x\" })",
        "unclosed fence": valid.removesuffix("```\n"),
        "prompt renamed plus prose decoy": valid.replace("prompt:", "message:", 1) + "Prompt: safe prose\n",
        "duplicate prompt same line": valid.replace(", thinking:", ', prompt: "decoy", thinking:', 1),
        "second positional object": (
            f"```js\nspawn({{prompt: {quoted}, thinking: \"medium\"}}, "
            "{prompt: \"unsafe\", thinking: \"high\"})\n```\n"
        ),
        "nested prompt": (
            f"```js\nspawn({{wrapper: {{prompt: {quoted}}}, thinking: \"medium\"}})\n```\n"
        ),
        "garbage member": (
            f"```js\nspawn({{prompt: {quoted}, garbage, thinking: \"medium\"}})\n```\n"
        ),
        "extra property": (
            f"```js\nspawn({{prompt: {quoted}, thinking: \"medium\", extra: true}})\n```\n"
        ),
        "extra prompt": valid + "```js\nspawn({prompt: \"unsafe\", thinking: \"high\"})\n```\n",
        "line-commented spawn": valid.replace("spawn(", "// spawn(", 1),
        "guarded spawn": valid.replace("spawn(", "false && spawn(", 1),
        "prefix statement": valid.replace("spawn(", "prepare(); spawn(", 1),
        "suffix statement": valid.replace("\n```", "\ncleanup();\n```", 1),
        "multiple calls in one fence": valid.replace(
            "\n```", "\nspawn({prompt: \"unsafe\", thinking: \"high\"});\n```", 1
        ),
        "comment-interposed spawn": valid.replace("spawn(", "spawn /*comment*/ (", 1),
    }
    # A trailing semicolon is the only optional statement suffix, and spawn-like
    # words inside the JSON prompt remain inert during active-call counting.
    masked_prompt = implementation + "\nLiteral parser decoy: spawn( is prompt text only."
    masked = (
        f"```js\nspawn({{prompt: {json.dumps(masked_prompt, ensure_ascii=False)}, "
        'thinking: "medium"});\n```\n'
    )
    if spawn_prompts(parse_markdown(masked, "JSON masking fixture"), "JSON masking fixture") != [
        masked_prompt
    ]:
        raise Error("self-test JSON-string masking drifted")

    for label, fixture in fixtures.items():
        def reject_fixture(value: str = fixture, item: str = label) -> None:
            md = parse_markdown(value, item)
            got = spawn_prompts(md, item)
            if len(got) != 1:
                raise Error(f"{item}: expected one spawn")
            validate_converger_prompt(got[0], item, owner)
        expect_rejected(label, reject_fixture)

    # Page boundaries, suffix/per-run, and malformed family mutations.
    base_page = "openspec-research-<repository_key>-<initiative_slug>-<story-slug>"
    for label, value in {
        "slash suffix": base_page + "/",
        "family suffix": base_page + "-family",
        "per-run suffix": base_page + "-run-7",
        "malformed qualifier": "openspec-research-<initiative_slug>-<story-slug>",
        "extra malformed family": base_page + " openspec-ops-<repository_key>-bad",
    }.items():
        def reject_page(candidate: str = value, item: str = label) -> None:
            page_prefixes(candidate, item)

        expect_rejected(label, reject_page)

    fragment = ("fragment-body\n", implementation)
    expect_rejected(
        "generated fragment omission",
        lambda: validate_generated_pair("fixture", fragment, ("canonical-only\n", implementation)),
    )
    expect_rejected(
        "generated fragment drift",
        lambda: validate_generated_pair("fixture", fragment, ("canonical\nfragment-drift\n", implementation)),
    )
