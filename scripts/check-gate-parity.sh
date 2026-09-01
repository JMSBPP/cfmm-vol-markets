#!/usr/bin/env bash
# prod.yml and vol-position-gate.yml must measure the SAME forge surface as develop-gate.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
GATE="$ROOT/.github/workflows/develop-gate.yml"
PROD="$ROOT/.github/workflows/prod.yml"
VPOS="$ROOT/.github/workflows/vol-position-gate.yml"

for f in "$GATE" "$PROD" "$VPOS"; do
  [ -f "$f" ] || { echo "ERROR: missing $f" >&2; exit 1; }
done

skips() { grep -v '^[[:space:]]*#' "$1" | grep -oE '"\*[^"]+\*"' | sort -u; }
no_match_test() { grep -v '^[[:space:]]*#' "$1" | grep -oE 'no-match-test[[:space:]]+[A-Za-z0-9_]+' \
                    | tr -s '[:space:]' ' ' | sort -u; }
seed()  { grep -v '^[[:space:]]*#' "$1" | grep -oE 'fuzz-seed[[:space:]]+[0-9]+' \
            | tr -s '[:space:]' ' ' | sort -u; }

rc=0
for b in prod vol-position-gate; do
  bf="$ROOT/.github/workflows/${b}.yml"
  for extractor in skips no_match_test seed; do
    if ! diff -u <($extractor "$GATE") <($extractor "$bf") > /tmp/gate-parity.diff 2>&1; then
      echo "ERROR: $extractor diverges: develop-gate vs $b" >&2
      sed 's/^/       /' /tmp/gate-parity.diff >&2
      rc=1
    fi
  done
done
[ "$rc" -eq 0 ] && echo "gate-parity OK: develop-gate == prod == vol-position-gate (forge surface)"
exit "$rc"
