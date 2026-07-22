// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {PoolKey} from "univ4-core/types/PoolKey.sol";
import {PoolId} from "univ4-core/types/PoolId.sol";
import {Slot0, Slot0Library} from "univ4-core/types/Slot0.sol";
import {StateLibrary} from "univ4-core/libraries/StateLibrary.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";

// @note: This is not production code, but experimentation only
/// @notice Bound to exactly one v4 pool. Discovers and self-verifies the storage slot of
/// that pool's slot0 inside PoolManager
contract PriceSetterHook {
    using Slot0Library for Slot0;

    IPoolManager public immutable poolManager;
    PoolId public poolId;
    bytes32 public slot0Slot;

    error NotPoolManager();
    error AlreadyBound();
    error NotBound();
    error WrongPool();
    error SlotVerificationFailed(int24 expected, int24 actual);

    modifier onlyPoolManager() { if (msg.sender != address(poolManager)) revert NotPoolManager();_;}

    modifier onlyBound() { if (slot0Slot == bytes32(0)) revert NotBound(); _;}

    constructor(IPoolManager _poolManager) { poolManager = _poolManager;}

    function beforeInitialize(address, PoolKey calldata poolKey, uint160)
        external
        onlyPoolManager
        returns (bytes4)
    {
        if (slot0Slot != bytes32(0)) revert AlreadyBound();
        PoolId id = poolKey.toId();
        poolId = id;
        slot0Slot = StateLibrary._getPoolStateSlot(id);
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata poolKey, uint160 sqrtPriceX96, int24 tick)
        external
        view
        onlyPoolManager
        returns (bytes4)
    {
        if (PoolId.unwrap(poolKey.toId()) != PoolId.unwrap(poolId)) revert WrongPool();
        Slot0 slot0 = readSlot0();
        if (slot0.tick() != tick || slot0.sqrtPriceX96() != sqrtPriceX96) {
            revert SlotVerificationFailed(tick, slot0.tick());
        }
        return IHooks.afterInitialize.selector;
    }

    function readSlot0() public view onlyBound returns (Slot0) {return Slot0.wrap(poolManager.extsload(slot0Slot));}

    function readTick() external view returns (int24) { return readSlot0().tick();}

    function readSqrtPriceX96() external view returns (uint160) { return readSlot0().sqrtPriceX96();}

    function packSlot0For(int24 newTick) external view returns (bytes32) {
        Slot0 current = readSlot0();
        uint160 newSqrtPriceX96 = TickMath.getSqrtPriceAtTick(newTick);
        return Slot0.unwrap(current.setTick(newTick).setSqrtPriceX96(newSqrtPriceX96));
    }
}
