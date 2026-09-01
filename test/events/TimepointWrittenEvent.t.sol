// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PlankTestBase} from "../PlankTestBase.sol";
import {Vm} from "forge-std/Vm.sol";

// ===========================================================================================
// EV-03: E3 TimepointWritten + E6 WindowChanged on RealizedVolatilityMod
// (.planning/events-subgraph-gams-SPEC.md D4/E3, D4/E6, D8).
//
//   E3 TimepointWritten(bytes32 indexed poolId, uint32 timestamp, int24 tick,
//                       uint88 volatilityCumulative, int24 averageTick, int56 tickCumulative)
//   E6 WindowChanged(bytes32 indexed poolId, uint32 window)
//
// poolId is the PERMANENT module-global sentinel bytes32(0) (spec D2): this module is
// module-keyed; the pool-keyed hook (task #16) is a different emitter.
//
// ORACLE DISCIPLINE (D8): the byte-exact anchor is the SEED event from initializeTWAP,
// whose fields are fully known (vol=0, avgTick=tick0, tickCumulative=0) -- solc encodes the
// expectation via vm.expectEmit + typed emit, with a NEGATIVE tick0 so sign extension is
// pinned by the reference compiler. The write path is then held to STATE<->LOG SUBSET
// EQUALITY (spec E3): every emitted field equals the canonical (unpacked, sign-extended)
// value of the corresponding stored Timepoint field, tolerance 0 -- and abi.decode's
// int24/int56 validity check makes a masked-not-signextended word REVERT the test.
//
// MUTANTS this file kills (spec EV battery):
//   - missing seed emit on initializeTWAP        -> test__unit__initializeEmitsSeedAndWindow
//   - masked-not-signextended tick/avgTick/cum   -> negative-tick seed expectEmit +
//                                                   abi.decode validation in _decodeE3
//   - emit on the same-block early-out           -> test__unit__sameBlockSecondWriteEmitsNothing
//   - emit-before-store / wrong-field emit       -> test__fuzz__writeLogMirrorsStoredTimepoint
//   - missing/wrong default-window E6            -> test__unit__initializeEmitsSeedAndWindow
// ===========================================================================================
interface IRVolMod {
    function initializeTWAP(uint32 blockTimestamp, int24 tick) external;
    function writeTimepoint(uint32 blockTimestamp, int24 tick) external;
    function getTimepointPacked(uint16 index) external view returns (uint256);
    function lastIndex() external view returns (uint16);
    function readWindow() external view returns (uint32);
}

contract TimepointWrittenEventTest is PlankTestBase {
    event TimepointWritten(
        bytes32 indexed poolId,
        uint32 timestamp,
        int24 tick,
        uint88 volatilityCumulative,
        int24 averageTick,
        int56 tickCumulative
    );
    event WindowChanged(bytes32 indexed poolId, uint32 window);

    /// @dev Restated from VolEventsLib.plk (cast keccak over the canonical signatures);
    ///      asserted against solc's own selectors so a drifting string is caught.
    bytes32 internal constant TOPIC0_TIMEPOINT_WRITTEN =
        0x44d3c76a584327df3a91e46e185e97959195c01202945078eebb23b19c161415;
    bytes32 internal constant TOPIC0_WINDOW_CHANGED =
        0x046630eacacfeb3f36a64fd8cb291b41c3e78bcd57f8733e12b9afeb69968b47;

    uint32 internal constant DEFAULT_WINDOW = 86400;

    IRVolMod internal mod;

    function setUp() public {
        mod = IRVolMod(deployPlank("src/modules/fee-volatility/RealizedVolatilityMod.plk"));
    }

    function test__unit__topicZeroConstantsMatchSolc() public pure {
        assertEq(TimepointWritten.selector, TOPIC0_TIMEPOINT_WRITTEN, "E3 topic0 == solc canonical");
        assertEq(WindowChanged.selector, TOPIC0_WINDOW_CHANGED, "E6 topic0 == solc canonical");
    }

    // The D8 byte-exact anchor: initializeTWAP emits E6 (default window) then the E3 seed,
    // with a NEGATIVE tick so the reference compiler pins sign extension end to end.
    function test__unit__initializeEmitsSeedAndWindow() public {
        uint32 t0 = 1_000_000;
        int24 tick0 = -8123; // negative on purpose: the sign-extension anchor

        vm.expectEmit(true, true, true, true, address(mod));
        emit WindowChanged(bytes32(0), DEFAULT_WINDOW);
        vm.expectEmit(true, true, true, true, address(mod));
        emit TimepointWritten(bytes32(0), t0, tick0, 0, tick0, 0);

        mod.initializeTWAP(t0, tick0);
        assertEq(mod.readWindow(), DEFAULT_WINDOW, "default window stored as emitted");
    }

    // ------------------------------------------------------------------ helpers

    /// @dev abi.decode is load-bearing: solc validates int24/int56 words and REVERTS on a
    ///      non-sign-extended (masked) encoding -- the highest-value mutant dies here.
    function _decodeE3(Vm.Log memory log)
        internal
        pure
        returns (uint32 ts, int24 tick, uint88 vol, int24 avgTick, int56 tickCum)
    {
        (ts, tick, vol, avgTick, tickCum) = abi.decode(log.data, (uint32, int24, uint88, int24, int56));
    }

    /// @dev The canonical (unpacked, sign-extended) view of the stored Timepoint word --
    ///      the Solidity restatement of unpack_timepoint. Timepoint.plk bit layout:
    ///      ts u32 at 0, vol u88 at 32, tick i24 at 120, avgTick i24 at 144, cum i56 at 168,
    ///      wsi u16 at 224, initialized at 240.
    function _storedAt(uint16 index)
        internal
        view
        returns (uint32 ts, int24 tick, uint88 vol, int24 avgTick, int56 tickCum)
    {
        uint256 w = mod.getTimepointPacked(index);
        ts = uint32(w);
        vol = uint88(w >> 32);
        tick = int24(uint24(w >> 120));
        avgTick = int24(uint24(w >> 144));
        tickCum = int56(uint56(w >> 168));
    }

    function _filterE3(Vm.Log[] memory logs) internal pure returns (Vm.Log[] memory out) {
        uint256 n;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == TOPIC0_TIMEPOINT_WRITTEN) n++;
        }
        out = new Vm.Log[](n);
        uint256 j;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == TOPIC0_TIMEPOINT_WRITTEN) out[j++] = logs[i];
        }
    }

    // ------------------------------------------------------------------ write path

    // State<->log subset equality on a deterministic corpus with negative ticks: after every
    // successful write, the single emitted E3 equals the canonical view of the word stored at
    // the advanced lastIndex. Tolerance 0.
    function test__unit__writeEmitsExactlyTheStoredTimepoint() public {
        mod.initializeTWAP(1_000_000, 100);

        int24[4] memory ticks = [int24(500), int24(-1200), int24(2000), int24(-8123)];
        uint32 t = 1_000_000;
        for (uint256 i = 0; i < 4; i++) {
            t += 600;
            vm.recordLogs();
            mod.writeTimepoint(t, ticks[i]);
            Vm.Log[] memory e3 = _filterE3(vm.getRecordedLogs());
            assertEq(e3.length, 1, "exactly one E3 per successful write");
            assertEq(e3[0].topics[1], bytes32(0), "module-global poolId sentinel");

            (uint32 lts, int24 ltick, uint88 lvol, int24 lavg, int56 lcum) = _decodeE3(e3[0]);
            (uint32 sts, int24 stick, uint88 svol, int24 savg, int56 scum) = _storedAt(mod.lastIndex());
            assertEq(lts, sts, "timestamp == stored");
            assertEq(lts, t, "timestamp == the write's timestamp");
            assertEq(ltick, stick, "tick == stored (sign-extended)");
            assertEq(ltick, ticks[i], "tick == the write's tick");
            assertEq(lvol, svol, "volatilityCumulative == stored");
            assertEq(lavg, savg, "averageTick == stored (sign-extended)");
            assertEq(lcum, scum, "tickCumulative == stored (sign-extended)");
        }
    }

    // Fuzz over non-degenerate corpora spanning both signs: the log stream is a faithful
    // projection of every stored timepoint.
    // forge-config: default.fuzz.runs = 128
    function test__fuzz__writeLogMirrorsStoredTimepoint(int32[6] memory tickRaw, uint16[6] memory dtRaw) public {
        int24 tick0 = int24(bound(int256(tickRaw[0]), -800000, 800000));
        mod.initializeTWAP(1_000_000, tick0);
        uint32 t = 1_000_000;
        for (uint256 i = 0; i < 6; i++) {
            t += uint32(bound(uint256(dtRaw[i]), 1, 40000));
            int24 tk = int24(bound(int256(tickRaw[i]), -800000, 800000));
            vm.recordLogs();
            mod.writeTimepoint(t, tk);
            Vm.Log[] memory e3 = _filterE3(vm.getRecordedLogs());
            assertEq(e3.length, 1, "one E3 per write");
            (uint32 lts, int24 ltick, uint88 lvol, int24 lavg, int56 lcum) = _decodeE3(e3[0]);
            (uint32 sts, int24 stick, uint88 svol, int24 savg, int56 scum) = _storedAt(mod.lastIndex());
            assertEq(lts, sts, "ts");
            assertEq(ltick, stick, "tick");
            assertEq(lvol, svol, "vol");
            assertEq(lavg, savg, "avgTick");
            assertEq(lcum, scum, "tickCum");
        }
    }

    // The same-block early-out is NOT a state transition and MUST NOT emit.
    function test__unit__sameBlockSecondWriteEmitsNothing() public {
        mod.initializeTWAP(1_000_000, 100);
        mod.writeTimepoint(1_000_600, 500);
        vm.recordLogs();
        mod.writeTimepoint(1_000_600, 999); // same block: silently ignored, no event
        assertEq(vm.getRecordedLogs().length, 0, "same-block write emits nothing");
    }
}
