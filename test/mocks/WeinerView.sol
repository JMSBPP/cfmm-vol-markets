// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice View-only Weiner.shock(dt, j) for History intro. dt ignored.
contract WeinerView {
    mapping(uint256 => uint256) public shocks;

    function set(uint256 j, uint256 dw) external {
        shocks[j] = dw;
    }

    function shock(uint256, uint256 j) external view returns (uint256) {
        return shocks[j];
    }
}
