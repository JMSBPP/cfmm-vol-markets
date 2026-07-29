---
phase: 16-type-packing-validation-foundation
plan: 01
subsystem: testing
tags: [plank, solidity, foundry, ffi, vol-order, validation, mutation-testing, bit-packing]

# Dependency graph
requires:
  - phase: 13-issuance-library-vegaissuancelib
    provides: "The pure-lib + FFI-harness pattern (VegaIssuanceLib.plk / VegaIssuanceKernelHarness.plk) transcribed here"
provides:
  - "src/lib/pos_spec/VolOrderValidationLib.plk — bool-returning validate_order core, reverting validate_order_strict wrapper, build_vol_order with TICK_SPACING pinned"
  - "The authored bound strike <= 2^88-1 (strike_fits_packed), closing the gap left by tick_volatility_is_complete"
  - "test/types/pos_spec/VolOrderValidationHarness.plk — 4-selector FFI entrypoint making the pure lib reachable over the ABI"
  - "test/types/pos_spec/VolOrderValidation.t.sol — 13 CALLED-green tests + the six-mutant battery record"
  - "make test-vol-order-validation"
affects: [17-interface-single-call-module, 18a-best-effort-batch, 18b-return-encoding, 19-differential-mutation-battery]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "bool-returning validation CORE + thin reverting WRAPPER, so strict and batch paths share one predicate by construction"
    - "Mutation applied to OUR file at the call site when the roadmap-named mutation site belongs to another track"
key-files:
  created:
    - src/lib/pos_spec/VolOrderValidationLib.plk
    - test/types/pos_spec/VolOrderValidationHarness.plk
    - test/types/pos_spec/VolOrderValidation.t.sol
  modified:
    - Makefile

key-decisions:
  - "validate_order is a bool CORE with validate_order_strict as a thin reverting wrapper — Phase 17 calls the wrapper, Phase 18a calls the core, making MCAL-04's 'same validation both paths' true by construction rather than by assertion"
  - "TICK_SPACING = 20 pinned inside build_vol_order (one place), because vol_range_width_is_complete ANDs tickSpacing > 0 — a zeroed field makes the composed validator identically FALSE and lets an all-reject validator pass a naive fuzz"
  - "MAX_STRIKE literal is byte-identical to pack_vol_order's 88-bit mask at VolOrder.plk:38; that identity is the point of the bound"
  - "M3 (skew comparison flip) applied at OUR call site by inlining the flipped predicate, not in SpreadTickAssimetry.plk, because this phase must never modify src/types/pos_spec/ — same falsification power, other track's tree byte-untouched"

patterns-established:
  - "Battery record lives at the foot of the test file with verbatim [FAIL] lines and the restored sha256, so downstream phases cite rather than repeat it"
  - "Natspec cannot contain a bare at-sign offset (`name@128`); layout offsets are spelled 'bits N' in docblocks and kept as at-signs only inside string literals"

requirements-completed: [VORD-02]

# Metrics
duration: 118min
completed: 2026-07-20
---

# Phase 16 Plan 01: Type Packing & Validation Foundation Summary

**Pure `validate_order` composing two existing pos_spec predicates verbatim plus a newly-authored `strike <= 2^88-1` bound, proven CALLED-green through a 4-selector FFI harness and gated by six observed-RED mutants.**

## Performance

- **Duration:** 118 min
- **Started:** 2026-07-20T14:27:51Z
- **Completed:** 2026-07-20T16:26:16Z
- **Tasks:** 3
- **Files modified:** 4 (3 created, 1 modified)

## Accomplishments

- **The shape Phases 17/18a depend on is pinned.** `validate_order` returns `bool`; `validate_order_strict` is a three-line `require` wrapper over it. The strict path reverts, the batch path can skip, and both provably run the same predicate because there is only one.
- **The missing bound is authored and demonstrably load-bearing.** `tick_volatility_is_complete` is only `vol > 0`. Without an upper bound, a strike of 2^88+7 passes validation and `pack_vol_order`'s 88-bit mask stores **7** — a silent value change, no revert, nothing observable on-chain. `test__unit__strikeBoundBlocksSilentMasking` witnesses the corruption and the rejection in the same test.
- **At least one tuple is ACCEPTED, and that fact is falsifiable.** Mutant M4 (`let res = false;`) reddens `test__unit__anchorValidTupleAccepted` on the string `"all-reject validator fails here"`. An all-reject validator satisfies every other criterion in this phase; this observation is the proof the suite can see it.
- **All six mutants killed, none equivalence-masked**, every kill carried by a non-fuzz `test__unit__*` assertion, every source restored sha256-identical.
- **No file under `src/types/pos_spec/` was modified** at any point, including transiently during the battery.

## Task Commits

1. **Task 1: Pure VolOrderValidationLib + FFI harness** — `2699546` (feat)
2. **Task 2: CALLED-green test suite + make target** — `42752b9` (test)
3. **Task 3: Mutation gate — six observed REDs** — `4edd11e` (test)

## Files Created/Modified

- `src/lib/pos_spec/VolOrderValidationLib.plk` — the pure surface: `TICK_SPACING`, `MAX_STRIKE`, `strike_fits_packed`, `build_vol_order`, `validate_order`, `validate_order_strict`
- `test/types/pos_spec/VolOrderValidationHarness.plk` — 4-selector `run{}` dispatch; unpack writes four whole words at 0/32/64/96
- `test/types/pos_spec/VolOrderValidation.t.sol` — 3 contracts, 13 tests, plus the battery record block
- `Makefile` — `test-vol-order-validation` target and `.PHONY` entry

## Carry-forward for Phases 17 and 18a

**Signatures (exact):**
```plank
const build_vol_order       = fn(strike: u256, width: u256, skew: u256) VolOrder;
const validate_order        = fn(self: VolOrder) bool;   // the CORE — 18a's batch calls this
const validate_order_strict = fn(self: VolOrder) void;   // reverts EMPTY — 17's create_order calls this
const strike_fits_packed    = fn(self: TickVolatility) bool;
const TICK_SPACING = 20;
const MAX_STRIKE   = 0xFFFFFFFFFFFFFFFFFFFFFF;  // 2^88 - 1
```
Argument order is create_order-native everywhere: **(strike, width, skew)**. Both phases MUST build orders through `build_vol_order` so `TICK_SPACING` stays pinned in exactly one place.

**Harness selectors (recomputed with `cast sig`; all four matched the plan's cross-checks exactly):**

| Signature | Selector | Calldata offsets |
|---|---|---|
| `validateOrder(uint256,uint256,uint256)` | `0x1b6f447e` | strike@4, width@36, skew@68 |
| `validateOrderStrict(uint256,uint256,uint256)` | `0x87a10138` | strike@4, width@36, skew@68 |
| `packVolOrder(uint256,uint256,uint256)` | `0x75b370cd` | strike@4, width@36, skew@68 |
| `unpackVolOrder(uint256)` | `0x729f096f` | packed@4; returns width/tickSpacing/strike/skew |

**Confirmed layout — the FULL 152-bit word is what gets stored:**
```
(width << 128) | (20 << 104) | (strike << 16) | skew
 width bits 128..151 | tickSpacing bits 104..127 | strike bits 16..103 | skew bits 0..15
```
Verified Solidity-side against an independently re-derived word across 512 constructed-corpus runs plus a fixed anchor, tolerance 0, with `tickSpacing == 20` round-tripping.

**Accept sets (as verified against the real predicates, not the requirement's earlier prose):**
- skew: **[1, 65534]** — 0 and 65535 rejected; **1 and 65534 are ACCEPTED and do NOT revert**
- width: [1, 0xffffff]
- strike: [1, 2^88-1]

**Measured new baselines:**
- `make compile-plank`: **12 ok, 0 failed, 0 skipped** (was 11; +1 for the new harness entrypoint)
- `make test`: **87 passed, 4 failed** (was 74 passed, 4 failed; +13 from this file). The 4 remain the pre-existing vol-type-track pos_spec harness failures — unchanged, unfiltered, not ours.
- `make test-vol-order-validation`: 13 passed, 0 failed, 0 skipped

**Mutation battery (Phase 19's MVER-02 can cite this rather than repeat it).** Pre-mutation and restored sha256 of the lib, identical for all six restorations: `5fe71f30e4820d230a6d15b30e440ae78a33875d0d9a66e60f4e0d7d73fe8f35`

| # | Mutant | Killed by (non-fuzz) | Verbatim FAIL |
|---|---|---|---|
| M1 | strike bound deleted | `test__unit__strikeBoundBlocksSilentMasking` | `[FAIL: strike >= 2^88 must be REJECTED: 1 != 0]` |
| M2 | `<=` → `<` | `test__unit__strikeMaxAcceptedAndRoundTripsExactly` | `[FAIL: strike 2^88-1 must be ACCEPTED: 0 != 1]` |
| M3 | both skew comparisons flipped | `test__unit__skewZeroRejected` + `test__unit__skew65535Rejected` | `[FAIL: skew 0 must be REJECTED: 1 != 0]`, `[FAIL: skew 65535 must be REJECTED: 1 != 0]` |
| M4 | all-reject sentinel | `test__unit__anchorValidTupleAccepted` | `[FAIL: anchor tuple must be ACCEPTED (all-reject validator fails here): 0 != 1]` |
| M5 | `TICK_SPACING = 0` | `test__unit__anchorValidTupleAccepted` + `test__unit__anchorRoundTrip` | `[FAIL: anchor layout word: 40833884030512615615605007035409039327231 != 40833884436160807688638415514354065047551]` |
| M6 | width conjunct dropped | `test__unit__widthZeroRejected` + `test__unit__widthAbove24BitsRejected` | `[FAIL: width 0 must be REJECTED: 1 != 0]` |

## Decisions Made

- **bool core + reverting wrapper** (the plan left this to discretion within a strong recommendation). Taken as recommended: it is the only shape under which MCAL-04's "strict and batch run the same validation" is true by construction.
- **M3 relocated to our call site.** The roadmap names the skew comparison flip, but that comparison lives in `SpreadTickAssimetry.plk:12`, which this phase may not touch. Inlining the flipped predicate inside `validate_order` has identical falsification power (it admits skew 0 and 65535) and leaves the other track's tree byte-untouched. Rationale recorded in the in-file battery block, as the plan required.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Natspec rejected the at-sign layout notation**
- **Found during:** Task 2 (test suite)
- **Issue:** The plan's docblock text `width@128..151 | tickSpacing@104..127 | ...` made solc fail compilation outright: `Error (6546): Documentation tag @128..151 not valid for functions.` The natspec parser reads a bare `@128` as an unknown doc tag. A first fix attempt reintroduced the same failure because my own explanatory sentence also contained `@128`.
- **Fix:** Spelled the offsets as `width bits 128..151 | ...` in the docblock, with a note on why. The at-sign form is retained where it is safe and load-bearing — inside the assertion string `"layout: width@128 | tickSpacing@104 | strike@16 | skew@0"` and in the `_expectedWord` expression, both of which the plan's acceptance greps check.
- **Files modified:** `test/types/pos_spec/VolOrderValidation.t.sol`
- **Verification:** `make test-vol-order-validation` compiles and passes 13/13; the required grep for `(width << 128) | (TICK_SPACING << 104) | (strike << 16) | skew` still exits 0.
- **Committed in:** `42752b9`

**2. [Rule 1 - Bug] Wrong digits in a battery arithmetic claim**
- **Found during:** Task 3 (battery record)
- **Issue:** While explaining M5's layout failure I wrote the difference between the two words as `405648192073033408479214945021440320` — a number I had produced without computing it.
- **Fix:** Computed it: the difference is exactly `20 << 104 = 405648192073033408478945025720320`. Corrected the comment and marked it verified.
- **Files modified:** `test/types/pos_spec/VolOrderValidation.t.sol`
- **Verification:** `python3 -c "print((40833884436160807688638415514354065047551-40833884030512615615605007035409039327231)==(20<<104))"` → `True`
- **Committed in:** `4edd11e`

### Plan-internal contradiction, resolved and reported (not auto-fixed)

**`grep -c 'wrap_spread_tick_assimetry' src/lib/pos_spec/VolOrderValidationLib.plk` returns 1, not 0.**

The plan's Task 1 acceptance criteria (and phase verification item 5) require this grep to return `0`. But the plan's own `<action>` block prescribes, verbatim, a header comment beginning `// NEVER call wrap_spread_tick_assimetry (SpreadTickAssimetry.plk:9): it is ...`. The prescribed source and the acceptance grep cannot both be satisfied while the warning names the function it warns about.

**Resolution:** kept the plan-prescribed warning (it is explicitly called load-bearing, and a reader grepping the repo for that identifier should find it), and verified the property the criterion actually exists to establish — that the buggy `<< 0xffff` wrapper is not on the validation path:

```
occurrences outside comment lines:
  src/lib/pos_spec/VolOrderValidationLib.plk: 0
  test/types/pos_spec/VolOrderValidationHarness.plk: 0
```

Two adjacent criteria had the same self-matching-prose shape (`grep -c 'vm.assume'` and `grep -c 'Dependency\[\]'`, each hit only by my own docblock text). Those two I resolved by rewording, since the identifiers carried no warning value there — both now return `0` as specified.

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug) + 1 plan contradiction reported.
**Impact on plan:** No scope change. The natspec fix was required to compile at all; the arithmetic fix corrected a fabricated number in documentation.

## Issues Encountered

- **M5 reddens a different assertion than the plan predicted.** The plan expected `test__unit__anchorRoundTrip` to fail on `"anchor tickSpacing == 20"`. It actually fails one assertion earlier, on `"anchor layout word"`, because `_expectedWord` composes the Solidity-side `TICK_SPACING` (20) into bits 104..127 while the mutated `pack` writes 0 there; Foundry stops at the first failing assertion, so the tickSpacing check is unreachable in that run. The mutant is still killed by `anchorRoundTrip` via the layout mechanism and by `anchorValidTupleAccepted` via satisfiability — both mechanisms the plan called for. Recorded as observed rather than as predicted.
- **No disagreement found between the pure lib and the pos_spec predicates.** The composed validator's accept sets match the source predicates exactly; nothing required stopping to report a counterexample.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **Phase 17 (single-call module) is unblocked.** It has the exact wrapper signature to call, the pinned `build_vol_order`, the confirmed 152-bit layout word to store, and a validated accept set to write module-level tests against.
- **Phase 18a (best-effort batch) is unblocked** on the validation question specifically: the non-reverting `validate_order` core exists, so an invalid tuple can be skipped without reverting the batch. Its other blocker is unchanged — `MAX_BATCH` and the return shape still await peer `mv15a18k` (PR #9).
- **Carried concern (not this phase's to fix):** `src/types/pos_spec/SpreadTickAssimetry.plk:69-71` writes `out_ptr`, `out_ptr +% 32`, `out_ptr +% 32` — the second field is overwritten and the third returned word is uninitialized malloc memory. This is one cause of the 4 known-red pos_spec tests and belongs to the vol-type track. This phase's harness deliberately does not reproduce that shape (offsets 0/32/64/96, all distinct).
- **Also carried:** `wrap_spread_tick_assimetry` (`SpreadTickAssimetry.plk:9`) is `rawSpread << 0xffff` and remains a live bug in that track. Phases 17/18a must keep building `SpreadTickAssimetry` struct literals via `build_vol_order` and never call it.

## Self-Check: PASSED

All 5 claimed files exist on disk; all 3 claimed commits (`2699546`, `42752b9`, `4edd11e`) exist in the log; the lib's sha256 on disk equals the `5fe71f30...` value cited throughout the battery record.

---
*Phase: 16-type-packing-validation-foundation*
*Completed: 2026-07-20*
