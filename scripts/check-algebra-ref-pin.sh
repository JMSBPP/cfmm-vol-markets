#!/usr/bin/env bash
#
# check-algebra-ref-pin.sh -- red-on-divergence guard for the Algebra reference closure.
#
# WHY THIS EXISTS
# ---------------
# The Algebra VolatilityOracle is the reference of record for the whole differential
# exercise -- every "bit-exact vs Algebra" claim is measured against it. It lives in
# node_modules, which is untracked (.gitignore:2) and silently rewritten by `npm ci`.
# It was ALREADY corrupted once by an editor auto-fill (tickCumulative -> tickC umulative).
# If the baseline can move, the comparison means nothing.
#
# WHAT IS PINNED, AND WHY node_modules RATHER THAN A VENDORED COPY
# ----------------------------------------------------------------
# remappings.txt has NO cryptoalgebra entry; resolution comes solely from foundry.toml:18
#   "@cryptoalgebra/volatility-oracle-plugin/=node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts"
# So node_modules holds the bytes actually compiled. Pinning a vendored copy under lib/
# would guard bytes nothing links while the suite kept compiling against node_modules --
# pin theatre. Checksumming the linked path makes pinned bytes == linked bytes by
# construction.
#
# The pin covers the WHOLE 4-file import closure the harness links, not just
# VolatilityOracle.sol. Pinning one file of a closure is false assurance.
#
# THREE INDEPENDENT CHECKS (all run; failures accumulate)
#   1. Content pin      -- sha256sum -c over the 4 closure files.
#   2. Closure drift    -- a pinned file may not gain a relative import that resolves
#                          outside the manifest, or "+ transitive imports" is a claim
#                          rather than a fact.
#   3. Package identity -- package-lock.json still declares the pinned version+integrity,
#                          catching a version bump that legitimately rewrites all 4 files.
#
# Checks are NOT short-circuited: check 1 failing must not hide check 2's verdict,
# otherwise the drift guard can never be observed firing and is untrustworthy.
#
# Exit 0 = pin intact. Non-zero = the differential baseline moved; every downstream
# exactness claim is void until it is restored (`npm ci`) or deliberately re-pinned.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="$REPO_ROOT/node_modules/@cryptoalgebra/volatility-oracle-plugin/contracts"
MANIFEST="$REPO_ROOT/test/refs/algebra-volatility-oracle.sha256"
LOCKFILE="$REPO_ROOT/package-lock.json"

PKG_VERSION="2.2.0"
PKG_INTEGRITY="sha512-BLFit/U2jiHyurFJ4DmJhBNJK1AlWlrXyncKEnx0FgEWp0Ixonb7IVTD0WRQNZ1vV5gUcvdBMO57H0a+nw1hBQ=="

# The pinned closure, paths relative to the package `contracts/` dir.
PINNED=(
  "VolatilityOraclePluginImplementation.sol"
  "libraries/VolatilityOracle.sol"
  "libraries/VolatilityOracleStorage.sol"
  "interfaces/IVolatilityOraclePluginImplementation.sol"
)

rc=0
fail() { echo "$@" >&2; rc=1; }

# --- Check 0: everything the pin refers to must EXIST ------------------------
# An absent/empty node_modules must be RED, not a silent pass. sha256sum -c would
# error anyway, but state it explicitly so the check cannot degrade to green.
if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: manifest missing: $MANIFEST" >&2
  exit 1
fi
if [[ ! -d "$REF" ]]; then
  echo "ERROR: Algebra reference package ABSENT: $REF" >&2
  echo "Run 'npm ci' to install the differential baseline." >&2
  exit 1
fi
for f in "${PINNED[@]}"; do
  if [[ ! -f "$REF/$f" ]]; then
    fail "ERROR: pinned Algebra reference file MISSING: $f"
  fi
done
if (( rc != 0 )); then
  echo "The differential baseline is incomplete. Run 'npm ci' to restore." >&2
  exit 1
fi

# --- Check 1: content pin ----------------------------------------------------
if ! ( cd "$REF" && sha256sum -c "$MANIFEST" ) ; then
  fail "ERROR: Algebra reference DIVERGED from the pin (test/refs/algebra-volatility-oracle.sha256)."
  fail "The differential baseline moved. Run 'npm ci' to restore, or re-pin deliberately if the bump is intended."
fi

# --- Check 2: closure-drift guard -------------------------------------------
# Every relative import of every pinned file must resolve to a pinned path. A new
# import pointing outside the manifest means the closure GREW and the pin no longer
# covers what the harness links.
is_pinned() {
  local target="$1"
  for p in "${PINNED[@]}"; do
    [[ "$p" == "$target" ]] && return 0
  done
  return 1
}

for f in "${PINNED[@]}"; do
  fdir="$(dirname "$f")"
  while IFS= read -r imp; do
    [[ -z "$imp" ]] && continue
    # Extract the quoted ./-relative path from the import statement.
    rel="$(printf '%s' "$imp" | sed -E "s/.*['\"](\.\/[^'\"]*)['\"].*/\1/")"
    # Normalize against the importing file's own directory (-m: no existence req).
    target="$(realpath -m --relative-to="$REF" "$REF/$fdir/$rel")"
    if ! is_pinned "$target"; then
      fail "ERROR: Algebra reference closure GREW: $f imports unpinned $target. Add it to the manifest."
    fi
  done < <(grep -oE "^import[^;]*['\"]\./[^'\"]*['\"]" "$REF/$f" || true)
done

# --- Check 3: package identity ----------------------------------------------
# A version bump legitimately rewrites all 4 files; catch it as a distinct signal
# rather than as four confusing hash mismatches.
# The version/integrity are read from the plugin's OWN lockfile block, not grepped over the
# whole file: a bare `"version": "2.2.0"` grep would match any of the ~hundreds of other
# packages and could never fail, which is not a check.
PKG_BLOCK="$(grep -A6 '"node_modules/@cryptoalgebra/volatility-oracle-plugin": {' "$LOCKFILE" || true)"
if [[ -z "$PKG_BLOCK" ]]; then
  fail "ERROR: package-lock.json no longer declares @cryptoalgebra/volatility-oracle-plugin."
else
  if ! printf '%s' "$PKG_BLOCK" | grep -q "\"version\": \"$PKG_VERSION\""; then
    fail "ERROR: package-lock.json no longer declares version $PKG_VERSION for the Algebra plugin."
    fail "The reference package was bumped. Re-pin deliberately if intended."
  fi
  if ! printf '%s' "$PKG_BLOCK" | grep -qF "$PKG_INTEGRITY"; then
    fail "ERROR: package-lock.json integrity for the Algebra plugin CHANGED (expected $PKG_INTEGRITY)."
    fail "The reference package was bumped. Re-pin deliberately if intended."
  fi
fi

if (( rc != 0 )); then
  exit 1
fi

echo "OK: Algebra reference pin intact (4 files, v${PKG_VERSION})"
