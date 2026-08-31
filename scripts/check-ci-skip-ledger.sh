#!/usr/bin/env bash
# The push build (.github/workflows/push-build.yml) runs a COPY of develop-gate's --skip
# ledger and fuzz seed, on purpose: a push build that measures a different surface than the
# gate stops predicting the gate, and would go red on the pre-existing known-broken families
# the gate deliberately excludes -- which trains everyone to ignore it.
#
# Two copies drift. Extracting the command into one shared place is not available: the ledger
# line in develop-gate.yml is not allowed to move. So the copy is guarded here instead. Red
# means the two workflows would measure different surfaces; fix the copy, do not delete the
# check.
#
# Pure grep/diff. No forge, no make, no node. Runs as the FIRST step of the push job (so a
# divergence costs seconds, not a full build) and is runnable locally.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
GATE="$ROOT/.github/workflows/develop-gate.yml"
PUSH="$ROOT/.github/workflows/push-build.yml"

for f in "$GATE" "$PUSH"; do
  [ -f "$f" ] || { echo "ERROR: missing $f" >&2; exit 1; }
done

# Comment lines are STRIPPED FIRST and that is load-bearing: develop-gate.yml's ledger comment
# names the same patterns unquoted, and a future comment must not be able to satisfy this
# check. Consequence: no comment in either workflow may contain a "*...*" quoted glob.
skips() { grep -v '^[[:space:]]*#' "$1" | grep -oE '"\*[^"]+\*"' | sort -u; }
no_match_test() { grep -v '^[[:space:]]*#' "$1" | grep -oE 'no-match-test[[:space:]]+[A-Za-z0-9_]+' \
                    | tr -s '[:space:]' ' ' | sort -u; }
seed()  { grep -v '^[[:space:]]*#' "$1" | grep -oE 'fuzz-seed[[:space:]]+[0-9]+' \
            | tr -s '[:space:]' ' ' | sort -u; }

rc=0

if ! diff -u <(skips "$GATE") <(skips "$PUSH") > /tmp/skip-ledger.diff 2>&1; then
  echo "ERROR: --skip ledger diverges between develop-gate.yml and push-build.yml" >&2
  echo "       (-) is develop-gate, (+) is push-build:" >&2
  sed 's/^/       /' /tmp/skip-ledger.diff >&2
  rc=1
fi

if ! diff -u <(no_match_test "$GATE") <(no_match_test "$PUSH") > /tmp/no-match-test.diff 2>&1; then
  echo "ERROR: --no-match-test diverges between develop-gate.yml and push-build.yml" >&2
  echo "       (-) is develop-gate, (+) is push-build:" >&2
  sed 's/^/       /' /tmp/no-match-test.diff >&2
  rc=1
fi

if ! diff -u <(seed "$GATE") <(seed "$PUSH") > /tmp/skip-seed.diff 2>&1; then
  echo "ERROR: --fuzz-seed diverges between develop-gate.yml and push-build.yml" >&2
  sed 's/^/       /' /tmp/skip-seed.diff >&2
  rc=1
fi

# A guard that passes when it found nothing to compare is not a guard. The gate has three
# entries and one seed today; require BOTH sides to be non-empty so an accidental YAML
# restructure that hides the ledger from the extractor reddens instead of silently agreeing.
n_gate="$(skips "$GATE" | grep -c .)" || true
n_push="$(skips "$PUSH" | grep -c .)" || true
if [ "$n_gate" -eq 0 ] || [ "$n_push" -eq 0 ]; then
  echo "ERROR: extracted 0 --skip patterns (gate=$n_gate push=$n_push) -- the extractor no" >&2
  echo "       longer sees the ledger. Vacuously-equal is NOT parity." >&2
  rc=1
fi
if [ -z "$(seed "$GATE")" ] || [ -z "$(seed "$PUSH")" ]; then
  echo "ERROR: extracted no --fuzz-seed from one or both workflows" >&2
  rc=1
fi

n_no_match="$(no_match_test "$GATE" | grep -c .)" || true
if [ "$rc" -eq 0 ]; then
  echo "skip-ledger parity OK: $n_gate patterns, $n_no_match no-match-test, seed $(seed "$GATE" | tr -d ' ' | sed 's/fuzz-seed//')"
fi
exit "$rc"
