#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lint.sh
source "$SCRIPT_DIR/lint.sh"
lint_suite_bootstrap || exit 1
lint_collect_source_inventory
# Aggregate primary reports generator failures and leaves shared trees ready.
# Standalone execution still generates both trees in its own private root.
if [[ "$LINT_USING_AGGREGATE_ROOT" != 1 || "${LINT_AGGREGATE_GENERATED_READY:-}" != 1 ]]; then
  lint_generate_silently || true
fi
lint_collect_generated_inventory
lint_workflow_contracts() {
  echo "lint: OpenSpec lifecycle semantic invariants"

  CANONICAL_SLUG_REGEX='^[a-z0-9]+(?:-[a-z0-9]+)*$'
  STORY_TEMPLATE="$REPO_ROOT/openspec/schemas/story-change/templates/story.md"
  PROGRESS_TEMPLATE="$REPO_ROOT/openspec/schemas/story-change/templates/progress.md"
  CONVENTIONS_DOC="$REPO_ROOT/docs/openspec-conventions.md"
  LIFECYCLE_DOC="$REPO_ROOT/docs/openspec-lifecycle.md"

  # Exact frontmatter key/token parsing is itself an invariant: duplicate keys or
  # malformed suffixes must not silently select a permissive value/token prefix.
  check_frontmatter_duplicate_detector
  check_allowed_tool_tokenizer

  # Story binding and operator-explicit review menus use story.md as authority.
  # Zero-reference legacy acceptance is permitted only after an initiative is
  # explicit/menu-selected; initiative discovery itself lists only bound stories.
  require_literal "initiative binding template" "$STORY_TEMPLATE" 'Initiative: <initiative-slug>'
  require_schema_writer story 'Initiative:'
  require_workflow_literal "initiative binding writer" openspec-story-plan 'Initiative: <initiative-slug>'
  check_workflow_contract \
    "implementation review bound-story menu" openspec-story-review \
    'a canonical top-level `Initiative:` header wins; otherwise only a unique exact `## Story Candidates` association binds the legacy workspace.' \
    'Exclude malformed, conflicting, multiply-associated, and zero-reference legacy workspaces from this initiative menu because no explicit initiative has yet accepted them.' \
    'Enumerate only workspaces explicitly bound to it or uniquely candidate-associated with it.' \
    'If no initiative references it, accept only when `<explicit_pair>` is true; emit a compatibility warning and do not backfill the header.'
  check_workflow_contract \
    "planning review bound-story menu" openspec-story-plan-review \
    'For menu/discovery scans, enumerate active `<root>/openspec/changes/*/story.md` workspaces across `<candidate_roots>`; never drive membership from initiative prose.' \
    'Inventory the complete top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line.' \
    'any other malformed Initiative-like line halts without editing and reports every offending line. Never reinterpret malformed present input as zero-header legacy.' \
    'No association is accepted only when `<explicit_pair>` is true and the selected initiative file exists.'
  require_literal "legacy initiative binding policy" "$CONVENTIONS_DOC" 'Legacy stories without an `Initiative:` header'
  check_workflow_contract \
    "feedback uniform explicit-pair legacy qualification" openspec-feedback \
    'Duplicate headers, empty values, malformed header syntax, or noncanonical values are hard conflicts, not legacy input; halt without relabeling or repair.' \
    'Every no-header target qualifies for any story disposition, including status-only resume or receipt backfill, only after the operator acknowledges a plan that names the exact `<initiative-slug>` + `<story-slug>` pair' \
    'a refreshed scan proves that no other initiative has an exact Story Candidates reference.'
  check_workflow_contract \
    "feedback initiative-only authoritative root" openspec-feedback \
    'Set `<receipt_root>` exactly once for the invocation.' \
    'Never default an initiative-only batch blindly to `<launch_root>`.' \
    'including an initiative-only batch, refresh `git worktree list --porcelain`, rerun Phase 0' \
    're-read `<receipt_root>/openspec/initiatives/<initiative-slug>/initiative.md` and revalidate every initiative-only disposition against that authoritative context'

  # Next-action resolves selected and broad-scan stories across candidate roots
  # before lifecycle routing and never silently chooses a stale duplicate.
  check_workflow_contract \
    "next-action transient root" openspec-next-action \
    'Build `<candidate_roots>` before declaring any target missing.' \
    'First inspect explicit `WORKTREE=` paths that are `<workspace_root>` or registered worktrees and contain the selected story plus its bound/associated initiative file.' \
    'Only when no explicit path qualifies, inspect registered worktrees other than `<workspace_root>`' \
    'Recompute all paths after selection.' \
    'aggregate active `openspec/changes/*/story.md` workspaces across `<candidate_roots>`'
  check_workflow_contract \
    "implementation review explicit-root precedence" openspec-story-review \
    'Inspect all explicit `WORKTREE=` values in either accepted form first.' \
    'If exactly one explicit candidate qualifies, set `<openspec_root>=<path>` immediately' \
    'Only when no explicit candidate qualifies, inspect registered root-repo worktrees other than `<workspace_root>`' \
    'that unique branch worktree outranks launch.'
  check_workflow_contract \
    "next-action exact Initiative-like binding validation" openspec-next-action \
    'Inventory the complete top-level header region before the first `## ` heading for every unindented `Initiative` or Initiative-like field line.' \
    'any other malformed Initiative-like line halts and reports every offending line. Never reinterpret malformed present input as a zero-header legacy story.' \
    'Only zero Initiative or Initiative-like lines is legacy.'
  check_workflow_contract \
    "next-action story-scoped DONE receipt and PR verification" openspec-next-action \
    'A modern DONE receipt qualifies only when exactly one section contains every canonical field exactly once' \
    'recompute canonical `review-identity-v1` from exactly the receipt-recorded `Identity bases` and `Identity paths` and require the result to equal `Identity digest`.' \
    'A bound modern DONE without a receipt routes only to the same fresh oblivious review.' \
    'whether the sole `## PR State` has exactly one non-placeholder `Verified implementation digest` equal to the receipt digest and one non-placeholder `Verified at` timestamp.'
  check_workflow_contract \
    "PR canonical story-scoped receipt identity and PR State write-back" openspec-pr \
    'A modern bound story requires exactly one complete canonical `progress.md → ## Implementation Review Receipt`' \
    'recompute the story-scoped identity with canonical `review-identity-v1` using exactly the receipt-recorded `Identity bases` and `Identity paths`.' \
    'Save the matching digest and the last pre-mutation UTC verification timestamp in memory for PR State write-back.' \
    'A bound modern DONE with an absent receipt routes only to the same fresh oblivious review' \
    'For a modern receipt, the verified digest must exactly equal its `Identity digest`; never carry forward an older verification timestamp or digest.'
  check_workflow_contract \
    "archive route-scoped receipt identity and PR State verification" openspec-archive \
    'At this phase validate receipt shape and remember its digest but do not recompute identity or mutate PR State' \
    'A bound modern DONE with an absent receipt routes only to fresh oblivious review.' \
    'The verified digest must exactly equal the current receipt'"'"'s `Identity digest`' \
    'Do not recompute identity in archive'"'"'s merged-PR route.' \
    'Only when `<archive_route>=no-pr` and a modern receipt exists, immediately before the first archive mutation' \
    'recompute canonical `review-identity-v1` from exactly its recorded `Identity bases` and `Identity paths`.'

  # A transient root may be reported operationally, but no artifact template or
  # artifact-writing command (including planning writers) may persist it.
  check_persisted_root_detector
  for artifact_template in "$REPO_ROOT"/openspec/schemas/story-change/templates/*.md; do
    if grep -Fq -- '<openspec_root>' "$artifact_template"; then
      fail "artifact template contains forbidden literal <openspec_root>: $artifact_template"
    elif awk '{ line=tolower($0); gsub(/[*_`]/, "", line); if (line ~ /openspec([ -]+artifact)?[ -]+root[[:space:]]*:/) bad=1 } END { exit bad ? 0 : 1 }' "$artifact_template"; then
      fail "artifact template persists an OpenSpec root field: $artifact_template"
    else
      ok "artifact template has no root literal or persisted OpenSpec root field: $artifact_template"
    fi
  done
  for skill_name in "${OPENSPEC_WORKFLOW_SKILLS[@]:-}"; do
    [[ -z "$skill_name" ]] && continue
    codex_name="$(hyphen_to_underscore "$skill_name")"
    for artifact_writer in \
      "$CLAUDE_SKILLS/$skill_name/SKILL.md" \
      "$CODEX_SKILLS/$codex_name/SKILL.md" \
      "$PI_SKILLS/$skill_name/SKILL.md"; do
      root_write_findings=""
      if root_write_findings="$(check_no_persisted_root_writes "$artifact_writer")"; then
        fail "artifact write clause persists OpenSpec root: $artifact_writer"
        printf '%s\n' "$root_write_findings" | sed 's/^/  /' >&2
      fi
    done
  done

  # Prerequisite lookup is a fixed ordered policy, avoiding slow prose-spanning
  # regular expressions and preventing archive from overriding an active copy.
  check_workflow_contract \
    "archived prerequisite fallback without mutable identity freshness" openspec-story-claim \
    'Resolve the active prerequisite first at `<openspec_root>/openspec/changes/<slug>/story.md`.' \
    'The active prerequisite is authoritative whenever that file exists' \
    'Only when the active prerequisite file is absent, fall back to `<openspec_root>/openspec/changes/archive/<slug>/story.md`.' \
    'Never let an archived DONE copy override an existing active prerequisite.' \
    'Check sibling `blocked.md` before trusting DONE: its existence makes the prerequisite contradictory and unsatisfied in both active and archived locations' \
    'A bound modern prerequisite must have `progress.md` containing exactly one `## Implementation Review Receipt` heading and one current body.' \
    'Missing, duplicate, malformed, or non-approving receipt evidence is unsatisfied.' \
    'never recompute or freshness-check the story-scoped review identity against mutable repository state.' \
    'Only an unbound pre-v3 prerequisite with `Status: ✅ DONE`, no `blocked.md`, zero Initiative headers, and zero receipt sections may satisfy without a receipt'
  check_workflow_contract \
    "review prerequisite/blocker/receipt contradictions" openspec-story-review \
    'if entry Status is already `✅ DONE`, a bound story must have exactly one well-formed current receipt with every required field exactly once' \
    'Only an unbound pre-v3 DONE story with zero Initiative headers and zero receipt sections gets bounded legacy compatibility' \
    'A sibling `blocked.md` makes the prerequisite contradictory and unsatisfied in active or archive, regardless of DONE or receipt evidence.' \
    'A bound modern prerequisite must have `progress.md` with exactly one `## Implementation Review Receipt` heading and one current body.' \
    'never recompute or freshness-check the story-scoped review identity against mutable repository state.' \
    'never recompute a prerequisite'"'"'s review identity.'
  for prerequisite_reader in openspec-story-resume openspec-story-converge; do
    check_workflow_contract \
      "prerequisite blocker/receipt/no-identity-freshness: $prerequisite_reader" "$prerequisite_reader" \
      'A sibling `blocked.md` makes the prerequisite contradictory and unsatisfied' \
      'A bound modern prerequisite must have `progress.md` with exactly one `## Implementation Review Receipt` heading and one current body.' \
      'never recompute or freshness-check the story-scoped review identity against mutable repository state.' \
      'Only an unbound pre-v3 prerequisite with DONE, no `blocked.md`, zero Initiative headers, and zero receipt sections may satisfy without a receipt'
  done

  # The receipt is one replace-in-place current record. Review validates in memory,
  # writes blocked.md when needed, writes the receipt, and writes Status last. For
  # non-DONE lanes a superseded receipt remains historical context only.
  require_literal "implementation review receipt template" "$PROGRESS_TEMPLATE" '## Implementation Review Receipt'
  forbid_literal "implementation review receipt is not in story template" "$STORY_TEMPLATE" '## Implementation Review Receipt'
  require_schema_writer progress 'Implementation Review Receipt'
  require_literal "single current receipt template" "$PROGRESS_TEMPLATE" 'Exactly one compact current completed-verdict body'
  require_literal "historical receipt for non-DONE template" "$PROGRESS_TEMPLATE" 'Status controls non-DONE routing, where an older receipt may be'
  CANONICAL_RECEIPT_FIELD_LIST='`Reviewed at`, `Decision`, `Approval gate`, `Status transition`, `Evidence reviewed`, `Identity method`, `Identity digest`, `Identity bases`, `Identity paths`, `Findings`, `Proof`, and `Next owner`'
  for receipt_reader in \
    openspec-story-claim openspec-story-resume \
    openspec-story-review openspec-story-converge; do
    require_workflow_literal \
      "canonical implementation receipt fields: $receipt_reader" \
      "$receipt_reader" \
      "$CANONICAL_RECEIPT_FIELD_LIST"
    for legacy_receipt_field in \
      'Review identity'" version" 'Review base'"/range" 'Review identity'" digest"; do
      forbid_workflow_literal \
        "no legacy implementation receipt field in $receipt_reader" \
        "$receipt_reader" \
        "$legacy_receipt_field"
    done
  done
  check_workflow_contract \
    "review canonical identity recording" openspec-story-review \
    'Record `Evidence reviewed` as a concise target/proof summary' \
    'Record `Identity method: review-identity-v1` exactly once.' \
    '`Identity bases` as one compact canonical JSON array' \
    '`Identity paths` as one compact canonical JSON array' \
    'Each manifest row is exactly `<repo>\t<path>\t<type>\t<lowercase-64-hex-sha256>\n`' \
    '`type` is exactly `file`, `executable`, `symlink`, or `deleted`.'
  check_workflow_contract \
    "review fail-closed receipt/status order" openspec-story-review \
    'Fail closed with this exact order:' \
    'create or update `<change_dir>/blocked.md` first' \
    'never append a duplicate receipt or retain receipt history there' \
    'Only after that succeeds, write the top-level `Status:` last' \
    'A non-approve verdict must not leave the story IN REVIEW and suggest another fresh review.'
  check_blocked_write_order
  check_workflow_contract \
    "review malformed receipt reconciliation" openspec-story-review \
    'Duplicate or malformed receipt sections are non-authoritative reconciliation inputs: do not choose a latest one' \
    'normalize all review-owned receipt sections to exactly one current receipt after the verdict' \
    'remove every old receipt section, and require exactly one normalized receipt in which each required field' \
    'If the normalized progress write succeeds but Status fails, report the exact receipt/Status mismatch and route explicit review-owned artifact reconciliation; do not call the verdict complete.' \
    'an APPROVE receipt with a failed Status write remains IN REVIEW, not legacy DONE.' \
    'Re-read all affected files and report `Receipt Write: failed` for any incomplete required pair.'
  check_workflow_contract \
    "planning review modern DONE receipt gate" openspec-story-plan-review \
    'inventory all `<change_dir>/progress.md → ## Implementation Review Receipt` headings.' \
    'A bound modern DONE story without a receipt routes to the same fresh oblivious review, never legacy compatibility.' \
    'Only a consistent DONE with a qualifying receipt or the exact zero-Initiative/zero-receipt pre-v3 exception' \
    'Do not recommend planning commands that reject DONE and do not invent a lifecycle owner.'
  check_workflow_contract \
    "historical receipt routing: openspec-story-converge" openspec-story-converge \
    'One well-formed unsuperseded section is current' \
    'historical' \
    'non-DONE'
  check_workflow_contract \
    "historical receipt routing: openspec-story-resume" openspec-story-resume \
    'One well-formed unsuperseded section is current.' \
    'historical context' \
    'non-DONE'

  # Feedback uses one invocation-wide receipt root, deterministic source identity
  # and FB allocation, Write for missing owned anchors, FB-tagged task/checkpoint
  # edits, and a receipt-only recovery path after a partial append failure.
  forbid_workflow_literal "initiative planning does not seed feedback receipts" openspec-initiative-plan '## Feedback Receipts'
  check_workflow_contract \
    "feedback rooted deterministic receipts" openspec-feedback \
    'Set `<receipt_root>` exactly once for the invocation.' \
    'Allocate new identities in their normalized input order.' \
    'The same Source ID with a different hash is a new identity.' \
    '`Write` is permitted only when a missing `progress.md`, `## Progress Timeline`, or `initiative.md → ## Feedback Receipts` section must be created' \
    'Any changed or added `tasks.md` row also includes `[FB-###]`' \
    'Receipt append failed after owned edits for FB-###.' \
    'reuse the same FB ID' \
    'construct its creation with the first acknowledged receipt' \
    'Append exactly one entry per stable identity'
  check_workflow_contract \
    "feedback receipt failure rollback/recovery" openspec-feedback \
    'If any owned edit or marker fails, stop before its receipt and later items.' \
    'Best-effort restore every file already written for that item from the retained item-baseline bytes, then verify every restored hash.' \
    'If rollback is incomplete, report every exact partially changed path with its current hash, expected item-baseline hash, and expected post-edit hash.' \
    'If a receipt append fails after owned edits succeeded, stop immediately; do not process later items, roll back or reapply successful owned edits, or allocate a different ID.' \
    'expected pre/post-receipt hashes so retry can reconcile a partial append.' \
    'Backfill only: reuse FB-### from the named FB marker under <receipt_root>; do not reapply owned edits.' \
    'reconcile any reported partial file first, and produce a receipt-only backfill plan.'
  require_literal "feedback receipt lifecycle contract" "$LIFECYCLE_DOC" '## Feedback Receipts'
  check_feedback_receipt_contract

  # Canonical/Codex feedback cannot require a notebook API. Pi may add optional
  # notebook orientation, but every disposition is already durable above.
  for portable_feedback_file in \
    "$CLAUDE_SKILLS/openspec-feedback/SKILL.md" \
    "$CODEX_SKILLS/openspec_feedback/SKILL.md"; do
    mapfile -t portable_feedback_tools < <(allowed_tool_tokens "$portable_feedback_file")
    for notebook_tool in notebook_index notebook_read notebook_write; do
      if in_array "$notebook_tool" "${portable_feedback_tools[@]:-}"; then
        fail "portable feedback has unconditional canonical notebook tool $notebook_tool: $portable_feedback_file"
      fi
    done
    if awk '
      {
        lower = tolower($0)
        if (lower ~ /notebook_(index|read|write)/ &&
            lower ~ /(use|scan|read|write|persist|required|must|abort|unavailable|not available)/ &&
            lower !~ /(optional|if available|when available|may use|may write)/) bad = 1
      }
      END { exit bad ? 0 : 1 }
    ' "$portable_feedback_file"; then
      fail "portable feedback has unconditional canonical notebook API instructions: $portable_feedback_file"
    fi
    if grep -Fq 'run this skill from a pi session' "$portable_feedback_file"; then
      fail "portable feedback has a Pi-only rerun requirement: $portable_feedback_file"
    fi
  done
  forbid_workflow_literal "portable feedback rejects no-receipt disposition" openspec-feedback 'No durable artifact write needed'

  # Pi may gather review-session evidence, but it may not import implementation
  # convergence context into a fresh implementation review.
  require_workflow_literal \
    "fresh implementation review firewall" \
    openspec-story-review \
    'Do not accept parent/converger notebook references'
  forbid_literal \
    "Pi review firewall fragment" \
    "$PI_FRAGMENTS/openspec-story-review.md" \
    'openspec-research-<initiative_slug>-<story_slug>'
  forbid_literal \
    "Pi review firewall generated skill" \
    "$PI_SKILLS/openspec-story-review/SKILL.md" \
    'openspec-research-<initiative_slug>-<story_slug>'

  # blocked.md is the hard gate: review must create/update it before writing
  # BLOCKED status, and resume may normalize stale BLOCKED only after absence.
  require_workflow_literal \
    "implementation review blocker receipt" \
    openspec-story-review \
    'create or update `<change_dir>/blocked.md` first'
  require_workflow_literal \
    "resume unblock signal" \
    openspec-story-resume \
    'If `blocked.md` is absent but `story.md → Status:` contains `⛔ BLOCKED`'

  # Canonical lifecycle/header spelling is intentionally scoped to the commands
  # that currently read or write those anchors. Positive top-level-only wording
  # prevents a stale alternate-section ban from being the sole guard.
  require_literal "canonical story Status template" "$STORY_TEMPLATE" 'Status: ⚪ TODO'
  require_workflow_literal \
    "implementation review requires top-level Status header" \
    openspec-story-review \
    'top-level `Status:` header'
  forbid_workflow_literal \
    "implementation review rejects alternate Status section" \
    openspec-story-review \
    'has an equivalent (e.g., an `## Status` section'
  require_literal "canonical Acceptance template" "$STORY_TEMPLATE" '## Acceptance'
  for skill_name in openspec-story-claim openspec-story-resume; do
    require_workflow_literal "canonical Acceptance reader: $skill_name" "$skill_name" '## Acceptance'
    forbid_workflow_literal "no stale Acceptance Criteria heading: $skill_name" "$skill_name" '## Acceptance Criteria'
  done

  # Slugs and executable tool permissions are exact contracts, not prose hints.
  for skill_name in "${OPENSPEC_WORKFLOW_SKILLS[@]:-}"; do
    [[ -z "$skill_name" ]] && continue
    require_workflow_literal "canonical slug regex: $skill_name" "$skill_name" "$CANONICAL_SLUG_REGEX"
  done
  check_allowed_tools_contract \
    openspec-initiative-plan \
    Read Grep Glob Write 'Bash(mkdir -p:*)' 'Bash(git status:*)' 'Bash(git log:*)'
  check_allowed_tools_contract \
    openspec-feedback \
    Read Edit Grep Glob 'Bash(gh pr view:*)' 'Bash(gh api:*)' 'Bash(date -u:*)' 'Bash(printf:*)' 'Bash(sha256sum:*)' 'Bash(shasum:*)'
  check_allowed_tools_exact \
    openspec-story-plan-converge \
    Read Edit Grep Glob Task 'Bash(git status:*)' 'Bash(git worktree list:*)'
  check_allowed_tools_exact \
    openspec-story-converge \
    Read Grep Glob Task 'Bash(git status:*)' 'Bash(git worktree list:*)'
  check_allowed_tools_contract \
    openspec-story-review \
    Read Edit Write Grep Glob Task Bash

  # Schema and template ownership must name the complete current writer set.
  for writer in /openspec-story-plan /openspec-story-plan-resume; do
    require_schema_writer proposal "$writer"
    require_template_writer proposal "$writer"
    require_schema_writer specs "$writer"
    require_template_writer spec "$writer"
  done
  for writer in \
    /openspec-story-plan /openspec-story-plan-review /openspec-story-plan-resume \
    /openspec-story-claim /openspec-story-resume /openspec-feedback \
    /openspec-story-review; do
    require_schema_writer story "$writer"
    require_template_writer story "$writer"
  done
  for writer in /openspec-story-plan /openspec-story-plan-resume /openspec-feedback; do
    require_schema_writer design "$writer"
    require_template_writer design "$writer"
  done
  for writer in \
    /openspec-story-plan /openspec-story-plan-resume /openspec-story-claim \
    /openspec-story-resume /openspec-feedback; do
    require_schema_writer tasks "$writer"
    require_template_writer tasks "$writer"
  done
  require_schema_writer specs '/opsx:archive'
  for writer in \
    /openspec-story-claim /openspec-story-resume /openspec-feedback \
    /openspec-story-review /openspec-pr; do
    require_schema_writer progress "$writer"
    require_template_writer progress "$writer"
  done
  for writer in /openspec-story-claim /openspec-story-resume /openspec-story-review; do
    require_schema_writer blocked "$writer"
    require_template_writer blocked "$writer"
  done

  # Resume may use notebooks for sourced orientation only; artifacts settle any
  # conflict and carry the implementation/review/feedback authority.
  require_workflow_literal \
    "artifact-over-notebook resume authority" \
    openspec-story-resume \
    'Canonical artifacts outrank notebook orientation.'
  forbid_workflow_literal \
    "artifact-over-notebook removes notebook precedence" \
    openspec-story-resume \
    'the contract and notebook take precedence'
  forbid_workflow_literal \
    "artifact-over-notebook removes notebook conflict prompt" \
    openspec-story-resume \
    'If notebook orientation conflicts with the change workspace artifacts, flag the conflict and ask the operator to resolve.'

  # PR extraction must use the full canonical selector to the actual level-three
  # subsection; checking an isolated backticked heading misses stale prose paths.
  for heading in 'Verification Commands' 'Test Architecture Plan' 'Acceptance Proof Matrix'; do
    require_workflow_literal \
      "PR canonical full selector: $heading" \
      openspec-pr \
      "story.md → ## Verification → ### $heading"
    forbid_workflow_literal \
      "PR stale full selector: $heading" \
      openspec-pr \
      "story.md → ## Verification → ## $heading"
  done

  # PR descriptions must orient a cold reader with an evidence-backed catalyst and
  # causal boundary without displacing the product verification contract.
  check_workflow_contract \
    "PR catalyst-first cold-reader summary" openspec-pr \
    '`story.md → ## Triggering Need` → Summary' \
    '`proposal.md → ## Goal / Context` → Summary' \
    'Start with the source-supported catalyst' \
    'State the observable before state and the user-visible after state' \
    'If the artifacts state no catalyst, lead with the strongest source-supported Goal, Purpose, or outcome without inventing a gap, history, or causality.' \
    'source-supported catalyst context, user-visible before/after state, and external compatibility facts belong when they remain true regardless of implementation.' \
    'Never infer chronology or causality' \
    'define it only from source-supported context' \
    'Do not let the Summary replace or weaken Requirements, Acceptance criteria, Contract changes, Out of scope, or How to verify.'
  forbid_workflow_literal \
    "PR removes outcome-only summary template" openspec-pr \
    '<one short paragraph in product language — the user-visible outcome this PR delivers>'

  # Rootless archive mutation is forbidden: a remote active root produces an exact
  # cd-and-rerun handoff. Broad PR discovery filters unrelated bound stories while
  # still halting a conflict on an explicitly selected story.
  check_workflow_contract \
    "archive remote-root rerun" openspec-archive \
    'If the selected or identified active checkout differs from `<workspace_root>`, halt before any PR refresh, artifact edit, `/opsx:archive`, or initiative update.' \
    'Print the exact two-step rerun: `cd <active-root>` followed by `/openspec-archive <initiative-slug> <story-slug>`.' \
    'The current rootless adapter is never invoked against a different checkout'
  check_workflow_contract \
    "PR unrelated story filtering" openspec-pr \
    'filter a well-formed story bound to another initiative as unrelated instead of halting the PR scan' \
    'filter well-formed stories bound to other initiatives as unrelated rather than halting' \
    'A conflict on an explicitly selected story still halts.'

  # Every IN REVIEW diagnostic names an executable fresh-review command; it does
  # not return a prose-only owner or send implementation review through a wrapper.
  check_workflow_contract \
    "next-action IN REVIEW executable route" openspec-next-action \
    '/openspec-story-review <initiative> <story-slug>' \
    'The current Status owns this route'
  check_workflow_contract \
    "archive IN REVIEW executable route" openspec-archive \
    '/openspec-story-review <initiative-slug> <story-slug>' \
    'If `Status: 🟣 IN REVIEW`'
  check_workflow_contract \
    "PR IN REVIEW executable route" openspec-pr \
    '/openspec-story-review <initiative> <story-slug>' \
    '`Status: 🟣 IN REVIEW` -> one fresh, oblivious'
  check_workflow_contract \
    "plan-review IN REVIEW executable route" openspec-story-plan-review \
    '/openspec-story-review <initiative-slug> <story-slug>' \
    'If it is `🟣 IN REVIEW`, abort plan review'

  # A genuinely absent story routes to creation; incomplete existing workspaces
  # route to repair. These exact creation routes avoid a resume dead end.
  require_workflow_literal \
    "missing story recovery: next-action" \
    openspec-next-action \
    '/openspec-story-plan INITIATIVE=<initiative>'
  require_workflow_literal \
    "missing story recovery: openspec-story-plan-converge" \
    openspec-story-plan-converge \
    '/openspec-story-plan INITIATIVE=<initiative>'
  for skill_name in \
    openspec-story-plan-resume openspec-story-plan-review \
    openspec-story-resume openspec-story-review; do
    require_workflow_literal \
      "missing story recovery: $skill_name" \
      "$skill_name" \
      '/openspec-story-plan INITIATIVE=<initiative-slug>'
  done

  require_exact_line \
    "README Claude update guidance does not force symlinks" \
    "$REPO_ROOT/README.md" \
    'scripts/install.sh --yes --agents claude'
  require_exact_line \
    "README Codex update guidance forces generated refresh" \
    "$REPO_ROOT/README.md" \
    'scripts/install.sh --yes --agents codex --force'
  require_exact_line \
    "README Pi update guidance forces generated refresh" \
    "$REPO_ROOT/README.md" \
    'scripts/install.sh --yes --agents pi --force'
  check_no_all_runtime_force_guidance "$REPO_ROOT/README.md"

}

lint_workflow_contracts
exit "$FAIL"
