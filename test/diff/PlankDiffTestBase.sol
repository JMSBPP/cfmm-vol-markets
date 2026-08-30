// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "../PlankTestBase.sol";
import {DifferentialTest} from "@seaport/utils/DifferentialTest.sol";

/// @title PlankDiffTestBase
/// @notice Plank deploy roots (PlankTestBase) plus Seaport's stateless differential runner
///         (DifferentialTest). Per-suite `.diff.t.sol` files define FuzzArgs + Context and
///         inherit this instead of re-vendoring DifferentialTest.
abstract contract PlankDiffTestBase is PlankTestBase, DifferentialTest {
    uint256 internal diffComparisons;

    function _requireComparisonRan() internal view {
        assertGt(diffComparisons, 0, "non-vacuity: zero comparisons");
    }

    function _runDiff(function(bytes memory) external fn, bytes memory ctx) internal {
        try fn(ctx) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }
}
