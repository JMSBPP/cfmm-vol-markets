#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# capture-chain-read.sh -- CHAIN-02's OBSERVATIONAL half, against the LIVE rig,
# recorded in offchain/rig/chain-read-conformance.json.
#
# WHY THIS FILE EXISTS
# --------------------
# CHAIN-02's obvious test cannot fail. On a single-writer local anvil a pinned
# read and an unpinned read return the same value in every recorded field, so a
# check that made both and compared them would pass whether or not the pin
# existed. The defect is invisible unless the divergence is CONSTRUCTED, and
# constructing it means changing the chain's state between two reads -- which
# `cabal test` is structurally forbidden from doing (three greps assert it:
# DB-free, GAMS-free, and as of 27-02 chain-free).
#
# So the divergence is constructed here and the artifact is what the suite then
# asserts over, offline. The sequence is in offchain/app/ChainReadConformance.hs;
# this script owns the PRECONDITIONS, the artifact preservation, and the
# self-checks that stop a vacuous capture from being committed.
#
# THE GATE IS A VALUE, NOT A GREEN RUN
# ------------------------------------
#   jq -r '.measurements[] | select(.name=="pinned_read_survives_a_state_change")
#          | .unpinned_differs'
# must print exactly `true`. If the unpinned read did NOT move, the capture did
# not construct the divergence and the whole artifact is void: a pinned read
# agreeing with itself on a chain that did not change says nothing about pinning.
# That assertion is what stops this capture passing vacuously on a quiet chain,
# and it is asserted HERE as well as in `cabal test`, because an artifact that
# silently recorded a non-divergence would be committed and believed.
#
# USAGE
#   bash offchain/rig/deploy-rig.sh          # stands the rig up, leaves anvil running
#   bash offchain/rig/capture-chain-read.sh
#
# NOTE: this MUTATES the chain. It writes a new tick into the pool's Slot0 and
# mines. It is not idempotent against a fixed chain state and it must not be run
# against a rig whose state another measurement depends on -- the same warning
# capture-cheat-swap-proof.sh carries, for the same reason.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

MANIFEST="${RIG_MANIFEST:-offchain/rig/rig-manifest.json}"
IMPORT_REF=offchain/rig/import-ref.txt
OUT=offchain/rig/chain-read-conformance.json
# CHAIN-06. Sourced, never re-spelled -- offchain/rig/endpoint.sh states the default once for the
# shell side and Chain.Endpoint states it once for the Haskell side, and the suite asserts the two
# statements BYTE-EQUAL.
. offchain/rig/endpoint.sh
RPC="$RPC_URL"

# --- Preconditions: FAIL LOUDLY AND BY NAME, never skip ---------------------
#
# "never skip" is the operative half. 23-RESEARCH's ruling stands: a capture gated on "if the tool
# is present" fails OPEN, so on every machine without the tool it reports success for the reason it
# exists to forbid. There is no skip path below; every branch that cannot proceed exits 1 naming
# what was missing.
if [ ! -f "$MANIFEST" ]; then
  echo "CAPTURE FAIL: no manifest at $(realpath -m "$MANIFEST")" >&2
  echo "              stand the rig up first: bash offchain/rig/deploy-rig.sh" >&2
  exit 1
fi
if [ ! -f "$IMPORT_REF" ]; then
  echo "CAPTURE FAIL: no $IMPORT_REF -- generatedFrom cannot be recorded, and a" >&2
  echo "              capture without it cannot be told stale from fresh" >&2
  exit 1
fi
for key in PoolManager; do
  value=$(jq -r --arg k "$key" '.contracts[$k] // ""' "$MANIFEST")
  if [ -z "$value" ]; then
    echo "CAPTURE FAIL: $(realpath -m "$MANIFEST") has no contracts.$key" >&2
    echo "              re-run: bash offchain/rig/deploy-rig.sh" >&2
    exit 1
  fi
done
POOL_ID=$(jq -r '.pool.poolId // ""' "$MANIFEST")
if [ -z "$POOL_ID" ]; then
  echo "CAPTURE FAIL: $(realpath -m "$MANIFEST") has no pool.poolId -- there is no pool to read" >&2
  exit 1
fi
if ! cast block-number --rpc-url "$RPC" >/dev/null 2>&1; then
  echo "CAPTURE FAIL: nothing answered eth_blockNumber at $RPC" >&2
  echo "              This is NOT a skip. CHAIN-02's evidence is an observation against a real" >&2
  echo "              chain, and a capture that quietly did nothing would leave the committed" >&2
  echo "              artifact stale while reporting success." >&2
  echo "              Stand the rig up first: bash offchain/rig/deploy-rig.sh" >&2
  exit 1
fi

# The chainId is asserted HERE as well as inside the program, and before anything is written.
# 27-01 put the same assertion above deploy-rig.sh's first --broadcast for the same reason: a
# state-changing call aimed at the wrong chain is not recoverable by noticing afterwards.
LIVE_CHAIN_ID=$(cast chain-id --rpc-url "$RPC")
MANIFEST_CHAIN_ID=$(jq -r '.chainId' "$MANIFEST")
if [ "$LIVE_CHAIN_ID" != "$MANIFEST_CHAIN_ID" ]; then
  echo "CAPTURE FAIL: the chain answering at $RPC is id $LIVE_CHAIN_ID and the manifest" >&2
  echo "              describes id $MANIFEST_CHAIN_ID. Every address this capture reads comes" >&2
  echo "              from that manifest, and this capture WRITES STORAGE." >&2
  exit 1
fi

# --- VALIDATE FIRST, REPLACE SECOND ----------------------------------------
# The same preservation capture-cheat-swap-proof.sh performs, for the same reason: the writer
# hardcodes the committed path, so a capture that FAILS a self-check below would otherwise have
# already destroyed the good evidence by the time the check fired.
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
cabal run -v0 chain-read-conformance

# Stable, sorted formatting so two runs differ only where the CHAIN differs and never because of
# key ordering.
jq -S . "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"

M='.measurements[] | select(.name=="pinned_read_survives_a_state_change")'

# --- Self-check 1: THE GATE. The divergence was CONSTRUCTED. ---------------
UNPINNED_DIFFERS=$(jq -r "$M | .unpinned_differs" "$OUT")
if [ "$UNPINNED_DIFFERS" != "true" ]; then
  echo "CAPTURE FAIL: unpinned_differs = $UNPINNED_DIFFERS." >&2
  echo "              The unpinned read did NOT move, so the divergence was never constructed" >&2
  echo "              and every other field in this artifact is a pinned read agreeing with" >&2
  echo "              itself on a chain that did not change. That is not evidence about" >&2
  echo "              pinning -- it is the vacuous pass CHAIN-02's whole shape exists to avoid." >&2
  echo "              This is a FINDING, not a threshold to adjust: the state change or the" >&2
  echo "              mining did not land. Report it." >&2
  exit 1
fi

# --- Self-check 2: the pin HELD. -------------------------------------------
PINNED_EQ=$(jq -r "$M | .pinned_equals_block_b" "$OUT")
if [ "$PINNED_EQ" != "true" ]; then
  PINNED=$(jq -r "$M | .pinned_value" "$OUT")
  BEFORE=$(jq -r "$M | .value_at_b_before" "$OUT")
  echo "CAPTURE FAIL: pinned_equals_block_b = $PINNED_EQ." >&2
  echo "              The read PINNED at block b returned $PINNED after the state change and" >&2
  echo "              the value at b was $BEFORE. The pin does not pin. This is CHAIN-02's" >&2
  echo "              defect, observed." >&2
  exit 1
fi

# --- Self-check 3: the chain actually advanced. ----------------------------
ADVANCED=$(jq -r "$M | .block_advanced" "$OUT")
if [ "$ADVANCED" != "true" ]; then
  echo "CAPTURE FAIL: block_advanced = $ADVANCED -- no block was mined after the write, so" >&2
  echo "              'pinned at b' and 'unpinned' name the same height and self-check 1" >&2
  echo "              could only have passed by accident." >&2
  exit 1
fi

# --- Self-check 4: the unpinned probe recorded NO height. ------------------
# A null, never a plausible number. A sentinel like 0 or -1 is a height a downstream reader cannot
# tell from a real one, which is the whole reason readback_height is a Maybe.
UNPINNED_H=$(jq -r "$M | .unpinned_readback_height" "$OUT")
if [ "$UNPINNED_H" != "null" ]; then
  echo "CAPTURE FAIL: unpinned_readback_height = $UNPINNED_H, and it must be null." >&2
  echo "              An unpinned read that records a plausible height is indistinguishable" >&2
  echo "              from a pinned one once it is in the artifact." >&2
  exit 1
fi

# --- Self-check 5: the two reads actually DISAGREE. ------------------------
# Distinct from self-check 1. Self-check 1 says the CHAIN moved; this says the two READS moved
# apart. A capture where the chain moved and BOTH reads followed it satisfies the first and fails
# this one, and that case is CHAIN-02's defect exactly.
DISAGREE=$(jq -r "$M | .pinned_and_unpinned_disagree" "$OUT")
ABOVE=$(jq -r "$M | .write_landed_above_b" "$OUT")
if [ "$DISAGREE" != "true" ] || [ "$ABOVE" != "true" ]; then
  echo "CAPTURE FAIL: pinned_and_unpinned_disagree = $DISAGREE, write_landed_above_b = $ABOVE." >&2
  echo "              If the write did not land ABOVE the pinned block it landed IN it, and the" >&2
  echo "              artifact would record a broken pin that is really a broken construction." >&2
  echo "              MEASURED at 27-02: anvil_setStorageAt does not create a block -- it writes" >&2
  echo "              into the state OF THE CURRENT HEAD -- so the capture mines before writing." >&2
  exit 1
fi

# --- Self-check 6: below the pool, every pinned read is REFUSED, by name. --
# This is the arm that shows the block parameter is honoured WITHOUT needing a state change at
# all: the pool does not exist at low heights, and a pin that were being ignored would return the
# live word at every one of them.
S='.measurements[] | select(.name=="the_pin_locates_the_block_the_pool_appeared")'
S_ALL=$(jq -r "$S | .all_below_refused" "$OUT")
S_NAMED=$(jq -r "$S | .all_below_name_the_field" "$OUT")
S_FIRST=$(jq -r "$S | .first_readable_block" "$OUT")
if [ "$S_ALL" != "true" ] || [ "$S_NAMED" != "true" ] || [ "$S_FIRST" = "null" ]; then
  echo "CAPTURE FAIL: all_below_refused=$S_ALL names_the_field=$S_NAMED" >&2
  echo "              first_readable_block=$S_FIRST" >&2
  echo "              Either a read below the pool's first block returned a VALUE -- which means" >&2
  echo "              the block parameter is not reaching the node -- or a refusal did not name" >&2
  echo "              the field, which is CHAIN-03." >&2
  exit 1
fi

echo
echo "chain-read conformance captured:"
jq -r "$M | \"  block b            : \(.block_b)\",
            \"  block after        : \(.block_after)\",
            \"  pinned  at b       : \(.pinned_value)\",
            \"  unpinned (head)    : \(.unpinned_value)\",
            \"  pinned held        : \(.pinned_equals_block_b)\",
            \"  unpinned differs   : \(.unpinned_differs)\"" "$OUT"
jq -r "$S | \"  pool appears at    : block \(.first_readable_block), and every one of the \(.refused_below_count) reads below it was refused by name\"" "$OUT"
echo
echo "wrote $(realpath -m "$OUT")"
echo "Commit it: cabal test asserts over this file and opens no socket of its own."
