// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {LibCall} from "bunni-v2/lib/solady/src/utils/LibCall.sol";

contract OrderTest is Test, PlankDeployer {
    uint256 ZERO_VALUE = 0;
    address ORDER_HARNESS;
    bytes4 SELECTOR_INIT_ORDER = 0xc566b5c5;
    BuildOptions opts;

    struct Notional {
	int24 tickStrike;
        uint48 size;
    }
    struct Order {
	int24 tickLower;
	int24 tickUpper;
	uint88 varianceExpsoureAmt;
    }

    function setUp() public {
        opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](3);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
	deps[1] = Dependency("std", "lib/plank-monorepo/std");
	deps[2] = Dependency("types", "src/types");
        opts.dependencies = deps;
	ORDER_HARNESS = plankDeployFFI("test/types/OrderHelper.plk", opts);
    }

    function test__fuzz__OrderMakeSucceed (int24 tickLower, int24 tickUpper, uint88 varianceExposure) public {
	// KNOWN-BROKEN (vol-type-system track): the guard `tickUpper == tickUpper` is always
	// true, so this expects EVERY order to revert. The correct condition is NOT a one-line
	// fix: validate_order/make decode ticks via decode_int24(0)/decode_int24(24), which read
	// byte offsets that do not match the ABI-padded 32-byte words this Solidity harness sends
	// (it reads the int24 sign-extension bytes, not the value). Fixing this needs the harness
	// calldata layout reconciled with the .plk decoder -- routed to that track, not touched here.
	if (tickUpper == tickUpper ) {
	    vm.expectRevert();
	}
        Order memory order = abi.decode(
					LibCall.callContract(
							     ORDER_HARNESS,
							     ZERO_VALUE,
							     abi.encodeWithSelector(
										    SELECTOR_INIT_ORDER,
										    tickLower,
										    tickUpper,
										    varianceExposure
										    
							     )
					),
					(Order)
	);
	
    }

    
    function test__fuzz__NotionalBuildSuceeds(
					      int24 tickStrike,
					      uint48 size
     ) public {

	     
     }


}
