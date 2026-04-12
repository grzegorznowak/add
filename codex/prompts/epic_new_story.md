---
description: Append a new story row to an epic's MASTER.md tracker AND create a properly-scaffolded story file from a plan, preserving all research findings (code smells, file references, decisions) so implementation does not have to re-discover them.
argument-hint: EPIC="<epic_name>" [PLAN="<path>"] [TITLE="<override>"] [DEPENDS="<list>"] [SLUG="<kebab>"]
---

New Story: $EPIC

Create a new story in `$EPIC` by mapping a plan into the epic's story-file
conventions, preserving every research finding from the plan with high fidelity.

Treat `$EPIC` as the exact directory name of an epic under the agent's current
working directory at:
`agent_coordination/epics/`

Optional named arguments:
- `$PLAN` — path to a plan file (markdown). If omitted, the in-session plan
  is used; otherwise the most recent `~/.claude/plans/*.md` (with operator
  confirmation).
- `$TITLE` — override the H1 title; default derived from plan
- `$DEPENDS` — comma-separated story refs (cross-epic OK), e.g.
  `"03,07,core 06"`
- `$SLUG` — filename slug; auto-derived from title if omitted

## Core principle

**The plan is the spec.** The story file is a high-fidelity persistence of
the plan, mapped into the epic's story-file conventions. No plan → no story.
Research already paid for during planning must never be re-discovered at
implementation time.

## Non-negotiable rules

1. **Plan is mandatory.** No plan in `~/.claude/plans/`, no in-session plan,
   AND no `$PLAN` arg → abort with: `No plan found. Pass PLAN=<path> or
   create a plan first via plan mode.`
2. **High-fidelity preservation.** Every code smell, gotcha, file path,
   function/class name, pattern reference, decision, and alternative
   recorded in the plan must appear in the story file. Verbatim where
   possible; rephrased only when section mapping requires it. **Never drop
   plan content.** When in doubt, preserve under the catch-all
   `## Discovery Notes` section.
3. **No content invention.** Do not write Acceptance criteria the plan did
   not state. If a section has no source material, leave a clearly-flagged
   `<TODO: missing from plan — ...>` placeholder so the operator can see
   what needs filling in.
4. **Plan provenance is recorded.** The story file references the source
   plan path and its mtime so future readers can audit the lineage.
5. **Never overwrite an existing story file.** If the resolved filename
   exists, abort with the path.
6. **Never silently renumber.** Story number = `max(existing tracker
   numbers, max archived numbers) + 1`. Show the operator the chosen number
   before writing.
7. **Never seed runtime sections.** No `## Active Claim`, `## Progress Log`,
   `## Session Handoff`, `## Review Log`, `## PR Tracking`. Those belong to
   the runtime flows that create them.
8. **Mirror sibling-story conventions.** Read at least one existing story
   file in the same epic and use its top-level section list as the
   template. Use the default scaffold only if the epic has no prior story
   files.
9. **The plan file is left untouched.** Do not move, rename, or delete it
   after the story is created.
10. **Checkpoint before writing.** Show the resolved filename, story number,
    plan-content coverage report, dependency validation, and the drafted
    file. The operator confirms before any file is touched.

## Phase 0 — Resolution

- Resolve `<cwd>/agent_coordination/epics/$EPIC/MASTER.md`. Abort if missing.
- Read `<epic>/MASTER.md` fully.
- Read the main repo `AGENTS.md` for the repo you will touch.

## Phase 1 — Plan resolution

1. If `$PLAN` was provided:
   - Verify the path exists and is non-empty. Abort otherwise.
   - Use it as the source plan.
2. Else if the current session has been actively working on a plan file
   (the operator and the model both have its path in context — typically a
   `/home/vscode/.claude/plans/<random-name>.md` the session has been
   writing or editing):
   - Use that one **without** doing an mtime sort.
   - Do not prompt for confirmation — the operator is explicitly asking
     this session to convert its current plan into a story.
3. Else:
   - List `~/.claude/plans/*.md`, sort by mtime descending.
   - If empty, **abort** with the no-plan error from rule #1.
   - Pick the newest. Show its path and mtime and ask the operator to
     confirm before using it (avoids accidental coupling between an
     unrelated plan and a new story).
4. Read the plan file fully.
5. Capture: source path, mtime, plan H1 title.

## Phase 2 — Convention learning

- List `<epic>/story-*.md` and `<epic>/archive/story-*.md`
- Pick the **most recent** existing story file (highest number, prefer
  non-archived)
- Read it
- Extract the **set of headings** present at the top level, excluding any
  of the runtime sections from rule #7
- This becomes the section template for the new story file
- If the epic has no prior story files, fall back to the default scaffold
  (below)

## Phase 3 — Plan parsing

Walk the plan file and classify each section by header. Use case-insensitive
fuzzy matching:

| Plan section header | Maps to story section |
|---|---|
| `Context`, `Background`, `Why`, `Problem` | `## Purpose` + `## Triggering Need` (split if both fit) |
| `Deliverable`, `Goal`, `Outcome` | `## Purpose` (merge with above if needed) |
| `Approach`, `Strategy`, `Implementation`, `Implementation Plan`, `Implementation Steps`, `Steps`, `Phases` | `## Implementation Notes` (preserved verbatim) |
| `Critical files`, `Files to modify`, `Files`, `Write surfaces` | `## Critical Files` (preserved verbatim with paths intact) |
| `Verification`, `How to verify`, `Testing`, `Test plan` | `## Verification` |
| `Out of scope`, `Non-goals` | `## Out of Scope` |
| `Acceptance`, `Acceptance criteria`, `Done when` | `## Acceptance` |
| `Decisions`, `Locked decisions`, `Architecture decisions`, `Trade-offs` | `## Locked Decisions` (preserved verbatim) |
| anything else, including bare paragraphs and bullet lists with discovered facts | `## Discovery Notes` (catch-all preservation) |

**Key rule**: any section the plan contains that doesn't have an obvious
mapping goes into `## Discovery Notes`. Never drop a section. Never
collapse a section into a one-line summary.

**Inline content extraction** (in addition to section mapping):
- Every `path/like/this.py:123` reference → preserved in `## Critical Files`
  even if the plan didn't have a dedicated section
- Every `function_name()` / `ClassName` / `CONSTANT_NAME` mention with
  explanatory context → preserved in `## Discovery Notes` under "Existing
  code to reuse"
- Every "code smell" / "gotcha" / "be careful" / "watch out" / "footgun" /
  "trap" phrase + its surrounding sentence → preserved in
  `## Discovery Notes` under "Gotchas and code smells"
- Every "we considered X but chose Y" or "alternative" → preserved in
  `## Locked Decisions` under "Alternatives considered"

## Phase 4 — Number, slug, and dependency validation

- Determine `next_n` = max(active tracker numbers, archived numbers) + 1
- If `$SLUG` not provided, derive from `$TITLE` (or from the plan H1 if
  `$TITLE` not provided): lowercase, alphanumeric-only, hyphen-separated,
  capped at ~50 chars
- Resolve filename: `story-<NN>-<slug>.md`, zero-padded to match the epic's
  existing zero-padding convention (default 2 digits)
- If the filename already exists in either the root or `archive/`, **abort**
  with the conflict path

For each entry in `$DEPENDS`:
- **Same-epic ref** (no space, e.g. `03`, `07`): look it up in the
  MASTER.md tracker. If missing, **abort**. If found but not `✅ DONE`,
  soft-warn (TODO can legitimately depend on TODO).
- **Cross-epic ref** (contains a space, e.g. `core 06`): pass through, flag
  as unverified.

Build the validation report.

## Phase 5 — Story draft

Build the story file. Required header:

```md
# Story <NN> — <TITLE>

Status: `todo`

> **Plan source**: `<plan path>` (mtime `<plan mtime ISO>`)
> Story scaffolded by `epic_new_story` from the plan above. Do not lose the discovery
> notes recorded here — they exist so implementation does not have to re-research what
> the plan already established.
```

Then the sections inferred from Phase 2's convention learning, populated
from Phase 3's plan parsing.

**Always include these four sections** even if convention-learning didn't
pick them up — they are the high-fidelity preservation surface and must
always appear in plan-sourced stories:
- `## Discovery Notes`
- `## Critical Files`
- `## Implementation Notes`
- `## Locked Decisions`

If the plan had no content for one of these sections, write
`<TODO: missing from plan — ...>` rather than omitting the section.

## Phase 6 — Checkpoint

Show the operator:
- Plan source path + mtime
- Resolved filename and story number (with the basis: "next after archive
  38, active 0")
- Section list — mark which were inherited from the sibling story and which
  are mandatory plan-preservation sections
- **Plan-content coverage report**:
  - which plan sections were mapped to which story sections
  - which plan sections went to `## Discovery Notes` (catch-all)
  - any `<TODO: missing from plan — ...>` placeholders that were inserted
- Dependency validation report (validated / soft-warned / cross-epic
  unverified)
- The drafted story file content

**CHECKPOINT**: confirm before writing. This is the only checkpoint — keep
the flow lightweight relative to `epic_squash`.

## Phase 7 — Apply

- Write the new story file
- Edit `MASTER.md` to append a new row to the story tracker:
  ```md
  | <NN> | ⚪ TODO | <TITLE> | <DEPENDS or "none"> | `story-<NN>-<slug>.md` |
  ```
- Match the existing column count and alignment of the table. Read the
  table header to determine which columns the epic uses (some have 4, some
  have 5).
- The plan file is left untouched per rule #9.

## Phase 8 — Final response

State:
- filename created
- story number assigned
- plan source path recorded
- sibling-convention source (which existing story it learned from)
- plan-content coverage summary (X sections mapped, Y catch-alled, Z TODO
  placeholders)
- dependency report
- suggested next action: usually `epic_claim` once the operator is ready to
  start work

## Default scaffold (used only when the epic has no prior story files)

```md
# Story <NN> — <TITLE>

Status: `todo`

> **Plan source**: `<plan path>` (mtime `<plan mtime ISO>`)
> Story scaffolded by `epic_new_story` from the plan above. Do not lose the discovery
> notes recorded here — they exist so implementation does not have to re-research what
> the plan already established.

## Purpose
<one paragraph: what user-visible outcome this story delivers>

## Triggering Need
<one paragraph: why now, what prompted this story>

## Expected Prerequisites
<bulleted list of dependency story numbers and their titles>

## Scope
<bulleted list of what is in scope>

## Out of Scope
<bulleted list of what is deliberately not in scope>

## Acceptance
<observable criteria a reviewer can verify>

## Verification
<test commands or manual checks a reviewer can run>

## Discovery Notes
<all research findings preserved verbatim from the plan — do not paraphrase away>

## Critical Files
<every file path the plan referenced, with line numbers when present>

## Implementation Notes
<the plan's approach / strategy / phases preserved verbatim>

## Locked Decisions
<decisions made during planning, plus alternatives considered and rejected>
```

## Mandatory section explanations

**`## Discovery Notes`** — the catch-all for plan content that doesn't fit
elsewhere. Preserves prose, gotchas, code smells, references to existing
patterns, named functions/classes with explanatory context. This is the
section that prevents re-discovery. Creation-time only from this flow, but
`epic_resume` may append new findings as implementation discovers them.

**`## Critical Files`** — every file path the plan named, with line numbers
when present. Bullet list, no editorialization. The implementation flow
(`epic_claim`) reads this first so it knows what surfaces to touch.

**`## Implementation Notes`** — the plan's "approach" / "strategy" /
"phases" preserved verbatim. Not a checklist for the implementer to tick
off — that's `## Acceptance`'s job — but a record of the design that
emerged from research.

**`## Locked Decisions`** — what was decided during planning, *and* the
alternatives considered. Both halves matter: a future implementer who
doesn't know why X was chosen will eventually re-litigate it.

## Edge cases

| Case | Handling |
|---|---|
| Epic has no MASTER.md | Abort. Suggest the future epic-creation flow instead. |
| MASTER.md has no tracker table | Abort with a clear "tracker section missing" error. Don't try to invent a table. |
| Tracker uses 4 columns vs 5 | Read the header row. Match the existing column count exactly. |
| Zero-padding mismatch (epic uses 2-digit, operator passes `100`) | Honor the higher digit count; warn the operator. |
| `$TITLE` contains markdown table delimiters (`\|`) | Escape them in the tracker row. |
| Sibling story has runtime sections (Active Claim, Progress Log, etc.) | Strip them from the inferred template — never seed runtime sections per rule #7. |
| `$DEPENDS` lists a story that's currently `🔵 IN PR` | Soft-warn: "depends on a story not yet merged; consider waiting." |
| Plan file exists but contains only an H1 and no sections | Abort. "Plan is too thin to source a story from." |
| Plan has sections that map to the same story section (e.g. two `Context` blocks) | Concatenate them in order, separated by `---`. Never drop. |
| Plan has no `Acceptance`-shaped section | Insert `<TODO: missing from plan — add observable acceptance criteria>` placeholder. Flag in the coverage report. |
| Plan references files that don't exist in the codebase | Preserve in `## Critical Files` anyway with a `(not found in codebase as of <date>)` note. The plan saw something we should look at. |
| Plan has multiple H1s (composite plan) | Abort. "Plan has multiple top-level titles. Pass a single-story plan or split first." |
| Multiple plans have the same mtime (Phase 1 branch 3) | Sort by filename descending and pick the first. Surface the ambiguity in the confirmation prompt. |

## Out of scope

- Generating the plan itself — that's plan mode's job
- Multi-story plans — one plan = one story (split a big plan manually first)
- Touching the plan file after creation
- Auto-archiving or reorganizing existing stories
