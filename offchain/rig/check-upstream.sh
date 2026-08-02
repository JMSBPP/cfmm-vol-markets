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
PINS="offchain/rig/rig-pins.json"
[ -f "$PINS" ] || { echo "FATAL: missing $PINS -- run offchain/rig/generate-pins.sh" >&2; exit 1; }

V2_SELECTOR="$(jq -r '.selectors.create_order.selector' "$PINS")"
V1_SELECTOR="$(jq -r '.retired.create_order_v1' "$PINS")"
for v in "$V2_SELECTOR" "$V1_SELECTOR"; do
  case "$v" in
    0x*) ;;
    *) echo "FATAL: $PINS did not yield a create_order selector pair (got '$v')" >&2; exit 1 ;;
  esac
done

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

printf '%s\n' "$DEV" > offchain/rig/import-ref.txt
echo "OPEN: origin/develop = $DEV carries the V2 rig artifacts ($V2_SELECTOR present)."
echo "recorded -> offchain/rig/import-ref.txt"
