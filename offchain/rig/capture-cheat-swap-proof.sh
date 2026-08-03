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

# --- VALIDATE FIRST, REPLACE SECOND ----------------------------------------
# M-5. The write below is atomic, so there is no truncation window -- but a capture that
# FAILS any of the five self-checks below had already destroyed the good committed
# evidence by the time the check fired. That falsifies this script's own rationale at
# lines 77-78 ("a capture that silently wrote the wrong tick is worse than no capture"):
# the failure mode it names leaves the operator with a bad artifact and no good one.
#
# The writer is offchain/app/CheatSwapProof.hs:78, which hardcodes the output path (by
# design -- README.md:234-238: RIG_CHEAT_SWAP_PROOF redirects the CHECKS only). So the
# preservation is done HERE, where the tracked file lives: the previous artifact is kept
# beside the target and put BACK on any non-zero exit, including a SIGINT. On success it
# is removed. `git status` is therefore clean-or-correct after every run, never neither.
if [ -f "$OUT" ]; then
  cp -p "$OUT" "$OUT.prev"
  PREV_SHA=$(sha256sum "$OUT" | cut -d' ' -f1)
else
  PREV_SHA="(no previous artifact)"
fi
restore_on_failure() {
  local rc=$?
  rm -f "$OUT.tmp"
  if [ "$rc" -ne 0 ] && [ -f "$OUT.prev" ]; then
    mv -f "$OUT.prev" "$OUT"
    echo "  RESTORED $OUT to its previous contents (sha256 $PREV_SHA)." >&2
    echo "           The capture failed, so the evidence it would have replaced is kept." >&2
  fi
  rm -f "$OUT.prev"
  exit "$rc"
}
trap restore_on_failure EXIT

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
#
# "Silent" here means the hook recorded ITS OWN pool's tick, NOT that it recorded
# nothing. MEASURED: e3_count = 1, e3.tick = 4999 -- the swap still fires
# beforeSwap and still writes a timepoint; what does not happen is the cheated
# 7000 arriving from the other manager. offchain/test/Main.hs:2656 asserts the
# same e3_count == 1 over the committed artifact.
#
# The existence, the status and the E3 COUNT are therefore asserted BEFORE the
# tick is interpreted. Without that, `[ "$B_TICK" = "7000" ]` fired only on that
# exact literal, so a MISSING row ("") and a placeholder `e3: null` ("null") both
# read as a pass -- the check that exists to detect "the blocker analysis is
# wrong" could not tell "correctly silent" from "never ran". Falsified: with the
# row deleted, with e3 nulled, and with status forced to 0, the old form exited 0
# on all three and printed `COUNTER: ... e3.tick =  (status )`.
B_ROWS=$(jq -c '[.measurements[] | select(.name=="cheat_wrong_pool_then_swap")]' "$OUT")
if [ "$(printf '%s' "$B_ROWS" | jq -r 'length')" != "1" ]; then
  echo "CAPTURE FAIL: the artifact carries $(printf '%s' "$B_ROWS" | jq -r 'length') rows named" >&2
  echo "              cheat_wrong_pool_then_swap, expected exactly 1. A missing counter-" >&2
  echo "              measurement is an UNRUN check, not a silent one. Absence never passes." >&2
  exit 1
fi
read -r B_STATUS B_E3COUNT B_TICK <<<"$(printf '%s' "$B_ROWS" \
  | jq -r '.[0] | "\(.status) \(.e3_count) \(.e3.tick // "none")"')"
if [ "$B_STATUS" != "1" ]; then
  echo "CAPTURE FAIL: the counter-measurement did not complete (status $B_STATUS)." >&2
  echo "              revert_reason: $(printf '%s' "$B_ROWS" | jq -r '.[0].revert_reason // "(none recorded)"')" >&2
  echo "              A swap that never landed proves nothing about where the cheat went." >&2
  exit 1
fi
if [ "$B_E3COUNT" != "1" ]; then
  echo "CAPTURE FAIL: the counter-measurement emitted $B_E3COUNT E3 logs, expected exactly 1." >&2
  echo "              beforeSwap runs before any swap math, so a status-1 receipt MUST carry a" >&2
  echo "              timepoint. Zero here means the G1 same-second guard ate the write and the" >&2
  echo "              measurement observed nothing -- it is not evidence of silence." >&2
  exit 1
fi
case "$B_TICK" in
  ''|none|null|*[!0-9-]*)
    echo "CAPTURE FAIL: the counter-measurement's E3 carries no decodable tick (got '$B_TICK')" >&2
    echo "              while reporting e3_count=1. The row and its log disagree." >&2
    exit 1 ;;
esac
if [ "$B_TICK" = "7000" ]; then
  echo "CAPTURE FAIL: cheating PriceSetterPoolManager DID move the hook's recorded tick" >&2
  echo "              (e3.tick = 7000, status $B_STATUS). The two-PoolManager blocker as" >&2
  echo "              described is WRONG. Stop and report -- do not proceed." >&2
  exit 1
fi

# --- Self-check 2b: the G1 same-second no-op ------------------------------
# The forced-collision step must come back at status 1 with an E5 and NO E3.
# This is the cheapest falsifiable check of clock discipline that exists, and
# both counts arrive in the same receipt.
read -r C2_E3 C2_E5 C2_STATUS <<<"$(jq -r '.measurements[]
  | select(.name=="same_second_repeat_step2")
  | "\(.e3_count) \(.e5_count) \(.status)"' "$OUT")"
if [ "$C2_E3 $C2_E5 $C2_STATUS" != "0 1 1" ]; then
  echo "CAPTURE FAIL: the forced same-second repeat did not behave as the source says." >&2
  echo "              got e3_count=$C2_E3 e5_count=$C2_E5 status=$C2_STATUS, expected 0 1 1" >&2
  echo "              RealizedVolatilityStateLib compares lastTimepointTimestamp to now for" >&2
  echo "              EQUALITY. If an E3 appeared, the guard is not what the source says it is." >&2
  exit 1
fi

# --- Self-check 2c: the extreme tick is a RECORDED outcome, either way -----
# Research flags the near-floor degeneracy as an unmeasured analytical argument.
# A revert is an acceptable answer; an unrecorded outcome is not.
read -r D_STATUS D_E3 D_TICK <<<"$(jq -r '.measurements[]
  | select(.name=="extreme_tick_near_floor")
  | "\(.status) \(.e3_count) \(.e3.tick // "none")"' "$OUT")"
if [ "$D_STATUS" = "1" ]; then
  if [ "$D_E3" != "1" ] || [ "$D_TICK" != "-887259" ]; then
    echo "CAPTURE FAIL: the floor-tick step succeeded but recorded e3_count=$D_E3 tick=$D_TICK" >&2
    echo "              beforeSwap runs BEFORE any swap math, so a status-1 receipt must carry" >&2
    echo "              the cheated tick. Report this rather than adjusting the expectation." >&2
    exit 1
  fi
elif [ "$(jq -r '.measurements[] | select(.name=="extreme_tick_near_floor") | .revert_reason // ""' "$OUT")" = "" ]; then
  echo "CAPTURE FAIL: the floor-tick step did not succeed and recorded no revert_reason." >&2
  echo "              A revert here is an acceptable MEASUREMENT and means 22-05 must choose" >&2
  echo "              direction and price limit from the cheated tick -- but only if it is" >&2
  echo "              written down." >&2
  exit 1
fi

# --- Self-check 3: the composition preserved the fee bits ------------------
# Compared as decimal STRINGS. The words run to 256 bits and jq's numbers are
# doubles; a rounded word still looks like a word. Measurements that did not
# complete carry no words and are skipped by the select.
#
# THE FLOOR COMES FIRST, AND FROM A DIFFERENT FIELD. The loop below filters on
# `has("word_before_high184")` -- the very field it asserts over -- so if the
# writer stopped emitting those keys the select yielded zero rows, the body never
# ran, and "the composition preserved the fee bits" was reported having compared
# NOTHING. Falsified: with both high184 keys stripped from all six rows the old
# form exited 0.
#
# `status` is the independent denominator. A row that did not complete records
# status 0 with a revert_reason and carries no words (CheatSwapProof.hs:288-294);
# every row that DID complete carries both (:295-312). So the two counts must be
# equal, and self-check 2c permits exactly ONE row -- extreme_tick_near_floor --
# to be a recorded revert. Hence the 5 floor. MEASURED: all 6 complete.
N_COMPLETE=$(jq -r '[.measurements[] | select(.status == 1)] | length' "$OUT")
N_WORDS=$(jq -r '[.measurements[]
                  | select(has("word_before_high184") and has("word_written_high184"))] | length' "$OUT")
if [ "$N_WORDS" != "$N_COMPLETE" ]; then
  echo "CAPTURE FAIL: $N_COMPLETE measurements completed (status 1) but only $N_WORDS carry the" >&2
  echo "              word_before_high184 / word_written_high184 pair. A completed measurement" >&2
  echo "              always records both, so the writer changed shape and the G5b comparison" >&2
  echo "              below would silently compare fewer rows than it claims." >&2
  exit 1
fi
if [ "$N_WORDS" -lt 5 ]; then
  echo "CAPTURE FAIL: only $N_WORDS measurements carry slot0 words, expected at least 5." >&2
  echo "              extreme_tick_near_floor is the ONE measurement allowed to be a recorded" >&2
  echo "              revert (self-check 2c). Fewer than 5 means G5b would be 'verified' over" >&2
  echo "              a sample too small to have exercised the composition at all." >&2
  exit 1
fi
N_COMPARED=0
while read -r nm before after; do
  N_COMPARED=$((N_COMPARED + 1))
  if [ "$before" != "$after" ]; then
    echo "CAPTURE FAIL: $nm did not preserve slot0 bits >= 184" >&2
    echo "              word_before high bits : $before" >&2
    echo "              word_written high bits: $after" >&2
    echo "              compose_slot0 masks at 184 so protocolFee/lpFee survive BY" >&2
    echo "              CONSTRUCTION (G5b). If these differ, the mask moved." >&2
    exit 1
  fi
done < <(jq -r '.measurements[] | select(has("word_before_high184"))
                | "\(.name) \(.word_before_high184) \(.word_written_high184)"' "$OUT")
# The loop body ran once per row it was handed. Asserting that against the count
# taken above is what turns "no rows" from a pass into a failure. The loop uses
# `< <(...)`, not a pipe, so this counter is the one the body incremented.
if [ "$N_COMPARED" != "$N_WORDS" ]; then
  echo "CAPTURE FAIL: G5b compared $N_COMPARED rows but $N_WORDS carry slot0 words" >&2
  exit 1
fi
echo "  G5b: slot0 bits >= 184 preserved on all $N_COMPARED completed measurements"

# --- Self-check 3b: every measurement is present ---------------------------
# A group that failed still emits a placeholder row, so a shrinking list means a
# measurement was silently dropped rather than recorded.
COUNT=$(jq -r '.measurements | length' "$OUT")
if [ "$COUNT" != "6" ]; then
  echo "CAPTURE FAIL: the artifact has $COUNT measurements, expected 6" >&2
  exit 1
fi

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
echo "  COUNTER: cheat_wrong_pool_then_swap e3.tick = $B_TICK (status $B_STATUS, e3_count $B_E3COUNT) -- cheated 7000, so 7000 is the FAIL value"
