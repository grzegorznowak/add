# Epic / Story File Conventions

Every command in this repo reads and writes a small set of well-defined
files inside an epic directory. This document is the schema. Stick to it
and the commands will work; deviate and they will misread your epic.

## Directory layout

```
agent_coordination/epics/<epic-name>/
├── MASTER.md             # tracker + status source of truth (required)
├── CONTRACT.md           # merged authoritative contract (created by /epic-squash, optional until first squash)
├── story-NN-<slug>.md    # one file per active story (the working surface)
├── archive/              # archived stories (created by /epic-squash if missing)
│   └── story-NN-<slug>.md
└── (anything else, untouched by these commands)
```

## `MASTER.md`

The tracker file. The commands treat this as the single lookup table for
which stories exist, what their statuses are, and where their spec files
live. There is exactly one `MASTER.md` per epic.

### Required sections

1. **Header** — at minimum the epic title.
2. **Goal / Context** — free-form prose describing why the epic exists. Not
   parsed by any command.
3. **Legend** — the status values used by the tracker (see
   [`epic-lifecycle.md`](epic-lifecycle.md) for the canonical legend).
4. **Story tracker** — a Markdown table. This is the only section the
   commands actually parse for status changes.

### Story tracker table

The minimum required columns are `Step | Status | Spec`. Most epics also
include `Deliverable` and `Depends`. The commands match against the header
row exactly, so any column count is fine as long as the column names are
preserved.

```md
## Story tracker

| Step | Status | Deliverable | Depends | Spec |
|-----:|--------|------------|---------|------|
| 01 | ✅ DONE | First public package release | none | `archive/story-01-public-package-contract.md` |
| 02 | ✅ DONE | TestPyPI/PyPI publishing workflow | `01` | `archive/story-02-pypi-trusted-publishing.md` |
| 16 | ⚪ TODO | Repo-owned multi-agent release command | `05`, `15` | `story-16-repo-owned-release-command-and-changelog.md` |
```

Rules:
- The `Step` value (e.g. `01`, `16`) is the canonical story identifier. Use
  zero-padded integers consistent with the rest of the epic.
- The `Spec` cell links to the story file. While the story is active, the
  link points at the epic root (`story-NN-<slug>.md`). After
  `/epic-squash`, it points into `archive/`.
- The `Status` cell uses one of the values from the Legend, exactly. The
  commands match on the leading emoji.
- The `Depends` cell is comma-separated story numbers. Cross-epic
  dependencies use `<epic> <number>` (e.g. `core 06`).

## Story files (`story-NN-<slug>.md`)

One file per story. The commands read and append specific named sections.
The list below is the union of every section any command in this repo will
read or write.

### Header

```md
# Story <NN> — <Title>

Status: `todo`

> **Plan source**: `<plan path>` (mtime `<plan mtime ISO>`)
> Story scaffolded by `/epic-new-story` from the plan above.
```

`Status:` is the file's local copy of the tracker status. It can drift
from `MASTER.md` and `/epic-squash` will reconcile.

### Spec sections (created by `/epic-new-story`)

These are the planning surfaces. They are written once at story creation
time by `/epic-new-story` from a Claude Code plan, and they are read by
every other command.

| Section | Purpose |
|---|---|
| `## Purpose` | One paragraph: what user-visible outcome this story delivers. |
| `## Triggering Need` | Why now, what prompted this story. |
| `## Expected Prerequisites` | Bulleted list of dependency story numbers and titles. |
| `## Scope` | What is in scope. |
| `## Out of Scope` | What is deliberately not in scope. |
| `## Acceptance` | Observable criteria a reviewer can verify. |
| `## Verification` | Test commands or manual checks a reviewer can run. |
| `## Discovery Notes` | The catch-all for plan content that doesn't fit elsewhere. Code smells, gotchas, references to existing patterns, named functions/classes with explanatory context. **This is the section that prevents re-discovery.** |
| `## Critical Files` | Every file path the plan referenced, with line numbers when present. |
| `## Implementation Notes` | The plan's approach / strategy / phases preserved verbatim. |
| `## Locked Decisions` | What was decided during planning, plus the alternatives considered and rejected. |

### Runtime sections (created by `/epic-claim`, `/epic-resume`, `/epic-review`, `/epic-pr`)

These are written by the runtime commands as work progresses. They must
**never** be seeded by `/epic-new-story` — they are owned by the flows
that create them.

#### `## Active Claim`

Written by `/epic-claim` (creation) and `/epic-resume` (refresh). Exactly
one `Active Claim` section per file.

```md
## Active Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: <Claude or Codex> <fresh|continuation> session
- Scope: <one sentence for this work chunk>
- Primary write surfaces: <paths>
```

#### `## Progress Log`

Append-only timestamped bullets recording meaningful milestones during
implementation. Written by `/epic-claim`, `/epic-resume`, and `/epic-pr`.

```md
## Progress Log
- 2026-04-12T10:32:00Z Claimed step and started implementation.
- 2026-04-12T11:14:00Z Locked design choice on retry behavior.
- 2026-04-12T11:48:00Z Patched core module and added tests.
- 2026-04-12T12:01:00Z Moved step to `🔵 IN PR` — https://github.com/.../pull/42
```

#### `## Session Handoff`

Refreshed at the end of every session. There may be multiple handoff
entries over a story's lifetime; only the most recent one is authoritative.

```md
## Session Handoff
- Status: done | blocked | in progress | in review
- What changed: <short bullets>
- Files touched: <paths>
- Tests run: <commands/results or not run>
- Remaining work: <short bullets>
- Blockers / risks: <short bullets>
- Exact next step: <one concrete recommendation>
```

#### `## Review Log`

Append-only entries written by `/epic-review`.

```md
## Review Log
- 2026-04-12T13:05:00Z Review run by Claude fresh session
  - Verdict: approve | request_changes | blocked | not_reviewable
  - Status transition: 🟣 IN REVIEW -> ✅ DONE
  - Files reviewed: <paths>
  - Key findings:
    - <short bullet>
  - Next action: <one concrete recommendation>
```

#### `## PR Tracking`

Written by `/epic-pr` only. There is exactly one `PR Tracking` section per
file; refreshing the metadata updates the existing section in place.

```md
## PR Tracking
- PR URL: https://github.com/<org>/<repo>/pull/<n>
- Number: <n>
- Title: <pr title>
- Branch: <head ref>
- Opened at: 2026-04-12T12:01:00Z
- PR status: open | changes_requested | approved | merged | closed
- Merge commit: <sha or "—">
- Last synced: 2026-04-12T13:42:00Z
```

## `CONTRACT.md`

The merged, authoritative contract for the epic. Created and maintained by
`/epic-squash`. When `CONTRACT.md` and a story disagree, `CONTRACT.md`
wins (it has been verified against the codebase). When `CONTRACT.md` and
the codebase disagree, the **codebase** wins — the contract is wrong and
`/epic-squash` should be re-run to fix it.

### Required sections

1. **Header** — epic title, story count, consolidation date.
2. **Domain sections** — one section per coherent product domain (e.g.
   "Configuration Surface", "Runtime Architecture", "Lifecycle"). Grouped
   by domain, not by story number.
3. **Appendix A: Resolved Contradictions** — append-only entries recording
   contradictions resolved during a squash.
4. **Appendix B: Resolved Gaps** — append-only entries recording gaps
   resolved during a squash.
5. **Appendix C: Discrepancies Resolved During Consolidation** —
   append-only entries recording code-level discrepancies found and
   (optionally) fixed during a squash.

`/epic-squash` never renumbers existing appendix entries; it only appends.

## `archive/`

Created by `/epic-squash` on first use (bootstrap mode). Contains the
original story files of every story that has been folded into
`CONTRACT.md`. The `MASTER.md` tracker links for those rows are updated
to point into `archive/` so the trail back to the original story prose is
preserved.

## Argument inference rules

Each command in this repo has a defined position on whether it auto-detects
the active epic and story when invoked without explicit args. This is the
canonical reference. Future commands declare their position in the same
table.

| Command | Auto-detects epic? | Auto-detects story? | Eligible-status filter | Notes |
|---|---|---|---|---|
| `/epic-claim` | yes (single active) | yes (first ready unclaimed) | `⚪ TODO` | Standard "single-context" inference. |
| `/epic-resume` | yes (single active) | yes (single in-progress, or in-pr `changes_requested`) | `🔄 IN PROGRESS`, `🔵 IN PR (changes_requested)` | Standard. |
| `/epic-review` | **no — explicit by design** | **no — explicit by design** | n/a | Required args are intentional friction. They force a context-switch into a fresh reviewer session, which is the entire point of separating implementer from reviewer. Do not "fix". |
| `/epic-pr` | yes (single active) | yes (single eligible) | `🟣 IN REVIEW`, `🔵 IN PR` | Also infers PR URL via the chain: existing `## PR Tracking` section → `gh pr list --head <current branch>` → fall through to `OPEN` mode after operator confirmation. |
| `/epic-squash` | yes (single active) | n/a (operates on every `✅ DONE` row) | `✅ DONE` | The "story" axis doesn't apply — the command consumes every done story in one pass. |
| `/epic-new-story` | no — explicit by design | n/a (creates) | n/a | Creating a new story should never be guessed. The operator must name the epic explicitly. |

**Inference rules for the "yes" rows**:

1. **Active epic**: an epic is active if its `MASTER.md` tracker has at
   least one row whose status is not `✅ DONE` and whose `Spec` link does
   not point into `archive/`. Exactly one active epic → infer it. Zero
   or many → abort with a specific message.
2. **Eligible story**: only rows whose status is in the per-command
   eligible-status filter qualify. Exactly one eligible row → infer it.
   Zero or many → abort with a specific message that names the next
   concrete action (e.g. "story X is in progress; run `/epic-review` first").
3. **Explicit args always win**: passing `EPIC=...` / `STORY=...` (Codex)
   or the equivalent positional args (Claude) skips the corresponding
   inference pass entirely. Inference can never override explicit values.
4. **Inference summary**: every command that runs inference must print a
   single resolved-context block before any destructive step, so the
   operator can verify what was inferred.

The "no — explicit by design" rows are **load-bearing**: they document
deliberate friction, not bugs to fix later. Any future PR that adds
inference to those commands must be rejected.

## What the commands will NOT do

- Rename or renumber existing stories
- Delete `Progress Log`, `Active Claim`, `Session Handoff`, or `Review Log`
  entries
- Touch product code from `/epic-pr` or `/epic-squash` (except optional
  per-fix approval in `/epic-squash` Phase 6, and the optional `gh pr
  create` call in `/epic-pr` open mode)
- Modify the plan file that `/epic-new-story` consumed
- Mark a story `✅ DONE` while its PR is open
- Archive a `🔵 IN PR` story
- Auto-infer arguments for `/epic-review` or `/epic-new-story` (see the
  "Argument inference rules" table above for the deliberate exceptions)
