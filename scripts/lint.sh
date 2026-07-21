#!/usr/bin/env bash
# Aggregate repository checks. Keep policy in focused deterministic suites.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$REPO_ROOT/scripts/lint-structure.sh"
bash "$REPO_ROOT/scripts/test-distribution.sh"
bash "$REPO_ROOT/scripts/test-installers.sh"

printf '\nlint: PASSED\n'
