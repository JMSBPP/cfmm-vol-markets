// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

interface IWeiner {
    function runWeiner(uint256 j) external returns (bool ok, uint256 deltaWVal);
}

/// @dev Bulloak-generated names from WeinerGeneratorRunWeiner.btt. Assertions filled.
/// Mirror ShockRunShock: fuzz prevrandao; warp t0+j*2; assert DeltaW differ across j.
contract WeinerGeneratorRunWeinerTest is PlankTestBase {
    IWeiner internal harness;

    function setUp() public {
        harness = IWeiner(deployPlank("test/harness/types/WeinerGeneratorHarness.plk"));
    }

    function test_WhenTimestampAndPrevrandaoAreAvailable(uint256 prevrandaoSeed) external {
        // it should return Some with Ray-scale DeltaW
        // it should yield different DeltaW across j
        vm.prevrandao(bytes32(prevrandaoSeed));
        uint256 t0 = block.timestamp;

        uint256[11] memory dws;
        for (uint256 j = 0; j <= 10; j++) {
            vm.warp(t0 + j * 2);
            (bool ok, uint256 dw) = harness.runWeiner(j);
            assertTrue(ok);
            dws[j] = dw;
        }

        for (uint256 a = 0; a <= 10; a++) {
            for (uint256 b = a + 1; b <= 10; b++) {
                assertTrue(dws[a] != dws[b], "DeltaW collide across j");
            }
        }
    }
}
