// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {LiquidityChunk, LiquidityChunkLibrary} from "@types/LiquidityChunk.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";

/// @dev Spec oracle for Payoffs.LadderPosition.ladderChunks:
///   L(i_x) = mulDiv(ΔQ_v*, ℓ(ξ*, ι; x), Q96) with ℓ from geometric_liquidity_density_x96.
contract LadderChunksTest is PlankTestBase {
    using LiquidityChunkLibrary for LiquidityChunk;

    address internal ladderHarness;
    address internal geoHarness;

    uint256 constant Q96 = 1 << 96;

    int24 constant FIX_LO = -120;
    int24 constant FIX_HI = 120;
    int24 constant FIX_STAR = 0;
    int24 constant FIX_TS = 10;
    uint256 constant FIX_VEGA = 1e18;

    function setUp() public {
        ladderHarness = deployPlank("test/types/LadderHarness.plk");
        geoHarness = deployPlank("test/lib/ldf/GeometricLibHarness.plk");
    }

    function _ladderIota(int256 lo, int256 hi, int256 ts) internal returns (uint256) {
        (bool ok, bytes memory r) =
            ladderHarness.staticcall(abi.encodeWithSignature("ladderIota(int256,int256,int256)", lo, hi, ts));
        require(ok, "ladderIota reverted");
        return abi.decode(r, (uint256));
    }

    function _rungLiquidity(int256 lo, int256 hi, int256 star, uint256 vega, int256 ts, uint256 x)
        internal
        returns (uint256)
    {
        (bool ok, bytes memory r) = ladderHarness.staticcall(
            abi.encodeWithSignature("rungLiquidity(int256,int256,int256,uint256,int256,uint256)", lo, hi, star, vega, ts, x)
        );
        require(ok, "rungLiquidity reverted");
        return abi.decode(r, (uint256));
    }

    function _rungChunk(int256 lo, int256 hi, int256 star, uint256 vega, int256 ts, uint256 x)
        internal
        returns (uint256)
    {
        (bool ok, bytes memory r) = ladderHarness.staticcall(
            abi.encodeWithSignature("rungChunk(int256,int256,int256,uint256,int256,uint256)", lo, hi, star, vega, ts, x)
        );
        require(ok, "rungChunk reverted");
        return abi.decode(r, (uint256));
    }

    function _materializeChunks(int256 lo, int256 hi, int256 star, uint256 vega, int256 ts)
        internal
        returns (bytes memory)
    {
        (bool ok, bytes memory r) = ladderHarness.staticcall(
            abi.encodeWithSignature("materializeChunks(int256,int256,int256,uint256,int256)", lo, hi, star, vega, ts)
        );
        require(ok, "materializeChunks reverted");
        return r;
    }

    function _geoDensity(int24 roundedTick, int24 ts, int24 minTick, int24 length, uint256 alpha)
        internal
        returns (uint256)
    {
        (bool ok, bytes memory r) = geoHarness.staticcall(
            abi.encodeWithSignature("geoDensity(int24,int24,int24,int24,uint256)", roundedTick, ts, minTick, length, alpha)
        );
        require(ok, "geoDensity reverted");
        return abi.decode(r, (uint256));
    }

    function _xiStar(int24 ts) internal pure returns (uint256) {
        return TickMath.getSqrtRatioAtTick(-ts);
    }

    function _oracleLiq(int256 lo, int256 hi, int256 star, uint256 vega, int256 ts, uint256 x)
        internal
        returns (uint256)
    {
        uint256 iota = _ladderIota(lo, hi, ts);
        int24 lo24 = int24(lo);
        int24 ts24 = int24(ts);
        int24 rungTick = lo24 + int24(int256(x)) * ts24;
        uint256 ell = _geoDensity(rungTick, ts24, lo24, int24(int256(iota)), _xiStar(ts24));
        return (vega * ell) / Q96;
    }

    function _panopticChunk(int24 tickLo, int24 tickHi, uint256 liq) internal pure returns (uint256) {
        return uint256(
            LiquidityChunk.unwrap(LiquidityChunkLibrary.createChunk(tickLo, tickHi, uint128(liq)))
        );
    }

    // spec iota: ι = (i_U - i_L) / Δ_i
    function test_ladderIota_matchesSpec() public {
        assertEq(_ladderIota(FIX_LO, FIX_HI, FIX_TS), uint256(int256(FIX_HI - FIX_LO)) / uint256(int256(FIX_TS)));
    }

    // spec ladderChunks: L(i_x) = mulDiv(ΔQ_v*, ℓ(ξ*, ι; x), Q96) for every rung
    function test_rungLiquidity_matchesSpecOracle() public {
        uint256 iota = _ladderIota(FIX_LO, FIX_HI, FIX_TS);
        for (uint256 x = 0; x < iota; x++) {
            assertEq(
                _rungLiquidity(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS, x),
                _oracleLiq(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS, x),
                "L(i_x) must match mulDiv(vega, ell, Q96)"
            );
        }
    }

    // spec createChunk(i_x, i_x + Δ_i, liq); liq > 0
    function test_rungChunk_matchesCreateChunk() public {
        uint256 iota = _ladderIota(FIX_LO, FIX_HI, FIX_TS);
        for (uint256 x = 0; x < iota; x++) {
            uint256 liq = _rungLiquidity(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS, x);
            assertGt(liq, 0, "spec: zero liquidity rung is an error");
            int24 tickLo = FIX_LO + int24(int256(x)) * FIX_TS;
            int24 tickHi = tickLo + FIX_TS;
            assertEq(
                _rungChunk(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS, x),
                _panopticChunk(tickLo, tickHi, liq),
                "packed chunk must match Panoptic createChunk"
            );
        }
    }

    // spec ladderChunks list comp ≡ ladder_materialize_chunks driver
    function test_materializeChunks_matchesRungChunk() public {
        uint256 iota = _ladderIota(FIX_LO, FIX_HI, FIX_TS);
        bytes memory raw = _materializeChunks(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS);
        assertEq(raw.length, iota * 32, "materialize returns iota words");
        for (uint256 x = 0; x < iota; x++) {
            uint256 word;
            assembly {
                word := mload(add(add(raw, 32), mul(x, 32)))
            }
            assertEq(
                word,
                _rungChunk(FIX_LO, FIX_HI, FIX_STAR, FIX_VEGA, FIX_TS, x),
                "materialize[x] == rungChunk(x)"
            );
        }
    }

    // spec LiquidityGrid: Σ_x ℓ(ξ*, ι; x) ≈ Q96 (partition of unity)
    function test_ellPartition_sumsToQ96() public {
        uint256 iota = _ladderIota(FIX_LO, FIX_HI, FIX_TS);
        uint256 xi = _xiStar(FIX_TS);
        uint256 sum;
        for (uint256 x = 0; x < iota; x++) {
            int24 rungTick = FIX_LO + int24(int256(x)) * FIX_TS;
            sum += _geoDensity(rungTick, FIX_TS, FIX_LO, int24(int256(iota)), xi);
        }
        assertApproxEqRel(sum, Q96, 1e12, "sum ell ~ Q96");
    }

    function testFuzz_rungLiquidity_matchesSpecOracle(
        int256 loR,
        uint256 spanR,
        uint256 starOffR,
        uint256 vegaR,
        uint256 tsR,
        uint256 xR
    ) public {
        int24 ts = int24(int256(bound(tsR, 1, 60)));
        uint256 span = bound(spanR, 2, 40);
        int24 lo = int24(int256(bound(loR, -400_000, 400_000)));
        lo = _alignDown(lo, ts);
        int24 hi = lo + int24(int256(span)) * ts;
        uint256 starOff = bound(starOffR, 1, span - 1);
        int24 star = lo + int24(int256(starOff)) * ts;
        uint256 vega = bound(vegaR, Q96, type(uint128).max);
        uint256 iota = _ladderIota(lo, hi, ts);
        uint256 x = bound(xR, 0, iota - 1);

        assertEq(
            _rungLiquidity(lo, hi, star, vega, ts, x),
            _oracleLiq(lo, hi, star, vega, ts, x),
            "fuzz: L(i_x) matches spec oracle"
        );
    }

    function _alignDown(int24 tick, int24 ts) internal pure returns (int24) {
        int256 t = int256(tick);
        int256 s = int256(ts);
        int256 q = t / s;
        if (t < 0 && (t % s) != 0) q -= 1;
        return int24(q * s);
    }
}
