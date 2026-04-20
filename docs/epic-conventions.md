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
> Story scaffolded by `/epic-story-save` from the plan above.
```

`Status:` is the file's local copy of the tracker status. It can drift
from `MASTER.md` and `/epic-squash` will reconcile.

### Spec sections (created by `/epic-story-save`)

These are the planning surfaces. They are written once at story creation
time by `/epic-story-save` from a Claude Code plan, and they are read by
every other command.

| Section | Purpose |
|---|---|
| `## Purpose` | One paragraph: what user-visible outcome this story delivers. |
| `## Triggering Need` | Why now, what prompted this story. |
| `## Expected Prerequisites` | Bulleted list of dependency story numbers and titles. |
| `## Scope` | What is in scope. |
| `## Out of Scope` | What is deliberately not in scope. |
| `## Acceptance` | Observable criteria a reviewer can verify. Every bullet uses a stable `A<n>` id and covers exactly one independently provable behavior. |
| `## Verification` | Reviewer-facing proof contract. Must always contain `### Verification Commands` and `### Acceptance Proof Matrix`, and must add `### Surface / Branch Proof Matrix` and/or `### Fail-open Checks` when the story's risk surface requires them. |
| `## Discovery Notes` | The catch-all for plan content that doesn't fit elsewhere. Code smells, gotchas, references to existing patterns, named functions/classes with explanatory context. **This is the section that prevents re-discovery.** |
| `## Critical Files` | Every file path the plan referenced, with line numbers when present. |
| `## Implementation Notes` | The plan's approach / strategy / phases preserved verbatim. |
| `## Locked Decisions` | What was decided during planning, plus the alternatives considered and rejected. |

#### `## Acceptance`

- Every acceptance bullet must start with a stable id: `A1`, `A2`, ...
- Each bullet must be atomic. If two parts could fail independently, split them.
- Every bullet must remain observable by command, file read, or direct reviewer observation.

Example:

```md
## Acceptance
- A1: `/epic-story-save` preserves the proof matrix verbatim from the plan file.
- A2: `/epic-review` rejects approval when any acceptance id has no proof row.
```

#### `## Verification`

`## Verification` is no longer a loose list of checks. It is the story's
reviewer-facing proof contract. It must always contain these core
subsections:

```md
## Verification

### Verification Commands
- <exact command or exact manual/file-read action>

### Acceptance Proof Matrix
| Acceptance ID | Proof Maturity | Proof Method | Reviewer Action | Expected Evidence | Relevant Surfaces | Open Detail |
|---|---|---|---|---|---|---|
| A1 | final | file-read | <exact reviewer action> | <exact expected evidence> | <paths / commands / surfaces> | |
| A2 | provisional | automated | <exact reviewer action> | <red/green or equivalent evidence> | <paths / commands / surfaces> | <what is still undecided> |
```

Rules:

- Every acceptance id must appear in the matrix at least once. Missing rows are
  invalid.
- A matrix row may reference multiple acceptance ids only as an exception, and
  only when the same proof action and failure signal genuinely cover all listed
  ids without reducing clarity.
- `Proof Maturity` uses only `final` or `provisional`.
- `Open Detail` may be blank for `final` rows.
- `Open Detail` is required for `provisional` rows and must state what remains
  undecided about the proof path.
- All rows may be `provisional` during planning if they are still anchored to
  the real owning surface and concrete enough to guide implementation.
- By `/epic-review`, every row must be `final`.
- Planning is proof-first, not guess-first. The plan must anchor the real
  owning surfaces and the focused test/proof area the implementer should
  inspect first, but it must not invent a fake exact first failing command when
  the repo facts do not support that level of precision.
- Implementation is red-first by default. After source inspection, the
  implementer chooses the smallest focused seam they can make fail, turns it
  green, and only then broadens verification.

Add this subsection whenever the story spans multiple user-visible surfaces,
supported variants/profiles/modes, or internal orchestration branches:

```md
### Surface / Branch Proof Matrix
| Surface | Supported Variant | Internal Execution Branch | Proof Class | Owning Proof Seam | Why This Seam Is Sufficient | Out of Scope Notes |
|---|---|---|---|---|---|---|
| <surface> | <variant / profile / mode> | <branch / callsite / orchestration path> | <helper | routing | behavior> | <test / command / file-read seam> | <why this proves the branch> | |
| <surface> | <variant / profile / mode> | <intentionally excluded branch> | behavior | <n/a or explicit proof seam> | <why exclusion is safe> | <explicit exclusion reason> |
```

Rules for `### Surface / Branch Proof Matrix`:

- Every in-scope surface / variant / internal branch combination must appear at
  least once.
- A row may mark a branch as intentionally excluded only when the exclusion is
  explicit in the story contract.
- `Proof Class` must distinguish `helper`, `routing`, and `behavior` proofs.
- Helper proof alone is insufficient when multiple supported callsites or
  orchestration branches exist. At least one `routing` proof must show that the
  supported callsites actually invoke the shared helper or branch logic.
- The matrix must be specific enough that a reviewer can tell which supported
  branches are covered, and which are intentionally out of scope, from the
  story alone.

Add this subsection whenever the feature depends on prompt placeholders,
template variables, string substitution, or other fail-open prompt assembly:

```md
### Fail-open Checks
- Supported renders leave no unresolved feature placeholders or raw tokens.
- Enabled supported paths prove the feature is active, not silently ignored.
- At least one disabled or default path proves baseline behavior stays intact.
- Any supported profile or mode that intentionally excludes the feature is
  called out explicitly.
```

### Runtime sections (created by `/epic-claim`, `/epic-resume`, `/epic-review`, `/epic-pr`)

These are written by the runtime commands as work progresses. They must
**never** be seeded by `/epic-story-save` — they are owned by the flows
that create them.

#### `## Active Claim`

Written by `/epic-claim` (creation) and `/epic-resume` (refresh). Exactly
one `Active Claim` section per file.

```md
## Active Claim
- Claimed at: <UTC ISO timestamp>
- Claimed by: <Claude or Codex> <fresh|continuation> session
- Scope: <one sentence for this work chunk>
- Worktrees:
  - <repo-basename>: </absolute/path/to/linked/worktree>
  - <repo-basename>: </absolute/path/to/linked/worktree>
- Main-tree targets: <repo-basename>, <repo-basename>
- Primary write surfaces: <paths>
```

The `- Worktrees:` parent bullet is **optional and plural**. It is
present only when the story is being implemented in one or more linked
`git worktrees` — typically because one or more target repos were dirty
at claim time, or because the operator passed
`WORKTREE="<basename>=<path>"` explicitly for that repo. Each child
bullet has the form `- <repo-basename>: <absolute path>` and records
where work for that specific repo is happening so `/epic-resume` and
`/epic-review` can reattach to the same checkouts in future sessions.

The discovery rule for which repos appear here lives in the
`## Worktree preflight` section of `/epic-claim` and `/epic-resume`: a
repo is included if it is named in the story's `## Scope` (via a
`projects/<name>/` token) AND has uncommitted changes at claim time.
Repos that are clean at claim time are written to directly and do NOT
appear in this list — their absence implies main-tree mode. When
**no** repos have worktrees (every target was clean, the story has no
target repos, or the operator declined the prompt for every dirty
repo), the entire `- Worktrees:` parent bullet must be omitted. Never
write the parent bullet with no children.

Multi-project workspaces (where `<cwd>` is not itself a git repo but
contains `projects/<name>/.git` sub-repos) are first-class: the
preflight discovers each dirty target sub-repo and creates one worktree
per repo. A story that touches two dirty sub-repos produces two child
bullets, each pointing at a different `<repo-basename>` and worktree
path. Coordination files under `agent_coordination/` always anchor at
`<cwd>` (the workspace root) regardless of any sub-repo worktrees, so
`MASTER.md` and the story file itself never live inside a worktree.

Once written, child bullets must not be deleted by subsequent runs of
`/epic-resume` or `/epic-review` — other sessions depend on them to
find the worktrees. `/epic-resume` may refresh a child bullet's path
if the recorded worktree is stale and the operator chooses to recreate
it at a new location, and may add new children if the operator passes
`WORKTREE="<basename>=<path>"` for a previously-unrecorded repo.

**Back-compat read**: stories claimed before the multi-worktree format
have a singular `- Worktree: <path>` bullet (no parent). `/epic-resume`
and `/epic-review` accept this legacy form by reading it as a single
implicit entry whose basename is `basename(<path>)`. The next
`/epic-resume` refresh on such a story rewrites the legacy bullet as a
`- Worktrees:` list — that is the one place legacy stories migrate
forward. New claims (`/epic-claim`) never write the singular form.

#### `## Progress Log`

Append-only timestamped bullets recording meaningful milestones during
implementation. Written by `/epic-claim`, `/epic-resume`, and `/epic-pr`.

```md
## Progress Log
- 2026-04-12T10:32:00Z Claimed step and started implementation.
- 2026-04-12T10:41:00Z Chose `tests/auth/test_refresh.py -k expired_token_rejected` as the focused red seam after source inspection.
- 2026-04-12T11:14:00Z Focused red seam turned green; broadening verification to the surrounding auth suite.
- 2026-04-12T11:48:00Z Patched core module and added tests.
- 2026-04-12T12:01:00Z Moved step to `🔵 IN PR` — https://github.com/.../pull/42
- 2026-04-12T12:09:00Z Refined proof matrix for `A2` after implementation moved the real assertion seam.
- 2026-04-12T12:16:00Z Recorded replanning checkpoint: original acceptance contract for `A3` bundled two independently failing behaviors and was split before implementation continued.
- 2026-04-12T12:21:00Z Recorded explicit red-first exception: fixture bootstrap cannot go red-first safely; using smoke command `uv run pytest tests/bootstrap/test_install.py` as the alternative proof path.
```

When implementation discovers contract drift:

- **Non-material proof drift**: update `## Verification` immediately and log
  what changed and why.
- **Material contract drift**: pause normal feature work, record a replanning
  checkpoint in `## Progress Log`, refresh the story contract, then continue.
- **Red-first infeasible**: record an explicit written exception in
  `## Progress Log` before proceeding. Name the reason, the alternative proof
  seam, and the verification path that will be used instead.

When local review finds a mismatch between the implementation and epic-level
commitments in `MASTER.md`, `CONTRACT.md`, dependencies, or relevant sibling
stories, record that explicitly as `Epic contract drift` in `## Review Log`.

#### `## Session Handoff`

Refreshed at the end of every session. There may be multiple handoff
entries over a story's lifetime; only the most recent one is authoritative.

```md
## Session Handoff
- Status: done | blocked | in progress | in review
- What changed: <short bullets>
- Files touched: <paths>
- Red-first path: <focused seam + red/green outcome, or explicit exception + alternative proof path>
- Tests run: <commands/results or not run>
- Remaining work: <short bullets>
- Blockers / risks: <short bullets>
- Exact next step: <one concrete recommendation>
```

#### `## Review Log`

Append-only entries written by `/epic-review`. This is the canonical
write-back schema for implementation review logs.

```md
## Review Log
- 2026-04-12T13:05:00Z Review run by fresh maintainer session
  - Decision: approve | request_changes | blocked | not_reviewable
  - Approval gate: pass | fail
  - Product verdict: approve | request_changes | reject | not_assessed
  - Technical verdict: approve | request_changes | reject | not_assessed
  - Epic contract drift: none | present
  - Status transition: 🟣 IN REVIEW -> ✅ DONE
  - Files reviewed: <paths>
  - Key findings:
    - <short bullet>
  - Next action: <one concrete recommendation>
```

#### `## Plan Review Log`

Append-only entries written **only** by `/epic-story-review`. Parallel in
shape to `## Review Log` but records plan-quality verdicts made at
`⚪ TODO`, before implementation begins. Never seeded by `/epic-story-save`;
never touched by any other command. Each re-run of `/epic-story-review`
after operator edits appends a new entry — the log is the story's plan
revision history.

```md
## Plan Review Log
- 2026-04-15T09:30:00Z Plan review run by fresh maintainer session
  - Verdict: approve | request_changes | blocked | not_reviewable
  - Status transition: ⚪ TODO -> ⚪ TODO
  - Sections reviewed: Purpose, Acceptance, Verification, Critical Files, Locked Decisions, Discovery Notes, Expected Prerequisites, Scope
  - Key findings:
    - <short bullet>
  - Next action: <one concrete recommendation — typically "/epic-claim <epic>" or "edit <sections> and re-run">
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

## Argument resolution rules

Each command in this repo has a defined resolution strategy for its
epic/story arguments. Two strategies exist:

- **Auto-inferred from running context** — for commands that continue
  running work (`/epic-claim`, `/epic-resume`, `/epic-pr`, `/epic-squash`).
  These operate on whatever is already active; guessing the context is
  the whole point.
- **Operator-explicit (arg or menu)** — for commands that *create* or
  *review* (`/epic-plan`, `/epic-story-plan`, `/epic-story-save`,
  `/epic-review`, `/epic-story-review`). These never auto-infer. The
  operator must make the decision — either by passing the arg or by
  picking from a filtered menu the skill shows when the arg is absent.
  The menu lists only legal candidates (filtered to each command's
  eligible-status set) and asks the operator to pick. Nothing is ever
  selected silently.

| Command | Resolution strategy | Eligible-status filter | Notes |
|---|---|---|---|
| `/epic-plan` | operator-explicit (optional NAME arg) | n/a — creates a new epic | If `NAME` is omitted, the interview asks for the slug. Never overwrites an existing epic. |
| `/epic-story-plan` | operator-explicit (arg or menu) | any epic with a `MASTER.md` | EPIC menu lists all epics under `agent_coordination/epics/`. Never edits `MASTER.md` or story files. |
| `/epic-story-save` | operator-explicit (arg or menu) | any epic with a `MASTER.md`; PLAN menu is 5 most recent files in `~/.claude/plans/` | Both EPIC and PLAN have menu fallbacks. Creating a story is a decision that should never be guessed. |
| `/epic-review` | operator-explicit (arg or menu) | `🟣 IN REVIEW` | Review must come from a fresh, independent perspective. The menu lists only stories at `🟣 IN REVIEW`. |
| `/epic-story-review` | operator-explicit (arg or menu) | `⚪ TODO` | Plan review must come from a fresh, independent perspective. The menu lists only stories at `⚪ TODO`. |
| `/epic-claim` | auto-inferred (running context) | `⚪ TODO` | Standard "single active epic + first ready unclaimed story" inference. |
| `/epic-resume` | auto-inferred (running context) | `🔄 IN PROGRESS`, `🔵 IN PR (changes_requested)` | Standard. |
| `/epic-pr` | auto-inferred (running context) | `🟣 IN REVIEW`, `🔵 IN PR` | Also infers PR URL via the chain: existing `## PR Tracking` section → `gh pr list --head <current branch>` → fall through to `OPEN` mode after operator confirmation. |
| `/epic-squash` | auto-inferred (running context) | `✅ DONE` | The "story" axis doesn't apply — the command consumes every done story in one pass. |

**Rules for the "auto-inferred" rows**:

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

**Rules for the "operator-explicit (arg or menu)" rows**:

1. **Arg takes priority**: if the operator passes the arg, use it
   directly (after validating it resolves to something real).
2. **Menu fallback**: if the arg is missing, the skill lists the legal
   candidates filtered by the command's eligible-status column, formats
   each row with a short summary (step / deliverable / status / last-
   touched), and asks the operator to pick by number or slug.
3. **Zero-row abort**: if the filtered menu is empty, abort fast with a
   pointer to the next concrete action (e.g. "no epics found; run
   `/epic-plan` to bootstrap one first", "no stories at ⚪ TODO; run
   `/epic-story-plan` to draft one").
4. **Never silent**: the menu never pre-selects a row the operator
   hasn't confirmed, even if there is only one eligible candidate.
   Picking is always an explicit operator action. Auto-inference for
   these commands must continue to be rejected — the menu pattern
   replaces typing friction with menu friction, it does not replace
   operator-explicit choice with silent guessing.

## What the commands will NOT do

- Rename or renumber existing stories
- Delete `Progress Log`, `Active Claim`, `Session Handoff`, `Review Log`,
  or `Plan Review Log` entries
- Touch product code from `/epic-pr` or `/epic-squash` (except optional
  per-fix approval in `/epic-squash` Phase 6, and the optional `gh pr
  create` call in `/epic-pr` open mode)
- Modify the plan file that `/epic-story-save` consumed
- Mark a story `✅ DONE` while its PR is open
- Archive a `🔵 IN PR` story
- Auto-infer arguments for any command in the "operator-explicit (arg or
  menu)" rows of the Argument resolution rules table. The menu pattern
  replaces the old "required explicit" friction but preserves the rule
  that the operator — not the skill — is the one making the choice.
- Overwrite an existing `MASTER.md` from `/epic-plan`. The epic directory
  must not already exist; collisions abort fast.
- Edit `MASTER.md` or any story file from `/epic-story-plan`. It writes
  only a plan file to `~/.claude/plans/` for `/epic-story-save` to
  consume.
- Delete or silently relocate an existing linked worktree from
  `/epic-claim`, `/epic-resume`, or `/epic-review`. The `- Worktrees:`
  list in `## Active Claim` (or the legacy singular `- Worktree:`
  bullet for back-compat) is the authoritative record of where the
  story's implementation lives. The only command that may change a
  recorded entry is `/epic-resume`, and only when the operator
  explicitly chooses to recreate a stale worktree at a new location.
  `/epic-review` may **never** create a worktree — it only reuses
  what the implementer recorded or a `WORKTREE="<basename>=<path>"`
  override. On partial worktree creation failure (one repo's worktree
  succeeds and another fails), no command auto-cleans the successful
  worktrees; the operator decides whether to keep them.
- Create a worktree branch `<epic>/<story-slug>` that already exists
  from `/epic-claim`. If the branch is present in any target repo,
  `/epic-claim` aborts fast and redirects the operator to
  `/epic-resume`.
