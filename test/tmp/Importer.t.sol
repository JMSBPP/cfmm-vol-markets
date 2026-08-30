// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankDiffTestBase} from "../diff/PlankDiffTestBase.sol";

/// @dev Smoke test: CI must init lib/seaport, resolve @seaport/, and link PlankDiffTestBase.
contract ImporterTest is PlankDiffTestBase {
    function test_importsPlankDiffTestBase() public view {
        assertTrue(PASSING_HASH != bytes32(0));
    }
}
