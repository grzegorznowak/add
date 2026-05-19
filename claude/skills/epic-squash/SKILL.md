---
name: epic-squash
description: Squash non-archived DONE stories of an epic into its merged CONTRACT.md, verifying every claim against the codebase, detecting/fixing discrepancies, and archiving the stories. Use when an epic accumulates completed stories that should be folded into the authoritative contract.
disable-model-invocation: true
argument-hint: "<epic-path-or-name>"
allowed-tools: Read Edit Write Grep Glob Bash
---

# Epic Squash

Fold non-archived DONE stories of an epic into its merged `CONTRACT.md`, verify every claim against the codebase (the source of truth), detect and optionally fix discrepancies, then move the stories to `archive/`.

Argument: `$ARGUMENTS` — the epic path (e.g. `agent_coordination/epics/<epic-name>`). If omitted and there is exactly one active epic under `agent_coordination/epics/`, default to that one; otherwise ask the user which epic.

## Non-negotiable rules

1. **The codebase is the source of truth.** Always. Story text and CONTRACT.md text lose to the code when they disagree. If a story's claim doesn't match the code, the story is wrong — OR the code has regressed; flag both possibilities.
2. **Never skip verification.** Even for stories marked `done`, verify their concrete claims against the code before folding anything.
3. **Do not ignore workflow evidence drift.** Missing focused red-seam evidence or a missing explicit written exception is a story discrepancy during consolidation.
4. **Never auto-fix product code.** Code-level fixes require explicit per-fix approval at the Phase 6 checkpoint. Contract edits and code edits live on different blast-radius tiers.
5. **Never archive on failing tests.** If Phase 6 runs tests and they fail, stop before Phase 7.
6. **Preserve appendix history.** Add new Appendix A / B / C entries; never renumber or delete existing ones.
7. **Use the minimum number of subagents.** One well-structured Explore agent beats three ad-hoc ones.
8. **Checkpoint before irreversible or high-blast-radius actions.** The phases below mark each explicit checkpoint — do not skip them.

## Phase 0 — Sanity check and bootstrap

- Resolve the epic path from `$ARGUMENTS` (or the default rule above).
- Verify the epic has `MASTER.md`. **This is the only hard requirement.** Abort if missing.
- Read `MASTER.md` fully.

Then determine the run mode based on what else is present:

**Mode A — normal squash** (default): both `CONTRACT.md` and `archive/` exist. Proceed with the phases below as written.

**Mode B — bootstrap squash**: `CONTRACT.md` is missing, or `archive/` is missing, or both. This is a valid "first squash" of the epic. Do NOT abort. Instead:
- If `archive/` is missing, note that Phase 7 will create it before moving story files.
- If `CONTRACT.md` is missing, note that Phase 4 will draft a fresh contract from scratch using the in-scope stories as input, and Phase 5 will `Write` it instead of `Edit`-ing.
- Report which artifacts will be bootstrapped at the start of Phase 1 so the user knows this is the first consolidation.
- In bootstrap mode there is no pre-existing CONTRACT.md to detect contradictions against. Phase 3's "Contract discrepancies" list will be empty by definition. Story and code-level discrepancies are still in scope.

Track the mode as a state variable and reference it in each phase's decisions.

## Phase 1 — Identify in-scope stories

From the MASTER.md tracker, select stories where:
- Status is `✅ DONE` (or the epic's equivalent), AND
- The spec link points to the epic root, NOT to `archive/`.

**Explicitly exclude** stories with any non-`DONE` status, including `🔵 IN PR`. An `IN PR` story has passed local review but its GitHub pull request is not yet merged — the code may still change before merge, so folding it into `CONTRACT.md` is unsafe. Report any excluded `IN PR` stories in a dedicated "skipped" list and tell the user to rerun `/epic-squash` once the PR merges and the story moves to `✅ DONE`.

Also flag (but still include) stories where the story file header status disagrees with the tracker (e.g. `in review` in file vs `DONE` in tracker). That drift is a known failure mode and needs to be fixed as part of the squash.

Print the in-scope list (story number, title, spec path, status-drift flag if any) and **CHECKPOINT 1**: confirm the list with the user before proceeding.

## Phase 2 — Parallel reads + single codebase-verification pass

In one message, batch:
1. `Read` on current `CONTRACT.md` (**skip in bootstrap mode — the file does not exist**)
2. `Read` on every in-scope story file

Then launch **exactly one** Explore subagent to verify every concrete claim in the in-scope stories against the codebase. The prompt must include a structured checklist:
- Function / class / method names the stories mention
- Constants, env vars, config keys
- Default values (especially when a story says "changed X from A to B")
- Lifecycle wiring claims (where something is called from)
- Test fixture paths
- Stale-compat path checks: for each changed default, grep for the OLD value anywhere in the code and report hits

The agent must return a match / no-match report with `file:line` evidence for each item.

## Phase 3 — Classify changes and detect discrepancies

For each in-scope story, categorize contract impact as one of:
- **no-op** — internal cleanup / refactor only; no contract change needed. Skip in squash.
- **additive** — introduces new contract terms (new section or subsection).
- **modifying** — changes the meaning of existing contract terms (find the section to edit).
- **removing** — deletes or deprecates existing contract terms.

Build three discrepancy lists:
- **Contract discrepancies**: `CONTRACT.md` text that contradicts the codebase (e.g. obsolete config keys, stale routing rules, old field tables). These MUST be fixed during the squash.
- **Story discrepancies**: claims in stories that don't match the codebase, or required workflow evidence that is missing from `## Progress Log` / `## Session Handoff` (focused red seam or explicit written exception). Codebase wins; update the squashed contract to match the code, and report the story drift.
- **Code-level discrepancies**: stale defaults in legacy compat paths, dead code left over from removed approaches, file-vs-tracker status drift, etc. These are candidates for Phase 6.

Treat `## Scenarios / Behavior Examples` as durable contract input only when a scenario is normative and linked with `Covers: A<n>`. Orientation-only scenarios are historical context and should not be consolidated unless the same behavior is also present in Acceptance or the final contract.

Present all three lists plus the story classification. **CHECKPOINT 2**: confirm classification and discrepancy lists before editing anything.

## Phase 4 — Draft contract edits

**Normal mode**: Produce a section-by-section edit list for `CONTRACT.md`:
- Header (story count + consolidation date)
- Each affected section (edit / add / remove with the exact target text)
- New Appendix A entries for resolved contradictions
- New Appendix B entries for resolved gaps
- New Appendix C entries for known or fixed code-level discrepancies

**Bootstrap mode**: Draft the **entire** CONTRACT.md from scratch. Use this scaffold:

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
- Group stories by coherent product domain (e.g. "Configuration Surface", "Runtime Architecture", "Observability", "Lifecycle", "Migration & Compatibility"), not by story number
- Each section should be scannable in under 30 seconds
- Lead each section with a one-line summary of the domain
- Prefer tables for structured contract surfaces (config keys, env vars, file paths, field schemas)
- Defer to the codebase when stories disagree on a term (source of truth rule)

No edits yet — only the plan. **CHECKPOINT 3**: confirm the full draft before writing.

## Phase 5 — Apply contract edits

**Normal mode**:
- Apply `CONTRACT.md` edits with `Edit` calls.
- Update `MASTER.md` primary-contract blurb (story count, consolidation date).
- Fix in-file story header status drift (e.g. `in review` → `done`) flagged in Phase 1.
- Do NOT touch product code in this phase.

**Bootstrap mode**:
- `Write` the new `CONTRACT.md` with the drafted content.
- Add or update the `MASTER.md` primary-contract section to reference `CONTRACT.md` as the authoritative document, with story count and consolidation date. If the section does not exist, add one immediately after the epic overview.
- Fix in-file story header status drift (e.g. `in review` → `done`) flagged in Phase 1.
- Do NOT touch product code in this phase.

## Phase 6 — Optional code-level fixes (per-fix approval)

For each code-level discrepancy from Phase 3, present a proposed diff individually. **CHECKPOINT 4**: confirm each fix separately. Only apply approved fixes.

After applying fixes, run the relevant test subset:
- Parse story `Verification` sections for test commands (`uv run pytest ...`, `npm test ...`, etc.)
- Union them into a minimal relevant set
- Run and wait for exit

If any test fails, stop before Phase 7 and report. Do not archive.

## Phase 7 — Archive and finalize

**CHECKPOINT 5**: confirm archival. This is irreversible from this session's perspective.

- If `archive/` does not exist (bootstrap mode), create it with `mkdir -p`.
- `mv` each in-scope story file into `archive/`
- Update MASTER.md tracker links: each in-scope row's spec path changes from `[story-NN-...md](story-NN-...md)` to `[archive/story-NN-...md](archive/story-NN-...md)`
- Remove now-stale transient notes about individual stories from MASTER.md (implementation notes, reopen notes, etc.)
- Print final summary:
  - stories squashed (by number and title)
  - contract sections edited (counts by type: edit / add / remove)
  - discrepancies reported / fixed (by category)
  - tests run and result
  - files moved to archive

## Optimization notes (apply where it helps)

- **Parallel story reads**: always batch the initial reads into one message with multiple `Read` calls.
- **Single verification agent**: do not launch multiple Explore agents for this task. One structured pass is enough.
- **Pre-classify no-ops early**: pure refactor / cleanup stories skip Phase 4 edit planning entirely.
- **Targeted grep for each changed default**: when a story changes a default (e.g. "xhigh → high"), explicitly grep for the OLD value across the codebase in Phase 2. Legacy compat paths are the usual culprits.
- **Batch trailing-appendix edits**: when adding many A / B / C entries at once, consider one larger Edit over many tiny ones for the trailing sections (never for middle-of-document section rewrites — those need focused diffs).
- **Consider writing a sibling `SQUASH_REPORT.md`** next to `CONTRACT.md` recording what was squashed, when, and what discrepancies were found and fixed. Good provenance for future audits. Ask the user before creating it the first time an epic is squashed.
