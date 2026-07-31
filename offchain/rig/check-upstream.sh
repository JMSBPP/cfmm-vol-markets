#!/usr/bin/env bash
# Phase 20 BLOCKING upstream gate.
# Exit 0 = the plank->develop merge carrying the V2 rig artifacts HAS landed; the 40-char
#          origin/develop sha is written to offchain/rig/import-ref.txt and echoed.
# Exit 2 = BLOCKED. PR #15 (feat/plank -> develop) has not merged. Nothing in Phase 20 is
#          executable. This is cross-track coordination (issue #13 / peer ul2inqpl), never a
#          local problem to work around.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

git fetch origin --quiet
DEV=$(git rev-parse origin/develop)

REQUIRED_PATHS=(
  foundry-scripts/deploy/PlankDeployBase.s.sol
  foundry-scripts/deploy/DeployVolOrderManagerMod.s.sol
  foundry-scripts/deploy/DeployRealizedVolatilityMod.s.sol
  foundry-scripts/deploy/DeployDynamicFeeMod.s.sol
  foundry-scripts/deploy/DeployDynamicFeeHook.s.sol
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
# from the stale v1 file (selector 0x6501fe94, no event block).
if ! git show "$DEV:src/interfaces/pos_spec/VolOrderManagerInterface.plk" 2>/dev/null \
     | grep -q '0x98d950ec'; then
  echo "STALE/ABSENT: VolOrderManagerInterface.plk on $DEV lacks the V2 selector 0x98d950ec"
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
echo "OPEN: origin/develop = $DEV carries the V2 rig artifacts (0x98d950ec present)."
echo "recorded -> offchain/rig/import-ref.txt"
