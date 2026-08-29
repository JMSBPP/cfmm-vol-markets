// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev V4 registry stand-in: exposes hooks() and poolManager() for Plank registry reads.
contract RegistryVerifyV4 {
    address public immutable hooks;
    address public immutable poolManager;

    constructor(address hooks_, address poolManager_) {
        hooks = hooks_;
        poolManager = poolManager_;
    }
}
