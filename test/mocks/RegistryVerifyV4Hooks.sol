// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// PROTOCOL REF: import {IHooks} from "univ4-core/interfaces/IHooks.sol";

/// @dev V4 hooks stand-in: IERC165 + IHooks interface id (for registry_verify V4 probe).

// Protocol-dependent body parked. See .ref/protocol_references.ref.
// Restore remaps + uncomment to compile against those GitHub pins.
// contract RegistryVerifyV4Hooks {
//     function supportsInterface(bytes4 id) external pure returns (bool) {
//         return id == 0x01ffc9a7 || id == type(IHooks).interfaceId;
//     }
// }

contract RegistryVerifyV4Hooks {}
