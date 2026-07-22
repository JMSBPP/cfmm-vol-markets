// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "reactive-test-lib/base/ReactiveTest.sol";
import "reactive-test-lib/interfaces/IReactiveInterfaces.sol";
import {PlankTestBase} from "test/PlankTestBase.sol";

contract PanopticReactiveRealizedVolatilityModTest is ReactiveTest, PlankTestBase {
    address reactive_realized_vol;
    address callback_realized_vol;
    
    function setUp() public override {
	super.setUp();
	reactive_realized_vol = deployPlank("src/modules/protocol_integrations/ReactiveRealizedVolatilityMod.plk");
	callback_realized_vol = deployPlank("src/modules/protocol_integrations/CallbackRealizedVolatilityMod.plk");
	
    }

    function test__unit__panopticReactiveRealizedVolatilityStoreTimePointSuccess() public {
    }
   
}
