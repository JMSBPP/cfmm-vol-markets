// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../../PlankTestBase.sol";

/// @title BinningTest
/// @notice Suite for Panoptic.Binning — legIntervals + binNotionals + binToLegs (spec Binning.hs).
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

    uint256 constant BOUND_PANOPTIC = 127;
    uint256 constant OR_MIN_DEFAULT = 8;

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

    struct BinToLegs {
        uint256 w0;
        uint256 w1;
        uint256 w2;
        uint256 w3;
        uint256 base;
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

    function _binNotionals(uint256 strike, uint256 width, uint256 skew, uint256 vega, uint256 ts)
        internal
        returns (BinNotionals memory ns)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "binNotionals(uint256,uint256,uint256,uint256,uint256)", strike, width, skew, vega, ts
            )
        );
        require(ok, "binNotionals reverted");
        (uint256 n0, uint256 n1, uint256 n2, uint256 n3) = abi.decode(r, (uint256, uint256, uint256, uint256));
        ns = BinNotionals({n0: n0, n1: n1, n2: n2, n3: n3});
    }

    function _binToLegs(
        uint256 orMin,
        uint256 bound,
        uint256 strike,
        uint256 width,
        uint256 skew,
        uint256 vega,
        uint256 ts
    ) internal returns (BinToLegs memory book) {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "binToLegs(uint256,uint256,uint256,uint256,uint256,uint256,uint256)",
                orMin,
                bound,
                strike,
                width,
                skew,
                vega,
                ts
            )
        );
        require(ok, "binToLegs reverted");
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3, uint256 base) =
            abi.decode(r, (uint256, uint256, uint256, uint256, uint256));
        book = BinToLegs({w0: w0, w1: w1, w2: w2, w3: w3, base: base});
    }

    function _roundBound(uint256 b, uint256 n, uint256 nMax) internal pure returns (uint256) {
        return (b * n + nMax / 2) / nMax;
    }

    function _max4(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256) {
        uint256 m = a > b ? a : b;
        m = m > c ? m : c;
        return m > d ? m : d;
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

    // binToLegs: weights + base — Spec.hs #28.3 uses wide fixture (voWide), not symmetric
    function test_binToLegs_wide_matchesNotionalsQuantize() public {
        uint256 ts = uint256(uint24(SYM_TS));
        BinNotionals memory ns = _binNotionals(SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, ts);
        uint256 nMax = _max4(ns.n0, ns.n1, ns.n2, ns.n3);
        BinToLegs memory book =
            _binToLegs(OR_MIN_DEFAULT, BOUND_PANOPTIC, SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, ts);
        assertEq(book.w0, _roundBound(BOUND_PANOPTIC, ns.n0, nMax), "w0");
        assertEq(book.w1, _roundBound(BOUND_PANOPTIC, ns.n1, nMax), "w1");
        assertEq(book.w2, _roundBound(BOUND_PANOPTIC, ns.n2, nMax), "w2");
        assertEq(book.w3, _roundBound(BOUND_PANOPTIC, ns.n3, nMax), "w3");
        assertEq(book.base, nMax / BOUND_PANOPTIC, "base");
        uint256 maxW = book.w0;
        if (book.w1 > maxW) maxW = book.w1;
        if (book.w2 > maxW) maxW = book.w2;
        if (book.w3 > maxW) maxW = book.w3;
        assertEq(maxW, 127, "max or = 127");
        assertGe(book.w0, OR_MIN_DEFAULT, "w0 >= orMin");
        assertGe(book.w1, OR_MIN_DEFAULT, "w1 >= orMin");
        assertGe(book.w2, OR_MIN_DEFAULT, "w2 >= orMin");
        assertGe(book.w3, OR_MIN_DEFAULT, "w3 >= orMin");
    }

    // binToLegs: orMin above max weight reverts (Haskell any (< orMin))
    function test_binToLegs_orMinAboveMaxWeight_reverts() public {
        uint256 ts = uint256(uint24(SYM_TS));
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "binToLegs(uint256,uint256,uint256,uint256,uint256,uint256,uint256)",
                BOUND_PANOPTIC + 1,
                BOUND_PANOPTIC,
                SYM_STRIKE,
                SYM_WIDTH,
                SYM_SKEW,
                SYM_VEGA,
                ts
            )
        );
        assertFalse(ok, "orMin > bound must revert");
    }
}
