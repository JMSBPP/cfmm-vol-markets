// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// PROTOCOL REF: import {RegistryVerifyV4} from "../mocks/RegistryVerifyV4.sol";
// PROTOCOL REF: import {Hooks} from "univ4-core/libraries/Hooks.sol";

/// @dev Mine-deploy RegistryVerifyV4 via cfmm-types `Hook.plk` (`mineAndDeployHook`).

// Protocol-dependent body parked. See .ref/protocol_references.ref.
// Restore remaps + uncomment to compile against those GitHub pins.
// library MinedRegistryV4Deployer {
//     function deploy(address hookMiner, address poolManager) internal returns (address registry) {
//         (bool ok, bytes memory r) = hookMiner.call(
//             abi.encodeWithSignature(
//                 "mineAndDeployHook(uint256,bytes,bytes)",
//                 uint256(uint160(Hooks.BEFORE_SWAP_FLAG)),
//                 type(RegistryVerifyV4).creationCode,
//                 abi.encode(poolManager)
//             )
//         );
//         require(ok, "Hook.plk mineAndDeployHook reverted");
//         (registry,) = abi.decode(r, (address, uint256));
//     }
// }

library MinedRegistryV4Deployer {}
