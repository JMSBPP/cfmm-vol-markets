#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

# phi-notation-gate.sh — the notation gate for the `φ` convention (2026-08-03).
#
# Usage: phi-notation-gate.sh <markdown-file>
#
# SUPERSEDES `.planning/phases/12-eta-tradeoff-optimum/eta-notation-gate.sh`,
# which encodes the 2026-07-31 decision and is now SELF-CONTRADICTORY: its
# Rule 2 demands `\chi` as the mapping target for Capponi's curvature while its
# Rule 4c forbids `\chi` outright.  Both rules describe a naming scheme the
# 2026-08-03 rename replaced.  The old script is left in place unmodified as the
# Phase-12 record; it must not be run against the live document.
#
# THE 2026-08-03 BINDING SCHEME (user decisions, in order):
#   \chi_{X/M}        SHARE / distribution parameter        ("Not \xi BUT \chi")
#   \epsilon_{X/M}    SUBSTITUTION parameter                 (was \rho)
#   \bar\epsilon_{X/M}  elasticity of substitution           (was \sigma_{ES})
#   \kappa_{\varphi}  the GENUINE curvature (1-eps)/(2-eps)  (reassigned)
#   \varsigma_{X/M}   SHARE ASYMMETRY — proven NOT a curvature (was \kappa_\varphi)
#   \epsilon reserved for ELASTICITIES, ALWAYS subscripted
#   \sigma   reserved for VOLATILITIES and VARIANCES, never an elasticity
#   \xi      the GDF ratio — NEVER X/M-subscripted (that role went to \chi)
#
# The ONLY escape hatch is `<!-- notation-map -->`, tagging a line whose SOLE
# purpose is to say what a foreign symbol MAPS TO.  Tagged lines are stripped
# before the glyph rules run.  Rule N bounds the marker so that tagging further
# lines cannot weaken the gate.
#
# Every pattern is plain POSIX ERE.

FILE="${1:-}"
if [ -z "$FILE" ]; then
  echo "usage: $0 <markdown-file>" >&2
  exit 2
fi
if [ ! -f "$FILE" ]; then
  echo "PHI NOTATION GATE: FAIL — no such file: $FILE" >&2
  exit 2
fi

fail() {
  echo "PHI NOTATION GATE: FAIL — $1" >&2
  exit 1
}

WARNED=0
STRIPPED="$(mktemp)"; trap 'rm -f "$STRIPPED"' EXIT
grep -v -- '<!-- notation-map -->' "$FILE" > "$STRIPPED" || true

# --- Rule 1: REQUIRE the protected pricing-kernel eta ---------------------
# Carried over from the Phase-12 gate: eta is the protected symbol, and its
# absence means this is not the document this gate is for.
if ! grep -qE 'η|\\eta' "$STRIPPED"; then
  fail "Rule 1: the protected pricing-kernel eta is absent — wrong document"
fi

# --- Rule 2: FORBID \rho — renamed to \epsilon_{X/M} on 2026-08-03 --------
# The substitution parameter carried \rho through the CES/curvature bundles.
# The rename moved it onto the epsilon family; a surviving \rho is a regression.
if grep -nE 'ρ|\\rho' "$STRIPPED"; then
  fail "Rule 2: rho appears — the substitution parameter is \\epsilon_{X/M} (2026-08-03)"
fi

# --- Rule 3: \sigma_{ES} is RETIRED --------------------------------------
# The elasticity of substitution moved off sigma entirely: sigma is reserved for
# volatilities and variances and is never an elasticity.
if grep -nE '\\sigma_\{ES\}|σ_\{ES\}|\\sigma_ES' "$STRIPPED"; then
  fail "Rule 3: sigma_{ES} appears — the elasticity of substitution is \\bar\\epsilon_{X/M}"
fi

# --- Rule 4: EVERY epsilon must be SUBSCRIPTED ----------------------------
# Binding rule (2026-08-03): epsilon is reserved for ELASTICITIES and is always
# subscripted to differentiate.  Strip every admissible subscripted form, then
# any epsilon that survives is bare and forbidden.  Admissible forms are
# \epsilon_{...} and \bar\epsilon_{...} with any subscript body.
EPS_HITS="$(sed -e 's/\\bar *\\epsilon_{[^}]*}//g' \
                -e 's/\\epsilon_{[^}]*}//g' \
                -e 's/ε_{[^}]*}//g' "$STRIPPED" \
  | grep -nE 'ε|\\epsilon' || true)"
if [ -n "$EPS_HITS" ]; then
  echo "$EPS_HITS" >&2
  fail "Rule 4: a BARE epsilon appears — epsilon is reserved for elasticities and must always be subscripted"
fi

# --- Rule 5: EVERY chi must be X/M-subscripted ----------------------------
# \chi is the SHARE parameter and carries the X/M subscript.  A bare \chi is
# the pre-rename curvature glyph and must not reappear.
CHI_HITS="$(sed -e 's/\\chi_{X\/M}//g' -e 's/χ_{X\/M}//g' "$STRIPPED" \
  | grep -nE 'χ|\\chi' || true)"
if [ -n "$CHI_HITS" ]; then
  echo "$CHI_HITS" >&2
  fail "Rule 5: a chi appears that is not \\chi_{X/M} — chi is the SHARE parameter"
fi

# --- Rule 6: varsigma outside \varsigma_{X/M} — WARN, NOT FAIL ------------
# Same reasoning as Rule 7: sigma-family glyphs occur inside prose and inside
# quoted anchor material where a rename is not appropriate.
# \varsigma_{X/M} is the SHARE-ASYMMETRY index — proven NOT a curvature
# (`CurvatureTwo.curvOfTilde_not_curvature`).  Admissible: \varsigma_{X/M} plus
# the ,S / ,I branch variants and a \star superscript.
VARSIGMA_HITS="$(sed -e 's/\\varsigma_{X\/M[^}]*}//g' -e 's/ς_{X\/M[^}]*}//g' "$STRIPPED" \
  | grep -nE 'ς|\\varsigma' || true)"
if [ -n "$VARSIGMA_HITS" ]; then
  echo "PHI NOTATION GATE: WARN — Rule 6: varsigma outside \\varsigma_{X/M}[,S|,I]:" >&2
  echo "$VARSIGMA_HITS" >&2
  WARNED=1
fi

# --- Rule 7: kappa outside \kappa_{\varphi} — WARN, NOT FAIL --------------
# DELIBERATELY a warning.  The Phase-12 gate made this a hard FAIL, which is
# wrong for this document: it carries at least THREE distinct legitimate kappas
# beyond the curvature — the econometric decay rate from the CLOSED upsilon
# phase, a scalarization multiplier in M6a, and Capponi's OWN kappa quoted
# inside the E1 block that REFUTES his family.  A blanket ban would force those
# to be renamed or whitelisted, neither of which is correct.  The warning still
# surfaces every site so a regression is visible.
# NOTE the referent CHANGED: \kappa_{\varphi} is now the GENUINE curvature
# (1-eps)/(2-eps), not the share asymmetry it used to name.
KAPPA_HITS="$(sed -e 's/\\kappa_{\\varphi[^}]*}//g' -e 's/κ_{\\varphi[^}]*}//g' -e 's/κ_φ//g' "$STRIPPED" \
  | grep -nE 'κ|\\kappa' || true)"
if [ -n "$KAPPA_HITS" ]; then
  echo "PHI NOTATION GATE: WARN — Rule 7: kappa outside \\kappa_{\\varphi}:" >&2
  echo "$KAPPA_HITS" >&2
  WARNED=1
fi

# --- Rule 8: \xi must NEVER be X/M-subscripted ---------------------------
# \xi is the GDF ratio (incl. \xi^{\star}).  The user's first proposal for the
# share parameter was \xi_{X/M}; it was REJECTED for colliding with the GDF
# ratio, and \chi was chosen instead.  This rule prevents the rejected form
# from creeping back.
if grep -nE '\\xi_\{X/M\}|ξ_\{X/M\}' "$STRIPPED"; then
  fail "Rule 8: \\xi_{X/M} appears — REJECTED (collides with the GDF ratio); the share parameter is \\chi_{X/M}"
fi

# --- Rule 9: Angstrom's k is EXEMPT, Capponi's is not --------------------
# The Phase-12 gate flagged every bare `k` as Capponi's curvature, which
# false-positives on the Angstrom auction tax factor k/(k+1) in M7.  Capponi's
# curvature is identifiable by CONTEXT, not by the glyph: it appears as a
# subscript on F.  Flag only that form.
FCAP_HITS="$(grep -nE 'F_\{?k\}?|F_\{\\kappa\}' "$STRIPPED" || true)"
if [ -n "$FCAP_HITS" ]; then
  echo "PHI NOTATION GATE: WARN — Rule 9: Capponi's F_k appears (deliberate in the E1 refutation block; a regression anywhere else):" >&2
  echo "$FCAP_HITS" >&2
  WARNED=1
fi

# --- Rule 10: probabilities carry an EVENT subscript ---------------------
# Binding convention: \mathbb{P}_{\Delta_{ARB}}, \mathbb{P}_{L_{JIT}}, ...
PROB_HITS="$(sed -e 's/\\mathbb{P}_{[^}]*}//g' -e 's/\\mathbb{P}_{[^{]*{[^}]*}[^}]*}//g' "$STRIPPED" \
  | grep -nE '\\mathbb\{P\}' || true)"
if [ -n "$PROB_HITS" ]; then
  echo "$PROB_HITS" >&2
  fail "Rule 10: an unsubscripted \\mathbb{P} appears — probabilities carry an EVENT subscript"
fi

# --- Rule 11: bound the whitelist marker ---------------------------------
# Tagging further lines must not be able to weaken the gate.  The marker is
# admissible only on lines that are genuinely notation maps.
MARKER_COUNT="$(grep -c -- '<!-- notation-map -->' "$FILE" || true)"
if [ "$MARKER_COUNT" -gt 40 ]; then
  fail "Rule 11: $MARKER_COUNT notation-map markers — the whitelist is being used to silence the gate"
fi

if [ "$WARNED" -eq 1 ]; then
  echo "PHI NOTATION GATE: PASS WITH WARNINGS ($MARKER_COUNT notation-map lines whitelisted)"
else
  echo "PHI NOTATION GATE: PASS ($MARKER_COUNT notation-map lines whitelisted)"
fi
