// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "../PlankTestBase.sol";

/// @title VolPositionTest
/// @notice Task 1 RED: `vol_position_from_ladder` product — book weights/base + ladder span on wide fixture.
/// @dev Harness calls `vol_position_from_ladder` (VolPosition.plk + Binning.plk).
contract VolPositionTest is PlankTestBase {
    address internal harness;

    uint256 constant SYM_STRIKE = 1;
    uint256 constant SYM_SKEW = 32768;
    uint256 constant SYM_VEGA = 1e18;
    int24 constant SYM_TS = 10;

    uint256 constant WIDE_WIDTH = 4000;
    int24 constant WIDE_LO = -2000;
    int24 constant WIDE_HI = 2000;

    uint256 constant BOUND_PANOPTIC = 127;
    uint256 constant OR_MIN_DEFAULT = 8;

    struct VolPositionView {
        uint256 w0;
        uint256 w1;
        uint256 w2;
        uint256 w3;
        uint256 base;
        int24 ladderLo;
        int24 ladderHi;
    }

    function setUp() public {
        harness = deployPlank("test/types/VolPositionHarness.plk");
    }

    function _u256ToInt24(uint256 v) internal pure returns (int24) {
        v = v & 0xffffff;
        if (v & 0x800000 != 0) {
            return int24(int256(v | (~uint256(0xffffff))));
        }
        return int24(int256(v));
    }

    function _volPositionFromLadder(
        uint256 orMin,
        uint256 bound,
        uint256 strike,
        uint256 width,
        uint256 skew,
        uint256 vega,
        uint256 ts,
        uint64 poolId
    ) internal returns (VolPositionView memory vp) {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "volPositionFromLadder(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)",
                orMin,
                bound,
                strike,
                width,
                skew,
                vega,
                ts,
                uint256(poolId)
            )
        );
        require(ok, "volPositionFromLadder reverted");
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3, uint256 base, uint256 lo, uint256 hi) =
            abi.decode(r, (uint256, uint256, uint256, uint256, uint256, uint256, uint256));
        vp = VolPositionView({
            w0: w0,
            w1: w1,
            w2: w2,
            w3: w3,
            base: base,
            ladderLo: _u256ToInt24(lo),
            ladderHi: _u256ToInt24(hi)
        });
    }

    function _roundBound(uint256 b, uint256 n, uint256 nMax) internal pure returns (uint256) {
        return (b * n + nMax / 2) / nMax;
    }

    function _max4(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256) {
        uint256 m = a > b ? a : b;
        m = m > c ? m : c;
        return m > d ? m : d;
    }

    function _binNotionals(uint256 strike, uint256 width, uint256 skew, uint256 vega, uint256 ts)
        internal
        returns (uint256 n0, uint256 n1, uint256 n2, uint256 n3)
    {
        address binHarness = deployPlank("test/lib/protocol_integrations/panoptic_v2/BinningHarness.plk");
        (bool ok, bytes memory r) = binHarness.staticcall(
            abi.encodeWithSignature(
                "binNotionals(uint256,uint256,uint256,uint256,uint256)", strike, width, skew, vega, ts
            )
        );
        require(ok, "binNotionals reverted");
        (n0, n1, n2, n3) = abi.decode(r, (uint256, uint256, uint256, uint256));
    }

    function test_volPosition_wide_bookMatchesBinningOracle() public {
        uint256 ts = uint256(uint24(SYM_TS));
        (uint256 n0, uint256 n1, uint256 n2, uint256 n3) =
            _binNotionals(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, ts);
        uint256 nMax = _max4(n0, n1, n2, n3);

        VolPositionView memory vp = _volPositionFromLadder(
            OR_MIN_DEFAULT, BOUND_PANOPTIC, SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, ts, 0
        );

        assertEq(vp.w0, _roundBound(BOUND_PANOPTIC, n0, nMax), "w0");
        assertEq(vp.w1, _roundBound(BOUND_PANOPTIC, n1, nMax), "w1");
        assertEq(vp.w2, _roundBound(BOUND_PANOPTIC, n2, nMax), "w2");
        assertEq(vp.w3, _roundBound(BOUND_PANOPTIC, n3, nMax), "w3");
        assertEq(vp.base, nMax / BOUND_PANOPTIC, "base");
        assertEq(vp.ladderLo, WIDE_LO, "ladder.lo");
        assertEq(vp.ladderHi, WIDE_HI, "ladder.hi");
    }

    function test_volPosition_orMinAboveMaxWeight_reverts() public {
        uint256 ts = uint256(uint24(SYM_TS));
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "volPositionFromLadder(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)",
                BOUND_PANOPTIC + 1,
                BOUND_PANOPTIC,
                SYM_STRIKE,
                WIDE_WIDTH,
                SYM_SKEW,
                SYM_VEGA,
                ts,
                uint256(0)
            )
        );
        assertFalse(ok, "orMin > bound must revert");
    }
}
