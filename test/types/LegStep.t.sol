// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

interface ILeg {
    function legStep(uint24 ts) external view returns (uint24);
}

/// @title LegStepTest
/// @notice Suite for {types/LegStep.plk} — LegStep(TickBucket(ts), ts) → (max − min) / ts.
contract LegStepTest is PlankTestBase {
    ILeg internal harness;

    function setUp() public {
        harness = ILeg(deployPlank("test/harness/types/LegStepHarness.plk"));
    }

    function test__unit__legStep_fromTickBucketSpacing() public view {
        uint24 ts = uint24(60);
        uint24 step = harness.legStep(ts);

        int256 spacing = int256(uint256(ts));
        int256 expectedMax = int256(uint256(type(uint24).max) / uint256(ts) * uint256(ts));
        int256 loRaw = -int256(uint256(type(uint24).max));
        int256 q = loRaw / spacing;
        if (loRaw % spacing != 0) {
            q -= 1;
        }
        int256 expectedMin = q * spacing;
        uint256 expectedStep = uint256(expectedMax - expectedMin) / uint256(ts);

        assertEq(uint256(step), expectedStep);
    }
}
