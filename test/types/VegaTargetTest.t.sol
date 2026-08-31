// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "../PlankTestBase.sol";
import {LiquidityChunkTest} from "panoptic-v2-core/test/foundry/types/LiquidityChunk.t.sol";

/// @title VegaTargetTest
/// @notice Plank-side unit suite for `VegaTarget` — scenario parity with {LiquidityChunkTest}.
///
/// @dev Inherits {PlankTestBase} for `deployPlank`. {LiquidityChunkTest}'s `setUp` and
///      `test_Success_*` are not `virtual`, so this contract mirrors those scenarios with the
///      Plank harness instead of `LiquidityChunkHarness`. The diff suite pairs this against a
///      deployed {LiquidityChunkTest} instance.
contract VegaTargetTest is PlankTestBase {
    IVegaTargetHarness public harness;

    function setUp() public {
        harness = IVegaTargetHarness(deployPlank("test/types/VegaTargetHarness.plk"));
    }

    function test_Success_AddLiq(uint128 y) public view {
        uint256 z = harness.vegaAmount(harness.addVegaAmount(harness.packEmpty(), y));
        assertEq(y, z);
    }

    function test_Success_TickLower(int24 y) public view {
        int256 z = harness.tickLower(harness.addTickLower(harness.packEmpty(), int256(y)));
        assertEq(int256(y), z);
    }

    function test_Success_TickUpper(int24 y) public view {
        int256 z = harness.tickUpper(harness.addTickUpper(harness.packEmpty(), int256(y)));
        assertEq(int256(y), z);
    }

    function test_Success_AddTicksLiquidity(int24 y, int24 z, uint128 u) public view {
        uint256 x = harness.packFromTicks(int256(y), int256(z), u);
        assertEq(harness.tickLower(x), int256(y));
        assertEq(harness.tickUpper(x), int256(z));
        assertEq(harness.vegaAmount(x), u);
    }

    function test_Success_updateTickLower(int24 y1, int24 y2) public view {
        uint256 x = harness.updateTickLower(harness.packEmpty(), int256(y1));
        assertEq(harness.tickLower(x), int256(y1));
        x = harness.updateTickLower(x, int256(y2));
        assertEq(harness.tickLower(x), int256(y2));
    }

    function test_Success_updateTickUpper(int24 y1, int24 y2) public view {
        uint256 x = harness.updateTickUpper(harness.packEmpty(), int256(y1));
        assertEq(harness.tickUpper(x), int256(y1));
        x = harness.updateTickUpper(x, int256(y2));
        assertEq(harness.tickUpper(x), int256(y2));
    }
}

interface IVegaTargetHarness {
    function packFromTicks(int256 tickLower, int256 tickUpper, uint256 amount) external view returns (uint256);
    function packEmpty() external view returns (uint256);
    function tickLower(uint256 packed) external view returns (int256);
    function tickUpper(uint256 packed) external view returns (int256);
    function vegaAmount(uint256 packed) external view returns (uint256);
    function addTickLower(uint256 packed, int256 tickLower) external view returns (uint256);
    function addTickUpper(uint256 packed, int256 tickUpper) external view returns (uint256);
    function addVegaAmount(uint256 packed, uint256 amount) external view returns (uint256);
    function updateTickLower(uint256 packed, int256 tickLower) external view returns (uint256);
    function updateTickUpper(uint256 packed, int256 tickUpper) external view returns (uint256);
}
