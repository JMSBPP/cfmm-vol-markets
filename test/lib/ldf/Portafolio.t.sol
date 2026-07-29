// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {LibGeometricDistribution} from "../../../lib/bunni-v2/src/ldf/LibGeometricDistribution.sol";

// Oracle: token0 (cumulativeAmount0) and token1 (cumulativeAmount1) over the geometric-LDF support.
contract CA01Ref {
    function ca0(int24 rt, uint256 tl, int24 ts, int24 mt, int24 len, uint256 a) external pure returns (uint256) {
        return LibGeometricDistribution.cumulativeAmount0(rt, tl, ts, mt, len, a);
    }

    function ca1(int24 rt, uint256 tl, int24 ts, int24 mt, int24 len, uint256 a) external pure returns (uint256) {
        return LibGeometricDistribution.cumulativeAmount1(rt, tl, ts, mt, len, a);
    }
}

// portafolio_for_liquidity(coord, liquidity) -> Portafolio: the (Q_X token1, Q_M token0) amounts a geometric
// position of liquidity Lbar holds over the FULL support. gross_input = cumulativeAmount0(i_min-Δ, Lbar);
// gross_output = cumulativeAmount1(i_max, Lbar).
contract PortafolioTest is PlankTestBase {
    // FFI-deployed Plank harness (PortafolioHarness.plk):
    //   portafolioForLiquidity(int24 minTick,int24 tickSpacing,int24 length,uint256 alphaX96,uint256 liquiditySize)
    //     -> (uint256 grossOutput, uint256 grossInput)
    address internal harness;
    CA01Ref internal ref;

    uint256 constant Q96 = 1 << 96;

    function setUp() public {
        harness = deployPlank("src/lib/ldf/PortafolioHarness.plk");
        ref = new CA01Ref();
    }

    function _pfl(int24 minTick, int24 tickSpacing, int24 length, uint256 alpha, uint256 size)
        internal
        returns (uint256 grossOutput, uint256 grossInput)
    {
        (bool ok, bytes memory ret) = harness.staticcall(
            abi.encodeWithSignature(
                "portafolioForLiquidity(int24,int24,int24,uint256,uint256)", minTick, tickSpacing, length, alpha, size
            )
        );
        require(ok, "portafolioForLiquidity reverted");
        (grossOutput, grossInput) = abi.decode(ret, (uint256, uint256));
    }

    function _alpha(uint256 seed) internal pure returns (uint256 a) {
        a = bound(seed, Q96 / 1e6 + 1, Q96 * 1000);
        if (a == Q96) a = Q96 + 1;
    }

    function testFuzz_portafolioForLiquidity_matchesBunni(
        uint256 aR,
        int256 mtR,
        uint256 tsR,
        uint256 lenR,
        uint256 szR
    ) public {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 100)));
        int24 length = int24(int256(bound(lenR, 2, 500)));
        int24 minTick = int24(bound(mtR, -800_000, 800_000));
        uint256 alpha = _alpha(aR);
        uint256 size = bound(szR, 1, 1e30);
        int24 iMax = minTick + length * tickSpacing;

        uint256 expInput = ref.ca0(minTick - tickSpacing, size, tickSpacing, minTick, length, alpha);
        uint256 expOutput = ref.ca1(iMax, size, tickSpacing, minTick, length, alpha);

        (uint256 gOut, uint256 gIn) = _pfl(minTick, tickSpacing, length, alpha, size);
        assertEq(gIn, expInput, "gross_input == Q_M (token0) over support");
        assertEq(gOut, expOutput, "gross_output == Q_X (token1) over support");

        // INDEPENDENT boundary check (not circular): i_max captures the full support iff the closed form at
        // i_max (clamp branch) equals the last in-support tick i_max-Δ; and the full sum dominates an interior tick.
        assertEq(
            ref.ca1(iMax, size, tickSpacing, minTick, length, alpha),
            ref.ca1(iMax - tickSpacing, size, tickSpacing, minTick, length, alpha),
            "i_max is a full-support boundary for Q_X"
        );
        int24 interior = minTick + (length / 2) * tickSpacing;
        assertGe(
            ref.ca1(iMax, size, tickSpacing, minTick, length, alpha),
            ref.ca1(interior, size, tickSpacing, minTick, length, alpha),
            "full-support Q_X >= interior Q_X (monotone)"
        );
    }

    function test_portafolioForLiquidity_golden() public {
        // geometric alpha=0.5, minTick=0, tickSpacing=1, length=4, Lbar=1e18
        uint256 alpha = Q96 / 2;
        uint256 size = 1e18;
        (uint256 gOut, uint256 gIn) = _pfl(0, 1, 4, alpha, size);
        assertEq(gIn, ref.ca0(-1, size, 1, 0, 4, alpha), "golden gross_input");
        assertEq(gOut, ref.ca1(4, size, 1, 0, 4, alpha), "golden gross_output");
    }

    // ---- inverse: liquidity_for_portafolio (full-support, Lbar = min(Lbar_M, Lbar_X)) ----

    uint128 constant U128_MAX = type(uint128).max;

    function _lfp(int24 minTick, int24 tickSpacing, int24 length, uint256 alpha, uint256 gOut, uint256 gIn)
        internal
        returns (bool ok, uint256 size)
    {
        bytes memory ret;
        (ok, ret) = harness.staticcall(
            abi.encodeWithSignature(
                "liquidityForPortafolio(int24,int24,int24,uint256,uint256,uint256)",
                minTick, tickSpacing, length, alpha, gOut, gIn
            )
        );
        if (ok) size = abi.decode(ret, (uint256));
    }

    // Lbar = min( gross_input·Q96/cost_M , gross_output·Q96/cost_X ), each rounded down (fund-safety).
    function testFuzz_liquidityForPortafolio_matchesMinInversion(
        uint256 aR,
        int256 mtR,
        uint256 tsR,
        uint256 lenR,
        uint256 giR,
        uint256 goR
    ) public {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 100)));
        int24 length = int24(int256(bound(lenR, 2, 500)));
        int24 minTick = int24(bound(mtR, -800_000, 800_000));
        uint256 alpha = _alpha(aR);
        uint256 gIn = bound(giR, 1, 1e30);
        uint256 gOut = bound(goR, 1, 1e30);
        int24 iMax = minTick + length * tickSpacing;

        uint256 costM = ref.ca0(minTick - tickSpacing, Q96, tickSpacing, minTick, length, alpha);
        uint256 costX = ref.ca1(iMax, Q96, tickSpacing, minTick, length, alpha);
        vm.assume(costM != 0 && costX != 0);
        uint256 lM = (gIn * Q96) / costM;
        uint256 lX = (gOut * Q96) / costX;
        uint256 expected = lM < lX ? lM : lX;
        vm.assume(expected <= U128_MAX);

        (bool ok, uint256 size) = _lfp(minTick, tickSpacing, length, alpha, gOut, gIn);
        assertTrue(ok, "liquidityForPortafolio reverted");
        assertEq(size, expected, "Lbar == min(gIn*Q96/cost_M, gOut*Q96/cost_X)");
    }

    // round-trip: liquidity_for_portafolio(portafolio_for_liquidity(Lbar)) recovers Lbar (conservative over-recovery,
    // bounded by ~Q96/cost since forward amounts round up and inverse Lbar rounds down).
    function testFuzz_portafolio_roundTrip(uint256 aR, int256 mtR, uint256 tsR, uint256 lenR, uint256 szR) public {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 100)));
        int24 length = int24(int256(bound(lenR, 2, 500)));
        int24 minTick = int24(bound(mtR, -800_000, 800_000));
        uint256 alpha = _alpha(aR);
        uint256 lIn = bound(szR, 1, 1e24);
        int24 iMax = minTick + length * tickSpacing;

        uint256 costM = ref.ca0(minTick - tickSpacing, Q96, tickSpacing, minTick, length, alpha);
        uint256 costX = ref.ca1(iMax, Q96, tickSpacing, minTick, length, alpha);
        vm.assume(costM != 0 && costX != 0);

        (uint256 gOut, uint256 gIn) = _pfl(minTick, tickSpacing, length, alpha, lIn);
        (bool ok, uint256 lOut) = _lfp(minTick, tickSpacing, length, alpha, gOut, gIn);
        vm.assume(ok);

        assertGe(lOut, lIn, "round-trip over-recovers (conservative)");
        uint256 unit = Q96 / (costM < costX ? costM : costX) + 2; // over-recovery bound ~ Q96/min(cost)
        assertLe(lOut - lIn, unit, "round-trip over-recovery <= ~Q96/min(cost)");
    }

    function test_liquidityForPortafolio_revertsAboveUint128() public {
        uint256 alpha = Q96 / 2;
        uint256 costM = ref.ca0(-1, Q96, 1, 0, 4, alpha);
        // gross_input large enough that Lbar_M (and thus the min) exceeds uint128
        uint256 gIn = (uint256(U128_MAX) * costM) / Q96 + costM + 1e18;
        uint256 gOut = type(uint256).max; // make the token1 leg non-binding
        (bool ok,) = _lfp(0, 1, 4, alpha, gOut, gIn);
        assertFalse(ok, "Lbar > uint128 max must revert");
    }
}
