// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {VolOrderManagerScript} from "scripts/VolOrderManager.s.sol";

contract VolOrderManagerFuzzTest is Test {
    VolOrderManagerScript volOrderManagerScript;

    function setUp() public {
	volOrderManagerScript = new VolOrderManagerScript();
	volOrderManagerScript.run();
    }

    function test__fuzz__logCreateOrder(uint88 volTarget, uint24 rangeWidth, uint16 skew) public {
	volOrderManagerScript.create_order(volTarget,rangeWidth,skew);
    }
}
