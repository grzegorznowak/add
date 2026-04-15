---
name: memorize
description: Persist the current sessions' knowledge
---

This skill was migrated one-to-one from the former custom prompt `memorize.md`.
Invoke it explicitly with `$memorize`.

Original argument hint: *(none)*

If the user supplies text alongside the explicit skill invocation, treat that text as additional context for the instructions below.

Make a list of areas and topics that you had problems understanding, that were time consuming, required lots of context or tool use.
Rate them 1-10 in terms of complexity/time-spent; prune low scorers.
Propose a small patch (or patches) to the AGENTS.md, stories, documentation, etc. that would make it easier for you
to navigate through the project in the next session.

Do not auto-apply the patch, confirm with the user first.
