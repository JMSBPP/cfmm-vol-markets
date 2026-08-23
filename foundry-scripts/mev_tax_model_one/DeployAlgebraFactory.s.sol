// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";

contract DeployAlgebraFactoryScript is Script {
    address public algebra_factory;	    
    address public algebra_deployer;
    
    function run() public{
	bytes memory algebra_factory_creation_code = vm.parseBytes(vm.readFile("foundry-scripts/mev_tax_model_one/bytecode/algebra_factory_creation_code.hex"));
	bytes memory algebra_deployer_creation_code = vm.parseBytes(vm.readFile("foundry-scripts/mev_tax_model_one/bytecode/algebra_deployer_creation_code.hex"));
    uint64 nonce = vm.getNonce(address(this));

    address predictedFactory = vm.computeCreateAddress(address(this), nonce);

    address predictedPoolDeployer = vm.computeCreateAddress(address(this), nonce + 1);

    bytes memory factoryInitCode = abi.encodePacked(
        algebra_factory_creation_code,
        abi.encode(predictedPoolDeployer)
    );

    address factory;

    assembly {
        factory := create(
            0,
            add(factoryInitCode, 0x20),
            mload(factoryInitCode)
        )
    }

    require(factory != address(0), "Factory deployment failed");
    require(factory == predictedFactory, "Factory address mismatch");

    bytes memory poolDeployerInitCode = abi.encodePacked(
        algebra_deployer_creation_code,
        abi.encode(factory)
    );

    address poolDeployer;

    assembly {
        poolDeployer := create(
            0,
            add(poolDeployerInitCode, 0x20),
            mload(poolDeployerInitCode)
        )
    }

    require(poolDeployer != address(0), "PoolDeployer deployment failed");
    require(
        poolDeployer == predictedPoolDeployer,
        "PoolDeployer address mismatch"
    );

    algebra_factory = factory;
    algebra_deployer = poolDeployer;
	
    }
}
