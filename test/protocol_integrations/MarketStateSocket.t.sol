// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ReactiveTest} from "reactive-test-lib/base/ReactiveTest.sol";
import {PlankTestBase} from "test/PlankTestBase.sol";

contract MarketStateSocketTest is PlankTestBase, ReactiveTest{
    // note: This necesarily is a fork test, we are monittring Base Uni v4 pool manager where there
    // is the deepest more active panoptic pool
    address market_state_socket;
    function setUp() public override {
        super.setUp();
	market_state_socket = deployPlank("src/modules/protocol_integrations/MarketStateSocket.plk");
    }
}
