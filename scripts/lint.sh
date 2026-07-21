#!/usr/bin/env bash
# Aggregate repository checks. Keep policy in focused deterministic suites.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$REPO_ROOT/scripts/lint-structure.sh"
bash "$REPO_ROOT/scripts/test-distribution.sh"
bash "$REPO_ROOT/scripts/test-installers.sh"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s "$REPO_ROOT/tests" \
  -p 'test_openspec_migrate.py' \
  -v

printf '\nlint: PASSED\n'
