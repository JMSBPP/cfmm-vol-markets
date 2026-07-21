---
phase: 14-module-dispatch-storage-layout-state-readers
verified: 2026-07-18T11:41:45Z
status: passed
score: 6/6 must-haves verified
---

# Phase 14: Module Dispatch, Storage Layout, State Readers Verification Report

**Phase Goal:** VegaAccountMod.plk becomes a live vault — selector dispatch mirroring RealizedVolatilityMod verbatim, three distinct accumulator slots (plus riskPrice — four total), a validated setRiskPrice, both zero guards and the unset-p_risk revert, preview views, and state readers for every stored field — with deposit proven CALLED green through deployed bytecode (never on compile alone).
**Verified:** 2026-07-18T11:41:45Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `deposit` CALLED through FFI-deployed bytecode moves totalDeposits/totalShares/riskWeightedShares (readers observe all three) | ✓ VERIFIED | `make test-vega-account` re-run: 12/12 passed incl. `test__unit__depositMovesAllThreeAccumulators` (two deposits double each accumulator) |
| 2 | deposit(0), dust deposit, deposit-before-setRiskPrice each REVERT with state unchanged | ✓ VERIFIED | `VegaAccountGuardTest` (4 tests) green; each `vm.expectRevert()` followed by `assertEq(totalDeposits(), 0, ...)` in test/exposure/VegaAccount.t.sol lines 84-125 |
| 3 | setRiskPrice stores the price (reader confirms) and reverts on 0 | ✓ VERIFIED | `VegaAccountSetRiskPriceTest.test__unit__setRiskPriceStores` + `test__unit__setRiskPriceZeroReverts` green |
| 4 | previewDeposit(amt) EQUALS the totalShares delta of an immediately following deposit(amt) | ✓ VERIFIED | `test__unit__previewDepositEqualsDepositDelta` (two prices) + `test__fuzz__previewDepositEqualsDepositDelta` (256 runs) green, both CALL previewDeposit and deposit selectors |
| 5 | previewRiskPrice returns p_risk and reverts for hX96>=2^96 | ✓ VERIFIED | `test__unit__previewRiskPriceComputesAndRejectsHGe1` green, pins 60944740395587951995033807951, reverts at h==1 |
| 6 | Every selector declared in VegaAccountInterface.plk with exact signature string, dispatches correctly | ✓ VERIFIED | 8/8 `cast sig` recomputations match file constants exactly (independently recomputed, see below) |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/interfaces/exposure/VegaAccountInterface.plk` | 8 cast-sig-verified SELECTOR_* consts | ✓ VERIFIED | grep -c `^const SELECTOR_` = 8; all 8 independently recomputed with `cast sig`, byte-identical |
| `src/modules/exposure/VegaAccountMod.plk` | verbatim dispatch, 4 slots, deposit/setRiskPrice/2 previews/4 readers, inert guard, zero arithmetic | ✓ VERIFIED | 4 `const SLOT_` decls, all independently recomputed with `cast keccak`, byte-identical; zero `mulDiv`/`*%`/`+%`; zero `@evm_not`; 5 `@evm_iszero` guard sites; dispatch structurally identical idiom to RealizedVolatilityMod (shr 224, if/else-if, `@evm_stop`, `return_u256`, trailing `revert_empty`) |
| `test/exposure/VegaAccount.t.sol` | smoke + guard + slot-distinctness + mutation contracts driving FFI-deployed module | ✓ VERIFIED | `deployPlank` used in shared `setUp`; 6 contracts, 12 tests, all CALLED green |
| `Makefile` | `test-vega-account` focused target | ✓ VERIFIED | present, in `.PHONY`, correct `--skip`/`--via-ir`/`--optimize` flags |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| VegaAccountMod.plk | VegaAccountInterface.plk | `import interfaces::exposure::VegaAccountInterface::*` | ✓ WIRED | line 2 of module |
| VegaAccountMod.plk | VegaIssuanceLib | `issue_shares`/`haircut_risk_price` calls | ✓ WIRED | lines 40, 74, 81; zero raw arithmetic for shares/p_risk |
| VegaAccount.t.sol | VegaAccountMod.plk | `deployPlank` FFI + selector calls | ✓ WIRED | `setUp` deploys via FFI; every test calls selectors via `IVegaAccount` |
| VegaAccount.t.sol (14-02) | VegaAccountMod.plk | test recomputes 4 slot addresses from same preimage strings | ✓ WIRED | test lines 211-214 `keccak256(bytes("VegaAccountMod.<field>"))` match module preimage comments verbatim; raw vm.load cross-checked against readers |
| vm.load on never-aliased slot | read-conflation-invisible aliasing mutant | raw slot read is the only kill | ✓ WIRED | independently re-applied mutant, observed RED at raw slot (`totalShares slot: 4 != 2`), documented in docblock lines 195-202 |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| VMOD-01 | 14-01 | deposit + 3 accumulators + zero/dust reverts | ✓ SATISFIED | REQUIREMENTS.md [x] Complete; module + tests confirm |
| VMOD-02 | 14-01 | setRiskPrice + unset-price coupling + unauthenticated scope | ✓ SATISFIED | REQUIREMENTS.md [x] Complete; "DOCUMENTED COUPLING" and "DELIBERATELY UNAUTHENTICATED" comments present in module |
| VMOD-03 | 14-01 | preview views + preview==deposit-delta | ✓ SATISFIED | REQUIREMENTS.md [x] Complete; fuzz + unit tests green |
| VMOD-04 | 14-01 | state readers + interface pinning | ✓ SATISFIED | REQUIREMENTS.md [x] Complete; 4 readers + 8-selector interface file |
| VMOD-05 | 14-02 | slot distinctness (vm.load) + mutation gate + inert guard falsifiability | ✓ SATISFIED | REQUIREMENTS.md [x] Complete; independently re-killed mutant (a), sha256 restored |

Traceability table (REQUIREMENTS.md lines 217-221): all five VMOD-01..05 rows read "Complete" — consistent with observations. No orphaned requirements found for Phase 14.

### Anti-Patterns Found

None. Scanned `src/modules/exposure/VegaAccountMod.plk`, `src/interfaces/exposure/VegaAccountInterface.plk`, `test/exposure/VegaAccount.t.sol` for TODO/FIXME/XXX/HACK/PLACEHOLDER and empty-return stubs — zero matches.

## Independent Re-Verification Detail

1. **Test suites re-run (not trusted from SUMMARY):**
   - `make test-vega-account`: **12 tests passed, 0 failed, 0 skipped** (6 suites) — matches SUMMARY claim.
   - `make test-vega-issuance`: **11 tests passed, 0 failed** — no regression, matches SUMMARY claim.
   - `make compile-plank`: final line **`compile-plank: 11 ok, 0 failed, 1 skipped`** — matches SUMMARY's corrected baseline (not the plan's stale "10"); VegaAccountMod remains the sole skip; `grep PLANK_SKIP` in Makefile confirms only `src/modules/exposure/VegaAccountMod.plk` is listed, unchanged.

2. **Module read verbatim:** dispatch idiom (`@evm_shr(224, @evm_calldataload(0))`, calldata 4/36, `@evm_stop()` on writes, `return_u256` on views, trailing `revert_empty()`) structurally matches `RealizedVolatilityMod.plk`. Zero arithmetic confirmed (`grep mulDiv|*%|+%` empty; `shares`/`p_risk` originate only from `issue_shares`/`haircut_risk_price`). Guards use `@evm_iszero` exclusively (`grep @evm_not` empty, 5 `@evm_iszero` sites). All required comments present: unauthenticated-setter scope boundary, inert admissibility guard's "NEVER fire" honesty comment, setter-rejects-0 "DOCUMENTED COUPLING" comment.

3. **Selectors/slots independently recomputed:**
   - `cast sig` for all 8 signatures byte-identical to file constants: deposit=0xb6b55f25, setRiskPrice=0x647b5b63, previewDeposit=0xef8b30f7, previewRiskPrice=0x2d3436e3, totalDeposits=0x7d882097, totalShares=0x3a98ef39, riskWeightedShares=0x3a2594b5, riskPrice=0xd04266d9.
   - `cast keccak` for all 4 preimages byte-identical to module SLOT_* consts (totalDeposits, totalShares, riskWeightedShares, riskPrice slots all matched).

4. **Independent mutant re-kill (slot-aliasing, SLOT_RISK_WEIGHTED_SHARES := SLOT_TOTAL_SHARES):**
   - Baseline sha256 confirmed: `555a7a100b97f41bcdf3604141065fc2fe3a1e2d63a5ec9ffcb12b9172818120` (64 hex chars, matches SUMMARY exactly).
   - `rm -rf cache/fuzz`, applied edit, `forge clean`, re-ran `make test-vega-account`-equivalent forge command.
   - Observed RED: `[FAIL: totalShares after first deposit (weight-one): 2000 != 1000] test__unit__depositMovesAllThreeAccumulators()` and `[FAIL: totalShares slot: 4 != 2] test__unit__depositWritesFourIndependentSlots()` — matches the SUMMARY's verbatim lines exactly (same shape, same numbers). Additional cascade failures observed in `VegaAccountPreviewTest` and `VegaAccountCrossProductMutantTest` (expected side effect of the doubled totalShares slot; not contradicting the SUMMARY, which named the two primary kill sites).
   - Restored via `git checkout --`, sha256 re-verified identical to baseline, re-run confirmed 12/12 green.

5. **Equivalence non-kill documented:** `test__unit__depositBeforeSetRiskPriceReverts`'s docblock (lines 101-113 of the test file) explicitly states the unset-price guard deletion is "PROVEN EQUIVALENT, NOT a kill" because the deletion is masked by the lib's own mulDiv zero-denominator revert, and states it is NOT counted among the three kills. Confirmed present and not counted anywhere as a kill.

6. **previewDeposit==deposit-delta / vm.load preimage cross-reference:** `test__unit__previewDepositEqualsDepositDelta` calls both `previewDeposit` and `deposit` selectors and asserts equality (lines 146-164). `VegaAccountSlotDistinctnessTest` computes `keccak256(bytes("VegaAccountMod.<field>"))` test-side (lines 211-214) from the identical preimage strings restated as comments in the module (lines 10, 12, 14, 16) — read both files, preimages match verbatim.

7. **Requirements cross-reference:** VMOD-01..05 all `[x] Complete` in REQUIREMENTS.md, traceability table all "Complete", consistent with all above observations. No orphaned requirements.

8. **must_haves from both PLAN frontmatters:** all truths, artifacts, and key_links from 14-01-PLAN.md and 14-02-PLAN.md frontmatter verified present and functioning in the codebase (see tables above).

### Human Verification Required

None. All must-haves are verifiable programmatically via test execution, grep, `cast sig`/`cast keccak` recomputation, and sha256 comparison — all were independently re-executed in this verification pass rather than trusted from the SUMMARYs.

### Gaps Summary

No gaps found. Every observable truth, artifact, and key link was independently re-derived and matches the SUMMARY claims exactly, including the specific numeric shapes of the re-killed mutant's failure output. `make compile-plank`'s "11 ok" (not the plan's stale "10") was independently confirmed as the correct current baseline, with PLANK_SKIP unchanged and VegaAccountMod still the sole skip (its exit is Phase 15/VVER-02, out of scope here).

---

_Verified: 2026-07-18T11:41:45Z_
_Verifier: Claude (gsd-verifier)_
