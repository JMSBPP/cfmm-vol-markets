// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";

contract PriceBucketTest is PlankTestBase {
    // FFI-deployed Plank harness (PriceBucketHarness.plk):
    //   priceBucket(uint256 tickSpacing,uint256 eta,uint256 numbRep,int24 i1,int24 imid,int24 i2)
    //     -> (bytes32 geometry, uint256 lower, uint256 mid, uint256 upper)
    //   priceBucketFromTickBucket(uint256 tickSpacing,uint256 eta,uint256 numbRep,int24 low,int24 up,int24 tbSpacing)
    //     -> (bytes32 geometry, uint256 lower, uint256 mid, uint256 upper)   [reverts if tbSpacing != tickSpacing]
    address internal harness;

    uint256 constant TICK_SPACING = 60;
    uint256 constant NUMB_REP     = 96;
    uint256 constant Q96          = 1 << 96;

    function setUp() public {
        harness = deployPlank("test/types/PriceBucketHarness.plk");
    }

    function _price(int24 t) internal pure returns (uint256) {
        return uint256(TickMath.getSqrtPriceAtTick(t));
    }

    function _sort3(int24 a, int24 b, int24 c) internal pure returns (int24 lo, int24 md, int24 hi) {
        int24[3] memory v = [a, b, c];
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = i + 1; j < 3; j++) {
                if (v[j] < v[i]) (v[i], v[j]) = (v[j], v[i]);
            }
        }
        return (v[0], v[1], v[2]);
    }

    function _bucket(uint256 eta, int24 i1, int24 imid, int24 i2)
        internal
        returns (bytes32 g, uint256 lower, uint256 mid, uint256 upper)
    {
        (bool ok, bytes memory ret) = harness.staticcall(
            abi.encodeWithSignature(
                "priceBucket(uint256,uint256,uint256,int24,int24,int24)",
                TICK_SPACING, eta, NUMB_REP, i1, imid, i2
            )
        );
        require(ok, "priceBucket reverted");
        return abi.decode(ret, (bytes32, uint256, uint256, uint256));
    }

    // ctor 1: (PriceCoordinate, i1, imid, i2) -> PriceBucket, sorted ascending
    function testFuzz_priceBucket(uint256 etaRaw, int256 aR, int256 bR, int256 cR) public {
        uint256 eta = bound(etaRaw, 1, Q96 - 1);
        int24 i1 = int24(bound(aR, TickMath.MIN_TICK, TickMath.MAX_TICK));
        int24 imid = int24(bound(bR, TickMath.MIN_TICK, TickMath.MAX_TICK));
        int24 i2 = int24(bound(cR, TickMath.MIN_TICK, TickMath.MAX_TICK));
        (int24 sLo, int24 sMd, int24 sHi) = _sort3(i1, imid, i2);

        (bytes32 g, uint256 lower, uint256 mid, uint256 upper) = _bucket(eta, i1, imid, i2);

        assertEq(g, keccak256(abi.encode(TICK_SPACING, eta, NUMB_REP)), "geometry == PriceCoordinateId");
        assertApproxEqRel(lower, _price(sLo), 1e10, "lower == price(min tick)");
        assertApproxEqRel(mid, _price(sMd), 1e10, "mid == price(median tick)");
        assertApproxEqRel(upper, _price(sHi), 1e10, "upper == price(max tick)");

        // canonical monotonic witness: genuinely ordered lower <= mid <= upper
        assertLe(_price(sLo), _price(sMd), "price(min) <= price(median)");
        assertLe(_price(sMd), _price(sHi), "price(median) <= price(max)");

        // permutation-independence: any input order yields the same bucket
        (bytes32 g2, uint256 l2, uint256 m2, uint256 u2) = _bucket(eta, i2, i1, imid);
        assertEq(g2, g, "geometry unchanged by permutation");
        assertEq(l2, lower, "lower unchanged");
        assertEq(m2, mid, "mid unchanged");
        assertEq(u2, upper, "upper unchanged");
    }

    // ctor 2: (TickBucket{low,tickSpacing,up}) -> PriceBucket, mid = floor((low+up)/2)
    function testFuzz_priceBucketFromTickBucket(uint256 etaRaw, int256 lowR, int256 upR) public {
        uint256 eta = bound(etaRaw, 1, Q96 - 1);
        int24 low = int24(bound(lowR, TickMath.MIN_TICK, TickMath.MAX_TICK));
        int24 up = int24(bound(upR, TickMath.MIN_TICK, TickMath.MAX_TICK));
        int24 midTick = int24((int256(low) + int256(up)) >> 1); // floor midpoint

        (bool ok, bytes memory ret) = harness.staticcall(
            abi.encodeWithSignature(
                "priceBucketFromTickBucket(uint256,uint256,uint256,int24,int24,int24)",
                TICK_SPACING, eta, NUMB_REP, low, up, int24(int256(TICK_SPACING))
            )
        );
        require(ok, "priceBucketFromTickBucket reverted");
        (bytes32 g, uint256 lower, uint256 mid, uint256 upper) =
            abi.decode(ret, (bytes32, uint256, uint256, uint256));

        assertEq(g, keccak256(abi.encode(TICK_SPACING, eta, NUMB_REP)), "geometry == PriceCoordinateId");
        assertApproxEqRel(lower, _price(low), 1e10, "lower == price(low)");
        assertApproxEqRel(upper, _price(up), 1e10, "upper == price(up)");
        assertApproxEqRel(mid, _price(midTick), 1e10, "mid == price(floor((low+up)/2))");
    }

    // ctor 2 enforces the same-geometry invariant: reverts when tb.tickSpacing != coord.tick_spacing
    function testFuzz_priceBucketFromTickBucket_revertsOnSpacingMismatch(
        uint256 etaRaw,
        int256 lowR,
        int256 upR,
        int256 spcR
    ) public {
        uint256 eta = bound(etaRaw, 1, Q96 - 1);
        int24 low = int24(bound(lowR, TickMath.MIN_TICK, TickMath.MAX_TICK));
        int24 up = int24(bound(upR, TickMath.MIN_TICK, TickMath.MAX_TICK));
        int24 tbSpacing = int24(bound(spcR, 1, 32767));
        vm.assume(uint256(uint24(tbSpacing)) != TICK_SPACING);

        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "priceBucketFromTickBucket(uint256,uint256,uint256,int24,int24,int24)",
                TICK_SPACING, eta, NUMB_REP, low, up, tbSpacing
            )
        );
        assertFalse(ok, "must revert when tb.tickSpacing != coord.tick_spacing");
    }
}
