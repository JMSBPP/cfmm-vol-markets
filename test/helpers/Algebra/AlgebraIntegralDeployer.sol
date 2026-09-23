// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";

/// @dev Deploy Algebra Integral factory + pool deployer + custom pool entry point from pinned
/// `.bytecode/algebra/*.bytecode` files (see `scripts/export-algebra-bytecode.sh`).
library AlgebraIntegralDeployer {
    struct Deployment {
        address factory;
        address poolDeployer;
        address entryPoint;
    }

    function deploy(Vm vm) internal returns (Deployment memory d) {
        bytes memory factoryCode = vm.parseBytes(vm.readFile(".bytecode/algebra/AlgebraFactory.bytecode"));
        bytes memory deployerCode = vm.parseBytes(vm.readFile(".bytecode/algebra/AlgebraPoolDeployer.bytecode"));
        bytes memory entryCode = vm.parseBytes(vm.readFile(".bytecode/algebra/AlgebraCustomPoolEntryPoint.bytecode"));

        uint256 nonce = vm.getNonce(address(this));
        address predictedFactory = vm.computeCreateAddress(address(this), nonce);
        address predictedPoolDeployer = vm.computeCreateAddress(address(this), nonce + 1);

        d.factory = _create(abi.encodePacked(factoryCode, abi.encode(predictedPoolDeployer)));
        require(d.factory == predictedFactory, "factory address mismatch");

        d.poolDeployer = _create(abi.encodePacked(deployerCode, abi.encode(d.factory)));
        require(d.poolDeployer == predictedPoolDeployer, "poolDeployer address mismatch");

        d.entryPoint = _create(abi.encodePacked(entryCode, abi.encode(d.factory)));
        require(d.entryPoint != address(0), "entryPoint deploy failed");
    }

    function _create(bytes memory initCode) private returns (address deployed) {
        assembly {
            deployed := create(0, add(initCode, 0x20), mload(initCode))
        }
    }
}
