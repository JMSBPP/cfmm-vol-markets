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

    function test_WhenTimestampAndPrevrandaoAreAvailable() external {
        // it should return Some with Pips in u16 range
        // it should be deterministic for the same j and block env
        vm.warp(block.timestamp + 2);
        vm.prevrandao(bytes32(uint256(0xA11CE)));

        uint256 j = 7;
        (bool ok1, uint256 pips1) = harness.runShock(j);
        assertTrue(ok1);
        assertLt(pips1, 65536);

        (bool ok2, uint256 pips2) = harness.runShock(j);
        assertTrue(ok2);
        assertEq(pips2, pips1);
    }
}
