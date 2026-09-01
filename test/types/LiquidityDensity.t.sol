// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "../PlankTestBase.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {FixedPoint96} from "@uniswap/v4-core/src/libraries/FixedPoint96.sol";
import {SqrtPriceMath} from "bunni-v2/src/lib/SqrtPriceMath.sol";
import {ShiftMode} from "bunni-v2/src/ldf/ShiftMode.sol";
import {LDFType} from "bunni-v2/src/types/LDFType.sol";
import {LibGeometricDistribution} from "bunni-v2/src/ldf/LibGeometricDistribution.sol";
import {PoolKey} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import "../../lib/bunni-v2/src/lib/Math.sol";

/// @dev Plank semantic LDF harness — {LiquidityDensityHarness.plk}.
interface IPlankLiquidityDensityHarness {
    function ldfDensity(int256 tickLo, int256 tickHi, uint256 vega, int256 tickSpacing, uint256 iotaLength)
        external
        view
        returns (uint256 densityX96);
    function ldfCumulativeCollateral(
        int256 tickLo,
        int256 tickHi,
        uint256 vega,
        int256 tickSpacing,
        uint256 minTick,
        uint256 iotaLength
    ) external view returns (uint256 amount0);
    function ldfCumulativeAsset(
        int256 tickLo,
        int256 tickHi,
        uint256 vega,
        int256 tickSpacing,
        uint256 minTick,
        uint256 iotaLength
    ) external view returns (uint256 amount1);
}

/// @title LiquidityDensityTest
/// @notice Plank unit suite — scenario parity with bunni-v2 {GeometricLibTest} in-scope tests.
/// @dev Harness lifts VolMarketKey/VegaTarget/ξ* adaptation; swaps/inverse-cum/boundary deferred.
contract LiquidityDensityTest is PlankTestBase {
    using TickMath for int24;
    using FixedPointMathLib for uint256;

    uint256 internal constant MAX_ERROR = 1e7;
    uint256 internal constant MAX_ERROR_CUM0 = 1e9;
    uint256 internal constant MAX_ERROR_CUM1 = 1e9;
    int24 internal constant MAX_TICK_SPACING = type(int16).max;
    int24 internal constant MIN_TICK_SPACING = 1000;
    uint256 internal constant MIN_ABS_ERROR = 1000;
    uint256 internal constant ALPHA_BASE = 1e8;

    IPlankLiquidityDensityHarness internal harness;

    function setUp() public {
        harness = IPlankLiquidityDensityHarness(deployPlank("test/types/LiquidityDensityHarness.plk"));
    }

    function _ldfParams(int24 tickSpacing, int24 minTick, int24 length) internal pure returns (bytes32) {
        uint256 alphaX96 = uint256(TickMath.getSqrtPriceAtTick(-tickSpacing));
        uint32 alpha = uint32((alphaX96 * ALPHA_BASE) / FixedPoint96.Q96);
        return bytes32(abi.encodePacked(ShiftMode.STATIC, minTick, int16(length), alpha));
    }

    function _paramsValid(int24 tickSpacing, int24 minTick, int24 length) internal pure returns (bool) {
        PoolKey memory key;
        key.tickSpacing = tickSpacing;
        return LibGeometricDistribution.isValidParams(key.tickSpacing, 0, _ldfParams(tickSpacing, minTick, length), LDFType.STATIC);
    }

    function _tryCum0(int24 roundedTick, uint256 totalLiquidity, int24 tickSpacing, int24 minTick, int24 length)
        internal
        returns (bool ok, uint256 amount)
    {
        (int256 lo, int256 hi) = _targetForMid(minTick, roundedTick);
        try harness.ldfCumulativeCollateral(
            lo, hi, totalLiquidity, tickSpacing, uint256(int256(minTick)), uint256(int256(length))
        ) returns (uint256 r) {
            return (true, r);
        } catch {
            return (false, 0);
        }
    }

    function _tryCum1(int24 roundedTick, uint256 totalLiquidity, int24 tickSpacing, int24 minTick, int24 length)
        internal
        returns (bool ok, uint256 amount)
    {
        (int256 lo, int256 hi) = _targetForMid(minTick, roundedTick);
        try harness.ldfCumulativeAsset(
            lo, hi, totalLiquidity, tickSpacing, uint256(int256(minTick)), uint256(int256(length))
        ) returns (uint256 r) {
            return (true, r);
        } catch {
            return (false, 0);
        }
    }

    /// @dev tick_lo = minTick, mid_tick = midTick (liquidity_density_at uses tick_low as geo minTick).
    function _targetForMid(int24 minTick, int24 midTick) internal pure returns (int256 tickLo, int256 tickHi) {
        tickLo = minTick;
        tickHi = int256(minTick) + 2 * (int256(midTick) - int256(minTick));
    }

    function _densityAt(int24 roundedTick, int24 tickSpacing, int24 minTick, int24 length)
        internal
        view
        returns (uint256)
    {
        (int256 lo, int256 hi) = _targetForMid(minTick, roundedTick);
        return harness.ldfDensity(lo, hi, FixedPoint96.Q96, tickSpacing, uint256(int256(length)));
    }

    // --- mirrors GeometricLibTest.test_liquidityDensity_sumUpToOne ---

    function test_liquidityDensity_sumUpToOne(int24 tickSpacing, int24 minTick, int24 length) public view {
        tickSpacing = int24(bound(tickSpacing, MIN_TICK_SPACING, MAX_TICK_SPACING));
        (int24 minUsableTick, int24 maxTick) =
            (TickMath.minUsableTick(tickSpacing), TickMath.maxUsableTick(tickSpacing) - tickSpacing);
        minTick = roundTickSingle(int24(bound(minTick, minUsableTick, maxTick - 2 * tickSpacing)), tickSpacing);
        length = int24(bound(length, 1, (maxTick - minTick) / tickSpacing - 1));

        uint256 cumulativeLiquidityDensity;
        for (int24 tick = minUsableTick; tick <= maxTick; tick += tickSpacing) {
            cumulativeLiquidityDensity += _densityAt(tick, tickSpacing, minTick, length);
        }
        assertApproxEqRel(
            cumulativeLiquidityDensity, FixedPoint96.Q96, MAX_ERROR, "liquidity density doesn't add up to one"
        );
    }

    // --- mirrors GeometricLibTest.test_query_cumulativeAmounts / _test_query_cumulativeAmounts ---
    // Riemann oracle (Option A): sum _densityAt(t) × amountDensity(t) — same semantic path as
    // ldfDensity → liquidity_density_at; direct cum goes vega* → geometric_cumulative_*.

    function test_query_cumulativeAmounts(int24 currentTick, int24 tickSpacing, int24 minTick, int24 length) public {
        tickSpacing = int24(bound(tickSpacing, MIN_TICK_SPACING, MAX_TICK_SPACING));
        (int24 minUsableTick, int24 maxUsableTick) =
            (TickMath.minUsableTick(tickSpacing), TickMath.maxUsableTick(tickSpacing));
        minTick = roundTickSingle(int24(bound(minTick, minUsableTick, maxUsableTick - 2 * tickSpacing)), tickSpacing);
        length = int24(bound(length, 1, (maxUsableTick - minTick) / tickSpacing - 1));
        currentTick = int24(bound(currentTick, minUsableTick, maxUsableTick));
        if (!_paramsValid(tickSpacing, minTick, length)) return;

        int24 roundedTick = roundTickSingle(currentTick, tickSpacing);
        int24 cum0Tick = roundedTick + tickSpacing;
        int24 cum1Tick = roundedTick - tickSpacing;
        int24 supportHi = minTick + length * tickSpacing;
        if (cum0Tick < minTick || cum0Tick > supportHi) return;
        if (cum1Tick <= minTick || cum1Tick > supportHi) return;

        (bool ok0, uint256 cumulativeAmount0DensityX96) =
            _tryCum0(cum0Tick, FixedPoint96.Q96, tickSpacing, minTick, length);
        if (!ok0) return;
        (bool ok0b, uint256 cumulativeAmount0) = _tryCum0(cum0Tick, FixedPoint96.Q96, tickSpacing, minTick, length);
        if (!ok0b) return;
        assertEq(cumulativeAmount0, cumulativeAmount0DensityX96, "cumulativeAmount0 incorrect");

        (bool ok1, uint256 cumulativeAmount1DensityX96) =
            _tryCum1(cum1Tick, FixedPoint96.Q96, tickSpacing, minTick, length);
        if (!ok1) return;
        (bool ok1b, uint256 cumulativeAmount1) = _tryCum1(cum1Tick, FixedPoint96.Q96, tickSpacing, minTick, length);
        if (!ok1b) return;
        assertEq(cumulativeAmount1, cumulativeAmount1DensityX96, "cumulativeAmount1 incorrect");

        uint256 bruteForceAmount0X96 =
            _bruteForceCumulativeAmount0Density(cum0Tick, tickSpacing, minTick, length);
        uint256 bruteForceAmount1X96 =
            _bruteForceCumulativeAmount1Density(cum1Tick, tickSpacing, minTick, length);

        (, uint256 error0) = absDiff(cumulativeAmount0DensityX96, bruteForceAmount0X96);
        if (error0 > MIN_ABS_ERROR) {
            assertApproxEqRel(
                cumulativeAmount0DensityX96, bruteForceAmount0X96, MAX_ERROR_CUM0, "cumulativeAmount0DensityX96 incorrect"
            );
        }

        (, uint256 error1) = absDiff(cumulativeAmount1DensityX96, bruteForceAmount1X96);
        if (error1 > MIN_ABS_ERROR) {
            assertApproxEqRel(
                cumulativeAmount1DensityX96, bruteForceAmount1X96, MAX_ERROR_CUM1, "cumulativeAmount1DensityX96 incorrect"
            );
        }
    }

    function _bruteForceCumulativeAmount0Density(int24 roundedTick, int24 tickSpacing, int24 minTick, int24 length)
        internal
        view
        returns (uint256 cumulativeAmount0DensityX96)
    {
        int24 maxTick = TickMath.maxUsableTick(tickSpacing) - tickSpacing;
        for (int24 tick = roundedTick; tick <= maxTick; tick += tickSpacing) {
            uint256 liquidityDensityX96 = _densityAt(tick, tickSpacing, minTick, length);
            uint256 amount0DensityX96 = _amount0DensityX96(tick, tickSpacing);
            cumulativeAmount0DensityX96 += amount0DensityX96.fullMulDivUp(liquidityDensityX96, FixedPoint96.Q96);
        }
    }

    function _bruteForceCumulativeAmount1Density(int24 roundedTick, int24 tickSpacing, int24 minTick, int24 length)
        internal
        view
        returns (uint256 cumulativeAmount1DensityX96)
    {
        int24 minUsableTick = TickMath.minUsableTick(tickSpacing);
        for (int24 tick = minUsableTick; tick <= roundedTick; tick += tickSpacing) {
            uint256 liquidityDensityX96 = _densityAt(tick, tickSpacing, minTick, length);
            uint256 amount1DensityX96 = _amount1DensityX96(tick, tickSpacing);
            cumulativeAmount1DensityX96 += amount1DensityX96.fullMulDivUp(liquidityDensityX96, FixedPoint96.Q96);
        }
    }

    function _amount0DensityX96(int24 roundedTick, int24 tickSpacing) internal pure returns (uint256) {
        return SqrtPriceMath.getAmount0Delta(
            roundedTick.getSqrtPriceAtTick(), (roundedTick + tickSpacing).getSqrtPriceAtTick(), FixedPoint96.Q96, true
        );
    }

    function _amount1DensityX96(int24 roundedTick, int24 tickSpacing) internal pure returns (uint256) {
        return SqrtPriceMath.getAmount1Delta(
            roundedTick.getSqrtPriceAtTick(), (roundedTick + tickSpacing).getSqrtPriceAtTick(), FixedPoint96.Q96, true
        );
    }
}
