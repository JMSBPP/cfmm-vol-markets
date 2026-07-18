---
phase: 14-module-dispatch-storage-layout-state-readers
plan: 02
subsystem: testing
tags: [plank, evm, vault, keccak-slots, vm-load, mutation-gate, falsifiability, vega-exposure]

# Dependency graph
requires:
  - phase: 14-module-dispatch-storage-layout-state-readers
    plan: 01
    provides: VegaAccountMod.plk live deposit-only vault (4 keccak scalar slots, inert admissibility guard, ZERO arithmetic) + test/exposure/VegaAccount.t.sol (9 CALLED-green tests) — EXTENDED here, not re-created
provides:
  - test/exposure/VegaAccount.t.sol — +VegaAccountSlotDistinctnessTest (raw vm.load at 4 recomputed keccak slots) +VegaAccountCrossProductMutantTest (baseline ACCEPT pin for the inert-guard mutant) + equivalence-checked non-kill docblock
  - the Phase 14 mutation gate as an OBSERVED procedure: 3 killable mutants each red then restored sha256-identical, 1 documented equivalence non-kill
affects: [15 (VVER-02 PLANK_SKIP exit — gated on this falsifiability proof)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Slot distinctness is provable ONLY by raw vm.load at independently-recomputed keccak addresses — with d==1 read-conflation is behaviorally invisible so reader assertions structurally cannot prove it"
    - "An INERT guard (can never fire behaviorally) is falsified SOLELY by a mutant: a test contract pins the baseline ACCEPT so the cross-product mutant has a green to redden"
    - "Every mutant restored sha256-identical (net zero module change); FFI recompiles the .plk fresh per run so no compile-plank between mutants; non-fuzz unit anchors are cache-independent"
    - "Equivalence-checked non-kill (masked by a downstream lib revert) is DOCUMENTED in the test docblock + SUMMARY, never counted as a kill — the project's false-verification guard"

key-files:
  created:
    - .planning/phases/14-module-dispatch-storage-layout-state-readers/14-02-SUMMARY.md
  modified:
    - test/exposure/VegaAccount.t.sol

key-decisions:
  - "Slot-alias mutant (a) reddens at the totalShares slot FIRST (raw vm.load 4!=2, the doubled shared slot) rather than the riskWeightedShares-reads-0 assertion the plan named — forge stops at the first failing assert. Both are vm.load kills; the earlier one directly shows the double-increment on the raw slot. Documented honestly, not silently reordered."
  - "Dust-guard mutant (b) surfaces as vm.expectRevert's 'next call did not revert as expected' (the guard's job WAS to revert) — an equivalent, earlier observation of the same state kill (deposit banks collateral for 0 shares); the downstream assertEq(totalDeposits,0) would also fail."

patterns-established:
  - "Mutation-gate observation is the deliverable: verbatim RED line + named assertion recorded per mutant; a runs:0 replay is not proof (all anchors here are non-fuzz unit, cache-independent by construction)"

requirements-completed: [VMOD-05]

# Metrics
duration: 6min
completed: 2026-07-18
---

# Phase 14 Plan 02: Slot Distinctness + Mutation Gate Summary

**The four keccak-derived slots are proven DISTINCT by raw vm.load at four independently-recomputed addresses (the proof reader assertions structurally cannot give under d==1), and the Phase 14 falsifiability gate holds: three killable mutants each OBSERVED RED at a named assertion then restored sha256-identical (module net-unchanged), plus the unset-price guard deletion documented equivalence-checked (masked by the lib's mulDiv zero-denominator revert), never counted as a kill.**

## Performance
- **Duration:** 6 min
- **Started:** 2026-07-18T11:29:00Z
- **Completed:** 2026-07-18T11:35:00Z
- **Tasks:** 2
- **Files modified:** 1 (test/exposure/VegaAccount.t.sol; module edited-then-restored net zero)

## Module hash (net zero change)
- **Baseline sha256** `src/modules/exposure/VegaAccountMod.plk`: `555a7a100b97f41bcdf3604141065fc2fe3a1e2d63a5ec9ffcb12b9172818120`
- **Final sha256 (after the full gate):** `555a7a100b97f41bcdf3604141065fc2fe3a1e2d63a5ec9ffcb12b9172818120` — **matches byte-for-byte.** Restore verified after every one of the four mutant edits.

## Accomplishments
- **Slot distinctness by raw vm.load (Task 1).** `VegaAccountSlotDistinctnessTest`: the four preimage strings are recomputed test-side with `keccak256(bytes("VegaAccountMod.<field>"))` (grep: 4 occurrences, no hardcoded hashes) and all four matched the module SLOT_* consts under fresh `cast keccak`. `test__unit__fourSlotsAreDistinct` pins all 6 pairwise addresses distinct. `test__unit__depositWritesFourIndependentSlots` deposits at pRisk==2^97 (shares=2 != collateral=4) and asserts raw `vm.load` at each slot returns 4 / 2 / 2 / 2·2^96, each cross-checked equal to its reader — binding the test-side preimage to the module storage.
- **Cross-product baseline pin (Task 2).** `VegaAccountCrossProductMutantTest.test__unit__crossProductOverflowsAtLargeDeposit` pins that the baseline collapsed guard ACCEPTS a ~2^200 deposit at weight-one (totalDeposits==2^200, totalShares==2^200) — the green the inert-admissibility-guard mutant reddens.
- **Falsifiability gate — three killable mutants OBSERVED RED then restored (see verbatim below).**
- **Equivalence-checked non-kill documented** in `test__unit__depositBeforeSetRiskPriceReverts`'s docblock and here — never counted as a kill.

## Mutation gate — verbatim observations

Per mutant: apply one-line edit → `forge clean` → run named test (`--via-ir --optimize --skip PriceSetterHook.sol`) → OBSERVE red → `git checkout` restore → sha256 re-verify → re-run green. FFI recompiles the .plk fresh per run (no `make compile-plank` between mutants); every anchor is a NON-FUZZ unit test (cache-independent by construction).

### Mutant (a) — SLOT-CONSTANT aliasing (KILLED)
Edit: `const SLOT_RISK_WEIGHTED_SHARES = 0xa89aa0ee…31a75;` → `const SLOT_RISK_WEIGHTED_SHARES = SLOT_TOTAL_SHARES;`
Effect: both totalShares and riskWeightedShares writes hit ONE slot → double-increment; the real riskWeightedShares slot is never written.
Verbatim RED (two named assertions):
- `[FAIL: totalShares after first deposit (weight-one): 2000 != 1000] test__unit__depositMovesAllThreeAccumulators()` — the shared slot banked 2·shares.
- `[FAIL: totalShares slot: 4 != 2] test__unit__depositWritesFourIndependentSlots()` — **raw vm.load** reads the doubled shared slot (4) where the field should hold 2.
Note: the slot-distinctness contract's FIRST failing `assertEq` is the totalShares slot (raw vm.load, 4!=2), so forge halts there; the downstream `vm.load(SLOT_RISK_WEIGHTED_SHARES)==2` assertion (the never-written slot reads 0) is the plan's named site but is reached only after the earlier one is removed. Both are vm.load kills — the earlier directly exhibits the double-increment on the raw slot. **The read-conflation variant (reader returns the other slot, write correct) is BEHAVIORALLY UNKILLABLE in v1 — with d==1 the two accumulators are numerically equal forever — killable ONLY by the raw vm.load on the never-written slot; this is stated in the slot-distinctness contract docblock and is exactly why Task 1 exists.**

### Mutant (b) — DUST-GUARD deletion (KILLED on state)
Edit: delete `if @evm_iszero(shares) { revert_empty(); }`.
Effect: a dust deposit (shares==0) proceeds and banks collateral for zero shares.
Verbatim RED:
- `[FAIL: next call did not revert as expected] test__unit__dustDepositReverts()` — `vm.expectRevert()` observes the deposit(1) NO LONGER reverting; the guard's job was to revert, so its absence is a state kill (collateral banked for 0 shares; the downstream `assertEq(totalDeposits,0)` would also fail).

### Mutant (c) — RAW CHECKED CROSS-PRODUCT admissibility guard (KILLED on state)
Edit: `require(new_total_deposits >= collateral);` → `require(new_total_deposits >= collateral * storedRiskPrice);` (ASCII `*` = CHECKED multiply; `storedRiskPrice` already in scope).
Effect: at collateral==2^200, storedRiskPrice==2^96 the checked product 2^296 > 2^256 overflow-reverts.
Verbatim RED:
- `[FAIL: panic: arithmetic underflow or overflow (0x11)] test__unit__crossProductOverflowsAtLargeDeposit()` — mutant reverts where baseline accepted (totalDeposits stays 0 vs baseline 2^200). This mutant is the SOLE verification of the inert admissibility guard's presence and collapsed money-side form.

### Equivalence-checked NON-KILL — unset-price guard deletion (NOT a kill)
Edit: delete `if @evm_iszero(storedRiskPrice) { revert_empty(); }` from deposit.
Observation: `[PASS] test__unit__depositBeforeSetRiskPriceReverts()` — STAYS GREEN. With the guard gone, a deposit before any setRiskPrice has storedRiskPrice==0, so `issue_shares(collateral, RiskPriceX96{val:0})` reverts via the lib's own mulDiv zero-denominator check. BOTH baseline and mutant revert empty with totalDeposits unchanged — same observable. The module guard is defense-in-depth (fails fast before the lib call). Documented equivalence-checked in that test's docblock and here; counting it as a kill would be the false-verification pattern this project catalogues.

## Verification Results
- `make test-vega-account`: **12 tests passed, 0 failed, 0 skipped** (6 suites) — 9 pre-existing + 2 slot-distinctness + 1 cross-product, all CALLED green through FFI-deployed bytecode.
- `make test-vega-issuance` (no-regression): **11 tests passed, 0 failed** — Phase-13 surface unregressed.
- `make compile-plank` final line (verbatim): **`compile-plank: 11 ok, 0 failed, 1 skipped`** — VegaAccountMod remains the 1 skipped; PLANK_SKIP untouched (exit is Phase 15/VVER-02).
- Final module sha256 == baseline (net zero change); `grep 'keccak256(bytes('` == 4; `grep 'vm.assume'` == 0.

## Task Commits
1. **Task 1: Slot-distinctness via raw vm.load** — `5e27641` (test)
2. **Task 2: Mutation gate — 3 killable mutants red + 1 equivalence non-kill** — `4e50cd2` (test)

## Files Created/Modified
- `test/exposure/VegaAccount.t.sol` — +`VegaAccountSlotDistinctnessTest` (4 keccak-recomputed slot consts, pairwise-distinctness + raw vm.load-at-each-slot after deposit), +`VegaAccountCrossProductMutantTest` (baseline ACCEPT pin), + equivalence-checked non-kill docblock on `test__unit__depositBeforeSetRiskPriceReverts`.
- `src/modules/exposure/VegaAccountMod.plk` — edited-then-restored for each of the four mutants; **net zero change** (sha256 identical to baseline).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] NatSpec tag collision on `@evm_iszero` in a docblock**
- **Found during:** Task 2
- **Issue:** The equivalence-documentation docblock quoted the module guard literally as `@evm_iszero(storedRiskPrice)`; Solidity's NatSpec parser read `@evm_iszero(...)` as a documentation tag and failed compilation with `Documentation tag @evm_iszero(storedRiskPrice) not valid for functions`. (Same class as 14-01's `@evm_not`/`vm.assume` comment-token collisions.)
- **Fix:** Reworded to "the iszero-storedRiskPrice revert branch" — no literal `@`-prefixed token in the docblock. No behavior change.
- **Files modified:** test/exposure/VegaAccount.t.sol
- **Commit:** 4e50cd2

### Observation deviations (documented honestly, not silenced)
- **Mutant (a)** reddens at the totalShares raw-slot assertion (vm.load 4!=2) BEFORE the plan's named riskWeightedShares-reads-0 assertion, because forge halts at the first failing `assertEq`. Both are vm.load kills; the earlier one directly exhibits the double-increment on the raw slot. Not reordered — recorded as-is.
- **Mutant (b)** surfaces as `vm.expectRevert`'s "next call did not revert as expected" rather than the plan's literal `totalDeposits == 1 != 0`, because `vm.expectRevert` precedes the state assert. Equivalent, earlier observation of the same state kill.

**Total deviations:** 1 auto-fixed (blocking, docblock-only, no behavior change) + 2 honest observation-form notes. No scope creep; all four preimages matched the module, module net-unchanged.

## Issues Encountered
None beyond the NatSpec token collision. All three killable mutants reddened as designed; no mutant unexpectedly survived; the equivalence non-kill behaved exactly as predicted (masked by the lib revert).

## User Setup Required
None.

## Next Phase Readiness
- VMOD-05 discharged: slot distinctness proven by raw vm.load; the inert admissibility guard's form falsified solely by the cross-product mutant; the falsifiability gate holds with the read-conflation UNKILLABLE and unset-price EQUIVALENCE cases documented honestly.
- Phase 14 complete (both plans landed). VegaAccountMod stays in PLANK_SKIP; its exit is Phase 15 (VVER-02), now gated on this CALLED-green + mutation-verified deposit surface.
- Untracked `src/modules/protocol_integrations/PriceSetterHook.sol` (another track) still requires `--skip` on every forge run — unchanged, logged in the phase deferred-items.

## Self-Check: PASSED

Both created/modified files exist (test file with both new contracts present, SUMMARY.md) and both task commits (5e27641, 4e50cd2) are in git history.

---
*Phase: 14-module-dispatch-storage-layout-state-readers*
*Completed: 2026-07-18*
