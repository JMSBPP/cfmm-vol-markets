// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {RegistryVerifyV4} from "../mocks/RegistryVerifyV4.sol";
import {Hooks} from "univ4-core/libraries/Hooks.sol";

/// @dev Deploy RegistryVerifyV4 at a CREATE2 address with valid v4 hook flag bits.
library MinedRegistryV4Deployer {
    uint160 internal constant FLAG_MASK = Hooks.ALL_HOOK_MASK;

    function deploy(address deployer, address poolManager) internal returns (address registry) {
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        bytes memory creationCode =
            abi.encodePacked(type(RegistryVerifyV4).creationCode, abi.encode(poolManager));

        for (uint256 i; i < 200_000; i++) {
            bytes32 salt = bytes32(i);
            address predicted = _computeCreate2(deployer, salt, creationCode);
            if (uint160(predicted) & FLAG_MASK == flags && predicted.code.length == 0) {
                return address(new RegistryVerifyV4{salt: salt}(poolManager));
            }
        }
        revert("MinedRegistryV4Deployer: no salt");
    }

    function _computeCreate2(address deployer, bytes32 salt, bytes memory creationCode)
        private
        pure
        returns (address)
    {
        return address(
            uint160(
                uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(creationCode))))
            )
        );
    }
}
