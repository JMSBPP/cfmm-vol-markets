// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {Vm} from "forge-std/Vm.sol";

contract DeployerScript is Script, PlankDeployer{
     BuildOptions opts;
     address public referenceContract;
     uint256 constant DEPLOYER_INDEX = 0;
     
     string constant ANVIL_MNEMONIC = "test test test test test test test test test test test junk";
    
     Vm.Wallet DEPLOYER;
     
     function run() public {
	 opts.backend = "sona";

	 Dependency[] memory deps = new Dependency[](2);
	 deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
	 deps[1] = Dependency("std", "lib/plank-monorepo/std");
	 opts.dependencies = deps;

	 uint256 deployerPk = vm.deriveKey(ANVIL_MNEMONIC, uint32(DEPLOYER_INDEX));
	 DEPLOYER = vm.createWallet(deployerPk);

	 vm.startBroadcast(DEPLOYER.privateKey);

	 referenceContract = plankDeployFFI(
					    "src/modules/VolOrderManagerMod.plk",
					    opts
	 );

	 vm.stopBroadcast();
     }
}
