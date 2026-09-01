// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {VolatilityOraclePluginImplementation} from
    "@cryptoalgebra/volatility-oracle-plugin/VolatilityOraclePluginImplementation.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {MarketStatisticsAlgebraRef, MarketStatisticsUniV3Ref} from "../../MarketStatisticsTest.t.sol";
import {AlgebraVolatilityKernelMock} from "../../mocks/AlgebraVolatilityKernelMock.sol";
import {TimepointDecoder, PlankTimepoint} from "../../types/fee-volatility/TimepointDecoder.sol";

// ===========================================================================================
// THE realized-volatility differential suite. Everything that exercises
// src/modules/fee-volatility/RealizedVolatilityMod.plk -- and the variance kernel it
// is built on -- lives in THIS FILE. Five contracts, two deploy targets, one place to look.
//
// The two deploy targets are deliberately different things:
//
//   * RealizedVolatilityMod.plk            -- the production module (init/write/query + state).
//   * RealizedVolatilityKernelHarness.plk  -- a TEST-ONLY ABI harness over the pure kernel
//                                             function calculate_realized_volatility, so the
//                                             formula can be diffed without a write path.
//
// Reading order, weakest claim to strongest:
//
//   1. RealizedVolatilityKernelProbeTest   -- kernel, ONE point, + an external hand-derived
//                                             anchor. A wiring proof.
//   2. RealizedVolatilityKernelDiffTest    -- kernel, 5-D fuzz over a domain (VDIFF-02).
//   3. RealizedVolatilitySmokeTest         -- the module is deployable, its dispatch is live,
//                                             and each named past bug is falsifiable.
//   4. RealizedVolatilityDiffTest          -- Algebra vs UniV3 vs Plank on the TICK surface
//                                             (accumulator, TWAP, stored state).
//   5. RealizedVolatilityTimepointDiffTest -- Algebra vs Plank on the VARIANCE surface, after
//                                             EVERY write (VDIFF-04).
//
// GLOBAL RULE FOR THIS FILE: "it compiles" is never acceptance. `plank build` does NOT
// type-check code unreachable from run{} -- this repo once shipped a "13 ok / 0 failed" compile
// gate that was green on an EMPTY module. Only calling a function proves it exists.
//
// GLOBAL RULE 2: no `make compile-plank` is needed to make a `.plk` edit reach these tests.
// deployPlank -> plankDeployFFI -> plankBuildFFI shells out to `plank build` over FFI AT TEST
// TIME. build/plank/*.hex is written by `make compile-plank` and read by NOTHING in this path.
// (08-02's SUMMARY claims the opposite; that claim is FALSE and STATE.md carries the
// correction. It was disproven empirically: a kernel-coefficient edit alone turned the probe
// red with no recompile.)
// ===========================================================================================

/// @notice The ABI RealizedVolatilityMod.plk dispatches on. `initializeTWAP` and `getTwapTick`
///         are deliberately the SAME selectors Algebra's plugin uses, so ONE interface drives
///         Algebra, UniV3 and Plank across the whole suite.
///
/// @dev getAverageVolatility(int24,uint32) is DELIBERATELY NOT DECLARED (VDIFF-03).
///
///      Plank's getAverageVolatility returned the last timepoint's RAW volatilityCumulative
///      accumulator. Algebra's (VolatilityOracle.sol:195-242) is Bessel-corrected AND
///      WINDOW-normalised. These are DIFFERENT QUANTITIES -- diffing them is not a strict test,
///      it is a wrong one, and any green it produced would be meaningless. The surface is
///      removed so the mistake cannot be made in the first place.
///
///      The CORRECT scalar-volatility check is the STORED volatilityCumulative field, read via
///      getTimepointPacked and unpacked at OFF_VOL -- see
///      RealizedVolatilitySmokeTest.test__unit__negativeAvgTickVolatilityIsExact, and
///      RealizedVolatilityTimepointDiffTest (VDIFF-04) which generalises it to a field-by-field
///      Algebra-vs-Plank differential.
///
///      The state readers below are not optional garnish: without them the module is a black
///      box, and getTwapTick (a QUOTIENT) lets compensating internal errors cancel.
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

/// @notice The Plank kernel harness's ABI. Deliberately takes ALGEBRA'S argument order
///         (dt, tick0, tick1, avgTick0, avgTick1) so ONE identical tuple drives both sides and
///         the harness owns the Algebra->Plank re-order at a SINGLE call site
///         (RealizedVolatilityKernelHarness.plk:49). That is what makes the parameter-order
///         footgun mutable in one place, and therefore falsifiable.
///
/// @dev Selector 0xc6342af0 = volatilityOnRange(int256,int256,int256,int256,int256) -- VERIFIED
///      with `cast sig`. 09-CONTEXT.md documents this selector as
///      volatilityOnRange(uint32,int24,int24,int24,int24); that is WRONG (it hashes to
///      0x5fb3d926). The harness's own header comment is the correct one. int256 is also what
///      the harness actually wants: it reads whole 32-byte calldata words and treats them as
///      sign-extended two's-complement, which is exactly Solidity's int256 ABI encoding.
interface IPlankVolKernel {
    function volatilityOnRange(int256 dt, int256 tick0, int256 tick1, int256 avgTick0, int256 avgTick1)
        external
        view
        returns (uint256);
}

/// @title RealizedVolatilityKernelProbeTest
/// @notice Proves the variance-kernel pair is WIRED and AGREES, on ONE point, against an
///         externally hand-derived anchor. Algebra's `_volatilityOnRange` (via
///         AlgebraVolatilityKernelMock) versus Plank's `calculate_realized_volatility` (via
///         RealizedVolatilityKernelHarness.plk), tolerance 0.
///
/// @dev WHY THESE INPUTS -- NON-DEGENERACY. dt=30, tick0=100, tick1=-400, avgTick0=50,
///      avgTick1=-100 gives k = -350 (!= 0) AND b = 1500 (!= 0). Both matter:
///        * A constant tick path yields k = 0 AND b = 0 => vol = 0 on BOTH sides, and
///          `assertEq(got, exp)` degrades to assertEq(0, 0) -- it would pass against a kernel
///          that returns 0 unconditionally. That is a vacuous test, not a probe.
///        * 08-CONTEXT phrases non-degeneracy as `tick0 != tick1`; that only secures k != 0.
///          b != 0 ADDITIONALLY requires tick0 != avgTick0. This input satisfies both.
///      Do not weaken this input.
///
/// @dev WHY dt = 30 AND NOT 0. dt = 0 is a KNOWN, EXCLUDED divergence: Solidity's `/` reverts
///      with Panic 0x12 even inside `unchecked`, while the EVM's SDIV returns 0 silently. The
///      kernels genuinely disagree there, by design of the two languages.
///
/// @dev WHAT THIS KILLS. The parameter-order footgun: Plank's kernel is
///      (avg_tick0, avg_tick1, tick0, tick1, dt) while Algebra's is (dt, tick0, tick1, avgTick0,
///      avgTick1). Mis-wiring the harness's re-order to Algebra's order makes the two sides
///      disagree on this input. That mutant was APPLIED and OBSERVED RED, then restored to green
///      (recorded in 08-02-SUMMARY.md) -- this probe is not merely asserted to be falsifiable.
///
/// @dev WHAT THIS DOES NOT DO. It is a SINGLE POINT, not the fuzz. RealizedVolatilityKernelDiffTest
///      below owns the 5-D domain. Agreement here is a wiring proof and a necessary precondition
///      -- not evidence of bit-exactness across the domain. Conversely the fuzz does not
///      supersede this probe: a purely differential assertion would be satisfied by a mock that
///      merely ECHOED Plank. Only this anchor pins Algebra to a number neither implementation
///      can influence. Both are needed.
contract RealizedVolatilityKernelProbeTest is PlankTestBase {
    AlgebraVolatilityKernelMock mock;
    IPlankVolKernel plk;

    // The hand-verified non-degenerate point. See the docblock above.
    int256 constant DT = 30;
    int256 constant TICK0 = 100;
    int256 constant TICK1 = -400;
    int256 constant AVG_TICK0 = 50;
    int256 constant AVG_TICK1 = -100;

    /// @dev Derived independently of BOTH implementations, from Algebra's documented formula:
    ///        k             = (tick1-tick0) - (avgTick1-avgTick0) = -500 - (-150) = -350
    ///        b             = (tick0-avgTick0)*dt                 = 50*30         = 1500
    ///        sumOfSequence = dt*(dt+1)                                           = 930
    ///        sumOfSquares  = sumOfSequence*(2*dt+1)                              = 56730
    ///        num = k^2*sumOfSquares + 6*b*k*sumOfSequence + 6*dt*b^2
    ///            = 6,949,425,000 + (-2,929,500,000) + 405,000,000 = 4,424,925,000
    ///        den = 6*dt^2 = 5400
    ///        vol = 4,424,925,000 / 5400 = 819,430  (SDIV truncates toward zero)
    ///      This anchor is load-bearing: without it, a mock that merely ECHOED Plank's answer
    ///      would satisfy the differential assertion. The anchor pins both sides to an
    ///      externally-derived number neither implementation can influence.
    uint256 constant EXPECTED_VOL = 819430;

    function setUp() public {
        mock = new AlgebraVolatilityKernelMock();
        plk = IPlankVolKernel(deployPlank("test/lib/fee-volatility/RealizedVolatilityKernelHarness.plk"));
    }

    function test__unit__kernelProbeAlgebraEqualsPlankNonDegenerate() public {
        uint256 got = plk.volatilityOnRange(DT, TICK0, TICK1, AVG_TICK0, AVG_TICK1);
        uint256 exp = mock.volatilityOnRange(DT, TICK0, TICK1, AVG_TICK0, AVG_TICK1);

        // THE differential assertion: exact agreement, no tolerance.
        assertEq(got, exp, "kernel probe: plank vs algebra, tolerance 0");

        // The independent anchor: pins Algebra's kernel to a hand-computed value, so a mock that
        // returns Plank's answer by accident cannot pass.
        assertEq(exp, EXPECTED_VOL, "algebra kernel vs hand-computed anchor");

        // Guards a future edit that flattens the input to a constant path (k=0, b=0 => vol=0),
        // which would make the assertion above pass vacuously.
        assertTrue(exp != 0, "probe must be non-degenerate");
    }
}

/// @title RealizedVolatilityKernelDiffTest
/// @notice VDIFF-02: the 5-D variance-kernel differential fuzz. Drives ONE
///         (dt, tick0, tick1, avgTick0, avgTick1) tuple through BOTH Algebra's
///         `_volatilityOnRange` (via AlgebraVolatilityKernelMock) and Plank's
///         `calculate_realized_volatility` (via RealizedVolatilityKernelHarness.plk), asserting
///         exact FULL-uint256 equality at tolerance 0 across a CONSTRUCTED non-degenerate domain.
///
/// @dev WHY TOLERANCE 0 IS GUARANTEED, NOT HOPED (within int24 ticks x uint32 dt). This is not an
///      empirical hope that the fuzzer failed to break; it is a property of the two operator trees:
///        * The trees match EXACTLY: Algebra's `k ** 2 * sumOfSquares` is Plank's
///          `(k *% k) *% sumOfSquares`; `6 * b * k * sumOfSequence` is left-associative on BOTH
///          sides; `6 * dt * b ** 2` is `(6 *% dt) *% (b *% b)` because Solidity's `**` binds
///          tighter than `*`.
///        * NEITHER SIDE WRAPS, so they cannot wrap DIFFERENTLY. |tick| <= 887272 < 2^20 and
///          dt < 2^32, so |b| = |tick0 - avgTick0| * dt <= 2^21 * 2^32 = 2^53 (bounded well under
///          the 2^56 headroom), and the numerator peaks around 2^149 -- vastly below 2^256.
///        * Plank's `evm_sdiv` builtin IS the SDIV opcode that Solidity's `int256 /` compiles to
///          under `unchecked`. Identical truncation toward zero, including negative numerators.
///          (Spelled without its Plank at-sigil here: solc's NatSpec parser reads a leading
///          at-sign inside a docblock as a documentation tag and rejects the file.)
///      Therefore: IF THIS FUZZ EVER GOES RED, IT IS A REAL DIVERGENCE. Do not add a tolerance,
///      shrink the domain, or bound the trap away to restore green -- report the counterexample.
///
/// @dev WHY TOLERANCE 0 IS REGIME-CONDITIONAL. Exactness is claimed ONLY inside int24 x uint32.
///      It is NOT claimed in Algebra's deliberate int56-overflow regime: Plank's full-width
///      in-flight accumulator does not replicate the `int56` wrap (RealizedVolatilityLib.plk vs
///      VolatilityOracle.sol:357). The type bounds below keep this corpus OUT of that regime.
///      This test proves bit-exactness on a stated domain, not universal exactness.
///
/// @dev WHY dt IS BOUNDED >= 1. dt = 0 is a KNOWN, EXCLUDED divergence (see the probe above).
///      Left unbounded, the fuzzer draws 0 within a handful of runs and the mock reverts -- the
///      run fails for the WRONG reason, telling us nothing about the kernels' agreement. The
///      exclusion is by CONSTRUCTION (bound), not by filtering.
///
/// @dev WHY THE CORPUS IS CONSTRUCTED AND NOT ASSUMPTION-FILTERED. The assume cheatcode would
///      silently shrink the corpus and can exhaust the fuzzer's rejection budget, converting a
///      real coverage hole into a green run. Every drawn tuple is REPAIRED into the
///      non-degenerate domain deterministically, so all 1024 runs are live assertions.
///
/// @dev WHY NON-DEGENERACY NEEDS BOTH k != 0 AND b != 0. If both are 0 the kernel returns 0 on
///      both sides and `assertEq(got, exp)` degrades to `assertEq(0, 0)` -- which passes against
///      a kernel that ALWAYS RETURNS 0. `tick0 != tick1` secures only k; b != 0 ADDITIONALLY
///      requires `tick0 != avgTick0`. Both are repaired in, and both are asserted on every run.
///
/// @dev WHY THE FULL uint256 AND NOT THE 88-BIT PRODUCTION WIDTH. Production truncates the
///      accumulator to 88 bits, but comparing the WHOLE returned word is strictly stronger on a
///      free axis: it catches high-bit divergence that truncation would hide from us. Mutant A
///      below is exactly that case.
///
/// @dev WHAT THIS KILLS -- APPLIED AND OBSERVED RED, NOT ASSERTED FROM REASONING (09-01 Task 2;
///      the verbatim failure output is recorded in 09-01-SUMMARY.md):
///        * MUTANT A -- the parameter-order footgun. Swapping the harness's single re-order call
///          site (RealizedVolatilityKernelHarness.plk:49) from Plank's order
///          `calculate_realized_volatility(avg_tick0, avg_tick1, tick0, tick1, dt)` to Algebra's
///          `(dt, tick0, tick1, avg_tick0, avg_tick1)` made this fuzz FAIL, exit 2:
///            "115792089237316195423570985008687907853269984665640564039457584003616512485613
///             != 787251601984"  (note the ~2^256 left side: the swap feeds dt where a tick is
///             expected, so the wrapping operators produce a near-full-width word -- exactly the
///             high-bit divergence the FULL-uint256 assertion exists to catch).
///          Restored byte-identical -> green.
///        * MUTANT B -- the kernel middle-term coefficient. Changing
///          RealizedVolatilityLib.plk:32 from `+% 6 *% b *% k *% sumOfSequence` to `+% 7 *% ...`
///          made this fuzz FAIL, exit 2, on a FRESH corpus (fuzz failure cache cleared first, so
///          this is a kill on its own merits and not a replay of Mutant A's cached
///          counterexample): "857507691265 != 857256149370" at
///          args=[dtRaw=887272, t0Raw=-887272, t1Raw=2820, a0Raw=-887272, a1Raw=4522].
///          Restored byte-identical -> green.
///      A `runs: 0` kill is Foundry REPLAYING a cached counterexample, not fuzzing. Clear
///      cache/fuzz before believing any kill in this contract.
contract RealizedVolatilityKernelDiffTest is PlankTestBase {
    AlgebraVolatilityKernelMock mock;
    IPlankVolKernel plk;

    // int24 tick bounds -- Uniswap/Algebra's MIN_TICK/MAX_TICK. Keeps the corpus inside the
    // regime where tolerance 0 is a guarantee (see the docblock).
    int256 constant TICK_MIN = -887272;
    int256 constant TICK_MAX = 887272;

    // dt in [1, 2^32): 0 is EXCLUDED BY CONSTRUCTION (known divergence, see the docblock).
    uint256 constant DT_MIN = 1;
    uint256 constant DT_MAX = 4294967295; // type(uint32).max

    function setUp() public {
        mock = new AlgebraVolatilityKernelMock();
        plk = IPlankVolKernel(deployPlank("test/lib/fee-volatility/RealizedVolatilityKernelHarness.plk"));
    }

    /// @notice THE differential fuzz: both kernels, one tuple, full uint256, tolerance 0.
    /// @dev Run count raised in-file. Each run is ~12k gas; setUp's FFI `plank build` happens once
    ///      per test function, NOT once per run, so 1024 runs is cheap.
    /// forge-config: default.fuzz.runs = 1024
    function test__fuzz__kernelAlgebraEqualsPlankFiveDim(
        uint32 dtRaw,
        int32 t0Raw,
        int32 t1Raw,
        int32 a0Raw,
        int32 a1Raw
    ) public {
        int256 dt = int256(bound(uint256(dtRaw), DT_MIN, DT_MAX));

        int256 tick0 = bound(int256(t0Raw), TICK_MIN, TICK_MAX);
        int256 avgTick0 = bound(int256(a0Raw), TICK_MIN, TICK_MAX);
        // b = (tick0 - avgTick0) * dt must be != 0  =>  tick0 != avgTick0.
        // REPAIR, do not reject: nudge avgTick0 by one, staying inside the int24 bounds.
        if (avgTick0 == tick0) avgTick0 = (tick0 == TICK_MAX) ? tick0 - 1 : tick0 + 1;

        int256 avgTick1 = bound(int256(a1Raw), TICK_MIN, TICK_MAX);
        int256 tick1 = bound(int256(t1Raw), TICK_MIN, TICK_MAX);
        // k = (tick1 - tick0) - (avgTick1 - avgTick0) must be != 0.
        // REPAIR: nudge tick1 by one, which shifts k by exactly +/-1 off zero. tick1 does not
        // appear in b, so this repair cannot undo the b repair above.
        if ((tick1 - tick0) - (avgTick1 - avgTick0) == 0) {
            tick1 = (tick1 == TICK_MAX) ? tick1 - 1 : tick1 + 1;
        }

        // The non-vacuity guard. Both, not just k: tick0 != tick1 alone secures only k, and a
        // corpus with b == 0 everywhere would pass against a kernel that ignores b entirely.
        int256 k = (tick1 - tick0) - (avgTick1 - avgTick0);
        int256 b = (tick0 - avgTick0) * dt;
        assertTrue(k != 0, "corpus must be non-degenerate: k != 0");
        assertTrue(b != 0, "corpus must be non-degenerate: b != 0");

        // THE assertion: ONE tuple, both sides, full uint256, tolerance 0.
        uint256 got = plk.volatilityOnRange(dt, tick0, tick1, avgTick0, avgTick1);
        uint256 exp = mock.volatilityOnRange(dt, tick0, tick1, avgTick0, avgTick1);
        assertEq(got, exp, "kernel 5-D: plank vs algebra, tolerance 0, full uint256");
    }
}

/// @title RealizedVolatilitySmokeTest
/// @notice Proves RealizedVolatilityMod.plk is deployable, its ABI dispatch is live, and -- the
///         part that matters -- that the specific fixes in d4da7f7 are FALSIFIABLE.
///
// dev: An earlier version of this suite was mutation-tested by a reviewer and FAILED: deleting
//      the signextend builtin from unpack_timepoint, corrupting the volatility kernel's
//      coefficient, and deleting u32_sub's 32-bit mask ALL left it 6/6 green. It asserted things
//      that could not distinguish a correct oracle from a broken one:
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
    IPlankOracle oracle;

    // Algebra's `uint32 constant WINDOW = 1 days`. Ours is STORAGE, so it must be asserted.
    uint32 constant WINDOW = 86400;
    uint32 constant DT = 30;

    // Deliberately ABOVE the window: the ordinary regime.
    uint32 constant T_HIGH = 1_000_000;
    // Deliberately BELOW the window: `currentTime - WINDOW` underflows uint32 here. This is the
    // ONLY regime in which the u32_sub fix is reachable, and the old suite never entered it.
    uint32 constant T_LOW = 500;

    // The Timepoint bit layout lives in ONE place -- ./TimepointDecoder.sol -- because the
    // VDIFF-04 differential below needs the same unpacker, and two copies of a bit layout is two
    // chances to desynchronise from Timepoint.plk. Reading the stored word back is what pins the
    // packing; the field WIDTHS are what must match Algebra, not the offsets (Plank's packing
    // order is not Solidity's struct packing order).

    function _timepoint(uint16 index) internal view returns (PlankTimepoint memory) {
        return TimepointDecoder.decode(oracle.getTimepointPacked(index));
    }

    function _last() internal view returns (PlankTimepoint memory) {
        return _timepoint(oracle.lastIndex());
    }

    function setUp() public {
        oracle = IPlankOracle(deployPlank("src/modules/fee-volatility/RealizedVolatilityMod.plk"));
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

    /// @notice KILLS: removing the signextend builtin from unpack_timepoint.
    /// @dev Reads the STORED tick/avg_tick back. Without sign-extension a negative int24 comes
    ///      back as a large positive (e.g. -200 -> 16777016). getTwapTick alone cannot see this,
    ///      because the tick it does arithmetic on comes from calldata, not from storage.
    function test__unit__storedNegativeTickSignExtends() public {
        int24 tick = int24(-200);
        oracle.initializeTWAP(T_HIGH, tick);

        PlankTimepoint memory t = _last();
        assertEq(t.tick, tick, "stored tick must sign-extend");
        assertEq(t.avgTick, tick, "stored avg_tick must sign-extend");
        assertTrue(t.initialized);
    }

    /// @notice KILLS: removing the signextend builtin from tick_cumulative (int56, a DIFFERENT
    ///         SIGNEXTEND byte index than the int24 ticks -- getting that one wrong is silent).
    /// @dev A sustained negative tick drives the accumulator negative.
    function test__unit__storedNegativeTickCumulativeSignExtends() public {
        int24 tick = int24(-500);
        oracle.initializeTWAP(T_HIGH, tick);
        oracle.writeTimepoint(T_HIGH + DT, tick);
        oracle.writeTimepoint(T_HIGH + 2 * DT, tick);

        PlankTimepoint memory t = _last();
        // tick_cumulative = sum(tick * dt) = -500 * 60
        assertEq(t.tickCumulative, int56(-500) * int56(60), "negative accumulator must sign-extend");
    }

    /// @notice KILLS: the checked `-` in the volatility kernel (this REVERTED), and asserts the
    ///         resulting accumulator so a kernel that merely stops reverting is not enough.
    function test__unit__downwardTickMoveIsCorrect() public {
        oracle.initializeTWAP(T_HIGH, int24(500));
        oracle.writeTimepoint(T_HIGH + DT, int24(100)); // strictly below the running average
        oracle.writeTimepoint(T_HIGH + 2 * DT, int24(-300)); // and again, through zero

        PlankTimepoint memory t = _last();
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

        // With a correct uint32 window_start, the oldest timepoint is NEWER than one window ago,
        // so avg_tick = (cum_now - cum_oldest) / (now - oldest) = (2000*30 - 0) / 30 = 2000.
        // With the mask deleted, oracle_lte inverts and avg_tick collapses to the spot tick --
        // which here is ALSO 2000, so the average must be checked where it differs from spot:
        oracle.writeTimepoint(T_LOW + 2 * DT, int24(0));
        PlankTimepoint memory t2 = _last();
        // now: cumulative = 2000*30 + 0*30 = 60000 over 60s from T_LOW -> average 1000, spot 0.
        assertEq(t2.tick, int24(0), "spot");
        assertEq(t2.avgTick, int24(1000), "avg must be the time-weighted mean, not the spot tick");
        assertTrue(t2.avgTick != t2.tick, "the whole point: average must differ from spot here");
    }

    /// @notice KILLS: (a) removing the signextend builtin from avg_tick, and (b) any corruption
    ///         of the volatility kernel's coefficients.
    ///
    /// @dev This is the ONLY assertion in this contract that pins either. Reading the stored
    ///      `.tick` back cannot pin sign-extension: the packed 24 bits are identical whether or
    ///      not unpack extends, and the Solidity decode re-derives the sign anyway. But
    ///      `avg_tick` is CONSUMED -- create_timepoint feeds `current.avg_tick` into
    ///      calculate_realized_volatility -- so a missing sign-extension turns -1000 into
    ///      16776216 and the kernel output explodes. Only an EXACT volatilityCumulative catches
    ///      it. `assertGt(vol, 0)` does not.
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

        PlankTimepoint memory t = _last();
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
    ///      NOT coverage.
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
        PlankTimepoint memory t = _timepoint(0);
        assertEq(t.timestamp, T_HIGH + DT, "slot 0 must hold the NEW timepoint, not genesis");
        assertEq(t.tick, int24(300), "slot 0 must hold the NEW tick, not genesis");
    }
}

/// @title RealizedVolatilityDiffTest
/// @notice The THREE-WAY tick-surface differential (Phase 0-1).
///
///         ONE driver applies the SAME (timestamp, tick) sequence to Algebra, UniV3 and Plank.
///         If they were driven by separate code paths a harness bug would surface as a silent
///         divergence blamed on the port.
///
///         After every point, the three implementations must agree EXACTLY, tolerance ZERO, on:
///           - getTickCumulative(dt) -- the primitive; isolates the ring search + interpolation
///           - getTwapTick(dt)       -- the quotient, incl. the floor-toward-(-inf) correction
///           - the stored (blockTimestamp, tickCumulative, initialized) at lastIndex
///         getTwapTick alone is insufficient: it is a QUOTIENT, so a truncated accumulator and a
///         wrong oldest-index cancel and a TWAP-only assertion passes. Assert the accumulator AND
///         the quotient AND the stored state.
///
///         UniV3 belongs HERE and not in the variance diff below, for a concrete reason:
///         tickCumulative genuinely exists in all three implementations. UniV3 has no volatility
///         accumulator at all.
///
///         Regime: strictly NO-WRAP. Writes are bounded < CARDINALITY_TARGET (512) so UniV3's
///         ring (mod cardinality) tracks Algebra/Plank (mod 65536). Wrap and the sub-WINDOW
///         u32_sub regime are Phase 10/11, not here.
contract RealizedVolatilityDiffTest is PlankTestBase {
    MarketStatisticsAlgebraRef alg;
    MarketStatisticsUniV3Ref uni;
    IPlankOracle plk;

    uint32 constant WINDOW = 86400;
    // < 512 keeps UniV3 in its no-wrap regime; also well under 65536.
    uint256 constant MAX_WRITES = 200;
    int24 constant TICK_MIN = -887272;
    int24 constant TICK_MAX = 887272;

    function setUp() public {
        alg = new MarketStatisticsAlgebraRef(new VolatilityOraclePluginImplementation());
        uni = new MarketStatisticsUniV3Ref();
        plk = IPlankOracle(deployPlank("src/modules/fee-volatility/RealizedVolatilityMod.plk"));
    }

    // ---- The shared three-way driver -------------------------------------------------------

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

    // Deterministic per-run derivation, so the corpus is CONSTRUCTED (not assumption-filtered).
    function _tickAt(uint256 seed, uint256 i) internal pure returns (int24) {
        return int24(bound(int256(uint256(keccak256(abi.encode(seed, i, "tick")))), TICK_MIN, TICK_MAX));
    }

    function _deltaAt(uint256 seed, uint256 i) internal pure returns (uint32) {
        return uint32(bound(uint256(keccak256(abi.encode(seed, i, "dt"))), 1, 3600));
    }

    // ---- The assertions ---------------------------------------------------------------------

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

        PlankTimepoint memory p = TimepointDecoder.decode(plk.getTimepointPacked(li));

        assertEq(tsA, tsU, "stored timestamp: algebra vs univ3");
        assertEq(tsA, p.timestamp, "stored timestamp: algebra vs plank");
        assertEq(cumA, cumU, "stored tickCumulative: algebra vs univ3");
        assertEq(cumA, p.tickCumulative, "stored tickCumulative: algebra vs plank");
        assertTrue(initU && p.initialized, "stored initialized flag");
    }

    // ---- Anchor: a fixed, hand-checkable sequence -------------------------------------------

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

    // ---- Fuzzed, constructed corpus, no-wrap ------------------------------------------------

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
        if (span == 0) return; // delta >= 1, so span >= 1 for n >= 2; defensive only
        uint32 dt = uint32(bound(uint256(keccak256(abi.encode(seed, "querydt"))), 1, span));
        _assertThreeWayAt(dt, lastTick, t);

        // Also pin the two boundaries explicitly.
        _assertThreeWayAt(1, lastTick, t); // newest interval
        _assertThreeWayAt(span, lastTick, t); // the whole window, back to genesis
    }
}

/// @title RealizedVolatilityTimepointDiffTest
/// @notice VDIFF-04: the full-timepoint VARIANCE differential. One (timestamp, tick) sequence is
///         applied to Algebra and Plank, and after EVERY write both must agree EXACTLY --
///         tolerance ZERO -- on the STORED volatilityCumulative, averageTick and windowStartIndex
///         at lastIndex.
///
// ===========================================================================================
// WHY THIS CONTRACT EXISTS, given the kernel is already fuzzed above (VDIFF-02 / 09-01).
//
// The kernel fuzz proves the variance FORMULA: calculate_realized_volatility agrees with
// Algebra's _volatilityOnRange across a 5-D domain at tolerance 0, 1024 runs, zero
// counterexamples. It says NOTHING about whether that formula is CALLED WITH THE RIGHT
// ARGUMENTS, ACCUMULATED correctly, or PACKED correctly on a real write path. This contract
// proves the variance STATE. Consequence worth knowing: because the kernel is proven bit-exact,
// any divergence THIS test finds is in the WRITE PATH (packing / accumulation / windowing), not
// in the kernel -- that is a genuinely narrowed diagnosis, not a vague red.
//
// WHY ALGEBRA-vs-PLANK ONLY -- the UniV3 reference is deliberately NOT driven here.
//
// UniV3's Oracle has NO volatility accumulator. It has nothing to contribute to any of the three
// fields asserted here. Driving it would cost ~11.5M gas per run (its Oracle.grow(512) prepay)
// to produce data that is never compared, and would impose a bogus 512 write-cap on the corpus
// (UniV3's ring is mod cardinality; Algebra's and Plank's are mod 65536). This is exactly where
// the variance differential parts company with RealizedVolatilityDiffTest above: that one has
// three participants because tickCumulative genuinely exists in all three. Its _writeAll drives
// all three, so it is deliberately NOT reused here -- this contract has its own two-way driver.
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
// Already diffed three-way by RealizedVolatilityDiffTest above. This contract adds the VARIANCE
// fields -- the three that diff never touches.
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
// WHAT THIS KILLS -- OBSERVED (09-02 Task 3). Both mutants were APPLIED, RUN, and seen RED; the
// failure output was recorded, then each was restored byte-identical and re-run green. Nothing
// below is inferred from reading the code.
//
//   * MUTANT A -- timepoint PACKING corruption. Timepoint.plk:32, OFF_AVG_TICK 144 -> 145,
//     shifting the packed avg_tick field off its layout. Plank's own pack/unpack stay
//     self-consistent (both read the constant), which is the point: only a test that reads the
//     STORED WORD at the real offset and diffs it against Algebra can see this. getTwapTick
//     cannot. OBSERVED: exit 2, failing the averageTick assertion with `100 != 200` on the fixed
//     anchor -- the stored field reads back exactly DOUBLED, i.e. packed one bit high and
//     decoded at the true offset. Restored -> exit 0.
//
//   * MUTANT B -- accumulation STOPPED. Timepoint.plk:115, the running sum
//     add(current vol, delta vol) reduced to the newest delta alone, i.e. Algebra's `+=` turned
//     into `=`. INVISIBLE on a single write; it can only diverge from the SECOND write onward.
//     OBSERVED: exit 2, failing the volatilityCumulative assertion with `9612287 != 7235899` on
//     the fixed anchor.
//     THIS IS WHY THE ASSERTION LIVES INSIDE THE DRIVER. Those numbers are the state after the
//     SECOND write of the fixed anchor -- 9612287 is Algebra's running cumulative
//     (2376388 + 7235899), 7235899 is that write's delta ALONE. The test aborts at the earliest
//     write at which this mutant is capable of diverging at all. A driver that only asserted
//     once at the end would still have gone red here, but it would have been comparing the
//     third write's state and would have said nothing about WHERE the accumulator first broke.
//     Restored -> exit 0.
//
// Both kills were run against a CLEARED cache/fuzz (rm -rf cache/fuzz). This is not ceremony:
// in 09-01 a mutant's first "kill" came back with runs: 0 because Foundry REPLAYED the previous
// mutant's cached counterexample instead of fuzzing -- the mutant looked killed while the fuzz
// had never run. A runs: 0 kill means REPLAY, not proof. Note that both mutants here are also
// caught by the NON-fuzz unit anchor below, which is cache-independent by construction.
// ===========================================================================================
contract RealizedVolatilityTimepointDiffTest is PlankTestBase {
    MarketStatisticsAlgebraRef alg;
    IPlankOracle plk;

    uint32 constant WINDOW = 86400;
    int24 constant TICK_MIN = -887272;
    int24 constant TICK_MAX = 887272;

    function setUp() public {
        alg = new MarketStatisticsAlgebraRef(new VolatilityOraclePluginImplementation());
        plk = IPlankOracle(deployPlank("src/modules/fee-volatility/RealizedVolatilityMod.plk"));
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
        assertEq(li, plk.lastIndex(), "lastIndex: algebra vs plank (variance)"); // else we compare different slots

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
    ///        den = 6*dt^2 = 5400  ->  vol = 2,376,388 (SDIV truncates toward zero)
    ///      That value was CHECKED empirically during 09-02 before being relaxed to the > 0 form
    ///      asserted here: the exact-value anchor duty belongs to RealizedVolatilityKernelProbeTest
    ///      (anchor 819430) and to the 5-D fuzz. THIS contract's job is the DIFFERENTIAL -- the
    ///      assertion that matters already ran inside every _writeBoth above. This last check only
    ///      certifies the corpus is not a constant path.
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
