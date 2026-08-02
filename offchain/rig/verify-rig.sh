#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Phase 20 / plan 20-03 -- SC-2.
# Exit 0 means every contract answered a read that an empty address could not.
#
# It reads EVERY probe target from offchain/rig/rig-manifest.json. There is no
# address literal anywhere in this file, so it cannot drift from the rig: if the
# manifest is stale the probes fail, they do not silently probe the wrong chain.
#
# Override the manifest path with RIG_MANIFEST=<path> (used by the falsifiability
# check, which points it at a copy carrying a dead address and must exit nonzero).
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

RPC_ALIAS="local"
MANIFEST="${RIG_MANIFEST:-offchain/rig/rig-manifest.json}"

if [ ! -f "$MANIFEST" ]; then
  echo "SC-2 FAIL: manifest not found at $(realpath -m "$MANIFEST")" >&2
  echo "           bash offchain/rig/deploy-rig.sh writes offchain/rig/rig-manifest.json" >&2
  exit 1
fi

# Every probe target below is read out of offchain/rig/rig-manifest.json with
# jq -r. Nothing in this file is a literal address, so there is no second copy
# of the rig's identity that could go stale.
m() { jq -r "$1" "$MANIFEST"; }
lower() { tr 'A-Z' 'a-z'; }
# `cast` renders large uints as `<int> [<scientific>]`; keep the leading token.
first_token() { awk '{print $1}'; }

# --- Probe 1: bytecode, for EVERY contract in the manifest ------------------
# This is the check that rules out the FFI path's known silent failure -- a
# deploy script that "succeeds" while placing zero-length bytecode on chain.
N=0
for name in $(m '.contracts | keys[]'); do
  addr=$(jq -r --arg n "$name" '.contracts[$n]' "$MANIFEST")
  if ! code=$(cast code "$addr" --rpc-url "$RPC_ALIAS" 2>/dev/null); then
    echo "SC-2 FAIL: cast code failed for $name at $addr (is anvil running?)" >&2
    exit 1
  fi
  if [ "${#code}" -le 2 ]; then
    echo "SC-2 FAIL: $name at $addr has zero-length bytecode" >&2
    exit 1
  fi
  echo "PASS bytecode $name: $addr has $(( (${#code} - 2) / 2 )) bytes of code"
  N=$((N + 1))
done

# --- Probe 2: VolOrderManagerMod answers orderCount() ----------------------
# The call must DECODE. 0 is the expected value on a fresh rig, so the VALUE is
# not asserted -- "0 means live" is fragile on its own, which is exactly why
# probe 1 above pairs with it.
VOM=$(m '.contracts.VolOrderManagerMod')
if ! COUNT=$(cast call "$VOM" "orderCount()(uint256)" --rpc-url "$RPC_ALIAS" 2>/dev/null | first_token); then
  echo "SC-2 FAIL: VolOrderManagerMod at $VOM did not answer orderCount()" >&2
  exit 1
fi
case "$COUNT" in
  ''|*[!0-9]*) echo "SC-2 FAIL: orderCount() did not decode to a uint (got '$COUNT')" >&2; exit 1 ;;
esac
echo "PASS orderCount VolOrderManagerMod: decoded $COUNT"

# --- Probe 3: RealizedVolatilityMod is SEEDED (the sharpest SC-2 check) ----
# Timepoint.plk's OFF_INITIALIZED = 240 makes a seeded timepoint's packed word
# nonzero regardless of the tick, so ZERO here means the seed did not take.
RVM=$(m '.contracts.RealizedVolatilityMod')
if ! IDX=$(cast call "$RVM" "lastIndex()(uint16)" --rpc-url "$RPC_ALIAS" 2>/dev/null | first_token); then
  echo "SC-2 FAIL: RealizedVolatilityMod at $RVM did not answer lastIndex()" >&2
  exit 1
fi
if ! PACKED=$(cast call "$RVM" "getTimepointPacked(uint16)(uint256)" --rpc-url "$RPC_ALIAS" "$IDX" 2>/dev/null | first_token); then
  echo "SC-2 FAIL: RealizedVolatilityMod at $RVM did not answer getTimepointPacked($IDX)" >&2
  exit 1
fi
if [ "$PACKED" = "0" ] || [ -z "$PACKED" ]; then
  echo "SC-2 FAIL: RealizedVolatilityMod packed timepoint at index $IDX is ZERO (seed did not take)" >&2
  exit 1
fi
echo "PASS seeded RealizedVolatilityMod: lastIndex=$IDX getTimepointPacked=$PACKED"

# --- Probe 4: DynamicFeeMod captured TOFU ownership ------------------------
DFM=$(m '.contracts.DynamicFeeMod')
DEPLOYER=$(m '.accounts.deployer' | lower)
if ! OWNER=$(cast call "$DFM" "owner()(address)" --rpc-url "$RPC_ALIAS" 2>/dev/null | first_token | lower); then
  echo "SC-2 FAIL: DynamicFeeMod at $DFM did not answer owner()" >&2
  exit 1
fi
[ "$OWNER" = "$DEPLOYER" ] || {
  echo "SC-2 FAIL: DynamicFeeMod owner()=$OWNER but the manifest deployer is $DEPLOYER" >&2; exit 1; }
echo "PASS owner DynamicFeeMod: owner()=$OWNER == manifest accounts.deployer"

# --- Probe 5: DynamicFeeHook is wired to its pool --------------------------
HOOK=$(m '.contracts.DynamicFeeHook')
WANT_PM=$(m '.contracts.PoolManager' | lower)
WANT_PID=$(m '.pool.poolId' | lower)
if ! GOT_PM=$(cast call "$HOOK" "poolManager()(address)" --rpc-url "$RPC_ALIAS" 2>/dev/null | first_token | lower); then
  echo "SC-2 FAIL: DynamicFeeHook at $HOOK did not answer poolManager()" >&2
  exit 1
fi
[ "$GOT_PM" = "$WANT_PM" ] || {
  echo "SC-2 FAIL: DynamicFeeHook poolManager()=$GOT_PM but the manifest PoolManager is $WANT_PM" >&2; exit 1; }
echo "PASS poolManager DynamicFeeHook: poolManager()=$GOT_PM == manifest contracts.PoolManager"

if ! GOT_PID=$(cast call "$HOOK" "poolId()(bytes32)" --rpc-url "$RPC_ALIAS" 2>/dev/null | first_token | lower); then
  echo "SC-2 FAIL: DynamicFeeHook at $HOOK did not answer poolId()" >&2
  exit 1
fi
[ "$GOT_PID" = "$WANT_PID" ] || {
  echo "SC-2 FAIL: DynamicFeeHook poolId()=$GOT_PID but the manifest pool.poolId is $WANT_PID" >&2; exit 1; }
echo "PASS poolId DynamicFeeHook: poolId()=$GOT_PID == manifest pool.poolId"

# --- Probe 6: both routers point at the SAME PoolManager the hook is bound to ---
# The router analogue of the fault Phase 20 measured on the hook: a router constructed
# against the OTHER live PoolManager (PriceSetterHook.s.sol stands up its own) is live,
# has bytecode, and is useless -- every swap through it would unlock a manager the hook is
# not bound to. Probe 1 cannot see that; only the binding can.
#
# The accessor is `manager`, READ out of the vendored source rather than guessed:
# lib/panoptic-v2-core/lib/v4-core/src/test/PoolTestBase.sol:16
#   IPoolManager public immutable manager;
# and both PoolSwapTest and PoolModifyLiquidityTest extend PoolTestBase.
for router in PoolSwapTest PoolModifyLiquidityTest; do
  RADDR=$(jq -r --arg n "$router" '.contracts[$n]' "$MANIFEST")
  # A jq miss yields the STRING "null", and `cast call null` fails with a message about
  # an address rather than about a manifest. Name the real fault instead.
  if [ "$RADDR" = "null" ] || [ -z "$RADDR" ]; then
    echo "SC-2 FAIL: $MANIFEST has no contracts.$router -- the InitSwappableRig step did not run," >&2
    echo "           so the pool has NO liquidity and no unlock-callback router. Re-run:" >&2
    echo "           bash offchain/rig/deploy-rig.sh" >&2
    exit 1
  fi
  if ! GOT_RPM=$(cast call "$RADDR" "manager()(address)" --rpc-url "$RPC_ALIAS" 2>/dev/null | first_token | lower); then
    echo "SC-2 FAIL: $router at $RADDR did not answer manager()" >&2
    exit 1
  fi
  [ "$GOT_RPM" = "$WANT_PM" ] || {
    echo "SC-2 FAIL: $router manager()=$GOT_RPM but the manifest PoolManager is $WANT_PM" >&2
    echo "           A router bound to the OTHER PoolManager is live and useless." >&2
    exit 1; }
  echo "PASS manager $router: manager()=$GOT_RPM == manifest contracts.PoolManager"
done

echo "SC-2 OK: $N contracts live, RealizedVolatilityMod seeded (packed=$PACKED)"
