// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {RegistryVerifyV4} from "../mocks/RegistryVerifyV4.sol";
import {HookMiner} from "../../lib/cfmm-types/lib/v4-hooks-public/src/utils/HookMiner.sol";
import {Hooks} from "univ4-core/libraries/Hooks.sol";

/// @dev Deploy RegistryVerifyV4 at a CREATE2 address with valid v4 hook flag bits.
library MinedRegistryV4Deployer {
    function deploy(address deployer, address poolManager) internal returns (address registry) {
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        bytes memory ctor = abi.encode(poolManager);
        (, bytes32 salt) = HookMiner.find(deployer, flags, type(RegistryVerifyV4).creationCode, ctor);
        registry = address(new RegistryVerifyV4{salt: salt}(poolManager));
    }
}
