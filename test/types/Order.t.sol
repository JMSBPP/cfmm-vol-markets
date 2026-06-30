// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {LibCall} from "bunni-v2/lib/solady/src/utils/LibCall.sol";

contract OrderTest is Test {

    address ORDER_HARNESS;

    function setUp() public {
        opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](2);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
	deps[1] = Dependency("std", "lib/plank-monorepo/std");
        opts.dependencies = deps;
	ORDER_HARNESS = plankDeployFFI("test/types/OrderHelper.plk", opts);
    }

    function test__unit__OrderOfTicksEnforced () public {
	

    } 
}
