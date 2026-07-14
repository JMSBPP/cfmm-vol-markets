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
    function getAverageVolatility(int24 tick, uint32 blockTimestamp) external view returns (uint88);
}

/// @title RealizedVolatilitySmokeTest
/// @notice Proves RealizedVolatilityMod.plk is deployable and its ABI dispatch is live.
///
// dev: This exists because `plank build` does NOT type-check code unreachable from run{}.
//      While the module's run{} was a bare stop, every function in it was dead code and the
//      compile gate was green on an EMPTY module. A passing `make compile-plank` proves
//      nothing on its own; only actually calling the thing does.
//
//      This is NOT the differential test -- it asserts only the degenerate properties that
//      must hold by construction. See .planning/plank-voldiff-plan.md.
contract RealizedVolatilitySmokeTest is PlankTestBase {
    IRealizedVolatility oracle;

    uint32 constant T0 = 1_000_000;
    uint32 constant DT = 30;

    function setUp() public {
        oracle = IRealizedVolatility(
            deployPlank("src/modules/market_state_measurements/RealizedVolatilityMod.plk")
        );
    }

    /// @notice One observation: the average tick over any lookback is that tick.
    function test__unit__singleObservationTwapEqualsTick() public {
        int24 tick = int24(200);
        oracle.initializeTWAP(T0, tick);
        assertEq(oracle.getTwapTick(DT, tick, T0 + DT), tick, "twap of a flat single obs must be the tick");
    }

    /// @notice NEGATIVE ticks. This is the case the old packing could not represent:
    ///         unpack masked with & 0xFFFFFF and never sign-extended, so a negative tick read
    ///         back as a large positive number.
    function test__unit__negativeTickRoundTrips() public {
        int24 tick = int24(-200);
        oracle.initializeTWAP(T0, tick);
        assertEq(oracle.getTwapTick(DT, tick, T0 + DT), tick, "negative tick must survive pack/unpack");
    }

    /// @notice A DOWNWARD tick move. This is the case that used to REVERT: the volatility
    ///         kernel used a checked `-` for (tick0 - avg_tick0), which underflows the moment
    ///         the tick sits below its trailing average.
    function test__unit__downwardTickMoveDoesNotRevert() public {
        oracle.initializeTWAP(T0, int24(500));
        oracle.writeTimepoint(T0 + DT, int24(100)); // strictly below the running average
        oracle.writeTimepoint(T0 + 2 * DT, int24(-300)); // and again, through zero
        int24 twap = oracle.getTwapTick(DT, int24(-300), T0 + 3 * DT);
        console2.log("twap after downward path:", twap);
    }

    /// @notice Constant tick across many writes -> the average is that tick.
    function test__fuzz__constantTickPathTwapEqualsTick(int24 _tick, uint8 _n) public {
        int24 tick = int24(bound(int256(_tick), -887272, 887272));
        uint256 n = bound(uint256(_n), 2, 40);

        oracle.initializeTWAP(T0, tick);
        for (uint256 i = 1; i <= n; i++) {
            oracle.writeTimepoint(uint32(T0 + i * DT), tick);
        }

        uint32 now_ = uint32(T0 + n * DT);
        uint32 lookback = uint32(n * DT);
        assertEq(oracle.getTwapTick(lookback, tick, now_), tick, "constant path must average to the tick");
    }

    /// @notice Both references reject dt == 0 (EVM SDIV by zero would otherwise return 0
    ///         SILENTLY, so Plank would answer 0 where Algebra and UniV3 revert).
    function test__unit__zeroPeriodReverts() public {
        oracle.initializeTWAP(T0, int24(200));
        vm.expectRevert();
        oracle.getTwapTick(0, int24(200), T0 + DT);
    }

    // notice: Double-init must revert. The old guard used EVM bitwise NOT on a bool, so
    //         NOT(0) and NOT(1) are both truthy and the guard could never fire.
    function test__unit__doubleInitReverts() public {
        oracle.initializeTWAP(T0, int24(200));
        vm.expectRevert();
        oracle.initializeTWAP(T0, int24(200));
    }
}
