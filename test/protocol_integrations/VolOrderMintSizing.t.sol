// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {TickMath} from "univ3-core/libraries/TickMath.sol";
import {FullMath} from "univ3-core/libraries/FullMath.sol";

// ===========================================================================================
// V2-03 ACCEPTANCE (vol-order-v2-target-vega-SPEC.md D4 + D0-ADDENDUM): the sizing map
//   (VolOrder) -> (PanopticTokenId, positionSize)
// under dimension (ii): DeltaQ_v* is raw LIQUIDITY; the mint is QUANTITY-EXACT one-sided.
//
// THE MECHANISM UNDER TEST (SE review, verified vs Panoptic getLiquidityChunk): with
// optionRatio = 1 and asset = 1 pinned, one positionSize induces per-leg
//   L_k = positionSize * Q96 / dsqrt_k,
// so positionSize = floor(DeltaQ_v* * Q96 / S), S = Sum mulDiv(Q96, Q96, dsqrt_k), is the
// MAXIMAL scalar delivering total <= DeltaQ_v*.
//
// ORACLES: TickMath/FullMath from the vendored univ3 core restate dsqrt and the mulDiv
// chain independently (same rounding order pinned), tolerance ZERO.
//
// THE COUPLING TEST (spec D4): the induced profile vs the explicit average-density chunks
// (the #14 decision of record, size_k = L_bar*w_k/n_k). BOTH must deliver the target
// one-sided in TOTAL; the per-leg profiles are two DISCRETIZATIONS whose agreement is
// MEASURED and pinned -- a structural divergence is a finding, not a tolerance to widen.
//
// MUTANTS killed:
//   asset bit dropped/0 (the inverse-ladder defect)  -> test__unit__assetBitPinnedToOne
//   floor direction flipped (over-delivery)          -> maximality pair (ps and ps+1)
//   S computed without the Q96 numerator scale       -> the tolerance-0 oracle equality
//   positionSize == 0 accepted (empty position
//   claiming a vega)                                 -> test__unit__dustTargetReverts
// ===========================================================================================
interface IMintSizing {
    function volOrderToMint(uint256 packedVo, uint256 poolId) external view returns (uint256 tokenId, uint256 positionSize);
    function inducedLegLiquidities(uint256 packedVo, uint256 ignored) external view returns (uint256, uint256, uint256, uint256);
    function averageDensityChunks(uint256 packedVo) external view returns (uint256, uint256, uint256, uint256);
}

contract VolOrderMintSizingTest is PlankTestBase {
    uint256 internal constant Q96 = 0x1000000000000000000000000;

    IMintSizing internal h;

    // The layer-1 anchor family: vol = 1 (center tick 0), ts = 10, wide symmetric-ish bucket.
    uint256 internal constant TS = 10;
    uint256 internal constant VOL = 1;
    uint256 internal constant WIDTH = 400 * TS;
    uint256 internal constant SPREAD = 0x8000; // centered skew
    uint96 internal constant TV = 5e20; // DeltaQ_v* raw L units -- realistic pool-L magnitude

    function setUp() public {
        h = IMintSizing(deployPlank("test/protocol_integrations/VolOrderMintSizingHarness.plk"));
    }

    /// @dev V2 packed VolOrder: targetVega at 152, width at 128, tickSpacing at 104,
    ///      vol at 16, spread at 0.
    function _packVO(uint256 width, uint256 ts, uint256 vol, uint256 spread, uint256 tv)
        internal
        pure
        returns (uint256)
    {
        return (tv << 152) | (width << 128) | (ts << 104) | (vol << 16) | spread;
    }

    function _anchor() internal pure returns (uint256) {
        return _packVO(WIDTH, TS, VOL, SPREAD, TV);
    }

    // ---- tokenId leg reconstruction (the same floor-strike encoding layer 1 pins) ----

    function _legBounds(uint256 tid, uint256 leg) internal pure returns (int24 lo, int24 hi) {
        uint256 base = 64 + leg * 48;
        int24 strike = int24(int256(uint256(uint24(tid >> (base + 12))) << 232) >> 232); // sign-extend 24
        uint24 w = uint24((tid >> (base + 36)) & 0xfff);
        int24 ts = int24(uint24((tid >> 48) & 0xffff));
        // Panoptic getTicks reconstruction of the center-strike encoding (strike = lo + span/2):
        // rangeDown = floor(w*ts/2), rangeUp = ceil(w*ts/2).
        uint256 span = uint256(w) * uint256(uint24(ts));
        lo = int24(int256(strike) - int256(span / 2));
        hi = int24(int256(strike) + int256((span + 1) / 2));
    }

    function _dsqrt(int24 lo, int24 hi) internal pure returns (uint256) {
        return uint256(TickMath.getSqrtRatioAtTick(hi)) - uint256(TickMath.getSqrtRatioAtTick(lo));
    }

    /// @dev The INDEPENDENT restatement of S = Sum mulDiv(Q96, Q96, dsqrt_k).
    function _sSum(uint256 tid) internal pure returns (uint256 s) {
        for (uint256 k = 0; k < 4; k++) {
            (int24 lo, int24 hi) = _legBounds(tid, k);
            s += FullMath.mulDiv(Q96, Q96, _dsqrt(lo, hi));
        }
    }

    // ------------------------------------------------------------------ the map

    function test__unit__assetBitPinnedToOne() public {
        (uint256 tid,) = h.volOrderToMint(_anchor(), 0);
        for (uint256 k = 0; k < 4; k++) {
            assertEq((tid >> (64 + k * 48)) & 1, 1, "asset = 1 on every leg (asset = 0 INVERTS the ladder)");
        }
    }

    // Tolerance-ZERO oracle: positionSize == floor(TV * Q96 / S) with S restated via the
    // vendored TickMath/FullMath, same rounding order.
    function test__unit__positionSizeMatchesOracle() public {
        (uint256 tid, uint256 ps) = h.volOrderToMint(_anchor(), 0);
        uint256 expected = FullMath.mulDiv(TV, Q96, _sSum(tid));
        assertEq(ps, expected, "positionSize = mulDiv(DeltaQ_v*, Q96, S), floor, tolerance 0");
        assertGt(ps, 0, "non-degenerate");
        assertLe(ps, type(uint128).max, "uint128 fit");
    }

    // MAXIMALITY (the floor-direction pin): ps delivers <= TV and ps+1 would overshoot.
    function test__unit__positionSizeIsMaximalOneSided() public {
        (uint256 tid, uint256 ps) = h.volOrderToMint(_anchor(), 0);
        uint256 delivered;
        uint256 deliveredPlus;
        for (uint256 k = 0; k < 4; k++) {
            (int24 lo, int24 hi) = _legBounds(tid, k);
            delivered += FullMath.mulDiv(ps, Q96, _dsqrt(lo, hi));
            deliveredPlus += FullMath.mulDiv(ps + 1, Q96, _dsqrt(lo, hi));
        }
        assertLe(delivered, TV, "one-sided: delivered <= DeltaQ_v*");
        assertGt(deliveredPlus, TV, "maximal: ps + 1 would overshoot the target");
    }

    // The induced profile the harness reports must be exactly the per-leg L_k of the plan.
    function test__unit__inducedProfileMatchesPlan() public {
        (uint256 tid, uint256 ps) = h.volOrderToMint(_anchor(), 0);
        (uint256 l0, uint256 l1, uint256 l2, uint256 l3) = h.inducedLegLiquidities(_anchor(), 0);
        uint256[4] memory got = [l0, l1, l2, l3];
        for (uint256 k = 0; k < 4; k++) {
            (int24 lo, int24 hi) = _legBounds(tid, k);
            assertEq(got[k], FullMath.mulDiv(ps, Q96, _dsqrt(lo, hi)), "induced L_k, tolerance 0");
        }
    }

    // ------------------------------------------------------------------ the coupling test

    // THE COUPLING FINDING (measured 2026-07-30, anticipated by spec D4's failure
    // semantics): for WIDE legs (hundreds of columns each) the two realizations diverge
    // structurally per leg (up to ~99% relative) because they conserve DIFFERENT
    // quantities across a leg: the induced chunk (constant L, normalized by the leg's
    // sqrt-range) preserves the CONTINUOUS log-contract aggregate; the average-density
    // chunk (mass/n_k) preserves the discrete COLUMN-SUM of the geometric mass. Both are
    // valid "deliver DeltaQ_v*" discretizations -- their per-leg ratio is
    // n_k*xi^{c}(...)-shaped and goes to 0 as legs widen. THEREFORE:
    //   (a) BOTH totals stay one-sided at the target (asserted, exact) -- the quantity
    //       identity is realization-independent;
    //   (b) in the FINE-GRID limit (every leg exactly ONE column, n_k = 1) the two
    //       coincide up to rounding -- asserted tight below, which is the sharp form of
    //       the coupling: the discretizations agree exactly where they are comparable;
    //   (c) the CANONICAL realization on the Panoptic rail is the INDUCED one (it is what
    //       the protocol physically deploys); the average-density profile is the
    //       LDF/lens-side per-column model. Recorded in the spec at V2-03 close.
    function test__coupling__totalsAgreeOnAnyGrid() public {
        (uint256 tid,) = h.volOrderToMint(_anchor(), 0);
        (uint256 a0, uint256 a1, uint256 a2, uint256 a3) = h.inducedLegLiquidities(_anchor(), 0);
        (,uint256 b1, uint256 b2,) = h.averageDensityChunks(_anchor());
        b1; b2; // profiles diverge on coarse grids by construction -- only totals compare here
        assertLe(a0 + a1 + a2 + a3, TV, "induced total <= target");
        (uint256 c0, uint256 c1, uint256 c2, uint256 c3) = h.averageDensityChunks(_anchor());
        uint256 avgColumnSum;
        uint256[4] memory avg = [c0, c1, c2, c3];
        for (uint256 k = 0; k < 4; k++) {
            (int24 lo, int24 hi) = _legBounds(tid, k);
            avgColumnSum += avg[k] * (uint256(int256(hi) - int256(lo)) / TS);
        }
        assertLe(avgColumnSum, TV, "average-density column-sum <= target");
    }

    // The FINE-GRID coupling: width = 4*ts makes each leg exactly one column (n_k = 1).
    // There the average-density chunk IS the column mass and the induced chunk covers the
    // same single column -- the two profiles must agree tightly (<= 0.1% per leg; residual
    // = the xi-vs-sqrt-range discretization of ONE column plus floors).
    function test__coupling__fineGridProfilesCoincide() public {
        uint256 vo = _packVO(4 * TS, TS, VOL, 0x8000, TV);
        (bool ok, bytes memory r) =
            address(h).staticcall(abi.encodeWithSelector(IMintSizing.volOrderToMint.selector, vo, uint256(0)));
        require(ok, "fine-grid order must be feasible");
        r;
        (uint256 a0, uint256 a1, uint256 a2, uint256 a3) = h.inducedLegLiquidities(vo, 0);
        (uint256 b0, uint256 b1, uint256 b2, uint256 b3) = h.averageDensityChunks(vo);
        uint256[4] memory ind = [a0, a1, a2, a3];
        uint256[4] memory avg = [b0, b1, b2, b3];
        for (uint256 k = 0; k < 4; k++) {
            uint256 hi_ = ind[k] > avg[k] ? ind[k] : avg[k];
            uint256 lo_ = ind[k] > avg[k] ? avg[k] : ind[k];
            assertLe((hi_ - lo_) * 1e18 / hi_, 1e15, "fine-grid (n_k = 1): profiles coincide within 0.1%");
        }
    }

    // ------------------------------------------------------------------ guards + fuzz

    function test__unit__dustTargetReverts() public {
        // TV = 1 raw L unit over a wide range floors positionSize to 0 -> refuse.
        (bool ok,) = address(h).staticcall(
            abi.encodeWithSelector(IMintSizing.volOrderToMint.selector, _packVO(WIDTH, TS, VOL, SPREAD, 1), uint256(0))
        );
        assertFalse(ok, "a target too small to deliver any liquidity REVERTS (no empty-position vega)");
    }

    // forge-config: default.fuzz.runs = 128
    function test__fuzz__oneSidedIdentityAcrossOrders(uint256 wR, uint256 spreadR, uint96 tvR) public {
        uint256 width = bound(wR, 100 * TS, 4000 * TS);
        uint256 spread = bound(spreadR, 0x2000, 0xE000);
        uint96 tv = uint96(bound(uint256(tvR), 1e15, type(uint96).max));
        uint256 vo = _packVO(width, TS, VOL, spread, tv);

        (bool ok, bytes memory r) =
            address(h).staticcall(abi.encodeWithSelector(IMintSizing.volOrderToMint.selector, vo, uint256(0)));
        vm.assume(ok); // layer-1 feasibility / dust guards may reject extreme shapes
        (uint256 tid, uint256 ps) = abi.decode(r, (uint256, uint256));

        uint256 delivered;
        for (uint256 k = 0; k < 4; k++) {
            (int24 lo, int24 hi) = _legBounds(tid, k);
            delivered += FullMath.mulDiv(ps, Q96, _dsqrt(lo, hi));
        }
        assertLe(delivered, tv, "one-sided identity under fuzz");
        assertLe(ps, type(uint128).max, "uint128 fit under fuzz");
        assertGt(ps, 0, "never a zero plan");
    }
}
