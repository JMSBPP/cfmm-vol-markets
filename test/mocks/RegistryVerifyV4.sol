// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "univ4-core/interfaces/IHooks.sol";

/// @dev V4 registry stand-in: IERC165 + IHooks on the registry itself, plus poolManager().
contract RegistryVerifyV4 {
    address public immutable poolManager;

    constructor(address poolManager_) {
        poolManager = poolManager_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IHooks).interfaceId;
    }
}
