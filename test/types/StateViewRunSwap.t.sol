// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {AlgebraSwapStub} from "test/mocks/AlgebraSwapStub.sol";

interface IStateViewRunSwap {
    function runSwap(
        address pool,
        uint256 fee,
        uint256 tickSpacing,
        uint256 amount,
        uint256 dir,
        address token,
        address from,
        address to,
        uint256 binJ
    ) external returns (bool ok);
}

/// @dev Bulloak-generated names from StateViewRunSwap.btt. Assertions filled.
contract StateViewRunSwapTest is PlankTestBase {
    IStateViewRunSwap internal harness;
    AlgebraSwapStub internal stub;

    uint256 internal constant FEE = 500;
    uint256 internal constant TICK_SPACING = 60;
    address internal constant TOKEN = address(0x7000);
    address internal constant FROM = address(0xA11CE);
    address internal constant TO = address(0xB0B);

    function setUp() public {
        harness = IStateViewRunSwap(deployPlank("test/harness/types/StateViewHarness.plk"));
        stub = new AlgebraSwapStub();
    }

    function test_WhenPoolAddressIsZero() external {
        // it should return run_swap None
        bool ok = harness.runSwap(address(0), FEE, TICK_SPACING, 100, 0, TOKEN, FROM, TO, 0);
        assertFalse(ok);
    }

    function test_WhenFlowAmountIsZero() external {
        // it should return run_swap None
        bool ok = harness.runSwap(address(stub), FEE, TICK_SPACING, 0, 0, TOKEN, FROM, TO, 0);
        assertFalse(ok);
    }

    function test_WhenSwapCallFails() external {
        // it should return run_swap None
        stub.setFailNext(true);
        bool ok = harness.runSwap(address(stub), FEE, TICK_SPACING, 100, 0, TOKEN, FROM, TO, 1);
        assertFalse(ok);
    }

    function test_WhenSwapCallSucceeds() external {
        // it should return run_swap Some
        bool ok = harness.runSwap(address(stub), FEE, TICK_SPACING, 100, 0, TOKEN, FROM, TO, 1);
        assertTrue(ok);
    }
}
