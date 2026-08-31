// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";

/// @dev Spec oracle: Panoptic.Binning.ladderFromVolOrder / fixtureSymmetricVolOrder
///   width=40, ts=10, skew=32768 → bucket [-20, 20], i* = 0.
///   Plank vol strike: use 1 (center tick 0), not Haskell Q96 — volQ64X96 shifts vol<<64.
contract LadderFromVolOrderTest is PlankTestBase {
    address internal harness;

    uint256 constant FIX_STRIKE = 1;
    uint256 constant FIX_WIDTH = 40;
    uint256 constant FIX_SKEW = 32768;
    uint256 constant FIX_VEGA = 1e18;
    int24 constant FIX_TS = 10;
    int24 constant FIX_LO = -20;
    int24 constant FIX_HI = 20;
    int24 constant FIX_STAR = 0;

    function setUp() public {
        harness = deployPlank("test/lib/protocol_integrations/panoptic_v2/BinningHarness.plk");
    }

    function _u24ToInt24(uint256 v) internal pure returns (int24) {
        v = v & 0xffffff;
        if (v & 0x800000 != 0) {
            return int24(int256(v | (~uint256(0xffffff))));
        }
        return int24(int256(v));
    }

    function _ladderGeometry(uint256 strike, uint256 width, uint256 skew, uint256 targetVega, uint256 ts)
        internal
        returns (int24 lo, int24 hi, int24 star, uint256 vega)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "ladderGeometryFromVolOrder(uint256,uint256,uint256,uint256,uint256)",
                strike,
                width,
                skew,
                targetVega,
                ts
            )
        );
        require(ok, "ladderGeometryFromVolOrder reverted");
        (uint256 loU, uint256 hiU, uint256 starU, uint256 vegaU) = abi.decode(r, (uint256, uint256, uint256, uint256));
        lo = _u24ToInt24(loU);
        hi = _u24ToInt24(hiU);
        star = _u24ToInt24(starU);
        vega = vegaU;
    }

    function _ladderFromVolOrder(uint256 strike, uint256 width, uint256 skew, uint256 targetVega, uint256 ts)
        internal
        returns (int24 lo, int24 hi, int24 star, uint256 vega)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "ladderFromVolOrder(uint256,uint256,uint256,uint256,uint256)",
                strike,
                width,
                skew,
                targetVega,
                ts
            )
        );
        require(ok, "ladderFromVolOrder reverted");
        (uint256 loU, uint256 hiU, uint256 starU, uint256 vegaU) = abi.decode(r, (uint256, uint256, uint256, uint256));
        lo = _u24ToInt24(loU);
        hi = _u24ToInt24(hiU);
        star = _u24ToInt24(starU);
        vega = vegaU;
    }

    function test_geometry_matches_symmetric_fixture() public {
        (int24 lo, int24 hi, int24 star, uint256 vega) =
            _ladderGeometry(FIX_STRIKE, FIX_WIDTH, FIX_SKEW, FIX_VEGA, uint256(uint24(FIX_TS)));
        assertEq(lo, FIX_LO, "lo");
        assertEq(hi, FIX_HI, "hi");
        assertEq(star, FIX_STAR, "star");
        assertEq(vega, FIX_VEGA, "vega");
    }

    function test_ladderFromVolOrder_matches_geometry() public {
        (int24 lo, int24 hi, int24 star, uint256 vega) =
            _ladderFromVolOrder(FIX_STRIKE, FIX_WIDTH, FIX_SKEW, FIX_VEGA, uint256(uint24(FIX_TS)));
        assertEq(lo, FIX_LO, "lo");
        assertEq(hi, FIX_HI, "hi");
        assertEq(star, FIX_STAR, "star");
        assertEq(vega, FIX_VEGA, "vega");
    }
}
