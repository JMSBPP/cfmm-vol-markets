---
phase: 21-v2-abi-re-pin-targetvega-generation
plan: 05
subsystem: testing
tags: [haskell, abi, golden-fixture, provenance, chain-independence, cross-track, anvil, jq]

# Dependency graph
requires:
  - phase: 21-v2-abi-re-pin-targetvega-generation
    plan: 02
    provides: "offchain/rig/batch-return-capture.json -- four live eth_call returndata strings with chainId/manager/blockNumber provenance and a recorded _golden_diff"
  - phase: 21-v2-abi-re-pin-targetvega-generation
    plan: 03
    provides: "the V2 E1 decoder, the sc4_no_retired_value_is_live padding hole, and a rig left standing"
  - phase: 21-v2-abi-re-pin-targetvega-generation
    plan: 04
    provides: "draw_target_vega / VegaDraw, whose drawn values this plan mined end to end"
  - phase: 19-differential-mutation-consumer-fixture
    provides: "test/pos_spec/fixtures/vol_order_return_golden.json -- the alloy-produced external-encoder golden"
provides:
  - "Four rpin05_ checks asserting the LIVE captured bytes against the external-encoder golden inside a suite that opens no socket"
  - "offchain/rig/peer-haskell-bytes.json -- the shipped Haskell decoder's output for all FIVE golden cases, offered to the Solidity-testing track"
  - "offchain/rig/gen-peer-bytes.hs -- the re-runnable generator for that artifact"
  - "21-CROSS-TRACK-FINDINGS.md -- F1, F2, F3 and F4 filed against their owners"
  - "sc4_no_retired_value_is_live compares NUMERICALLY -- the zero-padding hole 21-03 measured is closed"
  - "First end-to-end proof that the V2 re-pin works: cabal run's demo order MINES, and drawn targetVegas are accepted on chain"
affects: [22 drivers, plank track, Solidity-testing track]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A chain-independent suite asserts against a provenance-bearing COMMITTED artifact, never a live call -- the artifact's freshness is what the suite checks instead"
    - "An artifact's own self-report (_golden_diff) is cross-checked against its payload, so a hand-edited judgement contradicts its own bytes"
    - "A check that verifies strictness reads the raw words itself rather than going through the decoder whose strictness it is checking"
    - "Every plan-predicted claim is MEASURED before it is written down -- two of this plan's inherited claims were false"

key-files:
  created:
    - offchain/rig/peer-haskell-bytes.json
    - offchain/rig/gen-peer-bytes.hs
    - .planning/phases/21-v2-abi-re-pin-targetvega-generation/21-CROSS-TRACK-FINDINGS.md
  modified:
    - offchain/test/Main.hs
    - docs/superpowers/verification/2026-07-22-stochastic-order-gen-verification.md
    - .planning/phases/21-v2-abi-re-pin-targetvega-generation/deferred-items.md

key-decisions:
  - "[21-05 REFUTED] The plan's instruction to record follow-up #5 as ADDRESSED is FALSE. verify_mined_order is unchanged and still discards tickSpacing and bits >= 248 before comparing. Recorded as PARTIALLY ADDRESSED with the production gap named."
  - "[21-05 REFUTED] 21-02's carry-forward D2 named blockNumber as a discriminating provenance field. MEASURED false: three from-scratch deploys of the same rig gave heights 9, 11 and 10. The freshness check asserts chainId + manager only."
  - "[21-05 MEASURED] The freshness check does NOT catch a module CHANGE: manager is a CREATE address, bytecode-independent, and reproduced identically across three deploys. Recorded as F4 with a code-hash fix proposed, not applied."
  - "[21-05 MEASURED] decode_create_orders_result ignores the outer offset word -- follow-up #2's leniency demonstrated for the first time. The suite catches it; the decoder does not."
  - "[21-05 CLOSED] sc4_no_retired_value_is_live now compares numerically; under 21-03's identical injection the suite reports 4 failures where 21-03 recorded 3."
  - "cabal build -j all confirmed VACUOUS for the FOURTH consecutive plan; every gate ran as cabal build --enable-tests -j all."

patterns-established:
  - "When a plan tells you to write a conclusion into a durable document, verify the conclusion first -- 21-05 was told to write ADDRESSED and the truth was PARTIALLY ADDRESSED"
  - "State which staleness a freshness check catches and which it does not; 'a stale capture reddens' is three different claims"

requirements-completed: [RPIN-05]

# Metrics
duration: 19min
completed: 2026-08-01
---

# Phase 21 Plan 05: RPIN-05 Live-Capture Assertions and Phase Close Summary

**The V2 `(bool,uint256)[]` batch return captured off a live chain is now asserted byte-for-byte against an encoder outside this repo — including the 64-byte `N = 0` case — inside a `cabal test` that opens no socket and was PROVEN green with anvil stopped; and the phase gate closes with `cabal run`'s demo order MINING for the first time since 20-05 recorded it reverting, carrying an `ORDER_CREATED` log with `target_vega` and two chain-accepted drawn vegas.**

## Performance

- **Duration:** 19 min (19:23:56Z → 19:43:10Z)
- **Tasks:** 2 planned + 1 deferred-item closure
- **Files modified:** 6 (3 created, 3 modified)

## Task Commits

1. **Task 1: RPIN-05 assertions over the committed capture** — `e0f8cca` (test)
2. **Task 2: peer bytes artifact + cross-track findings + verification-record edits** — `38f4503` (feat)
3. **Extra: close the `sc4_no_retired_value_is_live` zero-padding hole** — `c3f2ee3` (fix)

---

## Requested verbatim record

### 1. OBSERVED RED — flipped capture byte

The plan asked which byte was flipped and which of two outcomes followed. **Both variants were run**, because the plan's own text says the answer depends on which byte, and measuring both is what turns that into evidence.

**FLIP A — last hex character of WORD 1, the ELEMENT-COUNT word (`…0000` → `…0001`).** Applied with `jq`, never typed.

```
PASS rpin05_capture_is_present_and_fresh
FAIL rpin05_live_bytes_match_the_external_golden: N0_empty: the LIVE bytes and the external-encoder golden differ.
FAIL rpin05_capture_decodes_through_the_shipped_decoder: N0_empty: the SHIPPED decode_create_orders_result REJECTED bytes captured from the live module -- create_orders result length mismatch: expected 128 bytes for count 1, got 64
PASS rpin05_no_canonical_bool_violation

63/65 checks passed
2 FAILED: rpin05_capture_decodes_through_the_shipped_decoder, rpin05_live_bytes_match_the_external_golden
```
exit **1**.

**FLIP B — last hex character of WORD 0, the OUTER OFFSET word (`0x20` → `0x21`).**

```
PASS rpin05_capture_is_present_and_fresh
FAIL rpin05_live_bytes_match_the_external_golden: N0_empty: the LIVE bytes and the external-encoder golden differ.
PASS rpin05_capture_decodes_through_the_shipped_decoder
PASS rpin05_no_canonical_bool_violation

64/65 checks passed
1 FAILED: rpin05_live_bytes_match_the_external_golden
```
exit **1**.

**HONEST NEGATIVE, and it produced a real finding.** The plan predicted that a length/offset byte "should break decoding". **Half of that is false.** A *length* byte does (flip A). An *offset* byte does **not** (flip B): `decode_create_orders_result` reads `count` from word 1 and the payload from word 2 onward, and **never looks at word 0 at all**. So the offset can be arbitrarily corrupt and the decoder returns a confident, wrong-by-construction `Right []`.

That is not a new idea — it is this workstream's own tracked follow-up **#2** ("check the offset word against `0x20`"), which had never been demonstrated. It has now been measured, and the verification record was annotated in place. `rpin05_capture_is_present_and_fresh` stayed GREEN under both flips, correctly: provenance is untouched by a bytes edit. `rpin05_no_canonical_bool_violation` also stayed green under both, correctly: for `N = 0` there are no success words to read.

`git checkout` restored the capture, sha256 **`64f81425374b5a9e2f41b0c13d7f7da45bac7d34da2b9c5fa5d364ad680c1ca3` before and after** both flips, `git diff --exit-code` clean, suite back to 65/65.

### 2. OBSERVED RED — altered `.manager`

One character changed with `jq` (`…aa3` → `…aa4`):

```
FAIL rpin05_capture_is_present_and_fresh: the capture names manager 0x5fbdb2315678afecb367f032d93f642f64180aa4 but the live manifest names 0x5fbdb2315678afecb367f032d93f642f64180aa3 -- the committed capture describes a DIFFERENT deployment and its bytes prove nothing about the module now on chain. Re-take it: bash offchain/rig/capture-batch-return.sh
PASS rpin05_live_bytes_match_the_external_golden
PASS rpin05_capture_decodes_through_the_shipped_decoder
PASS rpin05_no_canonical_bool_violation

64/65 checks passed
1 FAILED: rpin05_capture_is_present_and_fresh
```
exit **1**. Restored sha256-identical.

**HONEST NEGATIVE — the predicted one, and it is the GOOD outcome.** The plan expected the two bytes checks to stay green, and they did, "since the captured bytes themselves are unchanged". They are therefore **not entangled** with the freshness check: provenance and payload fail independently, which is what makes each one's green meaningful.

### 3. CHAIN-INDEPENDENCE — `cabal test` with anvil DOWN

```
$ bash offchain/rig/deploy-rig.sh --stop
rig stopped: nothing is listening on 8545          EXIT=0

$ pgrep anvil
(no output, exit 1)

$ cast block-number
Error: error sending request for url (http://localhost:8545/)

$ cabal test
PASS rpin05_capture_is_present_and_fresh
PASS rpin05_live_bytes_match_the_external_golden
PASS rpin05_capture_decodes_through_the_shipped_decoder
PASS rpin05_no_canonical_bool_violation

65/65 checks passed
SC-3 and SC-4 OK
                                                    EXIT=0

$ pgrep anvil          # still empty after the run
(no output, exit 1)
```

**The full suite passes with no chain in existence.** `grep -cE 'cast call|HttpProvider|8545' offchain/test/Main.hs` returns **0**. The rig was brought back up afterwards.

### 4. The phase gate, every command with its exit code

| # | command | exit | note |
|---|---|---|---|
| 1 | `bash offchain/rig/deploy-rig.sh` | **0** | anvil pid 366381 left running |
| 2 | `bash offchain/rig/verify-rig.sh` | **0** | `SC-2 OK: 7 contracts live, RealizedVolatilityMod seeded` |
| 3 | `bash offchain/rig/capture-batch-return.sh` | **0** | `wrote … (4 cases, chainId 31337, block 10)` |
| 4 | `bash offchain/rig/generate-pins.sh` | **0** | `selectors: 30  topics: 5  retired: 3` |
| 5 | `git diff --exit-code offchain/rig/rig-pins.json` | **0** | clean |
| 6 | `cabal build -j all` | **0** | the plan's form — recorded, but VACUOUS (see deviations) |
| 6b | `cabal build --enable-tests -j all` | **0** | the real gate; **0** warning lines |
| 7 | `cabal test` | **0** | 65/65, `SC-3 and SC-4 OK`, 4 `PASS rpin05_` |

**A by-product worth recording:** step 3 regenerated the capture, and its normalised form (`jq -S 'del(.generatedAt, .blockNumber)'`) hashes to **`786c9506f7a30acf284311f5022540198eaf78d3393d292272df59d7824c0cd7`** — **byte-identical to the sha256 21-02 recorded across its five runs**, now reproduced across a completely from-scratch redeploy with a new anvil process. The returndata is stable against rig rebuilds. Only `generatedAt` (18:32:22Z → 19:37:44Z) and `blockNumber` (9 → 10) moved, so the file was restored to HEAD rather than committing timestamp churn.

### 5. `cabal run` — the demo order MINES

20-05 recorded that the demo order **REVERTED** because `Encoding.hs` still built the retired 3-arg `create_order`. That is the exact defect Phase 21 exists to fix. Verbatim outcome:

```
tx      0xe505a6188c1e2a939f930af3fec2f084dfe6fd4ccc08ee1a4df422e96e3653eb
status  success
block   11
log     ORDER_CREATED
  order_id    1
  strike      1000
  width       60
  skew        500
  target_vega 1000000000000000000
price   WRITTEN
path    WRITTEN (5 observations)
batch   tx 0x5f306da6c4fe7365a6cb801635c3a1ea9cbc50dd2cc9cc2847cc87b656e24cf0
        status success
        2 succeeded, 0 failed (of 2)
  order 1 OK      id 2
  order 2 OK      id 3
```
`cabal run` exit **0**.

Answering the plan's two questions directly: **the receipt status IS success (1)**, and **an `ORDER_CREATED` log with a `target_vega` line DID appear**. There is no finding to report here — the defect 20-05 named is fixed.

**BEYOND THE PLAN, and it closes 21-04's carry-forward.** The `batch` line is `run_order_gen`, which calls `attach_vega gen (vega_draw config)` → `draw_target_vega` (`offchain/lib/StochasticOrderGen/Rpc.hs:48,56-64`). So those two orders carried **DRAWN** targetVegas. Read back out of chain storage (`getOrderPacked`, bits 152..247):

```
order 1: target_vega = 1000000000000000000     (1.0000e18)    <- sample_order's constant
order 2: target_vega = 6393999551897785344     (6.3940e18)    <- DRAWN
order 3: target_vega = 935459305769090809856   (935.4593e18)  <- DRAWN
```

Two distinct drawn values, two decades apart, both inside the configured `[1e18, 1e21]` band, both accepted on chain and both read back correctly. 21-04's carry-forward said "the generator's drawn orders have never been sent to a chain". **They have now.**

### 6. Check count

`cabal test`: **61 → 65**, exit 0, `SC-3 and SC-4 OK`, zero `-Wall` warnings.

---

## What the RPIN-05 checks DO and DO NOT establish

Stated plainly, because this is the phase's final plan and the summary is the last word before goal verification.

**They DO establish:**

- The four returndata strings captured off the live Phase-20 module by 21-02 are byte-for-byte equal to `expected[0..2]` in a fixture produced by `cast abi-encode` (alloy) — an encoder outside this repo and outside this language — with `N0_empty` additionally asserted to be **exactly 64 bytes**.
- The comparison is word-by-word for the non-empty cases, tolerating a difference **only** in order-id words; anything else fails naming the index and both words.
- The artifact's own `_golden_diff` self-report agrees with what its bytes actually say, so a hand-edited judgement contradicts its own payload.
- All four captured cases decode through the **shipped** `decode_create_orders_result` to the tuple lists the module's semantics require, with element counts matching each case's `n`.
- Every success word, read straight out of the bytes rather than through the decoder, is canonically 0 or 1; and `returndata_bytes` is tied to the `64 + 64*n` layout formula.
- The suite remains chain-independent — proven with anvil stopped and `pgrep anvil` empty.
- All FIVE golden cases (including the two the live rig never captured) decode through the Haskell decoder and agree with the golden's declared element counts.

**They DO NOT establish:**

- **That the capture was taken from the CURRENTLY RUNNING process.** See F4. The manager is a `CREATE` address — bytecode-independent, and measured identical across three from-scratch deploys — so a module CHANGE plus redeploy would keep the address and a stale capture would still pass. The fix (pin the deployed code hash) is proposed in the findings doc and deliberately not applied here, because it changes 21-02's artifact schema.
- **That `decode_create_orders_result` validates the return header.** It does not read the offset word at all (measured, flip B). Follow-up #2 remains open.
- **Anything about the INPUT side.** No Haskell **encoder** is exercised against an external oracle anywhere in this phase, so the canonical-array-offset requirement on calldata remains unexercised from this side. This is stated in the artifact's own `_scope`.
- **That the captured order ids exist on chain.** They are `eth_call` results against `orderCount = 0` — hypothetical. The checks assert `id > 0`, never `id == 1`, precisely so they test decoding rather than rig freshness.

## Findings

Filed in full in **`.planning/phases/21-v2-abi-re-pin-targetvega-generation/21-CROSS-TRACK-FINDINGS.md`** (218+ lines).

- **F1 — plank track.** Stale V1 comment block at `src/modules/pos_spec/VolOrderManagerMod.plk:177-188`, quoted verbatim, contradicting that same file's V2 code at 221-235. Documentation defect, not behaviour; the danger is that a V1 packer built from it is **silently skipped** by the batch path. **Not edited.**
- **F2 — plank track.** `TICK_SPACING = 20` vs the rig pool's `tickSpacing = 10`. *Correction to the plan:* the constant is at `src/lib/pos_spec/VolOrderValidationLib.plk:33`, **not** `src/types/pos_spec/VolOrder.plk` as the plan's reading list said. **Not edited.**
- **F3 — this workstream.** Follow-up #7 OBSOLETE (its premise is false; the module emits logs at `VolEventsLib.plk:47-54`), #5 corrected to **PARTIALLY ADDRESSED**, #2 annotated with a new measurement. All three superseded in place; no original text deleted.
- **F4 (new) — this workstream.** What the freshness assertion does not catch, with the code-hash fix proposed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `cabal build -j all` is not a build gate — a FOURTH confirmation**

- **Found during:** both tasks (inherited from 21-01, 21-03, 21-04)
- **Issue:** the plan's verify command in task 1 and task 2 builds only `lib` and `exe`.
- **Fix:** every gate ran as `cabal build --enable-tests -j all`. The plan's form was also run at the phase gate (exit 0) and is recorded, but only the corrected form is meaningful.
- **Committed in:** n/a (procedural)

**2. [Rule 1 - Bug] The plan instructed a FALSE conclusion into a durable document**

- **Found during:** Task 2, Part B/C
- **Issue:** the plan directs recording follow-up **#5** as "ADDRESSED by plan 21-01's storage round-trip check". #5 is about **`verify_mined_order`**, which is unchanged (`offchain/lib/VolOrder/Rpc.hs:94-104`): it compares the 4-field record produced by `unpack_vol_order_storage`, which discards bits 104..127 (tickSpacing) and 248..255 (junk) *before* the comparison. The exact drift #5 asks to catch is still not caught. Writing "ADDRESSED" would have retired a live gap in this workstream's own tracking document.
- **Fix:** annotated **PARTIALLY ADDRESSED**, naming what 21-01 genuinely delivered (test-side, against a reference-built word) and what remains open (the production verifier).
- **Verification:** `verify_mined_order` read directly and quoted in the findings doc.
- **Committed in:** `38f4503`

**3. [Rule 1 - Bug] A carry-forward provenance field, MEASURED unstable**

- **Found during:** Task 1
- **Issue:** 21-02's carry-forward D2 recommends "`blockNumber` / `manager` are the discriminating provenance fields". Three from-scratch deploys of the same rig during this plan produced chain heights **9, 11 and 10**. Asserting `blockNumber` would have reddened the suite after any ordinary redeploy.
- **Fix:** the freshness check asserts `chainId` + `manager` and deliberately not `blockNumber`; recorded in-file and as F4.
- **Committed in:** `e0f8cca`

**4. [Rule 2 - Missing Critical] The deferred `sc4_no_retired_value_is_live` hole closed, and MEASURED**

- **Found during:** after Task 2
- **Issue:** 21-03 measured that the one guard whose job is to stop a retired constant coming back **stayed GREEN while a retired value was live**, because it compared lowercased strings and the injected value was the left-padded form. Both 21-03 and 21-04 deferred it naming 21-05 as owner.
- **Fix:** compare numerically; a value that does not parse as hex now FAILS rather than being skipped.
- **Verification:** under 21-03's **identical** `jq` injection the suite reports **4 failures where 21-03 recorded 3**, the new one being `sc4_no_retired_value_is_live` naming which retired entry leaked. `rig-pins.json` sha256 `ecc8dcc3…1c8c845a` before and after; `generate-pins.sh` reproduces it byte-identically.
- **Committed in:** `c3f2ee3`

**5. [Rule 3 - Blocking] A generator was needed to satisfy "never hand-type bytes" reproducibly**

- **Found during:** Task 2, Part A
- **Issue:** the plan lists three files but requires the artifact be generated mechanically **and** the exact command recorded. A command that only exists in a summary is not re-runnable.
- **Fix:** added `offchain/rig/gen-peer-bytes.hs`, committed, run as `cabal exec -- runghc offchain/rig/gen-peer-bytes.hs | jq . > offchain/rig/peer-haskell-bytes.json`. Verified byte-identical on a second run. It contains no hex literals and does not redden `sc3_literal_purge`.
- **Committed in:** `38f4503`

---

**Total deviations:** 5 auto-fixed (2 blocking, 2 bugs in the plan's or a carry-forward's own claims, 1 missing-critical closure).
**Impact on plan:** No scope creep. Deviation 2 is the material one — the plan asked for a false statement to be written into a tracking document that outlives the phase.

## Issues Encountered

- **The plan's predicted mutant discrimination was again only half right** (flip B), for the third consecutive wave. The pattern now has four instances: an inequality survived a wrong offset (21-01), an inequality survived a destroyed field (21-03), a spread statistic survived the wrong draw law (21-04), and here a "should break decoding" prediction was false for the offset word. Each time the fix was to measure rather than argue.
- **`../plank/` cannot be `git status`-ed from this worktree** (it is a separate worktree, so git reports it as outside the repository). That is a structural guarantee rather than a gap: this session cannot edit it from here.

## Verification Results

| # | check | result |
|---|---|---|
| 1 | `cabal build --enable-tests -j all` exit 0, **0** warnings | PASS |
| 2 | `cabal test` exit 0, 65/65, `SC-3 and SC-4 OK`, 4 `PASS rpin05_` | PASS |
| 3 | anvil DOWN (`pgrep anvil` empty) + `cabal test` exit 0 | PASS |
| 4 | `generate-pins.sh` + `git diff --exit-code offchain/rig/rig-pins.json` | PASS (clean) |
| 5 | hex-literal purge over `offchain --include=*.hs --include=*.sh` | PASS (no output) |
| 6 | territory `src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt` | PASS (no output) |
| 7 | both observed REDs recorded verbatim before any green reported | PASS |
| — | `jq -r '.cases \| length' peer-haskell-bytes.json` == 5, all `haskell_decode` non-null | PASS |
| — | `_offer_to` names the track and `peer_haskell_bytes`; `_scope` names RETURN-only and the unexercised ENCODER | PASS |
| — | findings doc >= 40 lines with all five required strings | PASS (218+ lines) |
| — | verification record: `OBSOLETE` present, original #7 text preserved | PASS |
| — | `grep -cE 'cast call\|HttpProvider\|8545' offchain/test/Main.hs` == 0 | PASS |

## Rig state left behind

**anvil is RUNNING** — pid **366381**, block **12**, `orderCount = 3`, manager `0x5fbd…aa3`, `verify-rig.sh` re-run green (`SC-2 OK: 7 contracts live`).

The rig is **no longer at 21-02's `orderCount = 0`**: the phase-gate `cabal run` mined three real orders (one single-call, two batched with drawn vegas). That was intended — the gate's whole point was to exercise the mining path — and **nothing in `cabal test` depends on it**, because the committed capture carries its own provenance and the checks never call a chain. Stop the rig with `bash offchain/rig/deploy-rig.sh --stop`.

## User Setup Required

None. `cast` (foundry) and `jq` must be on `PATH`, as they already were.

## Next Phase Readiness

- **RPIN-05 is satisfied and marked complete.** With RPIN-01..04, RPIN-06 (21-01/02/03) and VEGA-01 (21-04), **all seven Phase 21 requirements are done**.
- **Open items carried out of the phase**, all recorded in `deferred-items.md` or the findings doc:
  1. **F1 / F2** — the plank track's, reported never edited.
  2. **Follow-up #2** — `decode_create_orders_result` does not validate the offset word. Now measured.
  3. **Follow-up #5** — `verify_mined_order` still compares the unpacked record, not the whole word.
  4. **F4** — the freshness check cannot see a module change behind an unchanged `CREATE` address; code-hash pinning proposed.
  5. **21-04's F3** — a second `VegaDraw` constructor must supply its own parameter validation.
  6. **`web3-crypto`** remains an unused library `build-depends`.
- **For Phase 22 (DRIV-02):** `verify_mined_order` is now exercised end to end for the first time — `cabal run` mined three orders and read every one back, including two drawn vegas. What is still unasserted is a *failing* readback; the happy path is now covered on a real chain.

## Self-Check: PASSED

- All three created files exist on disk: `offchain/rig/peer-haskell-bytes.json`, `offchain/rig/gen-peer-bytes.hs`, `21-CROSS-TRACK-FINDINGS.md`.
- All three modified files exist and carry the described edits.
- All three task commits resolve in `git log`: `e0f8cca`, `38f4503`, `c3f2ee3`.
- Final gates re-run after every restore: `cabal build --enable-tests -j all` exit 0 / **0** warnings; `cabal test` exit 0 at **65/65**.
- Mutated artifacts restored byte-identical: capture sha256 `64f81425…680c1ca3`, pins sha256 `ecc8dcc3…1c8c845a`.
- Territory clean at every checkpoint. (`lib/forge-std`, `offchain/spec/types.md` and the untracked root files were already modified at session start and were not touched.)

---
*Phase: 21-v2-abi-re-pin-targetvega-generation*
*Completed: 2026-08-01*
