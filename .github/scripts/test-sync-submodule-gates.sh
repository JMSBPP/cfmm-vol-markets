#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck source=/dev/null
source "$ROOT/.github/scripts/sync-submodule-gates.sh"

fail=0
assert_eq() {
  local got=$1 want=$2 label=$3
  if [[ "$got" != "$want" ]]; then
    echo "FAIL $label: got '$got' want '$want'"
    fail=1
  else
    echo "OK   $label"
  fi
}

export SYNC_GATE_TEST_JSON='{"check_runs":[{"name":"seam","conclusion":"success"}]}'
assert_eq "$(check_runs_conclusion d2p-finance/evm-spec-bridge deadbeefdeadbeefdeadbeefdeadbeefdeadbeef seam)" "success" "happy path"

export SYNC_GATE_TEST_JSON='{"check_runs":[]}'
assert_eq "$(check_runs_conclusion d2p-finance/evm-spec-bridge deadbeefdeadbeefdeadbeefdeadbeefdeadbeef seam)" "missing" "missing run"

export SYNC_GATE_TEST_JSON='{"check_runs":[{"name":"seam","conclusion":"success"}]}'
if require_check_run_success d2p-finance/evm-spec-bridge deadbeefdeadbeefdeadbeefdeadbeefdeadbeef seam; then
  echo "OK   accepts success"
else
  echo "FAIL should accept success"
  fail=1
fi

export SYNC_GATE_TEST_JSON='{"check_runs":[]}'
if require_check_run_success d2p-finance/evm-spec-bridge deadbeefdeadbeefdeadbeefdeadbeefdeadbeef seam 2>/dev/null; then
  echo "FAIL should reject missing"
  fail=1
else
  echo "OK   rejects missing"
fi

exit "$fail"
