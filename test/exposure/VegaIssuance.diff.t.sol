// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PlankTestBase} from "../PlankTestBase.sol";
import {IssuanceRefMock} from "../mocks/IssuanceRefMock.sol";

// ===========================================================================================
// THE VegaIssuanceLib differential suite. Everything that exercises the PURE issuance library
// src/lib/exposure/VegaIssuanceLib.plk -- through its FFI harness
// test/exposure/VegaIssuanceKernelHarness.plk -- lives in THIS FILE. Phase 13-02 EXTENDS it
// (composed<=direct one-sided fuzz, shares*pRisk<=deposit*2^96 backing invariant, mutation
// battery); do NOT fork a second file.
//
// GLOBAL RULE: "it compiles" is never acceptance. `plank build` does NOT type-check code
// unreachable from run{} -- deployPlank -> plankDeployFFI -> plankBuildFFI shells out to
// `plank build` over FFI AT TEST TIME, so every assertion below runs the DEPLOYED bytecode.
// Only a CALLED selector outcome proves the lib exists.
//
// The tolerance-0 differential is IDENTICAL-ALGORITHM ONLY: the Plank composed path vs
// IssuanceRefMock's ceil-then-floor composition over solady fullMulDiv(Up). It is NEVER claimed
// vs the `direct` path -- exact cross-path equality is FALSE in integers (risk.md §4).
// ===========================================================================================

/// @notice The harness ABI. haircutRiskPrice returns p_risk = RiskPriceX96.val; issueShares
///         returns the floored shares. Selectors cast-verified in the harness header
///         (0x00213e88 / 0x636ae14a).
interface IVegaIssuanceKernel {
    function haircutRiskPrice(uint256 oracleX96, uint256 hX96) external view returns (uint256);
    function issueShares(uint256 deposit, uint256 pRiskX96) external view returns (uint256);
}

/// @title VegaIssuanceKernelProbeTest
/// @notice The WIRING proof + the inexact-division anchor. Proves the lib is reachable over the
///         ABI and AGREES, on ONE point, with both IssuanceRefMock's composed path (tolerance 0)
///         AND an externally hand-derived anchor (risk.md §4).
///
/// @dev WHY THIS ANCHOR -- BOTH HOPS INEXACT. deposit=10, oracleX96=10*2^92, hX96=3*2^92 so
///      2^96-hX96 = 13*2^92. oracleX96*2^96 = 160*2^184 and 160 mod 13 = 4, so the p_risk
///      division is INEXACT and rounds UP to 60944740395587951995033807951. Then
///      mulDiv(10, 2^96, pRisk) floors to 12 (the direct path would floor to 13). Because BOTH
///      divisions are inexact, this single point pins BOTH rounding sites: a p_risk ceil->floor
///      mutant yields pRisk-1 and flips shares 12->13; a shares floor->ceil mutant also yields 13.
///      An exact-division anchor would kill NEITHER. Do not weaken this input.
///
/// @dev WHY THE EXTERNAL ANCHOR IS LOAD-BEARING. A purely differential assertion (plank == mock)
///      is satisfied by a mock that merely ECHOED Plank. Pinning mock.composed to the
///      hand-derived 12 makes both sides answer to a number neither implementation can influence.
contract VegaIssuanceKernelProbeTest is PlankTestBase {
    IVegaIssuanceKernel plk;
    IssuanceRefMock mock;

    // risk.md §4 -- both hops inexact. Reused verbatim; NOT a new anchor.
    uint256 constant DEPOSIT = 10;
    uint256 constant ORACLE_X96 = 10 * (2 ** 92);
    uint256 constant HX96 = 3 * (2 ** 92);
    uint256 constant EXP_PRISK = 60944740395587951995033807951; // hand-derived, triple-checked
    uint256 constant EXP_SHARES = 12; // composed; direct would be 13

    function setUp() public {
        plk = IVegaIssuanceKernel(deployPlank("test/exposure/VegaIssuanceKernelHarness.plk"));
        mock = new IssuanceRefMock();
    }

    /// @notice The pointwise anchor + tolerance-0 differential + external pin, all CALLED through
    ///         the FFI-deployed harness bytecode.
    function test__unit__anchorComposedEqualsMockAndHandDerived() public {
        uint256 pRisk = plk.haircutRiskPrice(ORACLE_X96, HX96);
        assertEq(pRisk, EXP_PRISK, "p_risk ceil at inexact anchor");

        uint256 shares = plk.issueShares(DEPOSIT, pRisk);
        assertEq(shares, EXP_SHARES, "shares floor at inexact anchor");

        // Tolerance-0 differential, IDENTICAL algorithm both sides.
        assertEq(shares, mock.composed(DEPOSIT, ORACLE_X96, HX96), "composed: plank vs mock, tolerance 0");

        // External anchor pins the mock so a mock that merely echoed Plank cannot pass.
        assertEq(mock.composed(DEPOSIT, ORACLE_X96, HX96), EXP_SHARES, "mock composed vs hand-derived anchor 12");

        // Non-degeneracy guard: the anchor MUST be an inexact-division point, else it kills no
        // rounding mutant.
        assertTrue(shares != DEPOSIT, "anchor must be an inexact-division point (else it kills no rounding mutant)");
    }
}

/// @title VegaIssuanceRevertTest
/// @notice The CONSTRUCTED reverting corpora (VLIB-01/02). Each revert is ASSERTED via
///         vm.expectRevert on the FFI-deployed harness -- NEVER inferred from an empty return.
///         Mechanics identical to RealizedVolatilitySmokeTest.zeroPeriodReverts/doubleInitReverts.
///
/// @dev The Plank lib reverts EMPTY (revert_empty / full_math zero-denominator), so a bare
///      vm.expectRevert() (any revert) is the correct expectation -- do not assert a selector.
contract VegaIssuanceRevertTest is PlankTestBase {
    IVegaIssuanceKernel plk;

    function setUp() public {
        plk = IVegaIssuanceKernel(deployPlank("test/exposure/VegaIssuanceKernelHarness.plk"));
    }

    /// @notice hX96 == 2^96: denom = 2^96 - hX96 = 0, mulDivRoundingUp's zero-denominator revert
    ///         (also caught by the explicit h>=2^96 guard).
    function test__unit__hEqualsOneReverts() public {
        vm.expectRevert();
        plk.haircutRiskPrice(2 ** 96, 2 ** 96);
    }

    /// @notice hX96 == 2^96 + 1: the checked subtraction 2^96 - hX96 underflows and reverts.
    function test__unit__hAboveOneReverts() public {
        vm.expectRevert();
        plk.haircutRiskPrice(2 ** 96, (2 ** 96) + 1);
    }

    /// @notice hX96 == 2^256 - 1: far above 2^96, checked subtraction reverts.
    function test__unit__hMaxReverts() public {
        vm.expectRevert();
        plk.haircutRiskPrice(2 ** 96, type(uint256).max);
    }

    /// @notice oracleX96 == 0: explicit guard rejects the silent p_risk=0 path (VLIB-01).
    function test__unit__oracleZeroReverts() public {
        vm.expectRevert();
        plk.haircutRiskPrice(0, 3 * (2 ** 92));
    }

    /// @notice pRiskX96 == 0: mulDiv's zero-denominator check reverts (VLIB-02).
    function test__unit__pRiskZeroReverts() public {
        vm.expectRevert();
        plk.issueShares(10, 0);
    }
}

/// @title VegaIssuanceMonotonicityTest
/// @notice VLIB-01, `haircutRiskPrice_ge_oracle`: p_risk >= oracle on every constructed fuzz run.
///         The corpus is CONSTRUCTED (bound), never assume-filtered.
///
/// @dev WHY THE BOUND. p_risk = oracle*2^96/denom. With oracleX96 in [1, 2^96] and hX96 in
///      [0, 2^96), denom = 2^96 - hX96 in [1, 2^96], so p_risk <= 2^96*2^96 = 2^192 < 2^256 --
///      mulDivRoundingUp never overflow-reverts. This keeps every run a LIVE assertion.
///
/// @dev WHAT THIS DOES NOT DO. This fuzz ALONE cannot kill a ceil->floor mutant: floor also
///      satisfies p_risk >= oracle. The rounding is pinned by the inexact anchor in
///      VegaIssuanceKernelProbeTest and by 13-02's mutation gate. This test owns ONLY the
///      monotonicity lemma across the domain.
contract VegaIssuanceMonotonicityTest is PlankTestBase {
    IVegaIssuanceKernel plk;

    function setUp() public {
        plk = IVegaIssuanceKernel(deployPlank("test/exposure/VegaIssuanceKernelHarness.plk"));
    }

    /// forge-config: default.fuzz.runs = 512
    function test__fuzz__priceGeOracle(uint256 oRaw, uint256 hRaw) public {
        // oracleX96 in [1, 2^96], hX96 in [0, 2^96): p_risk stays < 2^256 (see docblock).
        uint256 oracleX96 = bound(oRaw, 1, 2 ** 96);
        uint256 hX96 = bound(hRaw, 0, (2 ** 96) - 1);
        uint256 pRisk = plk.haircutRiskPrice(oracleX96, hX96);
        assertGe(pRisk, oracleX96, "haircutRiskPrice_ge_oracle: p_risk >= oracle on every run");
    }
}

// ===========================================================================================
// 13-02 EXTENSION: the Lean-lemma fuzz battery (VLIB-03 backing invariant + weight-one;
// VLIB-04 composed==mock tolerance-0 + one-sided composed<=direct). Each contract reuses the
// SAME harness (deployPlank) and mock (IssuanceRefMock) as the 13-01 contracts above; corpora
// are CONSTRUCTED via bound() only (never assume-filtered); forge runs --via-ir --optimize.
//
// Overflow-safety of the corpora (machine-verified this phase):
//   issue_shares = mulDiv(deposit, 2^96, pRisk) reverts (result >= 2^256) IFF deposit >= 2^160*pRisk.
//   With oracleX96 >= 2^96 the haircut raises pRisk >= oracle >= 2^96, so 2^160*pRisk >= 2^256 >
//   deposit for ANY deposit < 2^256 -- issue_shares NEVER overflows and `deposit` can be full u256.
//   direct = mulDiv(deposit, 2^96-hX96, oracleX96) likewise never overflows when oracleX96 >= 2^96.
//   => bound oracleX96 in [2^96, 2^160], hX96 in [0, 2^96), deposit full u256 (or [2^160, 2^256)
//      on the backing corpus so BOTH products cross 2^256 and the 512-bit path is genuinely run).
// ===========================================================================================

/// @title VegaIssuanceBackingTest
/// @notice VLIB-03 backing invariant `shares*pRisk <= deposit*2^96`, a PLAIN floor-division
///         property (NOT mulX96Down_le -- that is the deferred distance-pipeline weight clamp).
///         Both sides are computed in GENUINE 512-bit arithmetic (mulmod identity + lexicographic
///         (hi,lo) compare); there is NO raw `shares*pRisk` / `deposit*Q96` in the assertion,
///         because above deposit ~ 2^160 both products exceed 2^256 and a raw `*` would wrap.
///
/// @dev The corpus draws deposit in [2^160, 2^256) so the invariant is exercised in a regime the
///      512-bit path is REQUIRED for; assertGt(hiL, 0) proves that regime is genuinely reached
///      (a vacuous 256-bit corpus would leave hiL == 0 and prove nothing about 512-bit backing).
contract VegaIssuanceBackingTest is PlankTestBase {
    IVegaIssuanceKernel plk;

    uint256 constant Q96 = 1 << 96;

    function setUp() public {
        plk = IVegaIssuanceKernel(deployPlank("test/exposure/VegaIssuanceKernelHarness.plk"));
    }

    /// @dev Full 512-bit product (hi, lo) = a*b via the mulmod identity. NO raw a*b comparison.
    function _mul512(uint256 a, uint256 b) internal pure returns (uint256 hi, uint256 lo) {
        assembly {
            let mm := mulmod(a, b, not(0))
            lo := mul(a, b)
            hi := sub(sub(mm, lo), lt(mm, lo))
        }
    }

    /// @dev (hiA,loA) <= (hiB,loB), unsigned lexicographic.
    function _le512(uint256 hiA, uint256 loA, uint256 hiB, uint256 loB) internal pure returns (bool) {
        return hiA < hiB || (hiA == hiB && loA <= loB);
    }

    /// forge-config: default.fuzz.runs = 512
    function test__fuzz__backingInvariant(uint256 oRaw, uint256 hRaw, uint256 dRaw) public {
        // Upper bound 2^160-1 (NOT 2^160): at oracleX96==2^160 AND denom==1 (hX96==2^96-1)
        // haircut_risk_price computes 2^160*2^96 = 2^256 and mulDivRoundingUp OVERFLOW-reverts.
        // 2^160-1 keeps pRisk in-range for every hX96 while deposit>=2^160 still crosses 2^256.
        uint256 oracleX96 = bound(oRaw, Q96, 2 ** 160 - 1); // >= 2^96 => pRisk >= 2^96 => no overflow
        uint256 hX96 = bound(hRaw, 0, Q96 - 1);
        uint256 deposit = bound(dRaw, 2 ** 160, type(uint256).max); // force both products past 2^256
        uint256 pRisk = plk.haircutRiskPrice(oracleX96, hX96);
        uint256 shares = plk.issueShares(deposit, pRisk);
        (uint256 hiL, uint256 loL) = _mul512(shares, pRisk); // shares * pRisk
        (uint256 hiR, uint256 loR) = _mul512(deposit, Q96); // deposit * 2^96
        assertTrue(_le512(hiL, loL, hiR, loR), "backing: shares*pRisk <= deposit*2^96 (512-bit)");
        assertGt(hiR, 0, "backing corpus must genuinely exceed 2^256 (else 512-bit path is vacuous)");
    }
}

/// @title VegaIssuanceWeightOneTest
/// @notice VLIB-03 weight-one identity (`mulX96Down_one` mirror): with pRisk == 2^96 the Q96 scale
///         cancels exactly, so `issue_shares(deposit, 2^96) == deposit` for EVERY deposit.
contract VegaIssuanceWeightOneTest is PlankTestBase {
    IVegaIssuanceKernel plk;

    function setUp() public {
        plk = IVegaIssuanceKernel(deployPlank("test/exposure/VegaIssuanceKernelHarness.plk"));
    }

    /// forge-config: default.fuzz.runs = 512
    function test__fuzz__weightOneIdentity(uint256 dRaw) public {
        uint256 deposit = bound(dRaw, 0, type(uint256).max);
        assertEq(plk.issueShares(deposit, 1 << 96), deposit, "issue_shares(deposit, 2^96) == deposit");
    }
}

/// @title VegaIssuanceDiffTest
/// @notice VLIB-04 tolerance-0 composed differential. The Plank composed path
///         (ceil p_risk then floor shares) equals IssuanceRefMock.composed (the IDENTICAL
///         ceil-then-floor over solady fullMulDiv(Up)) at tolerance 0 across the whole domain.
///
/// @dev IDENTICAL-ALGORITHM ONLY. The tolerance-0 claim is made vs `mock.composed` alone (same
///      rounding at the same two sites both sides). It is NEVER made vs `mock.direct` -- that path
///      rounds at a DIFFERENT point (risk.md §4) and its exact equality is FALSE (the 12-vs-13
///      counterexample). Asserting tolerance-0 vs direct re-introduces review BLOCKER B1; the
///      direct path lives ONLY in VegaIssuanceOneSidedTest below as a `<=` bound.
contract VegaIssuanceDiffTest is PlankTestBase {
    IVegaIssuanceKernel plk;
    IssuanceRefMock mock;

    function setUp() public {
        plk = IVegaIssuanceKernel(deployPlank("test/exposure/VegaIssuanceKernelHarness.plk"));
        mock = new IssuanceRefMock();
    }

    /// forge-config: default.fuzz.runs = 1024
    function test__fuzz__composedEqualsMock(uint256 oRaw, uint256 hRaw, uint256 dRaw) public {
        // 2^160-1 upper bound: oracleX96==2^160 with denom==1 overflow-reverts haircut_risk_price.
        uint256 oracleX96 = bound(oRaw, 1 << 96, 2 ** 160 - 1);
        uint256 hX96 = bound(hRaw, 0, (1 << 96) - 1);
        uint256 deposit = bound(dRaw, 0, type(uint256).max);
        uint256 pRisk = plk.haircutRiskPrice(oracleX96, hX96);
        uint256 shares = plk.issueShares(deposit, pRisk);
        assertEq(shares, mock.composed(deposit, oracleX96, hX96), "composed: plank vs mock, tolerance 0");
    }
}

/// @title VegaIssuanceOneSidedTest
/// @notice VLIB-04 one-sided `issuance_haircut_equiv` integer transfer. `issuance_haircut_equiv`
///         is proven over ℝ only; in integers the composed path (ceil then floor) and the direct
///         path (single floor) round at different points, so exact equality is FALSE (risk.md §4).
///         Only the one-sided bound `composed <= direct` holds -- the anchor point (12 < 13) is
///         itself an inexact witness that this is a STRICT inequality somewhere, not vacuous.
///
/// @dev This is the ONLY place `mock.direct` appears. Getting (C) and (D) backwards -- claiming
///      tolerance-0 vs direct instead of a <= bound -- is review BLOCKER B1 (the 12-vs-13
///      counterexample). direct = mulDiv(deposit, 2^96-hX96, oracleX96).
contract VegaIssuanceOneSidedTest is PlankTestBase {
    IVegaIssuanceKernel plk;
    IssuanceRefMock mock;

    function setUp() public {
        plk = IVegaIssuanceKernel(deployPlank("test/exposure/VegaIssuanceKernelHarness.plk"));
        mock = new IssuanceRefMock();
    }

    /// forge-config: default.fuzz.runs = 1024
    function test__fuzz__composedLeDirect(uint256 oRaw, uint256 hRaw, uint256 dRaw) public {
        // 2^160-1 upper bound: oracleX96==2^160 with denom==1 overflow-reverts haircut_risk_price.
        uint256 oracleX96 = bound(oRaw, 1 << 96, 2 ** 160 - 1);
        uint256 hX96 = bound(hRaw, 0, (1 << 96) - 1);
        uint256 deposit = bound(dRaw, 0, type(uint256).max);
        uint256 pRisk = plk.haircutRiskPrice(oracleX96, hX96);
        uint256 composed = plk.issueShares(deposit, pRisk);
        uint256 direct = mock.direct(deposit, oracleX96, hX96);
        assertLe(composed, direct, "one-sided: composed <= direct (exact equality is FALSE in integers)");
    }
}
