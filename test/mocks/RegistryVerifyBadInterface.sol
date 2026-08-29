// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev Always rejects supportsInterface — for V4/Algebra negative tests.
contract RegistryVerifyBadInterface {
    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }
}
