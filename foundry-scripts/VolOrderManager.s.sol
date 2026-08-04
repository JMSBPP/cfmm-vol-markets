// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";


interface IVolOrderManager{
    event OrderCreated(address indexed owner, uint32 indexed timestamp, bytes encodedVolOrder);
    function create_order(uint88,uint24,uint16) external;
}
contract VolOrderManagerScript is Script, PlankDeployer {

    string constant ANVIL_MNEMONIC = "test test test test test test test test test test test junk";
    uint256 constant DEPLOYER_INDEX = 0;
    Vm.Wallet DEPLOYER;
    BuildOptions opts;
    IVolOrderManager volOrderManager;
    
    function run() public {
	opts.backend = "sona";

	// Same six module roots as test/PlankTestBase.sol:plankOpts() -- keep in
	// sync with Makefile:PLANK_DEP. The pos_spec module imports pos_spec::/
	// lib::/types::, which the old two-root set cannot resolve.
	Dependency[] memory deps = new Dependency[](6);
	deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
	deps[1] = Dependency("std", "lib/plank-monorepo/std/");
	deps[2] = Dependency("pos_spec", "src/types/pos_spec");
	deps[3] = Dependency("lib", "src/lib");
	deps[4] = Dependency("types", "src/types");
	deps[5] = Dependency("interfaces", "src/interfaces");
	opts.dependencies = deps;

	uint256 deployerPk = vm.deriveKey(ANVIL_MNEMONIC, uint32(DEPLOYER_INDEX));
	DEPLOYER = vm.createWallet(deployerPk);

	vm.startBroadcast(DEPLOYER.privateKey);

	volOrderManager = IVolOrderManager(
					     plankDeployFFI(
							    "src/modules/pos_spec/VolOrderManagerMod.plk",
							    opts
					     ));

	vm.stopBroadcast();
    }

    function create_order(uint88 volTarget, uint24 volRangeWidth, uint16 skew) external {
	Vm.Wallet memory order_creator = vm.createWallet(vm.deriveKey(ANVIL_MNEMONIC, uint32(DEPLOYER_INDEX + 1)));
	vm.startBroadcast(order_creator.privateKey);
	volOrderManager.create_order(volTarget,volRangeWidth,skew);
	vm.stopBroadcast();
    }
}
