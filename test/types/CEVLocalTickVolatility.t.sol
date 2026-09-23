// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {IntegralPoolBootstrap} from "test/helpers/Algebra/IntegralPoolBootstrap.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";
import {IAlgebraPoolState} from "@cryptoalgebra/integral-core/interfaces/pool/IAlgebraPoolState.sol";

interface ICEVLocalTickVolatility {
    error ZeroLiquidity();
    error ZeroSqrtPrice();
    error SigmaOverflowU88();

    function introFromState(
        uint256 sigmaF,
        uint256 chunkTickSpacing,
        uint256 packedChunk,
        address pool,
        uint256 fee,
        uint256 poolTickSpacing,
        uint256 tInit,
        uint256 k,
        uint256 j
    ) external view returns (bool ok, uint256 tick, uint256 sig);

    function introMalformed(uint256 sigmaF, uint256 liquidity, uint256 tick, uint256 sqrtP)
        external
        view
        returns (uint256 tickOut, uint256 sig);
}

/// @dev Bulloak-generated names from CEVLocalTickVolatility.btt. Assertions filled.
contract CEVLocalTickVolatilityTest is PlankTestBase {
    ICEVLocalTickVolatility internal harness;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant Q96 = 2 ** 96;
    uint256 internal constant LN_10001 = 99995000333308000000000;

    function setUp() public {
        harness = ICEVLocalTickVolatility(deployPlank("test/harness/types/CEVLocalTickVolatilityHarness.plk"));
    }

    function test_WhenChunkLiquidityIsZero() external {
        // it should revert ZeroLiquidity
        vm.expectRevert(ICEVLocalTickVolatility.ZeroLiquidity.selector);
        harness.introMalformed(RAY, 0, 0, Q96);
    }

    function test_WhenChunkLiquidityIsNonzeroAndObservationSqrt_pIsZero() external {
        // it should revert ZeroSqrtPrice
        vm.expectRevert(ICEVLocalTickVolatility.ZeroSqrtPrice.selector);
        harness.introMalformed(RAY, 10, 0, 0);
    }

    function test_WhenTypedInputsAreNonzeroAndSigmaOverflowsU88() external {
        // it should revert SigmaOverflowU88
        vm.expectRevert(ICEVLocalTickVolatility.SigmaOverflowU88.selector);
        harness.introMalformed(RAY, 1, TickMath.MIN_TICK, uint256(TickMath.MIN_SQRT_RATIO));
    }

    function test_WhenTypedInputsAreValidAndSigmaFitsU88() external {
        // it should return the observed tick and sigma
        IntegralPoolBootstrap.ReadyPool memory ready = IntegralPoolBootstrap.bootstrap(vm);
        uint128 liquidity = 10;
        uint256 packed = _pack(-60, 60, liquidity);
        (uint160 sqrtP, int24 observedTick,,,,) = IAlgebraPoolState(ready.pool).globalState();
        uint256 scaled = (RAY * Q96) / uint256(sqrtP);
        uint256 ratio = (scaled / liquidity) / LN_10001;

        (bool ok, uint256 tick, uint256 sig) = harness.introFromState(
            RAY,
            ready.tickSpacing,
            packed,
            ready.pool,
            ready.fee,
            ready.tickSpacing,
            block.timestamp,
            1,
            0
        );

        assertTrue(ok);
        assertEq(tick, uint256(int256(observedTick)));
        assertEq(sig, ratio * ratio);
    }

    function _pack(int24 lower, int24 upper, uint128 liquidity) private pure returns (uint256) {
        return (uint256(uint24(lower)) << 232) | (uint256(uint24(upper)) << 208) | uint256(liquidity);
    }
}
