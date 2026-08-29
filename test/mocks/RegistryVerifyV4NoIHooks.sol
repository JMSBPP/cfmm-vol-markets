// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev poolManager() without IERC165 / IHooks — must fail registry_verify(V4).
contract RegistryVerifyV4NoIHooks {
    address public immutable poolManager;

    constructor(address poolManager_) {
        poolManager = poolManager_;
    }
}
