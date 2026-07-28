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
// position of liquidity L̄ holds over the FULL support. gross_input = cumulativeAmount0(i_min-Δ, L̄);
// gross_output = cumulativeAmount1(i_max, L̄).
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
        // geometric alpha=0.5, minTick=0, tickSpacing=1, length=4, L̄=1e18
        uint256 alpha = Q96 / 2;
        uint256 size = 1e18;
        (uint256 gOut, uint256 gIn) = _pfl(0, 1, 4, alpha, size);
        assertEq(gIn, ref.ca0(-1, size, 1, 0, 4, alpha), "golden gross_input");
        assertEq(gOut, ref.ca1(4, size, 1, 0, 4, alpha), "golden gross_output");
    }
}
