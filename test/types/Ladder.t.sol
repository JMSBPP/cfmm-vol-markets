// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {LiquidityChunk, LiquidityChunkLibrary} from "@types/LiquidityChunk.sol";

/// @title LadderTest
/// @notice Type-law suite for {types/Ladder.plk} — every `require` branch + constructor paths.
/// @dev Chunk-oracle coverage lives in {LadderChunks.t.sol}; VolOrder geometry in {LadderFromVolOrder.t.sol}.
contract LadderTest is PlankTestBase {
    using LiquidityChunkLibrary for LiquidityChunk;

    address internal harness;

    uint256 constant U128_MAX = type(uint128).max;

    int24 constant FIX_LO = -120;
    int24 constant FIX_HI = 120;
    int24 constant FIX_STAR = 0;
    int24 constant FIX_TS = 10;
    uint256 constant FIX_VEGA = 1e18;

    function setUp() public {
        harness = deployPlank("test/types/LadderHarness.plk");
    }

    function _u256ToInt24(uint256 v) internal pure returns (int24) {
        v = v & 0xffffff;
        if (v & 0x800000 != 0) {
            return int24(int256(v | (~uint256(0xffffff))));
        }
        return int24(int256(v));
    }

    function _tryLadderNew(int256 lo, int256 hi, int256 star, uint256 vega, int256 ts) internal returns (bool ok) {
        (ok,) = harness.staticcall(
            abi.encodeWithSignature("tryLadderNew(int256,int256,int256,uint256,int256)", lo, hi, star, vega, ts)
        );
    }

    function _ladderFromVegaTarget(int256 tickLo, int256 tickUp, uint256 vega, int256 ts)
        internal
        returns (int24 lo, int24 hi, int24 star, uint256 vegaOut)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("ladderFromVegaTarget(int256,int256,uint256,int256)", tickLo, tickUp, vega, ts)
        );
        require(ok, "ladderFromVegaTarget reverted");
        (uint256 loU, uint256 hiU, uint256 starU, uint256 vegaU) = abi.decode(r, (uint256, uint256, uint256, uint256));
        lo = _u256ToInt24(loU);
        hi = _u256ToInt24(hiU);
        star = _u256ToInt24(starU);
        vegaOut = vegaU;
    }

    function _ladderIota(int256 lo, int256 hi, int256 ts) internal returns (uint256) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("ladderIota(int256,int256,int256)", lo, hi, ts));
        require(ok, "ladderIota reverted");
        return abi.decode(r, (uint256));
    }

    function _rungTick(int256 lo, int256 hi, int256 star, uint256 vega, int256 ts, uint256 x)
        internal
        returns (int24)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("rungTick(int256,int256,int256,uint256,int256,uint256)", lo, hi, star, vega, ts, x)
        );
        require(ok, "rungTick reverted");
        return _u256ToInt24(abi.decode(r, (uint256)));
    }

    function _rungChunkUnpack(int256 lo, int256 hi, int256 star, uint256 vega, int256 ts, uint256 x)
        internal
        returns (int24 tickLo, int24 tickHi, uint256 liq)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "rungChunkUnpack(int256,int256,int256,uint256,int256,uint256)", lo, hi, star, vega, ts, x
            )
        );
        require(ok, "rungChunkUnpack reverted");
        (uint256 loU, uint256 hiU, uint256 liqU) = abi.decode(r, (uint256, uint256, uint256));
        tickLo = _u256ToInt24(loU);
        tickHi = _u256ToInt24(hiU);
        liq = liqU;
    }

    function _rungChunk(int256 lo, int256 hi, int256 star, uint256 vega, int256 ts, uint256 x)
        internal
        returns (uint256)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("rungChunk(int256,int256,int256,uint256,int256,uint256)", lo, hi, star, vega, ts, x)
        );
        require(ok, "rungChunk reverted");
        return abi.decode(r, (uint256));
    }

    function _materializeChunks(int256 lo, int256 hi, int256 star, uint256 vega, int256 ts)
        internal
        returns (bytes memory)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("materializeChunks(int256,int256,int256,uint256,int256)", lo, hi, star, vega, ts)
        );
        require(ok, "materializeChunks reverted");
        return r;
    }

    function _materializeViaAccumulator(int256 lo, int256 hi, int256 star, uint256 vega, int256 ts)
        internal
        returns (bytes memory)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("materializeViaAccumulator(int256,int256,int256,uint256,int256)", lo, hi, star, vega, ts)
        );
        require(ok, "materializeViaAccumulator reverted");
        return r;
    }

    function _rungLiquidityWrongIota(int256 lo, int256 hi, int256 star, uint256 vega, int256 ts, uint256 x)
        internal
        returns (bool ok)
    {
        (ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "rungLiquidityWrongIota(int256,int256,int256,uint256,int256,uint256)", lo, hi, star, vega, ts, x
            )
        );
    }

    // --- ladder_new invariants (each require branch) ---

    function test_ladderNew_reverts_when_lo_ge_star() public {
        assertFalse(_tryLadderNew(0, 120, 0, FIX_VEGA, FIX_TS));
    }

    function test_ladderNew_reverts_when_star_ge_hi() public {
        assertFalse(_tryLadderNew(FIX_LO, FIX_HI, FIX_HI, FIX_VEGA, FIX_TS));
    }

    function test_ladderNew_reverts_when_lo_misaligned() public {
        assertFalse(_tryLadderNew(1, 120, 10, FIX_VEGA, FIX_TS));
    }

    function test_ladderNew_reverts_when_hi_misaligned() public {
        assertFalse(_tryLadderNew(FIX_LO, 121, FIX_STAR, FIX_VEGA, FIX_TS));
    }

    function test_ladderNew_reverts_when_star_misaligned() public {
        assertFalse(_tryLadderNew(FIX_LO, FIX_HI, 1, FIX_VEGA, FIX_TS));
    }

    function test_ladderNew_reverts_when_vega_zero() public {
        assertFalse(_tryLadderNew(FIX_LO, FIX_HI, FIX_STAR, 0, FIX_TS));
    }

    function test_ladderNew_reverts_when_vega_overflow() public {
        assertFalse(_tryLadderNew(FIX_LO, FIX_HI, FIX_STAR, U128_MAX + 1, FIX_TS));
    }

    // ι < 2 is unreachable: with Δ-aligned ticks and lo < star < hi, star must sit strictly
    // between lo and hi on the spacing grid, so (hi - lo) / Δ_i ≥ 2. The ι ≥ 1 require in
    // ladder_new is defensive; ladder_new is still instantiated via the tests above.

    function test_ladderNew_accepts_valid_fixture() public {
        assertTrue(_tryLadderNew(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS));
    }

    // --- ladder_from_vega_target ---

    function test_ladderFromVegaTarget_matchesExplicitSpan() public {
        (int24 lo, int24 hi, int24 star, uint256 vega) =
            _ladderFromVegaTarget(FIX_LO, FIX_HI, FIX_VEGA, FIX_TS);
        assertEq(lo, FIX_LO, "lo");
        assertEq(hi, FIX_HI, "hi");
        assertEq(star, FIX_STAR, "star");
        assertEq(vega, FIX_VEGA, "vega");
    }

    function test_ladderFromVegaTarget_star_is_mid_tick() public {
        (, , int24 star,) = _ladderFromVegaTarget(FIX_LO, FIX_HI, FIX_VEGA, FIX_TS);
        assertEq(star, FIX_STAR, "mid_tick for symmetric span");
    }

    // --- rung index / tick law ---

    function test_rungTick_matchesLo_plus_xTs() public {
        uint256 iota = _ladderIota(FIX_LO, FIX_HI, FIX_TS);
        for (uint256 x = 0; x < iota; x++) {
            int24 tick = _rungTick(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS, x);
            assertEq(tick, FIX_LO + int24(int256(x)) * FIX_TS, "rung tick");
        }
    }

    function test_rungIndex_reverts_when_x_ge_iota() public {
        uint256 iota = _ladderIota(FIX_LO, FIX_HI, FIX_TS);
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "rungTick(int256,int256,int256,uint256,int256,uint256)",
                FIX_LO,
                FIX_HI,
                FIX_STAR,
                FIX_VEGA,
                FIX_TS,
                iota
            )
        );
        assertFalse(ok, "x == iota must revert at rung_index");
    }

    // --- rung chunk unpack round-trip ---

    function test_rungChunkUnpack_matchesPackedWord() public {
        uint256 iota = _ladderIota(FIX_LO, FIX_HI, FIX_TS);
        for (uint256 x = 0; x < iota; x++) {
            (int24 tickLo, int24 tickHi, uint256 liq) =
                _rungChunkUnpack(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS, x);
            assertEq(tickLo, FIX_LO + int24(int256(x)) * FIX_TS, "tickLo");
            assertEq(tickHi, tickLo + FIX_TS, "tickHi");
            assertGt(liq, 0, "liq > 0");
            uint256 packed = _rungChunk(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS, x);
            assertEq(
                packed,
                uint256(LiquidityChunk.unwrap(LiquidityChunkLibrary.createChunk(tickLo, tickHi, uint128(liq)))),
                "unpack matches Panoptic createChunk"
            );
        }
    }

    // --- accumulator vs direct materialize ---

    function test_materializeViaAccumulator_matchesMaterializeChunks() public {
        bytes memory direct = _materializeChunks(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS);
        bytes memory acc = _materializeViaAccumulator(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS);
        assertEq(keccak256(acc), keccak256(direct), "accumulator path == materialize_chunks");
    }

    // --- iota chunk length guard ---

    function test_rungLiquidity_reverts_when_iotaChunk_wrongLength() public {
        assertFalse(_rungLiquidityWrongIota(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS, 0));
    }
}
