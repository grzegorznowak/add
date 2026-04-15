---
name: epic_squash
description: Squash non-archived DONE stories of an epic into its merged CONTRACT.md, verifying every claim against the codebase, detecting/fixing discrepancies, and archiving the stories.
legacy-argument-hint: '[EPIC="<epic_name>"]'
---

This skill was migrated one-to-one from the former custom prompt `epic_squash.md`.
Invoke it explicitly with `$epic_squash`.

Original argument hint: `[EPIC="<epic_name>"]`

If the user supplies text alongside the explicit skill invocation, treat that text as additional context for the instructions below.

Squash: $EPIC

Treat `$EPIC` as the exact directory name of an epic under the agent's current
working directory at:
`agent_coordination/epics/`

Your job is to fold every non-archived `✅ DONE` story of that epic into its
merged `CONTRACT.md`, verify every claim in those stories against the
codebase, detect and optionally fix discrepancies, and then move the squashed
stories into `archive/`.

Do **not** touch stories that are not `✅ DONE`.
Do **not** rewrite or renumber existing appendix entries in `CONTRACT.md`.
Do **not** auto-fix product code without explicit per-fix approval.

## Non-negotiable rules

1. **The codebase is the source of truth.** Always. Story text and CONTRACT.md
   text lose to the code when they disagree. If a story's claim doesn't match
   the code, the story is wrong — OR the code has regressed; flag both.
2. **Never skip verification.** Even for stories marked `done`, verify every
   concrete claim against the code before folding anything.
3. **Never auto-fix product code.** Code-level fixes require explicit per-fix
   approval at the Phase 6 checkpoint. Contract edits and code edits live on
   different blast-radius tiers.
4. **Never archive on failing tests.** If Phase 6 runs tests and any fail, stop
   before Phase 7.
5. **Preserve appendix history.** Add new Appendix A / B / C entries; never
   renumber or delete existing ones.
6. **Use the minimum number of subagents.** One well-structured exploration
   pass beats three ad-hoc ones.
7. **Checkpoint before irreversible or high-blast-radius actions.** The phases
   below mark each explicit checkpoint — do not skip them.

## Phase 0 — Sanity check and bootstrap

1. Resolve the epic directory as:
   - `<cwd>/agent_coordination/epics/$EPIC`
2. If `$EPIC` was not provided and there is exactly one active epic directory
   under `agent_coordination/epics/`, use that one; otherwise stop and ask.
3. If the resolved directory does not exist, stop and report the exact missing
   path.
4. Verify the epic has `MASTER.md`. **This is the only hard requirement.**
   Abort if missing.
5. Read the main repo `AGENTS.md` for the repo you will touch, then read
   `<epic>/MASTER.md` fully.

After reading `MASTER.md`, determine the run mode based on what else is
present in the epic directory:

**Mode A — normal squash** (default): both `CONTRACT.md` and `archive/`
exist. Proceed with the phases below as written.

**Mode B — bootstrap squash**: `CONTRACT.md` is missing, or `archive/` is
missing, or both. This is a valid "first squash" of the epic. Do NOT abort.
Instead:
- If `archive/` is missing, note that Phase 7 will create it before moving
  story files.
- If `CONTRACT.md` is missing, note that Phase 4 will draft a fresh contract
  from scratch using the in-scope stories as input, and Phase 5 will create
  it instead of patching it.
- Report which artifacts will be bootstrapped at the start of Phase 1 so the
  operator knows this is the first consolidation.
- In bootstrap mode there is no pre-existing CONTRACT.md to detect
  contradictions against. Phase 3's "Contract discrepancies" list will be
  empty by definition. Story and code-level discrepancies are still in
  scope.

Track the mode as a state variable and reference it in each phase's
decisions.

## Phase 1 — Identify in-scope stories

From the `<epic>/MASTER.md` tracker, select stories where:
- Status is `✅ DONE` (or the epic's equivalent), AND
- The `Spec` column link points to the epic root, not to `archive/`.

**Explicitly exclude** stories with any non-`DONE` status:
- `⬜ TODO`, `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `⛔ BLOCKED` — not finished
- `🔵 IN PR` — local review passed but GitHub PR is not merged. The code may
  still change before merge, so folding these into `CONTRACT.md` is unsafe.
  Report them separately in the "skipped" list and tell the operator to rerun
  `epic_squash` after the PR is merged and the story moves to `✅ DONE`.

Also flag (but still include) stories where the story file header status
disagrees with the tracker (e.g. `in review` in file vs `DONE` in tracker).
That drift is a known failure mode and must be fixed as part of the squash.

Print the in-scope list (story number, title, spec path, status-drift flag if
any).

**CHECKPOINT 1**: confirm the list with the user before proceeding.

## Phase 2 — Parallel reads + single codebase-verification pass

Read in parallel:
1. Current `<epic>/CONTRACT.md` (**skip in bootstrap mode — the file does
   not exist**)
2. Every in-scope story file

Then do **one** structured codebase-verification pass against the primary
source repo. Build a checklist of every concrete claim in the in-scope stories
and verify each one against real code:
- Function / class / method names the stories mention
- Constants, env vars, config keys
- Default values (especially when a story says "changed X from A to B")
- Lifecycle wiring claims (where something is called from)
- Test fixture paths
- **Stale-compat path checks**: for each changed default, grep for the OLD
  value across the codebase and report every hit

Return a match / no-match report with `file:line` evidence for each item.

## Phase 3 — Classify changes and detect discrepancies

For each in-scope story, categorize contract impact as one of:
- **no-op** — internal cleanup / refactor only; no contract change needed.
  Skip in squash.
- **additive** — introduces new contract terms (new section or subsection).
- **modifying** — changes the meaning of existing contract terms (find the
  section to edit).
- **removing** — deletes or deprecates existing contract terms.

Build three discrepancy lists:
- **Contract discrepancies**: CONTRACT.md text that contradicts the codebase
  (obsolete config keys, stale routing rules, old field tables). These MUST be
  fixed during the squash.
- **Story discrepancies**: claims in stories that don't match the codebase.
  Codebase wins; update the squashed contract to match the code, and report
  the story drift.
- **Code-level discrepancies**: stale defaults in legacy compat paths, dead
  code left over from removed approaches, file-vs-tracker status drift. These
  are candidates for Phase 6.

Present all three lists plus the per-story classification.

**CHECKPOINT 2**: confirm classification and discrepancy lists before editing
anything.

## Phase 4 — Draft contract edits

**Normal mode**: Produce a section-by-section edit list for
`<epic>/CONTRACT.md`:
- Header (story count + consolidation date)
- Each affected section (edit / add / remove with the exact target text)
- New Appendix A entries for resolved contradictions
- New Appendix B entries for resolved gaps
- New Appendix C entries for known or fixed code-level discrepancies

**Bootstrap mode**: Draft the **entire** `CONTRACT.md` from scratch. Use
this scaffold:

```md
# <Epic Title> — Merged Contract

Consolidated from <N> completed stories in the `<epic-name>` epic.
Organized by domain. Individual story files remain available for historical context in `archive/`.

Consolidated: <YYYY-MM-DD>

---

## 1. <Domain 1>
...

## 2. <Domain 2>
...

(Sections derived from the in-scope stories, grouped by coherent product domain — not by story number)

---

## Appendix A: Resolved Contradictions

(Empty on first consolidation unless stories contradict each other or the code. Add entries only when a contradiction was actually resolved.)

## Appendix B: Resolved Gaps

(Empty on first consolidation unless a gap was explicitly resolved.)

## Appendix C: Discrepancies Resolved During Consolidation

(Code-level items found and fixed during this squash. Empty if none.)
```

Domain grouping rules for the bootstrap scaffold:
- Group stories by coherent product domain (e.g. "Configuration Surface",
  "Runtime Architecture", "Observability", "Lifecycle", "Migration &
  Compatibility"), not by story number
- Each section should be scannable in under 30 seconds
- Lead each section with a one-line summary of the domain
- Prefer tables for structured contract surfaces (config keys, env vars,
  file paths, field schemas)
- Defer to the codebase when stories disagree on a term (source of truth
  rule)

No edits yet — only the plan.

**CHECKPOINT 3**: confirm the draft before applying.

## Phase 5 — Apply contract edits

**Normal mode**:
- Apply `CONTRACT.md` edits in place.
- Update `MASTER.md` primary-contract blurb (story count, consolidation date).
- Fix in-file story header status drift (e.g. `in review` → `done`) flagged
  in Phase 1.
- Do NOT touch product code in this phase.

**Bootstrap mode**:
- Create `<epic>/CONTRACT.md` with the drafted content.
- Add or update the `MASTER.md` primary-contract section to reference
  `CONTRACT.md` as the authoritative document, with story count and
  consolidation date. If the section does not exist, add one immediately
  after the epic overview.
- Fix in-file story header status drift (e.g. `in review` → `done`) flagged
  in Phase 1.
- Do NOT touch product code in this phase.

## Phase 6 — Optional code-level fixes (per-fix approval)

For each code-level discrepancy from Phase 3, present a proposed diff
individually.

**CHECKPOINT 4**: confirm each fix separately. Only apply approved fixes.

After applying fixes, run the relevant test subset:
- Parse each in-scope story's `Verification` section for test commands
  (`uv run pytest ...`, `npm test ...`, etc.)
- Union them into a minimal relevant set
- Run and wait for exit

If any test fails, stop before Phase 7 and report. Do not archive.

## Phase 7 — Archive and finalize

**CHECKPOINT 5**: confirm archival. This is irreversible from this session's
perspective.

- If `<epic>/archive/` does not exist (bootstrap mode), create it with
  `mkdir -p`.
- Move each in-scope story file into `<epic>/archive/`
- Update `MASTER.md` tracker links: each in-scope row's `Spec` path changes
  from `[story-NN-...md](story-NN-...md)` to
  `[archive/story-NN-...md](archive/story-NN-...md)`
- Remove now-stale transient notes about individual stories from `MASTER.md`
  (implementation notes, reopen notes, etc.)

## Final response

In your final response, state:
- which epic was squashed and the resolved path
- each story squashed (number and title)
- contract sections edited, by type: edit / add / remove (counts)
- discrepancies reported vs fixed, by category (contract / story / code)
- tests run and result
- files moved to `archive/`
- whether `MASTER.md` was updated
- the exact next action the operator should take (usually: none)

## Optimization notes

- **Parallel story reads**: always batch the initial reads into one
  message/tool-call group.
- **Single verification pass**: do not fan out multiple agents for this task.
  One structured pass is enough.
- **Pre-classify no-ops early**: pure refactor / cleanup stories skip Phase 4
  edit planning entirely.
- **Targeted grep for each changed default**: when a story changes a default
  (e.g. `"xhigh" → "high"`), explicitly grep for the OLD value across the
  codebase in Phase 2. Legacy compat paths are the usual culprits.
- **Batch trailing-appendix edits**: when adding many A / B / C entries at
  once, consider one larger edit over many tiny ones for the trailing
  sections (never for middle-of-document section rewrites — those need
  focused diffs).
- **Consider writing a sibling `SQUASH_REPORT.md`** next to `CONTRACT.md`
  recording what was squashed, when, and what discrepancies were found and
  fixed. Good provenance for future audits. Ask the operator before creating
  it the first time an epic is squashed.
