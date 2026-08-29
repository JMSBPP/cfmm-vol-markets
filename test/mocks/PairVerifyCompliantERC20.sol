// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @dev Minimal ERC20 for pair_verify_erc20 probes — OZ IERC20Errors custom errors.
contract PairVerifyCompliantERC20 {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256 bal = balanceOf[msg.sender];
        if (bal < amount) revert ERC20InsufficientBalance(msg.sender, bal, amount);
        unchecked {
            balanceOf[msg.sender] = bal - amount;
            balanceOf[to] += amount;
        }
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert ERC20InsufficientAllowance(msg.sender, allowed, amount);
        uint256 bal = balanceOf[from];
        if (bal < amount) revert ERC20InsufficientBalance(from, bal, amount);
        unchecked {
            allowance[from][msg.sender] = allowed - amount;
            balanceOf[from] = bal - amount;
            balanceOf[to] += amount;
        }
        return true;
    }
}
