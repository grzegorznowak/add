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

reviewer_semantic_findings() {
  local file="$1"
  markdown_without_comments "$file" | awk '
    function has_target(text) {
      return text ~ /(^|[^a-z])((story|progress|blocked)(\.md)?|status)([^a-z]|$)/
    }
    function has_direct_target(text) {
      return text ~ /(^|[^a-z])(story|progress|blocked)\.md([^a-z]|$)/ ||
        text ~ /(^|[^a-z])status([^a-z]|$)/
    }
    function has_publication_target(text) {
      return text ~ /(^|[^a-z])(receipt|timeline)([^a-z]|$)/
    }
    function nearby(word, first, last, i) {
      if (first < 1) first = 1
      if (last > count) last = count
      for (i = first; i <= last; i++)
        if (tokens[i] == word) return 1
      return 0
    }
    function target_nearby(first, last, i) {
      if (first < 1) first = 1
      if (last > count) last = count
      for (i = first; i <= last; i++)
        if (tokens[i] == "progress" ||
            tokens[i] == "receipt" ||
            tokens[i] == "timeline") return 1
      return 0
    }
    function contains_forbidden_verb(text, words, parts, part_count, i) {
      words = text
      gsub(/[^a-z]+/, " ", words)
      sub(/^[[:space:]]+/, "", words)
      sub(/[[:space:]]+$/, "", words)
      part_count = split(words, parts, /[[:space:]]+/)
      for (i = 1; i <= part_count; i++)
        if (forbidden_token(parts[i])) return 1
      return 0
    }
    function forbidden_token(token) {
      return token ~ /^(write|edit|create|update|replace|overwrite|append|publish|mutate|modify|save|persist|rewrite|delete)$/
    }
    function starts_with_forbidden_verb(text, token) {
      token = text
      sub(/[^a-z].*$/, "", token)
      return forbidden_token(token) || token ~ /^(touch|touches)$/
    }
    function negation_adverb(token) {
      return token ~ /^(ever|again|directly|immediately|explicitly|silently|blindly|automatically)$/
    }
    function verb_negated(parts, i, j, first) {
      first = i - 3
      if (first < 1) first = 1
      for (j = i - 1; j >= first; j--) {
        if (parts[j] == "not" || parts[j] == "never" ||
            parts[j] == "cannot") return 1
        if (!negation_adverb(parts[j])) return 0
      }
      return 0
    }
    function contains_affirmative_forbidden_verb(text, words, parts, part_count, i) {
      words = text
      gsub(/can.t/, "cannot", words)
      gsub(/[^a-z]+/, " ", words)
      sub(/^[[:space:]]+/, "", words)
      sub(/[[:space:]]+$/, "", words)
      part_count = split(words, parts, /[[:space:]]+/)
      for (i = 1; i <= part_count; i++)
        if (forbidden_token(parts[i]) && !verb_negated(parts, i)) return 1
      return 0
    }
    function reviewer_mutating_token(token) {
      return forbidden_token(token) ||
        token ~ /^(writes|edits|creates|updates|replaces|overwrites|appends|publishes|mutates|modifies|saves|persists|rewrites|deletes|remove|removes|set|sets|change|changes|touch|touches)$/
    }
    function contains_affirmative_reviewer_verb(text, words, parts, part_count, i) {
      words = text
      gsub(/can.t/, "cannot", words)
      gsub(/[^a-z]+/, " ", words)
      sub(/^[[:space:]]+/, "", words)
      sub(/[[:space:]]+$/, "", words)
      part_count = split(words, parts, /[[:space:]]+/)
      for (i = 1; i <= part_count; i++)
        if (reviewer_mutating_token(parts[i]) && !verb_negated(parts, i)) return 1
      return 0
    }
    function direct_assignment_mutation(text) {
      if (text ~ /^(always[[:space:]]+)?(set|change)[[:space:]]+((story|progress|blocked)\.md|status|the[[:space:]]+top-level[[:space:]]+status)([^a-z]|$)/)
        return 1
      if (text ~ /^remove[[:space:]]+((story|progress|blocked)\.md|status|(the[[:space:]]+)?(receipt|timeline))([^a-z]|$)/)
        return 1
      return text ~ /^((the|an)[[:space:]]+)?(reviewers?|you|agents?)([^a-z]|$)/ &&
        (has_direct_target(text) || has_publication_target(text)) &&
        contains_affirmative_reviewer_verb(text)
    }
    function direct_publication_mutation(text) {
      return starts_with_forbidden_verb(text) && has_publication_target(text)
    }
    function imperative_mutation(text) {
      if (starts_with_forbidden_verb(text)) return 1
      if (!contains_affirmative_forbidden_verb(text)) return 0
      if (text ~ /^(do not|never|must not|may not|cannot|can.t)[[:space:]]+(permit|allow|enable|instruct|tell|ask)([^a-z]|$)/)
        return 0
      if (text ~ /^(always|after|before|once|when|if|upon)([^a-z]|$)/)
        return 1
      if (text ~ /^((the|an)[[:space:]]+)?(reviewers?|review|you|agents?)([^a-z]|$)/)
        return 1
      return text ~ /^(do not|never|must not|may not|cannot|can.t)([^a-z]|$)/
    }
    function has_then_mutation(text, tails, tail_count, clauses, clause_count, i, j) {
      gsub(/(^|[^a-z])then([^a-z]|$)/, "\035", text)
      tail_count = split(text, tails, "\035")
      for (i = 2; i <= tail_count; i++) {
        gsub(/[,;]/, "\034", tails[i])
        clause_count = split(tails[i], clauses, "\034")
        for (j = 1; j <= clause_count; j++)
          if (contains_affirmative_forbidden_verb(clauses[j]) &&
              has_target(clauses[j])) return 1
      }
      return 0
    }
    function has_mutation_clause(text, clauses, clause_count, i) {
      if (direct_assignment_mutation(text) || direct_publication_mutation(text)) return 1
      if (has_then_mutation(text)) return 1
      gsub(/[,;]/, "\034", text)
      clause_count = split(text, clauses, "\034")
      for (i = 1; i <= clause_count; i++) {
        sub(/^[[:space:][:punct:]]+/, "", clauses[i])
        if (imperative_mutation(clauses[i]) && has_target(clauses[i])) return 1
      }
      return 0
    }
    function relation_negated(first, last, i) {
      if (first < 1) first = 1
      if (last > count) last = count
      for (i = first; i <= last; i++)
        if (tokens[i] == "not" || tokens[i] == "never" ||
            tokens[i] == "cannot") return 1
      return 0
    }
    function has_order_override(i, j) {
      if (readonly_order_context || invalid_order_context) return 0
      for (i = 1; i <= count; i++) {
        if (tokens[i] == "before" &&
            nearby("status", i - 6, i - 1) &&
            target_nearby(i + 1, i + 6) &&
            !relation_negated(i - 6, i + 6)) return 1
        if (((tokens[i] == "ahead" && tokens[i + 1] == "of") ||
             (tokens[i] == "prior" &&
              (tokens[i + 1] == "to" || tokens[i + 1] == "of"))) &&
            nearby("status", i - 6, i - 1) &&
            target_nearby(i + 2, i + 7) &&
            !relation_negated(i - 6, i + 7)) return 1
        if ((tokens[i] == "after" || tokens[i] == "behind") &&
            target_nearby(i - 6, i - 1) &&
            nearby("status", i + 1, i + 6) &&
            !relation_negated(i - 6, i + 6)) return 1
        if (tokens[i] == "after" &&
            nearby("status", i + 1, i + 4) &&
            target_nearby(i + 2, i + 10) &&
            !relation_negated(i, i + 10)) return 1
        if (tokens[i] == "first" &&
            nearby("status", i - 4, i - 1) &&
            target_nearby(i + 1, i + 8) &&
            !relation_negated(i - 4, i + 8)) return 1
        if (tokens[i] == "first")
          for (j = i + 1; j <= count && j <= i + 8; j++)
            if (tokens[j] == "next" &&
                nearby("status", i + 1, j - 1) &&
                target_nearby(j + 1, j + 6) &&
                contains_affirmative_forbidden_verb(line) &&
                !relation_negated(i, j + 6)) return 1
        if (tokens[i] == "then" &&
            nearby("status", i - 6, i - 1) &&
            target_nearby(i + 1, i + 6) &&
            !relation_negated(i - 6, i + 6)) return 1
        if (tokens[i] == "precede" &&
            nearby("status", i - 4, i - 1) &&
            target_nearby(i + 1, i + 5) &&
            !relation_negated(i - 4, i + 5)) return 1
        if (tokens[i] == "followed" && tokens[i + 1] == "by" &&
            nearby("status", i - 4, i - 1) &&
            target_nearby(i + 2, i + 6) &&
            !relation_negated(i - 4, i + 6)) return 1
      }
      return 0
    }
    {
      raw = $0
      line = tolower(raw)
      gsub(/`/, "", line)
      imperative = line
      sub(/^[[:space:]]*/, "", imperative)
      while (sub(/^([-*+]|[0-9]+[.)])[[:space:]]+/, "", imperative)) { }
      if (has_mutation_clause(imperative))
        print "mutation:" FNR ":" raw
      readonly_order_context = (imperative ~ /^(read|inspect|check|verify|compare|compute|locate|find|grep)([^a-z]|$)/ && !contains_forbidden_verb(imperative))
      invalid_order_context = (imperative ~ /^(reject|forbid)([^a-z]|$)/ || imperative ~ /(^|[^a-z])as invalid([^a-z]|$)/)
      order_line = line
      sub(/^.*[;:][[:space:]]*/, "", order_line)
      words = order_line
      gsub(/[^a-z]+/, " ", words)
      sub(/^[[:space:]]+/, "", words)
      sub(/[[:space:]]+$/, "", words)
      count = split(words, tokens, /[[:space:]]+/)
      split_order_override = (pending_status_first &&
        imperative ~ /^next([^a-z]|$)/ && has_target(imperative) &&
        contains_affirmative_forbidden_verb(imperative))
      if (has_order_override() || split_order_override)
        print "status-order:" FNR ":" raw
      starts_status_first = (imperative ~ /^first([^a-z]|$)/ &&
        line ~ /(^|[^a-z])status([^a-z]|$)/ &&
        contains_affirmative_forbidden_verb(imperative))
      if (starts_status_first)
        pending_status_first = 1
      else if (imperative !~ /^[[:space:]]*$/)
        pending_status_first = 0
    }
  '
}

stale_done_review_route_findings() {
  local file="$1"
  markdown_without_comments "$file" | awk 'BEGIN { RS="" }
    function bad_receipt_evidence(text) {
      return text ~ /(^|[^a-z])receiptless([^a-z]|$)/ ||
        text ~ /(missing|absent|lacking|duplicate|duplicated|malformed|non-approving|invalid|incomplete|truncated)[^.!?;]*(implementation[[:space:]]+review[[:space:]]+|approval[[:space:]]+)?receipt/ ||
        text ~ /receipt[[:space:]-]+(evidence|fields?|sections?|records?)[^.!?;]*(missing|absent|duplicate|duplicated|malformed|non-approving|invalid|incomplete|truncated)/ ||
        text ~ /receipt[[:space:]]+(is[[:space:]]+)?(missing|absent|duplicate|duplicated|malformed|non-approving|invalid|incomplete|truncated)/ ||
        text ~ /(^|[^a-z])(without|with[[:space:]]+no|no)[[:space:]]+(an?[[:space:]]+)?((implementation|approval|completed-review)[[:space:]]+)?receipt([^a-z]|$)/
    }
    function rejected_quotation(text) {
      return text ~ /(^|[^a-z])(reject|rejects|rejected|quote|quotes|quoted)[^.!?;]*(rule|claim|wording|statement)/
    }
    function feedback_route(text) {
      return text ~ /(route|routes|routed|return|returns|returned|send|sends|sent|use|uses)[^.!?;]*(ordinary[ -])?(\/openspec-)?feedback/
    }
    function affirmative_review_route(text, target, route) {
      target = "(/openspec-story-review|fresh[ -]review[[:space:]]+route|fresh[[:space:]]+(oblivious[[:space:]]+|substantive[[:space:]]+)?review)"
      route = "(route|routes|routed|return|returns|returned|send|sends|sent|recommend|recommends|recommended|open|opens|run|runs|invoke|invokes|launch|launches|hand off|hands off|direct|directs|use|uses)"
      if (rejected_quotation(text)) return 0
      if (text ~ "(never|do not|does not|must not|may not|cannot|can.t)[^.!?;]*" route "[^.!?;]*" target ||
          text ~ route "[^.!?;]*(not[[:space:]]+to|rather[[:space:]]+than|instead[[:space:]]+of)[[:space:]]*" target ||
          text ~ route "[^.!?;]*(ordinary[[:space:]]+)?feedback[^.!?;]*(not[[:space:]]+|rather[[:space:]]+than|instead[[:space:]]+of)[^.!?;]*" target ||
          text ~ route "[^.!?;]*(ordinary[ -])?(\/openspec-)?feedback[^.!?;]*" target)
        return 0
      return text ~ route "[^.!?;]*" target ||
        text ~ /(return|returns|returned)[[:space:]]+to[[:space:]]+(implementation[ -])?review([^a-z]|$)/
    }
    {
      raw = $0
      paragraph = tolower(raw)
      gsub(/`/, "", paragraph)
      count = split(paragraph, sentences, /[.!?;]+[[:space:]]*/)
      done_context = paragraph ~ /(^|[^a-z])(done|bound[[:space:]]+modern|modern[[:space:]]+(done|receipt))([^a-z]|$)/
      receipt_feedback_context = bad_receipt_evidence(paragraph) && feedback_route(paragraph)
      for (c = 1; c <= count; c++)
        if (done_context && affirmative_review_route(sentences[c]) &&
            (bad_receipt_evidence(sentences[c]) ||
             (!receipt_feedback_context && c > 1 && bad_receipt_evidence(sentences[c - 1]) && !feedback_route(sentences[c - 1])) ||
             (!receipt_feedback_context && c < count && bad_receipt_evidence(sentences[c + 1]) && !feedback_route(sentences[c + 1])))) {
          one_line = raw
          gsub(/\n/, " ", one_line)
          print "stale-done-review-route:paragraph-" NR ":" one_line
          next
        }
    }
  '
}

review_receipt_ownership_findings() {
  local file="$1"
  markdown_without_comments "$file" | awk '
    function clause_finding(clause, subject, artifact, action) {
      subject = "((the|a)[[:space:]]+)?(\/openspec[ -]story[ -]review|(fresh[[:space:]]+)?(substantive[ -]|readonly[ -]|implementation[ -])?(review|reviewer|reviewers))"
      artifact = "(receipt([[:space:]]+(publication|normalization))?|normalization|status([[:space:]]+transition)?|((completed[ -]review[[:space:]]+)?timeline)([[:space:]]+transition)?|local[[:space:]]+completion|blocker|blocked\\.md)"
      action = "(write|writes|wrote|written|create|creates|created|replace|replaces|replaced|normalize|normalizes|normalized|publish|publishes|published|set|sets|transition|transitions|transitioned|mutate|mutates|mutated|update|updates|updated|own|owns|owned|ownership|responsible)"
      sub(/^[[:space:]]*<[^>]*>/, "", clause)
      if (clause ~ /(never|not|cannot|can.t)[^.;]*(write|create|replace|normalize|publish|set|transition|mutate|update|own|responsible)/ ||
          clause ~ subject "[^.;]*(write|create|replace|normalize|publish|set|transition|mutate|update|own)[^.;]*no[[:space:]]+receipt" ||
          clause ~ artifact "[^.;]*(is|are|be|been)[^.;]*(not|never)[^.;]*(owned|written|created|replaced|normalized|published|set|transitioned|mutated|updated)" ||
          clause ~ /(rather[[:space:]]+than|instead[[:space:]]+of)[[:space:]]+(an?[[:space:]]+|the[[:space:]]+)?(implementation[ -])?(review|reviewer|reviewers|\/openspec[ -]story[ -]review)/)
        return 0
      if (clause ~ subject "[^.;]*(author|authors|authored)[^.;]*(target[[:space:]]+status|timeline[[:space:]]+transition|blocker[[:space:]]+body)[^.;]*handoff") return 0
      if (clause ~ subject "[^.;]*(author|authors|authored|approve|approves|approved|evaluate|evaluates|evaluated|return|returns|returned)[^.;]*feedback[^.;]*" action) return 0
      return clause ~ "^[^a-z]*" subject "[^.;]*" action "[^.;]*" artifact ||
        clause ~ "^[^a-z]*" subject "[^.;]*(responsible[[:space:]]+for)[^.;]*" artifact ||
        clause ~ artifact "[^.;]*(is|are|be|been)[^.;]*(written|created|replaced|normalized|published|set|transitioned|mutated|updated|owned)[^.;]*by[[:space:]]+(the[[:space:]]+)?" subject ||
        clause ~ artifact "[^.;]*(belongs|belong)[[:space:]]+to[[:space:]]+" subject
    }
    {
      raw = $0
      line = tolower(raw)
      gsub(/`/, "", line)
      count = split(line, clauses, /[.;]/)
      for (c = 1; c <= count; c++)
        if (clause_finding(clauses[c])) {
          print "review-receipt-ownership:" FNR ":" raw
          next
        }
    }
  '
}

blanket_fresh_review_route_findings() {
  local file="$1"
  markdown_without_comments "$file" | awk '
    {
      raw=$0; line=tolower(raw); gsub(/`/, "", line)
      if (line ~ /(^|[^a-z])(every|all|any)[^.;]*(fail|failed|failure|condition|gate|recheck)[^.;]*(route|routes|use|uses|return|returns)[^.;]*fresh[ -]review/ ||
          line ~ /(^|[^a-z])(every|all|any)[^.;]*(fail|failed|failure|condition|gate|recheck)[^.;]*\/openspec[ -]story[ -]review/)
        print "blanket-fresh-review-route:" FNR ":" raw
    }
  '
}

plan_review_status_ownership_findings() {
  local file="$1"
  markdown_without_comments "$file" | awk '
    {
      raw=$0; line=tolower(raw); gsub(/`/, "", line)
      subject="(\/openspec[ -]story[ -]plan[ -]review|plan(ning)?[ -]review)"
      count=split(line, clauses, /[.;]|[[:space:]]+and[[:space:]]+/)
      for (c=1; c<=count; c++) {
        clause=clauses[c]
        if (clause ~ /(does|do|must)[[:space:]]+not[^.;]*(set|write|update|transition|own)/) continue
        if (clause ~ subject "[^.;]*(set|sets|write|writes|update|updates|transition|transitions|own|owns|owned|responsible)[^.;]*(implementation[[:space:]]+)?status" ||
            clause ~ "(implementation[[:space:]]+)?status[^.;]*(is|be|been)[^.;]*(set|written|updated|transitioned|owned)[^.;]*by[[:space:]]+" subject) {
          print "plan-review-status-ownership:" FNR ":" raw
          next
        }
      }
    }
  '
}

extract_progress_transform_block() {
  local input="$1"
  local output="$2"
  local anchor='The canonical progress-byte transform used by both review and feedback is:'

  awk -v anchor="$anchor" '
    $0 == anchor {
      anchors++
      if (anchors == 1) {
        print
        capture = 1
        expect_blank = 1
      }
      next
    }
    capture && expect_blank {
      if ($0 != "") bad = 1
      print
      expect_blank = 0
      step = 1
      next
    }
    after_block {
      if ($0 ~ /^## /) {
        after_block = 0
      } else {
        continuation = $0
        sub(/^[[:space:]]*/, "", continuation)
        sub(/^[-*+][[:space:]]+/, "", continuation)
        if (continuation ~ /^[0-9]+[.)][[:space:]]/) {
          number = continuation
          sub(/[.)].*/, "", number)
          if ((number + 0) >= 8) bad = 1
        }
      }
    }
    capture && expect_end_blank {
      if ($0 != "") bad = 1
      print
      capture = 0
      complete++
      after_block = 1
      next
    }
    capture {
      if (index($0, step ". ") != 1) bad = 1
      print
      if (step == 7) expect_end_blank = 1
      step++
      next
    }
    END {
      if (anchors != 1 || complete != 1 || capture || bad) exit 1
    }
  ' "$input" >"$output"
}

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

  # The evaluator is declaratively read-only in every distributed runtime.
  # Feedback explicitly clears Pi's sticky read-only state before publication.
  # Exact unquoted lines reject strings and duplicate/malformed YAML values.
  for readonly_contract in \
    'openspec-story-review true' \
    'openspec-feedback false'; do
    read -r readonly_skill readonly_expected <<<"$readonly_contract"
    readonly_codex="$(hyphen_to_underscore "$readonly_skill")"
    for readonly_file in \
      "$CLAUDE_SKILLS/$readonly_skill/SKILL.md" \
      "$CODEX_SKILLS/$readonly_codex/SKILL.md" \
      "$PI_SKILLS/$readonly_skill/SKILL.md"; do
      check_frontmatter_unique_keys "$readonly_file"
      readonly_count="$(awk -v expected="readonly: $readonly_expected" '
        NR == 1 && $0 == "---" { frontmatter = 1; next }
        frontmatter && $0 == "---" { exit }
        frontmatter && $0 == expected { count++ }
        END { print count + 0 }
      ' "$readonly_file")"
      readonly_actual="$(frontmatter_value "$readonly_file" readonly)"
      if [[ "$readonly_count" != 1 || "$readonly_actual" != "$readonly_expected" ]]; then
        fail "$readonly_file: readonly must be exactly one unquoted '$readonly_expected' boolean"
      else
        ok "$readonly_file: strict readonly boolean is $readonly_expected"
      fi
    done
  done

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
    'whether the sole `## PR State` has exactly one non-placeholder `Verified implementation digest` equal to the receipt digest and one non-placeholder `Verified at` timestamp.'
  check_workflow_contract \
    "PR canonical story-scoped receipt identity and PR State write-back" openspec-pr \
    'A modern bound story requires exactly one complete canonical `progress.md → ## Implementation Review Receipt`' \
    'recompute the story-scoped identity with canonical `review-identity-v1` using exactly the receipt-recorded `Identity bases` and `Identity paths`.' \
    'Save the matching digest and the last pre-mutation UTC verification timestamp in memory for PR State write-back.' \
    'For a modern receipt, the verified digest must exactly equal its `Identity digest`; never carry forward an older verification timestamp or digest.'
  check_workflow_contract \
    "archive route-scoped receipt identity and PR State verification" openspec-archive \
    'At this phase validate receipt shape and remember its digest but do not recompute identity or mutate PR State' \
    'The verified digest must exactly equal the current receipt'"'"'s `Identity digest`' \
    'Do not recompute identity in archive'"'"'s merged-PR route.' \
    'Only when `<archive_route>=no-pr` and a modern receipt exists, immediately before the first archive mutation' \
    'recompute canonical `review-identity-v1` from exactly its recorded `Identity bases` and `Identity paths`.'

  # Every active DONE router sends invalid modern receipt evidence through an
  # acknowledged ordinary-feedback reopen. Generated runtimes must retain the
  # same route and the exact no-backfill pre-v3 exception.
  MODERN_DONE_FEEDBACK_ROUTE='For a bound modern `Status: ✅ DONE`, a missing, duplicate, malformed, or non-approving Implementation Review Receipt routes only to ordinary `/openspec-feedback <initiative-slug>` with an operator-acknowledged `resume-current-story` disposition; never route that receipt contradiction directly to `/openspec-story-review`.'
  PRE_V3_NO_BACKFILL_ROUTE='The only no-receipt exception is an unbound pre-v3 DONE story with zero Initiative or Initiative-like header lines and zero receipt sections; warn and backfill neither binding nor receipt.'
  for done_router in \
    openspec-archive openspec-next-action openspec-pr \
    openspec-story-claim openspec-story-resume openspec-story-converge \
    openspec-story-plan-review openspec-story-plan-converge \
    openspec-story-plan-resume; do
    check_workflow_contract \
      "modern DONE feedback reopen and exact pre-v3 exception: $done_router" \
      "$done_router" \
      "$MODERN_DONE_FEEDBACK_ROUTE" \
      "$PRE_V3_NO_BACKFILL_ROUTE"
  done
  # Semantic route/ownership guards cover paraphrases in every distributed active
  # skill. Exact positive route contracts above and the exact pre-v3 exception stay
  # pinned independently; these detectors reject stale affirmative ownership/routes.
  stale_route_fixture="$TMPDIR/stale-done-review-route-fixture.md"
  clean_route_fixture="$TMPDIR/clean-done-review-route-fixture.md"
  cat >"$stale_route_fixture" <<'EOF'
- A bound DONE story whose approval receipt is absent gets sent straight into `/openspec-story-review`.

- When modern DONE receipt fields are duplicated, open a fresh `/openspec-story-review` session.

- Invalid Implementation Review Receipt proof directs the modern DONE case to `/openspec-story-review`.

- A bound modern DONE without a receipt routes only to the same fresh oblivious review.

- A bound modern DONE with no receipt uses fresh substantive review.

- No implementation receipt on a bound DONE story sends it to the fresh-review route.

- A receiptless bound modern DONE routes to `/openspec-story-review`.

- A bound modern DONE lacking an approval receipt returns to implementation review.

- The bound modern DONE receipt is missing. Route it to fresh review.

- A bound modern DONE has no receipt evidence. After recording the contradiction, send it to `/openspec-story-review`.

- If feedback is not available, a receiptless modern DONE routes to `/openspec-story-review`.
EOF
  cat >"$clean_route_fixture" <<'EOF'
- Never route a missing modern DONE receipt directly to `/openspec-story-review`; use ordinary feedback.

- A missing modern DONE receipt routes to feedback, not `/openspec-story-review`.

- A bound modern DONE without a receipt uses feedback rather than `/openspec-story-review`.

- For a bound modern DONE with no receipt, use feedback instead of `/openspec-story-review`.

- An identity digest mismatch routes to fresh `/openspec-story-review` after canonical recomputation.

- Unchecked task evidence sends the DONE story to `/openspec-story-review` for substantive review.

- Reject the rule “a bound modern DONE without a receipt routes to fresh review”.

- Quote the claim “receiptless modern DONE routes to `/openspec-story-review`” only as rejected legacy wording.
EOF
  stale_route_fixture_findings="$(stale_done_review_route_findings "$stale_route_fixture")"
  clean_route_fixture_findings="$(stale_done_review_route_findings "$clean_route_fixture")"
  if [[ "$(grep -c '^stale-done-review-route:' <<<"$stale_route_fixture_findings" || true)" != 11 ]]; then
    fail "semantic DONE-receipt route detector missed paraphrased stale fixtures: $stale_route_fixture_findings"
  elif [[ -n "$clean_route_fixture_findings" ]]; then
    fail "semantic DONE-receipt route detector rejected negated or identity/task routes: $clean_route_fixture_findings"
  else
    ok "semantic DONE-receipt route detector rejects paraphrases and accepts valid negatives"
  fi

  stale_ownership_fixture="$TMPDIR/stale-review-receipt-ownership-fixture.md"
  clean_ownership_fixture="$TMPDIR/clean-review-receipt-ownership-fixture.md"
  cat >"$stale_ownership_fixture" <<'EOF'
- `/openspec-story-review` creates the current receipt after approval.
- The reviewer owns receipt normalization.
- A receipt is replaced by review before DONE.
- Implementation review publishes the approval receipt.
- Fresh substantive review owns normalization.
- Receipt publication is owned by review.
- Implementation review is responsible for receipt publication.
- Receipt normalization belongs to substantive review.
- Local completion is owned by `/openspec-story-review`.
- The reviewer publishes the completed-review timeline transition.
- Completed-review Status is set by `/openspec-story-review`.
- The blocker is written by the readonly reviewer.
EOF
  cat >"$clean_ownership_fixture" <<'EOF'
- `/openspec-story-review` must never write or replace the receipt.
- The reviewer publishes no receipt.
- Receipt publication is not owned by review.
- Feedback publishes the receipt instead of `/openspec-story-review`.
- The reviewer authors a completed-review handoff; feedback publishes the receipt.
- The reviewer authors Target Status, Timeline transition, and Blocker body in the handoff; feedback publishes them.
- Feedback creates the receipt from the reviewer-authored handoff.
EOF
  stale_ownership_fixture_findings="$(review_receipt_ownership_findings "$stale_ownership_fixture")"
  clean_ownership_fixture_findings="$(review_receipt_ownership_findings "$clean_ownership_fixture")"
  if [[ "$(grep -c '^review-receipt-ownership:' <<<"$stale_ownership_fixture_findings" || true)" != 12 ]]; then
    fail "semantic review receipt-ownership detector missed paraphrased fixtures: $stale_ownership_fixture_findings"
  elif [[ -n "$clean_ownership_fixture_findings" ]]; then
    fail "semantic review receipt-ownership detector rejected negation or handoff/feedback publication: $clean_ownership_fixture_findings"
  else
    ok "semantic review receipt-ownership detector rejects paraphrases and accepts publication boundaries"
  fi

  blanket_route_stale_fixture="$TMPDIR/blanket-fresh-review-stale.md"
  blanket_route_clean_fixture="$TMPDIR/blanket-fresh-review-clean.md"
  cat >"$blanket_route_stale_fixture" <<'EOF'
- Every failed final-recheck condition uses the fresh-review route.
- All recheck failures route to `/openspec-story-review`.
EOF
  cat >"$blanket_route_clean_fixture" <<'EOF'
- Missing receipt evidence returns through ordinary feedback. Identity mismatch uses fresh review.
- Root ambiguity requires operator correction; only unverifiable identity routes to fresh review.
EOF
  blanket_route_stale_findings="$(blanket_fresh_review_route_findings "$blanket_route_stale_fixture")"
  blanket_route_clean_findings="$(blanket_fresh_review_route_findings "$blanket_route_clean_fixture")"
  if [[ "$(grep -c '^blanket-fresh-review-route:' <<<"$blanket_route_stale_findings" || true)" != 2 ]]; then
    fail "blanket final-recheck detector missed stale fixtures: $blanket_route_stale_findings"
  elif [[ -n "$blanket_route_clean_findings" ]]; then
    fail "blanket final-recheck detector rejected state-correct routes: $blanket_route_clean_findings"
  else
    ok "blanket final-recheck detector requires state-correct routes"
  fi

  plan_status_stale_fixture="$TMPDIR/plan-review-status-stale.md"
  plan_status_clean_fixture="$TMPDIR/plan-review-status-clean.md"
  cat >"$plan_status_stale_fixture" <<'EOF'
- Plan review sets implementation Status to IN PROGRESS.
- Implementation Status is owned by `/openspec-story-plan-review`.
EOF
  cat >"$plan_status_clean_fixture" <<'EOF'
- Plan review sets Plan to approved and routes from authoritative implementation Status.
- Story claim owns implementation entry; plan review does not write Status.
EOF
  plan_status_stale_findings="$(plan_review_status_ownership_findings "$plan_status_stale_fixture")"
  plan_status_clean_findings="$(plan_review_status_ownership_findings "$plan_status_clean_fixture")"
  if [[ "$(grep -c '^plan-review-status-ownership:' <<<"$plan_status_stale_findings" || true)" != 2 ]]; then
    fail "plan-review Status detector missed stale fixtures: $plan_status_stale_findings"
  elif [[ -n "$plan_status_clean_findings" ]]; then
    fail "plan-review Status detector rejected plan-only ownership: $plan_status_clean_findings"
  else
    ok "plan-review Status detector preserves implementation ownership"
  fi

  for semantic_skill in "${OPENSPEC_WORKFLOW_SKILLS[@]:-}"; do
    [[ -z "$semantic_skill" ]] && continue
    semantic_codex="$(hyphen_to_underscore "$semantic_skill")"
    for semantic_file in \
      "$CLAUDE_SKILLS/$semantic_skill/SKILL.md" \
      "$CODEX_SKILLS/$semantic_codex/SKILL.md" \
      "$PI_SKILLS/$semantic_skill/SKILL.md"; do
      stale_route_findings="$(stale_done_review_route_findings "$semantic_file")"
      if [[ -n "$stale_route_findings" ]]; then
        fail "$semantic_file: modern DONE receipt contradiction routes directly to story review"
        printf '%s\n' "$stale_route_findings" | sed 's/^/  /' >&2
      fi
      stale_ownership_findings="$(review_receipt_ownership_findings "$semantic_file")"
      if [[ -n "$stale_ownership_findings" ]]; then
        fail "$semantic_file: assigns completed-review publication/transition ownership to story review"
        printf '%s\n' "$stale_ownership_findings" | sed 's/^/  /' >&2
      fi
    done
  done

  # Pi fragments are active prompt suffixes and can override generated skill
  # routing, so they receive the same semantic guards as full distributions.
  for semantic_fragment in "$PI_FRAGMENTS"/openspec-*.md; do
    [[ -e "$semantic_fragment" ]] || continue
    stale_route_findings="$(stale_done_review_route_findings "$semantic_fragment")"
    stale_ownership_findings="$(review_receipt_ownership_findings "$semantic_fragment")"
    blanket_route_findings="$(blanket_fresh_review_route_findings "$semantic_fragment")"
    plan_status_findings="$(plan_review_status_ownership_findings "$semantic_fragment")"
    if [[ -n "$stale_route_findings$stale_ownership_findings$blanket_route_findings$plan_status_findings" ]]; then
      fail "$semantic_fragment: active Pi fragment overrides lifecycle routing or ownership"
      printf '%s\n' "$stale_route_findings" "$stale_ownership_findings" "$blanket_route_findings" "$plan_status_findings" | sed '/^$/d; s/^/  /' >&2
    fi
  done

  for semantic_pr_file in \
    "$CLAUDE_SKILLS/openspec-pr/SKILL.md" \
    "$CODEX_SKILLS/openspec_pr/SKILL.md" \
    "$PI_SKILLS/openspec-pr/SKILL.md"; do
    blanket_route_findings="$(blanket_fresh_review_route_findings "$semantic_pr_file")"
    if [[ -n "$blanket_route_findings" ]]; then
      fail "$semantic_pr_file: blankets final-recheck failures into fresh review"
      printf '%s\n' "$blanket_route_findings" | sed 's/^/  /' >&2
    fi
  done

  for semantic_plan_review_file in \
    "$CLAUDE_SKILLS/openspec-story-plan-review/SKILL.md" \
    "$CODEX_SKILLS/openspec_story_plan_review/SKILL.md" \
    "$PI_SKILLS/openspec-story-plan-review/SKILL.md"; do
    plan_status_findings="$(plan_review_status_ownership_findings "$semantic_plan_review_file")"
    if [[ -n "$plan_status_findings" ]]; then
      fail "$semantic_plan_review_file: plan review sets or owns implementation Status"
      printf '%s\n' "$plan_status_findings" | sed 's/^/  /' >&2
    fi
  done

  DESIGN_BOOK="$REPO_ROOT/docs/openspec-add-flow-design-book.svg"
  for ownership_public_file in \
    "$REPO_ROOT/README.md" \
    "$CONVENTIONS_DOC" \
    "$DESIGN_BOOK"; do
    public_ownership_findings="$(review_receipt_ownership_findings "$ownership_public_file")"
    if [[ -n "$public_ownership_findings" ]]; then
      fail "$ownership_public_file: public reviewer/publisher wording assigns completed-review publication ownership to review"
      printf '%s\n' "$public_ownership_findings" | sed 's/^/  /' >&2
    else
      ok "$ownership_public_file: public reviewer/publisher wording keeps review read-only"
    fi
  done

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

  # The receipt remains one replace-in-place current record. Review evaluates and
  # returns a state-bound handoff; feedback alone validates and publishes it. For
  # non-DONE lanes a superseded receipt remains historical context only.
  REVIEW_HANDOFF_PUBLICATION_DOC='`/openspec-story-review` authors the completed-review handoff; `/openspec-feedback` validates it and solely publishes the receipt, timeline transition, blocker, and Status.'
  require_literal "README reviewer handoff and feedback publication ownership" "$REPO_ROOT/README.md" "$REVIEW_HANDOFF_PUBLICATION_DOC"
  require_literal "conventions reviewer handoff and feedback publication ownership" "$CONVENTIONS_DOC" "$REVIEW_HANDOFF_PUBLICATION_DOC"
  forbid_literal "README does not assign receipt creation to review" "$REPO_ROOT/README.md" 'review may create the current receipt'
  forbid_literal "README does not describe review as receipt/status publisher" "$REPO_ROOT/README.md" 'Every completed verdict replaces/creates the one current'
  forbid_literal "README command table does not describe review as publisher" "$REPO_ROOT/README.md" 'publish receipt plus timeline in one progress write'
  forbid_literal "conventions do not assign receipt publication to review" "$CONVENTIONS_DOC" 'written only by `/openspec-story-review`'
  forbid_literal "conventions write-surface list does not assign blocker publication to review" "$CONVENTIONS_DOC" 'implementation review: for BLOCKED, creates/updates `blocked.md` first'
  forbid_literal "conventions do not let review create progress" "$CONVENTIONS_DOC" '`/openspec-story-review` may create the minimal review'
  forbid_literal "conventions do not describe review as artifact publisher" "$CONVENTIONS_DOC" 'Review builds and validates the completed verdict in memory. For BLOCKED it'
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
  require_workflow_literal \
    "feedback preserves canonical implementation receipt fields" \
    openspec-feedback \
    "$CANONICAL_RECEIPT_FIELD_LIST"
  require_workflow_literal \
    "feedback never synthesizes or repairs a receipt without a validated handoff" \
    openspec-feedback \
    'Without a validated completed-review handoff, never create, reconstruct, synthesize, repair, normalize, or replace an Implementation Review Receipt; ordinary feedback may only preserve existing receipt bytes while an acknowledged `resume-current-story` disposition reopens the story.'
  check_workflow_contract \
    "review canonical identity recording" openspec-story-review \
    'Record `Evidence reviewed` as a concise target/proof summary' \
    'Record `Identity method: review-identity-v1` exactly once.' \
    '`Identity bases` as one compact canonical JSON array' \
    '`Identity paths` as one compact canonical JSON array' \
    'Each manifest row is exactly `<repo>\t<path>\t<type>\t<lowercase-64-hex-sha256>\n`' \
    '`type` is exactly `file`, `executable`, `symlink`, or `deleted`.'
  check_workflow_contract \
    "readonly review evaluator and state-bound handoff" openspec-story-review \
    'Treat the repository and OpenSpec artifacts as read-only throughout evaluation.' \
    'Return exactly one fenced `## Completed Review Handoff` block in the final response; do not write `story.md`, `progress.md`, or `blocked.md`.' \
    'Do not delegate mutation or use custom tools to bypass read-only operation.' \
    'A `NOT REVIEWABLE` result emits no publishable completed-review handoff.' \
    'Every handoff field appears exactly once.' \
    'Handoff version: review-handoff-v1' \
    'Story: <initiative-slug>/<story-slug>' \
    'Review cycle: sha256:<lowercase hex>' \
    'Story baseline digest: sha256:<lowercase hex>' \
    'Progress baseline digest: sha256:<lowercase hex>' \
    'Blocked baseline digest: absent | sha256:<lowercase hex>' \
    'Expected story digest: sha256:<lowercase hex>' \
    'Expected progress digest: sha256:<lowercase hex>' \
    'Expected blocked digest: absent | sha256:<lowercase hex>' \
    'Compute `Review cycle` as SHA-256 of the exact UTF-8 bytes `review-cycle-v1\\n`, then `story.md\\t<Story baseline digest>\\n`, `progress.md\\t<Progress baseline digest>\\n`, and `blocked.md\\t<Blocked baseline digest>\\n` in that order.' \
    '`Review cycle` identifies that baseline artifact state; it is not a unique issuance id or latest-packet authority.' \
    'The handoff carries each canonical receipt field exactly once:' \
    "$CANONICAL_RECEIPT_FIELD_LIST" \
    'Target Status:' \
    'Timeline transition:' \
    'Blocker body:' \
    'For every completed verdict, the immediate `Suggested next action` is the operator action to pass this fenced packet to `/openspec-feedback <initiative-slug>`;' \
    'The canonical progress-byte transform used by both review and feedback is:' \
    'DONE with a missing, malformed, duplicate, or non-approving bound receipt routes to ordinary `/openspec-feedback <initiative-slug>` with an acknowledged `resume-current-story` disposition;'
  for forbidden_review_publication in \
    'create or update `<change_dir>/blocked.md` first' \
    'write the top-level `Status:` last' \
    'normalize all review-owned receipt sections' \
    '## Notebook write-back' \
    'notebook_write'; do
    forbid_workflow_literal \
      "review does not retain publication instruction" \
      openspec-story-review \
      "$forbidden_review_publication"
  done
  check_workflow_contract \
    "feedback validates and solely publishes completed review" openspec-feedback \
    'Feedback is the sole publisher of a completed implementation review.' \
    'Accept only one fenced `## Completed Review Handoff` block with `Handoff version: review-handoff-v1`.' \
    'Require every handoff field exactly once, including the complete canonical receipt field set:' \
    "$CANONICAL_RECEIPT_FIELD_LIST" \
    '`Story`, `Review cycle`, all three baseline digests, all three expected digests, `Target Status`, `Timeline transition`, and `Blocker body`' \
    'Reject a missing, duplicate, malformed, stale, or mismatched completed-review handoff.' \
    'Recompute `Review cycle` from the packet baseline digests using the exact `review-cycle-v1` canonical encoding and require an exact match.' \
    '`Review cycle` identifies the baseline artifact state, not packet issuance order.' \
    'Authorize only these exact digest tuples: pristine baseline; blocked prefix; progress prefix; or completed Status prefix.' \
    'Check the exact completed Status prefix before enforcing the active-publication status gate:' \
    'Every writable prefix must retain the exact baseline story bytes with top-level Status `🟣 IN REVIEW`;' \
    'The canonical progress-byte transform used by both review and feedback is:' \
    'rebuild `<project_root_map>` only from `progress.md → ## Current Claim`, named `WORKTREE="<basename>=<path>"` target selectors, and the fixed main-tree candidates below.' \
    'An explicit selector overrides the recorded path for that basename only.' \
    'For a `Main-tree targets` basename with no effective worktree path, the only candidates are the fixed reviewer-compatible path `<launch_root>/projects/<basename>` or `<launch_root>` when `basename(<launch_root>)` is that basename.' \
    'Define a legacy empty claim as one with no recorded `Worktrees`, no legacy singular `Worktree`, and no `Main-tree targets`; named explicit selectors do not disable this fallback.' \
    'For a legacy empty claim, derive legacy main-tree basenames from exact `story.md → ## Scope` `projects/<basename>/` tokens and resolve them only through those same fixed main-tree candidates.' \
    'A named selector overrides its basename and may add a mapped basename that is absent from Scope, but it does not suppress Scope-derived candidates for other basenames.' \
    'Require every packet identity basename to resolve exactly once through a recorded path, named selector, explicit `Main-tree targets` basename, or this bounded Scope fallback;' \
    'Do not search the filesystem or Git state for another repository by basename, and never use `<receipt_root>` as a target-root fallback.' \
    'A root-repository alias is valid only when its recorded or explicit effective path canonicalizes exactly to `<launch_root>` or `<receipt_root>`; retain the declared alias key.' \
    'Require each basename in `Identity bases` and `Identity paths` to map exactly once' \
    'the canonical parent to remain beneath the canonical target root.' \
    'Feedback does not repeat the reviewer'"'"'s Git branch, worktree-registration, detached-HEAD, or immutable-base object checks' \
    'reproduce the packet'"'"'s exact canonical `review-identity-v1` manifest and digest.' \
    'For a writable prefix, set `<workspace_root>` to `<launch_root>` and `<openspec_root>` to `<receipt_root>`' \
    'Any artifact digest combination outside those transaction prefixes is an unreconciled partial failure.' \
    'Revalidate the handoff, safely mapped reviewed identity, and authoritative story/review-cycle transaction prefix immediately before the next publication write.' \
    '`APPROVE`/`PASS` maps to `✅ DONE`; `REQUEST CHANGES`/`FAIL` maps to `🔄 IN PROGRESS`; `BLOCKED`/`FAIL` maps to `⛔ BLOCKED`.' \
    'Duplicate or malformed Implementation Review Receipt sections are non-authoritative reconciliation inputs; replace all of them with exactly one current receipt containing every required field exactly once.' \
    'Build and validate the complete publication in memory before the first write.' \
    'For a blocked result, create or update `blocked.md` first.' \
    'Publish exactly one normalized Implementation Review Receipt and exactly one Progress Timeline transition atomically, then re-read both.' \
    'Write the top-level `Status:` last, perform a final re-read, and make no further writes.' \
    'A retry may continue only from the pristine baseline or an exact transaction prefix produced from the same handoff; never duplicate its receipt or timeline transition.' \
    'If any required write or re-read fails, stop, report the exact artifact mismatch, and do not call publication complete.' \
    'A failed APPROVE publication remains `🟣 IN REVIEW`, never receipt-absent legacy DONE.' \
    'A successfully published non-approve verdict must not leave the story `🟣 IN REVIEW`.' \
    'End with exactly one scalar `Suggested next action: <packet Next owner>`;' \
    'do not expose the packet'"'"'s post-publication `Next owner`.'
  check_workflow_contract \
    "review legacy Scope target mapping" openspec-story-review \
    'Define a legacy empty claim as one with no recorded `Worktrees`, no legacy singular `Worktree`, and no `Main-tree targets`.' \
    'Do this even when named explicit selectors already populated `<target_repos>`; a named selector overrides its basename but does not suppress Scope discovery for other basenames.' \
    'Do not infer `<openspec_root>` or `<workspace_root>` as a legacy root-repository target merely because it is a Git repository or appears generally in Scope.'

  # The producer packet is a structural contract, not disconnected prose. Every
  # field line must occur exactly once inside its dedicated section in all runtimes.
  review_codex="$(hyphen_to_underscore openspec-story-review)"
  for review_file in \
    "$CLAUDE_SKILLS/openspec-story-review/SKILL.md" \
    "$CODEX_SKILLS/$review_codex/SKILL.md" \
    "$PI_SKILLS/openspec-story-review/SKILL.md"; do
    review_handoff="$(markdown_section "$review_file" '## Completed review handoff contract')"
    for handoff_field in \
      'Handoff version' Story 'Review cycle' \
      'Story baseline digest' 'Progress baseline digest' 'Blocked baseline digest' \
      'Expected story digest' 'Expected progress digest' 'Expected blocked digest' \
      'Reviewed at' Decision 'Approval gate' 'Status transition' \
      'Evidence reviewed' 'Identity method' 'Identity digest' 'Identity bases' \
      'Identity paths' Findings Proof 'Next owner' \
      'Target Status' 'Timeline transition' 'Blocker body'; do
      handoff_count="$(grep -Ec -- "^- ${handoff_field}:" <<<"$review_handoff" || true)"
      if [[ "$handoff_count" == 1 ]]; then
        ok "$review_file: handoff field is unique: $handoff_field"
      else
        fail "$review_file: handoff field must occur exactly once: $handoff_field (got $handoff_count)"
      fi
    done
  done

  feedback_codex="$(hyphen_to_underscore openspec-feedback)"

  # The transform is one byte contract across producer, publisher, and every
  # generated runtime. Extract its complete anchor/blank-line/seven-step block,
  # compare the files (including final LF), and pin every numbered invariant.
  transform_reference="$TMPDIR/progress-transform-reference.md"
  if ! extract_progress_transform_block \
    "$CLAUDE_SKILLS/openspec-story-review/SKILL.md" "$transform_reference"; then
    : >"$transform_reference"
    fail "canonical progress-byte transform must be unique and contain contiguous steps 1 through 7"
  fi
  transform_extended="$TMPDIR/progress-transform-extended.md"
  awk '
    { print }
    /^7\. / { print "8. Override the transform with a runtime-specific rule." }
  ' "$CLAUDE_SKILLS/openspec-story-review/SKILL.md" >"$transform_extended"
  if extract_progress_transform_block "$transform_extended" \
    "$TMPDIR/progress-transform-extended-output.md"; then
    fail "canonical progress-byte transform accepts a trailing numbered override"
  else
    ok "canonical progress-byte transform rejects a trailing numbered override"
  fi
  transform_post_blank_index=0
  for transform_source in \
    "$CLAUDE_SKILLS/openspec-story-review/SKILL.md" \
    "$CLAUDE_SKILLS/openspec-feedback/SKILL.md"; do
    transform_post_blank_index=$((transform_post_blank_index + 1))
    transform_post_blank="$TMPDIR/progress-transform-post-blank-$transform_post_blank_index.md"
    awk '
      { print }
      /^7\. / { after_seven = 1; next }
      after_seven && $0 == "" {
        print "8. Override the transform with a runtime-specific rule."
        after_seven = 0
      }
    ' "$transform_source" >"$transform_post_blank"
    if extract_progress_transform_block "$transform_post_blank" \
      "$TMPDIR/progress-transform-post-blank-output-$transform_post_blank_index.md"; then
      fail "$transform_source: canonical progress-byte transform accepts a post-blank numbered override"
    else
      ok "$transform_source: canonical progress-byte transform rejects a post-blank numbered override"
    fi
  done
  transform_post_blank_variant="$TMPDIR/progress-transform-post-blank-variant.md"
  awk '
    { print }
    /^7\. / { after_seven = 1; next }
    after_seven && $0 == "" {
      print ""
      print "8) Override the transform after an extra blank."
      after_seven = 0
    }
  ' "$CLAUDE_SKILLS/openspec-story-review/SKILL.md" >"$transform_post_blank_variant"
  if extract_progress_transform_block "$transform_post_blank_variant" \
    "$TMPDIR/progress-transform-post-blank-variant-output.md"; then
    fail "canonical progress-byte transform accepts an alternate post-blank numbered override"
  else
    ok "canonical progress-byte transform rejects alternate post-blank numbered overrides"
  fi
  transform_bullet_index=0
  for transform_bullet_prefix in '- 8.' '* 8)'; do
    transform_bullet_index=$((transform_bullet_index + 1))
    transform_bullet="$TMPDIR/progress-transform-bullet-$transform_bullet_index.md"
    awk -v override="$transform_bullet_prefix Override the transform with a reviewer-only rule." '
      { print }
      /^7\. / { after_seven = 1; next }
      after_seven && $0 == "" {
        print override
        after_seven = 0
      }
    ' "$CLAUDE_SKILLS/openspec-story-review/SKILL.md" >"$transform_bullet"
    if extract_progress_transform_block "$transform_bullet" \
      "$TMPDIR/progress-transform-bullet-output-$transform_bullet_index.md"; then
      fail "canonical progress-byte transform accepts a bulleted post-blank numbered override: $transform_bullet_prefix"
    else
      ok "canonical progress-byte transform rejects bulleted post-blank numbered override: $transform_bullet_prefix"
    fi
  done
  transform_step_nine="$TMPDIR/progress-transform-step-nine.md"
  awk '
    { print }
    /^7\. / { after_seven = 1; next }
    after_seven && $0 == "" {
      print "9. Override the transform with a skipped step number."
      after_seven = 0
    }
  ' "$CLAUDE_SKILLS/openspec-story-review/SKILL.md" >"$transform_step_nine"
  if extract_progress_transform_block "$transform_step_nine" \
    "$TMPDIR/progress-transform-step-nine-output.md"; then
    fail "canonical progress-byte transform accepts a skipped post-blank step number"
  else
    ok "canonical progress-byte transform rejects skipped post-blank step numbers"
  fi
  transform_interposed="$TMPDIR/progress-transform-interposed.md"
  awk '
    { print }
    /^7\. / { after_seven = 1; next }
    after_seven && $0 == "" {
      print "This prose attempts to hide a later transform continuation."
      print ""
      print "8. Hash a different byte sequence instead."
      after_seven = 0
    }
  ' "$CLAUDE_SKILLS/openspec-story-review/SKILL.md" >"$transform_interposed"
  if extract_progress_transform_block "$transform_interposed" \
    "$TMPDIR/progress-transform-interposed-output.md"; then
    fail "canonical progress-byte transform accepts an interposed-prose numbered override"
  else
    ok "canonical progress-byte transform rejects interposed-prose numbered overrides"
  fi

  transform_index=0
  for transform_file in \
    "$CLAUDE_SKILLS/openspec-story-review/SKILL.md" \
    "$CLAUDE_SKILLS/openspec-feedback/SKILL.md" \
    "$CODEX_SKILLS/$review_codex/SKILL.md" \
    "$CODEX_SKILLS/$feedback_codex/SKILL.md" \
    "$PI_SKILLS/openspec-story-review/SKILL.md" \
    "$PI_SKILLS/openspec-feedback/SKILL.md"; do
    transform_index=$((transform_index + 1))
    transform_actual="$TMPDIR/progress-transform-$transform_index.md"
    if extract_progress_transform_block "$transform_file" "$transform_actual" && \
      cmp -s "$transform_reference" "$transform_actual"; then
      ok "$transform_file: canonical progress-byte transform is byte-identical"
    else
      fail "$transform_file: canonical progress-byte transform differs or is not unique/complete"
    fi
  done
  for transform_invariant in \
    '1. Treat `progress.md` as exact bytes. Require valid UTF-8, no CR byte, LF-only line termination, and a terminal LF.' \
    'Fenced-code state is irrelevant:' \
    'folding only ASCII `A` through `Z` to lowercase.' \
    '2. Decode `Timeline transition` from its canonical JSON transport string. The decoded bytes must be exactly one nonempty line beginning with the two ASCII bytes `- `' \
    '3. Require the Progress Timeline range to end with the two bytes `\n\n`. Its deterministic append point is immediately before the range'"'"'s final LF byte' \
    '4. In baseline construction mode, require zero exact full-line occurrences' \
    'In expected-candidate validation mode, require exactly one occurrence at that append point' \
    '5. Remove every section range whose heading line is exactly `## Implementation Review Receipt`, including duplicates.' \
    'Each of the twelve packet receipt values must be one valid UTF-8 line with no CR or LF.' \
    '6. Insert that one normalized receipt immediately after the resulting Progress Timeline range and before the next surviving canonical section-boundary heading or EOF.' \
    'Preserve every other byte and surviving section order exactly, then SHA-256 hash the complete resulting bytes.' \
    '7. Review applies baseline construction mode to its final baseline bytes.' \
    'Feedback applies baseline construction mode only when current progress exactly matches the packet'"'"'s baseline digest;' \
    'Any malformed, non-UTF-8, ambiguous, or noncanonical input fails closed.'; do
    if ! grep -Fq -- "$transform_invariant" "$transform_reference"; then
      fail "canonical progress-byte transform is missing invariant: $transform_invariant"
    fi
  done

  # Literal guards do not catch novel affirmative reviewer mutations or prose that
  # overrides Status-last ordering. Mutation-test canonical, Codex, and Pi copies
  # independently, including numbered and clause-leading instructions.
  reviewer_vocabulary="$TMPDIR/reviewer-semantic-vocabulary.md"
  reviewer_vocabulary_clean="$TMPDIR/reviewer-semantic-vocabulary-clean.md"
  cat >"$reviewer_vocabulary" <<'EOF'
- Save progress.md.
- The reviewer saves progress.md.
- Persist the receipt.
- Agents persist the receipt.
- Rewrite story.md.
- Reviewers rewrite story.md.
- Delete blocked.md.
- An agent deletes blocked.md.
- Remove progress.md.
- Remove the receipt.
- Touch progress.md.
- Agents touch progress.md.
EOF
  cat >"$reviewer_vocabulary_clean" <<'EOF'
- Do not save progress.md.
- The reviewer must not persist the receipt.
- Agents never rewrite story.md.
- Reviewers do not delete blocked.md.
- Never remove progress.md.
- Agents must not touch progress.md.
EOF
  reviewer_vocabulary_findings="$(reviewer_semantic_findings "$reviewer_vocabulary")"
  reviewer_vocabulary_count="$(grep -c '^mutation:' <<<"$reviewer_vocabulary_findings" || true)"
  reviewer_vocabulary_clean_findings="$(reviewer_semantic_findings "$reviewer_vocabulary_clean")"
  if [[ "$reviewer_vocabulary_count" != 12 ]]; then
    fail "semantic detector missed save/persist/rewrite/delete/remove/touch mutations ($reviewer_vocabulary_count/12)"
  elif [[ -n "$reviewer_vocabulary_clean_findings" ]]; then
    fail "semantic detector rejects negated save/persist/rewrite/delete/remove/touch fixtures: $reviewer_vocabulary_clean_findings"
  else
    ok "semantic detector rejects save/persist/rewrite/delete/remove/touch mutations and accepts their negations"
  fi

  reviewer_fixture_index=0
  for review_file in \
    "$CLAUDE_SKILLS/openspec-story-review/SKILL.md" \
    "$CODEX_SKILLS/$review_codex/SKILL.md" \
    "$PI_SKILLS/openspec-story-review/SKILL.md"; do
    reviewer_fixture_index=$((reviewer_fixture_index + 1))
    reviewer_clean="$TMPDIR/reviewer-semantic-clean-$reviewer_fixture_index.md"
    reviewer_mutation="$TMPDIR/reviewer-semantic-mutation-$reviewer_fixture_index.md"
    reviewer_order="$TMPDIR/reviewer-semantic-order-$reviewer_fixture_index.md"
    cp "$review_file" "$reviewer_clean"
    cp "$review_file" "$reviewer_mutation"
    cp "$review_file" "$reviewer_order"
    printf '\n' >>"$reviewer_mutation"
    printf '\n' >>"$reviewer_order"
    reviewer_number=0
    for reviewer_verb in \
      write edit create update replace overwrite append publish mutate; do
      reviewer_number=$((reviewer_number + 1))
      printf -- '- %d. %s `progress.md`.\n' "$reviewer_number" "$reviewer_verb" >>"$reviewer_mutation"
      printf -- '- Inspect evidence, then only after validation %s `progress.md`.\n' "$reviewer_verb" >>"$reviewer_mutation"
    done
    printf -- '- After Status, overwrite `progress.md`.\n' >>"$reviewer_mutation"
    cat >>"$reviewer_mutation" <<'EOF'
- Do not forget to write progress.md.
- Inspect evidence, then do not delay and write progress.md.
- Write Status.
- Set the top-level Status to DONE.
- Set progress.md to the new receipt.
- Change progress.md.
- Agents modify progress.md.
- The reviewer must write progress.md.
- Reviewers set Status to DONE.
- The reviewer must set Status to DONE.
- The reviewer changes Status to DONE.
- The reviewer modifies progress.md.
- The reviewers change progress.md.
- Append the receipt.
- Publish the timeline.
EOF
    cat >>"$reviewer_order" <<'EOF'
- Status before progress.
- Publish Status prior to the receipt.
- Status first, then timeline.
- Update progress.md after Status.
- Status is updated, then progress.
- After Status, overwrite progress.md.
- First publish Status, next update progress.md.
- Do not delay; Status before progress.
- Never hesitate: Status first, then timeline.
- Status must precede progress.
- Status is followed by progress.
- First write Status.
- Next update progress.md.
- First publish Status.

- Next update progress.md.
EOF
    cat >>"$reviewer_clean" <<'EOF'
1. Never overwrite progress.md.
- Do not update progress.md.
- Inspect evidence, then do not overwrite progress.md.
- Never write Status before progress.
- Read Status before progress.md.
- Compute a digest of Status before progress.md.
- Do not ever write progress.md.
- Do not permit tools to write progress.md.
- Never allow feedback to update progress.md.
- Reviewers must not set Status to DONE.
- The reviewers do not change progress.md.
- Agents never modify blocked.md.
- Reject any instruction saying "Status before progress."
- Treat `Status before progress` as invalid.
EOF
    clean_findings="$(reviewer_semantic_findings "$reviewer_clean")"
    mutation_findings="$(reviewer_semantic_findings "$reviewer_mutation")"
    order_findings="$(reviewer_semantic_findings "$reviewer_order")"
    mutation_count="$(grep -c '^mutation:' <<<"$mutation_findings" || true)"
    order_count="$(grep -c '^status-order:' <<<"$order_findings" || true)"
    if [[ -n "$clean_findings" ]]; then
      fail "$review_file: semantic detector rejects clean negated fixtures: $clean_findings"
    elif [[ "$mutation_count" != 34 ]]; then
      fail "$review_file: semantic detector missed numbered/clause mutations ($mutation_count/34)"
    elif [[ "$order_count" != 13 ]]; then
      fail "$review_file: semantic detector missed Status-order overrides ($order_count/13)"
    else
      ok "$review_file: semantic detector rejects numbered/clause mutations and Status-order overrides"
    fi

    reviewer_findings="$(reviewer_semantic_findings "$review_file")"
    if [[ -n "$reviewer_findings" ]]; then
      fail "$review_file: reviewer contains mutation or Status-order override"
      printf '%s\n' "$reviewer_findings" | sed 's/^/  /' >&2
    else
      ok "$review_file: reviewer remains nonmutating and has no Status-order override"
    fi
  done

  # Presence checks above are insufficient for a status-last contract. Verify the
  # numbered publication protocol is ordered in canonical and generated skills.
  for feedback_file in \
    "$CLAUDE_SKILLS/openspec-feedback/SKILL.md" \
    "$CODEX_SKILLS/$feedback_codex/SKILL.md" \
    "$PI_SKILLS/openspec-feedback/SKILL.md"; do
    feedback_publication="$(markdown_section "$feedback_file" '## Completed review publication')"
    feedback_order="$(awk '
      /Build and validate the complete publication in memory/ && !memory { memory = NR }
      /create or update `blocked\.md` first/ && !blocked { blocked = NR }
      /normalized Implementation Review Receipt/ && /Progress Timeline transition atomically/ && !progress { progress = NR }
      /Re-read `progress\.md` and the present-or-absent `blocked\.md`/ && !reread { reread = NR }
      /Write the top-level `Status:` last/ && !status { status = NR }
      /final re-read/ && /no further writes/ && !final { final = NR }
      END {
        if (memory && blocked && progress && reread && status && final &&
            memory < blocked && blocked < progress && progress < reread &&
            reread < status && status < final) print "ok"
        else print (memory + 0) ":" (blocked + 0) ":" (progress + 0) ":" (reread + 0) ":" (status + 0) ":" (final + 0)
      }
    ' <<<"$feedback_publication")"
    if [[ "$feedback_order" == ok ]]; then
      ok "$feedback_file: completed-review publication is ordered and Status-last"
    else
      fail "$feedback_file: completed-review publication order must be memory -> blocked -> progress -> reread -> Status -> final reread ($feedback_order)"
    fi
  done
  check_workflow_contract \
    "review rigor and mutation-sensitive multipass" openspec-story-review \
    'Record the owner-discovery searches you performed (`Code surfaces searched`) including domain terms, callsites/routes, existing tests, duplicate owners, generated/config/runtime surfaces, and any areas intentionally not searched.' \
    'Use `git -C <project_root_map>[<basename>] status`, `git -C <project_root_map>[<basename>] diff`, and targeted file reads to inspect what was actually changed.' \
    'Do not run broad or unfocused test suites; rerun the targeted proof commands named by the story and any narrower commands needed to resolve material review uncertainty.' \
    'If required live proof cannot be rerun credibly, record the evidence gap and fail the approval gate.' \
    'Unknown or provisional evidence that affects acceptance, route ownership, ticket intent, contract drift, or proof credibility blocks approval unless safely scoped out with a follow-up path.' \
    'Run a Debt Friction check:' \
    'Run a risk-sensitive sanity pass for activated risk lenses.' \
    'Were prior review findings and feedback fixes closed with disposition, fix proof, and regression/side-effect verification rather than prose acknowledgement only?' \
    'Build a compact review plan with 2-8 focused passes.' \
    'When `## Acceptance` has 6 or more concrete items, multipass review is required.' \
    'Multipass is also required when the combined diff across all target repos exceeds 30 files or 1500 lines' \
    'If diff size cannot be computed credibly, record a `Gate Finding`; do not use uncertainty to avoid multipass.' \
    'A documented manual focused-pass substitute is allowed only when child-agent spawning fails, times out, or is unavailable.' \
    'Each child is read-only for code and coordination files' \
    'Pass title and acceptance items covered.' \
    'Scope reviewed: repos, files, symbols, callsites, and tests.' \
    'Evidence quality: `confirmed`, `inferred`, `unknown`, and/or `provisional` evidence used by the pass' \
    'Result: `clean | findings | inconclusive`.' \
    'Map every `## Acceptance` item, including every named variant/failure mode inside an item, to at least one completed focused-pass result or explicit exclusion.' \
    'Map every `S<n> Covers: A<n>` normative scenario to the completed focused-pass result that proves the linked acceptance behavior.' \
    'Classify accumulated findings into `Gate Findings`, `Product Assessment`, `Technical Assessment`, or `Initiative Contract Drift`.' \
    'Every concrete issue under `Gate Findings`, `Product Assessment`, `Technical Assessment`, or `Initiative Contract Drift` must use this detailed finding card format in the final review output:' \
    '**Assumptions / Preconditions:** <required conditions, or `None.`>' \
    '**Downgrade Factors:** <what would reduce confidence or impact, or `None.`>' \
    '**Code Trail:** <grounded path from the cited evidence to the review conclusion>' \
    'Severity labels must be one of: `Critical`, `High`, `Medium`, `Low`, `Info`.' \
    'Likelihood labels must be one of: `High`, `Medium`, `Low`, `Not Assessed`.' \
    'If any acceptance item or required named variant is uncovered, any focused pass is inconclusive, or focused-pass outputs conflict, record a `Gate Finding`; `**Approval Gate**` must be `FAIL` and `**Decision**` cannot be `APPROVE`.' \
    'The Product and Technical verdicts are independent and may disagree.' \
    '`Gate Findings` contains readiness, proof-contract, state-transition, and red-first/precondition failures.' \
    '`Product Assessment` evaluates requested outcome, acceptance behavior, user-visible correctness, and initiative-level obligations explicitly owned by this story.' \
    '`Technical Assessment` evaluates correctness, regressions, architecture, reuse, tests, security, performance, maintainability, and rollout safety.' \
    '`Initiative Contract Drift` is only for mismatches between this story and initiative-level commitments'
  check_workflow_contract \
    "portable readonly runtime boundary" openspec-story-review \
    'Run this evaluator only in a fresh interactive session with runtime-enforced read-only mode; metadata and prose are not a security sandbox.' \
    'For Codex, require a verified `--sandbox read-only` launch; `readonly:` frontmatter is not claimed as Codex enforcement.'
  check_workflow_contract \
    "Pi sticky readonly policy" openspec-story-review \
    'Pi declarative read-only is a sticky interactive-session guard, not a security sandbox.' \
    'Bash protection is classifier-only and best-effort when OS sandboxing is unavailable; Task, custom, and MCP tools are not generically secured.'
  require_exact_line \
    "Pi fragment returns evidence without write-back" \
    "$PI_FRAGMENTS/openspec-story-review.md" \
    '### Read-only review return'
  require_literal \
    "generated Pi returns evidence without write-back" \
    "$PI_SKILLS/openspec-story-review/SKILL.md" \
    '### Read-only review return'
  forbid_literal \
    "Pi fragment removes review coordination write-back" \
    "$PI_FRAGMENTS/openspec-story-review.md" \
    '### Review coordination write-back'
  forbid_literal \
    "Pi fragment forbids notebook mutation" \
    "$PI_FRAGMENTS/openspec-story-review.md" \
    'notebook_write'
  pi_mutation_lines="$(markdown_without_comments "$PI_FRAGMENTS/openspec-story-review.md" | awk '
    {
      line = tolower($0)
      if (line ~ /(^|[^a-z])(write|edit|update|create|replace|normalize|reconcile|persist|append)([^a-z]|$)/ &&
          line !~ /(do not|never|must not|may not|cannot|can.t|without (writing|editing)|read-only)/) print FNR ":" $0
    }
  ')"
  if [[ -n "$pi_mutation_lines" ]]; then
    fail "Pi review fragment retains affirmative mutation instructions: $pi_mutation_lines"
  else
    ok "Pi review fragment contains no affirmative mutation instructions"
  fi
  check_workflow_contract \
    "planning review modern DONE receipt gate" openspec-story-plan-review \
    'inventory all `<change_dir>/progress.md → ## Implementation Review Receipt` headings.' \
    'A bound modern DONE with absent receipt evidence uses that ordinary-feedback reopen route.' \
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
    '`Write` is permitted only when a missing `progress.md`, `## Progress Timeline`, or `initiative.md → ## Feedback Receipts` section must be created, or when a missing `blocked.md` is the first write of a fully validated BLOCKED completed-review publication' \
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
  require_literal \
    "lifecycle names readonly review evaluator" \
    "$LIFECYCLE_DOC" \
    '`/openspec-story-review` is the read-only implementation evaluator.'
  require_literal \
    "lifecycle names sole completed-review publisher" \
    "$LIFECYCLE_DOC" \
    '`/openspec-feedback` is the sole publisher of completed-review artifacts and status transitions.'
  require_literal \
    "lifecycle qualifies ordinary feedback status ownership" \
    "$LIFECYCLE_DOC" \
    'Ordinary feedback never advances implementation `Status:`; outside completed-review publication, its only status write is an acknowledged `resume-current-story` reopen.'
  require_literal \
    "lifecycle documents bounded legacy Scope mapping" \
    "$LIFECYCLE_DOC" \
    'named target overrides do not suppress other Scope candidates. An unmapped legacy root-repository target fails closed:'
  require_literal \
    "lifecycle defers receiptless routing" \
    "$LIFECYCLE_DOC" \
    'Receiptless and current-cycle-derived reader routing remain outside this bridge.'

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

  # blocked.md is the hard gate: feedback must create/update it before publishing
  # BLOCKED status, and resume may normalize stale BLOCKED only after absence.
  require_workflow_literal \
    "feedback owns blocked review publication" \
    openspec-feedback \
    'For a blocked result, create or update `blocked.md` first.'
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
  check_allowed_tools_exact \
    openspec-feedback \
    Read Edit Write Grep Glob 'Bash(gh pr view:*)' 'Bash(gh api:*)' 'Bash(date -u:*)' 'Bash(printf:*)' 'Bash(sha256sum:*)' 'Bash(shasum:*)' 'Bash(git worktree list:*)' 'Bash(stat:*)' 'Bash(readlink:*)'
  forbid_workflow_literal \
    "feedback has no arbitrary repository Git permission" \
    openspec-feedback \
    'Bash(git -C:*)'
  check_allowed_tools_exact \
    openspec-story-plan-converge \
    Read Edit Grep Glob Task 'Bash(git status:*)' 'Bash(git worktree list:*)'
  check_allowed_tools_exact \
    openspec-story-converge \
    Read Grep Glob Task 'Bash(git status:*)' 'Bash(git worktree list:*)'
  check_allowed_tools_exact \
    openspec-story-review \
    Read Grep Glob Task Bash

  # Schema and template ownership must name the complete current writer set.
  for writer in /openspec-story-plan /openspec-story-plan-resume; do
    require_schema_writer proposal "$writer"
    require_template_writer proposal "$writer"
    require_schema_writer specs "$writer"
    require_template_writer spec "$writer"
  done
  for writer in \
    /openspec-story-plan /openspec-story-plan-review /openspec-story-plan-resume \
    /openspec-story-claim /openspec-story-resume /openspec-feedback; do
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
    /openspec-pr; do
    require_schema_writer progress "$writer"
    require_template_writer progress "$writer"
  done
  for writer in /openspec-story-claim /openspec-story-resume /openspec-feedback; do
    require_schema_writer blocked "$writer"
    require_template_writer blocked "$writer"
  done
  forbid_literal \
    "schema removes all review artifact ownership" \
    "$REPO_ROOT/openspec/schemas/story-change/schema.yaml" \
    '/openspec-story-review'
  forbid_literal \
    "story template removes all review artifact ownership" \
    "$STORY_TEMPLATE" \
    '/openspec-story-review'
  forbid_literal \
    "progress template removes all review artifact ownership" \
    "$PROGRESS_TEMPLATE" \
    '/openspec-story-review'
  forbid_literal \
    "blocked template removes all review artifact ownership" \
    "$REPO_ROOT/openspec/schemas/story-change/templates/blocked.md" \
    '/openspec-story-review'
  require_literal \
    "schema assigns completed-review publication to feedback" \
    "$REPO_ROOT/openspec/schemas/story-change/schema.yaml" \
    '/openspec-feedback publishes completed review Status:'
  require_literal \
    "story template assigns completed-review Status to feedback" \
    "$STORY_TEMPLATE" \
    '`/openspec-feedback` publishes completed-verdict Status'
  require_literal \
    "progress template assigns receipt publication to feedback" \
    "$PROGRESS_TEMPLATE" \
    'written by `/openspec-feedback` from a validated completed-review handoff only.'
  require_literal \
    "blocked template assigns review blocker publication to feedback" \
    "$REPO_ROOT/openspec/schemas/story-change/templates/blocked.md" \
    '`/openspec-feedback` publishes a completed BLOCKED review handoff'

  # Writer metadata is prose, so positive substring checks alone are not exact.
  # Compare every command token in each ownership block/template with its full set.
  for writer_artifact in story progress blocked; do
    case "$writer_artifact" in
      story)
        expected_writers="$(printf '%s\n' \
          /openspec-feedback /openspec-story-claim /openspec-story-plan \
          /openspec-story-plan-resume /openspec-story-plan-review \
          /openspec-story-resume | sort)"
        ;;
      progress)
        expected_writers="$(printf '%s\n' \
          /openspec-feedback /openspec-pr /openspec-story-claim \
          /openspec-story-resume | sort)"
        ;;
      blocked)
        expected_writers="$(printf '%s\n' \
          /openspec-feedback /openspec-story-claim /openspec-story-resume | sort)"
        ;;
    esac
    schema_writers="$(schema_artifact_block "$writer_artifact" | grep -Eo '/(openspec|opsx)[-:][a-z0-9:-]+' | sort -u || true)"
    template_writers="$(grep -Eo '/(openspec|opsx)[-:][a-z0-9:-]+' "$REPO_ROOT/openspec/schemas/story-change/templates/$writer_artifact.md" | sort -u || true)"
    if [[ "$schema_writers" == "$expected_writers" ]]; then
      ok "writer metadata: schema $writer_artifact has the exact command set"
    else
      fail "writer metadata: schema $writer_artifact command set mismatch"
    fi
    if [[ "$template_writers" == "$expected_writers" ]]; then
      ok "writer metadata: template $writer_artifact has the exact command set"
    else
      fail "writer metadata: template $writer_artifact command set mismatch"
    fi
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

  # The PR final mutation gate keeps each failure on its owning route. Invalid
  # receipt shape reopens through feedback, identity drift may require fresh review,
  # and durable state/root changes must not be collapsed into that review route.
  pr_entry_recheck="$TMPDIR/pr-entry-condition-recheck.md"
  awk '
    /^### Entry-condition recheck[[:space:]]*$/ { capture=1 }
    capture && /^### / && $0 !~ /^### Entry-condition recheck[[:space:]]*$/ { exit }
    capture { print }
  ' "$CLAUDE_SKILLS/openspec-pr/SKILL.md" >"$pr_entry_recheck"
  require_literal \
    "PR final recheck invalid receipt uses feedback reopen" \
    "$pr_entry_recheck" \
    'If receipt evidence is missing, duplicate, malformed, or non-approving for a bound modern story, abort without any `gh` or progress action using the ordinary-feedback reopen route above.'
  require_literal \
    "PR final recheck separates state/operator routes from identity review" \
    "$pr_entry_recheck" \
    'At final recheck, root ambiguity requires operator root correction; an archived story aborts as ineligible; a new blocker requires operator resolution/removal; non-DONE Status uses the state-correct diagnostic route; non-approved Plan uses only the contradictory durable-state operator action; only identity mismatch or unverifiable identity uses the fresh-review route.'
  forbid_literal \
    "PR final recheck does not blanket-route durable state failures to review" \
    "$pr_entry_recheck" \
    'If the root becomes ambiguous, the story is archived, `blocked.md` appeared, Status is no longer DONE, Plan is no longer unambiguously approved, or identity evidence mismatches or cannot be verified, abort without any `gh` or progress action using the same fresh-review route above.'

  # Planning review owns only its Plan lane. Claim/resume own implementation entry
  # and re-entry; readonly implementation review authors target state in its handoff,
  # while feedback alone publishes completed-review transitions.
  check_workflow_contract \
    "plan review preserves implementation Status ownership" openspec-story-plan-review \
    'the implementation `Status:` header field on `story.md` (`⚪ TODO`, `🔄 IN PROGRESS`, `🟣 IN REVIEW`, `✅ DONE`, `⛔ BLOCKED`)' \
    'This planning command does neither.' \
    'The substantive implementation review authors any normalized completed-review handoff; `/openspec-feedback` validates and publishes it.' \
    'Non-looped pass:** TODO -> `/openspec-story-claim`, IN PROGRESS -> `/openspec-story-resume`'

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
