// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev transferFrom reverts with a non-ERC20 selector — pair_verify_erc20 must reject.
contract PairVerifyBadAllowanceERC20 {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error WrongAllowanceError();

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }

    function transfer(address, uint256 amount) external view returns (bool) {
        revert ERC20InsufficientBalance(address(this), 0, amount);
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert WrongAllowanceError();
    }
}
