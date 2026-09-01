// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {LibGeometricDistribution} from "../../../lib/bunni-v2/src/ldf/LibGeometricDistribution.sol";

// Wraps Bunni's internal cumulativeAmount0/1 as the differential oracle.
contract GeoCumRef {
    function ca0(int24 rt, uint256 tl, int24 ts, int24 mt, int24 len, uint256 alpha)
        external
        pure
        returns (uint256)
    {
        return LibGeometricDistribution.cumulativeAmount0(rt, tl, ts, mt, len, alpha);
    }

    function ca1(int24 rt, uint256 tl, int24 ts, int24 mt, int24 len, uint256 alpha)
        external
        pure
        returns (uint256)
    {
        return LibGeometricDistribution.cumulativeAmount1(rt, tl, ts, mt, len, alpha);
    }
}

// The Plank geometric cumulativeAmount0 (Q_M^L from the notes) must match Bunni's
// LibGeometricDistribution.cumulativeAmount0 exactly.
contract GeometricCumulativeTest is PlankTestBase {
    // FFI-deployed Plank harness (GeometricLibHarness.plk):
    //   geoCumAmount0(int24 roundedTick,uint256 totalLiquidity,int24 tickSpacing,int24 minTick,int24 length,uint256 alphaX96) -> uint256
    address internal harness;
    GeoCumRef internal ref;

    uint256 constant Q96 = 1 << 96;

    function setUp() public {
        harness = deployPlank("test/lib/ldf/GeometricLibHarness.plk");
        ref = new GeoCumRef();
    }

    function _ca0(int24 rt, uint256 tl, int24 ts, int24 mt, int24 len, uint256 alpha) internal returns (uint256) {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "geoCumAmount0(int24,uint256,int24,int24,int24,uint256)", rt, tl, ts, mt, len, alpha
            )
        );
        require(ok, "geoCumAmount0 reverted");
        return abi.decode(r, (uint256));
    }

    function _alpha(uint256 seed) internal pure returns (uint256 a) {
        a = bound(seed, Q96 / 1e6 + 1, Q96 * 1000);
        if (a == Q96) a = Q96 + 1;
    }

    function testFuzz_cumAmount0_matchesBunni(
        uint256 aR,
        int256 mtR,
        uint256 tsR,
        uint256 lenR,
        uint256 xR,
        uint256 tlR
    ) public {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 100)));
        int24 length = int24(int256(bound(lenR, 2, 500)));
        uint256 x = bound(xR, 0, uint256(int256(length)) - 1);
        int24 minTick = int24(bound(mtR, -800_000, 800_000));
        int24 roundedTick = minTick + int24(int256(x)) * tickSpacing;
        uint256 totalLiquidity = bound(tlR, 0, 1e30);
        uint256 alpha = _alpha(aR);

        assertEq(
            _ca0(roundedTick, totalLiquidity, tickSpacing, minTick, length, alpha),
            ref.ca0(roundedTick, totalLiquidity, tickSpacing, minTick, length, alpha),
            "plank cumulativeAmount0 must equal Bunni"
        );
    }

    function testFuzz_cumAmount0_rightOfDistribution(uint256 aR, int256 mtR, uint256 tsR, uint256 lenR, uint256 tlR)
        public
    {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 100)));
        int24 length = int24(int256(bound(lenR, 2, 500)));
        int24 minTick = int24(bound(mtR, -800_000, 800_000));
        uint256 totalLiquidity = bound(tlR, 0, 1e30);
        uint256 alpha = _alpha(aR);
        int24 upper = minTick + length * tickSpacing;
        assertEq(_ca0(upper, totalLiquidity, tickSpacing, minTick, length, alpha), 0, "right of distribution -> 0");
    }

    function test_cumAmount0_golden() public {
        uint256 alpha = Q96 / 2;
        uint256 tl = 1e18;
        uint256 got = _ca0(0, tl, 1, 0, 4, alpha);
        assertEq(got, ref.ca0(0, tl, 1, 0, 4, alpha), "golden cumulativeAmount0 matches Bunni");
    }

    // ---- Increment 4: cumulativeAmount1 (Q_X^L) ----

    function _ca1(int24 rt, uint256 tl, int24 ts, int24 mt, int24 len, uint256 alpha) internal returns (uint256) {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "geoCumAmount1(int24,uint256,int24,int24,int24,uint256)", rt, tl, ts, mt, len, alpha
            )
        );
        require(ok, "geoCumAmount1 reverted");
        return abi.decode(r, (uint256));
    }

    function testFuzz_cumAmount1_matchesBunni(
        uint256 aR,
        int256 mtR,
        uint256 tsR,
        uint256 lenR,
        uint256 xR,
        uint256 tlR
    ) public {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 100)));
        int24 length = int24(int256(bound(lenR, 2, 500)));
        uint256 x = bound(xR, 0, uint256(int256(length)) - 1);
        int24 minTick = int24(bound(mtR, -800_000, 800_000));
        int24 roundedTick = minTick + int24(int256(x)) * tickSpacing;
        uint256 totalLiquidity = bound(tlR, 0, 1e30);
        uint256 alpha = _alpha(aR);

        assertEq(
            _ca1(roundedTick, totalLiquidity, tickSpacing, minTick, length, alpha),
            ref.ca1(roundedTick, totalLiquidity, tickSpacing, minTick, length, alpha),
            "plank cumulativeAmount1 must equal Bunni"
        );
    }

    function testFuzz_cumAmount1_leftOfDistribution(uint256 aR, int256 mtR, uint256 tsR, uint256 lenR, uint256 tlR)
        public
    {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 100)));
        int24 length = int24(int256(bound(lenR, 2, 500)));
        int24 minTick = int24(bound(mtR, -800_000, 800_000));
        uint256 totalLiquidity = bound(tlR, 0, 1e30);
        uint256 alpha = _alpha(aR);
        assertEq(
            _ca1(minTick - tickSpacing, totalLiquidity, tickSpacing, minTick, length, alpha),
            0,
            "left of distribution -> 0"
        );
    }

    function test_cumAmount1_golden() public {
        uint256 alpha = Q96 / 2;
        uint256 tl = 1e18;
        int24 rt = 2; // in [0, 4)
        uint256 got = _ca1(rt, tl, 1, 0, 4, alpha);
        assertEq(got, ref.ca1(rt, tl, 1, 0, 4, alpha), "golden cumulativeAmount1 matches Bunni");
    }
}
