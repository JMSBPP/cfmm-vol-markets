// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import  "@test/BaseTest.t.sol";
import {ReactiveTest} from "reactive-test-lib/base/ReactiveTest.sol";

contract SysAsCallbackTest is BaseTest, ReactiveTest {
    function setUp() public override(BaseTest, ReactiveTest) {
	BaseTest.setUp();
	ReactiveTest.setUp();
   }

    
    
}
