// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PlankTestBase} from "../PlankTestBase.sol";
import {AlgebraVolatilityKernelMock} from "../mocks/AlgebraVolatilityKernelMock.sol";

/// @notice The Plank kernel harness's ABI. Deliberately takes ALGEBRA'S argument order
///         (dt, tick0, tick1, avgTick0, avgTick1) so ONE identical tuple drives both sides and
///         the harness owns the re-order at a single call site.
interface IPlankVolKernel {
    function volatilityOnRange(int256 dt, int256 tick0, int256 tick1, int256 avgTick0, int256 avgTick1)
        external
        view
        returns (uint256);
}

/// @title RealizedVolatilityKernelProbeTest
/// @notice Proves the variance-kernel pair is WIRED and AGREES before Phase 9 fuzzes it.
///         Algebra's `_volatilityOnRange` (via AlgebraVolatilityKernelMock) against Plank's
///         `calculate_realized_volatility` (via RealizedVolatilityKernelHarness.plk), tolerance 0.
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
///      kernels genuinely disagree there, by design of the two languages. Bound dt >= 1.
///
/// @dev WHAT THIS KILLS. The parameter-order footgun (STATE.md open risk): Plank's kernel is
///      (avg_tick0, avg_tick1, tick0, tick1, dt) while Algebra's is (dt, tick0, tick1, avgTick0,
///      avgTick1). Mis-wiring the harness's re-order to Algebra's order makes the two sides
///      disagree on this input. That mutant was APPLIED and OBSERVED RED, then restored to green
///      (recorded in 08-02-SUMMARY.md) -- this probe is not merely asserted to be falsifiable.
///
/// @dev WHAT THIS DOES NOT DO. It is a SINGLE POINT, not the fuzz. VDIFF-02 / Phase 9 owns the
///      5-D fuzz over (dt, tick0, tick1, avgTick0, avgTick1). Agreement here is a wiring proof
///      and a necessary precondition -- not evidence of bit-exactness across the domain.
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
        plk = IPlankVolKernel(deployPlank("test/market_state_measurements/RealizedVolatilityKernelHarness.plk"));
    }

    function test__unit__kernelProbeAlgebraEqualsPlankNonDegenerate() public {
        uint256 got = plk.volatilityOnRange(DT, TICK0, TICK1, AVG_TICK0, AVG_TICK1);
        uint256 exp = mock.volatilityOnRange(DT, TICK0, TICK1, AVG_TICK0, AVG_TICK1);

        // THE differential assertion: exact agreement, no tolerance.
        assertEq(got, exp, "kernel: plank vs algebra, tolerance 0");

        // The independent anchor: pins Algebra's kernel to a hand-computed value, so a mock that
        // returns Plank's answer by accident cannot pass.
        assertEq(exp, EXPECTED_VOL, "algebra kernel vs hand-computed anchor");

        // Guards a future edit that flattens the input to a constant path (k=0, b=0 => vol=0),
        // which would make the assertion above pass vacuously.
        assertTrue(exp != 0, "probe must be non-degenerate");
    }
}
