// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev transfer never reverts — pair_verify_erc20 must reject this token.
contract PairVerifyBadTransferERC20 {
    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return false;
    }
}
