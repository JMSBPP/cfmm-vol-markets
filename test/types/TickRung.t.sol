// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

interface ITickRung {
    function tickRung(int256 tickVal, uint256 rawTickSpacing, uint24 step)
        external
        view
        returns (int256 i, int256 at);
}

/// @title TickRungTest
/// @notice Suite for sealed {types/TickRung.plk} — tick_rung → {i, at}.
contract TickRungTest is PlankTestBase {
    ITickRung internal harness;

    function setUp() public {
        harness = ITickRung(deployPlank("test/harness/types/TickRungHarness.plk"));
    }

    function test__unit__tickRung_fromTickAndStep() public view {
        int256 tickVal = int256(100);
        uint256 rawTs = 60;
        uint24 step = 3;

        (int256 i, int256 at) = harness.tickRung(tickVal, rawTs, step);

        int256 spacing = int256(60);
        int256 q = tickVal / spacing;
        if (tickVal % spacing != 0 && tickVal < 0) {
            q -= 1;
        }
        int256 expectedI = q * spacing;
        int256 expectedAt = expectedI + int256(uint256(step)) * spacing;

        assertEq(i, expectedI);
        assertEq(at, expectedAt);
    }
}
