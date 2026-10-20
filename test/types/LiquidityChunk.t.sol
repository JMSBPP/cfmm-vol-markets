// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

interface ILiquidityChunk {
    error TickOutOfBounds();
    error TickNotAligned();
    error TicksMisordered();
    error ZeroLiquidity();

    function intro(uint256 rawTickSpacing, int24 tickLower, int24 tickUpper, uint128 liquidity)
        external
        view
        returns (uint24 tickSpacing, int24 lower, int24 upper, uint128 chunkLiquidity);
}

/// @dev Bulloak-generated names from LiquidityChunk.btt. Assertions filled.
contract LiquidityChunkIntroTest is PlankTestBase {
    ILiquidityChunk internal harness;

    function setUp() public {
        harness = ILiquidityChunk(deployPlank("test/harness/types/LiquidityChunkHarness.plk"));
    }

    function test_WhenTickSpacingIsZero() external {
        // it should normalize spacing to one
        (uint24 spacing, int24 lower, int24 upper, uint128 liquidity) = harness.intro(0, -1, 1, 1);
        assertEq(spacing, 1);
        assertEq(lower, -1);
        assertEq(upper, 1);
        assertEq(liquidity, 1);
    }

    function test_WhenTickSpacingIsGreaterThanTwoHundred() external {
        // it should normalize spacing to two hundred
        (uint24 spacing, int24 lower, int24 upper, uint128 liquidity) = harness.intro(201, -200, 200, 1);
        assertEq(spacing, 200);
        assertEq(lower, -200);
        assertEq(upper, 200);
        assertEq(liquidity, 1);
    }

    function test_WhenTheLowerTickIsBelowTheMinimumTick() external {
        // it should revert with TickOutOfBounds
        vm.expectRevert(ILiquidityChunk.TickOutOfBounds.selector);
        harness.intro(1, -887273, 1, 1);
    }

    function test_WhenTheUpperTickIsAboveTheMaximumTick() external {
        // it should revert with TickOutOfBounds
        vm.expectRevert(ILiquidityChunk.TickOutOfBounds.selector);
        harness.intro(1, -1, 887273, 1);
    }

    function test_WhenTheLowerTickIsNotAligned() external {
        // it should revert with TickNotAligned
        vm.expectRevert(ILiquidityChunk.TickNotAligned.selector);
        harness.intro(10, -101, 100, 1);
    }

    function test_WhenTheUpperTickIsNotAligned() external {
        // it should revert with TickNotAligned
        vm.expectRevert(ILiquidityChunk.TickNotAligned.selector);
        harness.intro(10, -100, 101, 1);
    }

    function test_WhenTheLowerTickEqualsTheUpperTick() external {
        // it should revert with TicksMisordered
        vm.expectRevert(ILiquidityChunk.TicksMisordered.selector);
        harness.intro(10, -100, -100, 1);
    }

    function test_WhenTheLowerTickIsGreaterThanTheUpperTick() external {
        // it should revert with TicksMisordered
        vm.expectRevert(ILiquidityChunk.TicksMisordered.selector);
        harness.intro(10, 100, -100, 1);
    }

    function test_WhenLiquidityIsZero() external {
        // it should revert with ZeroLiquidity
        vm.expectRevert(ILiquidityChunk.ZeroLiquidity.selector);
        harness.intro(10, -100, 100, 0);
    }

    function test_WhenBothTicksAreInBoundsAndAlignedAndLiquidityIsPositive() external {
        // it should return the typed liquidity chunk
        (uint24 spacing, int24 lower, int24 upper, uint128 liquidity) = harness.intro(10, -100, 200, 123);
        assertEq(spacing, 10);
        assertEq(lower, -100);
        assertEq(upper, 200);
        assertEq(liquidity, 123);
    }
}
