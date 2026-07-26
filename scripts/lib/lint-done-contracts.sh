#!/usr/bin/env bash
# Structural DONE routing contracts. Only visible, column-zero fenced DSL blocks
# are policy; prose, quotations, comments, blockquotes, and generic fences are not.

DONE_DELIVERY_ORDER='blocker>receipt-or-pre-v3>plan>identity>task-proof>feedback-stop>delivery'
DONE_READONLY_ORDER='blocker>receipt-or-pre-v3>plan>known-contradiction>consistent-done'
DONE_SHALLOW_ORDER='blocker>receipt-or-pre-v3>plan>already-known-contradiction>defer'
DONE_RECEIPT='bound-modern:exactly-one-approve-pass|pre-v3:unbound+zero-initiative-like+zero-receipt+no-identity'
DONE_TASK_PROOF='tasks:missing|whitespace-only|malformed-checkbox-like|no-valid-checkbox|unchecked=>contradiction;valid-task-lines:- [ ] <nonempty>|- [x] <nonempty>|- [X] <nonempty>;apm:missing-table|malformed-table|missing-required-A<n>-row|missing-proof-method|missing-reviewer-action|missing-expected-evidence|missing-relevant-surfaces|missing-proof-maturity|invalid-proof-maturity|provisional-regardless-of-open-detail|final-open-detail-neither-blank-nor-explicitly-closed=>contradiction'
DONE_FEEDBACK='ordinary-feedback+preserve-receipt+no-delivery-write'
DONE_DEEP_ROUTES='receipt-invalid=>feedback|plan-invalid=>operator-stop|identity-invalid=>feedback|task-proof-invalid=>feedback|all-prior-pass=>delivery'
DONE_READONLY_ROUTES='receipt-invalid=>feedback|plan-invalid=>operator-stop|known-contradiction=>feedback|consistent-done=>next-action'
DONE_SHALLOW_ROUTES='receipt-invalid=>feedback|plan-invalid=>operator-stop|already-known-contradiction=>feedback|otherwise=>delivery-owner'

# Emit each complete, visible contract body and its immediately preceding visible
# source line. An unclosed generic fence hides the rest of the document; an
# unclosed contract fence is never emitted.
_done_contract_split_blocks() {
  local file="$1" out="$2"
  mkdir -p "$out"
  awk -v out="$out" '
    function uncomment(raw, result, start, finish) {
      result = ""
      while (1) {
        if (comment) {
          finish = index(raw, "-->")
          if (!finish) return result
          raw = substr(raw, finish + 3)
          comment = 0
        } else {
          start = index(raw, "<!--")
          if (!start) return result raw
          result = result substr(raw, 1, start - 1)
          raw = substr(raw, start + 4)
          comment = 1
        }
      }
    }
    {
      line = uncomment($0)
      if (generic) {
        if (line == generic_mark) generic = 0
        next
      }
      if (!inside && line == "```openspec-contract") {
        inside = 1
        body = ""
        heading = previous
        next
      }
      if (!inside && (line ~ /^```/ || line ~ /^~~~/)) {
        generic = 1
        generic_mark = substr(line, 1, 3)
        next
      }
      if (inside && line == "```") {
        count++
        printf "%s", body > (out "/" count ".block")
        printf "%s\n", heading > (out "/" count ".heading")
        close(out "/" count ".block")
        close(out "/" count ".heading")
        inside = 0
        body = ""
        previous = line
        next
      }
      if (inside) {
        body = body line "\n"
        next
      }
      previous = line
    }
  ' "$file"
}

_done_contract_expected_keys() {
  local contract="$1" owner="${2:-}" name="${3:-}"
  case "$contract" in
    done-delivery-v1) printf '%s\n' contract owner mode order receipt plan identity task-proof feedback delivery routes ;;
    done-readonly-route-v1|done-shallow-route-v1) printf '%s\n' contract owner mode order receipt plan checks writes routes ;;
    done-invocation-v1)
      printf '%s\n' contract owner name invokes checkpoint before
      case "$owner:$name" in
        openspec-archive:pre-archive-mutation|openspec-pr:final-recheck)
          printf '%s\n' reread recheck
          ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

_done_contract_identity() {
  case "$1" in
    openspec-archive) printf '%s' 'modern:no-pr-recompute|merged-pr:receipt-digest-only|pre-v3:none' ;;
    openspec-next-action|openspec-pr) printf '%s' 'modern:recompute|pre-v3:none' ;;
    *) return 1 ;;
  esac
}

_done_invocation_spec() {
  local owner="$1" name="$2"
  case "$owner:$name" in
    openspec-archive:pre-archive-mutation) printf '%s\n' pre-archive-mutation first-archive-mutation ;;
    openspec-next-action:pre-delivery-recommendation) printf '%s\n' pre-delivery-recommendation delivery-recommendation ;;
    openspec-pr:initial-resolution) printf '%s\n' initial-resolution resolved-context-publication ;;
    openspec-pr:final-recheck) printf '%s\n' final-recheck first-pr-or-progress-mutation ;;
    *) return 1 ;;
  esac
}

_done_contract_validate_block() {
  local block="$1" expected_owner="$2" expected_contract="$3"
  local -a keys=() values=() expected=() invocation=()
  local line key value i contract owner heading
  local -A seen=()
  while IFS= read -r line; do
    [[ -n "$line" && "$line" =~ ^([a-z][a-z0-9-]*):\ (.+)$ ]] || { printf 'shape'; return; }
    key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
    [[ -z "${seen[$key]:-}" ]] || { printf 'duplicate-key:%s' "$key"; return; }
    seen[$key]=1; keys+=("$key"); values+=("$value")
  done <"$block"
  contract="${values[0]:-}"; owner="${values[1]:-}"
  [[ "$contract" == "$expected_contract" ]] || { printf 'contract'; return; }
  [[ "$owner" == "$expected_owner" ]] || { printf 'owner'; return; }
  mapfile -t expected < <(_done_contract_expected_keys "$contract" "$owner" "${values[2]:-}")
  [[ "${#keys[@]}" == "${#expected[@]}" ]] || { printf 'key-inventory'; return; }
  for i in "${!expected[@]}"; do
    [[ "${keys[$i]}" == "${expected[$i]}" ]] || { printf 'key-order:%s' "${expected[$i]}"; return; }
  done
  case "$contract" in
    done-delivery-v1)
      [[ "${values[2]}" == deep ]] || { printf 'mode'; return; }
      [[ "${values[3]}" == "$DONE_DELIVERY_ORDER" ]] || { printf 'order'; return; }
      [[ "${values[4]}" == "$DONE_RECEIPT" ]] || { printf 'receipt'; return; }
      [[ "${values[5]}" == approved-only ]] || { printf 'plan'; return; }
      [[ "${values[6]}" == "$(_done_contract_identity "$owner")" ]] || { printf 'identity'; return; }
      [[ "${values[7]}" == "$DONE_TASK_PROOF" ]] || { printf 'task-proof'; return; }
      [[ "${values[8]}" == "$DONE_FEEDBACK" ]] || { printf 'feedback'; return; }
      [[ "${values[9]}" == all-prior-pass ]] || { printf 'delivery'; return; }
      [[ "${values[10]}" == "$DONE_DEEP_ROUTES" ]] || { printf 'routes'; return; }
      ;;
    done-readonly-route-v1)
      [[ "${values[2]}" == readonly ]] || { printf 'mode'; return; }
      [[ "${values[3]}" == "$DONE_READONLY_ORDER" ]] || { printf 'order'; return; }
      [[ "${values[4]}" == "$DONE_RECEIPT" ]] || { printf 'receipt'; return; }
      [[ "${values[5]}" == approved-only ]] || { printf 'plan'; return; }
      [[ "${values[6]}" == already-known-only ]] || { printf 'checks'; return; }
      [[ "${values[7]}" == forbidden ]] || { printf 'writes'; return; }
      [[ "${values[8]}" == "$DONE_READONLY_ROUTES" ]] || { printf 'routes'; return; }
      ;;
    done-shallow-route-v1)
      [[ "${values[2]}" == shallow ]] || { printf 'mode'; return; }
      [[ "${values[3]}" == "$DONE_SHALLOW_ORDER" ]] || { printf 'order'; return; }
      [[ "${values[4]}" == "$DONE_RECEIPT" ]] || { printf 'receipt'; return; }
      [[ "${values[5]}" == approved-only ]] || { printf 'plan'; return; }
      [[ "${values[6]}" == already-known-only+deep-forbidden ]] || { printf 'checks'; return; }
      [[ "${values[7]}" == forbidden-before-route ]] || { printf 'writes'; return; }
      [[ "${values[8]}" == "$DONE_SHALLOW_ROUTES" ]] || { printf 'routes'; return; }
      ;;
    done-invocation-v1)
      mapfile -t invocation < <(_done_invocation_spec "$owner" "${values[2]}")
      [[ "${#invocation[@]}" == 2 ]] || { printf 'name'; return; }
      [[ "${values[3]}" == done-delivery-v1 ]] || { printf 'invokes'; return; }
      [[ "${values[4]}" == "${invocation[0]}" ]] || { printf 'checkpoint'; return; }
      [[ "${values[5]}" == "${invocation[1]}" ]] || { printf 'before'; return; }
      case "$owner:${values[2]}" in
        openspec-archive:pre-archive-mutation|openspec-pr:final-recheck)
          [[ "${values[6]}" == 'current-story.md+current-tasks.md+current-progress.md+current-blocked.md' ]] || { printf 'reread'; return; }
          [[ "${values[7]}" == 'receipt-or-pre-v3>plan>identity>task-proof>feedback-stop' ]] || { printf 'recheck'; return; }
          ;;
      esac
      heading="$(<"${block%.block}.heading")"
      [[ "$heading" == "### DONE contract checkpoint: ${values[4]}" ]] || { printf 'heading'; return; }
      ;;
  esac
}

_done_contract_matching_blocks() {
  local dir="$1" owner="$2" contract="$3" block
  for block in "$dir"/*.block; do
    [[ -e "$block" ]] || continue
    grep -Fxq "contract: $contract" "$block" || continue
    grep -Fxq "owner: $owner" "$block" || continue
    printf '%s\n' "$block"
  done
}

_done_contract_allowed() {
  local owner="$1" contract="$2"
  case "$owner:$contract" in
    openspec-archive:done-delivery-v1|openspec-archive:done-invocation-v1|\
    openspec-next-action:done-delivery-v1|openspec-next-action:done-invocation-v1|\
    openspec-pr:done-delivery-v1|openspec-pr:done-invocation-v1|\
    openspec-story-review:done-readonly-route-v1|\
    openspec-story-claim:done-shallow-route-v1|openspec-story-resume:done-shallow-route-v1|\
    openspec-story-converge:done-shallow-route-v1|openspec-story-plan-review:done-shallow-route-v1|\
    openspec-story-plan-converge:done-shallow-route-v1|openspec-story-plan-resume:done-shallow-route-v1) return 0 ;;
    *) return 1 ;;
  esac
}

# Inventory is intentionally non-requiring: canonical missing checks own migration
# REDs, while generated inventory can still reject injected unknown/duplicate blocks.
lint_done_contract_inventory_findings() {
  local file="$1" expected_owner="$2" tmp block contract owner key
  local -A counts=()
  tmp="$(mktemp -d)" || return 1
  _done_contract_split_blocks "$file" "$tmp"
  for block in "$tmp"/*.block; do
    [[ -e "$block" ]] || continue
    contract="$(awk -F': ' '$1=="contract" {print $2}' "$block")"
    owner="$(awk -F': ' '$1=="owner" {print $2}' "$block")"
    if [[ -z "$contract" || -z "$owner" ]] || ! _done_contract_allowed "$expected_owner" "$contract" || [[ "$owner" != "$expected_owner" ]]; then
      printf 'done-contract:unknown-block:%s\n' "${contract:-missing-contract}"
      continue
    fi
    key="$owner:$contract"
    if [[ "$contract" == done-invocation-v1 ]]; then
      key="$key:$(awk -F': ' '$1=="name" {print $2}' "$block")"
    fi
    counts[$key]=$(( ${counts[$key]:-0} + 1 ))
  done
  for key in "${!counts[@]}"; do
    if [[ "${counts[$key]}" -gt 1 ]]; then
      printf 'done-contract:duplicate-block:%s\n' "$key"
    fi
  done
  rm -rf "$tmp"
}

# Backward-compatible name used by older focused harnesses.
lint_done_contract_unknown_findings() {
  lint_done_contract_inventory_findings "$@"
}

lint_done_contract_file_findings() {
  local file="$1" owner="$2" contract="$3" tmp block result count=0
  tmp="$(mktemp -d)" || return 1
  _done_contract_split_blocks "$file" "$tmp"
  while IFS= read -r block; do
    count=$((count + 1))
    result="$(_done_contract_validate_block "$block" "$owner" "$contract")"
    [[ -z "$result" ]] || printf 'done-contract:%s:%s:%s\n' "$owner" "$contract" "$result"
  done < <(_done_contract_matching_blocks "$tmp" "$owner" "$contract")
  if (( count == 0 )); then
    printf 'done-contract:%s:%s:missing\n' "$owner" "$contract"
  elif (( count > 1 )); then
    printf 'done-contract:%s:%s:duplicate-block\n' "$owner" "$contract"
  fi
  rm -rf "$tmp"
}

lint_done_invocation_findings() {
  local file="$1" owner="$2" tmp block result name
  local -a actual=() expected=()
  tmp="$(mktemp -d)" || return 1
  _done_contract_split_blocks "$file" "$tmp"
  while IFS= read -r block; do
    result="$(_done_contract_validate_block "$block" "$owner" done-invocation-v1)"
    if [[ -n "$result" ]]; then
      printf 'done-invocation:%s:invalid:%s\n' "$owner" "$result"
    else
      name="$(awk -F': ' '$1=="name" {print $2}' "$block")"
      actual+=("$name")
    fi
  done < <(_done_contract_matching_blocks "$tmp" "$owner" done-invocation-v1)
  case "$owner" in
    openspec-archive) expected=(pre-archive-mutation) ;;
    openspec-next-action) expected=(pre-delivery-recommendation) ;;
    openspec-pr) expected=(initial-resolution final-recheck) ;;
  esac
  [[ "${actual[*]}" == "${expected[*]}" ]] || \
    printf 'done-invocation:%s:expected:%s:got:%s\n' "$owner" "${expected[*]}" "${actual[*]:-none}"
  rm -rf "$tmp"
}

_done_contract_extract_matching() {
  local file="$1" owner="$2" contract="$3" tmp block
  tmp="$(mktemp -d)" || return 1
  _done_contract_split_blocks "$file" "$tmp"
  while IFS= read -r block; do
    printf '%s\n' '```openspec-contract'
    cat "$block"
    printf '%s\n' '```'
  done < <(_done_contract_matching_blocks "$tmp" "$owner" "$contract")
  rm -rf "$tmp"
}

lint_done_contract_parity_findings() {
  local canonical="$1" generated="$2" owner="$3" contract="$4" left right
  left="$(_done_contract_extract_matching "$canonical" "$owner" "$contract")"
  [[ -n "$left" ]] || return 0
  right="$(_done_contract_extract_matching "$generated" "$owner" "$contract")"
  [[ "$left" == "$right" ]] || printf 'done-contract-parity:%s:%s:%s\n' "$owner" "$contract" "$generated"
}

lint_done_contract_denylist_findings() {
  local file="$1" owner="${2:-}" phrase
  local -a direct_review_phrases=(
    'A receiptless bound modern DONE routes to `/openspec-story-review`.'
    'A bound modern DONE without a receipt routes only to the same fresh oblivious review.'
    'using the same fresh-review route above.'
  )
  local -a deep_owner_phrases=('recompute canonical `review-identity-v1`' 'full DONE delivery qualification')
  for phrase in "${direct_review_phrases[@]}"; do
    grep -Fn -- "$phrase" "$file" | sed 's/^/done-toxic-direct-review:/' || true
  done
  case "$owner" in
    openspec-archive|openspec-next-action|openspec-pr) ;;
    *)
      for phrase in "${deep_owner_phrases[@]}"; do
        grep -Fn -- "$phrase" "$file" | sed 's/^/done-toxic-deep-ownership:/' || true
      done
      ;;
  esac
}

_done_contract_without_comments() {
  awk '
    {
      line=$0; out=""
      while (1) {
        if (comment) {
          finish=index(line, "-->")
          if (!finish) { line=""; break }
          line=substr(line, finish + 3); comment=0
        } else {
          start=index(line, "<!--")
          if (!start) { out=out line; break }
          out=out substr(line, 1, start - 1)
          line=substr(line, start + 4); comment=1
        }
      }
      if (!comment || out != "") print out
    }
  ' "$1"
}

# Active contract prompts must not carry the obsolete alternative that sends a
# valid-receipt DONE identity/task/proof contradiction to review. This is a
# deliberately narrow vocabulary check, not a polarity or general NLP parser:
# quoting or negating the toxic route still keeps it in the active prompt.
lint_done_contract_review_contradiction_findings() {
  local file="$1" owner="$2"
  _done_contract_without_comments "$file" | awk -v owner="$owner" 'BEGIN { RS="" }
    {
      text = tolower($0)
      gsub(/`/, "", text)
      done_context = text ~ /(^|[^a-z])done([^a-z]|$)/
      contradiction = text ~ /(valid[ -]receipt[^.!?;]*(identity|task|proof|evidence)[^.!?;]*contradiction|identity[^.!?;]*(mismatch|unverifiable|contradiction)|unchecked[^.!?;]*task|task[^.!?;]*contradict|proof[^.!?;]*(provisional|missing|invalid|incomplete|stale|contradict)|evidence[^.!?;]*(incomplete|stale|contradict))/
      review_route = text ~ /(\/openspec[ -]story[ -]review|fresh[ -](oblivious[ -]|substantive[ -])?(story[ -])?review)/
      route_word = text ~ /(route|routes|routed|recommend|recommends|recommended|send|sends|sent|return|returns|returned|use|uses|used|open|opens|opened|run|runs|invoke|invokes|invoked|direct|directs|directly)/
      identity_contradiction = text ~ /identity[^.!?;]*(mismatch|unverifiable|contradiction)/
      if ((done_context || identity_contradiction) && contradiction && review_route && route_word) {
        print "done-toxic-valid-receipt-review-route:" owner
        exit
      }
    }
  '
}

# Active prompt instructions must never couple DONE directly to story-review.
# This intentionally conservative line rule avoids a synonym/polarity parser;
# mixed-state prose must put its IN REVIEW route on a separate instruction.
lint_done_contract_direct_done_review_findings() {
  local file="$1" owner="$2"
  _done_contract_without_comments "$file" | awk -v owner="$owner" '
    {
      line = $0
      gsub(/`/, "", line)
      if (line ~ /(^|[^A-Z])DONE([^A-Z]|$)/ && line ~ /\/openspec-story-review/) {
        print "done-direct-story-review:" owner ":" NR
      }
    }
  '
}

# PR resolved-context qualification must preserve both the authoritative modern
# binding and the exact Phase-0 legacy association route.
lint_done_contract_pr_pre_v3_association_findings() {
  local file="$1"
  grep -Fxq 'A DONE story qualifies as resolved PR context only when it has either a matching modern authoritative Initiative binding or the exact pre-v3 Phase 0 explicit/unique legacy association.' "$file" ||
    printf 'done-pre-v3-association:openspec-pr:missing-modern-or-phase-0-legacy-qualification\n'
}

# Next-action and PR must scope receipt-based identity calculation to modern
# receipt-bearing DONE on the same instruction, and must visibly preserve the
# exact no-identity pre-v3 placeholder path.
lint_done_contract_pre_v3_identity_findings() {
  local file="$1" owner="$2" broad=0 has_legacy=0
  case "$owner" in openspec-next-action|openspec-pr) ;; *) return 0 ;; esac

  if _done_contract_without_comments "$file" | awk '
    {
      line = tolower($0)
      gsub(/`/, "", line)
      calculate = line ~ /(recompute|calculate|compute|derive|verify)[^.;]*(implementation|story-scoped|canonical|review-identity)[^.;]*identity/ ||
        line ~ /(recompute|calculate|compute|derive|verify)[^.;]*review-identity-v1/
      recorded = line ~ /receipt-recorded|receipt.s recorded|recorded bases\/path|recorded identity bases/
      scoped = line ~ /(^|[^a-z])modern([^a-z]|$)/ &&
        line ~ /(^|[^a-z])receipt([^a-z]|$)/ && line ~ /(^|[^a-z])done([^a-z]|$)/
      if (calculate && recorded && !scoped) bad=1
    }
    END { exit bad ? 0 : 1 }
  '; then
    broad=1
  fi

  if _done_contract_without_comments "$file" | awk 'BEGIN { RS="" }
    {
      text = tolower($0)
      gsub(/`/, "", text)
      pre_v3 = text ~ /pre-v3/ && text ~ /no[ -]receipt|zero[ -]receipt/
      skip = text ~ /(skip|skips|without|no)[^.!?;]*identity[^.!?;]*recomput|identity[^.!?;]*recomput[^.!?;]*(skip|skips|without|none|no identity)/
      placeholder = text ~ /placeholder/ && text ~ /(digest|timestamp|verified implementation|verified at)/
      if (pre_v3 && skip && placeholder) good=1
    }
    END { exit good ? 0 : 1 }
  '; then
    has_legacy=1
  fi

  if (( broad || !has_legacy )); then
    printf 'done-pre-v3-identity-conflict:%s:unqualified-recompute-or-missing-skip-placeholder\n' "$owner"
  fi
}

# Portable exact transformations for fixtures, implemented with POSIX awk.
_done_transform() {
  local input="$1" output="$2" mode="$3"
  awk -v mode="$mode" '
    mode == "drop-delivery" && $0 == "delivery: all-prior-pass" { next }
    mode == "wrong-value" && $0 == "delivery: all-prior-pass" { print "delivery: early"; next }
    mode == "wrong-order" && /^order:/ { print "order: blocker>plan>receipt-or-pre-v3>identity>task-proof>feedback-stop>delivery"; next }
    mode == "early-delivery" && /^order:/ { print "order: blocker>delivery>receipt-or-pre-v3>plan>identity>task-proof>feedback-stop"; next }
    mode == "swap-plan-identity" && /^plan:/ { print "identity: approved-only"; next }
    mode == "swap-plan-identity" && /^identity:/ { sub(/^identity:/, "plan:"); print; next }
    mode == "incomplete-task-proof" { sub(/\|unchecked=>contradiction/, "") }
    mode == "missing-apm-table" { sub(/missing-table\|/, "") }
    mode == "malformed-apm-table" { sub(/malformed-table\|/, "") }
    mode == "missing-apm-row" { sub(/missing-required-A<n>-row\|/, "") }
    mode == "missing-proof-method" { sub(/missing-proof-method\|/, "") }
    mode == "missing-reviewer-action" { sub(/missing-reviewer-action\|/, "") }
    mode == "missing-expected-evidence" { sub(/missing-expected-evidence\|/, "") }
    mode == "missing-relevant-surfaces" { sub(/missing-relevant-surfaces\|/, "") }
    mode == "missing-proof-maturity" { sub(/missing-proof-maturity\|/, "") }
    mode == "invalid-proof-maturity" { sub(/invalid-proof-maturity\|/, "") }
    mode == "missing-provisional-rule" { sub(/provisional-regardless-of-open-detail\|/, "") }
    mode == "missing-final-open-detail-rule" { sub(/\|final-open-detail-neither-blank-nor-explicitly-closed/, "") }
    mode == "unknown-key" && /^routes:/ { print; print "unknown: value"; next }
    mode == "duplicate-key" && /^routes:/ { print; print "routes: duplicate"; next }
    mode == "wrong-owner" && $0 == "owner: openspec-pr" { print "owner: openspec-archive"; next }
    mode == "wrong-mode" && $0 == "mode: deep" { print "mode: shallow"; next }
    mode == "pre-v3-identity" { sub(/\+no-identity/, "") }
    mode == "bad-route" { sub(/identity-invalid=>feedback/, "identity-invalid=>review") }
    mode == "prefix-name" && $0 == "name: final-recheck" { print "name: final"; next }
    mode == "undefined-invokes" && $0 == "invokes: done-delivery-v1" { print "invokes: full-done-gate"; next }
    mode == "wrong-checkpoint" && !changed && $0 == "checkpoint: initial-resolution" { print "checkpoint: final-recheck"; changed=1; next }
    mode == "wrong-before" && !changed && $0 == "before: resolved-context-publication" { print "before: delivery-recommendation"; changed=1; next }
    mode == "drop-reread" && $0 == "reread: current-story.md+current-tasks.md+current-progress.md+current-blocked.md" { next }
    mode == "drop-recheck" && $0 == "recheck: receipt-or-pre-v3>plan>identity>task-proof>feedback-stop" { next }
    mode == "detached-heading" && $0 == "### DONE contract checkpoint: initial-resolution" { print; print "detached prose"; next }
    mode == "wrong-heading" && $0 == "### DONE contract checkpoint: initial-resolution" { print "### DONE contract checkpoint: final-recheck"; next }
    mode == "readonly-plan-order" && /^order:/ { print "order: blocker>receipt-or-pre-v3>known-contradiction>plan>consistent-done"; next }
    mode == "shallow-deep" && $0 == "mode: shallow" { print "mode: deep"; next }
    { print }
  ' "$input" >"$output"
}

lint_done_contract_selftest() {
  local tmp valid mutated findings label mode
  tmp="$(mktemp -d)" || return 1
  valid="$tmp/valid.md"
  # This known-good fixture is deliberately literal and independent of the
  # validator constants, so changing the implementation cannot bless itself.
  cat >"$valid" <<'EOF'
```openspec-contract
contract: done-delivery-v1
owner: openspec-pr
mode: deep
order: blocker>receipt-or-pre-v3>plan>identity>task-proof>feedback-stop>delivery
receipt: bound-modern:exactly-one-approve-pass|pre-v3:unbound+zero-initiative-like+zero-receipt+no-identity
plan: approved-only
identity: modern:recompute|pre-v3:none
task-proof: tasks:missing|whitespace-only|malformed-checkbox-like|no-valid-checkbox|unchecked=>contradiction;valid-task-lines:- [ ] <nonempty>|- [x] <nonempty>|- [X] <nonempty>;apm:missing-table|malformed-table|missing-required-A<n>-row|missing-proof-method|missing-reviewer-action|missing-expected-evidence|missing-relevant-surfaces|missing-proof-maturity|invalid-proof-maturity|provisional-regardless-of-open-detail|final-open-detail-neither-blank-nor-explicitly-closed=>contradiction
feedback: ordinary-feedback+preserve-receipt+no-delivery-write
delivery: all-prior-pass
routes: receipt-invalid=>feedback|plan-invalid=>operator-stop|identity-invalid=>feedback|task-proof-invalid=>feedback|all-prior-pass=>delivery
```
### DONE contract checkpoint: initial-resolution
```openspec-contract
contract: done-invocation-v1
owner: openspec-pr
name: initial-resolution
invokes: done-delivery-v1
checkpoint: initial-resolution
before: resolved-context-publication
```
### DONE contract checkpoint: final-recheck
```openspec-contract
contract: done-invocation-v1
owner: openspec-pr
name: final-recheck
invokes: done-delivery-v1
checkpoint: final-recheck
before: first-pr-or-progress-mutation
reread: current-story.md+current-tasks.md+current-progress.md+current-blocked.md
recheck: receipt-or-pre-v3>plan>identity>task-proof>feedback-stop
```
EOF
  [[ -z "$(lint_done_contract_file_findings "$valid" openspec-pr done-delivery-v1)" ]] || { rm -rf "$tmp"; return 1; }
  [[ -z "$(lint_done_invocation_findings "$valid" openspec-pr)" ]] || { rm -rf "$tmp"; return 1; }
  [[ -z "$(lint_done_contract_inventory_findings "$valid" openspec-pr)" ]] || { rm -rf "$tmp"; return 1; }

  for mode in drop-delivery wrong-value wrong-order early-delivery swap-plan-identity \
    incomplete-task-proof missing-apm-table malformed-apm-table missing-apm-row \
    missing-proof-method missing-reviewer-action missing-expected-evidence \
    missing-relevant-surfaces missing-proof-maturity invalid-proof-maturity \
    missing-provisional-rule missing-final-open-detail-rule unknown-key duplicate-key \
    wrong-owner wrong-mode pre-v3-identity bad-route; do
    mutated="$tmp/$mode.md"
    _done_transform "$valid" "$mutated" "$mode"
    findings="$(lint_done_contract_file_findings "$mutated" openspec-pr done-delivery-v1)"
    [[ -n "$findings" ]] || { printf 'selftest missed %s\n' "$mode" >&2; rm -rf "$tmp"; return 1; }
  done

  for mode in prefix-name undefined-invokes wrong-checkpoint wrong-before drop-reread drop-recheck detached-heading wrong-heading; do
    mutated="$tmp/$mode.md"
    _done_transform "$valid" "$mutated" "$mode"
    [[ -n "$(lint_done_invocation_findings "$mutated" openspec-pr)" ]] || { printf 'selftest missed %s invocation\n' "$mode" >&2; rm -rf "$tmp"; return 1; }
  done

  mutated="$tmp/duplicate.md"; cat "$valid" "$valid" >"$mutated"
  [[ "$(lint_done_contract_inventory_findings "$mutated" openspec-pr)" == *duplicate-block* ]] || { printf 'selftest missed duplicate inventory\n' >&2; rm -rf "$tmp"; return 1; }
  [[ "$(lint_done_contract_file_findings "$mutated" openspec-pr done-delivery-v1)" == *duplicate-block* ]] || { printf 'selftest missed duplicate contract\n' >&2; rm -rf "$tmp"; return 1; }
  [[ -n "$(lint_done_invocation_findings "$mutated" openspec-pr)" ]] || { printf 'selftest missed duplicate invocation\n' >&2; rm -rf "$tmp"; return 1; }

  cat >"$tmp/archive-invocation.md" <<'EOF'
### DONE contract checkpoint: pre-archive-mutation
```openspec-contract
contract: done-invocation-v1
owner: openspec-archive
name: pre-archive-mutation
invokes: done-delivery-v1
checkpoint: pre-archive-mutation
before: first-archive-mutation
reread: current-story.md+current-tasks.md+current-progress.md+current-blocked.md
recheck: receipt-or-pre-v3>plan>identity>task-proof>feedback-stop
```
EOF
  [[ -z "$(lint_done_invocation_findings "$tmp/archive-invocation.md" openspec-archive)" ]] || { printf 'selftest rejected archive invocation reread/recheck\n' >&2; rm -rf "$tmp"; return 1; }
  _done_transform "$tmp/archive-invocation.md" "$tmp/archive-missing-reread.md" drop-reread
  [[ -n "$(lint_done_invocation_findings "$tmp/archive-missing-reread.md" openspec-archive)" ]] || { printf 'selftest accepted archive invocation without reread\n' >&2; rm -rf "$tmp"; return 1; }
  _done_transform "$tmp/archive-invocation.md" "$tmp/archive-missing-recheck.md" drop-recheck
  [[ -n "$(lint_done_invocation_findings "$tmp/archive-missing-recheck.md" openspec-archive)" ]] || { printf 'selftest accepted archive invocation without recheck\n' >&2; rm -rf "$tmp"; return 1; }

  mutated="$tmp/generated-unknown.md"
  { cat "$valid"; printf '%s\n' '```openspec-contract' 'contract: done-magic-v2' 'owner: openspec-pr' '```'; } >"$mutated"
  [[ "$(lint_done_contract_inventory_findings "$mutated" openspec-pr)" == *unknown-block:done-magic-v2* ]] || { printf 'selftest missed generated unknown block\n' >&2; rm -rf "$tmp"; return 1; }

  mutated="$tmp/readonly.md"
  cat >"$mutated" <<'EOF'
```openspec-contract
contract: done-readonly-route-v1
owner: openspec-story-review
mode: readonly
order: blocker>receipt-or-pre-v3>plan>known-contradiction>consistent-done
receipt: bound-modern:exactly-one-approve-pass|pre-v3:unbound+zero-initiative-like+zero-receipt+no-identity
plan: approved-only
checks: already-known-only
writes: forbidden
routes: receipt-invalid=>feedback|plan-invalid=>operator-stop|known-contradiction=>feedback|consistent-done=>next-action
```
EOF
  [[ -z "$(lint_done_contract_file_findings "$mutated" openspec-story-review done-readonly-route-v1)" ]] || { rm -rf "$tmp"; return 1; }
  _done_transform "$mutated" "$tmp/readonly-bad.md" readonly-plan-order
  [[ -n "$(lint_done_contract_file_findings "$tmp/readonly-bad.md" openspec-story-review done-readonly-route-v1)" ]] || { printf 'selftest missed readonly Plan order\n' >&2; rm -rf "$tmp"; return 1; }

  mutated="$tmp/shallow.md"
  cat >"$mutated" <<'EOF'
```openspec-contract
contract: done-shallow-route-v1
owner: openspec-story-claim
mode: shallow
order: blocker>receipt-or-pre-v3>plan>already-known-contradiction>defer
receipt: bound-modern:exactly-one-approve-pass|pre-v3:unbound+zero-initiative-like+zero-receipt+no-identity
plan: approved-only
checks: already-known-only+deep-forbidden
writes: forbidden-before-route
routes: receipt-invalid=>feedback|plan-invalid=>operator-stop|already-known-contradiction=>feedback|otherwise=>delivery-owner
```
EOF
  [[ -z "$(lint_done_contract_file_findings "$mutated" openspec-story-claim done-shallow-route-v1)" ]] || { rm -rf "$tmp"; return 1; }
  _done_transform "$mutated" "$tmp/shallow-bad.md" shallow-deep
  [[ -n "$(lint_done_contract_file_findings "$tmp/shallow-bad.md" openspec-story-claim done-shallow-route-v1)" ]] || { printf 'selftest accepted shallow deep mode\n' >&2; rm -rf "$tmp"; return 1; }

  while IFS='|' read -r label sentence; do
    printf '%s\n' "$sentence" >"$tmp/toxic-$label.md"
    [[ "$(lint_done_contract_review_contradiction_findings "$tmp/toxic-$label.md" openspec-pr)" == 'done-toxic-valid-receipt-review-route:openspec-pr' ]] || { printf 'selftest missed %s valid-receipt review contradiction\n' "$label" >&2; rm -rf "$tmp"; return 1; }
  done <<'EOF'
exact|For a valid-receipt DONE identity contradiction, recommend /openspec-story-review.
negated|Never route a valid-receipt DONE identity contradiction to `/openspec-story-review`.
quoted|Quote “Unchecked task evidence for a valid-receipt DONE story routes to fresh substantive review.”
historical-identity|An identity digest mismatch routes to fresh `/openspec-story-review` after canonical recomputation.
historical-task|If Status is DONE but unchecked tasks or incomplete implementation evidence contradict it, recommend a fresh `/openspec-story-review` session.
EOF
  printf '%s\n' 'A modern DONE receipt identity mismatch uses ordinary feedback.' >"$tmp/clean-review-route.md"
  [[ -z "$(lint_done_contract_review_contradiction_findings "$tmp/clean-review-route.md" openspec-pr)" ]] || { printf 'selftest rejected feedback-only contradiction\n' >&2; rm -rf "$tmp"; return 1; }

  printf '%s\n' 'For DONE after the reviewed source snapshot drifts, invoke /openspec-story-review.' >"$tmp/direct-done-review.md"
  [[ "$(lint_done_contract_direct_done_review_findings "$tmp/direct-done-review.md" openspec-pr)" == done-direct-story-review:openspec-pr:1 ]] || { printf 'selftest missed direct DONE story-review bypass\n' >&2; rm -rf "$tmp"; return 1; }
  printf '%s\n' 'For IN REVIEW after repair, invoke /openspec-story-review.' >"$tmp/in-review-only.md"
  [[ -z "$(lint_done_contract_direct_done_review_findings "$tmp/in-review-only.md" openspec-pr)" ]] || { printf 'selftest rejected IN REVIEW-only story-review route\n' >&2; rm -rf "$tmp"; return 1; }

  printf '%s\n' 'A DONE story qualifies as resolved PR context only when it has either a matching modern authoritative Initiative binding or the exact pre-v3 Phase 0 explicit/unique legacy association.' >"$tmp/qualified-pre-v3-association.md"
  [[ -z "$(lint_done_contract_pr_pre_v3_association_findings "$tmp/qualified-pre-v3-association.md")" ]] || { printf 'selftest rejected modern/legacy PR association qualification\n' >&2; rm -rf "$tmp"; return 1; }
  printf '%s\n' 'A story becomes resolved PR context only after its authoritative story.md Initiative binding matches.' >"$tmp/unconditional-modern-association.md"
  [[ "$(lint_done_contract_pr_pre_v3_association_findings "$tmp/unconditional-modern-association.md")" == done-pre-v3-association:openspec-pr:missing-modern-or-phase-0-legacy-qualification ]] || { printf 'selftest missed unconditional modern PR association\n' >&2; rm -rf "$tmp"; return 1; }

  cat >"$tmp/unscoped-pre-v3.md" <<'EOF'
Recompute implementation identity from the receipt-recorded bases and paths.
EOF
  [[ -n "$(lint_done_contract_pre_v3_identity_findings "$tmp/unscoped-pre-v3.md" openspec-pr)" ]] || { printf 'selftest missed unscoped pre-v3 identity conflict\n' >&2; rm -rf "$tmp"; return 1; }
  cat >"$tmp/unscoped-calculate-pre-v3.md" <<'EOF'
Calculate review-identity-v1 from the receipt-recorded bases and paths.
EOF
  [[ -n "$(lint_done_contract_pre_v3_identity_findings "$tmp/unscoped-calculate-pre-v3.md" openspec-pr)" ]] || { printf 'selftest missed calculate pre-v3 identity conflict\n' >&2; rm -rf "$tmp"; return 1; }
  cat >"$tmp/scoped-pre-v3.md" <<'EOF'
For a modern receipt-bearing DONE story, recompute implementation identity from the receipt-recorded bases and paths.

For the exact pre-v3 no-receipt DONE exception, skip identity recomputation and use the documented placeholder digest and Verified at timestamp handling.
EOF
  [[ -z "$(lint_done_contract_pre_v3_identity_findings "$tmp/scoped-pre-v3.md" openspec-pr)" ]] || { printf 'selftest rejected scoped modern/pre-v3 identity handling\n' >&2; rm -rf "$tmp"; return 1; }

  for label in prose quoted negated blockquote generic incomplete html-comment html-inline incomplete-generic; do
    mutated="$tmp/$label.md"
    case "$label" in
      prose) printf 'contract: done-delivery-v1\nowner: openspec-pr\n' >"$mutated" ;;
      quoted) printf '"```openspec-contract\ncontract: done-delivery-v1\n```"\n' >"$mutated" ;;
      negated) printf 'Do not use ```openspec-contract as a contract.\n' >"$mutated" ;;
      blockquote) printf '> ```openspec-contract\n> contract: done-delivery-v1\n> ```\n' >"$mutated" ;;
      generic) { printf '```text\n'; cat "$valid"; printf '```\n'; } >"$mutated" ;;
      incomplete) printf '```openspec-contract\ncontract: done-delivery-v1\nowner: openspec-pr\n' >"$mutated" ;;
      html-comment) { printf '<!--\n'; cat "$valid"; printf '%s\n' '-->'; } >"$mutated" ;;
      html-inline) { printf '<!-- hidden -->\n<!-- '; cat "$valid"; printf '%s\n' ' -->'; } >"$mutated" ;;
      incomplete-generic) { printf '```text\n'; cat "$valid"; } >"$mutated" ;;
    esac
    [[ "$(lint_done_contract_file_findings "$mutated" openspec-pr done-delivery-v1)" == *:missing ]] || { printf 'selftest accepted %s\n' "$label" >&2; rm -rf "$tmp"; return 1; }
  done
  rm -rf "$tmp"
  printf 'ok   structural DONE contract fixtures\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  lint_done_contract_selftest
fi
