#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

# eta-notation-gate.sh — the INVERTED notation gate for the Phase-12 `## ETA`
# curvature-controller section (12-RESEARCH F2 / PIT-E1..PIT-E8).
#
# Usage: eta-notation-gate.sh <markdown-file>
#
# THE INVERSION.  The Phase-11 gate (`mev-notation-gate.sh`) FORBIDS the
# pricing-kernel eta.  Here eta is the PROTECTED symbol and Rule 1 REQUIRES it.
# The Phase-11 script is therefore unusable and is not reused; running THIS
# script on the Phase-11 addendum must fail at Rule 1 (the PIT-E1 canary).
#
# The ONLY escape hatch is the whitelist marker `<!-- notation-map -->`, which
# tags a line whose SOLE purpose is to say what a foreign symbol MAPS TO.
# Marker-tagged lines are stripped before the glyph rules are applied.
# Rule 11 bounds the marker so that tagging further lines cannot weaken the gate.
#
# Every pattern is plain POSIX ERE.  The GNU-only mid-alternation anchor
# ([^_]|$) is NOT used anywhere; the alternatives are written out.

FILE="${1:-}"
if [ -z "$FILE" ]; then
  echo "usage: $0 <markdown-file>" >&2
  exit 2
fi
if [ ! -f "$FILE" ]; then
  echo "ETA NOTATION GATE: FAIL — no such file: $FILE" >&2
  exit 2
fi

fail() {
  echo "ETA NOTATION GATE: FAIL — $1" >&2
  exit 1
}

# --- the whitelist step (first) -------------------------------------------
STRIPPED="$(mktemp)"; trap 'rm -f "$STRIPPED"' EXIT
grep -v -- '<!-- notation-map -->' "$FILE" > "$STRIPPED" || true

# --- Rule 1 (PIT-E1): REQUIRE the protected pricing-kernel eta -------------
# Grepped against the whitelist-STRIPPED text, NOT against "$FILE": the
# Phase-11 MEV addendum DOES carry eta on its notation-map lines, so a "$FILE"
# grep would pass there and void the canary.
if ! grep -qE 'η|\\eta' "$STRIPPED"; then
  fail "INVERTED Rule 1: the protected pricing-kernel eta is absent — this is the ETA section"
fi

# --- Rule 2: FORBID the anchor's curvature k ------------------------------
if grep -nE '\\\(k\\\)|k\^\{\\star\}|k\^\*|k_1|k_2|F_k|k \\in|\\\(k \\\)' "$STRIPPED"; then
  fail "Capponi's k appears unmapped — use \\chi"
fi

# --- Rule 3: FORBID the anchor's alpha / beta unsubscripted ----------------
# The premia are \varrho_I / \varrho_S; the document's own alpha_j, beta_j are
# Theta_phi sigmoid parameters and are ALWAYS subscripted.
if grep -nE 'α[^_]|α$|\\alpha[^_]|\\alpha$|β[^_]|β$|\\beta[^_]|\\beta$' "$STRIPPED"; then
  fail "Capponi's alpha/beta appear unsubscripted — use \\varrho_I / \\varrho_S"
fi

# --- Rule 4: FORBID theta, kappa and tau entirely -------------------------
# theta/kappa are absorbed into the \varpi_* constants (theta collides with the
# document's option theta, kappa with the Phase-11 scalarization weight); tau is
# TAKEN by M9's tau = tau_MEV and the anchor's tau_1/tau_2 are renamed c_1/c_2.
# Capital \Theta (as in \Theta_{\varphi}) is deliberately NOT matched.
if grep -nE 'θ|\\theta|κ|\\kappa|τ|\\tau' "$STRIPPED"; then
  fail "theta/kappa/tau appear outside the notation-map whitelist — absorb into \\varpi_* or use c_1/c_2"
fi

# --- Rule 5: FORBID nu, BOTH forms (TAKEN by M6b) -------------------------
if grep -nE 'ν|\\nu' "$STRIPPED"; then
  fail "nu appears — it is TAKEN by block M6b (nu_t = w_t/D_t)"
fi

# --- Rule 6: PERMIT lambda only in three sanctioned forms -----------------
# (a) immediately followed by `_` (a subscripted hazard) or `^` (the tick base
#     raised to a power);
# (b) on a line carrying the ln-prefixed tick base (E6's \ln\lambda denominator);
# (c) on the single E0 tick-base declaration line matching `λ *= *1.0001`.
# This extension is the SANCTIONED resolution of the gate-vs-displays conflict.
LAM_HITS="$(grep -nE 'λ[^_^]|λ$|\\lambda[^_^]|\\lambda$' "$STRIPPED" \
  | grep -vE '\\ln[[:space:]]*\\?lambda|ln[[:space:]]*λ' \
  | grep -vE 'λ *= *1\.0001' || true)"
if [ -n "$LAM_HITS" ]; then
  echo "$LAM_HITS" >&2
  fail "Rule 6: an unsubscripted lambda that is neither the ln-prefixed nor the declared tick base"
fi
DECL_COUNT="$(grep -cE 'λ *= *1\.0001' "$STRIPPED" || true)"
if [ "$DECL_COUNT" -gt 1 ]; then
  fail "Rule 6: the tick-base declaration line appears $DECL_COUNT times (at most one is sanctioned)"
fi

# --- Rule 7 (PIT-E7): FORBID a first-order condition ----------------------
# chi* is a KINK.  Lines that DENY an FOC are exempt.  `\bFOC\b` is
# case-SENSITIVE and word-bounded so that "focus" does not match.
FOC_EXEMPT='no first-order|not a first-order|kink|jumps|superseded|never claimed|none is claimed'
FOC_HITS="$( { grep -n -iE 'first.order condition|stationary point' "$FILE" || true; \
               grep -n -E '\bFOC\b' "$FILE" || true; } \
             | grep -viE "$FOC_EXEMPT" || true)"
if [ -n "$FOC_HITS" ]; then
  echo "$FOC_HITS" >&2
  fail "PIT-E7: a first-order condition is asserted — chi* is a KINK"
fi

# --- Rule 8: FORBID the CPMM misidentification ----------------------------
CPMM_HITS="$(grep -n -E '\\chi\(1|curvIndex 1 = 1|\\eta = 1.*\\chi = 1|\\chi = 1.*\\eta = 1' "$FILE" \
  | grep -viE 'NOT|≠|never' || true)"
if [ -n "$CPMM_HITS" ]; then
  echo "$CPMM_HITS" >&2
  fail "PIT-E3/F3: eta = 1 is the sqrt-price grid, NOT Capponi's chi = 1"
fi

# --- Rule 9: required tokens ----------------------------------------------
REQUIRED=(
  '2103.08842'
  'Lemma 3'
  'Proposition 5'
  'Proposition 6'
  '\chi'
  '\varrho_I'
  '\varrho_S'
  'priceEta'
  'joint_corner_degeneracy'
  'OPEN'
  '<!-- END ETA -->'
)
for tok in "${REQUIRED[@]}"; do
  grep -qF -- "$tok" "$FILE" || fail "missing required token: $tok"
done
# the varpi requirement accepts EITHER the LaTeX macro OR the Unicode glyph
grep -qF -- '\varpi' "$FILE" || grep -qF -- 'ϖ' "$FILE" \
  || fail "missing required token: the absorbed constants (\\varpi / ϖ)"

# --- Rule 10: no absolute paths -------------------------------------------
if grep -nE '/home/|\$HOME|~/' "$FILE"; then
  fail "an absolute or home-relative path leaked into the document"
fi

# --- Rule 11: bound the whitelist -----------------------------------------
MARKS="$(grep -c -- '<!-- notation-map -->' "$FILE" || true)"
[ "$MARKS" -ge 1 ] || fail "notation-map marker absent — the header notation sentences must carry it"
[ "$MARKS" -le 24 ] || fail "notation-map marker used $MARKS times (limit 24)"

LAST_MARK="$(grep -n -- '<!-- notation-map -->' "$FILE" | tail -1 | cut -d: -f1)"
E1_LINE="$(grep -n -- '\*\*E1\.' "$FILE" | head -1 | cut -d: -f1)"
[ -n "$E1_LINE" ] || fail "no **E1. block header found — cannot bound the whitelist"
[ "$LAST_MARK" -lt "$E1_LINE" ] \
  || fail "notation-map marker used outside the header/E0 whitelist (line $LAST_MARK >= E1 at line $E1_LINE)"

echo "ETA NOTATION GATE: PASS"
