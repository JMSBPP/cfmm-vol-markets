// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

interface IStateViewIntroAnchor {
    error ZeroPool();

    function introAnchor(address pool, uint256 fee, uint256 tickSpacing)
        external
        returns (address poolOut, uint256 feeOut, uint256 tickSpacingOut, uint256 tInit);
}

/// @dev Bulloak-generated names from StateViewIntroAnchor.btt. Assertions filled.
contract StateViewIntroAnchorTest is PlankTestBase {
    IStateViewIntroAnchor internal harness;

    address internal constant POOL = address(0xB001);
    uint256 internal constant FEE = 500;
    uint256 internal constant TICK_SPACING = 60;

    function setUp() public {
        harness = IStateViewIntroAnchor(deployPlank("test/harness/types/StateViewHarness.plk"));
    }

    function test_WhenPoolAddressIsZero() external {
        // it should revert ZeroPool
        vm.expectRevert(IStateViewIntroAnchor.ZeroPool.selector);
        harness.introAnchor(address(0), FEE, TICK_SPACING);
    }

    function test_WhenPoolIsNonzero() external {
        // it should set t_init to block timestamp
        // it should return the same pool fee and tick spacing
        uint256 ts = block.timestamp;
        (address poolOut, uint256 feeOut, uint256 spacingOut, uint256 tInit) =
            harness.introAnchor(POOL, FEE, TICK_SPACING);
        assertEq(tInit, ts);
        assertEq(poolOut, POOL);
        assertEq(feeOut, FEE);
        assertEq(spacingOut, TICK_SPACING);
    }
}
