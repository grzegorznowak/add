---
name: epic_story_review
description: Review a ⚪ TODO story's plan before implementation.
legacy-argument-hint: '[EPIC="<epic_name>"] [STORY="<story_number_or_spec_file>"]'
---

This skill was migrated one-to-one from the former custom prompt `epic_story_review.md`.
Invoke it explicitly with `$epic_story_review`.

Original argument hint: `[EPIC="<epic_name>"] [STORY="<story_number_or_spec_file>"]`

If the user supplies text alongside the explicit skill invocation, treat that text as additional context for the instructions below.

Plan review: $EPIC / $STORY

Treat `$EPIC` as the exact epic directory name under the agent's current
working directory at:
`agent_coordination/epics/`

Treat `$STORY` as the story selector. It may be either:
- the exact story number from the `Step` column in `<epic>/MASTER.md`, for
  example `03`
- the exact spec file name from the `Spec` column in `<epic>/MASTER.md`, for
  example `story-03-bootstrap-and-docs-rewrite.md`

You are a maintainer reviewing one `⚪ TODO` story's **plan** — its Purpose,
Acceptance, Verification, Critical Files, Locked Decisions, and surrounding
spec sections — against the live repository, before any implementation has
started.

This prompt is intended to work well from a fresh session. It can also be
run multiple times on the same story after the operator edits the spec
sections in response to a `request_changes` verdict.

## Important

This command only edits the resolved story file's `## Plan Review Log`
section. On a `blocked` verdict it additionally edits the `Status:` header
line of the story file and the matched `MASTER.md` tracker row. It **never**
touches:

- source code (product files, tests, configs)
- the files listed in the story's `## Critical Files`
- any spec section of the story file (`## Purpose`, `## Triggering Need`,
  `## Expected Prerequisites`, `## Scope`, `## Out of Scope`,
  `## Acceptance`, `## Verification`, `## Discovery Notes`,
  `## Critical Files`, `## Implementation Notes`, `## Locked Decisions`)
- any other runtime section (`## Active Claim`, `## Progress Log`,
  `## Session Handoff`, `## Review Log`, `## PR Tracking`)

If the plan is wrong, say so in the log's `Key findings` and recommend the
operator edit the spec sections themselves. Do not rewrite the plan inside
the log.

## Why this command requires explicit args

`epic_story_review` deliberately requires both `EPIC` and `STORY` to be
passed explicitly. Like `epic_review`, plan review must come from a fresh,
independent perspective. The same session that just wrote the plan will
rationalize it, not scrutinize it — it will read every section as evidence
for the conclusions it already reached during planning.

The arg requirement is a **forcing function**: if you find yourself typing
the epic and story numbers manually, you have just been nudged to consider
opening a fresh session for the review. **Do that.** Auto-inference here
would defeat the entire purpose of separating planner from plan reviewer.

Operators who insist on running plan review from the planning session can
still do so — the args make it possible — but the friction is intentional
and any future change that adds inference here must be rejected.

## Resolution

1. Resolve the epic directory as:
   - `<cwd>/agent_coordination/epics/$EPIC`
2. If `$STORY` is empty, abort fast and ask for `STORY` as either a `Step`
   value or a `Spec` value from `<epic>/MASTER.md`
3. Use `<epic>/MASTER.md` as the only lookup table
4. First try to match exactly one row whose `Step` value equals `$STORY`
5. If no row matches by `Step`, try to match exactly one row whose `Spec`
   value equals `$STORY`
6. If neither lookup finds a row, abort fast and report the unresolved
   selector plus the available `Step` and `Spec` values from `MASTER.md`
7. If the `Step` lookup and `Spec` lookup both match but point to different
   rows, abort fast and report the ambiguity
8. Resolve the story file as:
   - `<epic>/<matched row Spec value>`
9. If that path does not exist, abort fast and report the exact missing
   path.

## Read first

1. the main repo `AGENTS.md` for the repo the plan will touch
2. `<epic>/MASTER.md`
3. the resolved story file
4. dependency story files listed for the resolved row in `MASTER.md` and in
   the story's `## Expected Prerequisites`

## Plan readiness check

Before doing the full plan review, abort fast with a concise reason if any
of these hold:

- the story's status in `MASTER.md` (or its `Status:` header line) is not
  `⚪ TODO` — say "this story is past plan review; use `epic_review`
  instead"
- the story file has no `> **Plan source**:` header line — say "story was
  not scaffolded by `epic_new_story`; plan review assumes that shape"
- the story file is missing `## Purpose` or `## Acceptance` — say which
  section is missing
- any runtime section already exists on the story file (`## Active Claim`,
  `## Progress Log`, `## Session Handoff`, `## Review Log`,
  `## PR Tracking`) — say "story has already been claimed or reviewed;
  plan review runs before implementation begins"

## Source-of-truth hierarchy

1. the main repo `AGENTS.md`
2. `<epic>/MASTER.md`
3. the resolved story file
4. dependency story files
5. actual code referenced by the story's `## Critical Files` (read-only
   probes only)

Do not infer identity from filename shape or naming conventions that are not
explicitly recorded in `MASTER.md`.

## Plan review process

1. Read every spec section of the story file. Treat each one as a claim
   that must hold against the live repo.
2. Use code search and direct reading to probe the repository — confirm
   `## Critical Files` paths resolve, confirm the domain the plan covers
   does not already have reusable implementations the plan missed, confirm
   `## Locked Decisions` do not contradict `AGENTS.md` or established
   patterns.
3. Use `git status` to confirm the worktree is not mid-implementation (if
   there are large pending changes, note it — plan review on a dirty
   worktree is a warning signal).
4. Use `git log` to skim recent history for related work the plan should
   have referenced but did not.
5. Never speculate about code you haven't read. If a claim in the plan can
   be checked, check it.
6. If the plan looks structurally wrong, verdict is `request_changes` with
   a pointer to which sections to edit. Do not rewrite the plan inside the
   log.
7. Walk the full validation checklist below before settling on a verdict.

## Critical checks

Before approving, verify every item:

1. **`Purpose` is concrete and user-visible.** Fails on vague phrasing
   ("improve X", "refactor Y") with no observable outcome.
2. **`Triggering Need` is real.** Fails if tautological ("because we need
   it") or missing a concrete pain link.
3. **`Expected Prerequisites` match `MASTER.md`.** For every dependency
   story number listed: the row exists; its status is `✅ DONE` or
   realistically close; cross-epic deps are flagged but not failed.
4. **`Scope` is atomic.** Fails if the scope reads like multiple independent
   stories.
5. **`Out of Scope` is non-empty and meaningful.** A missing `## Out of
   Scope` is a warning, not a failure.
6. **`Acceptance` criteria are observable.** Each bullet must be checkable
   by a command, a file read, or a UI observation. Fails on "works
   correctly" / "is clean" / "is performant" with no measurable threshold.
7. **`Verification` has real commands.** Fails if it says "run the tests"
   with no command, or names a test file that doesn't exist.
8. **`Critical Files` exist.** Resolve every path. Missing or renamed files
   are plan-staleness signals.
9. **`Critical Files` are the right surfaces.** Grep the plan's domain
   keywords; if obvious owners of that domain are missing from the list,
   flag it.
10. **`Discovery Notes` mentions reusable existing code.** Search the repo
    for 2–3 domain terms from the plan and cross-reference against
    `## Discovery Notes`. If the plan invents something that clearly exists
    already, that is a `request_changes` finding.
11. **`Locked Decisions` don't contradict `AGENTS.md` or established
    patterns.** Read `AGENTS.md` and spot-check each decision.
12. **No hidden gotchas in `Critical Files`.** Skim each Critical File for
    things the plan didn't mention but should have: migrations, public
    APIs, existing tests that would break, cross-module coupling.
13. **`Implementation Notes` are internally consistent** with `## Acceptance`
    and `## Scope` (the plan's own self-consistency).
14. **No `<TODO: missing from plan — ...>` placeholders** left by
    `epic_new_story`. If any remain, verdict is at minimum `request_changes`.

## Status transitions

You may update `MASTER.md` and the story file's `Status:` header as part of
this review, but only within a narrow policy:

- `approve` → leave status at `⚪ TODO`. Tell the operator the next action
  is `epic_claim $EPIC` from a fresh session.
- `request_changes` → leave status at `⚪ TODO`. Tell the operator to edit
  the specific spec sections you named in the findings and re-run
  `epic_story_review` from a fresh session. For a ground-up rewrite,
  recommend deleting the story file and re-running `epic_new_story`.
- `blocked` → move to `⛔ BLOCKED` in both `MASTER.md` and the story file's
  `Status:` header. Use this only when the plan is unsalvageable as written
  and the operator needs to pause on this story (e.g., the plan depends on
  an upstream story that does not exist, or a `## Locked Decision` directly
  contradicts the architecture and the plan cannot be minimally amended).
- `not_reviewable` → leave status at `⚪ TODO`. Say what context is missing
  (e.g., `AGENTS.md` unreadable, dependency story files missing) and
  recommend how to unblock.

**Explicit prohibitions:** never move a story into `🔄 IN PROGRESS`,
`🟣 IN REVIEW`, `🔵 IN PR`, or `✅ DONE` from this command. Those transitions
are owned by `epic_claim`, `epic_resume`, `epic_review`, and `epic_pr`.

## Plan review log write-back

Append or create a `## Plan Review Log` section on the story file with a new
entry:

```md
- <UTC ISO timestamp> Plan review run by Codex fresh session
  - Verdict: approve | request_changes | blocked | not_reviewable
  - Status transition: <from> -> <to>
  - Sections reviewed: Purpose, Acceptance, Verification, Critical Files, Locked Decisions, Discovery Notes, Expected Prerequisites, Scope
  - Key findings:
    - <short bullet>
    - <short bullet>
  - Next action: <one concrete recommendation>
```

If a `Plan Review Log` section does not exist on the story file, create it
at the end of the file. Never delete or rewrite previous entries — the log
is append-only and records the plan's revision history across re-runs.

## Output format

Start with findings, ordered by severity, with section references.

Use:

```markdown
**Decision**: [APPROVE | REQUEST CHANGES | BLOCKED | NOT REVIEWABLE]
**Reviewed Story**: [Step <resolved_step_number> / <resolved_spec_file>]
**Plan coverage**: [sections present / missing / thin]

**Findings**
- [Severity] [section] issue

**Summary**
- [2–4 short bullets]

**Status Transition**
- [⚪ TODO -> ⚪ TODO | ⚪ TODO -> ⛔ BLOCKED]

**Next Action**
- [single concrete next step, e.g. "epic_claim $EPIC" or "edit <sections> in <story file> and re-run epic_story_review from a fresh session"]
```

If there are no findings, say that explicitly.
