---
phase: 21-v2-abi-re-pin-targetvega-generation
plan: 01
subsystem: api
tags: [haskell, cabal, abi, keccak, bit-packing, volorder, plank, tdd]

# Dependency graph
requires:
  - phase: 20-deploy-rig-source-of-truth-import
    provides: "rig-pins.json (generated selectors/topic0s), Rig.Manifest loader, the single offchain/test/Main.hs runner with signatures_in / signature_for / selector_of / verify_pin, and the sc3_literal_purge gate"
provides:
  - "VolOrder carrying target_vega (raw Uniswap L units, [1, 2^96-1])"
  - "V2-only encode_create_order (4-arg create_order); the V1 3-arg path deleted from offchain/"
  - "pack_vol_order_input packing the V2 batch input word skew@0..15 | strike@16..103 | width@104..127 | targetVega@128..223 with bits >= 224 zero by construction and four attributable per-field rejections"
  - "unpack_vol_order_storage reading the 248-bit V2 storage word with targetVega at 152..247"
  - "Six new named checks (rpin01/02/03) plus the rpin_v2_layout_behavior anchor in the single cabal test runner: 44 -> 51"
  - "Test-only pack_storage_reference: an independent second implementation of VolOrder.plk pack_vol_order"
  - "Shared test fixtures rpin_base_*, vega_corners, mask_of, module_tick_spacing for plans 21-03/21-04"
affects: [21-03 event re-pin, 21-04 targetVega generation, 21-05 phase verification, 22 drivers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Selector proven by three-way agreement: keccak of the signature PARSED OUT OF the interface .plk, the bytes the encoder actually emits, and the generated pin"
    - "Attributable per-field rejection: each field's error message must name that field and NO OTHER field"
    - "Test-only reference packer as the independent second implementation, so a round-trip is not self-consistency"
    - "Constructed corner corpus kept separate from drawn values (a Double draw has 53 significand bits against a ~70-bit band)"

key-files:
  created: []
  modified:
    - offchain/lib/VolOrder/Types.hs
    - offchain/lib/VolOrder/Encoding.hs
    - offchain/lib/VolOrder/Decode.hs
    - offchain/app/Sample.hs
    - offchain/test/Main.hs
    - cfmm-replicationPlank-rpc-api.cabal

key-decisions:
  - "cabal build -j all does NOT build the test suite -- it exited 0 with a test suite that would not compile. The warning/build gate must be cabal build --enable-tests -j all."
  - "module_tick_spacing was introduced one task earlier than planned (task 2, not task 3) because the task-1 behaviour anchor already needed the storage-word constant."
  - "The plan's own verification step 6 (grep -rn 'uint88,uint24,uint16)' offchain/ produces NO output) was violated by a comment the plan itself asked for; the comment was reworded rather than the criterion relaxed."
  - "The demo (cabal run) was deliberately NOT executed: it writes live orders to the shared rig that plan 21-02 was capturing batch-return data from in the same wave."

patterns-established:
  - "Three-way selector derivation (interface file / encoder output / generated pin) replaces any transcribed selector in a test"
  - "Rejection attributability is asserted positively AND negatively: the message names its own field and none of the other three"
  - "Every mutation demo records the HONEST NEGATIVE -- which checks stayed green -- alongside the RED"

requirements-completed: [RPIN-01, RPIN-02, RPIN-03]

# Metrics
duration: 11min
completed: 2026-08-01
---

# Phase 21 Plan 01: V2 ABI Re-Pin (Client-Side Word Layouts) Summary

**`VolOrder` gained `target_vega` and all three client-side wire layouts moved to V2 — the 4-arg `create_order` calldata, the `skew|strike|width|targetVega` batch input word, and the 248-bit storage word with `targetVega` at 152..247 — with the V1 3-arg path deleted outright and six new named checks taking the suite from 44 to 51.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-08-01T18:27:01Z
- **Completed:** 2026-08-01T18:38:16Z
- **Tasks:** 3 (task 1 executed TDD, so 4 commits)
- **Files modified:** 6

## Accomplishments

- **The live bug named in the objective is fixed at its source.** `encode_create_order` built the retired 3-arg `create_order` against a module that dispatches only the 4-arg V2 selector, so the demo order reverted (recorded in 20-05-SUMMARY.md). The encoder now emits the 4-arg form and its selector is proven equal, in the test, to a keccak recomputed from the signature string parsed out of `src/interfaces/pos_spec/VolOrderManagerInterface.plk` **and** to the generated pin in `rig-pins.json`. Nothing is transcribed.
- **The V2 input word is pinned at the bit level from the EXECUTABLE code**, `src/modules/pos_spec/VolOrderManagerMod.plk:229-235`, not from that same file's stale V1 comment block (see Finding F1 below). `width` is interior at 104..127; `targetVega` is the unmasked top field at 128..223; bits >= 224 are zero by construction over a six-corner corpus that includes `2^96-1`.
- **Rejection is attributable, and that is asserted both ways.** Each of the four fields, perturbed one at a time from a valid order, is rejected by a message that names it *and does not name any of the other three*. `target_vega = 2^96-1` is proven ACCEPTED — the bound is exclusive on the high side, exactly as `target_vega_fits_packed` enforces it on-chain.
- **The 248-bit storage word round-trips against an independent second implementation.** `pack_storage_reference` is a test-only mirror of `src/types/pos_spec/VolOrder.plk:50-56`; checking the library's unpacker against the library's own packer would have proven only self-consistency.
- **An order is exhibited whose input word differs from its storage word**, with the disagreement pinned at the specific bits that distinguish the layouts (104..127 holds `width = 600` on the input side and `tickSpacing = 20` on the storage side; `targetVega` sits at 128 vs 152), plus the assertion that feeding the INPUT word to the STORAGE unpacker does *not* reproduce the order.
- **Two mutants applied, two REDs observed, both restored sha256-identical**, each with its honest negative recorded (below).

## Task Commits

1. **Task 1 (TDD RED): V2 layout behaviour contract as a failing check** — `f54819e` (test)
2. **Task 1 (TDD GREEN): V2 record, encoder, input word, storage unpack; V1 deleted** — `e2a13b6` (feat)
3. **Task 2: RPIN-01 + RPIN-02 checks** — `dcc3e63` (test)
4. **Task 3: RPIN-03 checks** — `6edacb1` (test)

No REFACTOR commit was needed; the GREEN implementation was already the final shape.

## Files Created/Modified

- `offchain/lib/VolOrder/Types.hs` — `VolOrder` gains `target_vega`, with a haddock note fixing its dimension as **raw liquidity (Uniswap `L`)**, not X96, not WAD, not collateral, and stating why a unit slip here is invisible on-chain (any u96 stores fine).
- `offchain/lib/VolOrder/Encoding.hs` — V2-only `encode_create_order`; a fourth `in_range 96` guard in `pack_vol_order_input`; header comment rewritten to the V2 layout with the strict-REVERTS / batch-SKIPS asymmetry stated explicitly and the stale V1 comment block named as untrustworthy.
- `offchain/lib/VolOrder/Decode.hs` — `unpack_vol_order_storage` reads `target_vega` from bits 152..247; header comment carries the full 248-bit table and reports the `TICK_SPACING = 20` vs pool `tickSpacing = 10` discrepancy.
- `offchain/app/Sample.hs` — both construction sites supply a real `target_vega = 10^18` (raw L), never a placeholder.
- `offchain/test/Main.hs` — six new named checks plus the `rpin_v2_layout_behavior` anchor, the shared `rpin_base_*` fixtures, `vega_corners`, `mask_of`, `module_tick_spacing`, and the test-only `pack_storage_reference`.
- `cfmm-replicationPlank-rpc-api.cabal` — test suite gains `memory-hexstring`, `web3-ethereum`, `mwc-random` (all already project dependencies; no new package enters the build plan).

## Requested Evidence

### 1. The `-Wall` warning list after the record change

**The plan asked for "the exact warning list from the first `cabal build` after the record change (evidence that `-Wmissing-fields` found every construction site)". That list was EMPTY, and reporting an empty list as evidence would be reporting nothing.** The record change and every construction site were edited in the same pass, so no warning ever surfaced. So the claim was measured directly instead: `target_vega` was removed from `sample_order` and the build re-run:

```
offchain/app/Sample.hs:31:3: warning: [GHC-20125] [-Wmissing-fields]
    • Fields of ‘VolOrder’ not initialised:
        target_vega :: web3-ethereum-1.1.0.1:Network.Ethereum.Api.Types.Quantity
    • In the expression:
        VolOrder {vol_target = 1000, range_width = 60, skew = 500}
      In an equation for ‘sample_order’:
          sample_order
```

Sample.hs was then restored. The complete set of `VolOrder` construction sites is **three** — `offchain/lib/VolOrder/Decode.hs:131`, `offchain/app/Sample.hs:31` and `:46` — confirmed by grep, not by the absence of warnings.

### 2. OBSERVED RED — the `shiftL 120` mutant (task 2)

With `(vega \`shiftL\` 128)` changed to `(vega \`shiftL\` 120)` in `pack_vol_order_input`, `cabal test` exits **1 at 47/49**:

```
FAIL rpin_v2_layout_behavior: V2 input word: packed 1329227995784915872915976506042535578254368351580651597, expected 340282366920938463463386776877530402458254368351580651597
PASS rpin01_encoder_selector_is_recomputed
PASS rpin01_encoder_argument_order
FAIL rpin02_input_word_layout: corner min: targetVega@128..223 reads back as 0, expected 1
PASS rpin02_field_rejections
47/49 checks passed
2 FAILED: rpin02_input_word_layout, rpin_v2_layout_behavior
```

`git checkout offchain/lib/VolOrder/Encoding.hs` restored the file sha256-identical (`bce4ae02…28adf1c8` before and after) and the suite returned to 51/51.

**HONEST NEGATIVE.** Exactly the two checks expected to stay green did:

- `rpin01_encoder_argument_order` **stayed GREEN** — correctly. It exercises `encode_create_order`, which goes through `cast calldata` and never touches `pack_vol_order_input`. The two encoders are genuinely independent paths, which is why a batch-word mutation cannot redden the calldata check. It also means **the calldata checks provide zero coverage of the input-word layout**, and vice versa; both are load-bearing.
- `rpin02_field_rejections` **stayed GREEN** — correctly. It asserts *bounds*, not *positions*; a misplaced field is still in range. A suite of rejection checks alone would have accepted the mutant.
- `rpin_v2_layout_behavior` reddened as well, expected: it asserts the whole word.

The discrimination claim is therefore specific and true: this mutant is caught by the layout checks *and only by the layout checks*.

### 3. OBSERVED RED — the `shiftR 144` mutant (task 3, extra)

Not required by the plan, but the storage side deserved its own kill. With `unpack_vol_order_storage`'s `shiftR 152` changed to `shiftR 144`, `cabal test` exits **1 at 49/51**:

```
FAIL rpin_v2_layout_behavior: the 248-bit storage word did not round-trip: got VolOrder {vol_target = 12345, range_width = 600, skew = 77, target_vega = 256000000000000000000}, expected VolOrder {... target_vega = 1000000000000000000}
FAIL rpin03_storage_round_trip: corner min: target_vega read back as 256, expected 1
49/51 checks passed
```

Restored sha256-identical (`7fc9e077…c01def8e`).

**HONEST NEGATIVE, and this one is a real limitation worth carrying forward:** `rpin03_input_word_is_not_storage_word` **stayed GREEN** under the wrong storage offset. Its final assertion is an INEQUALITY (`unpack_vol_order_storage input /= rpin_base_order`), and a *wrong* offset satisfies an inequality just as well as the right one. That check discriminates **conflation of the two layouts**, not **correctness of either**. It must never be cited as evidence that the storage offset is right; only `rpin03_storage_round_trip` establishes that.

### 4. Check count

`cabal test`: **44 -> 51**, exit 0, `SC-3 and SC-4 OK`. Seven new checks — the six the plan names plus the `rpin_v2_layout_behavior` anchor introduced as the TDD RED.

## Findings Reported (not fixed — other tracks' files)

**F1 CONFIRMED — the stale V1 comment block is exactly as the plan described it.** `src/modules/pos_spec/VolOrderManagerMod.plk:177-188` still reads *"INPUT WORD: skew@0..15 | strike@16..103 | width@104..127 | bits >=128 MUST BE ZERO"* and *"width IS DELIBERATELY UNMASKED. It is the TOP field"*. The V2 code at lines 229-235 of that same file masks `width` (`@evm_shr(104, word) & 0xFFFFFF`) and reads `targetVega` unmasked from bit 128 (`@evm_shr(128, word)`). Both sentences are false of V2. **The file belongs to the plank track (`ul2inqpl`) and was NOT edited.** The Haskell-side comment in `Encoding.hs` now names the block as not-to-be-trusted so the next reader does not repeat the trap. Consequence if trusted: a V1 packer passes every offchain test and is silently SKIPPED on the batch path — a `(false, 0)` indistinguishable from an ordinary business rejection.

**F2 — `TICK_SPACING = 20` (module) vs `tickSpacing = 10` (deployed pool).** `src/types/pos_spec/VolOrder.plk` writes the module constant 20 into storage bits 104..127, while `offchain/rig/rig-manifest.json` `.pool.tickSpacing` is 10. Reported in both `Decode.hs` and `offchain/test/Main.hs`, and the test expectation is deliberately written against the MODULE CONSTANT so a change to it reddens rather than passing silently. Not resolved — resolving it means editing another track's module.

## Decisions Made

- **`cabal build -j all` is not a build gate for this suite.** It exited **0** while the test suite would not compile — cabal only builds test components when tests are enabled. Every build and warning gate here was run as `cabal build --enable-tests -j all`. Both forms are recorded as exit 0 / zero warnings in the final verification, but only the second is meaningful.
- **`module_tick_spacing` landed in task 2 rather than task 3.** The task-1 behaviour anchor asserts the storage round-trip and so needed the constant before task 3 existed; introducing it with the shared fixtures avoided a literal `20` that task 3 would then have had to replace.
- **`cabal run` was deliberately not executed.** It writes live orders to the shared anvil rig, and plan 21-02 was capturing batch-return data from that same rig in this wave. The demo's V2 correctness is established statically (the encoder's selector equals the module's dispatched selector, proven three ways) and its live confirmation belongs to a plan that owns the rig state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The plan's build/warning gate does not build the test suite**
- **Found during:** Task 1 (TDD RED)
- **Issue:** `cabal build -j all` — the plan's verification command in all three tasks — exited **0** against a test suite containing `Not in scope: record field 'target_vega'`. It builds `lib` and `exe` only. Used as written, a test suite that does not compile would have been reported as a passing warning gate.
- **Fix:** Every build and warning gate was run as `cabal build --enable-tests -j all`. The plan's original form was also run at final verification and is recorded, so nothing is lost.
- **Files modified:** none (procedural)
- **Verification:** `cabal build -j all` = exit 0 / 0 warnings **while the test suite was broken**; `cabal build --enable-tests -j all` = exit 1 naming the two errors. Both measured.
- **Committed in:** n/a

**2. [Rule 1 - Bug] The plan's own prescribed comment violated the plan's own verification step 6**
- **Found during:** Task 1
- **Issue:** The plan asked for a comment saying the V1 3-arg path is deleted, and its verification step 6 requires `grep -rn 'uint88,uint24,uint16)' offchain/` to produce **no output**. Written naturally, the comment spells out the V1 signature and matches that grep. This is the same self-contradicting-criterion pattern the plan itself warns about (Phase 20 shipped a prescribed comment that could not satisfy its own criterion — the seventh instance).
- **Fix:** The comment now says "the V1 3-arg `create_order` path is DELETED" without repeating the signature string, and states *why* it is not repeated. The criterion was satisfied, not relaxed.
- **Files modified:** `offchain/lib/VolOrder/Encoding.hs`
- **Verification:** `grep -rn 'uint88,uint24,uint16)' offchain/` exits 1 with no output.
- **Committed in:** `e2a13b6`

**3. [Rule 2 - Missing Critical] Added a storage-side mutation demo the plan did not ask for**
- **Found during:** Task 3
- **Issue:** The plan mandates an observed RED for the input-word layout (`shiftL 120`) but none for the storage layout. RPIN-03 would have shipped with its discrimination unmeasured — and the measurement turned out to matter, because it revealed that `rpin03_input_word_is_not_storage_word` does **not** discriminate a wrong storage offset.
- **Fix:** Applied `shiftR 152` -> `shiftR 144`, observed the RED, restored sha256-identical, recorded both the kill and the honest negative (Requested Evidence section 3).
- **Files modified:** none (mutant restored byte-identical)
- **Verification:** sha256 `7fc9e077…c01def8e` before and after; suite back to 51/51.
- **Committed in:** n/a (evidence only)

---

**Total deviations:** 3 auto-fixed (1 blocking, 1 bug, 1 missing critical)
**Impact on plan:** No scope creep. Deviation 1 is the difference between a real gate and a vacuous one; deviation 2 resolves a self-contradiction in the plan text without weakening the criterion; deviation 3 is evidence the plan should have required and whose result changed what can honestly be claimed about RPIN-03.

## Issues Encountered

- **The TDD RED for task 1 is a compile-level RED, not an assertion-level one, and that is not a shortcut — it is the only RED available.** Every V1-vs-V2 difference in the *existing* three fields is nil: V1 already places `skew` at 0, `strike` at 16, `width` at 104 in the input word, and `skew`/`strike`/`width` at 0/16/128 in the storage word. The layouts differ **only** in `target_vega`, so no assertion expressible against the 3-field record can fail. The RED is therefore `Not in scope: record field 'target_vega'` — the absence of the field *is* the defect. The assertion-level RED for the same code is the `shiftL 120` mutant in Requested Evidence section 2.

## User Setup Required

None — no external service configuration required. `cast` (foundry) must be on `PATH`, as it already was for the Phase 20 checks.

## Next Phase Readiness

- **Ready for 21-03 (event re-pin, RPIN-04/05/06).** `VolOrder`'s derived `Eq` now covers `target_vega`, so `verify_mined_order`'s whole-record comparison picks up the new field for free — the mechanism 21-03 relies on. The event decoder in `Decode.hs` was deliberately left at its v1 shape; that is 21-03's work.
- **Ready for 21-04 (targetVega generation).** `mwc-random` is already in the test suite's `build-depends`, and `vega_corners` is deliberately documented as a corpus *separate* from drawn values so 21-04 does not conflate the two.
- **`Sample.hs`'s `sample_orders` currently carries a constant `target_vega = 10^18`** and is explicitly marked as the value 21-04 replaces with draws. `sample_order` stays fixed as the single-call demo's anchor.
- **Carry-forward for whoever runs the demo:** the V2 fix is proven statically but has **not** been confirmed against the live rig by this plan (see Decisions). A `cabal run` against a rig the runner owns is the remaining confirmation.
- **Two findings are open against the plank track:** F1 (stale V1 comment block) and F2 (`TICK_SPACING = 20` vs pool `tickSpacing = 10`). Neither blocks this phase.

## Self-Check: PASSED

- All six modified files exist on disk.
- All four task commits exist in `git log`: `f54819e`, `e2a13b6`, `dcc3e63`, `6edacb1`.
- The "three construction sites" claim verified by grep: `Decode.hs:131`, `Sample.hs:31`, `Sample.hs:46`.
- F1 verified still present in the plank track's file: `grep -c 'bits >=128 MUST BE ZERO' src/modules/pos_spec/VolOrderManagerMod.plk` = 1.
- F2 verified: `offchain/rig/rig-manifest.json` `.pool.tickSpacing` = 10 against the module's 20.
- Final gates: `cabal build --enable-tests -j all` exit 0 / 0 warnings; `cabal test` exit 0 at 51/51 with `SC-3 and SC-4 OK`; purge grep no output; `generate-pins.sh` re-run leaves `rig-pins.json` byte-identical; `git status --porcelain src/ test/ Makefile foundry.toml remappings.txt foundry-scripts/` empty.

---
*Phase: 21-v2-abi-re-pin-targetvega-generation*
*Completed: 2026-08-01*
