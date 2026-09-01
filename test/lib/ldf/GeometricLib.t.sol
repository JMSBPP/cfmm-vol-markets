// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {LibGeometricDistribution} from "../../../lib/bunni-v2/src/ldf/LibGeometricDistribution.sol";

// Wraps Bunni's internal liquidityDensityX96 as the differential oracle.
contract GeoRef {
    function ldx96(int24 rt, int24 ts, int24 mt, int24 len, uint256 alpha) external pure returns (uint256) {
        return LibGeometricDistribution.liquidityDensityX96(rt, ts, mt, len, alpha);
    }
}

// The Plank geometric liquidity density must match Bunni's LibGeometricDistribution exactly (same
// formula, same rpow / 512-bit mulDiv). alpha (=xi) in Q96; minTick (=i_min); length (=iota).
contract GeometricLibTest is PlankTestBase {
    // FFI-deployed Plank harness (GeometricLibHarness.plk):
    //   geoDensity(int24 roundedTick, int24 tickSpacing, int24 minTick, int24 length, uint256 alphaX96) -> uint256
    address internal harness;
    GeoRef internal ref;

    uint256 constant Q96 = 1 << 96;

    function setUp() public {
        harness = deployPlank("test/lib/ldf/GeometricLibHarness.plk");
        ref = new GeoRef();
    }

    function _density(int24 rt, int24 ts, int24 mt, int24 len, uint256 alpha) internal returns (uint256) {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("geoDensity(int24,int24,int24,int24,uint256)", rt, ts, mt, len, alpha)
        );
        require(ok, "geoDensity reverted");
        return abi.decode(r, (uint256));
    }

    // a valid alpha != Q96 (avoid alpha == 1, which Bunni intentionally reverts on)
    function _alpha(uint256 seed) internal pure returns (uint256 a) {
        a = bound(seed, Q96 / 1e6 + 1, Q96 * 1000);
        if (a == Q96) a = Q96 + 1;
    }

    function testFuzz_geoDensity_matchesBunni(uint256 aR, int256 mtR, uint256 tsR, uint256 lenR, uint256 xR)
        public
    {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 200)));
        int24 length = int24(int256(bound(lenR, 2, 1000)));
        uint256 x = bound(xR, 0, uint256(int256(length)) - 1);
        int24 minTick = int24(bound(mtR, -4_000_000, 4_000_000));
        int24 roundedTick = minTick + int24(int256(x)) * tickSpacing;
        uint256 alpha = _alpha(aR);

        assertEq(
            _density(roundedTick, tickSpacing, minTick, length, alpha),
            ref.ldx96(roundedTick, tickSpacing, minTick, length, alpha),
            "plank geo density must equal Bunni"
        );
    }

    function testFuzz_geoDensity_outOfSupport(uint256 aR, int256 mtR, uint256 tsR, uint256 lenR) public {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 200)));
        int24 length = int24(int256(bound(lenR, 2, 1000)));
        int24 minTick = int24(bound(mtR, -4_000_000, 4_000_000));
        uint256 alpha = _alpha(aR);

        assertEq(_density(minTick - tickSpacing, tickSpacing, minTick, length, alpha), 0, "below support -> 0");
        int24 upper = minTick + length * tickSpacing;
        assertEq(_density(upper, tickSpacing, minTick, length, alpha), 0, "at/above upper -> 0");
    }

    function test_geoDensity_golden() public {
        // alpha = 0.5, minTick=0, length=4, roundedTick=0 (x=0):
        //   density = (Q96 - alpha)*alpha^0 / (Q96 - alpha^4) = (1/2) / (1 - 1/16) = 8/15
        uint256 alpha = Q96 / 2;
        uint256 got = _density(0, 1, 0, 4, alpha);
        assertEq(got, ref.ldx96(0, 1, 0, 4, alpha), "golden matches Bunni");
        assertApproxEqAbs(got, (Q96 * 8) / 15, 2, "golden == 8/15 in Q96");
    }

    // notes property (VOLATILITY_INSTRUMENTS): the normalized densities sum to 1 (Q96) over the support.
    function testFuzz_geoDensity_normalizes(uint256 aR, uint256 tsR, uint256 lenR) public {
        int24 tickSpacing = int24(int256(bound(tsR, 1, 200)));
        int24 length = int24(int256(bound(lenR, 2, 64))); // bounded sum
        int24 minTick = 0;
        uint256 alpha = _alpha(aR);

        uint256 sum;
        for (uint256 x = 0; x < uint256(int256(length)); x++) {
            sum += _density(minTick + int24(int256(x)) * tickSpacing, tickSpacing, minTick, length, alpha);
        }
        // Mathematically the normalized geometric densities sum to 1. In fixed point the sum drifts
        // (truncating mulDiv + rpow compounding a truncated alphaInv) — my port reproduces Bunni's drift
        // exactly (see matchesBunni), so this is a spec-level Sum=1 sanity within a relative bound.
        assertApproxEqRel(sum, Q96, 1e12, "sum of densities ~ Q96 (1e-6 rel)");
    }
}
