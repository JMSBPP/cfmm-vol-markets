// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Hooks, IHooks} from "v4-core/libraries/Hooks.sol";

using Hooks for IHooks;

/// Exact flag mask: AFTER_ADD_LIQUIDITY + AFTER_SWAP (each with RETURNS_DELTA).
/// Loose `hasPermission` alone can mine returns-delta bits without their action
/// flags → PoolManager HookAddressNotValid.
function NoFeeVarianceClaimBuilderPermissions(address addr) pure returns (bool) {
    return uint160(addr) & Hooks.ALL_HOOK_MASK
        == Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG
            | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
}
