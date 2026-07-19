---
phase: 15-differential-verification-mutation-battery-plank-skip-exit
plan: 02
subsystem: testing
tags: [mutation-battery, differential, forge, ffi, plank, vega-account, plank-skip, milestone-v3.0]

# Dependency graph
requires:
  - phase: 15-01
    provides: "VegaAccountE2EDiffTest (test/exposure/VegaAccount.e2e.t.sol) — the rounding/guard/overflow-sensitive e2e driver this battery reddens"
  - phase: 13-issuance-library-vegaissuancelib
    provides: "VegaIssuanceLib.plk (haircut_risk_price ceil / issue_shares floor) + VegaIssuance.diff.t.sol kernel probe — the cache-independent lib kill site"
  - phase: 14-module-dispatch-storage-layout-state-readers
    provides: "VegaAccountMod.plk CALLED-green deposit surface + VegaAccount.t.sol (vm.load slot-distinctness, dust-guard, cross-product mutant tests)"
provides:
  - "VVER-02 discharged: observed-RED mutation battery of FIVE killable mutants over the e2e + reused Phase-13/14 exposure surface, each cache-cleared and restored sha256-identical"
  - "VegaAccountMod OUT of PLANK_SKIP — queue now EMPTY; module compiles standalone (build/plank/src_modules_exposure_VegaAccountMod.hex)"
  - "make test folded in: vega + e2e suites now counted via the PriceSetterHook --skip guard; test-vega-e2e focused target added"
  - "Two runs of record: make compile (11 ok / 1 failed / 0 skipped) and make test (74 pass / 5 fail) — verbatim tails recorded"
affects: [milestone-v3.0-close, gsd:complete-milestone]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Observed-RED battery over the WHOLE exposure surface in one shot: forge test --match-path 'test/exposure/*.t.sol' reddens the e2e driver AND the reused Phase-13/14 kill sites simultaneously; cache/fuzz cleared before every mutant so no runs:0 kill is a cached replay"
    - "PLANK_SKIP shrinks only on PROOF, never on compile: the queue emptied only after every killable mutant in the module was observed red, not merely because it compiles"
    - "Honest gate accounting: an out-of-scope another-track compile failure (OrderHelper.plk) is logged to deferred-items and left VISIBLE rather than skipped/filtered to fake 12/0/0"

key-files:
  created:
    - ".planning/phases/15-differential-verification-mutation-battery-plank-skip-exit/deferred-items.md"
  modified:
    - "Makefile"

key-decisions:
  - "VegaAccountMod's PLANK_SKIP exit is gated on the observed-RED battery (VVER-02), not on compile — the module compiles standalone AND every killable mutant in it was observed red before the skip line was deleted"
  - "The out-of-scope OrderHelper.plk / missing src/types/Order.plk failure (OrderType track) is logged to deferred-items and NOT fixed: restoring the HEAD-committed-but-working-tree-deleted file would clobber another track's in-progress refactor; skipping the harness would be the dishonest gate-greening the repo forbids"
  - "make test CURRENTLY-RED comment updated to MEASURED counts (74 pass / 5 fail), never guessed; the 5 pos_spec failures restated and kept visible"

patterns-established:
  - "Per-mutant protocol: Edit -> rm -rf cache/fuzz -> observe RED verbatim (noting the e2e-specific kill) -> git checkout HEAD -> sha256 == recorded baseline -> re-run GREEN. Restores files net-unchanged so the source diff for the battery task is empty (evidence lives in this SUMMARY)."

requirements-completed: [VVER-02]

# Metrics
duration: 13min
completed: 2026-07-18
---

# Phase 15 Plan 02: Observed-RED Mutation Battery + PLANK_SKIP Exit Summary

**Five killable mutants over the VegaAccount e2e + reused Phase-13/14 surface each OBSERVED red (cache/fuzz cleared) and restored sha256-identical, the two equivalence-masked mutants documented as non-kills, VegaAccountMod taken OUT of PLANK_SKIP (compiles standalone), and the vega + e2e suites folded into `make test` — closing VVER-02 and the v3.0 acceptance gate.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-07-18T16:22:51Z
- **Completed:** 2026-07-18T16:35:56Z
- **Tasks:** 2
- **Files modified:** 2 (Makefile modified, deferred-items.md created; both source .plk files net-unchanged by the battery)

## Accomplishments
- VVER-02 discharged: the FIVE killable mutants were each observed red at the e2e driver AND the reused kill sites, cache/fuzz cleared before every run, then restored to the recorded sha256 baselines with the suite re-run green.
- The two equivalence-masked mutants (h-bound `>=`->`>` in the lib; unset-price guard deletion in the module) were applied, the suite STAYED green, and both are documented as equivalence-checked defense-in-depth — never counted as kills.
- VegaAccountMod left PLANK_SKIP (queue now EMPTY) after being PROVEN by the battery, not on compile alone; it compiles standalone.
- The vega + e2e suites are folded into `make test` via the `--skip PriceSetterHook.sol` guard; a `test-vega-e2e` focused target was added.
- Both runs of record captured verbatim (see below).

## The observed-RED battery (Task 1)

Baseline pre-condition: both source files matched the recorded sha256 on disk (the 15-01 WIP-edit note was already resolved); STEP 0 `git checkout HEAD --` was run anyway. Baseline suite GREEN: `25 tests passed, 0 failed, 0 skipped`.

Suite run per mutant (reddens the e2e AND the reused files in one shot):
`rm -rf cache/fuzz && forge test --match-path 'test/exposure/*.t.sol' --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize`

### Five KILLABLE mutants — each OBSERVED red, restored sha256-identical

**(a) p_risk ceil->floor (LIB VegaIssuanceLib.plk, `mulDivRoundingUp` -> `mulDiv` in `haircut_risk_price`)**
- e2e kill: `[FAIL: p_risk ceil: module preview vs mock, tol 0: 60944740395587951995033807950 != 60944740395587951995033807951] test__unit__fixedAnchorSequenceDiffers()`
- reused kill: `[FAIL: p_risk ceil at inexact anchor: 60944740395587951995033807950 != 60944740395587951995033807951] test__unit__anchorComposedEqualsMockAndHandDerived()` (VegaIssuanceKernelProbeTest, cache-independent unit anchor)
- also: module `previewRiskPrice` unit test + composed==mock/one-sided fuzzes.
- Restored: `SHA256 RESTORED OK (lib)` (2ee07162…bfc7e3); re-run `25 passed, 0 failed`.

**(b) shares floor->ceil (LIB VegaIssuanceLib.plk, `mulDiv` -> `mulDivRoundingUp` in `issue_shares`)**
- e2e kill: `[FAIL: totalShares: module vs mirror, tol 0: 1013 != 1012] test__unit__fixedAnchorSequenceDiffers()` (Phase-12 anchor: 12 shares becomes 13)
- reused kill: `[FAIL: shares floor at inexact anchor: 13 != 12] test__unit__anchorComposedEqualsMockAndHandDerived()` (cache-independent unit anchor)
- also: dust-guard cascade (`next call did not revert as expected` at the 2.5->3 point), backing invariant, composed==mock/one-sided fuzzes.
- Restored: `SHA256 RESTORED OK (lib)`; re-run `25 passed, 0 failed`.

**(c) slot-constant aliasing (MODULE VegaAccountMod.plk, `SLOT_RISK_WEIGHTED_SHARES` value aliased to the `SLOT_TOTAL_SHARES` value 0x8d1d621c…c31c)**
- e2e kill: `[FAIL: totalShares: module vs mirror, tol 0: 2000 != 1000] test__unit__fixedAnchorSequenceDiffers()` (first weight-one deposit double-writes the shared slot)
- reused kill: `[FAIL: totalShares slot: 4 != 2] test__unit__depositWritesFourIndependentSlots()` (VegaAccountSlotDistinctnessTest vm.load)
- also: `depositMovesAllThreeAccumulators` (2000 != 1000), `previewDepositEqualsDepositDelta` (1000 != 2000).
- Restored: `SHA256 RESTORED OK (module)` (555a7a10…818120); re-run `25 passed, 0 failed`.

**(d) dust-guard deletion (MODULE VegaAccountMod.plk, delete `if @evm_iszero(shares) { revert_empty(); }`)**
- e2e kill: `[FAIL: next call did not revert as expected] test__unit__fixedAnchorSequenceDiffers()` (the mid-sequence dust deposit no longer reverts)
- reused kill: `[FAIL: next call did not revert as expected] test__unit__dustDepositReverts()` (VegaAccountGuardTest)
- Restored: `SHA256 RESTORED OK (module)`; re-run `25 passed, 0 failed`.

**(e) cross-product guard (MODULE VegaAccountMod.plk, `require(new_total_deposits >= collateral);` -> `let _x = collateral * storedRiskPrice;`)**
- e2e kill: `[FAIL: panic: arithmetic underflow or overflow (0x11)] test__unit__fixedAnchorSequenceDiffers()` (the ~2^200 weight-one step 7 the baseline accepts overflows the checked multiply)
- reused kill: `[FAIL: panic: arithmetic underflow or overflow (0x11)] test__unit__crossProductOverflowsAtLargeDeposit()` (VegaAccountCrossProductMutantTest)
- Restored: `SHA256 RESTORED OK (module)`; re-run `25 passed, 0 failed`.

Every killable mutant reddened the e2e driver `test__unit__fixedAnchorSequenceDiffers` SPECIFICALLY (the new claim this phase proves) in addition to the reused Phase-13/14 sites. cache/fuzz was cleared before every run; the (a) and (b) kills also land on cache-independent UNIT anchors, so they cannot be replays even in principle.

### Two EQUIVALENCE-MASKED mutants — applied, suite STAYED green, documented as NON-kills

- **h-bound `>=`->`>` (LIB):** suite stayed `25 passed, 0 failed` (at hX96==2^96 the denom is 0 and `mulDivRoundingUp` reverts regardless). NOT a kill. Restored sha256-identical.
- **unset-price guard deletion (MODULE):** suite stayed `25 passed, 0 failed` (the lib's mulDiv zero-denominator revert masks it; both revert empty, state unchanged). NOT a kill. Restored sha256-identical.

Final: `sha256sum` of both files == the recorded baselines (lib 2ee07162…bfc7e3, module 555a7a10…818120); source files net-unchanged by the battery.

## PLANK_SKIP exit + make test fold-in (Task 2)

- `PLANK_SKIP :=` is now EMPTY; the rescue-queue comment rewritten to record the queue emptied when VegaAccountMod was PROVEN (VVER-02), not on compile.
- `make test` gained the `--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` guard with a loud comment (routes around the untracked PR-#11 stray that breaks `forge build` of the whole tree; filters no test).
- New `test-vega-e2e` focused target (mirrors test-vega-account/issuance) added to the `.PHONY` line.
- CURRENTLY-RED comment block updated to MEASURED counts.

### Runs of record (verbatim tails)

`make compile`:
```
compile-plank: 11 ok, 1 failed, 0 skipped
make: *** [Makefile:200: compile-plank] Error 1
```

`make test`:
```
Encountered a total of 5 failing tests, 74 tests succeeded

Tip: Run `forge test --rerun` to retry only the 5 failed tests
make: *** [Makefile:51: test] Error 1
```

All 14 vega + e2e suites (25 tests: VegaAccount 12, VegaIssuance 11, e2e 2) passed. The 5 make-test failures are exactly the documented pos_spec harness tests (OrderTest OrderMakeSucceed ×1, SpreadTickAssimetryTest ×2, VolRangeWidthTest ×2), left visible.

## Task Commits

1. **Task 1: Observed-RED mutation battery** — no source commit (the battery restores both `.plk` files byte-identical to HEAD; evidence is this SUMMARY). Verified `git diff --stat` on both source files is empty.
2. **Task 2: Exit PLANK_SKIP + fold vega/e2e into make test** - `e8180b0` (chore)

**Plan metadata:** (final metadata commit) (docs: complete plan)

## Files Created/Modified
- `Makefile` - PLANK_SKIP emptied (rescue-queue comment rewritten); `test:` recipe gains the PriceSetterHook `--skip` guard + loud comment; CURRENTLY-RED comment updated to measured 74/5; `test-vega-e2e` target added + `.PHONY`.
- `.planning/phases/15-.../deferred-items.md` - Logs the out-of-scope OrderHelper.plk / missing src/types/Order.plk finding (OrderType track).
- `src/lib/exposure/VegaIssuanceLib.plk` - net-unchanged (battery restored).
- `src/modules/exposure/VegaAccountMod.plk` - net-unchanged (battery restored).

## Decisions Made
- PLANK_SKIP exit gated on PROOF (the observed-RED battery), not compile. VegaAccountMod compiles standalone AND every killable mutant in it was observed red before the skip line was deleted.
- The OrderHelper.plk / missing Order.plk failure is out of scope and left visible (see deviation below).

## Deviations from Plan

### Finding (out of scope — logged, not fixed)

**1. [Scope boundary] make compile-plank is 11 ok / 1 failed / 0 skipped, NOT the plan's expected 12/0/0**
- **Found during:** Task 2 (running `make compile-plank` after removing VegaAccountMod from PLANK_SKIP).
- **Issue:** `test/types/OrderHelper.plk` (tracked; committed at `3bf788d`) imports `types::Order` from `src/types/Order.plk`, which is present in HEAD but DELETED from the working tree (` D src/types/Order.plk`, unstaged). So `plank build` of that harness fails. It is the compile-side twin of the already-documented `OrderTest OrderMakeSucceed` pos_spec failure; the OrderType track appears mid-move (Order -> pos_spec/VolOrder, the latter green).
- **Why out of scope:** the failure is NOT caused by this change — OrderHelper was never in PLANK_SKIP. Proven independent: with the Makefile change reverted (VegaAccountMod re-skipped), `make compile-plank` still reports `10 ok, 1 failed, 1 skipped`; with the change it is `11 ok, 1 failed, 0 skipped` (VegaAccountMod compiles OK, the intended +1). The plan's `12/0/0` expectation was based on the 14-02 baseline of `11 ok / 0 failed / 1 skipped`, which drifted when the OrderType track deleted Order.plk from disk after planning.
- **Why NOT fixed:** restoring `src/types/Order.plk` from HEAD would clobber another track's intentional working-tree deletion; skipping/filtering OrderHelper.plk would be the dishonest gate-greening the repo explicitly forbids.
- **Action taken:** logged to phase `deferred-items.md`; the VegaAccountMod deliverable (compiles standalone, out of PLANK_SKIP) is MET regardless.
- **Committed in:** `e8180b0` (Makefile CURRENTLY-RED comment + deferred-items.md).

---

**Total deviations:** 1 out-of-scope finding (logged, not fixed). No auto-fixes to source. No scope creep.
**Impact on plan:** VVER-02 fully satisfied (battery + PLANK_SKIP exit). The single deviation is a pre-existing, another-track working-tree regression that blocks the `12/0/0` compile-plank number only; VegaAccountMod itself compiles green and is out of the skip queue.

## Issues Encountered
- The `12 ok, 0 failed, 0 skipped` compile-plank target could not be reached due to the out-of-scope OrderHelper.plk / missing Order.plk failure documented above. Resolved by honest accounting (logged to deferred-items, left visible) rather than papering over it.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- VVER-02 satisfied; VegaAccountMod out of PLANK_SKIP; vega + e2e folded into make test. This closes the Phase 15 acceptance work for milestone v3.0.
- **Do NOT run gsd:complete-milestone** — the milestone close/audit is a SEPARATE user decision after the phase verifier passes (per the plan).
- **Carry-forward blocker (out of scope, for the OrderType/pos_spec track):** restore `src/types/Order.plk` (if the deletion was accidental) or repoint `test/types/OrderHelper.plk` to `types::pos_spec::VolOrder`, to return `make compile-plank` to `12 ok, 0 failed, 0 skipped`. See phase deferred-items.md.
- **Carry-forward blocker (unchanged):** untracked `src/modules/protocol_integrations/PriceSetterHook.sol` still needs the `--skip` on forge targets here; no-op once the owning track removes it.

## Self-Check: PASSED

- FOUND: `.planning/phases/15-.../15-02-SUMMARY.md`
- FOUND: `.planning/phases/15-.../deferred-items.md`
- FOUND commit: `e8180b0` (Task 2)
- VERIFIED: both source `.plk` files net-unchanged (sha256 == recorded baselines lib 2ee07162…bfc7e3 / module 555a7a10…818120)
- VERIFIED: `PLANK_SKIP :=` empty; `test:` has the PriceSetterHook `--skip` guard; `test-vega-e2e` target present

---
*Phase: 15-differential-verification-mutation-battery-plank-skip-exit*
*Completed: 2026-07-18*
