// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

interface ILiquidityChunkUnpack {
    error ReservedBitsNonzero();
    error TickOutOfBounds();
    error TickNotAligned();
    error TicksMisordered();
    error ZeroLiquidity();

    function unpack(uint256 rawTickSpacing, uint256 packed)
        external
        view
        returns (uint24 tickSpacing, int24 lower, int24 upper, uint128 liquidity);
}

/// @dev Bulloak-generated names from LiquidityChunkUnpack.btt. Assertions filled.
contract LiquidityChunkUnpackTest is PlankTestBase {
    ILiquidityChunkUnpack internal harness;

    function setUp() public {
        harness = ILiquidityChunkUnpack(deployPlank("test/harness/types/LiquidityChunkHarness.plk"));
    }

    function test_WhenReservedBitsAreNonzero() external {
        // it should revert with ReservedBitsNonzero
        vm.expectRevert(ILiquidityChunkUnpack.ReservedBitsNonzero.selector);
        harness.unpack(10, _pack(-100, 100, 1) | (uint256(1) << 128));
    }

    function test_WhenAnUnpackedTickIsOutsideProtocolBounds() external {
        // it should revert with TickOutOfBounds
        vm.expectRevert(ILiquidityChunkUnpack.TickOutOfBounds.selector);
        harness.unpack(1, _pack(-887273, -887200, 1));
    }

    function test_WhenAnUnpackedTickIsNotAligned() external {
        // it should revert with TickNotAligned
        vm.expectRevert(ILiquidityChunkUnpack.TickNotAligned.selector);
        harness.unpack(10, _pack(-101, 100, 1));
    }

    function test_WhenUnpackedTicksAreMisordered() external {
        // it should revert with TicksMisordered
        vm.expectRevert(ILiquidityChunkUnpack.TicksMisordered.selector);
        harness.unpack(10, _pack(100, -100, 1));
    }

    function test_WhenUnpackedLiquidityIsZero() external {
        // it should revert with ZeroLiquidity
        vm.expectRevert(ILiquidityChunkUnpack.ZeroLiquidity.selector);
        harness.unpack(10, _pack(-100, 100, 0));
    }

    function test_WhenThePackedChunkIsValid() external {
        // it should sign extend both ticks
        // it should return the typed liquidity chunk
        uint128 expectedLiquidity = type(uint128).max;
        (uint24 spacing, int24 lower, int24 upper, uint128 liquidity) =
            harness.unpack(200, _pack(-200, 400, expectedLiquidity));

        assertEq(spacing, 200);
        assertEq(lower, -200);
        assertEq(upper, 400);
        assertEq(liquidity, expectedLiquidity);
    }

    function _pack(int24 lower, int24 upper, uint128 liquidity) private pure returns (uint256) {
        return (uint256(uint24(lower)) << 232) | (uint256(uint24(upper)) << 208) | uint256(liquidity);
    }
}
