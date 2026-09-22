// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 *
 * TokenFlow surface: Transfer Mod + Data.balanceOf. Approve, Mint,
 * totalSupply, and allowance are not used.
 */

import "@perfect-abstractions/compose/token/ERC20/Transfer/ERC20TransferMod.sol" as TransferMod;

contract FlowToken {
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        return TransferMod.transferFrom(_from, _to, _value);
    }

    function balanceOf(address _account) external view returns (uint256) {
        return TransferMod.getStorage().balanceOf[_account];
    }
}
