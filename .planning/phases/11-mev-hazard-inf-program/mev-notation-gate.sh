#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

# mev-notation-gate.sh — mechanical enforcement of the three MMR<->doc notation
# collisions (11-RESEARCH F2 / PIT-1, PIT-2, PIT-3) on the lambda_MEV addendum,
# plus the structural claims the addendum is not allowed to make.
#
# Usage: mev-notation-gate.sh <markdown-file>
#
# THE ONLY escape hatch is the whitelist marker `<!-- notation-map -->`, which
# tags a line whose SOLE purpose is to say what a foreign symbol MAPS TO.
# Marker-tagged lines are stripped before the glyph rules (1-3) are applied.
# Rule 7 bounds the marker so that tagging further lines cannot weaken the gate.

FILE="${1:-}"
if [ -z "$FILE" ]; then
  echo "usage: $0 <markdown-file>" >&2
  exit 2
fi
if [ ! -f "$FILE" ]; then
  echo "MEV NOTATION GATE: FAIL — no such file: $FILE" >&2
  exit 2
fi

fail() {
  echo "MEV NOTATION GATE: FAIL — $1" >&2
  exit 1
}

# --- the whitelist step (first) -------------------------------------------
STRIPPED="$(mktemp)"; trap 'rm -f "$STRIPPED"' EXIT
grep -v -- '<!-- notation-map -->' "$FILE" > "$STRIPPED" || true

# --- Rule 1 (PIT-1): the pricing-kernel eta, BOTH forms --------------------
if grep -nE 'η|\\eta' "$STRIPPED"; then
  fail "PIT-1: the reserved pricing-kernel eta appears outside the notation-map whitelist"
fi

# --- Rule 2 (PIT-2): a bare block-rate lambda, BOTH forms ------------------
# Every lambda must be subscripted.  The two anchored alternatives are written
# out rather than using ([^_]|$), which is a GNU extension.
if grep -nE 'λ[^_]|λ$|\\lambda[^_]|\\lambda$' "$STRIPPED"; then
  fail "PIT-2: an unsubscripted lambda appears outside the notation-map whitelist"
fi

# --- Rule 3 (PIT-3): the fee-gamma, BOTH forms -----------------------------
# Every gamma must be subscripted, unless the line names the whole parameter
# vector (multiFee argument list / Theta_varphi).
if grep -nE 'γ[^_]|γ$|\\gamma[^_]|\\gamma$' "$STRIPPED" \
   | grep -vE 'multiFee|Theta_\{?\\?varphi|Θ_φ' \
   | grep -q .; then
  grep -nE 'γ[^_]|γ$|\\gamma[^_]|\\gamma$' "$STRIPPED" \
    | grep -vE 'multiFee|Theta_\{?\\?varphi|Θ_φ' >&2 || true
  fail "PIT-3: an unsubscripted gamma appears outside the notation-map whitelist"
fi

# --- Rule 4 (PIT-5): the false affine claim --------------------------------
if grep -nE 'lambda_\{\\text\{(MEV|ARB)\}\}[^=]*=[^=]*pathWeight' "$FILE"; then
  fail "PIT-5: the hazard is presented as a scalar times a path weight (no such decomposition exists)"
fi
if grep -n 'affine' "$FILE" | grep -vE 'no affine|not affine' | grep -q .; then
  grep -n 'affine' "$FILE" | grep -vE 'no affine|not affine' >&2 || true
  fail "PIT-5: 'affine' used on a line that does not deny the affine identification"
fi

# --- Rule 5: required tokens ----------------------------------------------
REQUIRED=(
  'P_{\text{trade}}'
  '\Delta t'
  '\lambda_{\text{ARB}}'
  '\lambda_{\text{sandwich}}'
  '\Theta_{\lambda_{\text{MEV}}}'
  '2305.14604'
  'multiFee'
  'OPEN'
)
for tok in "${REQUIRED[@]}"; do
  grep -qF -- "$tok" "$FILE" || fail "missing required token: $tok"
done

# --- Rule 6: no absolute paths --------------------------------------------
if grep -nE '/home/|\$HOME|~/' "$FILE"; then
  fail "an absolute or home-relative path leaked into the document"
fi

# --- Rule 7: bound the whitelist ------------------------------------------
MARKS="$(grep -c -- '<!-- notation-map -->' "$FILE" || true)"
[ "$MARKS" -ge 1 ] || fail "notation-map marker absent — the header notation sentences must carry it"
[ "$MARKS" -le 12 ] || fail "notation-map marker used $MARKS times (limit 12)"

LAST_MARK="$(grep -n -- '<!-- notation-map -->' "$FILE" | tail -1 | cut -d: -f1)"
M1_LINE="$(grep -n -- '\*\*M1\.' "$FILE" | head -1 | cut -d: -f1)"
[ -n "$M1_LINE" ] || fail "no **M1. block header found — cannot bound the whitelist"
[ "$LAST_MARK" -lt "$M1_LINE" ] \
  || fail "notation-map marker used outside the header/M0 whitelist (line $LAST_MARK >= M1 at line $M1_LINE)"

echo "MEV NOTATION GATE: PASS"
