// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";

// ===========================================================================================
// V2-04 ACCEPTANCE: the lens READOUTS of the auto-deleverage law + endogenous maturity
// (vol-order-v2-target-vega-SPEC.md D5; math block "VOL ORDER COMPLETION" in
// VOLATILITY_INSTRUMENTS.md; EndogenousMaturity.lean, run 128b24ae; t_mult selected by the
// author 2026-07-30).
//
//   dqvFunded(DeltaQ_v*, Q_M, pRiskX96) = min(DeltaQ_v*, floor(Q_M * 2^96 / pRiskX96))
//     -- the GREATEST admissible exposure (Lean: dQvFunded_maximal), computed ONLY through
//        the mulDiv form (a bare product would revert-DoS as p_risk grows; units table §4).
//   impliedMaturity(dqv, N_sigma) = floor(2 * dqv / N_sigma)          [SECONDS; N_sigma L/s]
//   impliedMaturityMult(dqv, N_sigma, sig2R, sig2K)
//     = floor( impliedMaturity * (sig2K - sig2R)+ / sig2K )           [t*_mult, clamped]
//
// THE FLOOR-MAXIMALITY PROPERTY TEST is the pinned predicate #13's enforcer INHERITS:
//   dqv_e * pRisk <= Q_M * 2^96   AND   ( (dqv_e + 1) * pRisk > Q_M * 2^96  OR  dqv_e = DeltaQ_v* )
//
// Lean lemma mirrors (names in assertions): dQvFunded_maximal, dQvFunded_admissible,
// dQvFunded_eq_of_no_violation, dQvFunded_zero_QM, tStarFunded_mono_QM,
// tStarFunded_antitone_prisk, tStarFunded_eq_tStar_of_topup, tStarJoint (mult) sanity.
//
// MUTANTS killed: min dropped (funded > target)     -> no-violation identity + maximality
//                 ceil instead of floor on the level -> admissibility half of the property
//                 clamp dropped in t_mult             -> sig2R >= sig2K zero case
//                 t_mult division order swapped       -> the exact-value anchors
// ===========================================================================================
interface IVegaLensReadouts {
    function dqvFunded(uint256 targetVega, uint256 qM, uint256 pRiskX96) external view returns (uint256);
    function impliedMaturity(uint256 dqv, uint256 nSigma) external view returns (uint256);
    function impliedMaturityMult(uint256 dqv, uint256 nSigma, uint256 sig2R, uint256 sig2K)
        external view returns (uint256);
}

contract VegaLensReadoutsTest is PlankTestBase {
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    IVegaLensReadouts internal lens;

    function setUp() public {
        lens = IVegaLensReadouts(deployPlank("test/exposure/VegaLensReadoutsHarness.plk"));
    }

    // ------------------------------------------------------------------ dqvFunded

    // THE PROPERTY TEST (#13's inherited predicate): admissible AND maximal, mulDiv form.
    // forge-config: default.fuzz.runs = 256
    function test__fuzz__floorMaximality(uint96 tvR, uint128 qMR, uint160 pR) public {
        uint256 tv = bound(uint256(tvR), 1, type(uint96).max);
        uint256 qM = bound(uint256(qMR), 0, type(uint128).max);
        uint256 pRisk = bound(uint256(pR), 1, type(uint160).max); // p_risk > 0 (admissible_iff_mul hypothesis)

        uint256 e = lens.dqvFunded(tv, qM, pRisk);

        // dQvFunded_admissible: e * pRisk <= qM * 2^96  (checked in 512-bit-safe form)
        assertLe(_mul512Hi(e, pRisk, qM), 0, "dQvFunded_admissible (mulDiv form)");
        // dQvFunded_maximal: e+1 inadmissible OR e == target
        if (e != tv) {
            assertGt(_mul512Hi(e + 1, pRisk, qM), 0, "dQvFunded_maximal: e+1 overshoots");
        }
        assertLe(e, tv, "never exceeds the target");
    }

    /// @dev returns 1 if a*b > c*2^96 else 0, without overflowing (uses mulDiv comparison).
    function _mul512Hi(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        // a*b <= c*2^96  <=>  a <= mulDiv(c, 2^96, b)  when b > 0 (floor on the right is safe
        // for the <= direction: a <= floor(x) <=> a <= x for integer a)
        uint256 lvl = mulDivFloor(c, Q96, b);
        return a <= lvl ? 0 : 1;
    }

    function mulDivFloor(uint256 a, uint256 b, uint256 d) internal pure returns (uint256) {
        unchecked {
            // 512-bit mulDiv (solady-style compact) -- d > 0 guaranteed by callers
            uint256 p0; uint256 p1;
            assembly {
                let mm := mulmod(a, b, not(0))
                p0 := mul(a, b)
                p1 := sub(sub(mm, p0), lt(mm, p0))
            }
            if (p1 == 0) return p0 / d;
            uint256 r;
            assembly {
                r := mulmod(a, b, d)
                p1 := sub(p1, gt(r, p0))
                p0 := sub(p0, r)
                let t := and(d, sub(0, d))
                d := div(d, t)
                let inv := xor(mul(3, d), 2)
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                inv := mul(inv, sub(2, mul(d, inv)))
                p0 := mul(or(mul(p1, add(div(sub(0, t), t), 1)), div(p0, t)), inv)
            }
            return p0;
        }
    }

    // dQvFunded_eq_of_no_violation: fully funded -> the target itself.
    function test__unit__noViolationIdentity() public {
        uint256 tv = 5e20;
        uint256 pRisk = 3 * Q96; // 3 collateral per L unit
        uint256 qM = 2e21; // >= tv * 3 -> no violation
        assertEq(lens.dqvFunded(tv, qM, pRisk), tv, "dQvFunded_eq_of_no_violation");
    }

    // dQvFunded_zero_QM: liquidation degenerate case.
    function test__unit__zeroCollateralZeroExposure() public {
        assertEq(lens.dqvFunded(5e20, 0, Q96), 0, "dQvFunded_zero_QM");
    }

    // tStarFunded_mono_QM / _antitone_prisk (on the funded level, through the maturity map).
    function test__unit__fundedLevelMonotonicity() public {
        uint256 tv = 1e21;
        uint256 p1 = 2 * Q96;
        assertLe(lens.dqvFunded(tv, 1e20, p1), lens.dqvFunded(tv, 2e20, p1), "tStarFunded_mono_QM");
        assertGe(lens.dqvFunded(tv, 1e20, p1), lens.dqvFunded(tv, 1e20, 3 * Q96), "tStarFunded_antitone_prisk");
    }

    // ------------------------------------------------------------------ implied maturity

    function test__unit__impliedMaturitySeconds() public {
        // dqv = 1e18 L, N_sigma = 4e15 L/s -> t* = 2*1e18/4e15 = 500 seconds exactly.
        assertEq(lens.impliedMaturity(1e18, 4e15), 500, "t* = 2 dqv / N_sigma, seconds");
        // floor: 2*1e18/3e15 = 666.66 -> 666
        assertEq(lens.impliedMaturity(1e18, 3e15), 666, "floor rounding");
    }

    // tStarFunded_eq_tStar_of_topup: full funding restores the full maturity EXACTLY.
    function test__unit__topupRestoresMaturity() public {
        uint256 tv = 6e20;
        uint256 nSigma = 3e15;
        uint256 pRisk = 2 * Q96;
        uint256 tFull = lens.impliedMaturity(tv, nSigma);
        // underfunded: contracted
        uint256 eLow = lens.dqvFunded(tv, 1e20, pRisk);
        assertLt(lens.impliedMaturity(eLow, nSigma), tFull, "underfunded maturity contracts");
        // topped up: exactly restored
        uint256 eFull = lens.dqvFunded(tv, 2e21, pRisk);
        assertEq(lens.impliedMaturity(eFull, nSigma), tFull, "tStarFunded_eq_tStar_of_topup");
    }

    // ------------------------------------------------------------------ t*_mult (DECIDED law)

    function test__unit__tMultAnchors() public {
        // t* = 500s; sig2K = 1000, sig2R = 250 -> t_mult = 500 * 750/1000 = 375 exactly.
        assertEq(lens.impliedMaturityMult(1e18, 4e15, 250, 1000), 375, "t*_mult exact anchor");
        // sig2R = 0 -> agrees with t* (tStarJoint sanity: agreement at zero accrual)
        assertEq(lens.impliedMaturityMult(1e18, 4e15, 0, 1000), 500, "sig2R = 0 -> t*");
    }

    function test__unit__tMultClampsAtStrike() public {
        // sig2R >= sig2K -> the budget is spent -> 0 (the (.)+ clamp, never a revert)
        assertEq(lens.impliedMaturityMult(1e18, 4e15, 1000, 1000), 0, "sig2R = sig2K -> 0");
        assertEq(lens.impliedMaturityMult(1e18, 4e15, 5000, 1000), 0, "sig2R > sig2K -> 0 (clamped, no revert)");
    }

    // contracting in sig2R (tStarJoint sanity: monotone contraction)
    // forge-config: default.fuzz.runs = 128
    function test__fuzz__tMultContractsInSig2R(uint88 rA, uint88 rB, uint88 kR) public {
        uint256 sig2K = bound(uint256(kR), 1, type(uint88).max);
        uint256 a = bound(uint256(rA), 0, sig2K);
        uint256 b = bound(uint256(rB), 0, sig2K);
        if (a > b) (a, b) = (b, a);
        assertGe(
            lens.impliedMaturityMult(1e18, 4e15, a, sig2K),
            lens.impliedMaturityMult(1e18, 4e15, b, sig2K),
            "t*_mult non-increasing in sig2R"
        );
    }
}
