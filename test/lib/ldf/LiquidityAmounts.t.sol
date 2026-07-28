// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {LibGeometricDistribution} from "../../../lib/bunni-v2/src/ldf/LibGeometricDistribution.sol";

// Oracle: token0 amount over the full support [i_min, i_max) at a given liquidity = Bunni cumulativeAmount0
// evaluated at (i_min - tickSpacing).
contract CA0Ref {
    function ca0(int24 rt, uint256 tl, int24 ts, int24 mt, int24 len, uint256 alpha)
        external
        pure
        returns (uint256)
    {
        return LibGeometricDistribution.cumulativeAmount0(rt, tl, ts, mt, len, alpha);
    }
}

// liquidity_for_collateral(ldf_params, coord, collateral): the Lbar that a geometric-LDF position holds when
// funded by `collateral` token0 over its support. By the reviewed design, Lbar = collateral·Q96 / cost_M where
// cost_M = cumulativeAmount0(i_min-Δ, Q96, ...). Exact vs Bunni (both round the division down).
contract LiquidityAmountsTest is PlankTestBase {
    // FFI-deployed Plank harness (LiquidityAmountsHarness.plk):
    //   liquidityForCollateral(int24 minTick,int24 tickSpacing,int24 length,uint256 alphaX96,uint256 collateral) -> uint256 (Lbar)
    address internal harness;
    CA0Ref internal ref;

    uint256 constant Q96 = 1 << 96;
    uint128 constant U128_MAX = type(uint128).max;

    function setUp() public {
        harness = deployPlank("src/lib/ldf/LiquidityAmountsHarness.plk");
        ref = new CA0Ref();
    }

    function _lfc(int24 minTick, int24 tickSpacing, int24 length, uint256 alpha, uint256 collateral)
        internal
        returns (bool ok, uint256 size)
    {
        bytes memory ret;
        (ok, ret) = harness.staticcall(
            abi.encodeWithSignature(
                "liquidityForCollateral(int24,int24,int24,uint256,uint256)",
                minTick, tickSpacing, length, alpha, collateral
            )
        );
        if (ok) size = abi.decode(ret, (uint256));
    }

    function _alpha(uint256 seed) internal pure returns (uint256 a) {
        a = bound(seed, Q96 / 1e6 + 1, Q96 * 1000);
        if (a == Q96) a = Q96 + 1;
    }

    // Lbar == collateral·Q96 / cumulativeAmount0(i_min-Δ, Q96, ...) exactly.
    function testFuzz_liquidityForCollateral_matchesInversion(
        uint256 aR,
        int256 mtR,
        uint256 tsR,
        uint256 lenR,
        uint256 colR
    ) public {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 100)));
        int24 length = int24(int256(bound(lenR, 2, 500)));
        int24 minTick = int24(bound(mtR, -800_000, 800_000));
        uint256 alpha = _alpha(aR);
        uint256 collateral = bound(colR, 1, 1e30);

        uint256 costM = ref.ca0(minTick - tickSpacing, Q96, tickSpacing, minTick, length, alpha);
        vm.assume(costM != 0);
        uint256 expectedL = (collateral * Q96) / costM; // no overflow: collateral<=1e30, *Q96 < 2^196
        vm.assume(expectedL <= U128_MAX); // in-range: plank returns it (out-of-range reverts, tested separately)

        (bool ok, uint256 size) = _lfc(minTick, tickSpacing, length, alpha, collateral);
        assertTrue(ok, "liquidityForCollateral reverted");
        assertEq(size, expectedL, "Lbar == collateral*Q96 / cumulativeAmount0(i_min-d, Q96)");
    }

    // round-trip: the token0 amount the returned Lbar holds over the support is ~ the collateral funded.
    function testFuzz_liquidityForCollateral_roundTrip(
        uint256 aR,
        int256 mtR,
        uint256 tsR,
        uint256 lenR,
        uint256 colR
    ) public {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 100)));
        int24 length = int24(int256(bound(lenR, 2, 500)));
        int24 minTick = int24(bound(mtR, -800_000, 800_000));
        uint256 alpha = _alpha(aR);
        uint256 collateral = bound(colR, 1e6, 1e30);

        uint256 costM = ref.ca0(minTick - tickSpacing, Q96, tickSpacing, minTick, length, alpha);
        vm.assume(costM != 0);
        vm.assume((collateral * Q96) / costM <= U128_MAX);

        (bool ok, uint256 size) = _lfc(minTick, tickSpacing, length, alpha, collateral);
        assertTrue(ok, "reverted");
        vm.assume(size != 0);

        uint256 back = ref.ca0(minTick - tickSpacing, size, tickSpacing, minTick, length, alpha);
        // Lbar = floor(collateral*Q96/costM), so flooring loses < 1 liquidity unit, worth costM/Q96 token0.
        // The round-trip is thus conservative (back <= collateral) and lossy by at most one unit's cost.
        uint256 unitCost = costM / Q96; // token0 cost of one liquidity unit
        assertLe(back, collateral, "round-trip token0 <= collateral (conservative)");
        assertLe(collateral - back, unitCost + 2, "round-trip loss <= one liquidity-unit token0 cost");
    }

    // liquidity_for_vega reduces to liquidity_for_collateral(ΔM) with ΔM = exposure·priceVolX96/Q96
    // (exposure.md §2: ΔM = N_v·p_vol). So it must equal the same Bunni-cumulativeAmount0 inversion.
    function _lfv(int24 minTick, int24 tickSpacing, int24 length, uint256 alpha, uint256 exposure, uint256 priceVol)
        internal
        returns (bool ok, uint256 size)
    {
        bytes memory ret;
        (ok, ret) = harness.staticcall(
            abi.encodeWithSignature(
                "liquidityForVega(int24,int24,int24,uint256,uint256,uint256)",
                minTick, tickSpacing, length, alpha, exposure, priceVol
            )
        );
        if (ok) size = abi.decode(ret, (uint256));
    }

    function testFuzz_liquidityForVega_matchesCollateralOfDeltaM(
        uint256 aR,
        int256 mtR,
        uint256 tsR,
        uint256 lenR,
        uint256 expR,
        uint256 pvR
    ) public {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 100)));
        int24 length = int24(int256(bound(lenR, 2, 500)));
        int24 minTick = int24(bound(mtR, -800_000, 800_000));
        uint256 alpha = _alpha(aR);
        uint256 exposure = bound(expR, 1, 1e18); // bounds keep exposure*priceVol < 2^256 in Solidity
        uint256 priceVol = bound(pvR, 1, 1e30);

        uint256 deltaM = (exposure * priceVol) / Q96; // ΔM = N_v·p_vol/Q96 (matches plank mulDiv, round down)
        uint256 costM = ref.ca0(minTick - tickSpacing, Q96, tickSpacing, minTick, length, alpha);
        vm.assume(costM != 0);
        uint256 expectedL = (deltaM * Q96) / costM;
        vm.assume(expectedL <= U128_MAX);

        (bool ok, uint256 size) = _lfv(minTick, tickSpacing, length, alpha, exposure, priceVol);
        assertTrue(ok, "liquidityForVega reverted");
        assertEq(size, expectedL, "liquidity_for_vega == liquidity_for_collateral(deltaM)");
    }

    function test_liquidityForCollateral_revertsAboveUint128() public {
        int24 minTick = 0;
        int24 tickSpacing = 1;
        int24 length = 4;
        uint256 alpha = Q96 / 2;
        uint256 costM = ref.ca0(-1, Q96, 1, 0, 4, alpha);
        // collateral chosen so Lbar = collateral*Q96/costM comfortably exceeds uint128 max
        uint256 collateral = (uint256(U128_MAX) * costM) / Q96 + costM + 1e18;
        (bool ok,) = _lfc(minTick, tickSpacing, length, alpha, collateral);
        assertFalse(ok, "Lbar > uint128 max must revert");
    }
}
