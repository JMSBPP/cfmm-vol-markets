// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "@test/PlankTestBase.sol";
import {console2} from "forge-std/console2.sol";

uint256 constant REACTIVE_CHAIN_ID = 1597;

contract ReactiveCostTest is PlankTestBase {
    address reactiveCostTracking = makeAddr("cfmm-vol-markets.reactive-cost-tracking");
    function setUp() public {
	deployCodeTo(reactiveCostTracking, compilePlank("src/utils/protocol_integrations/ReactiveCost.plk"));
    }


    function test__unit__reactiveCost() external {
	vm.chainId(REACTIVE_CHAIN_ID);
	(bool ok, bytes memory res)= reactiveCostTracking.call(abi.encode(109942));
	if (ok) {
	    uint256 resCost = abi.decode(res, (uint256));
	    console2.log("Res Reactive Cost:", resCost);
	}
    }
}
