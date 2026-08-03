// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";

// CR-I2 Layer 1, Increment 1: the floor-strike leg encoder panoptic_add_leg_from_bucket must produce
// a (strike,width) pair that Panoptic's getTicks reconstructs to EXACTLY the sub-bucket [lo,hi],
// tickSpacing-aligned, for ANY sign/parity. The negative-odd case is the one that distinguishes
// floor-strike (correct) from sdiv(low+up,2) truncation-toward-zero (off by +1, off-grid).
contract VolOrderToPanopticTokenIdTest is PlankTestBase {
    // FFI-deployed Plank harness (VolOrderToPanopticTokenIdHarness.plk):
    //   legFromBucket(int24 lo,int24 hi,int24 ts,uint256 leg) -> (int256 strike, uint256 width)
    address internal harness;

    int24 constant I24_MIN = -8388608;
    int24 constant I24_MAX = 8388607;

    function setUp() public {
        harness = deployPlank("test/protocol_integrations/VolOrderToPanopticTokenIdHarness.plk");
    }

    function _legFromBucket(int24 lo, int24 hi, int24 ts, uint256 leg)
        internal
        returns (int24 strike, uint256 width)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("legFromBucket(int24,int24,int24,uint256)", lo, hi, ts, leg)
        );
        require(ok, "legFromBucket reverted");
        (int256 s, uint256 w) = abi.decode(r, (int256, uint256));
        strike = int24(s);
        width = w;
    }

    // Panoptic reconstruction: getRangesFromStrike (rangeDown=floor(w*ts/2), rangeUp=ceil) + getTicks.
    function _reconstruct(int24 strike, uint256 width, int24 ts)
        internal
        pure
        returns (int24 tickLower, int24 tickUpper)
    {
        int256 span = int256(width) * int256(ts); // = hi - lo, always > 0
        int256 rangeDown = span / 2; // floor (span > 0)
        int256 rangeUp = span - rangeDown; // ceil
        tickLower = int24(int256(strike) - rangeDown);
        tickUpper = int24(int256(strike) + rangeUp);
    }

    function _assertReconstructs(int24 lo, int24 hi, int24 ts) internal {
        (int24 strike, uint256 width) = _legFromBucket(lo, hi, ts, 0);
        (int24 tl, int24 tu) = _reconstruct(strike, width, ts);
        assertEq(tl, lo, "tickLower == lo");
        assertEq(tu, hi, "tickUpper == hi");
        assertEq(tl % ts, 0, "tickLower tickSpacing-aligned");
        assertEq(tu % ts, 0, "tickUpper tickSpacing-aligned");
    }

    // even span: strike is aligned, textbook case
    function test_legFromBucket_positiveEven() public {
        _assertReconstructs(100, 200, 10);
    }

    // ODD span: strike lands half-a-tickSpacing off-grid, but the reconstructed TICKS are aligned
    function test_legFromBucket_positiveOdd() public {
        _assertReconstructs(100, 130, 10);
    }

    // load-bearing: NEGATIVE odd span. sdiv(low+up,2) truncates toward zero -> strike off by +1 ->
    // reconstructs [-124,-100] (off-grid). floor-strike -> [-125,-100]. This test fails for sdiv.
    function test_legFromBucket_negativeOdd() public {
        _assertReconstructs(-125, -100, 5);
    }

    // any aligned bucket (incl. negatives) reconstructs exactly
    function testFuzz_legFromBucket_reconstructs(int256 loR, uint256 wR, int256 tsR) public {
        int24 ts = int24(bound(tsR, 1, 200));
        int256 tsI = int256(ts);
        uint256 w = bound(wR, 1, 4095);
        int256 lo = bound(loR, I24_MIN / 2, I24_MAX / 2);
        lo = lo - (lo % tsI); // align to tickSpacing (rounds toward zero)
        int256 hi = lo + int256(w) * tsI;
        vm.assume(hi <= I24_MAX);
        _assertReconstructs(int24(lo), int24(hi), ts);
    }

    // ---- Increment 2: the top-level map vol_order_to_panoptic_token_id ----

    // VolOrder packing (pack_vol_order layout): width@128, tickSpacing@104, vol@16, spread@0.
    function _packVO(uint256 width, uint256 tickSpacing, uint256 vol, uint256 spread)
        internal
        pure
        returns (uint256)
    {
        return (width << 128) | (tickSpacing << 104) | (vol << 16) | spread;
    }

    function _tokenId(uint256 packedVO, uint256 poolId) internal returns (uint256) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("tokenIdFromVolOrder(uint256,uint256)", packedVO, poolId));
        require(ok, "tokenIdFromVolOrder reverted");
        return abi.decode(r, (uint256));
    }

    // Panoptic per-leg decoders (layout: base = 64 + 48*leg)
    function _tokenType(uint256 tid, uint256 leg) internal pure returns (uint256) {
        return (tid >> (64 + 48 * leg + 9)) & 1;
    }

    function _isLong(uint256 tid, uint256 leg) internal pure returns (uint256) {
        return (tid >> (64 + 48 * leg + 8)) & 1;
    }

    function _optionRatio(uint256 tid, uint256 leg) internal pure returns (uint256) {
        return (tid >> (64 + 48 * leg + 1)) & 0x7f;
    }

    function _legStrike(uint256 tid, uint256 leg) internal pure returns (int24) {
        return int24(uint24((tid >> (64 + 48 * leg + 12)) & 0xffffff));
    }

    function _legWidth(uint256 tid, uint256 leg) internal pure returns (uint256) {
        return (tid >> (64 + 48 * leg + 36)) & 0xfff;
    }

    function _tickSpacing(uint256 tid) internal pure returns (uint256) {
        return (tid >> 48) & 0xffff;
    }

    // Golden vector: width=1000, ts=10, vol=1 (=> tick 0), spread=0x8000 (~0.5) =>
    // bucket [-500,500], i*=0, split points +-250 => legs [-500,-250],[-250,0],[0,250],[250,500].
    // strikes [-375,-125,125,375], widths [25,25,25,25], tokenType [put,put,call,call], all long.
    function test_map_goldenStructure() public {
        uint256 tid = _tokenId(_packVO(1000, 10, 1, 0x8000), 0);

        assertEq(_tickSpacing(tid), 10, "tickSpacing written exactly once == 10 (not 5x)");

        for (uint256 L = 0; L < 4; L++) {
            assertEq(_isLong(tid, L), 1, "every leg long");
            assertEq(_optionRatio(tid, L), 1, "uniform optionRatio = 1");
        }

        assertEq(_tokenType(tid, 0), 0, "leg0 put (below i*)");
        assertEq(_tokenType(tid, 1), 0, "leg1 put (below i*)");
        assertEq(_tokenType(tid, 2), 1, "leg2 call (above i*)");
        assertEq(_tokenType(tid, 3), 1, "leg3 call (above i*)");

        assertEq(_legStrike(tid, 0), int24(-375), "strike leg0");
        assertEq(_legStrike(tid, 1), int24(-125), "strike leg1");
        assertEq(_legStrike(tid, 2), int24(125), "strike leg2");
        assertEq(_legStrike(tid, 3), int24(375), "strike leg3");

        for (uint256 L = 0; L < 4; L++) {
            assertEq(_legWidth(tid, L), 25, "each leg width 25");
        }
    }

    // ---- Increment 3: feasibility guard (each side >= 2*tickSpacing => two non-degenerate legs) ----

    function _tryTokenId(uint256 packedVO) internal returns (bool ok) {
        (ok,) = harness.staticcall(
            abi.encodeWithSignature("tokenIdFromVolOrder(uint256,uint256)", packedVO, uint256(0))
        );
    }

    // width=20, ts=10 => bucket [-10,10], each side = 1*ts < 2*ts => a side can't make 2 non-degenerate
    // legs (would emit width-0 legs). Must revert rather than build an invalid tokenId.
    function test_map_guard_revertsOnNarrowSide() public {
        assertFalse(_tryTokenId(_packVO(20, 10, 1, 0x8000)), "side < 2*ts must revert");
    }

    // width=40, ts=10 => bucket [-20,20], each side = 2*ts => 2 legs of width 1 each => must succeed.
    function test_map_guard_passesAtExactly2ts() public {
        assertTrue(_tryTokenId(_packVO(40, 10, 1, 0x8000)), "side == 2*ts must succeed");
    }

    // width=200000, ts=10 => each leg spans ~5000 tickSpacings > 4095, overflowing the 12-bit width
    // field (silently masked to a wrong value). Must revert rather than emit a mis-encoded width.
    function test_map_guard_revertsOnWidthOverflow() public {
        assertFalse(_tryTokenId(_packVO(200000, 10, 1, 0x8000)), "leg width >= 4096 must revert");
    }

    // ---- Increment 4: the tokenId must pass Panoptic's TokenId.validate() ----
    // The real TokenIdLibrary can't be imported (pulls PanopticMath -> unresolved OZ), so validate()
    // is replicated verbatim from TokenId.sol:472-518 as the differential oracle.

    uint256 constant CHUNK_MASK =
        0xFFFFFFFFF200_FFFFFFFFF200_FFFFFFFFF200_FFFFFFFFF200_0000000000000000;
    uint256 constant OPTION_RATIO_MASK =
        0x0000000000FE_0000000000FE_0000000000FE_0000000000FE_0000000000000000;
    int24 constant MIN_POOL_TICK = -887272;
    int24 constant MAX_POOL_TICK = 887272;

    function _riskPartner(uint256 tid, uint256 i) internal pure returns (uint256) {
        return (tid >> (64 + 48 * i + 10)) % 4;
    }

    function _strikeSigned(uint256 tid, uint256 i) internal pure returns (int24) {
        return int24(int256(tid >> (64 + 48 * i + 12)));
    }

    function _countLegs(uint256 tid) internal pure returns (uint256 numLegs) {
        uint256 optionRatios = (tid & OPTION_RATIO_MASK) >> 64;
        unchecked {
            while (optionRatios >= (1 << (48 * numLegs))) {
                ++numLegs;
            }
        }
    }

    // faithful port of TokenIdLibrary.validate(): reverts on invalid, returns normally on valid.
    function _validate(uint256 tid) internal pure {
        require(_optionRatio(tid, 0) != 0, "InvalidTokenIdParameter(1)");
        unchecked {
            uint256 chunkData = (tid & CHUNK_MASK) >> 64;
            uint256 numLegs = _countLegs(tid);
            for (uint256 i = 0; i != 4; ++i) {
                if (_optionRatio(tid, i) == 0) {
                    require((tid >> (64 + 48 * i)) == 0, "InvalidTokenIdParameter(1) gap");
                    break;
                }
                for (uint256 j = i + 1; j != numLegs; ++j) {
                    require(
                        uint48(chunkData >> (48 * i)) != uint48(chunkData >> (48 * j)),
                        "InvalidTokenIdParameter(6)"
                    );
                }
                require(
                    _strikeSigned(tid, i) != MIN_POOL_TICK && _strikeSigned(tid, i) != MAX_POOL_TICK,
                    "InvalidTokenIdParameter(4)"
                );
                uint256 rp = _riskPartner(tid, i);
                require(rp <= numLegs - 1, "InvalidTokenIdParameter(3)");
                if (rp != i) {
                    require(_riskPartner(tid, rp) == i, "InvalidTokenIdParameter(3) mutual");
                }
            }
        }
    }

    // the map's tokenId must be accepted by Panoptic's validate()
    function test_map_validatesAsPanoptic() public {
        uint256 tid = _tokenId(_packVO(1000, 10, 1, 0x8000), 0);
        _validate(tid); // reverts if Panoptic would reject it
    }

    // ---- Increment 6: composed-invariant fuzz (regression net over the input space) ----

    function _bucket(uint256 packedVO) internal returns (int24 low, int24 up) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("bucketFromVolOrder(uint256)", packedVO));
        require(ok, "bucketFromVolOrder reverted");
        (int256 lo,, int256 u) = abi.decode(r, (int256, int256, int256));
        low = int24(lo);
        up = int24(u);
    }

    function _center(uint256 packedVO) internal returns (int24) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("centerTick(uint256)", packedVO));
        require(ok, "centerTick reverted");
        return int24(abi.decode(r, (int256)));
    }

    // Over random wide VolOrders (fixed ts, vol => center 0; fuzz width & skew): the tokenId passes
    // validate() AND the 4 legs reconstruct to a contiguous tiling of [i_l,i_u] with the put/call
    // boundary at i*.
    function testFuzz_map_validAndTiles(uint256 wR, uint256 spreadR) public {
        int24 ts = 10;
        uint256 width = bound(wR, 100 * uint256(uint24(ts)), 4000 * uint256(uint24(ts)));
        uint256 spread = bound(spreadR, 0x2000, 0xE000); // skew not extreme (both sides stay >= 2*ts)
        uint256 packedVO = _packVO(width, uint256(uint24(ts)), 1, spread);

        (int24 i_l, int24 i_u) = _bucket(packedVO);
        int24 iStar = _center(packedVO);
        // stay inside the map's feasibility preconditions
        vm.assume(int256(iStar) - int256(i_l) >= 2 * int256(ts));
        vm.assume(int256(i_u) - int256(iStar) >= 2 * int256(ts));

        uint256 tid = _tokenId(packedVO, 0);
        _validate(tid); // Panoptic-valid

        // contiguous tiling: leg L lower == previous upper; last upper == i_u
        int24 prev = i_l;
        int24 boundary1;
        for (uint256 L = 0; L < 4; L++) {
            (int24 tl, int24 tu) = _reconstruct(_legStrike(tid, L), _legWidth(tid, L), ts);
            assertEq(tl, prev, "leg lower == previous upper (contiguous)");
            prev = tu;
            if (L == 1) boundary1 = tu;
        }
        assertEq(prev, i_u, "leg3 upper == i_u (covers support)");
        assertEq(boundary1, iStar, "put/call boundary at i*");
    }
}
