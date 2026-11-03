// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Hooks, IHooks} from "v4-core/libraries/Hooks.sol";

using Hooks for IHooks;

function NoFeeVarianceClaimBuilderPermissions(address addr) pure returns (bool) {
    return IHooks(addr).hasPermission(Hooks.AFTER_ADD_LIQUIDITY_FLAG);
}
