// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev Uniswap V3 factory fingerprint: `owner()` view succeeds (no IERC165).
contract RegistryVerifyV3Factory {
    function owner() external view returns (address) {
        return address(this);
    }
}
