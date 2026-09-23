// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

interface ILiquidityChunkPack {
    function pack(uint256 rawTickSpacing, int24 tickLower, int24 tickUpper, uint128 liquidity)
        external
        view
        returns (uint256);
}

/// @dev Bulloak-generated names from LiquidityChunkPack.btt. Assertions filled.
contract LiquidityChunkPackTest is PlankTestBase {
    ILiquidityChunkPack internal harness;

    function setUp() public {
        harness = ILiquidityChunkPack(deployPlank("test/harness/types/LiquidityChunkHarness.plk"));
    }

    function test_WhenAValidTypedChunkIsPacked() external {
        // it should place the lower tick in bits 255 through 232
        // it should place the upper tick in bits 231 through 208
        // it should leave bits 207 through 128 zero
        // it should place liquidity in bits 127 through zero
        int24 lower = -200;
        int24 upper = 400;
        uint128 liquidity = type(uint128).max;
        uint256 packed = harness.pack(200, lower, upper, liquidity);

        uint256 expected =
            (uint256(uint24(lower)) << 232) | (uint256(uint24(upper)) << 208) | uint256(liquidity);
        uint256 reservedMask = ((uint256(1) << 80) - 1) << 128;

        assertEq(packed, expected);
        assertEq(packed & reservedMask, 0);
    }
}
