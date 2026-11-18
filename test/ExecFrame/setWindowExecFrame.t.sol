// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import  "@test/BaseTest.t.sol";
import {DifferentialTest} from "@test/DifferentialTest.sol";
import {IWindow} from "@test/Window.t.sol";
import {ReactiveTest} from "reactive-test-lib/base/ReactiveTest.sol";

contract WindowExecFrameTest is DifferentialTest ,ReactiveTest {

    function setUp() public override(BaseTest, ReactiveTest) {
	BaseTest.setUp();
	ReactiveTest.setUp();
	
    }

    modifier whenSetWindowIsCalledWithWindowLenCalldata() {
        _;
    }

    function WhenSetWindowIsCalledWithWindowLenCalldata(Context memory ctx) external {
	// It should calculate WindowGasBudgetUpperBound
	// It should log if WindowLenCalldata exceeds WindowGasBudgetUpperBound
        // It should set windowIdx to zero in storage
        // It should set windowDelta to WindowCalldata in storage
        // It should set ExFrame state on Window to listening
        // It should subscribe to MarketKeyMarketId on the ReactiveNetwork

    }

    function test__fuzz__WhenSetWindowIsCalledWithWindowLenCalldata(FuzzInputsCommon memory args) external whenSetWindowIsCalledWithWindowLenCalldata {
       Context memory ctx = globalContext;

        
        IWindow(ctx.io).set_window(args.windowLen);
	test(
	     this.WhenSetWindowIsCalledWithWindowLenCalldata,
	     ctx
	);
    }

    function test_WhenWindowLenCalldataExceedsWindowGasBudgetUpperBound()
        external
        whenSetWindowIsCalledWithWindowLenCalldata
    {
        // It should set windowLen to WindowGasBudgetUpperBound in storage
    }

    function test_WhenWindowLenCalldataDoesNotExceedWindowGasBudgetUpperBound()
        external
        whenSetWindowIsCalledWithWindowLenCalldata
    {
        // It should set windowLen to WindowLenCalldata in storage
    }
}

