// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {PoolKey} from "univ4-core/types/PoolKey.sol";
import {PoolId} from "univ4-core/types/PoolId.sol";
import {Slot0, Slot0Library} from "univ4-core/types/Slot0.sol";
import {StateLibrary} from "univ4-core/libraries/StateLibrary.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";

/// @notice Bound to exactly one v4 pool. Discovers and self-verifies the storage slot of
/// that pool's slot0 inside PoolManager so an off-chain party on a LOCAL DEV NODE can
/// impose a tick trajectory via setStorageAt. The hook itself cannot write PoolManager
/// storage on-chain; it is the trusted source of WHERE to write and WHAT value:
///
///   setStorageAt(address(poolManager), hook.slot0Slot(), hook.packSlot0For(tick))
///
/// packSlot0For keeps tick and sqrtPriceX96 consistent and preserves the fee bits, so
/// slot0-based reads stay coherent. Liquidity structures (liquidity, tickBitmap, ticks,
/// feeGrowthGlobal) are NOT maintained: only use pools with no liquidity or with
/// full-range-only liquidity, so an imposed tick never crosses an initialized tick.
///
/// The hook address must carry BEFORE_INITIALIZE_FLAG (1 << 13) and
/// AFTER_INITIALIZE_FLAG (1 << 12).
contract PriceSetterHook {
    using Slot0Library for Slot0;

    IPoolManager public immutable poolManager;

    /// @notice The bound pool. Set once in beforeInitialize.
    PoolId public poolId;
    /// @notice Verified storage slot of the bound pool's slot0 inside PoolManager.
    /// slot0Slot == 0 <=> unbound (keccak256 output is never zero in practice).
    bytes32 public slot0Slot;

    error NotPoolManager();
    error AlreadyBound();
    error NotBound();
    error WrongPool();
    error SlotVerificationFailed(int24 expected, int24 actual);

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    modifier onlyBound() {
        if (slot0Slot == bytes32(0)) revert NotBound();
        _;
    }

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    /// @notice Binds this hook to the first pool initialized with it (one pool per instance).
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

    /// @notice Cross-checks the recorded slot against the values Pool.initialize actually
    /// stored. A wrong slot computation aborts pool creation, so a successfully bound
    /// hook is a proven slot.
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

    /// @notice Raw slot0 of the bound pool, read through PoolManager.extsload.
    function readSlot0() public view onlyBound returns (Slot0) {
        return Slot0.wrap(poolManager.extsload(slot0Slot));
    }

    function readTick() external view returns (int24) {
        return readSlot0().tick();
    }

    function readSqrtPriceX96() external view returns (uint160) {
        return readSlot0().sqrtPriceX96();
    }

    /// @notice The exact bytes32 an off-chain party writes at slot0Slot to impose newTick:
    /// current slot0 with tick := newTick, sqrtPriceX96 := getSqrtPriceAtTick(newTick)
    /// (reverts InvalidTick outside [MIN_TICK, MAX_TICK]), fee bits preserved.
    function packSlot0For(int24 newTick) external view returns (bytes32) {
        Slot0 current = readSlot0();
        uint160 newSqrtPriceX96 = TickMath.getSqrtPriceAtTick(newTick);
        return Slot0.unwrap(current.setTick(newTick).setSqrtPriceX96(newSqrtPriceX96));
    }
}
