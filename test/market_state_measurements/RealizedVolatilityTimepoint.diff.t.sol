// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VolatilityOraclePluginImplementation} from
    "@cryptoalgebra/volatility-oracle-plugin/VolatilityOraclePluginImplementation.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {MarketStatisticsAlgebraRef} from "../MarketStatisticsTest.t.sol";
import {TimepointDecoder, PlankTimepoint} from "./TimepointDecoder.sol";

/// @notice Plank's oracle module ABI. Deliberately narrower than the Phase 0-1 driver's copy: this
///         file never queries getTwapTick/getTickCumulative -- those are Phase 0-1's surface.
interface IPlankOracle {
    function initializeTWAP(uint32 blockTimestamp, int24 tick) external;
    function writeTimepoint(uint32 blockTimestamp, int24 tick) external;
    function getTimepointPacked(uint16 index) external view returns (uint256);
    function lastIndex() external view returns (uint16);
    function readWindow() external view returns (uint32);
}

/// @title RealizedVolatilityTimepointDiffTest
/// @notice VDIFF-04: the full-timepoint VARIANCE differential. One (timestamp, tick) sequence is
///         applied to Algebra and Plank, and after EVERY write both must agree EXACTLY --
///         tolerance ZERO -- on the STORED volatilityCumulative, averageTick and windowStartIndex
///         at lastIndex.
///
// ===========================================================================================
// WHY THIS FILE EXISTS, given the kernel is already fuzzed (VDIFF-02 / 09-01).
//
// The kernel fuzz proves the variance FORMULA: calculate_realized_volatility agrees with
// Algebra's _volatilityOnRange across a 5-D domain at tolerance 0, 1024 runs, zero
// counterexamples. It says NOTHING about whether that formula is CALLED WITH THE RIGHT
// ARGUMENTS, ACCUMULATED correctly, or PACKED correctly on a real write path. This file proves
// the variance STATE. Consequence worth knowing: because the kernel is proven bit-exact, any
// divergence THIS test finds is in the WRITE PATH (packing / accumulation / windowing), not in
// the kernel -- that is a genuinely narrowed diagnosis, not a vague red.
//
// WHY ALGEBRA-vs-PLANK ONLY -- the UniV3 reference is deliberately NOT driven.
//
// UniV3's Oracle has NO volatility accumulator. It has nothing to contribute to any of the three
// fields asserted here. Driving it would cost ~11.5M gas per run (its Oracle.grow(512) prepay)
// to produce data that is never compared, and would impose a bogus 512 write-cap on the corpus
// (UniV3's ring is mod cardinality; Algebra's and Plank's are mod 65536). This is exactly where
// the variance differential parts company with the merged Phase 0-1 three-way tick-average diff:
// that one has three participants because tickCumulative genuinely exists in all three.
// RealizedVolatility.diff.t.sol's _writeAll drives all three, so it is NOT reused here.
//
// WHY THE OLDEST-INDEX IS NOT ASSERTED.
//
// It only becomes non-zero once the ring has been overwritten -- after 65,536 writes. Any Phase
// 9/10 corpus leaves it at 0 on BOTH sides, so asserting it would pass NO MATTER WHAT the wrap
// logic does. That is a vacuous assertion: it would add a green tick and zero information. The
// ring-wrap oldest-index is covered Plank-side in Phase 11 via vm.store (Algebra's library ring
// cannot be cheaply forced to a near-wrap state, so it is not a differential at all).
//
// WHY tickCumulative / blockTimestamp / initialized ARE NOT HERE.
//
// Already diffed three-way by the merged Phase 0-1 test. This file adds the VARIANCE fields --
// the three the Phase 0-1 diff never touches.
//
// WHY delta >= 1 IS LOAD-BEARING, not incidental hygiene.
//
// Plank deliberately omits Algebra's withHeuristic binary-search first guess
// (RealizedVolatilityLib.plk:95-98), claiming result-invariance. That claim holds ONLY given
// strictly-increasing DISTINCT timestamps. The windowStartIndex assertion below is what TESTS
// that equivalence -- it does not assume it. A corpus containing delta = 0 would be testing a
// different claim entirely, so every delta here is constructed >= 1 by bound(), never filtered.
//
// WHY TOLERANCE 0 IS GUARANTEED -- AND REGIME-CONDITIONAL.
//
// Guaranteed within int24 ticks x uint32 timestamps: max |tickCumulative| is about 3.8e15,
// comfortably inside int56's 3.6e16, so neither side wraps. The uint88 accumulation agrees
// because Algebra truncates-then-adds while Plank adds-then-masks, and
// (a + x) mod 2^88 == (a + (x mod 2^88)) mod 2^88 -- identical. It is NOT claimed in Algebra's
// DELIBERATE int56-overflow regime: Plank's full-width in-flight accumulator does not replicate
// that wrap. The int24/uint32 type bounds keep this corpus out of that regime. Tolerance 0 is
// therefore correct and must not be softened: a divergence here is a real find, not noise.
//
// WHAT IS DELIBERATELY NOT HERE.
//
// A span exceeding twice the WINDOW, and the sub-WINDOW u32_sub corpus, are PHASE 10
// (VDIFF-05/06). This driver need only be NON-VACUOUS. It does NOT claim to execute
// calculate_avg_tick's WINDOW-interpolation branch, and no assertion here should be read as
// covering it.
//
// WHAT THIS KILLS -- PENDING OBSERVATION (09-02 Task 3 fills this in with the OBSERVED results).
//
// This section deliberately does NOT yet claim any kill. The mutants below are the ones Task 3
// will APPLY and RUN; until that has actually happened and the failure output has been recorded,
// asserting a kill here would be the precise failure mode this whole phase exists to prevent --
// a green/red claim written from reasoning rather than from observation.
//
//   * MUTANT A -- timepoint PACKING corruption. Timepoint.plk:32, OFF_AVG_TICK 144 -> 145,
//     shifting the packed avg_tick field off its layout. Plank's own pack/unpack stay
//     self-consistent (both read the constant), which is the point: only a test that reads the
//     STORED WORD at the real offset and diffs it against Algebra can see this. getTwapTick
//     cannot.
//   * MUTANT B -- accumulation STOPPED. Timepoint.plk:115, the running sum
//     add(current vol, delta vol) reduced to the newest delta alone, i.e. Algebra's `+=` turned
//     into `=`. INVISIBLE on a single write; it can only diverge from the SECOND write onward --
//     which is why this driver asserts after EVERY write against a >= 2-write sequence rather
//     than once at the end.
// ===========================================================================================
contract RealizedVolatilityTimepointDiffTest is PlankTestBase {
    MarketStatisticsAlgebraRef alg;
    IPlankOracle plk;

    uint32 constant WINDOW = 86400;
    int24 constant TICK_MIN = -887272;
    int24 constant TICK_MAX = 887272;

    function setUp() public {
        alg = new MarketStatisticsAlgebraRef(new VolatilityOraclePluginImplementation());
        plk = IPlankOracle(deployPlank("src/modules/market_state_measurements/RealizedVolatilityMod.plk"));
    }

    // ---- The two-way driver ----------------------------------------------------------------
    // The assertion lives INSIDE the driver, so "after EVERY write" cannot be forgotten at a
    // call site. A driver that only checks at the end would let a divergence appear and then be
    // overwritten by a later write.

    function _initBoth(uint32 t, int24 tick) internal {
        alg.initializeTWAP(t, tick);
        plk.initializeTWAP(t, tick);
        _assertVarianceFieldsMatch();
    }

    function _writeBoth(uint32 t, int24 tick) internal {
        alg.writeTimepoint(t, tick);
        plk.writeTimepoint(t, tick);
        _assertVarianceFieldsMatch();
    }

    // ---- THE assertion: exactly three fields, tolerance 0 ------------------------------------

    /// @dev Algebra's getTimepoint returns, IN ORDER:
    ///      (initialized, blockTimestamp, tickCumulative, volatilityCumulative, tick, averageTick,
    ///      windowStartIndex). The destructuring below is positional -- get it wrong and you diff
    ///      tick against avgTick and the test still "passes" on a constant path.
    function _assertVarianceFieldsMatch() internal {
        uint16 li = alg.lastIndex();
        assertEq(li, plk.lastIndex(), "lastIndex: algebra vs plank"); // else we compare different slots

        (,,, uint88 volA,, int24 avgA, uint16 wsiA) = alg.getTimepoint(li);
        PlankTimepoint memory p = TimepointDecoder.decode(plk.getTimepointPacked(li));

        assertEq(
            uint256(volA), uint256(p.volatilityCumulative), "volatilityCumulative: algebra vs plank, tolerance 0"
        );
        assertEq(avgA, p.avgTick, "averageTick: algebra vs plank, tolerance 0");
        assertEq(wsiA, p.windowStartIndex, "windowStartIndex: algebra vs plank, tolerance 0");
    }

    // ---- Corpus construction ----------------------------------------------------------------
    // Deterministic per-run derivation: the corpus is CONSTRUCTED, never filtered by the assume
    // cheatcode. Every fuzz run therefore executes a live assertion instead of being silently
    // discarded, and a rejected-heavy fuzz cannot quietly reduce the effective run count to near
    // zero.

    function _tickAt(uint256 seed, uint256 i) internal pure returns (int24) {
        return int24(bound(int256(uint256(keccak256(abi.encode(seed, i, "tick")))), TICK_MIN, TICK_MAX));
    }

    function _deltaAt(uint256 seed, uint256 i) internal pure returns (uint32) {
        return uint32(bound(uint256(keccak256(abi.encode(seed, i, "dt"))), 1, 3600)); // >= 1, ALWAYS
    }

    // ---- Test A: the fixed, hand-checkable non-vacuity anchor --------------------------------

    /// @notice A fixed sequence with a strict FALL through zero, a strict RISE, and a fall again.
    ///
    /// @dev volA > 0 is GUARANTEED here, not hoped for -- the derivation:
    ///      init sets averageTick = tick = 100. At t+30 with tick = -400: delta = 30, and
    ///      b = (tick0 - avgTick0) * dt = (-400 - 100) * 30 = -15000, which is NON-ZERO. The
    ///      oldest timepoint is newer than one WINDOW ago, so avgTick resolves to
    ///      (-400*30 - 0)/30 = -400, giving k = (t1-t0) - (a1-a0) = 0 - (-400 - 100) = 500.
    ///      With sumOfSequence = dt*(dt+1) = 930 and sumOfSquares = 930*61 = 56730:
    ///        num = 500^2*56730 + 6*(-15000)*500*930 + 6*30*(-15000)^2
    ///            = 14,182,500,000 - 41,850,000,000 + 40,500,000,000 = 12,832,500,000
    ///        den = 6*dt^2 = 5400  ->  vol = 2,376,388 (SDIV truncates toward zero).
    ///      That value was CHECKED empirically during 09-02 before being relaxed to the > 0 form
    ///      asserted here: the exact-value anchor duty belongs to
    ///      RealizedVolatilityKernel.probe.t.sol (anchor 819430) and to the 09-01 fuzz. THIS
    ///      file's job is the DIFFERENTIAL -- the assertion that matters already ran inside every
    ///      _writeBoth above. This last check only certifies the corpus is not a constant path.
    function test__unit__fixedSequenceVarianceFieldsMatch() public {
        uint32 t = 1_000_000;
        _initBoth(t, int24(100));
        _writeBoth(t + 30, int24(-400)); // a strict FALL through zero
        _writeBoth(t + 60, int24(250)); // a strict RISE
        _writeBoth(t + 90, int24(-50)); // and a fall again

        (,,, uint88 volA,,,) = alg.getTimepoint(alg.lastIndex());
        assertGt(volA, 0, "corpus must be non-vacuous: a moving tick must accrue realized volatility");
    }

    // ---- Test B: the fuzzed, CONSTRUCTED corpus ---------------------------------------------

    /// @notice A random tick path driven identically into Algebra and Plank, asserting all three
    ///         variance fields after every single write.
    function test__fuzz__randomPathVarianceFieldsMatch(uint256 seed, uint8 nRaw) public {
        uint256 n = bound(uint256(nRaw), 2, 60);
        uint32 t0 = uint32(bound(uint256(keccak256(abi.encode(seed, "t0"))), 1_000_000, 3_000_000));

        int24 lastTick = _tickAt(seed, 0);
        _initBoth(t0, lastTick);

        // Fixed non-vacuity prefix: guarantees a strict move off the init tick before the random
        // walk, so the corpus can NEVER degenerate to a constant path. On a constant path k = 0
        // AND b = 0, both sides return 0, and every assertEq degrades to assertEq(0, 0) -- green
        // against an oracle that always returns 0.
        uint32 t = t0 + 30;
        lastTick = (lastTick >= 0) ? lastTick - 500 : lastTick + 500;
        _writeBoth(t, lastTick);

        for (uint256 i = 1; i < n; i++) {
            t += _deltaAt(seed, i); // STRICTLY INCREASING, DISTINCT
            int24 next = _tickAt(seed, i);
            // REPAIR, never reject: consecutive equal ticks would flatten the path.
            if (next == lastTick) next = (next == TICK_MAX) ? next - 1 : next + 1;
            lastTick = next;
            _writeBoth(t, lastTick); // asserts all three fields, every write
        }
    }
}
