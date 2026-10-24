// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

interface IShock {
    function runShock(uint256 j) external returns (bool ok, uint256 pipsVal);
}

/// @dev Bulloak-generated names from ShockRunShock.btt. Assertions filled.
contract ShockRunShockTest is PlankTestBase {
    IShock internal harness;

    function setUp() public {
        harness = IShock(deployPlank("test/harness/types/ShockHarness.plk"));
    }

    function test_WhenTimestampAndPrevrandaoAreAvailable(uint256 prevrandaoSeed) external {
        // it should return Some with Pips in u16 range
        // it should yield different shocks across j
        vm.prevrandao(bytes32(prevrandaoSeed));
        uint256 t0 = block.timestamp;

        uint256[11] memory shocks;
        for (uint256 j = 0; j <= 10; j++) {
            vm.warp(t0 + j * 2);
            (bool ok, uint256 pips) = harness.runShock(j);
            assertTrue(ok);
            assertLt(pips, 65536);
            shocks[j] = pips;
        }

        for (uint256 a = 0; a <= 10; a++) {
            for (uint256 b = a + 1; b <= 10; b++) {
                assertTrue(shocks[a] != shocks[b], "shocks collide across j");
            }
        }
    }
}
