"""Strict Markdown and fenced-spawn parsing."""
from __future__ import annotations

import json
import re

from protocol_lint.common import Error, Markdown, PAGE_START, SPAWN_START


def strip_comments(text: str, label: str) -> str:
    """Remove balanced Markdown comments while rejecting hidden contracts."""
    out: list[str] = []
    pos = 0
    while pos < len(text):
        start = text.find("<!--", pos)
        # A bare ``-->`` is ordinary Markdown text (the lifecycle diagrams use
        # it as an arrow); only an opener starts comment parsing.
        if start == -1:
            out.append(text[pos:])
            break
        out.append(text[pos:start])
        close = text.find("-->", start + 4)
        if close == -1:
            raise Error(f"{label}: unclosed Markdown comment")
        nested = text.find("<!--", start + 4, close)
        if nested != -1:
            raise Error(f"{label}: nested/unbalanced Markdown comment")
        hidden = text[start + 4 : close]
        if SPAWN_START.search(hidden) or PAGE_START.search(hidden):
            raise Error(f"{label}: notebook/spawn contract hidden in Markdown comment")
        # Preserve newlines so diagnostics and fence structure remain stable.
        out.append("\n" * hidden.count("\n"))
        pos = close + 3
    return "".join(out)


def parse_markdown(text: str, label: str) -> Markdown:
    active = strip_comments(text, label)
    fences: list[str] = []
    outside: list[str] = []
    current: list[str] | None = None
    fence_char = ""
    fence_len = 0
    opener = re.compile(r"^( {0,3})(`{3,}|~{3,})([^\n]*)$")
    for line in active.splitlines(keepends=True):
        raw = line.rstrip("\r\n")
        match = opener.match(raw)
        if current is None:
            if match:
                token = match.group(2)
                fence_char, fence_len = token[0], len(token)
                current = []
            else:
                outside.append(line)
            continue
        close = re.match(rf"^ {{0,3}}{re.escape(fence_char)}{{{fence_len},}}[ \t]*$", raw)
        if close:
            fences.append("".join(current))
            current = None
            fence_char = ""
            fence_len = 0
        else:
            current.append(line)
    if current is not None:
        raise Error(f"{label}: unclosed Markdown fence")
    if SPAWN_START.search("".join(outside)):
        raise Error(f"{label}: active spawn call must be inside a closed fence")
    return Markdown(active=active, fences=tuple(fences))


def balanced_call(code: str, start: int, label: str) -> tuple[str, int]:
    """Return one spawn(...) body using JSON-string-aware balancing."""
    open_at = code.find("(", start)
    depth = 0
    quote = False
    escaped = False
    for index in range(open_at, len(code)):
        char = code[index]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quote = False
            continue
        if char == '"':
            quote = True
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return code[open_at + 1 : index], index + 1
    raise Error(f"{label}: malformed/unclosed spawn call")


def prompt_from_call(body: str, label: str) -> str:
    """Decode the one controlled spawn shape and reject all other JS syntax."""
    stripped = body.strip()
    prefix = re.match(r"^\{\s*prompt\s*:\s*", stripped)
    if prefix is None:
        raise Error(
            f"{label}: spawn requires exactly one positional top-level object literal "
            "whose first and only prompt key is top-level"
        )
    after_prompt = stripped[prefix.end() :]
    try:
        prompt, used = json.JSONDecoder().raw_decode(after_prompt)
    except json.JSONDecodeError as exc:
        raise Error(f"{label}: invalid JSON-compatible prompt string: {exc.msg}") from exc
    if not isinstance(prompt, str):
        raise Error(f"{label}: prompt value is not a string")

    # Controlled fixtures support exactly ``{prompt: <JSON string>, thinking:
    # <JSON string>}`` in that order. Requiring the complete tail rejects nested
    # prompt keys, second positional arguments, spread/computed properties,
    # methods, garbage members, and unknown/extra properties.
    tail = after_prompt[used:]
    thinking_match = re.fullmatch(
        r'\s*,\s*thinking\s*:\s*"(low|medium|high)"\s*\}\s*', tail
    )
    if thinking_match is None:
        raise Error(
            f"{label}: spawn supports only {{prompt: <JSON string>, "
            'thinking: "low|medium|high"}} with no other arguments or properties'
        )
    return prompt


def spawn_prompts(md: Markdown, label: str) -> list[str]:
    """Extract fenced spawn calls while requiring one complete active statement."""
    prompts: list[str] = []
    suspicious_spawn = re.compile(r"\bspawn\b(?=\s*(?:/\*|//|\())")
    for fence_no, code in enumerate(md.fences, 1):
        starts = list(SPAWN_START.finditer(code))
        if not starts:
            if suspicious_spawn.search(code):
                raise Error(f"{label}: fence {fence_no}: malformed/comment-interposed spawn call")
            continue

        # Start with the first lexical call. balanced_call masks JSON-string
        # contents, so spawn-like words inside the prompt cannot become active
        # calls. Outside that one call, only whitespace and one trailing
        # semicolon are allowed: no comments, guards, assignments, or siblings.
        match = starts[0]
        if code[: match.start()].strip():
            raise Error(f"{label}: fence {fence_no}: spawn must be the only active statement")
        body, end = balanced_call(code, match.start(), f"{label}: fence {fence_no}")
        if re.fullmatch(r"\s*;?\s*", code[end:]) is None:
            raise Error(f"{label}: fence {fence_no}: spawn must be the only active statement")
        prompts.append(prompt_from_call(body, f"{label}: fence {fence_no} spawn 1"))
    return prompts
