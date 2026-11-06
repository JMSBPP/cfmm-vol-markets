// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

/// @dev Thin stand-in for SFPM.getCurrentTick (slot0.tick via StateLibrary), without compiling
///      SemiFungiblePositionManagerV4 (stack-too-deep / IR blow-up on the e502 v4-core pin).
contract CfmmTickLens {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    IPoolManager public immutable manager;

    constructor(IPoolManager manager_) {
        manager = manager_;
    }

    function getCurrentTick(bytes memory poolKey) external view returns (int24 currentTick) {
        PoolKey memory key = abi.decode(poolKey, (PoolKey));
        (, currentTick,,) = manager.getSlot0(key.toId());
    }
}
