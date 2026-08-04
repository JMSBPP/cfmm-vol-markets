---
phase: 13-issuance-library-vegaissuancelib
verified: 2026-07-18T00:00:00Z
status: passed
score: 5/5 must-haves verified
---

# Phase 13: Issuance Library (VegaIssuanceLib) Verification Report

**Phase Goal:** The pure issuance library — `haircut_risk_price`, `issue_shares`, and the Lean-lemma fuzz battery — is proven bit-exact against a Solidity reference mock via an FFI-deployed kernel harness, before any module or storage exists, composing the existing `v3::math::full_math::mulDiv` (never reimplemented).
**Verified:** 2026-07-18
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Full suite is CALLED-green with real (non-replay) fuzz counts | ✓ VERIFIED | `rm -rf cache/fuzz && forge test --match-path 'test/exposure/VegaIssuance.diff.t.sol' --skip 'src/modules/protocol_integrations/PriceSetterHook.sol' --via-ir --optimize` — 7 suites, 11 tests passed, 0 failed. Fuzz run counts observed: `priceGeOracle` runs:512, `weightOneIdentity` runs:512, `backingInvariant` runs:512, `composedLeDirect` runs:1024, `composedEqualsMock` runs:1024. |
| 2 | `VegaIssuanceLib.plk` composes `v3::math::full_math` (never reimplements 512-bit math), uses checked `-` | ✓ VERIFIED | File read directly: `import v3::math::full_math::{mulDiv, mulDivRoundingUp};`, body calls `mulDivRoundingUp(oracleX96, TWO_96, denom)` and `mulDiv(deposit, TWO_96, pRiskX96.val)`; subtraction is `TWO_96 - hX96.val` (ASCII `-`, checked); no `-%`, no `@evm_mulmod` or hand-rolled 512-bit body. |
| 3 | Mutation gate is real — at least one mutant independently re-killed by the verifier, then restored byte-identical | ✓ VERIFIED | Applied the shares floor→ceil mutant (`mulDiv`→`mulDivRoundingUp` in `issue_shares`), cleared `cache/fuzz`, re-ran: `[FAIL: shares floor at inexact anchor: 13 != 12] test__unit__anchorComposedEqualsMockAndHandDerived()` — verbatim match to the SUMMARY's recorded FAIL line. 3 other tests also reddened as expected (one-sided, diff, backing). `git checkout` restored the file; `sha256sum` == `2ee071627e25f4fe07b6e78cb5e163435cdfb737b4dcf293939c5a8ae7bfc7e3`, matching the SUMMARY's recorded hash exactly. Re-ran green (11/11) via both direct forge invocation and `make test-vega-issuance`. |
| 4 | Harness selectors are cast-sig-verified, not hand-derived | ✓ VERIFIED | `cast sig "haircutRiskPrice(uint256,uint256)"` → `0x00213e88`; `cast sig "issueShares(uint256,uint256)"` → `0x636ae14a`. Both match `SELECTOR_HAIRCUT_RISK_PRICE`/`SELECTOR_ISSUE_SHARES` constants in `VegaIssuanceKernelHarness.plk` verbatim. |
| 5 | Mock computes the identical ceil-then-floor composition; tolerance-0 vs `composed` is a SEPARATE assertion from the one-sided `composed <= direct` bound (no B1 regression) | ✓ VERIFIED | `IssuanceRefMock.sol` read directly: `haircutRiskPrice` uses `fullMulDivUp` (ceil), `issueShares` uses `fullMulDiv` (floor), no tolerance parameter anywhere. Test file: `assertEq(shares, mock.composed(...), "composed: plank vs mock, tolerance 0")` (2 occurrences, unit anchor + fuzz) is structurally distinct from `assertLe(composed, direct, "one-sided: composed <= direct...")` — different assertion, different mock function (`composed` vs `direct`). |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/lib/exposure/VegaIssuanceLib.plk` | Pure `haircut_risk_price` + `issue_shares` composing `v3::math::full_math` | ✓ VERIFIED | Exists, 34 lines, both functions typed with `Haircut`/`RiskPriceX96` newtypes, composes full_math, checked `-`. sha256 = `2ee071627e25f4fe07b6e78cb5e163435cdfb737b4dcf293939c5a8ae7bfc7e3`. |
| `test/exposure/VegaIssuanceKernelHarness.plk` | FFI ABI harness, cast-verified selectors | ✓ VERIFIED | Exists, selectors recomputed and match (`0x00213e88`, `0x636ae14a`). |
| `test/mocks/IssuanceRefMock.sol` | solady `fullMulDiv(Up)` reference exposing `haircutRiskPrice`/`issueShares`/`composed`/`direct` | ✓ VERIFIED | Exists, all four functions present, no artificial deposit cap (fullMulDiv both paths). |
| `test/exposure/VegaIssuance.diff.t.sol` | Anchor probe + reverts + monotonicity (13-01) + fuzz battery + mutation gate (13-02) | ✓ VERIFIED | 7 contracts, 11 tests, all green. Contains anchor probe, 5 reverting-corpus tests, monotonicity fuzz, backing-invariant fuzz (512-bit via `_mul512`/`_le512`/mulmod, no raw `*`), weight-one identity, composed==mock diff, composed<=direct one-sided. |
| `Makefile` (`test-vega-issuance` target) | Focused target running the differential + fuzz suite | ✓ VERIFIED | `make -n test-vega-issuance` shows the exact `forge test --match-path 'test/exposure/VegaIssuance.diff.t.sol' --skip '...' --via-ir --optimize` invocation; `make test-vega-issuance` run directly: 11/11 passed. Default `make test` target untouched by this phase (grep confirms `test-vega-issuance` is a separate `.PHONY` entry). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `VegaIssuanceLib.plk` | `v3::math::full_math::{mulDiv, mulDivRoundingUp}` | import + compose | ✓ WIRED | Both functions called in the two library functions; no reimplementation found (no `@evm_mulmod` in the lib body). |
| `VegaIssuanceKernelHarness.plk` | `lib::exposure::VegaIssuanceLib` | selector dispatch over whole-word calldata | ✓ WIRED | Import present, `haircut_risk_price`/`issue_shares` called from `run{}` dispatch on the two cast-verified selectors. |
| `VegaIssuance.diff.t.sol` | `deployPlank(harness)` + `IssuanceRefMock` | differential `assertEq` tolerance 0 | ✓ WIRED | `plk = IVegaIssuanceKernel(deployPlank("test/exposure/VegaIssuanceKernelHarness.plk"))`; `mock = new IssuanceRefMock()`; both exercised across all 7 test contracts. |
| `VegaIssuance.diff.t.sol` (backing test) | solady `fullMulDiv`/mulmod 512-bit identity | `_mul512`/`_le512`, no raw `*` | ✓ WIRED | `_mul512` uses the `mulmod(a,b,not(0))` identity in assembly; backing test compares via `_le512`, no raw multiplication in the assertion. `assertGt(hiR, 0, ...)` confirms the corpus genuinely crosses 2^256 (deposit ≥ 2^160). |
| `VegaIssuance.diff.t.sol` | `IssuanceRefMock.direct` | one-sided `composed <= direct` | ✓ WIRED | `direct` appears exactly once, in `test__fuzz__composedLeDirect`'s `assertLe`; not reused in the tolerance-0 diff test. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|--------------|--------|----------|
| VLIB-01 | 13-01 | Pure `haircut_risk_price` = `mulDivRoundingUp(oracleX96, 2^96, 2^96-hX96)`, checked `-`, reverts `hX96≥2^96`/`oracleX96==0`, `p_risk≥oracle` fuzz, no silent-zero | ✓ SATISFIED | Lib body matches; 5 revert tests green; `VegaIssuanceMonotonicityTest.test__fuzz__priceGeOracle` (runs:512) asserts `assertGe(pRisk, oracleX96)`. |
| VLIB-02 | 13-01 | Pure `issue_shares` = `mulDiv(deposit, 2^96, pRiskX96)` floor, reverts `pRiskX96==0`, composes full_math | ✓ SATISFIED | Lib body matches; `test__unit__pRiskZeroReverts` green; composes `mulDiv` (no reimplementation). |
| VLIB-03 | 13-02 | Backing invariant `shares·pRisk ≤ deposit·2^96` (512-bit both sides) + weight-one identity, constructed corpus | ✓ SATISFIED | `VegaIssuanceBackingTest` (512-bit via mulmod identity, runs:512) and `VegaIssuanceWeightOneTest` (runs:512) both green; `grep -c vm.assume` = 0. |
| VLIB-04 | 13-02 | Composed diffed vs solady mock at tolerance 0 via FFI harness; separate one-sided `composed≤direct` fuzz; non-fuzz anchor at inexact-division point | ✓ SATISFIED | Anchor probe green (pRisk = 60944740395587951995033807951, shares = 12); `VegaIssuanceDiffTest` (tolerance-0, runs:1024) and `VegaIssuanceOneSidedTest` (runs:1024) both green and structurally separate. |

Traceability cross-checked against `.planning/REQUIREMENTS.md`: lines 107-110 all `[x]`, lines 213-216 traceability table all `Complete` for VLIB-01..04 — consistent with the evidence above. No orphaned requirements found for Phase 13 in REQUIREMENTS.md.

### Anti-Patterns Found

None. `grep -n -iE "TODO|FIXME|XXX|HACK|PLACEHOLDER|not implemented|coming soon"` across `VegaIssuanceLib.plk`, `VegaIssuance.diff.t.sol`, `VegaIssuanceKernelHarness.plk`, `IssuanceRefMock.sol` returned no matches. `grep -c vm.assume` in the test file returns 0 (constructed corpora only, per project standard).

### Human Verification Required

None. All claims in this phase are mechanically checkable (bytecode-level FFI differential, cast-sig selector recomputation, sha256 restore verification, forge fuzz run counts) and were independently re-derived above — no visual, real-time, or subjective-quality items apply to a pure-function library phase.

### Gaps Summary

None. All five derived observable truths verified, all five required artifacts present and wired at all three levels, all four requirement IDs (VLIB-01..04) satisfied with direct evidence, one mutant independently re-killed with a verbatim-matching FAIL line and byte-identical sha256 restore, and the known out-of-scope build blocker (`src/modules/protocol_integrations/PriceSetterHook.sol`, untracked, another track's WIP) is correctly logged in `deferred-items.md` and does not affect this phase's committed deliverables — confirmed by running the exact suite command with the documented `--skip` workaround, per the plan's own acceptance criteria.

---

*Verified: 2026-07-18*
*Verifier: Claude (gsd-verifier)*
