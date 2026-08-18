#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# capture-batch-return.sh -- record REAL (bool, uint256)[] returndata off the
# live V2 VolOrderManagerMod into offchain/rig/batch-return-capture.json.
#
# WHY THIS FILE EXISTS
# --------------------
# Until this script was run, the shape of the V2 batch return had never been
# OBSERVED on chain. It was derived from the emitter source and repeated through
# a hand-off document. A hand-off sentence and a byte string are not the same
# kind of evidence: the sentence cannot be wrong in a way that reddens. Every
# byte in the output artifact came off a LIVE chain through eth_call, in this
# script, on the run recorded in the artifact's own provenance fields.
#
# WHY eth_call AND NOT A TRANSACTION
# ----------------------------------
# create_orders RETURNS its array, so a plain eth_call hands the whole encoded
# result straight back. There is no transaction to sign, no gas to manage, no
# receipt to poll for and no nonce to sequence. Nothing on chain changes, so the
# four cases below are order-independent and every one of them sees the same
# orderCount -- which is also why the captured order ids are reproducible.
#
# WHY THE ARTIFACT IS COMMITTED
# -----------------------------
# So that `cabal test` can assert against real bytes while STAYING
# CHAIN-INDEPENDENT. That property is measured, not assumed: the Haskell suite
# is green with anvil down, and it is worth keeping -- a test suite that needs a
# rig is a test suite that gets skipped. This script is the one place that needs
# the chain; everything downstream reads the committed JSON.
#
# WHY THE PROVENANCE FIELDS EXIST
# -------------------------------
# rig-manifest.json is gitignored, so on a machine that never stood the rig up
# there is nothing to check the artifact against. The artifact therefore carries
# its own chainId, manager address and block number. A capture taken against a
# different chain, a different deployment or a stale block is then VISIBLE and
# reddens downstream, instead of passing quietly as plausible-looking bytes.
#
# USAGE
#   bash offchain/rig/deploy-rig.sh          # stands the rig up, leaves anvil running
#   bash offchain/rig/capture-batch-return.sh
# Re-running is reproducible: `jq -S 'del(.generatedAt, .blockNumber)'` over two
# runs against the same rig is byte-identical.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

MANIFEST="${RIG_MANIFEST:-offchain/rig/rig-manifest.json}"
GOLDEN="test/pos_spec/fixtures/vol_order_return_golden.json"
OUT=offchain/rig/batch-return-capture.json
# CHAIN-06. This line used to be the authority written out as a literal, so ETH_RPC_URL was
# accepted by the shell and ignored here -- the capture went to 8545 no matter what the operator
# exported, and so did the rig it claims to describe. The resolver is sourced, never re-spelled:
# offchain/rig/endpoint.sh is the ONE place the shell side states the default.
. offchain/rig/endpoint.sh
RPC="$RPC_URL"
SIG='create_orders(uint256,uint256[])'

# --- Preconditions: fail loudly, never default -----------------------------
if [ ! -f "$MANIFEST" ]; then
  echo "CAPTURE FAIL: no manifest at $(realpath -m "$MANIFEST")" >&2
  echo "              stand the rig up first: bash offchain/rig/deploy-rig.sh" >&2
  exit 1
fi
if [ ! -f "$GOLDEN" ]; then
  echo "CAPTURE FAIL: golden fixture not found at $(realpath -m "$GOLDEN")" >&2
  echo "              it belongs to the Solidity-testing track and is READ ONLY here" >&2
  exit 1
fi

MGR=$(jq -r '.contracts.VolOrderManagerMod' "$MANIFEST" | tr 'A-Z' 'a-z')
CHAIN=$(jq -r '.chainId' "$MANIFEST")
if [ -z "$MGR" ] || [ "$MGR" = "null" ]; then
  echo "CAPTURE FAIL: $(realpath -m "$MANIFEST") has no contracts.VolOrderManagerMod" >&2
  echo "              regenerate it: bash offchain/rig/deploy-rig.sh" >&2
  exit 1
fi
if [ -z "$CHAIN" ] || [ "$CHAIN" = "null" ]; then
  echo "CAPTURE FAIL: $(realpath -m "$MANIFEST") has no chainId" >&2
  echo "              regenerate it: bash offchain/rig/deploy-rig.sh" >&2
  exit 1
fi

# Captured ONCE, before any call, so every case in the artifact shares one block.
if ! BLOCK=$(cast block-number --rpc-url "$RPC" 2>/dev/null); then
  echo "CAPTURE FAIL: nothing answered eth_blockNumber at $RPC" >&2
  echo "              stand the rig up first: bash offchain/rig/deploy-rig.sh" >&2
  exit 1
fi
GENERATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# --- The V2 input word -----------------------------------------------------
# V2 INPUT WORD: skew@0..15 | strike@16..103 | width@104..127 | targetVega@128..223
# Source: src/modules/pos_spec/VolOrderManagerMod.plk:229-235 (the CODE).
# Lines 177-188 of that same file are a STALE V1 block (it says width is the top
# field and that bits >=128 must be zero) -- do not use it. A word built that way
# carries targetVega = 0, the tuple is REJECTED, and the batch SKIPS it rather
# than reverting, so the capture would degenerate into an all-invalid artifact
# that looks like a legitimate result.
#
# bash arithmetic is 64-bit and these words run to 224 bits, so the shifts are
# done in python3 and emitted as DECIMAL, which cast calldata accepts.
input_word() {   # strike width skew targetVega -> decimal u256
  python3 -c 'import sys; s,w,k,v=(int(a) for a in sys.argv[1:5]); print(k | (s<<16) | (w<<104) | (v<<128))' \
    "$1" "$2" "$3" "$4"
}

# --- Word-level helpers over returndata ------------------------------------
# The return is offset word, then length in ELEMENTS, then a static (bool,uint256)
# tuple per element: success at 2+2i, orderId at 3+2i.
success_words() { python3 -c '
import sys
h = sys.argv[1][2:]
w = [h[i:i+64] for i in range(0, len(h), 64)]
n = int(w[1], 16)
print("\n".join(str(int(w[2+2*i], 16)) for i in range(n)))
' "$1"; }

order_id_words() { python3 -c '
import sys
h = sys.argv[1][2:]
w = [h[i:i+64] for i in range(0, len(h), 64)]
n = int(w[1], 16)
print("\n".join(str(int(w[3+2*i], 16)) for i in range(n)))
' "$1"; }

# Structural comparison against the golden: prints two words,
# "<matches_golden> <differs_only_in_order_ids>".
golden_cmp() { python3 -c '
import sys
def words(h):
    h = h[2:] if h[:2] == "0x" else h
    return [h[i:i+64] for i in range(0, len(h), 64)]
a, b = words(sys.argv[1].lower()), words(sys.argv[2].lower())
match = a == b
only_ids = False
if not match and len(a) == len(b) >= 2 and a[0] == b[0] and a[1] == b[1]:
    n = int(a[1], 16)
    # offset and length already agree; every SUCCESS word must agree too, and at
    # least one orderId word must be the thing that differs.
    only_ids = all(a[2+2*i] == b[2+2*i] for i in range(n))
print(("true" if match else "false"), ("true" if only_ids else "false"))
' "$1" "$2"; }

CASES_TMP=$(mktemp)
GOLD_TMP=$(mktemp)
# "$OUT.tmp" is in the trap so a fault or a SIGINT during the emit leaves no half-written
# sibling behind for a later run to trip over. $OUT itself is never in the trap: the whole
# point is that the tracked artifact is not touched until the emit has been validated.
trap 'rm -f "$CASES_TMP" "$GOLD_TMP" "$OUT.tmp"' EXIT

# --- The capture itself ----------------------------------------------------
run_case() {   # name n word...
  local name="$1" n="$2"; shift 2
  local arr cd ret bytes
  if [ "$#" -eq 0 ]; then arr="[]"; else arr="[$(IFS=,; echo "$*")]"; fi
  cd=$(cast calldata "$SIG" "$n" "$arr")
  if ! ret=$(cast call "$MGR" "$cd" --rpc-url "$RPC" 2>/dev/null); then
    echo "CAPTURE FAIL: eth_call reverted for case $name against $MGR at $RPC" >&2
    echo "              a REVERT is not a skip -- the batch path skips invalid tuples," >&2
    echo "              so this is a guard rejection or a dead address, not a business result" >&2
    exit 1
  fi
  ret=$(printf '%s' "$ret" | tr 'A-Z' 'a-z')
  bytes=$(( (${#ret} - 2) / 2 ))
  echo "  $name  n=$n  ${bytes} bytes"
  jq -n --arg name "$name" --argjson n "$n" --arg calldata "$cd" \
        --arg returndata "$ret" --argjson rb "$bytes" \
    '{name: $name, n: $n, calldata: $calldata, returndata: $returndata, returndata_bytes: $rb}' \
    >> "$CASES_TMP"
}

W_VALID=$(input_word 12345 600 77 1000000000000000000)
# skew = 65535 is the ONLY input a client can pass that the contract rejects:
# spread_tick_assimetry_is_complete accepts [1, 65534]. It exercises best-effort
# skip semantics on a LIVE chain rather than in a mock.
W_BAD_SKEW=$(input_word 999 7 65535 1000000000000000000)
# targetVega exactly ONE ABOVE the u96 bound. This is the V2-specific silent-skip
# case: it comes back (false, 0), INDISTINGUISHABLE from a business rejection,
# which is the whole reason the client-side in_range 96 guard exists.
W_DIRTY_VEGA=$(input_word 12345 600 77 "$(python3 -c 'print(2**96)')")

echo "capturing against $MGR (chainId $CHAIN, block $BLOCK)"
run_case N0_empty             0
run_case N1_success           1 "$W_VALID"
run_case N2_success_then_fail 2 "$W_VALID" "$W_BAD_SKEW"
run_case N1_dirty_vega        1 "$W_DIRTY_VEGA"

CASES=$(jq -s '.' "$CASES_TMP")
get() { jq -r --arg n "$1" '.[] | select(.name==$n) | '"$2" <<<"$CASES"; }

# --- Self-check 1: N=0 is EXACTLY 64 bytes ---------------------------------
# Asserted as a NUMBER. Comparing against a pasted byte string would put a
# 64-hex literal in a .sh file, which sc3_literal_purge exists to forbid.
N0_BYTES=$(get N0_empty .returndata_bytes)
if [ "$N0_BYTES" != "64" ]; then
  echo "CAPTURE FAIL: N0_empty returned $N0_BYTES bytes, not 64" >&2
  echo "              an empty batch returns the offset word plus a zero length -- never 0, never 32" >&2
  exit 1
fi

# --- Self-check 2: every case is 64 + 64*n bytes ---------------------------
while read -r nm n b; do
  want=$(( 64 + 64 * n ))
  if [ "$b" != "$want" ]; then
    echo "CAPTURE FAIL: $nm returned $b bytes, expected $want (= 64 + 64*$n)" >&2
    exit 1
  fi
done < <(jq -r '.[] | "\(.name) \(.n) \(.returndata_bytes)"' <<<"$CASES")

# --- Self-check 3: the rejection cases really rejected ---------------------
# A capture in which every element succeeded means the input words were built
# wrong (the stale-V1-comment trap). Silently all-success is worse than nothing.
for nm in N2_success_then_fail N1_dirty_vega; do
  fails=$(success_words "$(get "$nm" .returndata)" | grep -c '^0$' || true)
  if [ "$fails" -lt 1 ]; then
    echo "CAPTURE FAIL: $nm has no (false, 0) element -- every tuple was ACCEPTED" >&2
    echo "              the input words were built from the stale V1 layout, or validation moved" >&2
    exit 1
  fi
done

# --- Self-check 4: N1_success is exactly one (true, id>0) ------------------
S1=$(success_words "$(get N1_success .returndata)")
I1=$(order_id_words "$(get N1_success .returndata)")
if [ "$(wc -l <<<"$S1")" != "1" ] || [ "$S1" != "1" ]; then
  echo "CAPTURE FAIL: N1_success success words are '$S1', expected exactly one canonical 1" >&2
  exit 1
fi
if [ "$I1" -le 0 ]; then
  echo "CAPTURE FAIL: N1_success orderId is $I1, expected a positive assigned id" >&2
  exit 1
fi

# --- The golden diff -------------------------------------------------------
# The first three names match the v4.0 fixture's names[0..2] positionally, so
# they are compared against expected[0..2]. The golden's bytes came from
# cast abi-encode (alloy), an encoder outside this repo, and its INPUTS are the
# pre-V2 three-field ones -- which is fine, because the return encoding is a
# function of (success, id) only and targetVega never enters it.
GOLDEN_NAMES=(N0_empty N1_success N2_success_then_fail)
for idx in 0 1 2; do
  nm=${GOLDEN_NAMES[$idx]}
  exp=$(jq -r --argjson i "$idx" '.expected[$i]' "$GOLDEN" | tr 'A-Z' 'a-z')
  got=$(get "$nm" .returndata)
  read -r matched only_ids < <(golden_cmp "$got" "$exp")
  if [ "$nm" = "N0_empty" ] && [ "$matched" != "true" ]; then
    echo "CAPTURE FAIL: N0_empty does not match the external-encoder golden." >&2
    echo "              live   : $got" >&2
    echo "              golden : $exp" >&2
    echo "              This is a hard failure, not a finding: the empty encoding has no order ids in it." >&2
    exit 1
  fi
  if [ "$matched" != "true" ] && [ "$only_ids" != "true" ]; then
    echo "CAPTURE FAIL: $nm disagrees with the golden beyond the order-id words." >&2
    echo "              live   : $got" >&2
    echo "              golden : $exp" >&2
    echo "              Order ids may legitimately differ (the golden was taken against a fresh" >&2
    echo "              registry). Anything else differing is a RETURN-ENCODING disagreement and a" >&2
    echo "              FINDING to report. Do not adjust the golden: test/ is another track's." >&2
    exit 1
  fi
  jq -n --arg name "$nm" --argjson m "$matched" --argjson o "$only_ids" \
    '{name: $name, matches_golden: $m, differs_only_in_order_ids: $o}' >> "$GOLD_TMP"
done

GOLDEN_DIFF=$(jq -s 'map({key: .name, value: {matches_golden, differs_only_in_order_ids}})
                     | from_entries
                     | . + {_note: "Compared positionally against expected[0..2] of test/pos_spec/fixtures/vol_order_return_golden.json, whose bytes came from cast abi-encode (alloy), an encoder outside this repo. N1_dirty_vega has NO golden counterpart -- the fixture predates V2 -- so it is captured as new evidence, not as a diff target. differs_only_in_order_ids is true when the offset word, the length word and every success word agree and only orderId words differ, which is legitimate when the golden was taken against a fresher registry than this rig."}' \
              "$GOLD_TMP")

# --- Emit the artifact -----------------------------------------------------
# WRITE BESIDE, VALIDATE, THEN RENAME. This used to be `jq -n ... > "$OUT"` against
# offchain/rig/batch-return-capture.json, which `git ls-files` confirms is TRACKED.
# The shell creates and truncates the redirect target BEFORE jq runs, so any jq fault
# -- or a SIGINT between the two -- left committed evidence at zero bytes. That is the
# rule README.md:248 already states ("Never regenerate with `generator ... > committed-
# file`"), that 4f02866 fixed elsewhere, and that the sibling generate-pins.sh:411-423
# already follows. This one writer was missed.
#
# MEASURED with a jq shim faulting only on this emit (matched on the unique _scope_limit
# key, every other jq call real): offchain/rig/batch-return-capture.json went 4497 bytes
# -> 0 bytes, sha 64f81425 -> e3b0c442 (the sha256 of nothing).
jq -n \
  --arg     generatedAt "$GENERATED_AT" \
  --argjson chainId     "$CHAIN" \
  --arg     manager     "$MGR" \
  --argjson blockNumber "$BLOCK" \
  --arg     signature   "$SIG" \
  --argjson cases       "$CASES" \
  --argjson goldenDiff  "$GOLDEN_DIFF" \
  '{
     generatedAt: $generatedAt,
     chainId: $chainId,
     manager: $manager,
     blockNumber: $blockNumber,
     signature: $signature,
     _provenance: "Every returndata string below was read off a live chain by offchain/rig/capture-batch-return.sh, against the rig stood up by offchain/rig/deploy-rig.sh. The manager address was read from offchain/rig/rig-manifest.json (gitignored) and is copied here because a machine that never stood the rig up has nothing else to check this artifact against. Nothing here was transcribed from a hand-off document.",
     _scope_limit: "These are eth_call results. No state was changed, no transaction was sent and no receipt exists, so the order ids below are the ids the calls WOULD have assigned against the orderCount live at blockNumber -- not ids that exist on chain. Re-running against a rig whose orderCount has advanced legitimately shifts the orderId words and nothing else.",
     _golden_diff: $goldenDiff,
     cases: $cases
   }' > "$OUT.tmp"

# Re-check the emitted document BEFORE it replaces the tracked one, on the same reasoning
# as generate-pins.sh:411-423: jq can exit 0 having written less than intended, and an
# artifact that parses is not the same as an artifact that carries what it claims to.
#
# The assertion is a SET, not a count. A count floor is satisfied by a count-preserving
# swap -- rename `cases` to `casesXX` and a "7 top-level keys" floor sails through while
# every downstream rpin05_* check reads a missing field. The expected case names are
# DERIVED from $CASES (the thing actually captured), never typed here, so adding a case
# needs no edit and losing or renaming one is caught.
[ -s "$OUT.tmp" ] || { echo "CAPTURE FAIL: the emit produced an EMPTY $OUT.tmp; $OUT NOT replaced" >&2; exit 1; }
jq -e . "$OUT.tmp" >/dev/null || { echo "CAPTURE FAIL: $OUT.tmp is not valid JSON; $OUT NOT replaced" >&2; exit 1; }

want_keys='["_golden_diff","_provenance","_scope_limit","blockNumber","cases","chainId","generatedAt","manager","signature"]'
got_keys=$(jq -cS 'keys' "$OUT.tmp")
if [ "$got_keys" != "$want_keys" ]; then
  echo "CAPTURE FAIL: the emitted document's top-level key SET is wrong. $OUT NOT replaced." >&2
  echo "       want: $want_keys" >&2
  echo "       got : $got_keys" >&2
  echo "       A missing or RENAMED field reads as absent to every rpin05_* check, which is" >&2
  echo "       silent. This is a set and not a count on purpose: a rename preserves the count." >&2
  exit 1
fi

want_cases=$(jq -cS '[.[].name] | sort' <<<"$CASES")
got_cases=$(jq -cS '[.cases[].name] | sort' "$OUT.tmp")
if [ "$got_cases" != "$want_cases" ] || [ "$want_cases" = "[]" ]; then
  echo "CAPTURE FAIL: the emitted cases do not match the cases this run captured." >&2
  echo "       captured: $want_cases" >&2
  echo "       emitted : $got_cases" >&2
  echo "       (an EMPTY set is a failure too -- zero cases is an unrun capture, not a clean one)" >&2
  exit 1
fi

mv "$OUT.tmp" "$OUT"

echo "wrote $OUT  ($(jq -r '.cases | length' "$OUT") cases, chainId $CHAIN, block $BLOCK)"
