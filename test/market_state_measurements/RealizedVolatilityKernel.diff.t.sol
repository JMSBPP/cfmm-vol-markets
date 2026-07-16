// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PlankTestBase} from "../PlankTestBase.sol";
import {AlgebraVolatilityKernelMock} from "../mocks/AlgebraVolatilityKernelMock.sol";

/// @notice The Plank kernel harness's ABI. Deliberately takes ALGEBRA'S argument order
///         (dt, tick0, tick1, avgTick0, avgTick1) so ONE identical tuple drives both sides and
///         the harness owns the re-order at a single call site.
/// @dev Declared at file scope here, mirroring RealizedVolatilityKernel.probe.t.sol. A second
///      declaration in a second file is deliberate: the probe and the fuzz are independent
///      artifacts and neither should import the other.
/// @dev Selector 0xc6342af0 = volatilityOnRange(int256,int256,int256,int256,int256) -- VERIFIED
///      with `cast sig`. 09-CONTEXT.md documents this selector as
///      volatilityOnRange(uint32,int24,int24,int24,int24); that is WRONG (it hashes to
///      0x5fb3d926). The harness's own header comment is the correct one. int256 is also what the
///      harness actually wants: it reads whole 32-byte calldata words and treats them as
///      sign-extended two's-complement, which is exactly Solidity's int256 ABI encoding.
interface IPlankVolKernel {
    function volatilityOnRange(int256 dt, int256 tick0, int256 tick1, int256 avgTick0, int256 avgTick1)
        external
        view
        returns (uint256);
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
/// @dev WHY dt IS BOUNDED >= 1. dt = 0 is a KNOWN, EXCLUDED divergence: Solidity's `/` reverts
///      with Panic 0x12 even inside `unchecked`, while the EVM's SDIV(N, 0) returns 0 SILENTLY.
///      Left unbounded, the fuzzer draws 0 within a handful of runs and the mock reverts -- the
///      run fails for the WRONG reason, telling us nothing about the kernels' agreement. The
///      exclusion is by CONSTRUCTION (bound), not by filtering.
///
/// @dev WHY THE CORPUS IS CONSTRUCTED AND NOT ASSUMPTION-FILTERED. The assume cheatcode would
///      silently shrink the corpus and can exhaust the fuzzer's rejection budget, converting a
///      real coverage hole into a green run. Every drawn tuple is REPAIRED into the
///      non-degenerate domain deterministically, so all 1024 runs are live assertions. This file
///      contains NO assume-style filtering, by policy -- and that policy is grep-enforceable
///      precisely because the token appears nowhere in it.
///
/// @dev WHY NON-DEGENERACY NEEDS BOTH k != 0 AND b != 0. If both are 0 the kernel returns 0 on
///      both sides and `assertEq(got, exp)` degrades to `assertEq(0, 0)` -- which passes against
///      a kernel that ALWAYS RETURNS 0. `tick0 != tick1` secures only k; b != 0 ADDITIONALLY
///      requires `tick0 != avgTick0`. Both are repaired in, and both are asserted on every run.
///
/// @dev WHY THE FULL uint256 AND NOT THE 88-BIT PRODUCTION WIDTH. Production truncates the
///      accumulator to 88 bits, but comparing the WHOLE returned word is strictly stronger on a
///      free axis: it catches high-bit divergence that truncation would hide from us.
///
/// @dev WHAT THIS KILLS -- APPLIED AND OBSERVED RED, NOT ASSERTED (09-01 Task 2; the verbatim
///      failure output is recorded in 09-01-SUMMARY.md):
///        * MUTANT A -- the parameter-order footgun. Swapping the harness's single re-order call
///          site (RealizedVolatilityKernelHarness.plk:49) from Plank's order
///          `calculate_realized_volatility(avg_tick0, avg_tick1, tick0, tick1, dt)` to Algebra's
///          `(dt, tick0, tick1, avg_tick0, avg_tick1)` made this fuzz FAIL (exit != 0). Restored
///          byte-identical -> green.
///        * MUTANT B -- the kernel middle-term coefficient. Changing
///          RealizedVolatilityLib.plk:32 from `+% 6 *% b *% k *% sumOfSequence` to `+% 7 *% ...`
///          made this fuzz FAIL (exit != 0). Restored byte-identical -> green.
///      Both mutants reached the DEPLOYED bytecode without any `make compile-plank`: `deployPlank`
///      -> `plankDeployFFI` -> `plankBuildFFI` shells out to `plank build` over FFI AT TEST TIME.
///      `build/plank/*.hex` is read by NOTHING in this path.
///
/// @dev WHAT THIS DOES NOT REPLACE: RealizedVolatilityKernel.probe.t.sol's independent anchor
///      819430. This fuzz is PURELY DIFFERENTIAL, and a purely differential assertion would be
///      satisfied by a mock that merely ECHOED Plank. The probe pins Algebra to an externally
///      hand-derived value that neither implementation can influence. Both are needed; the fuzz
///      does not supersede the probe.
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
        plk = IPlankVolKernel(deployPlank("test/market_state_measurements/RealizedVolatilityKernelHarness.plk"));
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
