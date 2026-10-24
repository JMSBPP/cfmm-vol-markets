// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

interface ITickRungTickBucketLib {
    function tickBucketFromRung(int256 tickVal, uint256 rawTickSpacing, uint24 step)
        external
        view
        returns (int256 minTick, int256 maxTick);
}

/// @title TickRungTickBucketLibTest
/// @notice Suite for {lib/types/TickRungTickBucketLib.plk} — tick_bucket(tick_rung(...)).
contract TickRungTickBucketLibTest is PlankTestBase {
    ITickRungTickBucketLib internal harness;

    function setUp() public {
        harness = ITickRungTickBucketLib(deployPlank("test/harness/lib/types/TickRungTickBucketLibHarness.plk"));
    }

    function test__unit__tickBucket_fromTickRung() public view {
        int256 tickVal = int256(100);
        uint256 rawTs = 60;
        uint24 step = 3;

        (int256 minTick, int256 maxTick) = harness.tickBucketFromRung(tickVal, rawTs, step);

        int256 spacing = int256(60);
        int256 q = tickVal / spacing;
        if (tickVal % spacing != 0 && tickVal < 0) {
            q -= 1;
        }
        int256 expectedMin = q * spacing;
        int256 expectedMax = expectedMin + int256(uint256(step)) * spacing;

        assertEq(minTick, expectedMin);
        assertEq(maxTick, expectedMax);
    }
}
