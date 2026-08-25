#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# capture-loop.sh -- LOOP-01..05's LIVE half, end to end, against a real rig,
# recorded in offchain/rig/loop-conformance.json.
#
# THIS SCRIPT HAS NEVER BEEN RUN, AND THAT IS RECORDED RATHER THAN HIDDEN.
# ------------------------------------------------------------------------
# It cannot be run today. Two preconditions below are unmet in every checkout
# this workstream builds from, both of them owned by other tracks, and both are
# named by number in the refusal that stops the run:
#
#   * CHAIN-01 / GitHub issue #26. There is no deployable emitter of the
#     `Shock` event. It is emitted from a forge TEST
#     (test/models/mev_tax_model_one/AlgebraIntegralMevTaxModelOneShocks.t.sol),
#     not from a contract another process can drive, and
#     foundry-scripts/mev_tax_model_one/ holds only DeployAlgebraFactory.s.sol.
#     `next(address,uint160,int24,uint24,uint24)` -- the SELECTOR_NEXT constant --
#     is a FUNCTION SELECTOR on AlgebraIntegralShocksWriterInterface.plk and has
#     never been an event; the event is
#     Shock(address indexed pool, int24, uint24, uint24). Neither the selector nor
#     the event's topic0 is spelled in this file: both are inside
#     sc3_literal_purge's blast radius, both are recomputed rather than
#     transcribed (Chain.Shock.shock_signature through keccak256, asserted against
#     `cast keccak` in cabal test), and .planning/REQUIREMENTS.md CHAIN-01 carries
#     the written values for a reader who needs them.
#     WHAT WOULD DISCHARGE IT: one driver emitting a single Shock in a MINED
#     transaction on the resolved endpoint. Nothing more, and it is not this
#     workstream's to build.
#
#   * LOOP-04 / GitHub issues #24 and #25. The publication directory
#     test/models/mev_tax_model_one/fixtures/ is absent from this worktree AND
#     from origin/develop -- MEASURED at 28-04, both directions, and registered
#     as a standing check (the_fixtures_directory_is_recorded_absent_from_both_trees).
#     The loop REFUSES to create it, so the run stops at its own startup
#     precondition with exit 40 before a block is read.
#
# So the script ships unrun, its artifact is deliberately ABSENT, and the suite
# asserts that absence: `the_live_loop_capture_is_present_and_names_its_block`
# passes while offchain/rig/loop-conformance.json does not exist and FAILS on the
# day it appears, at which point the phase close must assert over the artifact
# instead. That inversion is the only form in which "this evidence does not exist
# yet" can itself be evidence.
#
# WHY THE EVIDENCE HAS TO BE A CAPTURE AT ALL
# -------------------------------------------
# `cabal test` is chain-free, database-free and solver-free by three structural
# greps with positive controls. Every LOOP-01..05 proof in the suite is therefore
# driven against synthetic logs, Store.Memory, new_memory_ledger and a stub
# Solver -- which is enough for the requirements as written (they are about the
# watermark, the ledger, the atomic write and the shutdown) and is not enough for
# the COMPOSITION. This file is where the composition is observed once, out of
# band, and the artifact is what the suite then reads offline.
#
# THE GATE IS A VALUE, NOT A GREEN RUN
# ------------------------------------
# Every self-check below reads a NUMBER out of the artifact and refuses on it.
# The two that matter most:
#
#   * `.watermark.after` must be strictly greater than `.watermark.before`, or
#     the loop processed nothing and every other field describes a run that did
#     not happen;
#   * `.events | length` must be at least 1, or no Shock was ever seen and the
#     capture is a green statement about an empty chain -- which is precisely
#     what issue #26 makes the default outcome.
#
# 23-RESEARCH's ruling stands and is why there is no skip path anywhere below: a
# capture gated on "if the tool is present" fails OPEN, so on every machine
# without the tool it reports success for the reason it exists to forbid.
#
# USAGE
#   bash offchain/rig/deploy-rig.sh            # a FRESH rig; this is not optional
#   PGSTORE_DSN=...  GAMS_MODEL=/abs/volume_path.gms \
#     bash offchain/rig/capture-loop.sh
#   bash offchain/rig/deploy-rig.sh --stop
#
# NOTE: this MUTATES the chain, the database and the publication directory, and
# it is NOT idempotent. It needs a FRESH rig -- the same warning
# capture-chain-read.sh and capture-cheat-swap-proof.sh carry, for the same
# reason: the loop advances a persisted watermark, so a second run over the same
# database sees no new blocks and records a drained loop as if it were a
# processed one.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

MANIFEST="${RIG_MANIFEST:-offchain/rig/rig-manifest.json}"
IMPORT_REF=offchain/rig/import-ref.txt
OUT=offchain/rig/loop-conformance.json
FIXTURE_DIR_DEFAULT=test/models/mev_tax_model_one/fixtures
FIXTURES="${FIXTURE_DIR:-$FIXTURE_DIR_DEFAULT}"
FIXTURE_FILE=volume_path.json
# The contract name Loop's own executable looks for. Stated here so the refusal
# can quote it rather than saying "a contract" -- offchain/app/LoopMain.hs holds
# the same string in shock_emitter_contract.
SHOCK_EMITTER=ShockWriter

# CHAIN-06. Sourced, never re-spelled -- offchain/rig/endpoint.sh states the default once for the
# shell side and Chain.Endpoint states it once for the Haskell side, and the suite asserts the two
# statements BYTE-EQUAL.
. offchain/rig/endpoint.sh
RPC="$RPC_URL"

fail() {
  echo "CAPTURE FAIL: $1" >&2
  shift
  for line in "$@"; do echo "              $line" >&2; done
  exit 1
}

# --- Preconditions: FAIL LOUDLY AND BY NAME, never skip ---------------------

command -v jq   >/dev/null 2>&1 || fail "jq is not on PATH." \
  "Every field of this artifact is read back and asserted with jq, and a capture" \
  "that could not read its own output would commit an unchecked one."
command -v cast >/dev/null 2>&1 || fail "cast (foundry) is not on PATH." \
  "The liveness probe and the chainId assertion are cast calls."
command -v psql >/dev/null 2>&1 || fail "psql is not on PATH." \
  "The watermark and every ledger row are read straight out of loop_event and" \
  "loop_watermark. A capture that took the loop's own word for what it wrote" \
  "would be the loop agreeing with itself."

[ -f "$MANIFEST" ] || fail "no manifest at $(realpath -m "$MANIFEST")" \
  "stand the rig up first: bash offchain/rig/deploy-rig.sh"
[ -f "$IMPORT_REF" ] || fail "no $IMPORT_REF -- generatedFrom cannot be recorded" \
  "and a capture without it cannot be told stale from fresh."

if ! cast block-number --rpc-url "$RPC" >/dev/null 2>&1; then
  fail "nothing answered eth_blockNumber at $RPC." \
    "This is NOT a skip. LOOP-01..05's live evidence is an observation against a real" \
    "chain, and a capture that quietly did nothing would leave the committed artifact" \
    "stale -- or absent -- while reporting success." \
    "Stand the rig up first: bash offchain/rig/deploy-rig.sh"
fi

LIVE_CHAIN_ID=$(cast chain-id --rpc-url "$RPC")
MANIFEST_CHAIN_ID=$(jq -r '.chainId' "$MANIFEST")
if [ "$LIVE_CHAIN_ID" != "$MANIFEST_CHAIN_ID" ]; then
  fail "the chain answering at $RPC is id $LIVE_CHAIN_ID and the manifest describes id $MANIFEST_CHAIN_ID." \
    "Every address this capture reads comes from that manifest, and this capture DRIVES" \
    "TRANSACTIONS and WRITES A DATABASE."
fi

# --- THE BLOCK. CHAIN-01, issue #26. ---------------------------------------
#
# Checked before anything is deployed or written, because it is the one that
# cannot be repaired by re-running: there is no emitter to point the loop at.
EMITTER=$(jq -r --arg k "$SHOCK_EMITTER" '.contracts[$k] // ""' "$MANIFEST")
if [ -z "$EMITTER" ]; then
  fail "$(realpath -m "$MANIFEST") names no contracts.$SHOCK_EMITTER, so there is nothing to emit a Shock." \
    "deploy-rig.sh step 3b (DeployShockWriter.s.sol, shipped by PR #42 for issue #26) did not" \
    "run, or the manifest predates it. Re-run: bash offchain/rig/deploy-rig.sh" \
    "HISTORY, kept so the refusal reads the same to an operator who last saw the old one:" \
    "CHAIN-01 WAS BLOCKED, ON GITHUB ISSUE #26 -- the plank / mev-migrate workstream." \
    "The Shock event is emitted from a forge TEST, not from a deployable contract" \
    "another process can drive: foundry-scripts/mev_tax_model_one/ holds only" \
    "DeployAlgebraFactory.s.sol. The SELECTOR_NEXT constant is a FUNCTION SELECTOR on" \
    "AlgebraIntegralShocksWriterInterface.plk and never an event; the event is" \
    "Shock(address indexed pool, int24, uint24, uint24)." \
    "WHAT WOULD DISCHARGE IT: one driver emitting a single Shock in a MINED" \
    "transaction at $RPC. Everything on this side is ready -- Chain.Shock decodes" \
    "it, Chain.Read pins the reads to its block, and the loop is proven chain-free" \
    "in cabal test. NOT THIS WORKSTREAM'S TO BUILD, and not a threshold to lower."
fi

POOL_ID=$(jq -r '.pool.poolId // ""' "$MANIFEST")
[ -n "$POOL_ID" ] || fail "$(realpath -m "$MANIFEST") has no pool.poolId -- there is no pool to read."
MANAGER=$(jq -r '.contracts.PoolManager // ""' "$MANIFEST")
[ -n "$MANAGER" ] || fail "$(realpath -m "$MANIFEST") has no contracts.PoolManager." \
  "re-run: bash offchain/rig/deploy-rig.sh"

# --- THE PUBLICATION DIRECTORY. LOOP-04, issues #24 and #25. ---------------
#
# The loop never creates it and neither does this script. MEASURED at 28-04: the
# directory is absent from this worktree AND from origin/develop.
if [ ! -d "$FIXTURES" ]; then
  fail "the publication directory $(realpath -m "$FIXTURES") DOES NOT EXIST." \
    "It belongs to the mev_tax_model_one workstream -- GitHub issues #24 AND #25 --" \
    "and neither the loop nor this capture will create it: a directory invented here" \
    "would publish a fixture into a path of its own making, report success, and leave" \
    "the consuming forge test skipping forever." \
    "Land the directory on develop from the #24 track, or point FIXTURE_DIR at a" \
    "directory that already exists. The loop's own startup precondition refuses the" \
    "same thing with exit 40, and this check exists so the refusal is reported by the" \
    "capture rather than discovered as an exit code."
fi

# --- THE PROVER. A startup precondition of the loop, so it is one here. ----
GAMS_BIN_RESOLVED="${GAMS_BIN:-$(command -v gams || true)}"
[ -n "$GAMS_BIN_RESOLVED" ] && [ -x "$GAMS_BIN_RESOLVED" ] || fail \
  "the prover could not be resolved (GAMS_BIN='${GAMS_BIN-<unset>}')." \
  "Set GAMS_BIN to the binary, or put gams on PATH. Resolution is a STARTUP" \
  "precondition of the loop -- 28-01's ruling -- so a run that reached the first" \
  "block without it would report a resolution failure under a solver discriminator."
[ -n "${GAMS_MODEL:-}" ] && [ -f "${GAMS_MODEL:-}" ] || fail \
  "GAMS_MODEL is unset or not a file (GAMS_MODEL='${GAMS_MODEL-<unset>}')." \
  "volume_path.gms is NOT in this worktree -- model/ belongs to the GAMS workstream --" \
  "so the path is REQUIRED here rather than defaulted."

# --- THE STORE. ------------------------------------------------------------
DSN="${PGSTORE_DSN:-}"
[ -n "$DSN" ] || fail "PGSTORE_DSN is unset." \
  "The ledger and the watermark are rows; a capture with no database has nothing" \
  "to read them out of."
psql "$DSN" -Atqc 'select 1' >/dev/null 2>&1 || fail "no database answered PGSTORE_DSN." \
  "bash offchain/rig/capture-store-conformance.sh provisions one via Docker."

# --- VALIDATE FIRST, REPLACE SECOND ----------------------------------------
# The same preservation capture-chain-read.sh performs, for the same reason: the writer hardcodes
# the committed path, so a capture that FAILED a self-check below would otherwise already have
# destroyed the good evidence by the time the check fired.
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

# --- BEFORE ----------------------------------------------------------------
# A FRESH database has no loop_watermark table yet: the loop applies migrations 001-005 itself at
# startup (LoopMain.run_migrations_or_exit), so on the first run the table appears AFTER this
# read. MEASURED on the first live run: `relation "loop_watermark" does not exist`, and under
# set -e that ended the capture at 0s having driven nothing. A missing table is honestly
# "no watermark" -- the same null the empty table yields -- and is recorded as exactly that.
if [ "$(psql "$DSN" -Atqc "select to_regclass('loop_watermark') is not null" | head -1)" = t ]; then
  WM_BEFORE=$(psql "$DSN" -Atqc "select coalesce(max(block)::text, 'null') from loop_watermark" \
                | head -1)
else
  WM_BEFORE=null
fi
[ -n "$WM_BEFORE" ] || WM_BEFORE=null
HEAD_BEFORE=$(cast block-number --rpc-url "$RPC")

# --- DRIVE ONE Shock -------------------------------------------------------
#
# One MINED transaction, on the resolved endpoint, from the contract the manifest
# names. The values are the fixture's own -- VOLUME_PATH.md section 2 -- so the
# shock the loop reads is the shock every offline proof in this repository is
# about.
#
# THE CALL BELOW IS UNCONFIRMED AND SAYING SO IS THE POINT. The emitter does not
# exist in any tree this workstream builds from (issue #26), so its entry point's
# NAME and ARGUMENT LIST cannot be read off anything -- only the EVENT is pinned,
# by its topic0, which is recomputed from Chain.Shock.shock_signature and asserted
# against `cast keccak` in cabal test. Whoever lands the emitter must correct this
# one line against the interface they ship; the refusal above is what stops the
# script reaching it in the meantime, and a plausible-looking call that was never
# executed is exactly the kind of thing that gets believed.
# CONFIRMED against the emitter shipped in PR #42 (issue #26): ShockWriterMod.plk,
# shock(address pool, int24 tickDiff, uint24 txlVolmNormRate, uint24 txlVolmDecay), flags
# internal. The pool is an ADDRESS -- the loop keys its reads by pool.poolId through PoolManager
# and never by this field, so the manifest's PoolManager is the truthful value. The values are
# VOLUME_PATH.md section 2's: tickDiff 0, txlVolmNormRate 490000 (that is delta*, 0.49 in pips --
# Loop.Run takes it as se_norm_rate), txlVolmDecay 0 (26-02 asserts decay never reaches the
# prover). The earlier draft carried 6497 here: that is the golden fixture's COMPOSED FEE, which the
# loop reads from the chain and never from the shock -- issue #41 records why that mattered.
cast send "$EMITTER" \
  'shock(address,int24,uint24,uint24)' \
  "$MANAGER" 0 490000 0 \
  --rpc-url "$RPC" \
  --mnemonic "test test test test test test test test test test test junk" \
  >/dev/null

HEAD_AFTER_EMIT=$(cast block-number --rpc-url "$RPC")
if [ "$HEAD_AFTER_EMIT" -le "$HEAD_BEFORE" ]; then
  fail "no block was mined by the emit (head $HEAD_BEFORE -> $HEAD_AFTER_EMIT)." \
    "An unmined Shock has no transaction hash and no log index, so it has no ledger" \
    "identity at all -- Loop.Poll.event_identity refuses it by field name."
fi

# --- THE LOOP, ONCE --------------------------------------------------------
#
# `--once` and not the resident mode: the capture has to END, and the mode is the
# only thing that differs between them (Loop.Run: one iteration function).
set +e
FIXTURE_DIR="$FIXTURES" cabal run -v0 loop -- --once
LOOP_EXIT=$?
set -e

# --- AFTER -----------------------------------------------------------------
WM_AFTER=$(psql "$DSN" -Atqc "select coalesce(max(block)::text, 'null') from loop_watermark" \
             | head -1)
[ -n "$WM_AFTER" ] || WM_AFTER=null
EVENTS_JSON=$(psql "$DSN" -Atqc \
  "select coalesce(json_agg(row_to_json(e) order by e.block, e.log_index)::text, '[]') \
     from (select tx_hash, log_index, block, model, key_scheme, \
                  encode(key, 'hex') as key_hex, outcome, reason, gams_ver, conopt_ver, fee_source \
             from loop_event) e")

PUBLISHED="$FIXTURES/$FIXTURE_FILE"
if [ -f "$PUBLISHED" ]; then
  FIXTURE_SHA=$(sha256sum "$PUBLISHED" | cut -d' ' -f1)
  FIXTURE_LEN=$(wc -c < "$PUBLISHED" | tr -d ' ')
  # THE FORK HEIGHT for the consuming forge test (plank's Gate B): the block the fixture was
  # published at, read back out of the fixture itself so this record and the file cannot
  # disagree. On a fresh single-shock run it equals head.afterEmit; the consumer's guard is
  # head >= blockNumber, then createSelectFork AT blockNumber -- the pool's state is
  # block-invariant after InitSwappableRig (the emitter never touches the pool), so the assert
  # at the fixture's own block is meaningful and a later shock on the same chain only raises head.
  FORK_HEIGHT=$(jq -r '.blockNumber // empty' "$PUBLISHED")
else
  FIXTURE_SHA=""
  FIXTURE_LEN=0
  FORK_HEIGHT=""
fi

jq -n -S \
  --arg generatedFrom "$(cat "$IMPORT_REF")" \
  --arg generatedAt   "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg endpoint      "$RPC" \
  --arg chainId       "$LIVE_CHAIN_ID" \
  --arg emitter       "$EMITTER" \
  --arg poolId        "$POOL_ID" \
  --arg manager       "$MANAGER" \
  --arg fixturePath   "$PUBLISHED" \
  --arg fixtureSha256 "$FIXTURE_SHA" \
  --argjson fixtureBytes "$FIXTURE_LEN" \
  --arg     forkHeight    "$FORK_HEIGHT" \
  --argjson exitCode     "$LOOP_EXIT" \
  --argjson headBefore   "$HEAD_BEFORE" \
  --argjson headAfter    "$HEAD_AFTER_EMIT" \
  --argjson wmBefore     "$WM_BEFORE" \
  --argjson wmAfter      "$WM_AFTER" \
  --argjson events       "$EVENTS_JSON" \
  '{ generatedFrom: $generatedFrom, generatedAt: $generatedAt,
     endpoint: $endpoint, chainId: $chainId,
     rig: { emitter: $emitter, poolId: $poolId, poolManager: $manager },
     head: { before: $headBefore, afterEmit: $headAfter },
     watermark: { before: $wmBefore, after: $wmAfter },
     exitCode: $exitCode,
     forkHeight: (if $forkHeight == "" then null else $forkHeight end),
     fixture: { path: $fixturePath, sha256: $fixtureSha256, bytes: $fixtureBytes },
     events: $events }' > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"

# --- Self-check 1: THE LOOP EXITED CLEAN. ----------------------------------
EXIT_RECORDED=$(jq -r '.exitCode' "$OUT")
if [ "$EXIT_RECORDED" != "0" ]; then
  fail "the loop exited $EXIT_RECORDED." \
    "Every non-zero code is in Loop.Config.exit_table -- 30..34 are halts, 40..44 are" \
    "preconditions -- and a capture that recorded one would be evidence of the halt," \
    "not of the loop. Look the number up in that table before changing anything here."
fi

# --- Self-check 2: THE WATERMARK MOVED. ------------------------------------
if [ "$(jq -r '.watermark.after > .watermark.before' "$OUT")" != "true" ]; then
  fail "the watermark did not advance ($(jq -r '.watermark.before' "$OUT") -> $(jq -r '.watermark.after' "$OUT"))." \
    "The loop processed nothing, so every other field in this artifact describes a run" \
    "that did not happen. This is a FINDING, not a threshold to adjust."
fi

# --- Self-check 3: A Shock WAS ACTUALLY SEEN. ------------------------------
if [ "$(jq -r '.events | length' "$OUT")" -lt 1 ]; then
  fail "the ledger holds no rows." \
    "The emit was mined and the watermark advanced, so the loop crossed the block and" \
    "decided nothing in it: either the topic0 filter, the emitter filter or the decoder" \
    "refused the log. A green capture over an empty ledger is the vacuous pass this" \
    "whole shape exists to avoid -- and it is the default outcome while issue #26 is" \
    "open, which is why it is asserted rather than assumed."
fi

# --- Self-check 4: THE FIXTURE IS ON DISK AND PARSES. ----------------------
if [ "$(jq -r '.fixture.bytes' "$OUT")" -lt 1 ] || [ -z "$(jq -r '.fixture.sha256' "$OUT")" ]; then
  fail "nothing was published at $PUBLISHED." \
    "LOOP-03 says the newest run reaches the fixture path the forge test reads; a run" \
    "that decided an event and published nothing is that requirement failing live."
fi
jq -e . "$PUBLISHED" >/dev/null || fail "the published fixture is not JSON." \
  "The atomic rename is what makes that impossible, so this is LOOP-03 observed failing."

# --- Self-check 5: EVERY LEDGER ROW CARRIES A KNOWN OUTCOME. ---------------
UNKNOWN=$(jq -r '([.events[].outcome] - ["elided","stored","not_persisted","inadmissible"]) | join(", ")' "$OUT")
if [ -n "$UNKNOWN" ]; then
  fail "the ledger holds outcome token(s) the vocabulary does not contain: $UNKNOWN." \
    "loop_event_outcome_known is the constraint that forbids it, so either it is gone or" \
    "the row was written by something that is not Loop.Ledger."
fi

echo
echo "loop conformance captured:"
jq -r '"  endpoint          : \(.endpoint) (chain \(.chainId))",
       "  watermark         : \(.watermark.before) -> \(.watermark.after)",
       "  ledger rows       : \(.events | length)",
       "  outcomes          : \([.events[].outcome] | join(", "))",
       "  fixture           : \(.fixture.bytes) bytes, sha256 \(.fixture.sha256)",
       "  loop exit         : \(.exitCode)"' "$OUT"
echo
echo "wrote $(realpath -m "$OUT")"
echo "Commit it: cabal test asserts over this file and opens no socket of its own."

# --- NEXT: the consuming forge test, against THIS rig, before deploy-rig --stop -----------------
# plank's Gate B replays the published dQx on-chain against the pool the fixture names. It needs
# the rig UP and the fork pinned at the fixture's own block; the three-arm guard on its side is
# chainId == fixture.chainId, code at fixture.pool, head >= fixture.blockNumber. Printed with the
# RESOLVED endpoint and the height read back from the file, so the replay's inputs are this run's.
if [ -n "${FORK_HEIGHT:-}" ]; then
  echo
  echo "NEXT  the consuming forge test, against this rig (anvil is still up; stop it AFTER):"
  echo "      forge test --match-test test__priceInvarianceUnderVolumePath \\"
  echo "        --fork-url $RPC --fork-block-number $FORK_HEIGHT -vv"
  echo "      then: bash offchain/rig/deploy-rig.sh --stop"
fi
