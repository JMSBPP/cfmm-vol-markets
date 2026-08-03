#!/usr/bin/env bash
# Phase 20 BLOCKING upstream gate.
# Exit 0 = the plank->develop merge carrying the V2 rig artifacts HAS landed; the 40-char
#          origin/develop sha is written to offchain/rig/import-ref.txt and echoed.
# Exit 2 = BLOCKED. PR #15 (feat/plank -> develop) has not merged. Nothing in Phase 20 is
#          executable. This is cross-track coordination (issue #13 / peer ul2inqpl), never a
#          local problem to work around.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

command -v jq >/dev/null || { echo "FATAL: jq not on PATH" >&2; exit 1; }

# The two selectors this gate compares against are NOT typed here. They are read from the
# committed, generated pin file, whose every value was computed by `cast` from a signature string
# parsed out of an interface file (offchain/rig/generate-pins.sh). A hand-copied selector in this
# script would be exactly the failure this milestone exists to remove: it would keep passing after
# the pins moved, because a stale hex constant cannot announce that it went stale. It also keeps
# offchain/**/*.sh free of hex literals, which is plan 20-05's SC-3 purge scope.
#
# RIG_PINS IS HONOURED HERE. It is advertised in README.md:274 ("RIG_PINS / RIG_MANIFEST
# override the default paths") with no exception, and honoured by Rig/Manifest.hs:193 --
# and it was DEAD in this file, the BLOCKING upstream gate. MEASURED: with
# `.selectors.create_order` deleted from a copy,
#   RIG_PINS=<copy> bash offchain/rig/check-upstream.sh
# printed "OPEN: ... (0x98d950ec present)" and exited 0, having read the tracked file and
# ignored the override entirely. A gate that cannot be aimed at a doctored pin file cannot
# be falsified at all -- the only remaining way to test it was to damage the tracked
# evidence it guards. This is byte-for-byte the reader/writer asymmetry 90765c1 fixed for
# RIG_MANIFEST.
PINS="${RIG_PINS:-offchain/rig/rig-pins.json}"
[ -f "$PINS" ] || {
  echo "FATAL: missing $(realpath -m "$PINS") -- run offchain/rig/generate-pins.sh" >&2
  if [ -n "${RIG_PINS:-}" ]; then
    echo "       RIG_PINS is set to '$RIG_PINS'; unset it to use the default path." >&2
  fi
  exit 1
}
if [ -n "${RIG_PINS:-}" ]; then
  echo "note: RIG_PINS is set -- this gate reads its selectors from $(realpath -m "$PINS")"
fi

V2_SELECTOR="$(jq -r '.selectors.create_order.selector' "$PINS")"
V1_SELECTOR="$(jq -r '.retired.create_order_v1' "$PINS")"
# The shape is pinned to EXACTLY 0x + 8 hex digits, not to the `0x*` prefix it used to be.
# A degeneracy does not have to be the empty string to degenerate: `0x` alone satisfied `0x*`
# and would then have been handed to the `grep -q` below, where it matches every hex line in
# the interface file and the discriminator reports OPEN unconditionally. An unset/empty value
# arrives here as jq's "null" and a truncated one as a short prefix; all three must be a loud
# FATAL, and the check must name which of the two selectors was wrong.
for pair in "V2:$V2_SELECTOR" "V1:$V1_SELECTOR"; do
  which_one="${pair%%:*}"; v="${pair#*:}"
  case "$v" in
    0x[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
    *) echo "FATAL: $(realpath -m "$PINS") did not yield a well-formed $which_one create_order" >&2
       echo "       selector: got '$v', expected 0x followed by exactly 8 lowercase hex digits." >&2
       echo "       Regenerate the pin file: bash offchain/rig/generate-pins.sh" >&2
       exit 1 ;;
  esac
done
if [ "$V2_SELECTOR" = "$V1_SELECTOR" ]; then
  echo "FATAL: the live and the retired create_order selectors are the SAME value" >&2
  echo "       ($V2_SELECTOR). The V1-vs-V2 discriminator below cannot discriminate:" >&2
  echo "       every file carrying one carries the other, so the gate would report OPEN" >&2
  echo "       against the stale v1 interface. This is a pin-file finding, not a threshold." >&2
  exit 1
fi

git fetch origin --quiet
DEV=$(git rev-parse origin/develop)

REQUIRED_PATHS=(
  foundry-scripts/deploy/PlankDeployBase.s.sol
  foundry-scripts/deploy/DeployVolOrderManagerMod.s.sol
  foundry-scripts/deploy/DeployRealizedVolatilityMod.s.sol
  foundry-scripts/deploy/DeployDynamicFeeMod.s.sol
  foundry-scripts/deploy/DeployDynamicFeeHook.s.sol
  foundry-scripts/deploy/InitSwappableRig.s.sol
  notes/DATA_CONTRACT.md
  notes/UNITS_AND_SCALES.md
  .planning/rpc-api-volorder-v2-HANDOFF.md
  src/interfaces/premium/DynamicFeeInterface.plk
  src/interfaces/pos_spec/VolOrderManagerInterface.plk
)
missing=0
for p in "${REQUIRED_PATHS[@]}"; do
  git cat-file -e "$DEV:$p" 2>/dev/null || { echo "ABSENT on $DEV: $p"; missing=1; }
done

# The V1-vs-V2 discriminator. A path-existence check alone CANNOT tell a merged V2 interface
# from the stale v1 file (which declares the RETIRED $V1_SELECTOR and has no event block).
if ! git show "$DEV:src/interfaces/pos_spec/VolOrderManagerInterface.plk" 2>/dev/null \
     | grep -q "$V2_SELECTOR"; then
  echo "STALE/ABSENT: VolOrderManagerInterface.plk on $DEV lacks the V2 create_order selector"
  echo "  expected (pinned) : $V2_SELECTOR"
  echo "  the stale v1 file declares the retired $V1_SELECTOR instead"
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  echo "BLOCKED: PR #15 (feat/plank -> develop) has NOT merged."
  echo "  origin/develop = $DEV"
  echo "  Phase 20 imports its artifacts FROM origin/develop (20-CONTEXT.md, locked decision)."
  echo "  Coordination: GitHub issue #13 / claude-peers agent ul2inqpl (plank development)."
  echo "  Do NOT import from origin/feat/plank as a workaround - the recorded develop ref IS"
  echo "  the SC-1 acceptance target."
  exit 2
fi

# import-ref.txt is the ONE external anchor every other rig component reads (generate-pins.sh,
# deploy-rig.sh, capture-cheat-swap-proof.sh, verify-import.sh) and it is TRACKED. Its shape is
# asserted before it is written, and it is written beside-then-renamed, for the same reason
# generate-pins.sh:411-423 does: the readers have no way to tell an empty anchor from a valid
# one -- capture-cheat-swap-proof.sh's self-check 4 compares generatedFrom to this file and an
# empty file makes that comparison "" == "", which PASSES (measured).
case "$DEV" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
  *) echo "FATAL: origin/develop resolved to '$DEV', not a 40-digit lowercase sha." >&2
     echo "       Refusing to record it: every reader of import-ref.txt would inherit it." >&2
     exit 1 ;;
esac
printf '%s\n' "$DEV" > offchain/rig/import-ref.txt.tmp
mv offchain/rig/import-ref.txt.tmp offchain/rig/import-ref.txt
echo "OPEN: origin/develop = $DEV carries the V2 rig artifacts ($V2_SELECTOR present)."
echo "recorded -> offchain/rig/import-ref.txt"
