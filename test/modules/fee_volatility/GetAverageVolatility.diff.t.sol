// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {MarketStatisticsAlgebraRef} from "../../MarketStatisticsTest.t.sol";
import {VolatilityOraclePluginImplementation} from
    "@cryptoalgebra/volatility-oracle-plugin/VolatilityOraclePluginImplementation.sol";

// Differential: Plank getAverageVolatility MUST equal Algebra's window-normalized, Bessel-corrected
// getAverageVolatility (VolatilityOracle.sol), tolerance ZERO. This is todo 6-9 (VDIFF-03 deliberately
// left getAverageVolatility out of the earlier diff because Plank's was a raw-cumulative STUB).
//
// The full chain exercised here (nothing before this test touched it end-to-end):
//   write-path volatilityCumulative accumulation + windowStartIndex tracking
//   -> volatility_cumulative_at (interpolation, incl. the kernel-based extrapolate branch)
//   -> the 3-branch windowed getAverageVolatility (full-window / interpolate-at-wsi / Bessel extrapolate).
//
// MUTATION this kills: any get_average_volatility that returns the raw cumulative (the stub), skips the
// /WINDOW normalization, drops Bessel's correction, or mis-interpolates the window start -- all diverge
// from Algebra's uint88 here.
interface IPlankVolMod {
    function initializeTWAP(uint32 blockTimestamp, int24 tick) external;
    function writeTimepoint(uint32 blockTimestamp, int24 tick) external;
    function getAverageVolatility(int24 tick, uint32 blockTimestamp) external view returns (uint88);
}

contract GetAverageVolatilityDiffTest is PlankTestBase {
    IPlankVolMod internal plk;
    MarketStatisticsAlgebraRef internal alg;

    uint32 constant WINDOW = 86400; // Algebra's 1 day

    function setUp() public {
        plk = IPlankVolMod(deployPlank("src/modules/fee_volatility/RealizedVolatilityMod.plk"));
        alg = new MarketStatisticsAlgebraRef(new VolatilityOraclePluginImplementation());
    }

    // Write the SAME corpus to both oracles: init, then a series of (timestamp, tick) samples with
    // VARYING ticks (non-degenerate volatility) spanning > WINDOW so the full-window branch is hit.
    function _writeCorpus(uint32 t0, int24 tick0, uint32[8] memory dts, int24[8] memory ticks) internal {
        plk.initializeTWAP(t0, tick0);
        alg.initializeTWAP(t0, tick0);
        uint32 t = t0;
        for (uint256 i = 0; i < 8; i++) {
            t += dts[i];
            plk.writeTimepoint(t, ticks[i]);
            alg.writeTimepoint(t, ticks[i]);
        }
    }

    // Deterministic corpus spanning > 1 day with a rising/falling tick path -> genuine variance.
    function test_getAverageVolatility_matchesAlgebra_fullWindow() public {
        uint32 t0 = 1_000_000;
        int24 tick0 = 100;
        // dts sum = 8*15000 = 120000 > WINDOW(86400): full-window branch reachable.
        uint32[8] memory dts = [uint32(15000), 15000, 15000, 15000, 15000, 15000, 15000, 15000];
        int24[8] memory ticks =
            [int24(500), int24(-300), int24(900), int24(-1200), int24(400), int24(2000), int24(-800), int24(1500)];
        _writeCorpus(t0, tick0, dts, ticks);

        uint32 nowTs = t0 + 120000 + 7; // a few seconds past the last write (interpolate-to-now path)
        int24 nowTick = 1234;
        assertEq(
            uint256(plk.getAverageVolatility(nowTick, nowTs)),
            uint256(alg.getAverageVolatilityLast(nowTick, nowTs)),
            "getAverageVolatility == Algebra, tolerance 0 (full window)"
        );
    }

    // Short corpus (< WINDOW total) -> the Bessel-corrected EXTRAPOLATE branch.
    function test_getAverageVolatility_matchesAlgebra_besselExtrapolate() public {
        uint32 t0 = 1_000_000;
        int24 tick0 = 0;
        uint32[8] memory dts = [uint32(600), 600, 600, 600, 600, 600, 600, 600]; // sum 4800 << WINDOW
        int24[8] memory ticks =
            [int24(200), int24(-500), int24(700), int24(-100), int24(1300), int24(-900), int24(300), int24(-600)];
        _writeCorpus(t0, tick0, dts, ticks);

        uint32 nowTs = t0 + 4800 + 3;
        int24 nowTick = -250;
        assertEq(
            uint256(plk.getAverageVolatility(nowTick, nowTs)),
            uint256(alg.getAverageVolatilityLast(nowTick, nowTs)),
            "getAverageVolatility == Algebra, tolerance 0 (Bessel extrapolate)"
        );
    }

    // Fuzz: random non-degenerate corpus (varying ticks, varying dts across both regimes), tolerance 0.
    // Kills any storage-ignoring / interpolation / branch-selection mutant the two golden cases miss.
    // forge-config: default.fuzz.runs = 256
    function testFuzz_getAverageVolatility_matchesAlgebra(
        int32[8] memory tickRaw, uint16[8] memory dtRaw, uint32 nowExtra, int32 nowTickRaw
    ) public {
        int24 tick0 = int24(bound(int256(tickRaw[0]), -800000, 800000));
        uint32 t0 = 1_000_000;
        uint32[8] memory dts;
        int24[8] memory ticks;
        int24 prev = tick0;
        for (uint256 i = 0; i < 8; i++) {
            dts[i] = uint32(bound(uint256(dtRaw[i]), 1, 40000)); // >0 (no same-block collapse); mix of regimes
            int24 tk = int24(bound(int256(tickRaw[i]), -800000, 800000));
            if (tk == prev) tk = (tk == int24(800000)) ? tk - 1 : tk + 1; // non-degenerate variance
            ticks[i] = tk;
            prev = tk;
        }
        _writeCorpus(t0, tick0, dts, ticks);

        uint32 lastTs = t0;
        for (uint256 i = 0; i < 8; i++) {
            lastTs += dts[i];
        }
        uint32 nowTs = lastTs + uint32(bound(uint256(nowExtra), 0, 20000));
        int24 nowTick = int24(bound(int256(nowTickRaw), -800000, 800000));

        assertEq(
            uint256(plk.getAverageVolatility(nowTick, nowTs)),
            uint256(alg.getAverageVolatilityLast(nowTick, nowTs)),
            "getAverageVolatility == Algebra, tolerance 0 (fuzz)"
        );
    }
}
