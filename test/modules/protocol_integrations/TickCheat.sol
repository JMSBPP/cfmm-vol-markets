// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {PriceSetterHook} from "../../../src/modules/protocol_integrations/PriceSetterHook.sol";

/// @notice Test-side twin of the off-chain write protocol:
/// setStorageAt(manager, hook.slot0Slot(), hook.packSlot0For(tick)) == vm.store(...).
library TickCheat {
    function setTick(Vm vm, IPoolManager manager, PriceSetterHook hook, int24 newTick) internal {
        vm.store(address(manager), hook.slot0Slot(), hook.packSlot0For(newTick));
    }
}
