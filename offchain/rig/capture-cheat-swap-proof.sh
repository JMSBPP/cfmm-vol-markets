#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# capture-cheat-swap-proof.sh -- execute the cheat-swap sequence against the
# LIVE rig and record the result in offchain/rig/cheat-swap-proof.json.
#
# WHY THIS FILE EXISTS
# --------------------
# Phase 22's highest-severity finding is that PriceSetterHook is bound to a pool
# on a SECOND PoolManager while DynamicFeeHook is on a different one, so cheating
# slot0 on one and swapping the other records the un-cheated tick -- silently.
# The composition fix in CheatSwap.Types was rated MEDIUM confidence precisely
# because every one of its components was verified in isolation and NOTHING had
# been executed end to end. This script is that end-to-end execution.
#
# The gate is a VALUE, not a green build:
#   jq -r '.measurements[] | select(.name=="cheat_to_5000_then_swap") | .e3.tick'
# must print exactly 5000. Tick 5000 cannot be produced by swap impact (1e6 wei
# of exact input against L = 1e21) and cannot be the un-cheated state (the pool
# initialised at tick 0), so observing it has exactly one possible cause.
#
# WHY THE ARTIFACT IS COMMITTED
# -----------------------------
# So `cabal test` can assert over real chain evidence while STAYING
# chain-independent -- a property this workstream measures rather than assumes.
# This script is the one place that needs the chain.
#
# USAGE
#   bash offchain/rig/deploy-rig.sh          # stands the rig up, leaves anvil running
#   bash offchain/rig/capture-cheat-swap-proof.sh
#
# NOTE: this MUTATES the chain. It sends real swaps and advances the clock. It is
# not idempotent against a fixed chain state, and it must not be run against a
# rig whose state another measurement depends on.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

MANIFEST="${RIG_MANIFEST:-offchain/rig/rig-manifest.json}"
IMPORT_REF=offchain/rig/import-ref.txt
OUT=offchain/rig/cheat-swap-proof.json
RPC=http://127.0.0.1:8545

# --- Preconditions: fail loudly, never default -----------------------------
if [ ! -f "$MANIFEST" ]; then
  echo "CAPTURE FAIL: no manifest at $(realpath -m "$MANIFEST")" >&2
  echo "              stand the rig up first: bash offchain/rig/deploy-rig.sh" >&2
  exit 1
fi
if [ ! -f "$IMPORT_REF" ]; then
  echo "CAPTURE FAIL: no $IMPORT_REF -- generatedFrom cannot be recorded, and a" >&2
  echo "              capture without it is the exact Phase-21 F4 gap this artifact closes" >&2
  exit 1
fi
for key in PoolManager PriceSetterPoolManager DynamicFeeHook PriceSetterHook PoolSwapTest; do
  value=$(jq -r --arg k "$key" '.contracts[$k] // ""' "$MANIFEST")
  if [ -z "$value" ]; then
    echo "CAPTURE FAIL: $(realpath -m "$MANIFEST") has no contracts.$key" >&2
    echo "              the InitSwappableRig step did not run, so the pool has NO liquidity" >&2
    echo "              and no unlock-callback router. Re-run: bash offchain/rig/deploy-rig.sh" >&2
    exit 1
  fi
done
if ! cast block-number --rpc-url "$RPC" >/dev/null 2>&1; then
  echo "CAPTURE FAIL: nothing answered eth_blockNumber at $RPC" >&2
  echo "              stand the rig up first: bash offchain/rig/deploy-rig.sh" >&2
  exit 1
fi

# --- The capture itself ----------------------------------------------------
cabal run -v0 cheat-swap-proof

# Stable, sorted formatting so two runs differ only where the CHAIN differs and
# never because of key ordering.
jq -S . "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"

# --- Self-check 1: THE GATE ------------------------------------------------
# Asserted here as well as in cabal test, because a capture that silently wrote
# the wrong tick is worse than no capture: it would be committed and believed.
A_TICK=$(jq -r '.measurements[] | select(.name=="cheat_to_5000_then_swap") | .e3.tick' "$OUT")
A_STATUS=$(jq -r '.measurements[] | select(.name=="cheat_to_5000_then_swap") | .status' "$OUT")
if [ "$A_TICK" != "5000" ]; then
  echo "CAPTURE FAIL: the cheated tick did NOT reach E3." >&2
  echo "              e3.tick = $A_TICK, expected 5000 (status $A_STATUS)." >&2
  echo "              The slot0 composition does not work end to end. This is a FINDING," >&2
  echo "              not a threshold to adjust: report it and do NOT build a driver loop." >&2
  exit 1
fi

# --- Self-check 2: the counter-measurement really was silent ---------------
# If the wrong-pool write DID land, the blocker analysis is wrong and that is the
# single most important finding of the phase. It must stop the run, not pass.
B_TICK=$(jq -r '.measurements[] | select(.name=="cheat_wrong_pool_then_swap") | .e3.tick' "$OUT")
B_STATUS=$(jq -r '.measurements[] | select(.name=="cheat_wrong_pool_then_swap") | .status' "$OUT")
if [ "$B_TICK" = "7000" ]; then
  echo "CAPTURE FAIL: cheating PriceSetterPoolManager DID move the hook's recorded tick" >&2
  echo "              (e3.tick = 7000, status $B_STATUS). The two-PoolManager blocker as" >&2
  echo "              described is WRONG. Stop and report -- do not proceed." >&2
  exit 1
fi

# --- Self-check 3: the composition preserved the fee bits ------------------
# Compared as decimal STRINGS. The words run to 256 bits and jq's numbers are
# doubles; a rounded word still looks like a word.
while read -r nm before after; do
  if [ "$before" != "$after" ]; then
    echo "CAPTURE FAIL: $nm did not preserve slot0 bits >= 184" >&2
    echo "              word_before high bits : $before" >&2
    echo "              word_written high bits: $after" >&2
    echo "              compose_slot0 masks at 184 so protocolFee/lpFee survive BY" >&2
    echo "              CONSTRUCTION (G5b). If these differ, the mask moved." >&2
    exit 1
  fi
done < <(jq -r '.measurements[] | "\(.name) \(.word_before_high184) \(.word_written_high184)"' "$OUT")

# --- Self-check 4: generatedFrom really is the imported ref ----------------
REF_IN_FILE=$(jq -r '.generatedFrom' "$OUT")
REF_ON_DISK=$(cat "$IMPORT_REF")
if [ "$REF_IN_FILE" != "$REF_ON_DISK" ]; then
  echo "CAPTURE FAIL: generatedFrom is $REF_IN_FILE but $IMPORT_REF says $REF_ON_DISK" >&2
  exit 1
fi

# --- Self-check 5: blockNumber must NOT be a provenance field --------------
# 21-02 measured three from-scratch deploys landing at heights 9, 11 and 10.
if [ "$(jq -r 'has("blockNumber")' "$OUT")" != "false" ]; then
  echo "CAPTURE FAIL: the artifact records a blockNumber. Three from-scratch deploys" >&2
  echo "              were measured at heights 9, 11 and 10, so it reddens after any redeploy." >&2
  exit 1
fi

echo "wrote $OUT  ($(jq -r '.measurements | length' "$OUT") measurements, chainId $(jq -r '.chainId' "$OUT"), ref $REF_ON_DISK)"
echo "  GATE: cheat_to_5000_then_swap e3.tick = $A_TICK (status $A_STATUS)"
echo "  COUNTER: cheat_wrong_pool_then_swap e3.tick = $B_TICK (status $B_STATUS) -- cheated 7000"
