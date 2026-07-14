// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {VolatilityOraclePluginImplementation} from "@cryptoalgebra/volatility-oracle-plugin/VolatilityOraclePluginImplementation.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {MarketStatisticsAlgebraRef, MarketStatisticsUniV3Ref} from "../MarketStatisticsTest.t.sol";

/// @notice The Plank oracle module's ABI. initializeTWAP / getTwapTick are the SAME selectors
///         Algebra's plugin uses, so this one interface drives all three implementations.
interface IPlankOracle {
    function initializeTWAP(uint32 blockTimestamp, int24 tick) external;
    function writeTimepoint(uint32 blockTimestamp, int24 tick) external;
    function getTwapTick(uint32 dt, int24 tick, uint32 currentTimestamp) external view returns (int24);
    function getTickCumulative(uint32 dt, int24 tick, uint32 currentTimestamp) external view returns (int56);
    function getTimepointPacked(uint16 index) external view returns (uint256);
    function lastIndex() external view returns (uint16);
    function oldestIndex() external view returns (uint16);
    function readWindow() external view returns (uint32);
}

/// @title RealizedVolatilityDiffTest
/// @notice Phase 0-1 of the differential plan (.planning/plank-voldiff-plan.md).
///
///         Phase 0: ONE driver applies the SAME (timestamp, tick) sequence to Algebra, UniV3
///         and Plank. If they were driven by separate code paths a harness bug would surface as
///         a silent divergence blamed on the port.
///
///         Phase 1: after every point, the three implementations must agree EXACTLY, tolerance
///         ZERO, on:
///           - getTickCumulative(dt) -- the primitive; isolates the ring search + interpolation
///           - getTwapTick(dt)       -- the quotient, incl. the floor-toward-(-inf) correction
///           - the stored (blockTimestamp, tickCumulative, initialized) at lastIndex
///         getTwapTick alone is insufficient: it is a QUOTIENT, so a truncated accumulator and a
///         wrong oldest-index cancel and a TWAP-only assertion passes. Assert the accumulator AND
///         the quotient AND the stored state.
///
///         Regime: strictly NO-WRAP. Writes are bounded < CARDINALITY_TARGET (512) so UniV3's
///         ring (mod cardinality) tracks Algebra/Plank (mod 65536). Wrap and the sub-WINDOW
///         u32_sub regime are Phases 3b/4, not here.
contract RealizedVolatilityDiffTest is PlankTestBase {
    MarketStatisticsAlgebraRef alg;
    MarketStatisticsUniV3Ref uni;
    IPlankOracle plk;

    uint32 constant WINDOW = 86400;
    // < 512 keeps UniV3 in its no-wrap regime; also well under 65536.
    uint256 constant MAX_WRITES = 200;
    int24 constant TICK_MIN = -887272;
    int24 constant TICK_MAX = 887272;

    // Plank Timepoint bit offsets (src/types/market_state_measurements/Timepoint.plk).
    uint256 constant OFF_TICK_CUM = 168;
    uint256 constant OFF_INIT = 240;

    function setUp() public {
        alg = new MarketStatisticsAlgebraRef(new VolatilityOraclePluginImplementation());
        uni = new MarketStatisticsUniV3Ref();
        plk = IPlankOracle(deployPlank("src/modules/market_state_measurements/RealizedVolatilityMod.plk"));
    }

    // ---- Phase 0: the shared driver -------------------------------------------------------

    function _initAll(uint32 t, int24 tick) internal {
        alg.initializeTWAP(t, tick);
        uni.initializeTWAP(t, tick);
        plk.initializeTWAP(t, tick);
    }

    function _writeAll(uint32 t, int24 tick) internal {
        alg.writeTimepoint(t, tick);
        uni.writeTimepoint(t, tick);
        plk.writeTimepoint(t, tick);
    }

    // Deterministic per-run derivation, so the corpus is CONSTRUCTED (not vm.assume-filtered).
    function _tickAt(uint256 seed, uint256 i) internal pure returns (int24) {
        return int24(bound(int256(uint256(keccak256(abi.encode(seed, i, "tick")))), TICK_MIN, TICK_MAX));
    }

    function _deltaAt(uint256 seed, uint256 i) internal pure returns (uint32) {
        return uint32(bound(uint256(keccak256(abi.encode(seed, i, "dt"))), 1, 3600));
    }

    // ---- Phase 1 assertions ----------------------------------------------------------------

    /// @dev The three quantities that MUST agree across all three implementations.
    function _assertThreeWayAt(uint32 dt, int24 tick, uint32 now_) internal {
        int56 cAlg = alg.getTickCumulative(dt, tick, now_);
        assertEq(cAlg, uni.getTickCumulative(dt, tick, now_), "tickCumulative: algebra vs univ3");
        assertEq(cAlg, plk.getTickCumulative(dt, tick, now_), "tickCumulative: algebra vs plank");

        int24 twAlg = alg.getTwapTick(dt, tick, now_);
        assertEq(twAlg, uni.getTwapTick(dt, tick, now_), "twap: algebra vs univ3");
        assertEq(twAlg, plk.getTwapTick(dt, tick, now_), "twap: algebra vs plank");
    }

    function _assertStoredStateMatches() internal {
        uint16 li = alg.lastIndex();
        assertEq(li, uni.lastIndex(), "lastIndex: algebra vs univ3");
        assertEq(li, plk.lastIndex(), "lastIndex: algebra vs plank");

        (, uint32 tsA, int56 cumA,,,,) = alg.getTimepoint(li);
        (uint32 tsU, int56 cumU, bool initU) = uni.getTimepoint(li);

        uint256 word = plk.getTimepointPacked(li);
        uint32 tsP = uint32(word & 0xFFFFFFFF);
        int56 cumP = int56(uint56((word >> OFF_TICK_CUM) & 0xFFFFFFFFFFFFFF));
        bool initP = ((word >> OFF_INIT) & 1) == 1;

        assertEq(tsA, tsU, "stored timestamp: algebra vs univ3");
        assertEq(tsA, tsP, "stored timestamp: algebra vs plank");
        assertEq(cumA, cumU, "stored tickCumulative: algebra vs univ3");
        assertEq(cumA, cumP, "stored tickCumulative: algebra vs plank");
        assertTrue(initU && initP, "stored initialized flag");
    }

    // ---- Phase 0 anchor: a fixed, hand-checkable sequence ----------------------------------

    /// @notice Non-fuzz anchor. A constant-tick warm-up then a step; the accumulator over a known
    ///         lookback is hand-computable, and all three must agree on it.
    function test__unit__phase1_fixedSequenceThreeWay() public {
        uint32 t = 1_000_000;
        _initAll(t, int24(100));
        _writeAll(t + 30, int24(100));
        _writeAll(t + 60, int24(-400)); // a downward move through zero
        _writeAll(t + 90, int24(250));

        uint32 now_ = t + 90;
        // whole recorded span, and a partial lookback
        _assertThreeWayAt(90, int24(250), now_);
        _assertThreeWayAt(45, int24(250), now_);
        _assertStoredStateMatches();
    }

    // ---- Phase 1: fuzzed, constructed corpus, no-wrap --------------------------------------

    /// @notice The core of the exercise: a random tick path driven identically into all three,
    ///         asserting exact agreement on the accumulator, the TWAP, and the stored state.
    function test__fuzz__phase1_randomPathThreeWay(uint256 seed, uint8 nRaw) public {
        uint256 n = bound(uint256(nRaw), 2, 60); // < MAX_WRITES, keeps 256-run fuzz tractable

        uint32 t0 = uint32(bound(uint256(keccak256(abi.encode(seed, "t0"))), 1_000_000, 3_000_000));
        int24 lastTick = _tickAt(seed, 0);

        _initAll(t0, lastTick);

        uint32 t = t0;
        for (uint256 i = 1; i < n; i++) {
            t += _deltaAt(seed, i);
            lastTick = _tickAt(seed, i);
            _writeAll(t, lastTick);
        }

        // Stored state after the full identical drive must match bit-for-bit.
        _assertStoredStateMatches();

        // Query the accumulator/TWAP at the last timestamp over a lookback WITHIN recorded
        // history (dt <= span), so the target is bracketed by stored points on all three and the
        // passed tick is irrelevant (no extrapolation past the last point).
        uint32 span = t - t0;
        if (span == 0) return; // n could be 2 with... no: delta >= 1, so span >= 1 for n >= 2
        uint32 dt = uint32(bound(uint256(keccak256(abi.encode(seed, "querydt"))), 1, span));
        _assertThreeWayAt(dt, lastTick, t);

        // Also pin the two boundaries explicitly.
        _assertThreeWayAt(1, lastTick, t); // newest interval
        _assertThreeWayAt(span, lastTick, t); // the whole window, back to genesis
    }
}
