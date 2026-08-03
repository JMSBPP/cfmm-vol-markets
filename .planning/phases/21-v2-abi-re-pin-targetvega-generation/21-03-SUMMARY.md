---
phase: 21-v2-abi-re-pin-targetvega-generation
plan: 03
subsystem: api
tags: [haskell, abi, events, keccak, decoder, volorder, plank, tdd, mutation]

# Dependency graph
requires:
  - phase: 21-v2-abi-re-pin-targetvega-generation
    plan: 01
    provides: "VolOrder carrying target_vega, V2 encode_create_order / pack_vol_order_input / unpack_vol_order_storage, the rpin_base_* fixtures, vega_corners, mask_of, module_tick_spacing and the test-only pack_storage_reference"
  - phase: 20-deploy-rig-source-of-truth-import
    provides: "rig-pins.json (generated topic0s + the retired block), signatures_in / signature_for / topic0_of, the sc3_literal_purge gate, deploy-rig.sh / verify-rig.sh"
provides:
  - "V2 OrderCreatedEvent: orderId (indexed topic 1), orderStrike, orderRangeWidth, orderSkew, orderTargetVega -- orderOwner and orderCreatedAt DELETED"
  - "decode_order_created matching EXACTLY two topics and four data words, with a >= 128-byte data-length guard"
  - "report_order_created printing the V2 field set"
  - "synthetic_log / word32be / hexstring_of / filler_address -- a PURE, chain-independent log builder for the test suite"
  - "Seven new named checks (rpin_e1 anchor + four rpin04 + two rpin06): 51 -> 58"
  - "FIRST EVER on-chain OBSERVATION of an E1 VolOrderCreated v2 log, captured non-destructively via anvil evm_snapshot/evm_revert"
affects: [21-04, 21-05, 22 drivers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Assertion-level TDD RED for a decoder rewrite: assert only shape predicates (isJust/isNothing) that are expressible against the OLD record, so the RED is a failing assertion rather than a compile error"
    - "Negative checks paired with a positive control: every rejection is proven to come from the intended comparison by decoding the same fixture successfully under the value it was built from"
    - "Non-destructive live capture: evm_snapshot -> real tx -> read logs -> evm_revert, leaving block height and orderCount byte-identical for a downstream plan"

key-files:
  created: []
  modified:
    - offchain/lib/VolOrder/Decode.hs
    - offchain/lib/VolOrder/Report.hs
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "The plan's `cabal build -j all` gate is VACUOUS (21-01's finding, re-confirmed); every gate here was run as `cabal build --enable-tests -j all`."
  - "The TDD RED is ASSERTION-level, not compile-level: asserting only isJust/isNothing on log shapes is expressible against the v1 record, so the RED is a real failing assertion (unlike 21-01's, which could only be a compile error)."
  - "`time` REMOVED from the library build-depends -- MEASURED dead with -Wunused-packages after this plan deleted the only Data.Time usage. `web3-crypto` (library) and `mwc-random` (test) are ALSO unused but PRE-EXISTING / owed to 21-04; recorded, not removed."
  - "The `rpin06_perturbed_target_vega_fails_readback` baseline assertion is the SOLE discriminator of the target_vega=0 mutant -- MEASURED by neutralising it and observing the rest of the check pass."
  - "A real E1 v2 log was captured live via evm_snapshot/evm_revert so plan 21-05's rig-freshness dependency (block 9, orderCount 0) survives byte-identical."

patterns-established:
  - "A rejection check must carry its own positive control, or a merely-malformed fixture produces the same green"
  - "An inequality-based assertion never establishes correctness of the thing it is unequal about -- assert the unperturbed baseline FIRST and treat that assertion as the load-bearing one"
  - "Mutation evidence is incomplete without a second-order measurement of WHICH assertion inside the surviving check did the killing"

requirements-completed: [RPIN-04, RPIN-06]

# Metrics
duration: 15min
completed: 2026-08-01
---

# Phase 21 Plan 03: E1 v2 Event Re-Pin and targetVega Readback Summary

**`decode_order_created` was rewritten from the v1 three-topic/five-word shape to the real V2 shape — two topics, four data words, `orderId` from the indexed topic — and the rewrite is confirmed against the FIRST E1 v2 log ever observed on chain, while `targetVega`'s participation in the readback comparison is established by an observed RED whose sole discriminating assertion was itself measured.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-08-01T18:43:38Z
- **Completed:** 2026-08-01T18:59:10Z
- **Tasks:** 3 (task 1 executed TDD, so 4 commits)
- **Files modified:** 4

## Task Commits

1. **Task 1 (TDD RED): failing check for the E1 v2 log shape** — `90791e0` (test)
2. **Task 1 (TDD GREEN): V2 decoder + report; owner/timestamp deleted** — `c3b6391` (feat)
3. **Task 2: RPIN-04 checks** — `8e18fb1` (test)
4. **Task 3: RPIN-06 checks** — `fc8c1cd` (test)

No REFACTOR commit was needed.

---

## Requested Evidence

### 1. OBSERVED RED — the TDD RED (task 1), assertion-level

The plan's premise is that RPIN-04 is *not* a constant swap. That was measured before any code changed. `rpin_e1_v2_decode_behavior` was added and run against the **shipped v1 decoder**, exit **1 at 51/52**:

```
FAIL rpin_e1_v2_decode_behavior: the E1 v2 log shape (2 topics, 4 data words -- @evm_log2 over a 128-byte buffer) did not decode. A decoder that returns Nothing here reports every real VolOrderCreated log as "unknown" and never says so.
```

**This is an ASSERTION-level RED, unlike 21-01's, and deliberately so.** 21-01 recorded that its RED could only be a compile error (`Not in scope: record field 'target_vega'`) because no assertion expressible against the 3-field record could fail. Here the failing property — *does a two-topic/four-word log decode at all* — is expressible against the **old** record (`isJust` / `isNothing` name no fields), so the RED is a genuine failing assertion against compiling code. That is the stronger form and it was available, so it was used.

### 2. The `-Wall` warning list from deleting `orderOwner` / `orderCreatedAt`

**The plan asked for this list. It was EMPTY, and an empty list reported as evidence is evidence of nothing** — the same situation 21-01 hit and handled the same way. The record, the decoder and the single consumer (`Report.hs`) were edited in one pass, so no warning ever surfaced. The `-Wall` gate *did* do the work the plan predicted, just silently: `Data.Time.Clock`, `Data.Time.Clock.POSIX` and `fromBytes` were removed from `Decode.hs`'s imports as part of the same edit and the build is clean at zero warnings.

What was measured instead is stronger and is reported in section 6: the `time` package is now provably dead in the library, established with `-Wunused-packages` rather than inferred from the absence of a warning.

### 3. OBSERVED RED — the stale-pin demo (task 2)

`.topics.VolOrderCreated.topic0` was set **mechanically with `jq`** (never typed) to the left-padded 32-byte form of `retired.topic_order_created_stale`:

```
0x00000000000000000000000000000000000000000000000000000000a8892769
```

`cabal test` exits **1 at 53/56**. Verbatim:

```
FAIL sc4_cast_agreement: cross-encoder disagreement:
      VolOrderCreated: cast keccak=0x18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6 haskell=0x18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6 pinned=0x00000000000000000000000000000000000000000000000000000000a8892769

FAIL rpin04_topic0_is_recomputed: the generated pin and the recomputed topic0 disagree -- either the pin file or src/interfaces/pos_spec/VolOrderManagerInterface.plk is stale
      signature parsed from the file : VolOrderCreated(uint256,uint88,uint24,uint16,uint96)
      recomputed (keccak256)         : 0x18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6
      pinned in offchain/rig/rig-pins.json  : 0x00000000000000000000000000000000000000000000000000000000a8892769

FAIL sc4_pin_topic0_VolOrderCreated: recomputed value does not match the pin

53/56 checks passed
3 FAILED: rpin04_topic0_is_recomputed, sc4_cast_agreement, sc4_pin_topic0_VolOrderCreated
```

Note the shape of the evidence: in both `sc4_cast_agreement` and `rpin04_topic0_is_recomputed` the **recomputed value is correct and the pin is wrong**, with `cast keccak` and the Haskell encoder agreeing independently. Restored with `git checkout`: sha256 `ecc8dcc3…1c8c845a` **before and after**, `git diff --exit-code` clean, suite back to **58/58**, and `bash offchain/rig/generate-pins.sh` reproduces the file **byte-identically** (same sha256).

#### HONEST NEGATIVE — and this one is a real, previously unrecorded hole

**`sc4_no_retired_value_is_live` STAYED GREEN while a retired value was, in fact, live.** That check exists precisely to stop a retired constant coming back, and it did not fire. Cause: it compares pin values as **lowercased strings**, and the injected live value was the 66-character left-padded form while the retired entry is the 10-character `0xa8892769`. Same number, different string.

Consequence: the retired-value guard can be defeated by zero-padding — which is exactly the form a topic0 takes on the wire. **Not fixed here:** it is Phase 20's check, the defect is pre-existing rather than introduced by this plan, and 21-03's scope is RPIN-04/06. Logged to `deferred-items.md` with the fix (compare numerically, skipping the non-hex `_note` key). Candidate owner: 21-05.

Also green, and *correctly* so: `rpin04_positive_v2_decode`, `rpin04_v1_shape_is_rejected`, `rpin04_retired_topic0s_are_rejected` and `rpin_e1_v2_decode_behavior` all recompute the topic0 from the interface file via `e1_topic0_from` and never read the pin. They are pin-independent **by design** and structurally cannot catch a stale pin; `rpin04_topic0_is_recomputed` is the only one of the five that can, and it did.

### 4. OBSERVED RED — the `target_vega = 0` mutant (task 3)

`unpack_vol_order_storage`'s `target_vega` line replaced with `target_vega = 0`. `cabal test` exits **1 at 55/58**. Verbatim:

```
FAIL rpin_v2_layout_behavior: the 248-bit storage word did not round-trip: got VolOrder {vol_target = 12345, range_width = 600, skew = 77, target_vega = 0}, expected VolOrder {vol_target = 12345, range_width = 600, skew = 77, target_vega = 1000000000000000000}
FAIL rpin03_storage_round_trip: corner min: target_vega read back as 0, expected 1
FAIL rpin06_perturbed_target_vega_fails_readback: the UNPERTURBED storage word does not round-trip, so the perturbation results below would pass for the wrong reason: got VolOrder {vol_target = 12345, range_width = 600, skew = 77, target_vega = 0}, expected VolOrder {vol_target = 12345, range_width = 600, skew = 77, target_vega = 1000000000000000000}

55/58 checks passed
3 FAILED: rpin03_storage_round_trip, rpin06_perturbed_target_vega_fails_readback, rpin_v2_layout_behavior
```

Restored with `git checkout`: `Decode.hs` sha256 **`1bf3ab5490e84d674aeb659d97af95893c36f30f85fbe8e0ba0efd69336bc63f` before and after**, `git diff --exit-code` clean, suite back to 58/58 at zero warnings.

#### HONEST NEGATIVE — the predicted one

`rpin06_target_vega_reaches_every_sender` **stayed GREEN**, exactly as the plan predicted. It exercises `pack_vol_order_input` and `encode_create_order` and never calls the unpacker. It is labelled **STRUCTURAL** in-file for this reason: it establishes that `target_vega` is *routed* to both senders, and establishes **nothing whatever** about any value being correct. It must never be cited as readback evidence.

#### HONEST NEGATIVE — the one that was MEASURED rather than assumed, and it matters

Wave-1 flagged that 21-01's `rpin03_input_word_is_not_storage_word` survived a wrong offset because its assertion is an inequality. `rpin06_perturbed_target_vega_fails_readback` is built around an inequality too, so the same doubt was **measured instead of argued**: with the mutant still applied, the check's *baseline* assertion was neutralised (`expect True`) and the suite re-run.

```
PASS rpin06_perturbed_target_vega_fails_readback
56/58 checks passed
2 FAILED: rpin03_storage_round_trip, rpin_v2_layout_behavior
```

**The check PASSES under a decoder that destroys the field entirely.** Every perturbation assertion is satisfied: `0 /= 10^18` makes the inequality true, the other three fields are untouched so the localisation assertions hold, and `target_vega` does differ between decoded and submitted. Only the **unperturbed baseline round-trip** assertion catches it.

So, stated plainly:

- **What `rpin06_perturbed_target_vega_fails_readback` DOES establish:** given that the unpacker round-trips correctly (asserted first), a storage word perturbed *only* within bits 152..247 — at both the low (152) and high (247) end — produces a record that fails the same whole-record `Eq` comparison `verify_mined_order` performs, and the resulting difference is confined to `target_vega`.
- **What it DOES NOT establish on its own:** that the unpacker reads the right bits. That is entirely carried by the first assertion, and by `rpin03_storage_round_trip`. The perturbation half is a *localisation* argument layered on top of a correctness fact it does not itself supply.

Main.hs was restored from a pre-mutation copy, sha256 `3e28889dbba700585c0b77907b9c0623e5ca4c17de074e188a1918aff8769aad` before and after.

### 5. FIRST OBSERVED E1 v2 LOG ON CHAIN — beyond plan scope, non-destructive

Wave-1 recorded that **no E1 v2 log had ever been observed**: 21-02 captured by `eth_call`, which emits no logs, so this plan's decode shape was derived from emitter source alone. With the rig standing and the V2 input word proven live, that gap was closed — **without disturbing the rig state plan 21-05 depends on**, by bracketing a real transaction in `evm_snapshot` / `evm_revert`.

One real `create_order(12345, 600, 77, 10^18)` transaction, status `0x1`, emitted **exactly one log**:

```json
{
  "address": "0x5fbdb2315678afecb367f032d93f642f64180aa3",
  "topics": [
    "0x18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6",
    "0x0000000000000000000000000000000000000000000000000000000000000001"
  ],
  "data": "0x0000...3039 0000...0258 0000...004d 0000...0de0b6b3a7640000"
}
```

Every structural claim this plan's decoder rests on, confirmed against a real log:

| property | source-derived claim | OBSERVED |
|---|---|---|
| topic count | 2 (`@evm_log2`) | **2** |
| data length | 128 bytes = 4 words | **128 bytes, 4 words** |
| topic 0 | the pinned topic0 | **identical to `rig-pins.json`** |
| topic 1 | `orderId`, indexed | **1** (first order) |
| data word 0 | strike | **12345** |
| data word 1 | width | **600** |
| data word 2 | skew | **77** |
| data word 3 | targetVega | **1000000000000000000** |

The four data words are the four submitted arguments in declared order, and `orderId` appears **only** in the topic — never in the payload — which is the exact property `rpin04_positive_v2_decode` asserts synthetically.

**Rig restored and verified:** `evm_revert` returned `true`, `cast block-number` back to **9**, `orderCount()` back to **0**, and `verify-rig.sh` re-run prints `SC-2 OK: 7 contracts live, RealizedVolatilityMod seeded` at exit 0. 21-05's freshness dependency (block 9) is intact.

**The test suite remains chain-independent**, as the plan requires. This observation is recorded here as evidence; not one assertion in `cabal test` touches a chain, and every RPIN-04 fixture is still built by `synthetic_log` from pure values.

### 6. Check count

`cabal test`: **51 -> 58**, exit 0, `SC-3 and SC-4 OK`, zero `-Wall` warnings. Seven new checks — the six the plan names plus the `rpin_e1_v2_decode_behavior` anchor introduced as the TDD RED.

---

## Files Created/Modified

- `offchain/lib/VolOrder/Decode.hs` — `OrderCreatedEvent` replaced outright (`orderOwner` / `orderCreatedAt` deleted; `orderId` / `orderTargetVega` added; `orderVolTarget` renamed `orderStrike`); `decode_order_created` matches exactly two topics, reads data words 0..3, and guards on `>= 128` bytes; header comment rewritten to the V2 truth, citing the emitter at `src/lib/events/VolEventsLib.plk:47-54` and stating the failure mode being fixed. The topic0-as-a-PARAMETER paragraph was kept — that reasoning is still load-bearing.
- `offchain/lib/VolOrder/Report.hs` — `report_order_created` prints `order_id / strike / width / skew / target_vega`, with a note that owner and timestamp are absent because they are **not in a v2 log at all**. `report_receipt` and its topic0 threading untouched.
- `offchain/test/Main.hs` — the pure log builder (`word32be`, `hexstring_of`, `filler_address`, `synthetic_log`), `e1_topic0_from`, `integer_of_hex_text`, `retired_value`, and seven new checks.
- `cfmm-replicationPlank-rpc-api.cabal` — `web3-solidity` added to the **test** deps (for the `Address` that `Change`'s non-optional `changeAddress` demands); `time` **removed** from the library deps.

## Decisions Made

- **`cabal build -j all` is not a build gate** — 21-01's finding, inherited by this plan's verify commands and applied throughout. Every build/warning gate here ran as `cabal build --enable-tests -j all`. The plan's original form was also run at final verification (exit 0) and is recorded, but only the corrected form is meaningful.
- **The TDD RED is assertion-level.** See Requested Evidence 1.
- **`time` removed, `web3-crypto` and `mwc-random` deliberately not.** `-Wunused-packages` names all three. `time` became dead *because of this plan* (its only user was the deleted `orderCreatedAt`), so removing it is in scope. `web3-crypto` (library) was already dead before this plan touched anything — pre-existing, out of scope per the scope boundary. `mwc-random` (test) is 21-04's incoming dependency and removing it would only force 21-04 to add it back. Both recorded in `deferred-items.md`.
- **The live log capture used snapshot/revert rather than being skipped or run destructively.** 21-01 declined to run `cabal run` because 21-02 was capturing from the shared rig; that constraint has expired, but 21-05's block-9 freshness dependency has not. Snapshot/revert satisfies both.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The plan's build/warning gate does not build the test suite**

- **Found during:** all three tasks (inherited from 21-01)
- **Issue:** `cabal build -j all` — the plan's verify command in every task — builds only `lib` and `exe`. Used as written it would report a passing warning gate over a test suite that might not compile.
- **Fix:** every gate run as `cabal build --enable-tests -j all`. The original form was also run at final verification and recorded (exit 0), so nothing is lost.
- **Files modified:** none (procedural)
- **Committed in:** n/a

**2. [Rule 1 - Bug] The plan's own acceptance grep did not match the natural implementation**

- **Found during:** Task 3
- **Issue:** the criterion requires `grep -q 'shiftL` 152'` and `grep -q 'shiftL` 247'`. The natural implementation iterates over bit *indices* (`[152, 247]`) and forms the mask once as ``1 `shiftL` bit``, so both greps fail while the check genuinely perturbs both ends of the field. This is the self-contradicting-criterion pattern the repo has now recorded eight times.
- **Fix:** the flip **masks** are written out at the call site (``1 `shiftL` 152`` / ``1 `shiftL` 247``) and `one` takes a mask instead of an index. The criterion is satisfied genuinely — both constants are legible in the source, which is what the criterion was reaching for — rather than relaxed.
- **Files modified:** `offchain/test/Main.hs`
- **Verification:** both greps exit 0; suite still 58/58.
- **Committed in:** `fc8c1cd`

**3. [Rule 2 - Missing Critical] Second-order measurement of which assertion kills the mutant**

- **Found during:** Task 3
- **Issue:** the plan requires an observed RED for the `target_vega = 0` mutant but not an account of *which* assertion inside the reddened check did the work. Given wave-1's explicit warning that an inequality-based assertion survived a wrong offset in 21-01, shipping RPIN-06 without that measurement would have repeated the same unmeasured claim.
- **Fix:** with the mutant applied, the baseline assertion was neutralised and the suite re-run; the check **passed**, establishing that the baseline is the sole discriminator. Recorded in Requested Evidence 4, and the summary states explicitly what the check does and does not establish.
- **Files modified:** none (both files restored sha256-identical)
- **Committed in:** n/a (evidence only)

**4. [Rule 2 - Missing Critical] Live E1 v2 log captured, non-destructively**

- **Found during:** after Task 3
- **Issue:** no E1 v2 log had ever been observed on chain; the decode shape rested entirely on emitter source. The orchestrator flagged the capture as high-value if cheap, but 21-05 depends on the rig sitting at block 9.
- **Fix:** `evm_snapshot` → one real `create_order` → read the receipt's log → `evm_revert`, then re-verified block height, `orderCount` and the SC-2 gate. Every structural claim confirmed (Requested Evidence 5).
- **Files modified:** none
- **Verification:** `evm_revert` = `true`, block 9, `orderCount` 0, `SC-2 OK: 7 contracts live`.
- **Committed in:** n/a (evidence only)

---

**Total deviations:** 4 auto-fixed (1 blocking, 1 bug in the plan's own criterion, 2 missing-critical evidence)
**Impact on plan:** No scope creep. Deviations 3 and 4 are evidence the plan should have required; deviation 3's result materially changed what can honestly be claimed about RPIN-06.

## Findings Reported (not fixed — other tracks' files, or out of scope)

**F1 STILL PRESENT — not re-confirmed by inspection here, and not needed.** `src/modules/pos_spec/VolOrderManagerMod.plk:177-188` was confirmed verbatim by both wave-1 executors. This plan took **no** layout from it: the event shape came from `src/lib/events/VolEventsLib.plk:47-54` and `src/interfaces/pos_spec/VolOrderManagerInterface.plk:32-39`, and the storage layout from 21-01's already-verified `pack_storage_reference`. The plank track's file was not edited.

**NEW — `sc4_no_retired_value_is_live` is defeated by zero-padding.** See Requested Evidence 3. Logged to `deferred-items.md`. This is the first time the check has been exercised against a retired value in a *different textual form*, and it failed to fire.

## Issues Encountered

- **The v1 decoder's failure mode is worth restating, because it is the reason RPIN-04 could not have been a constant swap.** Against a v2 log the shipped decoder did not decode *wrongly* — its three-element topic pattern simply did not match, so it returned `Nothing` and `report_log` printed the log as an anonymous "unknown" one. There is no wrong value to notice, no exception, no log line saying anything is amiss. Changing only the topic0 constant would have left that behaviour completely intact.

## User Setup Required

None. `cast` (foundry) must be on `PATH`, as it already was.

## Next Phase Readiness

- **Ready for 21-04 (targetVega generation).** `vega_corners`, `mwc-random` and the `rpin_base_*` fixtures are untouched and still available; `Sample.hs`'s constant `target_vega = 10^18` is still the value 21-04 replaces with draws.
- **Ready for 21-05 (phase verification).** The rig is **left running at block 9 with `orderCount = 0`**, verified after the snapshot/revert, so the freshness assertion 21-02 left it standing for is intact. Stop it with `bash offchain/rig/deploy-rig.sh --stop` when the phase closes.
- **Two items for 21-05 to consider:** the `sc4_no_retired_value_is_live` padding hole (fix is a numeric comparison), and the two remaining unused build-depends. Both are in `deferred-items.md`.
- **RPIN-05 remains unchecked**, as 21-02 decided: it needs `decode_create_orders_result` asserted against `offchain/rig/batch-return-capture.json`, which this plan did not do.
- **Carry-forward for Phase 22 (DRIV-02):** `verify_mined_order` is still confirmed only in reproduction, never against a live mined order. The live E1 capture here shows the transaction path works end to end, which lowers the risk, but it is not the same assertion.

## Self-Check: PASSED

- All four modified files exist on disk.
- All four task commits resolve in `git log`: `90791e0`, `c3b6391`, `8e18fb1`, `fc8c1cd`.
- Final gates re-run after every restore: `cabal build --enable-tests -j all` exit 0 / **0** warning lines; `cabal test` exit 0 at **58/58** with `SC-3 and SC-4 OK`.
- `grep -rn 'orderOwner\|orderCreatedAt' offchain/` — no output. `grep -rn 'Data.Time' offchain/lib/VolOrder/Decode.hs` — no output.
- Purge grep over `offchain --include='*.hs' --include='*.sh'` — no output.
- `bash offchain/rig/generate-pins.sh && git diff --exit-code offchain/rig/rig-pins.json` — clean; sha256 `ecc8dcc3…1c8c845a` unchanged across the whole plan.
- Both mutated files restored sha256-identical: `Decode.hs` `1bf3ab54…336bc63f`, `Main.hs` `3e28889d…f8769aad`.
- Territory clean: `git status --porcelain src/ test/ foundry-scripts/ Makefile foundry.toml remappings.txt` — no output. (`lib/forge-std` and `offchain/spec/types.md` were already modified at session start and were not touched.)

---
*Phase: 21-v2-abi-re-pin-targetvega-generation*
*Completed: 2026-08-01*
