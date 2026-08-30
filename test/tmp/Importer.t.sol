// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {DifferentialTest} from "@seaport/utils/DifferentialTest.sol";

/// @dev Smoke test: CI must init lib/seaport and resolve @seaport/ remapping.
contract ImporterTest is DifferentialTest {
    function test_importsDifferentialTest() public view {
        assertTrue(PASSING_HASH != bytes32(0));
    }
}
