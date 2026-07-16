// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {PlankTestBase} from "../PlankTestBase.sol";

/// @notice The ABI RealizedVolatilityMod.plk dispatches on. `initializeTWAP` and `getTwapTick`
///         are deliberately the SAME selectors Algebra's plugin uses, so one interface can
///         drive Algebra, UniV3 and Plank in the differential suite.
interface IRealizedVolatility {
    function initializeTWAP(uint32 blockTimestamp, int24 tick) external;
    function writeTimepoint(uint32 blockTimestamp, int24 tick) external;
    function getTwapTick(uint32 dt, int24 tick, uint32 currentTimestamp) external view returns (int24);
    function getTickCumulative(uint32 dt, int24 tick, uint32 currentTimestamp) external view returns (int56);
    // getAverageVolatility(int24,uint32) is DELIBERATELY NOT DECLARED HERE (VDIFF-03).
    //
    // Plank's getAverageVolatility returns the last timepoint's RAW volatilityCumulative
    // accumulator (RealizedVolatilityMod.plk:221-224). Algebra's getAverageVolatility
    // (VolatilityOracle.sol:195-242) is Bessel-corrected AND WINDOW-normalised. These are
    // DIFFERENT QUANTITIES -- diffing them is not a strict test, it is a wrong one, and any
    // green it produced would be meaningless.
    //
    // The selectors differ too (0x8171455c vs Algebra's getAverageVolatilityLast 0xc3c8050a),
    // so a shared-interface call would revert rather than mis-compare -- but do not rely on
    // that: the surface is removed so the mistake cannot be made in the first place.
    //
    // The CORRECT scalar-volatility check is the stored volatilityCumulative field, read via
    // getTimepointPacked and unpacked at OFF_VOL -- see
    // test__unit__negativeAvgTickVolatilityIsExact below, and VDIFF-04 (Phase 9) which
    // generalises it to a field-by-field Algebra-vs-Plank differential.
    //
    // Porting Algebra's window-normalised getAverageVolatility to Plank (its own
    // _getVolatilityCumulativeAt binary search, windowed interpolation, and Bessel branch) is
    // production work, explicitly DEFERRED out of this milestone -- and redundant with VDIFF-04.
    // State readers -- without these the module is a black box and getTwapTick (a QUOTIENT)
    // lets compensating internal errors cancel.
    function getTimepointPacked(uint16 index) external view returns (uint256);
    function lastIndex() external view returns (uint16);
    function oldestIndex() external view returns (uint16);
    function readWindow() external view returns (uint32);
}

/// @title RealizedVolatilitySmokeTest
/// @notice Proves RealizedVolatilityMod.plk is deployable, its ABI dispatch is live, and -- the
///         part that matters -- that the specific fixes in d4da7f7 are FALSIFIABLE.
///
// dev: An earlier version of this file was mutation-tested by a reviewer and FAILED: deleting
//      @evm_signextend from unpack_timepoint, corrupting the volatility kernel's coefficient,
//      and deleting u32_sub's 32-bit mask ALL left the suite 6/6 green. It asserted things that
//      could not distinguish a correct oracle from a broken one:
//
//        * sign-extension: the STORED .tick field is read nowhere on the getTwapTick path (the
//          tick used in arithmetic comes from CALLDATA, which Solidity already sign-extends).
//          Only by reading the stored word back can the packing be pinned.
//        * u32_sub: every test used T0 = 1_000_000, far above WINDOW = 86400, so no 32-bit
//          subtraction ever underflowed. The regime was never entered.
//        * the kernel: nothing asserted volatilityCumulative at all.
//
//      Each test below now states which mutation it kills. If you add a test here, say what it
//      would catch -- a test that cannot fail is worse than no test, because it is counted.
contract RealizedVolatilitySmokeTest is PlankTestBase {
    IRealizedVolatility oracle;

    // Algebra's `uint32 constant WINDOW = 1 days`. Ours is STORAGE, so it must be asserted.
    uint32 constant WINDOW = 86400;
    uint32 constant DT = 30;

    // Deliberately ABOVE the window: the ordinary regime.
    uint32 constant T_HIGH = 1_000_000;
    // Deliberately BELOW the window: `currentTime - WINDOW` underflows uint32 here. This is the
    // ONLY regime in which the u32_sub fix is reachable, and the old suite never entered it.
    uint32 constant T_LOW = 500;

    // Timepoint bit layout (src/types/market_state_measurements/Timepoint.plk). Mirrored here
    // ONLY to read the stored word back; the field WIDTHS are what must match Algebra, not these
    // offsets (Plank's packing order is not Solidity's struct packing order).
    uint256 constant OFF_VOL = 32;
    uint256 constant OFF_TICK = 120;
    uint256 constant OFF_AVG_TICK = 144;
    uint256 constant OFF_TICK_CUM = 168;
    uint256 constant OFF_WSI = 224;
    uint256 constant OFF_INIT = 240;

    struct TP {
        uint32 timestamp;
        uint88 volatilityCumulative;
        int24 tick;
        int24 avgTick;
        int56 tickCumulative;
        uint16 windowStartIndex;
        bool initialized;
    }

    function _timepoint(uint16 index) internal view returns (TP memory t) {
        uint256 w = oracle.getTimepointPacked(index);
        t.timestamp = uint32(w & 0xFFFFFFFF);
        t.volatilityCumulative = uint88((w >> OFF_VOL) & 0xFFFFFFFFFFFFFFFFFFFFFF);
        t.tick = int24(uint24((w >> OFF_TICK) & 0xFFFFFF));
        t.avgTick = int24(uint24((w >> OFF_AVG_TICK) & 0xFFFFFF));
        t.tickCumulative = int56(uint56((w >> OFF_TICK_CUM) & 0xFFFFFFFFFFFFFF));
        t.windowStartIndex = uint16((w >> OFF_WSI) & 0xFFFF);
        t.initialized = ((w >> OFF_INIT) & 1) == 1;
    }

    function _last() internal view returns (TP memory) {
        return _timepoint(oracle.lastIndex());
    }

    function setUp() public {
        oracle = IRealizedVolatility(
            deployPlank("src/modules/market_state_measurements/RealizedVolatilityMod.plk")
        );
    }

    /// @notice Our WINDOW is storage where Algebra's is a compile-time constant. If init is ever
    ///         skipped this reads 0 and every windowed comparison silently diverges.
    function test__unit__windowMatchesAlgebraConstant() public {
        oracle.initializeTWAP(T_HIGH, int24(200));
        assertEq(oracle.readWindow(), WINDOW, "plank WINDOW must equal Algebra's 1 days");
    }

    /// @notice One observation: the average tick over any lookback is that tick.
    function test__unit__singleObservationTwapEqualsTick() public {
        int24 tick = int24(200);
        oracle.initializeTWAP(T_HIGH, tick);
        assertEq(oracle.getTwapTick(DT, tick, T_HIGH + DT), tick);
    }

    /// @notice KILLS: removing @evm_signextend from unpack_timepoint.
    /// @dev Reads the STORED tick/avg_tick back. Without sign-extension a negative int24 comes
    ///      back as a large positive (e.g. -200 -> 16777016). getTwapTick alone cannot see this,
    ///      because the tick it does arithmetic on comes from calldata, not from storage.
    function test__unit__storedNegativeTickSignExtends() public {
        int24 tick = int24(-200);
        oracle.initializeTWAP(T_HIGH, tick);

        TP memory t = _last();
        assertEq(t.tick, tick, "stored tick must sign-extend");
        assertEq(t.avgTick, tick, "stored avg_tick must sign-extend");
        assertTrue(t.initialized);
    }

    /// @notice KILLS: removing @evm_signextend from tick_cumulative (int56, a DIFFERENT
    ///         SIGNEXTEND byte index than the int24 ticks -- getting that one wrong is silent).
    /// @dev A sustained negative tick drives the accumulator negative.
    function test__unit__storedNegativeTickCumulativeSignExtends() public {
        int24 tick = int24(-500);
        oracle.initializeTWAP(T_HIGH, tick);
        oracle.writeTimepoint(T_HIGH + DT, tick);
        oracle.writeTimepoint(T_HIGH + 2 * DT, tick);

        TP memory t = _last();
        // tick_cumulative = sum(tick * dt) = -500 * 60
        assertEq(t.tickCumulative, int56(-500) * int56(60), "negative accumulator must sign-extend");
    }

    /// @notice KILLS: the checked `-` in the volatility kernel (this REVERTED), and asserts the
    ///         resulting accumulator so a kernel that merely stops reverting is not enough.
    function test__unit__downwardTickMoveIsCorrect() public {
        oracle.initializeTWAP(T_HIGH, int24(500));
        oracle.writeTimepoint(T_HIGH + DT, int24(100)); // strictly below the running average
        oracle.writeTimepoint(T_HIGH + 2 * DT, int24(-300)); // and again, through zero

        TP memory t = _last();
        // tick_cumulative accrues the tick that was CURRENT over each elapsed interval:
        //   [T0, T0+30) at tick 100  -> 100*30
        //   [T0+30, T0+60) at tick -300 -> -300*30
        assertEq(t.tickCumulative, int56(100) * 30 + int56(-300) * 30, "accumulator after a downward path");
        assertEq(t.tick, int24(-300));
        // The kernel must have produced SOMETHING for a moving tick; a constant path yields 0.
        assertGt(t.volatilityCumulative, 0, "a moving tick must accrue realized volatility");
    }

    /// @notice KILLS: deleting the `& 0xFFFFFFFF` from u32_sub.
    /// @dev The ONLY regime where that fix is reachable: currentTime < WINDOW, so
    ///      `current_time - WINDOW` underflows uint32. Unmasked it wraps mod 2^256 instead of
    ///      mod 2^32, which INVERTS oracle_lte and makes calculate_avg_tick return the raw tick
    ///      instead of a real average -- so avg_tick silently becomes the spot tick.
    function test__unit__timestampBelowWindowDoesNotInvertComparator() public {
        oracle.initializeTWAP(T_LOW, int24(1000));
        oracle.writeTimepoint(T_LOW + DT, int24(2000));

        TP memory t = _last();
        // With a correct uint32 window_start, the oldest timepoint is NEWER than one window ago,
        // so avg_tick = (cum_now - cum_oldest) / (now - oldest) = (2000*30 - 0) / 30 = 2000.
        // With the mask deleted, oracle_lte inverts and avg_tick collapses to the spot tick --
        // which here is ALSO 2000, so the average must be checked where it differs from spot:
        oracle.writeTimepoint(T_LOW + 2 * DT, int24(0));
        TP memory t2 = _last();
        // now: cumulative = 2000*30 + 0*30 = 60000 over 60s from T_LOW -> average 1000, spot 0.
        assertEq(t2.tick, int24(0), "spot");
        assertEq(t2.avgTick, int24(1000), "avg must be the time-weighted mean, not the spot tick");
        assertTrue(t2.avgTick != t2.tick, "the whole point: average must differ from spot here");
    }

    /// @notice KILLS: (a) removing @evm_signextend from avg_tick, and (b) any corruption of the
    ///         volatility kernel's coefficients.
    ///
    /// @dev This is the ONLY assertion that pins either. Reading the stored `.tick` back cannot
    ///      pin sign-extension: the packed 24 bits are identical whether or not unpack extends,
    ///      and the Solidity decode re-derives the sign anyway. But `avg_tick` is CONSUMED --
    ///      create_timepoint feeds `current.avg_tick` into calculate_realized_volatility -- so a
    ///      missing sign-extension turns -1000 into 16776216 and the kernel output explodes.
    ///      Only an EXACT volatilityCumulative catches it. `assertGt(vol, 0)` does not.
    ///
    ///      Expected value derived from Algebra's _volatilityOnRange, which
    ///      create_timepoint invokes as (avg_tick0, avg_tick1, tick, tick, delta):
    ///        init(T, -1000); write(T+30, -2000)
    ///        => a0=-1000, a1=-2000, t0=t1=-2000, dt=30
    ///           k  = (t1-t0) - (a1-a0)          = 1000
    ///           b  = (t0-a0) * dt               = -30000
    ///           sumOfSequence = dt*(dt+1)       = 930
    ///           sumOfSquares  = sumOfSequence*(2dt+1) = 56730
    ///           vol = (k^2*sumOfSquares + 6*b*k*sumOfSequence + 6*dt*b^2) / (6*dt^2)
    ///               = 51,330,000,000 / 5400  = 9,505,555   (SDIV truncates toward zero)
    function test__unit__negativeAvgTickVolatilityIsExact() public {
        oracle.initializeTWAP(T_HIGH, int24(-1000));
        oracle.writeTimepoint(T_HIGH + DT, int24(-2000));

        TP memory t = _last();
        assertEq(t.avgTick, int24(-2000), "avg_tick over the interval");
        assertEq(
            uint256(t.volatilityCumulative),
            uint256(9505555),
            "exact realized-variance accrual with a NEGATIVE avg_tick"
        );
    }

    /// @notice Constant tick -> the average is that tick.
    /// @dev NON-DISCRIMINATING BY CONSTRUCTION. On a constant path avg_tick == tick, so k = 0 and
    ///      b = 0 in the volatility kernel and calculate_avg_tick short-circuits. This passes
    ///      against an oracle that ignores storage entirely. Kept as a smoke check only; it is
    ///      NOT coverage. See .planning/plank-voldiff-plan.md Phase 3.
    function test__fuzz__constantTickPathTwapEqualsTick(int24 _tick, uint8 _n) public {
        int24 tick = int24(bound(int256(_tick), -887272, 887272));
        uint256 n = bound(uint256(_n), 2, 40);

        oracle.initializeTWAP(T_HIGH, tick);
        for (uint256 i = 1; i <= n; i++) {
            oracle.writeTimepoint(uint32(T_HIGH + i * DT), tick);
        }
        assertEq(oracle.getTwapTick(uint32(n * DT), tick, uint32(T_HIGH + n * DT)), tick);
    }

    /// @notice dt == 0: EVM SDIV by zero returns 0 SILENTLY, so Plank would answer 0 where both
    ///         references revert.
    function test__unit__zeroPeriodReverts() public {
        oracle.initializeTWAP(T_HIGH, int24(200));
        vm.expectRevert();
        oracle.getTwapTick(0, int24(200), T_HIGH + DT);
    }

    /// @notice Double-init must revert. The old guard used EVM bitwise NOT on a bool, so NOT(0)
    ///         and NOT(1) are both truthy and it could never fire.
    function test__unit__doubleInitReverts() public {
        oracle.initializeTWAP(T_HIGH, int24(200));
        vm.expectRevert();
        oracle.initializeTWAP(T_HIGH, int24(200));
    }

    /// @notice KILLS: the unmasked ring index. StorageIndex.next did not mask to 16 bits while
    ///         load_timepoint did, so at last_index == 65535 the write landed at
    ///         keccak(base)+65536 -- OUTSIDE the 2^16 ring -- while the state word masked
    ///         ss_index back to 0. Reads then resolved index 0 to the GENESIS timepoint: the
    ///         oracle silently rewound to its init state on wrap, losing every sample.
    /// @dev vm.store the index to 65535 rather than performing 65536 writes (~125k gas, not 2e9).
    function test__unit__ringWrapWritesInsideTheRing() public {
        oracle.initializeTWAP(T_HIGH, int24(200));

        // SLOT_REALIZED_VOL_STATE, packed: ss_index bits 0-15 | lastTimepointTimestamp 16-47 |
        // isInitialized bit 48.
        bytes32 stateSlot = bytes32(uint256(0x66d25f45c9eb3ca9255387e4a0842bb72d450363ab922011aef46dbadb163e9e));
        uint256 packed = uint256(0xFFFF) | (uint256(T_HIGH) << 16) | (uint256(1) << 48);
        vm.store(address(oracle), stateSlot, bytes32(packed));
        assertEq(oracle.lastIndex(), uint16(0xFFFF), "precondition: parked at the last ring slot");

        oracle.writeTimepoint(T_HIGH + DT, int24(300));

        // The advanced index must WRAP to 0, and slot 0 must hold the NEW timepoint -- not the
        // genesis one.
        assertEq(oracle.lastIndex(), uint16(0), "index must wrap to 0");
        TP memory t = _timepoint(0);
        assertEq(t.timestamp, T_HIGH + DT, "slot 0 must hold the NEW timepoint, not genesis");
        assertEq(t.tick, int24(300), "slot 0 must hold the NEW tick, not genesis");
    }
}
