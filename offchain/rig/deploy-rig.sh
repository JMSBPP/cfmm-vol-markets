#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Phase 20 / plan 20-03 -- the ONE command that stands up the full V2 rig.
#
# It owns anvil (kills a stale listener on 8545, starts a fresh chain at a FIXED
# genesis timestamp), runs the six deploy scripts, and writes
# offchain/rig/rig-manifest.json.
#
# Phase 22 / plan 22-03 added the SIXTH script, InitSwappableRig.s.sol: the pool is
# SWAPPABLE on exit -- two routers, one full-range position, and a probe swap this
# script asserts actually wrote a hook timepoint.
#
# Every address in the manifest is taken from foundry's machine-written
# broadcast record (broadcast/<script>/31337/run-latest.json) and then
# INDEPENDENTLY confirmed against the deploy script's own printed console line.
# A disagreement is a hard failure, never a warning. No address, account or seed
# value in this file was typed by hand or derived from nonce arithmetic -- that
# is precisely how offchain/app/Sample.hs's literals went stale.
#
# On success anvil is left RUNNING so the Haskell drivers can use the rig.
# Use `deploy-rig.sh --stop` to tear it down.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

RPC_ALIAS="local"                 # foundry.toml [rpc_endpoints] local = http://127.0.0.1:8545
RPC_PORT=8545
LOG_DIR=/tmp/rig-logs
MANIFEST=offchain/rig/rig-manifest.json

# --- Step 0: constants -----------------------------------------------------
# These are FIXED LITERALS on purpose. SC-5 (two from-scratch runs produce a
# byte-identical manifest) dies the moment any of them is read from the clock.
ANVIL_MNEMONIC="test test test test test test test test test test test junk"
INIT_TS=1700000000    # MUST be nonzero: with INIT_TS=0 DeployRealizedVolatilityMod
                      # prints `seeded : false`, SKIPS initializeTWAP, and STILL exits 0.
INIT_TICK=0           # Safe at 0 for the seed check: Timepoint.plk's OFF_INITIALIZED = 240
                      # makes a seeded timepoint's packed word nonzero regardless of tick.
                      # NOTE: this is the RealizedVolatilityMod ENV VAR. The
                      # `int24 constant INIT_TICK = 0` inside DeployDynamicFeeHook is a
                      # DIFFERENT, non-env-read constant -- exporting this one does not
                      # move the hook's pool. They are not one knob.
CHAIN_ID=31337
IMPORT_REF=$(cat offchain/rig/import-ref.txt)

# --- a pure-bash bounded pause (the poll interval) -------------------------
# Deliberately not the `sleep` binary: this script must contain no fixed wait,
# only bounded polling. `read -t` on a fifo nothing ever writes to is an exact,
# process-free timeout.
PAUSE_FIFO=$(mktemp -u "${TMPDIR:-/tmp}/rig-pause.XXXXXX")
mkfifo "$PAUSE_FIFO"
exec 9<>"$PAUSE_FIFO"
rm -f "$PAUSE_FIFO"
pause() { read -r -t "$1" -u 9 _ || true; }

kill_rpc_listener() {
  # Kill by PORT, never a blanket `pkill anvil`: another peer's worktree may be
  # running its own anvil on a different port.
  if command -v lsof >/dev/null 2>&1; then
    local pids
    pids=$(lsof -ti "tcp:${RPC_PORT}" 2>/dev/null || true)
    [ -n "$pids" ] && kill $pids 2>/dev/null || true
  elif command -v fuser >/dev/null 2>&1; then
    fuser -k "${RPC_PORT}/tcp" >/dev/null 2>&1 || true
  else
    echo "FATAL: neither lsof nor fuser available; cannot own port ${RPC_PORT} safely" >&2
    exit 1
  fi
}

wait_for_port_release() {
  local i
  for i in $(seq 1 50); do
    cast block-number --rpc-url "$RPC_ALIAS" >/dev/null 2>&1 || return 0
    pause 0.2
  done
  echo "FATAL: something is still answering on port ${RPC_PORT} after 10s" >&2
  exit 1
}

if [ "${1:-}" = "--stop" ]; then
  kill_rpc_listener
  wait_for_port_release
  echo "rig stopped: nothing is listening on ${RPC_PORT}"
  exit 0
fi

# --- Step 1: kill any stale anvil, then start a fresh one ------------------
mkdir -p "$LOG_DIR"
kill_rpc_listener
wait_for_port_release

# --timestamp gives the chain the SAME clock origin as the RealizedVolatilityMod seed.
# Without it there are two unrelated clocks: INIT_TS seeds the module-global series at
# 1.7e9 while DeployDynamicFeeHook seeds the HOOK's own buffer at uint32(block.timestamp)
# = wall clock (~1.78e9 in Aug 2026). A driver computing INIT_TS + k*stride would then be
# asking for timestamps ~2.7 YEARS in the past, which anvil rejects outright.
# HONEST LIMIT: --timestamp fixes the ORIGIN, not the RATE. anvil's clock still advances
# with wall time from that anchor (MEASURED on anvil 1.5.1: 13 s of real time -> block
# timestamp 1700000013), and InitSwappableRig below adds a further +5 s of its own. A
# driver must therefore READ THE CHAIN HEAD, never assume the head equals INIT_TS.
nohup anvil --silent --timestamp "$INIT_TS" >"$LOG_DIR/anvil.log" 2>&1 &
ANVIL_PID=$!
# Keep-alive is the DEFAULT -- the rig must survive this script. anvil is killed
# only on a failure path.
trap 'rc=$?; if [ $rc -ne 0 ]; then kill $ANVIL_PID 2>/dev/null || true; fi; exit $rc' EXIT

# --- Step 2: poll until the chain answers (never a fixed wait) -------------
CHAIN_UP=0
for _ in $(seq 1 50); do
  if cast block-number --rpc-url "$RPC_ALIAS" >/dev/null 2>&1; then CHAIN_UP=1; break; fi
  pause 0.2
done
[ "$CHAIN_UP" = "1" ] || { echo "FATAL: anvil did not answer on ${RPC_PORT} within 10s (see $LOG_DIR/anvil.log)" >&2; exit 1; }

# --- Step 3: delete stale broadcast records. NOT OPTIONAL. -----------------
# A script that fails leaves the PREVIOUS run's run-latest.json on disk, and the
# generator below would then emit a stale address. Deleting first turns that
# silent-wrong-address failure into an honest "file not found".
rm -rf broadcast/DeployVolOrderManagerMod.s.sol broadcast/DeployRealizedVolatilityMod.s.sol \
       broadcast/DeployDynamicFeeMod.s.sol broadcast/DeployDynamicFeeHook.s.sol \
       broadcast/PriceSetterHook.s.sol broadcast/InitSwappableRig.s.sol

# --- Step 4: derive the accounts (never hardcoded) -------------------------
# DEPLOYER = anvil index 0 = PlankDeployBase.deployerKey()'s default.
# SENDER   = anvil index 1 = the ORDER SENDER, which is what Sample.hs:21's
#            literal actually was. They are different addresses; both ship.
DEPLOYER=$(cast wallet address --mnemonic "$ANVIL_MNEMONIC" --mnemonic-index 0 | tr 'A-Z' 'a-z')
SENDER=$(cast wallet address --mnemonic "$ANVIL_MNEMONIC" --mnemonic-index 1 | tr 'A-Z' 'a-z')

# --- Step 5: run the deploy scripts ----------------------------------------
# `tee` inside a pipeline hides forge's exit code; `set -o pipefail` (on) plus
# the `if !` wrapper turns that into a loud, log-naming failure.
run_deploy() {
  local log="$1"; shift
  echo "--> $*"
  if ! "$@" 2>&1 | tee "$log"; then
    echo "FATAL: deploy script failed: $*" >&2
    echo "       full output: $log" >&2
    exit 1
  fi
}

# The pool fields are NOT addresses in the broadcast record; poolId in particular exists
# nowhere else, so for these the console IS the primary source and there is nothing
# independent to cross-check poolId against. Defined HERE rather than in Step 7 because
# the 6th deploy script needs CURRENCY0/CURRENCY1 as ENV, i.e. before Step 7 runs.
console_field() {   # $1 = label prefix, $2 = log file
  grep -m1 -- "$1" "$2" | sed 's/.*: *//' | tr -d '\r' | tr 'A-Z' 'a-z'
}

FS=(--rpc-url "$RPC_ALIAS" --broadcast --ffi --via-ir)

run_deploy "$LOG_DIR/01-vom.log" \
  forge script foundry-scripts/deploy/DeployVolOrderManagerMod.s.sol "${FS[@]}"
run_deploy "$LOG_DIR/02-rvm.log" \
  env INIT_TS="$INIT_TS" INIT_TICK="$INIT_TICK" \
  forge script foundry-scripts/deploy/DeployRealizedVolatilityMod.s.sol "${FS[@]}"
run_deploy "$LOG_DIR/03-dfm.log" \
  forge script foundry-scripts/deploy/DeployDynamicFeeMod.s.sol "${FS[@]}"
# DeployDynamicFeeHook.s.sol declares two contracts (DeployDynamicFeeHook,
# MinimalToken) so forge cannot pick a target on its own.
run_deploy "$LOG_DIR/04-hook.log" \
  forge script foundry-scripts/deploy/DeployDynamicFeeHook.s.sol --tc DeployDynamicFeeHook "${FS[@]}"

# --- Step 5a: the four values the 6th script needs as ENV -------------------
# These extractions used to live in Step 7 with the rest. They are MOVED here (not
# duplicated) because InitSwappableRig.s.sol reads POOL_MANAGER/HOOK/TOKEN0/TOKEN1 from
# the environment and every one of them is produced by the 4th script above. Step 7 keeps
# the remaining extractions and Step 8 keeps ALL of the cross-checks.
B_HOOK=broadcast/DeployDynamicFeeHook.s.sol/31337/run-latest.json
[ -f "$B_HOOK" ] || { echo "FATAL: broadcast record missing: $B_HOOK" >&2; exit 1; }

# DeployDynamicFeeHook creates the hook by a raw `.call` to the CREATE2 proxy,
# not `new X{salt:...}`, so the created contract is EXPECTED in
# additionalContracts[]. Try that first, fall back to a top-level CREATE2
# transaction. Whichever branch fires is recorded in RIG-RUN.md.
HOOK=$(jq -r '([.transactions[].additionalContracts[]? | select(.transactionType=="CREATE2") | .address]
               + [.transactions[] | select(.transactionType=="CREATE2") | .contractAddress])[0] // empty' \
       "$B_HOOK" | tr 'A-Z' 'a-z')
if [ -z "$HOOK" ]; then
  echo "FATAL: could not locate the CREATE2 hook in $B_HOOK. Observed transaction shape:" >&2
  jq -r '[.transactions[] | {transactionType, contractName, contractAddress, additionalContracts}]' "$B_HOOK" >&2
  exit 1
fi
HOOK_SHAPE=$(jq -r 'if ([.transactions[].additionalContracts[]? | select(.transactionType=="CREATE2")] | length) > 0
                    then "additionalContracts" else "top-level-CREATE2" end' "$B_HOOK")

PM=$(jq -r '[.transactions[] | select(.contractName=="PoolManager")][0].contractAddress' "$B_HOOK" | tr 'A-Z' 'a-z')

CURRENCY0=$(console_field 'currency0      :' "$LOG_DIR/04-hook.log")
CURRENCY1=$(console_field 'currency1      :' "$LOG_DIR/04-hook.log")

# PriceSetterHook.s.sol's single contract is named PriceSetterHookScript, not
# after its file. It stands up its OWN second PoolManager -- hence the schema's
# distinct PriceSetterPoolManager key. This is plank's file: RUN it, never edit it.
run_deploy "$LOG_DIR/05-psh.log" \
  forge script foundry-scripts/PriceSetterHook.s.sol --tc PriceSetterHookScript "${FS[@]}"

# --- Step 5b: the 6th script -- the pool becomes SWAPPABLE ------------------
# It runs LAST because it consumes the 4th script's outputs, and it takes a DIFFERENT
# flag set: --tc (the file declares one contract but forge still needs the target named
# for --broadcast bookkeeping) and NO --ffi (it is pure Solidity; the other five scripts
# still need --ffi, which is why FS is left alone).
#
# Until this runs, DynamicFeeHook's pool has ZERO liquidity and there is no
# unlock-callback router anywhere on chain, so a swap from an EOA is impossible and the
# hook can never write a timepoint. It deploys the two vendored v4-core routers, funds +
# approves deployer->ROUTERS (never deployer->PoolManager: settlement is
# CurrencySettler.settle -> transferFrom pulled BY the router), mints ONE full-range
# position (G4: do NOT mint additional ranges), and runs a probe swap.
run_deploy "$LOG_DIR/06-swappable.log" \
  env POOL_MANAGER="$PM" HOOK="$HOOK" TOKEN0="$CURRENCY0" TOKEN1="$CURRENCY1" \
  forge script foundry-scripts/deploy/InitSwappableRig.s.sol --tc InitSwappableRig \
    --rpc-url "$RPC_ALIAS" --broadcast --via-ir

# --- Step 5c: the probe swap PROVED the write path -------------------------
# The script's own `require(tsAfter > tsBefore)` already enforces this, but the rig owns
# its acceptance checks: this is the same move Step 6 makes for `seeded : true`. A
# console line the rig never reads is a claim; a console line the rig asserts is a check.
TS_BEFORE=$(console_field 'timepoint ts before   :' "$LOG_DIR/06-swappable.log")
TS_AFTER=$(console_field 'timepoint ts after    :' "$LOG_DIR/06-swappable.log")
case "$TS_BEFORE$TS_AFTER" in
  ''|*[!0-9]*)
    echo "FATAL: timepoint ts before/after not parsed from $LOG_DIR/06-swappable.log" >&2
    echo "       (got before='$TS_BEFORE' after='$TS_AFTER')" >&2
    exit 1 ;;
esac
[ "$TS_AFTER" -gt "$TS_BEFORE" ] || {
  echo "FATAL: probe swap did not advance the hook's timepoint clock ($TS_BEFORE -> $TS_AFTER)." >&2
  echo "       The rig is NOT proven swappable: beforeSwap either did not run or hit the" >&2
  echo "       G1 same-second no-op. E3 is the ground truth of what landed, never the swap count." >&2
  exit 1; }
echo "  probe swap wrote a timepoint: $TS_BEFORE -> $TS_AFTER"

# --- Step 6: assert the seed actually happened -----------------------------
if ! grep -qE 'seeded[[:space:]]*:[[:space:]]*true' "$LOG_DIR/02-rvm.log"; then
  echo "FATAL: RealizedVolatilityMod was NOT seeded (INIT_TS=$INIT_TS did not reach the script)." >&2
  echo "       DeployRealizedVolatilityMod skips initializeTWAP when INIT_TS == 0 and still exits 0," >&2
  echo "       so the later nonzero-timepoint check would fail for a CONFIG reason." >&2
  exit 1
fi

# --- Step 7: extract addresses from the broadcast JSONs (PRIMARY source) ---
# B_HOOK is defined in Step 5a (its addresses are ENV inputs to the 6th script).
B_VOM=broadcast/DeployVolOrderManagerMod.s.sol/31337/run-latest.json
B_RVM=broadcast/DeployRealizedVolatilityMod.s.sol/31337/run-latest.json
B_DFM=broadcast/DeployDynamicFeeMod.s.sol/31337/run-latest.json
B_PSH=broadcast/PriceSetterHook.s.sol/31337/run-latest.json
B_SWAP=broadcast/InitSwappableRig.s.sol/31337/run-latest.json

for f in "$B_VOM" "$B_RVM" "$B_DFM" "$B_HOOK" "$B_PSH" "$B_SWAP"; do
  [ -f "$f" ] || { echo "FATAL: broadcast record missing: $f" >&2; exit 1; }
done

# Plank FFI deploys land as transactionType CREATE with contractName NULL for
# every Plank module -- you cannot key on the name, only on the type.
addr_of() {
  jq -r '[.transactions[] | select(.transactionType=="CREATE")][0].contractAddress' "$1" | tr 'A-Z' 'a-z'
}
VOM=$(addr_of "$B_VOM")
RVM=$(addr_of "$B_RVM")
DFM=$(addr_of "$B_DFM")

# PriceSetterHook.s.sol uses `new X{salt:...}`, which foundry records as a
# top-level CREATE2 WITH a populated contractName -- so key it by name.
PSH=$(jq -r '[.transactions[] | select(.contractName=="PriceSetterHook")][0].contractAddress' "$B_PSH" | tr 'A-Z' 'a-z')
PSPM=$(jq -r '[.transactions[] | select(.contractName=="PoolManager")][0].contractAddress' "$B_PSH" | tr 'A-Z' 'a-z')

# Both routers are plain `new X(...)` under startBroadcast, so foundry records them as
# TOP-LEVEL CREATE with a POPULATED contractName -- the PriceSetterHook pattern, NOT the
# nameless-Plank-CREATE pattern addr_of() handles. Key them by name.
SWAPR=$(jq -r '[.transactions[] | select(.contractName=="PoolSwapTest")][0].contractAddress' "$B_SWAP" | tr 'A-Z' 'a-z')
LIQR=$(jq -r '[.transactions[] | select(.contractName=="PoolModifyLiquidityTest")][0].contractAddress' "$B_SWAP" | tr 'A-Z' 'a-z')

for pair in "VolOrderManagerMod:$VOM" "RealizedVolatilityMod:$RVM" "DynamicFeeMod:$DFM" \
            "DynamicFeeHook:$HOOK" "PoolManager:$PM" "PriceSetterHook:$PSH" "PriceSetterPoolManager:$PSPM" \
            "PoolSwapTest:$SWAPR" "PoolModifyLiquidityTest:$LIQR"; do
  n=${pair%%:*}; v=${pair#*:}
  case "$v" in
    0x????????????????????????????????????????) ;;
    *) echo "FATAL: no address extracted for $n (got '$v')" >&2; exit 1 ;;
  esac
done

# console_field is defined above Step 5 (the 6th script needs it earlier than this).
# CURRENCY0/CURRENCY1 are extracted in Step 5a for the same reason.
POOL_ID=$(console_field 'poolId         :' "$LOG_DIR/04-hook.log")
TICK_SPACING=$(console_field 'tickSpacing    :' "$LOG_DIR/04-hook.log")

case "$POOL_ID" in
  0x????????????????????????????????????????????????????????????????) ;;
  *) echo "FATAL: poolId not parsed from the hook console log (got '$POOL_ID')" >&2; exit 1 ;;
esac
case "$TICK_SPACING" in
  ''|*[!0-9]*) echo "FATAL: tickSpacing not parsed from the hook console log (got '$TICK_SPACING')" >&2; exit 1 ;;
esac

# --- Step 8: cross-check EVERY extracted address against the console --------
# Both sides lowercased UNCONDITIONALLY: broadcast JSON is lowercase while
# console.log renders EIP-55 mixed case, so normalising makes the comparison
# correct under either rendering.
check() {   # $1 = console label prefix, $2 = log file, $3 = address from the broadcast JSON
  local got
  got=$(grep -m1 -- "$1" "$2" | grep -oiE '0x[0-9a-fA-F]{40}' | tr 'A-Z' 'a-z')
  [ -n "$got" ] || { echo "CROSS-CHECK: no address on console line '$1' in $2" >&2; exit 1; }
  [ "$got" = "$3" ] || { echo "MISMATCH $1: console=$got broadcast=$3" >&2; exit 1; }
  echo "  cross-check OK  $1 $3"
}
check 'VolOrderManagerMod :'    "$LOG_DIR/01-vom.log"  "$VOM"
check 'RealizedVolatilityMod :' "$LOG_DIR/02-rvm.log"  "$RVM"
check 'DynamicFeeMod :'         "$LOG_DIR/03-dfm.log"  "$DFM"
check 'DynamicFeeHook :'        "$LOG_DIR/04-hook.log" "$HOOK"
check 'PoolManager    :'        "$LOG_DIR/04-hook.log" "$PM"
check 'PriceSetterHook :'       "$LOG_DIR/05-psh.log"  "$PSH"
check 'PoolManager     :'       "$LOG_DIR/05-psh.log"  "$PSPM"
check 'swapRouter            :' "$LOG_DIR/06-swappable.log" "$SWAPR"
check 'modifyLiquidityRouter :' "$LOG_DIR/06-swappable.log" "$LIQR"

# currency0/currency1 come from the console; when the rig deploys its own
# MinimalTokens they ALSO appear in the broadcast record, so confirm the pair
# as a SET (the script sorts them by address, the broadcast keeps deploy order).
MINTOKENS=$(jq -r '[.transactions[] | select(.contractName=="MinimalToken") | .contractAddress] | sort | join(",")' \
            "$B_HOOK" | tr 'A-Z' 'a-z')
if [ -n "$MINTOKENS" ] && [ "$MINTOKENS" != "" ]; then
  CONSOLE_PAIR=$(printf '%s\n%s\n' "$CURRENCY0" "$CURRENCY1" | sort | paste -sd, -)
  [ "$MINTOKENS" = "$CONSOLE_PAIR" ] || {
    echo "MISMATCH currencies: console={$CONSOLE_PAIR} broadcast={$MINTOKENS}" >&2; exit 1; }
  echo "  cross-check OK  currency0/currency1 (MinimalToken set) $CONSOLE_PAIR"
fi

# --- Step 9: emit the manifest --------------------------------------------
# DECISION: only the two router ADDRESSES from the 6th script enter the manifest. The tick
# range, the liquidity and the probe deltas stay on the console and in
# $LOG_DIR/06-swappable.log -- they are proof the script produced, not values any driver
# reads. Every mandatory manifest field is a field Rig.Manifest refuses to load without,
# and adding a field no consumer reads would weaken that meaning rather than strengthen it.
GENERATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n \
  --argjson chainId       "$CHAIN_ID" \
  --arg     generatedAt   "$GENERATED_AT" \
  --arg     generatedFrom "$IMPORT_REF" \
  --arg     deployer      "$DEPLOYER" \
  --arg     sender        "$SENDER" \
  --arg     vom           "$VOM" \
  --arg     rvm           "$RVM" \
  --arg     dfm           "$DFM" \
  --arg     hook          "$HOOK" \
  --arg     pm            "$PM" \
  --arg     psh           "$PSH" \
  --arg     pspm          "$PSPM" \
  --arg     swapr         "$SWAPR" \
  --arg     liqr          "$LIQR" \
  --arg     poolId        "$POOL_ID" \
  --arg     currency0     "$CURRENCY0" \
  --arg     currency1     "$CURRENCY1" \
  --argjson tickSpacing   "$TICK_SPACING" \
  --argjson initTs        "$INIT_TS" \
  --argjson initTick      "$INIT_TICK" \
  '{
     chainId: $chainId,
     generatedAt: $generatedAt,
     generatedFrom: $generatedFrom,
     accounts: { deployer: $deployer, sender: $sender },
     contracts: {
       VolOrderManagerMod: $vom,
       RealizedVolatilityMod: $rvm,
       DynamicFeeMod: $dfm,
       DynamicFeeHook: $hook,
       PoolManager: $pm,
       PriceSetterHook: $psh,
       PriceSetterPoolManager: $pspm,
       PoolSwapTest: $swapr,
       PoolModifyLiquidityTest: $liqr
     },
     pool: { poolId: $poolId, currency0: $currency0, currency1: $currency1, tickSpacing: $tickSpacing },
     seed: { initTs: $initTs, initTick: $initTick }
   }' > "$MANIFEST"

# --- Step 10: summary ------------------------------------------------------
echo
echo "RIG UP  chainId=$CHAIN_ID  ref=$IMPORT_REF  hook-broadcast-shape=$HOOK_SHAPE"
printf '  %-24s %s\n' \
  VolOrderManagerMod     "$VOM" \
  RealizedVolatilityMod  "$RVM" \
  DynamicFeeMod          "$DFM" \
  DynamicFeeHook         "$HOOK" \
  PoolManager            "$PM" \
  PriceSetterHook        "$PSH" \
  PriceSetterPoolManager "$PSPM" \
  PoolSwapTest           "$SWAPR" \
  PoolModifyLiquidityTest "$LIQR"
printf '  %-24s %s\n' deployer "$DEPLOYER" sender "$SENDER" poolId "$POOL_ID"
echo "  manifest: $MANIFEST   (anvil pid $ANVIL_PID left RUNNING; stop with $0 --stop)"
