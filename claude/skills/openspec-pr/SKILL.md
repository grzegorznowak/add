---
name: openspec-pr
description: Open, attach, or refresh optional GitHub PR delivery metadata/evidence for one OpenSpec story. Does not change story Status.
disable-model-invocation: true
argument-hint: "<initiative-slug> <story-slug> [pr-url|OPEN=true]"
allowed-tools: Read Edit Write Grep Glob Bash(git status:*) Bash(git log:*) Bash(git branch:*) Bash(git rev-parse:*) Bash(git worktree:*) Bash(git diff:*) Bash(git ls-files:*) Bash(git hash-object:*) Bash(sha256sum:*) Bash(shasum:*) Bash(gh pr list:*) Bash(gh pr view:*) Bash(gh pr edit:*) Bash(gh pr create:*) Bash(curl:*)
---

# OpenSpec PR

Open, attach, or refresh a GitHub PR for a locally completed OpenSpec story and record delivery metadata on the change workspace's `progress.md`. This is a lightweight delivery helper after local review has already marked the story `✅ DONE`; it is not a story lifecycle state and never updates `story.md → Status:`.

Argument: `$ARGUMENTS` — `<initiative_slug> <story_slug> [<pr_url_or_OPEN=true>]`. Initiative and story may be inferred only when exactly one non-archived, locally DONE story is eligible. The third arg is either a full GitHub PR URL (attach mode) or the literal `OPEN=true` to have this flow open the PR via `gh` (open mode). Omitting the third arg means refresh an existing `## PR State` URL when present, otherwise discover an existing branch PR, otherwise ask before opening a new PR.

## Intent

This flow applies after `/openspec-story-review` has approved local product/spec correctness and written `Status: ✅ DONE`. GitHub PRs are external delivery/review channels: they may be useful or required before archive, but they are not the authority for local story completion.

Use this command to:

- generate or refresh a product-facing PR body from story/proposal/spec context;
- open a PR via `gh`, attach an existing PR URL, or refresh metadata for an already-bound PR;
- maintain `progress.md → ## PR State` as durable PR delivery evidence for archive preflight.

If a PR reviewer requests changes, do not downgrade the story here. Route actionable PR feedback through `/openspec-feedback`, which can reopen the story for resume, amend planning/contract artifacts, create a follow-up candidate, record an initiative decision, or defer/reject the feedback.

## Resolution Model

- `<workspace_root>` = `<cwd>` and remains the launch checkout/worktree-discovery base.
- `<openspec_root>` = the transient active coordination artifact anchor resolved in Phase 0; never persist an `OpenSpec root:` field.
- `<initiative_dir>` = `<openspec_root>/openspec/initiatives/<initiative>`.
- `<initiative_file>` = `<initiative_dir>/initiative.md`.
- `<change_dir>` = `<openspec_root>/openspec/changes/<story-slug>`.
- `<story_file>` = `<change_dir>/story.md`.
- `<progress_file>` = `<change_dir>/progress.md`.
- `<proposal_file>` = `<change_dir>/proposal.md`.

There is no `MASTER.md`, no tracker table, and no PR lifecycle status. All status is self-contained in the change workspace artifacts:

- The `Status:` header field in `<story_file>` is the authoritative implementation status and is not changed by this command.
- The `Plan:` header field in `<story_file>` is the authoritative planning lane.
- `story.md → Initiative:` is the authoritative initiative association. Inventory the top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line. Exactly one present line is valid only when its whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`; duplicate, empty, whitespace-before-colon, non-canonical, or otherwise malformed Initiative-like lines are hard conflicts, never legacy absence.
- `Status: ✅ DONE` in `<story_file>` is local completion authority. A modern bound story requires exactly one complete canonical `progress.md → ## Implementation Review Receipt`; receipt absence is compatible only for a true pre-v3 story with zero Initiative or Initiative-like lines and zero receipt sections.
- The `## Current Claim` section in `<progress_file>` records implementation state and worktree bindings.
- The `## PR State` section in `<progress_file>` is the sole PR metadata/evidence location.
- The `## Progress Timeline` section in `<progress_file>` records milestone bullets.

## Status lifecycle (reference)

- `⬜ TODO` — not started
- `🔄 IN PROGRESS` — actively being worked
- `🟣 IN REVIEW` — ready for independent local review
- `✅ DONE` — local workflow completed by independent `/openspec-story-review` approval
- `⛔ BLOCKED` — explicit blocker

## Phase 0 — Resolution and inference

This flow accepts three positional inputs in `$ARGUMENTS` — `<initiative>`, `<story>`, and `<pr_url_or_OPEN=true>` — and runs three independent inference passes for any of them that is missing. **Explicit values always win and skip their corresponding inference pass.** The goal is convenience without silently selecting completed history from a crowded workspace.

Parse `$ARGUMENTS` first. Treat any of the three slots that is empty as a request to infer. Validate every explicit or inferred initiative/story slug against `^[a-z0-9]+(?:-[a-z0-9]+)*$` before path construction. Record `<explicit_pair>` as true only when the operator supplied both initiative and story positional arguments in this invocation; an inferred/defaulted selector or initiative alone does not make an explicit pair. This command accepts no `WORKTREE=` selector.

### Transient OpenSpec-root and initiative-binding preflight

1. Set `<workspace_root>=<cwd>` and initially set `<openspec_root>=<workspace_root>`. `<openspec_root>` is transient runtime state only.
2. Build candidate roots from `<workspace_root>` plus `git worktree list --porcelain`. For a known initiative/story pair, a root qualifies only when it contains both `<root>/openspec/initiatives/<initiative>/initiative.md` and `<root>/openspec/changes/<story>/story.md`. For missing selectors, collect bounded eligible pairs from those same artifact families and validate binding as steps 3–4 require; do not associate a story merely because an initiative file contains similar prose.
3. Inventory each candidate story's complete top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line. Exactly one present line is valid only when its whole line matches `^Initiative: ([a-z0-9]+(?:-[a-z0-9]+)*)$`. Duplicate canonical headers, an empty value, whitespace before the colon (for example `Initiative : foo`), a non-canonical value, or any other malformed Initiative-like line halts and reports every offending line; never treat malformed present input as header absence. For the selected story, an explicit/inferred initiative conflict is an Initiative mismatch: halt, report both values and candidate root, and do not proceed. During broad initiative/story discovery, filter a well-formed story bound to another initiative as unrelated instead of halting the PR scan; never re-associate it from prose.
4. Only zero Initiative or Initiative-like lines is a legacy story. For that case, scan same-root initiative files for exact story-slug associations in `## Story Candidates`. Exactly one association may drive discovery and must equal any selected initiative; a different or multiple association halts. No association is accepted only for a selected story when `<explicit_pair>` is true and the selected same-root initiative file exists. An inferred/defaulted or initiative-only selector is not an explicit pair. Warn for every accepted legacy story and never backfill the header. During broad discovery and story menus, include bound stories plus uniquely associated zero-line legacy stories only; exclude zero-association legacy stories.
5. Resolve a known pair by root precedence. Because PR accepts no `WORKTREE=` selector, inspect registered worktrees other than `<workspace_root>` on `refs/heads/<initiative>/<story>` first. Exactly one qualifying branch worktree outranks launch even when launch has matching stale artifacts; multiple qualifying branch worktrees halt for operator selection. Only when no branch worktree qualifies, fall back to `<workspace_root>` and require both artifacts there. Ignore unrelated/non-branch matching roots rather than selecting one arbitrarily. Set `<openspec_root>` and recompute every coordination path.
6. After story/initiative inference fills a missing selector, rerun steps 3–5 with both slugs. All subsequent `openspec/...` reads and writes use `<openspec_root>`. If the launch fallback lacks the active pair, ask the operator to rerun from the checkout containing both artifacts; do not silently select a non-branch copy.

### Pass 1 — Initiative inference (when `<initiative>` is empty)

1. List initiative directories across the candidate roots that contain an `initiative.md`, deduplicating each discovered story pair with the branch-over-launch precedence above.
2. An initiative is eligible if its `initiative.md` exists and at least one non-archived story selected by that precedence is authoritatively bound to it by `story.md → Initiative:` and has `Status: ✅ DONE`. A legacy story is discoverable only through exactly one exact same-root candidate association; zero-reference legacy stories require an operator-explicit pair and therefore never appear in this inference pass.
3. If exactly one eligible initiative exists, use it. Print: `inferred initiative: <slug> (single eligible initiative)`.
4. If zero eligible initiatives exist, do not infer one. Collect non-DONE initiative/story pairs as diagnostics only. If exactly one diagnostic candidate exists, list `<initiative>/<story> | <Status> | <title>` and emit its state-correct route from the DONE-only qualification rules below. If multiple exist, list all and use the singular `Operator decision: select a lifecycle target by stable <initiative>/<story> identifier; none is eligible PR context.` If none exist, require initiative/story correction. Abort before PR inference in every case.
5. If multiple eligible initiatives exist, abort with the list and: `multiple eligible initiatives; pass <initiative> explicitly to disambiguate.`

### Pass 2 — Story inference (when `<story>` is empty)

After the initiative is known, list active change workspaces across candidate roots, deduplicating each slug with branch-over-launch precedence. For each, read its authoritative `story.md → Initiative:` binding first. Include only stories bound to the selected initiative or legacy stories with exactly one same-root candidate association to it; filter well-formed stories bound to other initiatives as unrelated rather than halting. Exclude zero-reference legacy stories because an inferred story is not an explicit pair. A conflict on an explicitly selected story still halts. Then read `Status:` and collect every matching story whose status is `✅ DONE`.

1. If exactly one story matches, use it. Print: `inferred story: <story-slug> — <title> (status: ✅ DONE)`.
2. If zero stories match, collect every non-archived non-DONE story for the initiative as diagnostics only; none is a resolvable PR target.
   - If multiple non-DONE stories exist, list each as `<story-slug> | <Status> | <title>` and abort with the singular `Operator decision: select a lifecycle target by stable story slug; no candidate is eligible for PR delivery.` Do not select one merely because only one candidate is IN REVIEW or IN PROGRESS.
   - If exactly one non-DONE story exists, print it as `diagnostic only: <story-slug> | <Status> | <title>`, apply the state-correct diagnostic routing below, and abort before PR inference. Never call it inferred or resolved PR context.
   - If no non-DONE story exists, report that no active story was found and require explicit story/initiative correction as the singular operator route.
3. If multiple stories match the eligible set, list each candidate as `<story-slug> | ✅ DONE | <title>` and abort with: `multiple locally DONE stories are eligible; pass <story> explicitly to disambiguate.`

### DONE-only story qualification and diagnostic routing

Before Pass 3, read the explicitly selected or DONE-inferred workspace and qualify it. A story becomes resolved PR context only after all of these checks pass: it is active/non-archived, its authoritative `story.md → Initiative:` binding matches, it has no `blocked.md`, it has authoritative `Status: ✅ DONE`, it has unambiguous `Plan: 🟢 PLAN APPROVED`, and bounded task/implementation approval evidence does not contradict DONE.

Consume `progress.md → ## Implementation Review Receipt` as follows:

- Inventory every receipt heading and body. If any receipt is present for a DONE story, require exactly one `## Implementation Review Receipt` section and exactly one occurrence of every canonical field: `Reviewed at`, `Decision`, `Approval gate`, `Status transition`, `Evidence reviewed`, `Identity method`, `Identity digest`, `Identity bases`, `Identity paths`, `Findings`, `Proof`, and `Next owner`. Require `Decision: APPROVE`, `Approval gate: PASS`, a `Status transition` ending in `✅ DONE`, `Identity method: review-identity-v1`, one canonical `sha256:<lowercase-hex>` digest, and reproducible canonical JSON bases/path arrays (`[]` is valid for an empty list). Duplicate headings/bodies/fields, omitted or extra entry-shaped fields, `REQUEST CHANGES`, `BLOCKED`, FAIL, malformed values, or contradictory content blocks PR operations and routes only to `Open a completely fresh, oblivious session and run /openspec-story-review <initiative> <story-slug>.` Never search for an older approval; fresh substantive review owns normalization to one current receipt.
- Before displaying resolved PR context and again immediately before any `gh` mutation or `progress.md` write, recompute the story-scoped identity with canonical `review-identity-v1` using exactly the receipt-recorded `Identity bases` and `Identity paths`. Require an exact match to the receipt's `Identity digest` and resolve every recorded base/path without substitution. Missing paths, an unavailable base, unsupported/malformed identity input, or mismatch routes only to the same fresh oblivious review; this command never repairs or synthesizes receipt evidence. Save the matching digest and the last pre-mutation UTC verification timestamp in memory for PR State write-back.
- `review-identity-v1` excludes the story's OpenSpec coordination artifacts. Therefore this command's own `## PR State` and `## Progress Timeline` writes do not change the identity and must not trigger a post-write recomputation; source/path drift remains a mismatch at the required pre-mutation recomputation.
- A true pre-v3 legacy DONE without an implementation review receipt is compatible only when the same story has zero Initiative or Initiative-like header lines, zero receipt sections, and every other qualification passes. Print a warning that both binding and receipt evidence are absent, use the Phase 0 explicit/unique-association rules to resolve it, and backfill neither artifact. A bound modern DONE with an absent receipt routes only to the same fresh oblivious review; do not invent a synthetic receipt.
- For every non-DONE story, authoritative `Status:` owns routing. A receipt left from an earlier completed review may be historical context but never overrides the current non-DONE lane or makes the story eligible for PR delivery.

An explicit or diagnostic non-DONE candidate is never resolved PR context and never reaches PR inference. Route it without mutation in this order:

1. `blocked.md` -> one scalar operator action to resolve the blocker and remove the file.
2. `Status: 🟣 IN REVIEW` -> one fresh, oblivious `/openspec-story-review <initiative> <story-slug>` route even when Plan contradicts it; the wrapper never launches review.
3. For another non-DONE status, inspect Plan. A safely repairable incomplete scaffold may use the planning Converge wrapper plus Non-looped plan-resume; a structurally reviewable DRAFT/PLAN IN REVIEW lane with no unresolved finding may use the wrapper plus Non-looped plan-review; CHANGES REQUESTED uses plan-resume while findings/repairs remain and plan-review only when fully blended and reviewable. PLAN BLOCKED, malformed/ambiguous/unresolvable Plan, and unknown state remain singular.
4. With approved Plan, TODO may use the implementation wrapper plus Non-looped claim and IN PROGRESS may use that wrapper plus Non-looped resume. BLOCKED, missing, malformed/ambiguous, and unknown statuses remain singular.

For a DONE candidate, any non-approved, missing, malformed, or ambiguous Plan is a contradictory durable state. Abort with only `Operator action: investigate and reconcile the contradictory durable Status: ✅ DONE and Plan: <value> state before PR delivery or archive.` Do not recommend planning commands that reject DONE and do not invent a lifecycle owner. If Plan is approved but bounded tasks or implementation approval evidence contradicts DONE, route only to a completely fresh, oblivious story-review session. Only a DONE candidate passing these checks is `<resolved_story>`.

### Pass 3 — PR inference (when `<pr_url_or_OPEN=true>` is empty)

After the DONE story is resolved, decide whether this is an attach (existing PR) or open (new PR) operation. Walk the inference chain in order:

1. **PR State section.** Read `<progress_file>` and look for a `## PR State` section. If it exists and has a `- PR URL:` line with a non-empty URL, that is the existing PR. Use attach mode in refresh form. Print: `inferred PR (from PR State): <url>`. Skip the rest of the chain.

2. **Project repo detection.** Read `<progress_file>` for the `## Current Claim` section and parse the `- Primary write surfaces:` field. Take the first path. Walk up the directory tree until you find a `.git/` directory; that is the project repo. If no `.git/` is found, fall back to the workspace `.git/` if one exists. If still none, skip directly to step 4.

3. **Branch-based PR lookup.**
   - Inside the detected project repo, run `git rev-parse --abbrev-ref HEAD` to get the current branch.
   - If the branch is the repo's default branch, abort before OPEN mode with the scalar route `Operator action: check out or create and push the story feature branch, then rerun /openspec-pr <initiative> <story-slug> OPEN=true.` Operating directly on `main`/`master` is not how PRs are opened; do not also offer another route.
   - Otherwise run `gh pr list --head <branch> --state all --json url,number,headRefName,title,state,isDraft,mergedAt,mergeCommit,closedAt,reviewDecision,latestReviews` from inside the project repo. Use all states so this helper can discover already merged or closed PRs instead of opening duplicates.
   - If exactly one PR is returned, print `inferred PR (from current branch <branch>): <url> (state: <state>)` and **ask the user to confirm** before attaching. The branch may legitimately host work unrelated to this story.
     - If the inferred PR is merged, attach/refresh it with the live merged metadata; do not open a duplicate PR.
     - If the inferred PR is closed but not merged, report that closed-unmerged PR and do not silently open a duplicate. Ask whether to attach the closed PR for audit metadata or explicitly proceed with replacement OPEN mode; if the user does not choose replacement OPEN mode, abort without write-back.
     - If the inferred PR is open, attach it normally after confirmation.
   - If multiple PRs are returned, list each as `<number> | <state> | <title> | <url>` and ask which to attach. Highlight merged and closed-unmerged candidates; do not fall through to implicit OPEN mode until the operator explicitly rejects/ignores the existing candidates.
   - If zero are returned, fall through to step 4.

4. **Fall through to OPEN mode.** If no existing PR was found by any previous step, or the operator explicitly chose replacement OPEN mode after reviewing branch PR candidates:
   - Ask the user: `no existing PR found for the detected story branch/repo. Open a new one via gh? [Y/n]`
   - If yes, proceed exactly as the existing `OPEN=true` path in "PR creation mode".
   - If no, abort with: `pass <pr_url> explicitly when one exists, or rerun with OPEN=true to open a fresh PR.`

### Inference summary printout

Before doing any work that affects `progress.md` or the PR, print a single resolved-context block so the user can verify what was inferred:

```
Resolved context:
- initiative: <slug>          (explicit | inferred from single eligible initiative)
- story: <story-slug> — <title>  (explicit | inferred from single eligible story)
- status: ✅ DONE
- PR:    <url>           (explicit | from PR State | from current branch | new via OPEN)
```

Print this even when everything was passed explicitly — the printout is the contract the user approves before any PR/body update runs.

### Entry-condition recheck

Immediately before any PR/body/progress mutation, re-resolve `<openspec_root>`, re-read and inventory the already resolved story's complete top-level Initiative-like header region by the rules above, and repeat the full DONE-only qualification. Legacy receipt absence is allowed only for the exact zero-Initiative-like/zero-receipt pre-v3 case. A present receipt must be the one complete canonical APPROVE/PASS record with a transition ending in DONE, and canonical `review-identity-v1` must recompute from its recorded bases/path list to exactly its recorded digest. If the root becomes ambiguous, the story is archived, `blocked.md` appeared, Status is no longer DONE, Plan is no longer unambiguously approved, receipt evidence is malformed/missing for a bound story, or identity evidence mismatches or cannot be verified, abort without any `gh` or progress action using the same fresh-review route above. Save the matching digest and current UTC timestamp only after this final pre-mutation recheck. Never print a resolved-context block whose status is not `✅ DONE`.

Do not normalize or mutate `story.md → Status:` from this command.

### Known limitations

- **Cross-repo PR detection is not supported.** The PR inference looks at the project repo derived from the story's `Primary write surfaces` in `progress.md → ## Current Claim`. If a story's surfaces span multiple repos, pass the PR URL explicitly.
- **Stories without a `## Current Claim` section in progress.md cannot have their project repo inferred.** This usually means the story has never been claimed via `/openspec-story-claim` / `/openspec-story-resume`. Pass the PR URL explicitly in that case.

## PR description — product-focused, NOT implementation-focused

**This is the most important rule of this flow.** The PR body is a spec-vs-code verification contract for the GitHub reviewer, not a developer diary. The reviewer must be able to answer one question from the PR body alone: *does this code deliver what the story promised?*

### What belongs in the PR body

Extract **only** product-facing content from the change workspace artifacts (`proposal.md`, `story.md`, and delta specs under `specs/`):

- the product-facing **Triggering Need** / **Goal / Context** (what changed, broke, or became necessary and why the work is needed now)
- the story **Purpose** / **Goal** (what outcome the user gets)
- concise external compatibility context when it is necessary to explain the observable breakage or migration boundary
- role-based **Actors** when they clarify who the PR affects
- normative **Scenarios / Behavior Examples** only when they are linked to a single acceptance id with `Covers: A<n>` and help the reviewer understand expected behavior
- explicit **original ticket/card links** from `Triggering Need`, `Purpose`, `Scope`, `Goal / Context`, `External Resources`, or other product-facing prose, when present
- the **Acceptance criteria** (observable behavior the code must satisfy)
- the **Out of Scope** section (what this PR deliberately does not deliver)
- **Contract / interface changes** — if and only if they affect external behavior (config keys, CLI surface, API shape, file formats, env vars, persisted metadata schema, user-visible defaults, migration requirements). These live in the PR body because they change what the code promises to the outside world.
- **User-facing verification** — how a reviewer can manually confirm the outcome without reading the code (CLI commands, config snippets, expected UI/log output)
- **Delta spec summaries** — summary-level behavioral changes described in `specs/` delta specs, when they clarify the user-visible behavioral contract and fit the inclusion boundary

### What does NOT belong in the PR body

Suppress anything that describes *how* the code was implemented rather than *what* it delivers:
- `## Current Claim` (session-local metadata)
- `## Progress Timeline` (implementation diary with timestamps)
- `## Session Handoff` (inter-session handoff notes)
- `Status:` header in `story.md` (prior review approval signal)
- `design.md` content (architecture decisions, rationale, internal module structure)
- `tasks.md` content (task checklists, implementation ordering)
- `progress.md` content (runtime tracking)
- file paths, function names, class names, internal module names — unless they ARE the contract (e.g. a public API endpoint, a documented config key)
- internal refactoring decisions, helper extractions, private naming choices
- test file paths, fixture paths, parameterization notes
- "why we chose X over Y" architecture rationale, unless the choice is user-visible
- `## Discovery Notes`, `## Locked Decisions`, `## Implementation Notes`, `## Critical Files` from story.md (implementation-facing sections)
- any content that would go stale if the implementation were rewritten without changing the contract

**Test the inclusion boundary**: source-supported catalyst context, user-visible before/after state, and external compatibility facts belong when they remain true regardless of implementation. Other content does not belong if it would become stale under a completely different implementation that still passes the Acceptance criteria and preserves the Contract changes.

### PR body template

Generate the body using this structure. Omit any section that has no content rather than writing "N/A".

```md
## Summary
<one or two short paragraphs in product language. Start with the source-supported catalyst: what happened or changed, why the work is needed now, and any explicit cause-versus-exposure distinction. Then state the user-visible before/after outcome this PR delivers. If the artifacts state no catalyst, lead with the strongest source-supported Goal, Purpose, or outcome without inventing a gap, history, or causality.>

## Original tickets
- <optional label>: <url>

## Requirements
<bulleted list extracted from the story's Purpose / Goal>

## Acceptance criteria
<bulleted list extracted from the story's Acceptance section, rephrased in reviewer-verifiable terms>

## Contract changes
<only if the story changes external contracts: config keys added/removed/renamed, CLI flag changes, API/file-format changes, migration requirements, user-visible defaults>

## Out of scope
<bulleted list from the story's Out of Scope section>

## How to verify
<user-facing verification steps a reviewer can run or inspect without reading the code>

## Initiative reference
- Initiative: <initiative-slug>
- Story: <story-slug> — <story title>
- Change workspace: openspec/changes/<story-slug>/
```

### Sourcing the content

Read the following artifacts in the change workspace and map them to the PR body. Skip any missing artifact silently. This mapping order does not determine the Summary's narrative order: when a catalyst is available, it still comes first.

1. `proposal.md → ## Goal / Context` → Summary (catalyst, why now, and outcome when stated)
2. `proposal.md → ## External Resources` → Original tickets (extract only explicit URLs; omit narrative descriptions)
3. `story.md → ## Triggering Need` → Summary (catalyst, observable before state, and explicit causal boundaries when stated)
4. `story.md → ## Purpose` → Summary + Requirements
5. `story.md → ## Triggering Need`, `## Purpose`, `## Scope` → Original tickets (extract only explicit URLs not already found)
6. `story.md → ## Actors` → Requirements only when role context is product-facing
7. `story.md → ## Scenarios / Behavior Examples` → Acceptance criteria only for normative scenarios linked with exactly one `Covers: A<n>`; omit orientation-only examples
8. `story.md → ## Acceptance` → Acceptance criteria
9. `story.md → ## Scope` → filter for contract-affecting parts only → Contract changes
10. `story.md → ## Out of Scope` → Out of scope
11. `story.md → ## Verification → ### Verification Commands` → filter for user-facing checks only → How to verify
12. `story.md → ## Verification → ### Test Architecture Plan` → exclusion-only proof-planning input; never copy it into the PR body
13. `story.md → ## Verification → ### Acceptance Proof Matrix` → use only to cross-check that acceptance wording is reviewer-verifiable; never copy receipt/proof-ledger rows into the PR body
14. `specs/*.md` → Contract changes (only where behavioral deltas describe external contract surface changes; summarize in contract language, not implementation language)

### Cold-reader and causality check

Before publishing, read the Summary without the title or linked artifacts:
- Start with the source-supported catalyst when one is available, so a new reviewer can understand what changed and why the work is needed now.
- State the observable before state and the user-visible after state when the eligible artifacts provide them.
- Preserve explicit causal boundaries such as "exposed" versus "caused." Never infer chronology or causality that the eligible artifacts do not state.
- Rephrase unfamiliar terminology into plain language; when an unfamiliar term is unavoidable, define it only from source-supported context.
- Do not let the Summary replace or weaken Requirements, Acceptance criteria, Contract changes, Out of scope, or How to verify.

For original ticket/card links:
- Include links only; never summarize or quote original ticket text.
- Detect explicit URLs and stable identifiers only. Do not infer from vague prose.
- When multiple links are found, keep a unique compact list.
- Try to fetch or infer short labels when reasonably available from the link target or local markdown link text. If a label is unavailable, include only the link.
- Missing ticket links are not a prompt and not a blocker for this story flow.

Do not paste sections verbatim if they contain internal terminology. Rephrase into reviewer-facing language. A reviewer who has never seen the change workspace should understand the PR body.

**Exclusion enforcement for PR body generation**: never include content from `design.md`, `tasks.md`, or `progress.md` in the PR body. These files may be read only for this command's PR metadata, entry-condition, and approval-evidence gates. Explicitly exclude the implementation review receipt and every feedback receipt/feedback ledger entry, even when nearby product prose is eligible. If a section of `story.md` is implementation-facing (`## Discovery Notes`, `## Locked Decisions`, `## Implementation Notes`, `## Critical Files`, `story.md → ## Verification → ### Acceptance Proof Matrix`, `story.md → ## Verification → ### Test Architecture Plan`), exclude it from the PR body.

## PR creation mode

**Attach mode (default)** — a PR URL is provided:
- The user has already opened the PR
- Verify the URL is well-formed (`https://github.com/<org>/<repo>/pull/<n>`)
- Call `gh pr view <PR_URL> --json number,title,headRefName,state,url,body,isDraft,reviewDecision,latestReviews,mergedAt,mergeCommit,closedAt,updatedAt` to enrich metadata and read the current body, review decision, merged state, and merge commit.
- **Update the PR body to the generated product description** via `gh pr edit <PR_URL> --body-file <tmpfile>`
  - If the existing body already contains substantial content authored by the user, show a diff and ask confirmation before overwriting. Offer to prepend/append instead of replacing.
  - If the existing body is empty or auto-generated (e.g. commit messages), replace silently.
- If `gh` is unavailable, skip enrichment and the body edit, record only what the user provided, and tell the user the PR body was not updated

**Open mode** — user passes `OPEN=true` with no URL, or explicitly selects a `✅ DONE` story with no URL and no existing PR was found:
- Verify `git status` is clean or only contains intended changes
- Verify the current branch is not the default branch
- Generate the PR body (see template above) and write it to a tempfile
- Call `gh pr create --title "<story title>" --body-file <tmpfile>`
- Capture the returned URL
- Immediately call `gh pr view <returned-url> --json number,title,headRefName,state,url,body,isDraft,reviewDecision,latestReviews,mergedAt,mergeCommit,closedAt,updatedAt` to populate the same durable metadata fields used by attach/refresh mode.
- If the current branch is the default branch, abort with only `Operator action: check out or create and push the story feature branch, then rerun /openspec-pr <initiative> <story-slug> OPEN=true.` For a `✅ DONE` story, leave `story.md`, `progress.md`, and `## PR State` untouched.
- If `gh` fails or is unavailable, abort with only `Operator action: open the PR manually, then rerun /openspec-pr <initiative> <story-slug> <pr-url> in attach mode.` Include the failure, and for a `✅ DONE` story leave `story.md`, `progress.md`, and `## PR State` untouched.

In both modes, **never** force-push, **never** bypass hooks, **never** rewrite history without explicit user confirmation.

## Write-back to progress.md

### PR State section

Add or refresh a `## PR State` section in `<progress_file>`:

```md
## PR State
- PR URL: <url>
- Number: <n>
- Title: <pr title>
- Branch: <head ref>
- Opened at: <UTC ISO timestamp>
- PR status: open | changes_requested | approved | merged | closed
- Review decision: <APPROVED | CHANGES_REQUESTED | REVIEW_REQUIRED | blank | unavailable>
- Merge commit: <sha or "—">
- Merged at: <UTC ISO timestamp or "—">
- Verified implementation digest: <receipt Identity digest, or "—" only for accepted pre-v3 no-receipt legacy>
- Verified at: <UTC ISO timestamp from the final pre-mutation identity verification, or "—" only for accepted pre-v3 no-receipt legacy>
- Last synced: <UTC ISO timestamp>
```

Do **not** create a duplicate `## PR State` section. If one already exists, update its fields in place. When refreshing an older section, add the `Review decision:`, `Merged at:`, `Verified implementation digest:`, and `Verified at:` fields rather than dropping them. For a modern receipt, the verified digest must exactly equal its `Identity digest`; never carry forward an older verification timestamp or digest.

### PR status derivation

When `gh pr view` is available, derive the progress `PR status` from the enriched JSON fields, not from the URL alone:

1. If `state` is `MERGED` or `mergedAt` is non-empty, set `PR status: merged`, set `Merged at:` to `mergedAt` when available, and set `Merge commit:` to `mergeCommit.oid` (or the user-provided merge commit if `gh` lacks it).
2. Else if `state` is `CLOSED`, set `PR status: closed`.
3. Else if `reviewDecision` is `CHANGES_REQUESTED`, or the latest effective review state in `latestReviews` is `CHANGES_REQUESTED`, set `PR status: changes_requested`.
4. Else if `reviewDecision` is `APPROVED`, set `PR status: approved`.
5. Else set `PR status: open`.

If `gh` is unavailable in attach mode, record the supplied URL and any user-provided fields, set unavailable fields to `unavailable` or `—`, and report that archive cannot treat the PR as merged until live GitHub data or explicit merged-state evidence, merge commit, and merged-at timestamp are recorded.

### Progress Timeline entry

Append a timestamped bullet under `## Progress Timeline` in `<progress_file>`. Use the entry that matches the operation:

```md
- <UTC ISO timestamp> Opened PR delivery record — <PR URL> (status: <PR status>)
- <UTC ISO timestamp> Attached PR delivery record — <PR URL> (status: <PR status>)
- <UTC ISO timestamp> Refreshed PR delivery record — <PR URL> (status: <PR status>)
```

Do not write lifecycle transition language in the timeline. This command records delivery metadata only.

### story.md Status header

Never update the `Status:` header field in `<story_file>` from this command. If the entry-condition recheck no longer sees `Status: ✅ DONE`, abort before writing PR metadata and apply the non-DONE diagnostic routing above; do not retain or print it as resolved PR context.

## Refresh existing PR metadata

If `## PR State` already has a PR URL, refresh it:

- Re-query `gh pr view --json number,title,headRefName,state,url,body,isDraft,reviewDecision,latestReviews,mergedAt,mergeCommit,closedAt,updatedAt` if available and update `## PR State → PR status`, `Review decision`, `Merge commit`, `Merged at`, `Verified implementation digest`, `Verified at`, and `Last synced`. The identity fields come only from the final successful pre-mutation recomputation, not cached PR State.
- If `PR status` is `merged` and both `Merge commit:` and `Merged at:` are populated, report that archive PR evidence is complete.
- If `PR status` is `merged` but merge commit or merged-at evidence is missing, report the missing durable evidence and tell the user to rerun `/openspec-pr` with `gh` available or provide the missing evidence explicitly before archive.
- If `PR status` is `changes_requested` or reviewer comments request changes, do not update `story.md → Status:`. Tell the user to run `/openspec-feedback <initiative> --pr <PR URL>` so the feedback can be classified into story rework, planning changes, a follow-up story, initiative decision, or defer/reject.
- Otherwise leave local story completion alone and update PR delivery metadata only.

## No MASTER.md update

There is no `MASTER.md` and no tracker table in this flow. PR evidence is written to `<progress_file> → ## PR State` and `<progress_file> → ## Progress Timeline` only. No centralized coordination cache is consulted or written, and no story status is changed.

## Rules

1. **Use the PR description inclusion boundary above.** The PR body is a product contract for reviewers, not an implementation diary.
2. **Never change `story.md → Status:` from this flow.** Local completion is owned by `/openspec-story-review`; PR merge evidence is an archive gate, not story lifecycle authority.
3. **Never touch product code in this flow.** It is a coordination-only PR delivery helper (except for the optional `gh pr create` call in open mode).
4. **Never skip the progress.md write-back when a PR is opened, attached, or refreshed.** The PR URL is the durable link between the change workspace and the GitHub review.
5. **Never leave `Last synced` stale across PR metadata refreshes.**
6. **Never paste `## Current Claim`, `## Progress Timeline`, `## Session Handoff`, `design.md`, `tasks.md`, or `progress.md` content into the PR body.** Those sections are implementation diary, not product contract.
7. **Never silently pick among multiple locally DONE stories.** Ask the operator to pass the story explicitly.
8. **Never absorb PR feedback here.** Route actionable feedback through `/openspec-feedback`.
9. **Never treat cached local PR metadata as merged archive evidence when live `gh` data is available.** Archive performs its own authoritative preflight.
10. **Never perform PR delivery against implementation state that differs from, or cannot be reproduced by, canonical `review-identity-v1` from the receipt's recorded bases/path list.** Require the recomputed digest to equal the receipt, persist that digest and verification time in PR State, and route mismatch or unverifiable evidence to fresh substantive review. PR State/timeline coordination writes are outside identity scope and require no post-write recomputation.
11. **Never summarize or quote original tickets.** Include detected links only, and omit the section when no link is found.

## Final response

State:
- which initiative and change workspace were updated
- the PR URL, number, branch, and derived PR status
- whether merge evidence is complete for archive
- that `story.md → Status:` was left unchanged
- whether `gh` enrichment/body update was used
- one branch-specific final suggestion selected from the durable/live PR evidence; never list all branches together

End every success or abort response with:

```markdown
Suggested next action: <scalar route; leave empty only for a lifecycle dual route>
- Converge wrapper: <command; lifecycle dual routes only>
- Non-looped pass: <state-correct command; lifecycle dual routes only>
Choose one; do not run both.
```

For a scalar route, put its value on the label line and omit the three dual-route lines. Lifecycle entry failures that legitimately offer wrapper/direct routes leave the label empty and render those three lines immediately after it.

For an eligible locally DONE story, select exactly one exhaustive PR route from current durable/live evidence, in precedence order:
- stale, unavailable, incomplete, or conflicting PR/merge evidence -> `/openspec-pr <initiative> <story-slug> <url>` to refresh the same PR record
- merged with complete merge commit and merged-at evidence -> `/openspec-archive <initiative> <story-slug>`
- closed without merge -> `Operator decision: choose whether to reopen the closed PR or explicitly create/attach a replacement PR.`
- requested changes or actionable reviewer feedback -> `/openspec-feedback <initiative> --pr <url>`
- open draft (`isDraft: true`) -> `Operator decision: keep the PR in draft or mark it ready for review.`
- open, non-draft, approved but unmerged -> `Wait: PR approved and awaiting merge.`
- open, non-draft, clean/no-requested-changes and not yet approved -> `Wait for PR review.`

Also use one scalar route for each open-mode failure: default branch -> check out/create and push the story feature branch, then rerun with `OPEN=true`; `gh` unavailable/create failure -> open manually, then rerun with the explicit PR URL in attach mode; operator declines OPEN with no existing PR -> pass an existing PR URL or explicitly rerun with `OPEN=true`. Do not combine these routes.

`isDraft` refines only the open-PR next-action message; it does not alter PR status authority or `story.md → Status:`. Non-DONE candidates are diagnostic only, never resolved context. DONE with non-approved Plan uses only the operator contradiction-reconciliation action. Entry-condition failures use only the state-dependent routing defined above.
