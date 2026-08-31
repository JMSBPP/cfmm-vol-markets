// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankDiffTestBase} from "../diff/PlankDiffTestBase.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {FixedPoint96} from "@uniswap/v4-core/src/libraries/FixedPoint96.sol";
import {ShiftMode} from "bunni-v2/src/ldf/ShiftMode.sol";
import {LDFType} from "bunni-v2/src/types/LDFType.sol";
import {LibGeometricDistribution} from "bunni-v2/src/ldf/LibGeometricDistribution.sol";
import {ILiquidityDensityFunction} from "bunni-v2/src/interfaces/ILiquidityDensityFunction.sol";
import {GeometricDistributionTest} from "bunni-v2/test/ldf/GeometricDistribution.t.sol";
import {IPlankLiquidityDensityHarness} from "./LiquidityDensity.t.sol";

/// @dev Bunni reference — {GeometricDistributionTest}; forwards {ILiquidityDensityFunction} for Guarded.
contract BunniLDFOracle is GeometricDistributionTest, ILiquidityDensityFunction {
    function initHarness() public {
        _setUpLDF();
    }

    function query(
        PoolKey calldata key,
        int24 roundedTick,
        int24 twapTick,
        int24 spotPriceTick,
        bytes32 ldfParams,
        bytes32 ldfState
    )
        external
        view
        override
        returns (
            uint256 liquidityDensityX96,
            uint256 cumulativeAmount0DensityX96,
            uint256 cumulativeAmount1DensityX96,
            bytes32 newLdfState,
            bool shouldSurge
        )
    {
        return ldf.query(key, roundedTick, twapTick, spotPriceTick, ldfParams, ldfState);
    }

    function computeSwap(
        PoolKey calldata key,
        uint256 inverseCumulativeAmountInput,
        uint256 totalLiquidity,
        bool zeroForOne,
        bool exactIn,
        int24 twapTick,
        int24 spotPriceTick,
        bytes32 ldfParams,
        bytes32 ldfState
    )
        external
        view
        override
        returns (
            bool success,
            int24 roundedTick,
            uint256 cumulativeAmount0_,
            uint256 cumulativeAmount1_,
            uint256 swapLiquidity
        )
    {
        return ldf.computeSwap(
            key,
            inverseCumulativeAmountInput,
            totalLiquidity,
            zeroForOne,
            exactIn,
            twapTick,
            spotPriceTick,
            ldfParams,
            ldfState
        );
    }

    function cumulativeAmount0(
        PoolKey calldata key,
        int24 roundedTick,
        uint256 totalLiquidity,
        int24 twapTick,
        int24 spotPriceTick,
        bytes32 ldfParams,
        bytes32 ldfState
    ) external view override returns (uint256) {
        return ldf.cumulativeAmount0(key, roundedTick, totalLiquidity, twapTick, spotPriceTick, ldfParams, ldfState);
    }

    function cumulativeAmount1(
        PoolKey calldata key,
        int24 roundedTick,
        uint256 totalLiquidity,
        int24 twapTick,
        int24 spotPriceTick,
        bytes32 ldfParams,
        bytes32 ldfState
    ) external view override returns (uint256) {
        return ldf.cumulativeAmount1(key, roundedTick, totalLiquidity, twapTick, spotPriceTick, ldfParams, ldfState);
    }

    function isValidParams(PoolKey calldata key, uint24 twapSecondsAgo, bytes32 ldfParams, LDFType ldfType)
        external
        view
        override
        returns (bool)
    {
        return ldf.isValidParams(key, twapSecondsAgo, ldfParams, ldfType);
    }
}

/// @dev Plank oracle — {ILiquidityDensityFunction} adapter over {LiquidityDensityHarness.plk}.
contract PlankLDFOracle is ILiquidityDensityFunction {
    IPlankLiquidityDensityHarness internal immutable harness;

    constructor(address harness_) {
        harness = IPlankLiquidityDensityHarness(harness_);
    }

    function _decode(PoolKey calldata key, int24 twapTick, bytes32 ldfParams)
        internal
        pure
        returns (int24 minTick, int24 length)
    {
        uint256 alphaX96;
        ShiftMode shiftMode;
        (minTick, length, alphaX96, shiftMode) = LibGeometricDistribution.decodeParams(twapTick, key.tickSpacing, ldfParams);
    }

    function _targetForMid(int24 minTick, int24 midTick) internal pure returns (int256 tickLo, int256 tickHi) {
        tickLo = minTick;
        tickHi = int256(minTick) + 2 * (int256(midTick) - int256(minTick));
    }

    function query(
        PoolKey calldata key,
        int24 roundedTick,
        int24 twapTick,
        int24,
        bytes32 ldfParams,
        bytes32 ldfState
    )
        external
        view
        override
        returns (
            uint256 liquidityDensityX96,
            uint256 cumulativeAmount0DensityX96,
            uint256 cumulativeAmount1DensityX96,
            bytes32 newLdfState,
            bool shouldSurge
        )
    {
        (int24 minTick, int24 length) = _decode(key, twapTick, ldfParams);
        (int256 lo, int256 hi) = _targetForMid(minTick, roundedTick);
        liquidityDensityX96 = harness.ldfDensity(lo, hi, FixedPoint96.Q96, key.tickSpacing, uint256(int256(length)));
        cumulativeAmount0DensityX96 = _cum0(key, roundedTick + key.tickSpacing, FixedPoint96.Q96, twapTick, ldfParams);
        cumulativeAmount1DensityX96 = _cum1(key, roundedTick - key.tickSpacing, FixedPoint96.Q96, twapTick, ldfParams);
        newLdfState = ldfState;
        shouldSurge = false;
    }

    function computeSwap(
        PoolKey calldata key,
        uint256 inverseCumulativeAmountInput,
        uint256 totalLiquidity,
        bool zeroForOne,
        bool exactIn,
        int24 twapTick,
        int24,
        bytes32 ldfParams,
        bytes32
    )
        external
        view
        override
        returns (
            bool success,
            int24 roundedTick,
            uint256 cumulativeAmount0_,
            uint256 cumulativeAmount1_,
            uint256 swapLiquidity
        )
    {
        (int24 minTick, int24 length, uint256 alphaX96,) =
            LibGeometricDistribution.decodeParams(twapTick, key.tickSpacing, ldfParams);
        return LibGeometricDistribution.computeSwap(
            inverseCumulativeAmountInput,
            totalLiquidity,
            zeroForOne,
            exactIn,
            key.tickSpacing,
            minTick,
            length,
            alphaX96
        );
    }

    function cumulativeAmount0(
        PoolKey calldata key,
        int24 roundedTick,
        uint256 totalLiquidity,
        int24 twapTick,
        int24,
        bytes32 ldfParams,
        bytes32
    ) external view override returns (uint256) {
        return _cum0(key, roundedTick, totalLiquidity, twapTick, ldfParams);
    }

    function cumulativeAmount1(
        PoolKey calldata key,
        int24 roundedTick,
        uint256 totalLiquidity,
        int24 twapTick,
        int24,
        bytes32 ldfParams,
        bytes32
    ) external view override returns (uint256) {
        return _cum1(key, roundedTick, totalLiquidity, twapTick, ldfParams);
    }

    function isValidParams(PoolKey calldata key, uint24 twapSecondsAgo, bytes32 ldfParams, LDFType ldfType)
        external
        pure
        override
        returns (bool)
    {
        return LibGeometricDistribution.isValidParams(key.tickSpacing, twapSecondsAgo, ldfParams, ldfType);
    }

    function _cum0(PoolKey calldata key, int24 roundedTick, uint256 totalLiquidity, int24 twapTick, bytes32 ldfParams)
        internal
        view
        returns (uint256)
    {
        (int24 minTick, int24 length) = _decode(key, twapTick, ldfParams);
        (int256 lo, int256 hi) = _targetForMid(minTick, roundedTick);
        return harness.ldfCumulativeCollateral(
            lo, hi, totalLiquidity, key.tickSpacing, uint256(int256(minTick)), uint256(int256(length))
        );
    }

    function _cum1(PoolKey calldata key, int24 roundedTick, uint256 totalLiquidity, int24 twapTick, bytes32 ldfParams)
        internal
        view
        returns (uint256)
    {
        (int24 minTick, int24 length) = _decode(key, twapTick, ldfParams);
        (int256 lo, int256 hi) = _targetForMid(minTick, roundedTick);
        return harness.ldfCumulativeAsset(
            lo, hi, totalLiquidity, key.tickSpacing, uint256(int256(minTick)), uint256(int256(length))
        );
    }
}

/// @title LiquidityDensityDiffTest
/// @notice Differential: Bunni {GeometricDistribution} vs Plank {LiquidityDensityHarness} semantic path.
///
/// @dev Pattern from {VegaTargetDiffTest}: same `exec` twice with oracle swapped in `Context`,
///      then assertApproxEqAbs. α in ldfParams pinned to ξ* = getSqrtRatioAtTick(-Δ).
contract LiquidityDensityDiffTest is PlankDiffTestBase {
    // Bunni uint32 α vs Plank ξ*(tickSpacing) — ~1e-7 rel; percentDelta is 1e18-scaled.
    uint256 internal constant MAX_ERROR_CUM0 = 1e11;
    uint256 internal constant MAX_ERROR_CUM1 = 1e11;
    uint256 internal constant MAX_ERROR_DENSITY = 1e11;
    uint256 internal constant ALPHA_BASE = 1e8;
    bytes32 internal constant LDF_STATE = bytes32(0);

    ILiquidityDensityFunction internal bunni;
    ILiquidityDensityFunction internal plank;

    struct Context {
        ILiquidityDensityFunction oracle;
        PoolKey key;
        int24 roundedTick;
        uint256 totalLiquidity;
        bytes32 ldfParams;
    }

    function setUp() public {
        BunniLDFOracle bunniHarness = new BunniLDFOracle();
        bunniHarness.initHarness();
        bunni = bunniHarness;
        plank = new PlankLDFOracle(deployPlank("test/types/LiquidityDensityHarness.plk"));
    }

    function _ldfParams(int24 tickSpacing, int24 minTick, int24 length) internal pure returns (bytes32) {
        uint256 alphaX96 = TickMath.getSqrtRatioAtTick(-tickSpacing);
        uint32 alpha = uint32((alphaX96 * ALPHA_BASE) / FixedPoint96.Q96);
        return bytes32(abi.encodePacked(ShiftMode.STATIC, minTick, int16(length), alpha));
    }

    function _fixedContext(ILiquidityDensityFunction oracle) internal pure returns (Context memory ctx) {
        ctx.oracle = oracle;
        ctx.roundedTick = -50;
        ctx.totalLiquidity = 1e18;
        ctx.key.tickSpacing = 10;
        ctx.ldfParams = _ldfParams(ctx.key.tickSpacing, -100, 24);
    }

    function test(function(Context memory) external fn, Context memory context) internal {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function test_differential__Success_liquidityDensityX96_fixedFixture() public {
        Context memory ctx = _fixedContext(bunni);
        test(this.execLiquidityDensityX96, ctx);
        ctx.oracle = plank;
        test(this.execLiquidityDensityX96, ctx);
        _assertLiquidityDensityX96Eq(ctx);
        diffComparisons++;
        _requireComparisonRan();
    }

    function test_differential__Success_cumulativeAmount0_fixedFixture() public {
        Context memory ctx = _fixedContext(bunni);
        test(this.execCumulativeAmount0, ctx);
        ctx.oracle = plank;
        test(this.execCumulativeAmount0, ctx);
        _assertCumulativeAmount0Eq(ctx);
        diffComparisons++;
        _requireComparisonRan();
    }

    function test_differential__Success_cumulativeAmount1_fixedFixture() public {
        Context memory ctx = _fixedContext(bunni);
        test(this.execCumulativeAmount1, ctx);
        ctx.oracle = plank;
        test(this.execCumulativeAmount1, ctx);
        _assertCumulativeAmount1Eq(ctx);
        diffComparisons++;
        _requireComparisonRan();
    }

    function execLiquidityDensityX96(Context memory ctx) external stateless {
        (uint256 d,,,,) = ctx.oracle.query(ctx.key, ctx.roundedTick, 0, 0, ctx.ldfParams, LDF_STATE);
        assertGt(d, 0, "density must be in-support");
    }

    function execCumulativeAmount0(Context memory ctx) external stateless {
        uint256 a0 = ctx.oracle.cumulativeAmount0(
            ctx.key, ctx.roundedTick, ctx.totalLiquidity, 0, 0, ctx.ldfParams, LDF_STATE
        );
        assertGt(a0, 0, "cumulativeAmount0 must be positive in-support");
    }

    function execCumulativeAmount1(Context memory ctx) external stateless {
        uint256 a1 = ctx.oracle.cumulativeAmount1(
            ctx.key, ctx.roundedTick, ctx.totalLiquidity, 0, 0, ctx.ldfParams, LDF_STATE
        );
        assertGt(a1, 0, "cumulativeAmount1 must be positive in-support");
    }

    function _assertLiquidityDensityX96Eq(Context memory ctx) internal view {
        (uint256 b,,,,) = bunni.query(ctx.key, ctx.roundedTick, 0, 0, ctx.ldfParams, LDF_STATE);
        (uint256 p,,,,) = plank.query(ctx.key, ctx.roundedTick, 0, 0, ctx.ldfParams, LDF_STATE);
        assertApproxEqRel(b, p, MAX_ERROR_DENSITY, "liquidityDensityX96: Bunni vs Plank");
    }

    function _assertCumulativeAmount0Eq(Context memory ctx) internal view {
        uint256 b = bunni.cumulativeAmount0(
            ctx.key, ctx.roundedTick, ctx.totalLiquidity, 0, 0, ctx.ldfParams, LDF_STATE
        );
        uint256 p = plank.cumulativeAmount0(
            ctx.key, ctx.roundedTick, ctx.totalLiquidity, 0, 0, ctx.ldfParams, LDF_STATE
        );
        assertApproxEqRel(b, p, MAX_ERROR_CUM0, "cumulativeAmount0: Bunni vs Plank");
    }

    function _assertCumulativeAmount1Eq(Context memory ctx) internal view {
        uint256 b = bunni.cumulativeAmount1(
            ctx.key, ctx.roundedTick, ctx.totalLiquidity, 0, 0, ctx.ldfParams, LDF_STATE
        );
        uint256 p = plank.cumulativeAmount1(
            ctx.key, ctx.roundedTick, ctx.totalLiquidity, 0, 0, ctx.ldfParams, LDF_STATE
        );
        assertApproxEqRel(b, p, MAX_ERROR_CUM1, "cumulativeAmount1: Bunni vs Plank");
    }
}
