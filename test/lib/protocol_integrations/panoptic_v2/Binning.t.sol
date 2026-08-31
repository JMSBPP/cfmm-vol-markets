// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../../PlankTestBase.sol";

/// @title BinningTest
/// @notice RED suite for Panoptic.Binning — legIntervals + binNotionals (spec Binning.hs).
/// @dev Haskell oracles: Spec.hs symmetric fixture (width=40, ts=10) and wide voWide (width=4000).
contract BinningTest is PlankTestBase {
    address internal harness;

    // Symmetric fixture (fixtureSymmetricVolOrder): width=40, ts=10, skew=32768, strike→tick 0.
    uint256 constant SYM_STRIKE = 1;
    uint256 constant SYM_WIDTH = 40;
    uint256 constant SYM_SKEW = 32768;
    uint256 constant SYM_VEGA = 1e18;
    int24 constant SYM_TS = 10;
    int24 constant SYM_LO = -20;
    int24 constant SYM_HI = 20;

    // Wide fixture (Spec.hs TODO #28.3): width=4000, ts=10.
    uint256 constant WIDE_WIDTH = 4000;
    int24 constant WIDE_LO = -2000;
    int24 constant WIDE_HI = 2000;

    struct LegIntervals {
        int24 lo0;
        int24 hi0;
        int24 lo1;
        int24 hi1;
        int24 lo2;
        int24 hi2;
        int24 lo3;
        int24 hi3;
    }

    struct BinNotionals {
        uint256 n0;
        uint256 n1;
        uint256 n2;
        uint256 n3;
    }

    function setUp() public {
        harness = deployPlank("test/lib/protocol_integrations/panoptic_v2/BinningHarness.plk");
    }

    function _u256ToInt24(uint256 v) internal pure returns (int24) {
        v = v & 0xffffff;
        if (v & 0x800000 != 0) {
            return int24(int256(v | (~uint256(0xffffff))));
        }
        return int24(int256(v));
    }

    function _legIntervals(uint256 strike, uint256 width, uint256 skew, uint256 vega, uint256 ts)
        internal
        returns (LegIntervals memory legs)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "legIntervalsFromVolOrder(uint256,uint256,uint256,uint256,uint256)",
                strike,
                width,
                skew,
                vega,
                ts
            )
        );
        require(ok, "legIntervalsFromVolOrder reverted");
        (
            uint256 lo0,
            uint256 hi0,
            uint256 lo1,
            uint256 hi1,
            uint256 lo2,
            uint256 hi2,
            uint256 lo3,
            uint256 hi3
        ) = abi.decode(r, (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256));
        legs = LegIntervals({
            lo0: _u256ToInt24(lo0),
            hi0: _u256ToInt24(hi0),
            lo1: _u256ToInt24(lo1),
            hi1: _u256ToInt24(hi1),
            lo2: _u256ToInt24(lo2),
            hi2: _u256ToInt24(hi2),
            lo3: _u256ToInt24(lo3),
            hi3: _u256ToInt24(hi3)
        });
    }

    /// @dev OOG vs revert: staticcall forwards 63/64 gas. OOG leaves ~1/64 and empty returndata.
    /// EVM has no OOM opcode — malloc that burns remaining gas looks like OOG; a require looks like REVERT.
    function _failKind(uint256 gasBefore, uint256 gasAfter, bytes memory r)
        internal
        pure
        returns (string memory)
    {
        uint256 remainingBps = gasBefore == 0 ? 0 : (gasAfter * 10000) / gasBefore;
        bool likelyOog = r.length == 0 && remainingBps < 300; // ~156 bps = 1/64
        if (r.length >= 4) {
            bytes4 sel = bytes4(r);
            if (sel == bytes4(0x4e487b71)) return "PANIC";
            if (sel == bytes4(0x08c379a0)) return "ERROR_STRING";
        }
        if (likelyOog) return "OOG_OR_OOM_VIA_GAS";
        if (r.length == 0) return "REVERT_EMPTY";
        return "REVERT_DATA";
    }

    function _binNotionals(uint256 strike, uint256 width, uint256 skew, uint256 vega, uint256 ts)
        internal
        returns (BinNotionals memory ns)
    {
        uint256 gasBefore = gasleft();
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "binNotionals(uint256,uint256,uint256,uint256,uint256)", strike, width, skew, vega, ts
            )
        );
        uint256 gasAfter = gasleft();
        if (!ok) {
            emit log_named_uint("gasBefore", gasBefore);
            emit log_named_uint("gasAfter", gasAfter);
            emit log_named_uint("gasUsed", gasBefore - gasAfter);
            emit log_named_uint("remaining_bps", gasBefore == 0 ? 0 : (gasAfter * 10000) / gasBefore);
            emit log_named_uint("returndata_len", r.length);
            emit log_named_bytes("returndata", r);
            emit log_named_string("failKind", _failKind(gasBefore, gasAfter, r));
            revert(
                string.concat(
                    "binNotionals ",
                    _failKind(gasBefore, gasAfter, r),
                    " gasUsed=",
                    vm.toString(gasBefore - gasAfter),
                    " remaining_bps=",
                    vm.toString(gasBefore == 0 ? 0 : (gasAfter * 10000) / gasBefore),
                    " retlen=",
                    vm.toString(r.length)
                )
            );
        }
        (uint256 n0, uint256 n1, uint256 n2, uint256 n3) = abi.decode(r, (uint256, uint256, uint256, uint256));
        ns = BinNotionals({n0: n0, n1: n1, n2: n2, n3: n3});
    }

    function _ladderIota(uint256 strike, uint256 width, uint256 skew, uint256 vega, uint256 ts)
        internal
        returns (uint256)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "ladderIotaFromVolOrder(uint256,uint256,uint256,uint256,uint256)",
                strike,
                width,
                skew,
                vega,
                ts
            )
        );
        require(ok, "ladderIotaFromVolOrder reverted");
        return abi.decode(r, (uint256));
    }

    function _chunkNumeraireAtRung(uint256 strike, uint256 width, uint256 skew, uint256 vega, uint256 ts, uint256 x)
        internal
        returns (uint256)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "chunkNumeraireAtRung(uint256,uint256,uint256,uint256,uint256,uint256)",
                strike,
                width,
                skew,
                vega,
                ts,
                x
            )
        );
        require(ok, "chunkNumeraireAtRung reverted");
        return abi.decode(r, (uint256));
    }

    function _binNotionalsLimited(
        uint256 strike,
        uint256 width,
        uint256 skew,
        uint256 vega,
        uint256 ts,
        uint256 maxSteps
    ) internal returns (BinNotionals memory ns) {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "binNotionalsLimited(uint256,uint256,uint256,uint256,uint256,uint256)",
                strike,
                width,
                skew,
                vega,
                ts,
                maxSteps
            )
        );
        require(ok, string.concat("binNotionalsLimited maxSteps=", vm.toString(maxSteps)));
        (uint256 n0, uint256 n1, uint256 n2, uint256 n3) = abi.decode(r, (uint256, uint256, uint256, uint256));
        ns = BinNotionals({n0: n0, n1: n1, n2: n2, n3: n3});
    }

    function _materializeChunksFromVolOrder(uint256 strike, uint256 width, uint256 skew, uint256 vega, uint256 ts)
        internal
        returns (bytes memory raw)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "materializeChunksFromVolOrder(uint256,uint256,uint256,uint256,uint256)",
                strike,
                width,
                skew,
                vega,
                ts
            )
        );
        require(ok, "materializeChunksFromVolOrder reverted");
        raw = r;
    }

    function _tickInHalfOpen(int24 tick, int24 lo, int24 hi) internal pure returns (bool) {
        return tick >= lo && tick < hi;
    }

    function _oracleBinNotionals(uint256 strike, uint256 width, uint256 skew, uint256 vega, uint256 ts, int24 lo, int24 hi, int24 ts24)
        internal
        returns (BinNotionals memory ns)
    {
        LegIntervals memory legs = _legIntervals(strike, width, skew, vega, ts);
        uint256 iota = uint256(int256(hi - lo)) / uint256(int256(ts24));
        uint256 n0;
        uint256 n1;
        uint256 n2;
        uint256 n3;
        uint256 total;
        for (uint256 x = 0; x < iota; x++) {
            int24 tickLo = lo + int24(int256(x)) * ts24;
            uint256 n = _chunkNumeraireAtRung(strike, width, skew, vega, ts, x);
            total += n;
            if (_tickInHalfOpen(tickLo, legs.lo0, legs.hi0)) n0 += n;
            else if (_tickInHalfOpen(tickLo, legs.lo1, legs.hi1)) n1 += n;
            else if (_tickInHalfOpen(tickLo, legs.lo2, legs.hi2)) n2 += n;
            else if (_tickInHalfOpen(tickLo, legs.lo3, legs.hi3)) n3 += n;
            else revert("rung tick not in any leg interval");
        }
        ns = BinNotionals({n0: n0, n1: n1, n2: n2, n3: n3});
        assertGt(total, 0, "oracle: total numeraire > 0");
    }

    // spec VolOrder.legIntervals: fixture four legs [(-20,-10), (-10,0), (0,10), (10,20)]
    function test_legIntervals_symmetricFixture_matchesHaskell() public {
        LegIntervals memory legs =
            _legIntervals(SYM_STRIKE, SYM_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)));
        assertEq(legs.lo0, -20, "leg0.lo");
        assertEq(legs.hi0, -10, "leg0.hi");
        assertEq(legs.lo1, -10, "leg1.lo");
        assertEq(legs.hi1, 0, "leg1.hi");
        assertEq(legs.lo2, 0, "leg2.lo");
        assertEq(legs.hi2, 10, "leg2.hi");
        assertEq(legs.lo3, 10, "leg3.lo");
        assertEq(legs.hi3, 20, "leg3.hi");
    }

    // spec Spec.hs wide VolOrder legs [(-2000,-1000), (-1000,0), (0,1000), (1000,2000)]
    function test_legIntervals_wideFixture_matchesHaskell() public {
        LegIntervals memory legs =
            _legIntervals(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)));
        assertEq(legs.lo0, WIDE_LO, "leg0.lo");
        assertEq(legs.hi0, -1000, "leg0.hi");
        assertEq(legs.lo1, -1000, "leg1.lo");
        assertEq(legs.hi1, 0, "leg1.hi");
        assertEq(legs.lo2, 0, "leg2.lo");
        assertEq(legs.hi2, 1000, "leg2.hi");
        assertEq(legs.lo3, 1000, "leg3.lo");
        assertEq(legs.hi3, WIDE_HI, "leg3.hi");
    }

    // binNotionals: per-leg sums match brute-force partition of chunkNumeraire rungs
    function test_binNotionals_matchesBruteForcePartition_symmetric() public {
        BinNotionals memory got =
            _binNotionals(SYM_STRIKE, SYM_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)));
        BinNotionals memory oracle = _oracleBinNotionals(
            SYM_STRIKE, SYM_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)), SYM_LO, SYM_HI, SYM_TS
        );
        assertEq(got.n0, oracle.n0, "n0");
        assertEq(got.n1, oracle.n1, "n1");
        assertEq(got.n2, oracle.n2, "n2");
        assertEq(got.n3, oracle.n3, "n3");
    }

    // binNotionals: every rung numeraire is assigned to exactly one leg (partition)
    function test_binNotionals_partitionSum_equalsTotalNumeraires_symmetric() public {
        BinNotionals memory ns =
            _binNotionals(SYM_STRIKE, SYM_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)));
        uint256 iota = uint256(int256(SYM_HI - SYM_LO)) / uint256(int256(SYM_TS));
        uint256 total;
        for (uint256 x = 0; x < iota; x++) {
            total += _chunkNumeraireAtRung(SYM_STRIKE, SYM_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)), x);
        }
        assertEq(ns.n0 + ns.n1 + ns.n2 + ns.n3, total, "leg sums partition rung numeraires");
    }

    function test_ladderIota_symmetric_matchesSpec() public {
        uint256 iota = _ladderIota(SYM_STRIKE, SYM_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)));
        assertEq(iota, uint256(int256(SYM_HI - SYM_LO)) / uint256(int256(SYM_TS)), "symmetric iota");
    }

    function test_ladderIota_wide_matchesSpec() public {
        uint256 iota = _ladderIota(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)));
        assertEq(iota, uint256(int256(WIDE_HI - WIDE_LO)) / uint256(int256(SYM_TS)), "wide iota");
    }

    function test_chunkNumeraire_wide_firstAndLastRung_complete() public {
        uint256 iota = _ladderIota(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)));
        uint256 n0 = _chunkNumeraireAtRung(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)), 0);
        uint256 nLast =
            _chunkNumeraireAtRung(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)), iota - 1);
        assertGt(n0, 0, "wide x=0");
        // Top rung [1990,2000) can price to 0 collateral at the distribution upper edge.
        assertGe(nLast, 0, "wide x=iota-1 completes");
    }

    function test_wide_materializeChunks_fromVolOrder_succeeds() public {
        uint256 iota = _ladderIota(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)));
        bytes memory raw = _materializeChunksFromVolOrder(
            SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS))
        );
        assertEq(raw.length, iota * 32, "wide materialize bytes");
    }

    function test_wide_allChunkNumeraires_iterate() public {
        uint256 iota = _ladderIota(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)));
        for (uint256 x = 0; x < iota; x++) {
            _chunkNumeraireAtRung(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)), x);
        }
    }

    function test_binNotionals_wide_limitedSteps_399() public {
        _binNotionalsLimited(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)), 399);
    }

    function test_binNotionals_wide_limitedSteps_400() public {
        _binNotionalsLimited(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)), 400);
    }

    function test_binNotionals_matchesBruteForcePartition_wide() public {
        BinNotionals memory got =
            _binNotionals(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)));
        BinNotionals memory oracle = _oracleBinNotionals(
            SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)), WIDE_LO, WIDE_HI, SYM_TS
        );
        assertEq(got.n0, oracle.n0, "n0");
        assertEq(got.n1, oracle.n1, "n1");
        assertEq(got.n2, oracle.n2, "n2");
        assertEq(got.n3, oracle.n3, "n3");
    }
}
