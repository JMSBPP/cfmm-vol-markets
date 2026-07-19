---
phase: 15-differential-verification-mutation-battery-plank-skip-exit
verified: 2026-07-19T12:43:14Z
status: passed
score: 10/10 must-haves verified
---

# Phase 15: Differential Verification & Mutation Battery, PLANK_SKIP Exit Verification Report

**Phase Goal:** The milestone acceptance bar — an end-to-end differential driving identical (setRiskPrice, deposit) sequences into VegaAccountMod and the Solidity reference mock with three accumulators equal at tolerance 0 after EVERY write, the full observed-RED mutation battery, and VegaAccountMod leaving PLANK_SKIP only after deposit is CALLED green — folded into make test.
**Verified:** 2026-07-19T12:43:14Z
**Status:** passed
**Re-verification:** No — initial verification

**Note on staleness:** the 15-02-SUMMARY.md was written before two post-execution repo changes
(commits `a986dc6` + `faeb412`, both by a different track): the Order/OrderHelper/OrderTest
closure was deleted (it had already lost its `Order.plk` dependency out from under it), and the
VolOrder chain — briefly over-swept by a substring grep — was restored. The SUMMARY's recorded
runs (`compile-plank 11 ok/1 failed/0 skipped`, `make test` 74 pass/5 fail including
`OrderTest OrderMakeSucceed`) were historically accurate at their timestamp and are honestly
superseded, not wrong. Current truth, independently re-derived below, is **strictly better** than
what either plan asked for: `compile-plank 11 ok/0 failed/0 skipped` (the plan wanted 12/0/0; the
Order-closure deletion removed a whole entrypoint rather than fixing it, so the "12" ceiling no
longer applies — 0 failures is the operative bar and it is met) and `make test` 74 pass/4 fail (no
`OrderTest` anywhere, the 4 failures being exactly the two named pre-existing pos_spec harnesses).

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | E2E differential drives identical (setRiskPrice, deposit) sequences into VegaAccountMod (FFI-deployed) and IssuanceRefMock-backed mirror; three accumulators equal tol 0 after EVERY write, assertion INSIDE the driver helpers | VERIFIED | `test/exposure/VegaAccount.e2e.t.sol` read in full; `_assertAccumulatorsMatch()` called inside `_setPriceBoth`/`_depositBoth`/`_depositExpectRevertBoth` (lines 99, 112, 123). Re-ran `forge test --match-path 'test/exposure/VegaAccount.e2e.t.sol' ...` on cleared cache: `2 passed, 0 failed, 0 skipped`, fuzz `runs: 256`. |
| 2 | Fixed anchor reproduces the Phase-12 value (deposit=10 at P12 price mints 12 shares) via previewRiskPrice diffed tol-0 vs mock.haircutRiskPrice | VERIFIED | Lines 178-180: `assertEq(p12, mock.haircutRiskPrice(...))` then `assertEq(p12, 60944740395587951995033807951, ...)`; test passes. |
| 3 | Mid-sequence dust deposit reverts on the module and leaves all three accumulators synced with the mirror | VERIFIED | `_depositExpectRevertBoth(1)` at line 189, helper asserts sync post-revert (lines 119-124); test passes. |
| 4 | riskWeightedShares == totalShares asserted as a d==1 consequence via two SEPARATE mirror accumulators | VERIFIED | `_assertAccumulatorsMatch` line 134: `assertEq(mRiskWeighted, mShares, ...)`; `mShares`/`mRiskWeighted` are distinct fields (lines 81-82), never conflated in `_depositBoth` (lines 108-110). |
| 5 | Corpus CONSTRUCTED (bound only, no vm.assume), non-vacuous, mid-sequence re-pricing, ~2^200 weight-one point accepted | VERIFIED | `grep -c 'vm.assume' test/exposure/VegaAccount.e2e.t.sol` = 0; `1 << 200` present (line 197); fuzz sets a new price every iteration (line 232-233); `assertTrue(... != 0, "non-vacuous")` present in both tests. |
| 6 | Each of the FIVE killable mutants produces an OBSERVED RED at the e2e/reused kill sites with cache/fuzz cleared before each | VERIFIED | 15-02-SUMMARY.md records verbatim RED lines for all 5 (a-e). Independently re-derived one end-to-end (shares floor→ceil, LIB): applied mutant, cleared cache/fuzz, re-ran the e2e suite, observed `[FAIL: totalShares: module vs mirror, tol 0: 1013 != 1012] test__unit__fixedAnchorSequenceDiffers()` — byte-identical to the SUMMARY's recorded line for mutant (b). |
| 7 | After each mutant restored, sha256sum matches the recorded baseline and the suite re-runs GREEN | VERIFIED | Restored via `git checkout HEAD --`; `sha256sum src/lib/exposure/VegaIssuanceLib.plk` = `2ee071627e25f4fe07b6e78cb5e163435cdfb737b4dcf293939c5a8ae7bfc7e3` (exact match); re-run on cleared cache: `2 passed, 0 failed, 0 skipped`. Both source files currently on disk match both recorded baselines (lib and module) exactly; `git diff --stat` on both is empty. |
| 8 | The two equivalence-masked mutants documented as equivalence-checked defense-in-depth, never counted as kills | VERIFIED | 15-02-SUMMARY.md §"Two EQUIVALENCE-MASKED mutants" explicitly states both stayed green and are NOT kills; `src/lib/exposure/VegaIssuanceLib.plk` lines 17-20 carry the in-source equivalence note for the h-bound case. |
| 9 | VegaAccountMod OUT of PLANK_SKIP; module compiles standalone; `make compile` clean | VERIFIED | `grep -n 'PLANK_SKIP' Makefile` → `PLANK_SKIP    :=` (empty, line 171). Re-ran `make compile`: tail `compile-plank: 11 ok, 0 failed, 0 skipped` (current truth — see staleness note; strictly meets "module proven, no failures" bar; the plan's literal "12" figure was superseded by an orthogonal closure deletion on a different track, not by a regression here). |
| 10 | `make test` compiles (PriceSetterHook skipped) and runs; vega + e2e tests pass; pre-existing pos_spec failures REMAIN visible (never filtered) | VERIFIED | Re-ran `make test` on cleared cache/fuzz: `74 tests passed, 4 failed`; e2e suite `[PASS] test__fuzz__randomSequenceDiffers`, `[PASS] test__unit__fixedAnchorSequenceDiffers`; the 4 failures are exactly `VolRangeWidthTest` (2) + `SpreadTickAssimetryTest` (2), named and visible, not skipped; `grep -rn OrderTest test/` finds none (the closure was deleted by an out-of-scope track, not by this phase). |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/exposure/VegaAccount.e2e.t.sol` | E2E (setRiskPrice, deposit) sequence differential; contract `VegaAccountE2EDiffTest`; >= 120 lines | VERIFIED | 246 lines; contract present; helpers + fixed anchor + 256-run fuzz all present and green. |
| `Makefile` — PLANK_SKIP empty, test: with PriceSetterHook skip, test-vega-e2e target | VERIFIED | `PLANK_SKIP    :=` empty (line 171); `test:` recipe carries `--skip 'src/modules/protocol_integrations/PriceSetterHook.sol'` (line 50); `test-vega-e2e` target (line 130) present and in `.PHONY` (line 133). |
| `src/modules/exposure/VegaAccountMod.plk` — restored to recorded baseline, contains `SLOT_RISK_WEIGHTED_SHARES` | VERIFIED | `sha256sum` = `555a7a100b97f41bcdf3604141065fc2fe3a1e2d63a5ec9ffcb12b9172818120`, exact match; `grep -c SLOT_RISK_WEIGHTED_SHARES` present. |
| `src/lib/exposure/VegaIssuanceLib.plk` — restored to recorded baseline, contains `mulDivRoundingUp` | VERIFIED | `sha256sum` = `2ee071627e25f4fe07b6e78cb5e163435cdfb737b4dcf293939c5a8ae7bfc7e3`, exact match; `mulDivRoundingUp` present (haircut_risk_price). |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `test/exposure/VegaAccount.e2e.t.sol` | `src/modules/exposure/VegaAccountMod.plk` | `deployPlank("src/modules/exposure/VegaAccountMod.plk")` (FFI) | WIRED | Line 86: `acct = IVegaAccount(deployPlank("src/modules/exposure/VegaAccountMod.plk"));` — called in `setUp()`, exercised by every test. |
| `test/exposure/VegaAccount.e2e.t.sol` | `test/mocks/IssuanceRefMock.sol` | `mock.issueShares` / `mock.haircutRiskPrice` | WIRED | Lines 107, 179: both mock functions called as the mirror's expected-value source, used inside the assertion-bearing helpers. |
| `Makefile test:` target | whole forge suite incl. vega + e2e | `forge test --skip PriceSetterHook.sol` | WIRED | Confirmed via live re-run: `make test` compiles the whole tree and runs 78 total tests including the 2 e2e tests. |
| `Makefile PLANK_SKIP` | `make compile-plank` 0 skipped | VegaAccountMod.plk line deleted | WIRED | `PLANK_SKIP` empty; `make compile` re-run shows `0 skipped`. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| VVER-01 | 15-01-PLAN.md | End-to-end differential, three accumulators tol-0 after every write, assertion inside driver, one file with unit anchor + fuzz | SATISFIED | Truths 1-5 above; REQUIREMENTS.md line 122 `[x]`; ROADMAP traceability row `Complete`. |
| VVER-02 | 15-02-PLAN.md | Observed-RED mutation battery (5 killable, 2 equivalence-masked), PLANK_SKIP exit gated on proof, folded into make test | SATISFIED | Truths 6-10 above; REQUIREMENTS.md line 123 `[x]`; ROADMAP traceability row `Complete`. |

No orphaned requirements found for this phase.

**ROADMAP.md consistency note (non-blocking documentation drift):** the phase-summary traceability
table (line 403, `15. Differential Verification & Mutation Battery, PLANK_SKIP Exit | 2/2 | Complete
| 2026-07-19`) is accurate and consistent with the codebase. However the phase's own checkbox
(line 324, `- [ ] **Phase 15: ...`) and the per-plan list (line 391, `- [ ] 15-01-PLAN.md ...`) are
stale — `15-01` shows unchecked despite its SUMMARY existing and its work being folded in and proven
by `15-02`. This is cosmetic ROADMAP bookkeeping (the phase-verifier gate has not run before now to
flip these), not a functional gap; the goal-relevant artifacts and the traceability table are correct.
STATE.md's `stopped_at`/`Current Position` fields are similarly stale (describe "15-01 complete;
15-02 pending"), predating `e186adc`'s bookkeeping-completion commit. Recommend the orchestrator
flip these three checkboxes/fields as part of closing this phase, but this does not block "passed".

### Anti-Patterns Found

None. Scanned `test/exposure/VegaAccount.e2e.t.sol`, `src/lib/exposure/VegaIssuanceLib.plk`,
`src/modules/exposure/VegaAccountMod.plk`, and `Makefile` for TODO/FIXME/placeholder/empty-return
patterns — none found. No stub handlers, no empty implementations.

### Independent Re-Kill (zero-trust reproduction)

Per the verification brief, independently re-killed mutant (b) (shares floor→ceil, LIB
`issue_shares`: `mulDiv` → `mulDivRoundingUp`) end-to-end, outside of and in addition to what either
SUMMARY recorded:

1. Applied the edit to `src/lib/exposure/VegaIssuanceLib.plk` line 33.
2. `sha256sum` confirmed the file changed (`445642238fb6e...` != baseline).
3. `rm -rf cache/fuzz`; ran `forge test --match-path 'test/exposure/VegaAccount.e2e.t.sol' --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize`.
4. Observed RED: `[FAIL: totalShares: module vs mirror, tol 0: 1013 != 1012] test__unit__fixedAnchorSequenceDiffers()` plus a fuzz counterexample — the unit-anchor failure is byte-for-byte identical to 15-02-SUMMARY.md's recorded line for mutant (b).
5. Restored via `git checkout HEAD -- src/lib/exposure/VegaIssuanceLib.plk`; `sha256sum` = `2ee071627e25f4fe07b6e78cb5e163435cdfb737b4dcf293939c5a8ae7bfc7e3` (exact baseline match).
6. Re-ran on cleared cache: `2 passed, 0 failed, 0 skipped`.
7. `git diff --stat` on the file post-restore: empty (no residual change).

This independently confirms the e2e corpus is rounding-sensitive at the shares-floor site, as
claimed by 15-02, using a fresh execution rather than trusting the SUMMARY's transcript.

### Human Verification Required

None. All must-haves were verifiable programmatically via direct re-execution of the specified
commands and inspection of the resulting source/output.

### Gaps Summary

No gaps. All must-haves from both 15-01-PLAN.md and 15-02-PLAN.md frontmatter were independently
re-derived against the CURRENT working tree (not merely read from the SUMMARYs):

- `make compile` → `compile-plank: 11 ok, 0 failed, 0 skipped`, `PLANK_SKIP` empty.
- `make test` (cache/fuzz cleared) → `74 tests passed, 4 failed`, the 4 being exactly
  `VolRangeWidthTest` (2) + `SpreadTickAssimetryTest` (2); no vega/e2e/exposure failures; no
  `OrderTest` anywhere.
- E2E suite in isolation (cache cleared) → `2 passed, 0 failed, 0 skipped`, fuzz `runs: 256`.
- Both source baselines' sha256 match exactly.
- One mutant independently re-applied, re-killed (RED line byte-identical to the SUMMARY's), and
  restored (sha256 exact, suite green, no residual diff).
- `VegaAccount.e2e.t.sol` read in full: assertion inside every driver helper, mirror kept in two
  separate accumulators, no `vm.assume`.
- REQUIREMENTS.md VVER-01/VVER-02 both `[x] Complete`; ROADMAP traceability row `2/2 Complete`.

The two counts that differ from the 15-02-SUMMARY.md's recorded numbers (`11 ok/0 failed` vs the
SUMMARY's `11 ok/1 failed`; `4 fail` vs the SUMMARY's `5 fail`) are the expected, explained
consequence of the two post-execution, out-of-scope commits (`a986dc6`, `faeb412`) noted in the
verification brief — they resolve (not regress) the SUMMARY's one open deviation
(the OrderHelper.plk / missing Order.plk compile failure), and are consistent with
`deferred-items.md`'s description of that finding as belonging to a different track. The only
loose end is that `deferred-items.md` itself is now stale (it still describes the OrderHelper.plk
failure as outstanding) — cosmetic, does not affect this phase's goal.

---

_Verified: 2026-07-19T12:43:14Z_
_Verifier: Claude (gsd-verifier)_
