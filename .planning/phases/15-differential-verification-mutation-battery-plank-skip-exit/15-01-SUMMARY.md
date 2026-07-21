---
phase: 15-differential-verification-mutation-battery-plank-skip-exit
plan: 01
subsystem: testing
tags: [differential, forge, ffi, plank, vega-account, mutation-battery, foundry-fuzz]

# Dependency graph
requires:
  - phase: 13-issuance-library-vegaissuancelib
    provides: "IssuanceRefMock (solady fullMulDiv floor / fullMulDivUp ceil), proven tolerance-0 vs VegaIssuanceLib — the e2e mirror's expected-value source"
  - phase: 14-module-dispatch-storage-layout-state-readers
    provides: "VegaAccountMod.plk CALLED-green deposit surface (deposit/setRiskPrice/previews/4 readers over 4 keccak slots) + the IVegaAccount ABI"
provides:
  - "test/exposure/VegaAccount.e2e.t.sol — VegaAccountE2EDiffTest: the milestone acceptance driver (VVER-01)"
  - "End-to-end (setRiskPrice, deposit) SEQUENCE differential: deployed module vs trivially-simple IssuanceRefMock-backed stateful mirror, three accumulators tol-0 after EVERY write, assertion INSIDE the driver helpers"
  - "A rounding/guard/overflow-sensitive green for the 15-02 mutation battery to redden (p_risk ceil, shares floor, dust guard, cross-product overflow all sensitized)"
affects: [15-02, mutation-battery, plank-skip-exit, vver-02]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Stateful sequence differential: identical (setRiskPrice, deposit) sequences driven into module + mirror, assertion INSIDE _writeBoth-style helpers (abort-at-earliest-divergence), mirroring RealizedVolatilityTimepointDiffTest (VDIFF-04)"
    - "Trivially-simple mirror: three uint256 accumulators updated ONLY via the mock's pure functions — no arithmetic of its own to distrust"
    - "Two SEPARATE mirror accumulators for shares vs riskWeightedShares so d==1 (riskWeightedShares==totalShares) is a genuine cross-check, not a shared-storage tautology"

key-files:
  created:
    - "test/exposure/VegaAccount.e2e.t.sol"
  modified: []

key-decisions:
  - "New third test file (not folded into VegaAccount.t.sol module surface nor VegaIssuance.diff.t.sol lib surface): the stateful sequence differential is a distinct surface; the .e2e name keeps VegaAccount.t.sol pure and 15-02 runs both files"
  - "Fixed anchor reuses the Phase-12/13 anchor VERBATIM (deposit=10 at p12=60944740395587951995033807951 mints shares=12) — inherited, not invented"
  - "Mid-sequence price derived via the module's previewRiskPrice and diffed tol-0 vs mock.haircutRiskPrice so the p_risk CEIL site is sensitive in the e2e"
  - "Fuzz bounds (price in [2^96,2^120], deposit in [2^120,2^160]) constructed so shares>=2^96 always — no dust, no repair, no result overflow; every run a live assertion"

patterns-established:
  - "Sensitivity map documented in-file: each 15-02 killable mutant (p_risk ceil->floor, shares floor->ceil, dust-guard delete, raw-checked cross-product) named with its exact kill site in this driver"

requirements-completed: [VVER-01]

# Metrics
duration: 4min
completed: 2026-07-18
---

# Phase 15 Plan 01: End-to-End (setRiskPrice, deposit) Sequence Differential Summary

**VegaAccountE2EDiffTest drives identical (setRiskPrice, deposit) sequences into the FFI-deployed VegaAccountMod and a trivially-simple IssuanceRefMock-backed mirror, asserting all three accumulators equal at tolerance 0 AFTER EVERY write — inside the driver helpers — over a fixed Phase-12 anchor plus a 256-run constructed fuzz.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-18T16:13:20Z
- **Completed:** 2026-07-18T16:17:27Z
- **Tasks:** 2
- **Files modified:** 1 (created)

## Accomplishments
- Built the milestone acceptance driver (VVER-01): `test/exposure/VegaAccount.e2e.t.sol`, one contract `VegaAccountE2EDiffTest`, 246 lines.
- The assertion lives INSIDE `_setPriceBoth` / `_depositBoth` / `_depositExpectRevertBoth` (abort-at-earliest-divergence), so "after every write" cannot be forgotten at a call site.
- All four 15-02-relevant sites are sensitized so each killable mutant has a green to redden: the p_risk CEIL site (previewRiskPrice vs mock.haircutRiskPrice, tol 0), the shares FLOOR site (Phase-12 anchor shares=12 + the 2.5->2 point), the dust GUARD (mid-sequence dust revert leaves state synced), and the cross-product OVERFLOW (~2^200 weight-one deposit the baseline accepts).
- Fixed anchor reproduces the inherited Phase-12/13 anchor exactly (p12 = 60944740395587951995033807951; deposit=10 mints 12 shares).
- Constructed 256-run fuzz with a NEW price each iteration (mid-sequence re-pricing → stale-price guard), no vm.assume, zero counterexamples.

## Task Commits

Each task was committed atomically:

1. **Task 1: E2E differential driver — mirror, helpers, and the fixed hand-checkable anchor** - `52ce92e` (test)
2. **Task 2: Constructed fuzz sequences (no vm.assume), mid-sequence re-pricing** - `7374d56` (test)

**Plan metadata:** (this commit) (docs: complete plan)

## Files Created/Modified
- `test/exposure/VegaAccount.e2e.t.sol` - VegaAccountE2EDiffTest: the end-to-end (setRiskPrice, deposit) sequence differential. Trivially-simple mirror (three uint256 accumulators + mirrored price, updated via mock.issueShares/haircutRiskPrice only); helpers with the tol-0 three-field assertion inside; fixed anchor + constructed 256-run fuzz.

## Hand-checked anchor totals (verbatim from the docblock, all module==mirror, tol 0)

| Step | Op | Expected (D, S, RW) |
| ---- | -- | ------------------- |
| 1 | setRiskPrice(2^96) | (0, 0, 0) |
| 2 | deposit(1000) | (1000, 1000, 1000) |
| 3 | p12 = previewRiskPrice(10·2^92, 3·2^92) == mock.haircutRiskPrice(...) == **60944740395587951995033807951**; setRiskPrice(p12) | (1000, 1000, 1000) |
| 4 | deposit(10) @ p12 → floor = **12 shares** (Phase-12 anchor, INEXACT) | (1010, 1012, 1012) |
| 5 | setRiskPrice(2^97); deposit(1) DUST REVERT (floor=0) | (1010, 1012, 1012) synced after revert |
| 6 | deposit(5) @ 2^97 → floor(2.5) = **2** (INEXACT) | (1015, 1014, 1014) |
| 7 | setRiskPrice(2^96); deposit(2^200) baseline ACCEPTS | (1015+2^200, 1014+2^200, 1014+2^200) |

## Verbatim green tail of the e2e run

```
Ran 2 tests for test/exposure/VegaAccount.e2e.t.sol:VegaAccountE2EDiffTest
[PASS] test__fuzz__randomSequenceDiffers(uint256,uint8) (runs: 256, μ: 246601, ~: 243084)
[PASS] test__unit__fixedAnchorSequenceDiffers() (gas: 253148)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 56.57ms (41.52ms CPU time)
Ran 1 test suite in 57.31ms (56.57ms CPU time): 2 tests passed, 0 failed, 0 skipped (2 total tests)
```

Command (skip the parallel-track PriceSetterHook.sol; --via-ir --optimize per the phase gate):
`forge test --match-path 'test/exposure/VegaAccount.e2e.t.sol' --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize`

## Grep-checkable acceptance (all met)
- `assertEq(p12, mock.haircutRiskPrice` : 1 (p_risk site sensitive)
- `_depositExpectRevertBoth` : 4 (dust revert proves sync)
- `1 << 200` : 1 (cross-product kill site)
- `vm.assume` : 0 (corpus constructed via bound() only — a docblock mention was reworded so the mechanical grep stays honest)
- `forge-config: default.fuzz.runs` : 1 (256 runs)
- `"price"` keccak key : 1 (mid-sequence re-pricing)

## Decisions Made
None beyond the plan — followed the action spec verbatim. The one editorial change (reword a comment containing the literal string "vm.assume" to "assume-filtering cheatcode") was made so the plan's own `grep -c 'vm.assume' == 0` acceptance criterion stays mechanically honest; the corpus was never assume-filtered.

## Deviations from Plan

None - plan executed exactly as written. No bugs, no missing critical functionality, no blocking issues, no architectural changes. The differential found ZERO divergence between module and mock (no surprising red — the module matches the reference over both the fixed anchor and 256 constructed sequences).

## Issues Encountered
None. The source-file guard from the plan was checked first: module `sha256 555a7a10…818120` and lib `sha256 2ee07162…c7e3` both match HEAD (WIP-edit note confirmed RESOLVED before the run).

## Baselines (unregressed)
- `make test-vega-account` — 12/12 passed
- `make test-vega-issuance` — 11/11 passed
- `compile-plank` — unaffected by construction (this plan added a `.sol` test only; touched no `.plk`; VegaAccountMod stays the 1 skipped, PLANK_SKIP untouched)

## Next Phase Readiness
- VVER-01 satisfied. The rounding/guard/overflow-sensitive green is in place for **15-02** (the mutation battery + PLANK_SKIP exit / VVER-02).
- 15-02 should apply its five named mutants against BOTH `test/exposure/VegaAccount.t.sol` and `test/exposure/VegaAccount.e2e.t.sol`, verify each reddens (clear cache/fuzz before believing any fuzz kill), restore sha256-identical, then gate the PLANK_SKIP exit on the CALLED-green + mutation-verified surface.
- Carry-forward blocker (unchanged): untracked `src/modules/protocol_integrations/PriceSetterHook.sol` (parallel track) still requires `--skip` on forge targets here (logged in phase deferred-items.md).

## Self-Check: PASSED

- FOUND: `test/exposure/VegaAccount.e2e.t.sol`
- FOUND: `.planning/phases/15-differential-verification-mutation-battery-plank-skip-exit/15-01-SUMMARY.md`
- FOUND commit: `52ce92e` (Task 1)
- FOUND commit: `7374d56` (Task 2)

---
*Phase: 15-differential-verification-mutation-battery-plank-skip-exit*
*Completed: 2026-07-18*
