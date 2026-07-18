---
phase: 14-module-dispatch-storage-layout-state-readers
plan: 01
subsystem: testing
tags: [plank, evm, vault, dispatch, keccak-slots, ffi, forge, vega-exposure]

# Dependency graph
requires:
  - phase: 13-issuance-library-vegaissuancelib
    provides: VegaIssuanceLib (haircut_risk_price ceil, issue_shares floor) + RiskPriceX96/Haircut newtypes — the ONLY arithmetic the module composes
  - phase: 12-risk-price-spec-vegaexposure-types
    provides: VegaExposure newtypes the lib signatures are typed by
provides:
  - src/interfaces/exposure/VegaAccountInterface.plk — 8 cast-sig-verified SELECTOR_* consts with signature-string comments
  - src/modules/exposure/VegaAccountMod.plk — live deposit-only vault (dispatch, 4 keccak scalar slots, deposit/setRiskPrice/2 previews/4 readers, inert admissibility guard, ZERO arithmetic)
  - test/exposure/VegaAccount.t.sol — 9 CALLED-green tests through FFI-deployed bytecode (smoke/guard/setter/preview)
  - Makefile test-vega-account focused target
affects: [14-02 (slot-distinctness vm.load + mutation gate), 15 (VVER-02 PLANK_SKIP exit)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Module holds ZERO arithmetic — shares only via issue_shares, p_risk only via haircut_risk_price"
    - "Interface file pins selectors from the SAME signature strings the test ABI derives from"
    - "Guards via @evm_iszero (never the bitwise-NOT builtin); every guard asserted ON STATE, never on return data"
    - "previewDeposit routes through the identical lib call as deposit (canonical-vault-bug guard)"

key-files:
  created:
    - src/interfaces/exposure/VegaAccountInterface.plk
    - test/exposure/VegaAccount.t.sol
    - .planning/phases/14-module-dispatch-storage-layout-state-readers/14-01-SUMMARY.md
  modified:
    - src/modules/exposure/VegaAccountMod.plk
    - Makefile

key-decisions:
  - "compile-plank baseline is 11 ok / 0 failed / 1 skipped, NOT the plan's stale 10 — Phase-13's VegaIssuanceKernelHarness.plk entrypoint (commit 12bb9d7) is the 11th; VegaAccountMod remains the 1 skipped, PLANK_SKIP untouched"
  - "All 8 selectors and all 4 keccak slots matched the plan's cross-check reference exactly under fresh cast recompute — zero selector/slot deviations"

patterns-established:
  - "New-surface test file separate from the lib-arithmetic file (one file per surface)"
  - "TDD module task: the .t.sol driving FFI-deployed bytecode IS the RED->GREEN proof; compile-green proves nothing"

requirements-completed: [VMOD-01, VMOD-02, VMOD-03, VMOD-04]

# Metrics
duration: 5min
completed: 2026-07-18
---

# Phase 14 Plan 01: Module Dispatch, Storage Layout, State Readers Summary

**VegaAccountMod.plk is now a live deposit-only vault — verbatim RealizedVolatilityMod dispatch over 4 keccak-derived scalar slots, deposit(3 guards)/setRiskPrice/previewDeposit/previewRiskPrice/4 readers, ZERO arithmetic (all math composed from VegaIssuanceLib), proven 9/9 CALLED-green through FFI-deployed bytecode.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-18T11:19:06Z
- **Completed:** 2026-07-18T11:24:13Z
- **Tasks:** 3
- **Files modified:** 5 (2 created source, 1 modified source, 1 test created, 1 Makefile)

## Accomplishments
- Pinned 8 selectors in a new `interfaces/exposure/VegaAccountInterface.plk`, each recomputed with `cast sig` — all matched the plan reference (deposit=0xb6b55f25, setRiskPrice=0x647b5b63, previewDeposit=0xef8b30f7, previewRiskPrice=0x2d3436e3, totalDeposits=0x7d882097, totalShares=0x3a98ef39, riskWeightedShares=0x3a2594b5, riskPrice=0xd04266d9).
- Authored the live module over 4 `cast keccak`-verified scalar slots (all matched the plan reference): totalDeposits=0x7028e6d3…586a1f, totalShares=0x8d1d621c…97c31c, riskWeightedShares=0xa89aa0ee…31a75 (0xa89aa0ee0b526f887c7f5ea59cdeaeeeccc805ac2bfa050fcf4f8a353fe31a75), riskPrice=0x264476aa…7566ea.
- 9/9 CALLED-green: deposit moves all three accumulators additively (two deposits → doubled), all three deposit guards + the setter zero-guard revert asserted ON STATE, previewDeposit == totalShares delta at weight-one + a second price + 256-run fuzz, previewRiskPrice pins p_risk=60944740395587951995033807951 and reverts at h==1.
- Module holds ZERO arithmetic (shares only via `issue_shares`, p_risk only via `haircut_risk_price`); guards use `@evm_iszero` (no bitwise-NOT builtin present).

## Task Commits

Each task was committed atomically:

1. **Task 1: Interface file — pin every selector** - `3bb6bd6` (feat)
2. **Task 2: Implement VegaAccountMod** - `11b4755` (feat)
3. **Task 3: Smoke + guard suite CALLED-green** - `6f73dce` (test)

_Note: Task 3 is tdd="true"; the module implementation existed from Task 2, so the .t.sol driving FFI-deployed bytecode is the RED→GREEN proof committed in one test commit._

## Files Created/Modified
- `src/interfaces/exposure/VegaAccountInterface.plk` - 8 SELECTOR_* consts, each cast-sig-verified with its signature-string comment; uint256-everywhere type convention documented.
- `src/modules/exposure/VegaAccountMod.plk` - Live module: verbatim dispatch, 4 keccak scalar slots, deposit/setRiskPrice/2 previews/4 readers, inert admissibility guard, zero arithmetic.
- `test/exposure/VegaAccount.t.sol` - Smoke/guard/setter/preview contracts driving the FFI-deployed module; IVegaAccount declared from the same signature strings as the interface file.
- `Makefile` - `test-vega-account` focused target added beside `test-vega-issuance` and to `.PHONY`.

## Verification Results
- `make test-vega-account`: **9 tests passed, 0 failed, 0 skipped** (4 test suites) — every selector CALLED green through FFI-deployed bytecode.
- `make test-vega-issuance` (no-regression): **11 tests passed, 0 failed** — Phase-13 surface unregressed.
- `make compile-plank` final line (verbatim): **`compile-plank: 11 ok, 0 failed, 1 skipped`** — VegaAccountMod remains the 1 skipped; PLANK_SKIP unchanged.
- No `vm.assume` anywhere in the test file (grep returns 0).

## Decisions Made
- **compile-plank baseline correction:** the plan and STATE.md cross-check said "10 ok / 0 failed / 1 skipped". The measured value is **11 ok**. Enumerating init-block `.plk` entrypoints confirmed the 11th OK is `test/exposure/VegaIssuanceKernelHarness.plk`, added by Phase 13-01 (commit 12bb9d7) — it postdates the Phase-9 "10 ok" note. My changes add NO new `.plk` entrypoint (the interface file has no init block; the module was already skipped; the test is `.sol`). The acceptance intent — module still SKIPPED, gate still green, PLANK_SKIP untouched — holds; only the stale numeric cross-check was updated. Per the phase's own rule ("embedded values are cross-checks, not authoritative"), the measured value wins.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reworded two comments containing literal builtin/cheatcode tokens that broke the automated acceptance greps**
- **Found during:** Task 2 and Task 3
- **Issue:** (a) The module's Guard-1 comment contained the literal `@evm_not`, tripping the `! grep -q '@evm_not'` structure check even though no guard used it. (b) The test docblock contained the literal `vm.assume`, tripping the "grep returns nothing" acceptance even though no assume-filter is used.
- **Fix:** Reworded both comments to describe the trap without the literal token ("the bitwise-NOT builtin"; "CONSTRUCTED via bound() only — never assume-filtered").
- **Files modified:** src/modules/exposure/VegaAccountMod.plk, test/exposure/VegaAccount.t.sol
- **Verification:** `grep '@evm_not'` and `grep 'vm.assume'` both return nothing; structure verify prints "module structure ok"; 9/9 tests green.
- **Committed in:** 11b4755 (Task 2), 6f73dce (Task 3)

---

**Total deviations:** 1 auto-fixed (1 blocking, comment-only — no behavior change) + 1 stale-cross-check correction (documented above, not a code deviation).
**Impact on plan:** No scope creep, no behavior change. All selectors/slots matched the plan reference exactly; the only substantive finding is the corrected compile-plank baseline (11, not 10).

## Issues Encountered
None beyond the comment-token grep collisions documented above. No real bug found in the Phase-13 lib.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- 14-02 is ready: the 4 keccak slots (preimages restated in-module) are computable Solidity-side for the slot-distinctness `vm.load` proof; the inert admissibility guard and every selector branch are in place for the cross-product mutation gate.
- VegaAccountMod stays in PLANK_SKIP this phase; its exit is Phase 15 (VVER-02), gated on this CALLED-green deposit surface.
- Untracked `src/modules/protocol_integrations/PriceSetterHook.sol` (another track) still requires `--skip` on every forge run — unchanged, logged in the phase deferred-items.

## Self-Check: PASSED

All created files exist (interface, module, test, summary) and all three task commits (3bb6bd6, 11b4755, 6f73dce) are present in git history.

---
*Phase: 14-module-dispatch-storage-layout-state-readers*
*Completed: 2026-07-18*
