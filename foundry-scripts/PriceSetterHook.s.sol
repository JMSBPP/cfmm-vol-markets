// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {PoolManager} from "univ4-core/PoolManager.sol";
import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {Hooks} from "univ4-core/libraries/Hooks.sol";
import {PoolKey} from "univ4-core/types/PoolKey.sol";
import {Currency} from "univ4-core/types/Currency.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";
import {HookMiner} from "utils/HookMiner.sol";
import {PriceSetterHook} from "../src/modules/protocol_integrations/reactive/PriceSetterHook.sol";

/// @notice Stands up a local tick-experiment rig: a PoolManager, a PriceSetterHook mined to a
/// flag-carrying address, and a pool bound to that hook. After `run()`, the printed
/// (poolManager, slot0Slot) pair is everything an off-chain stochastic driver needs to impose a
/// tick trajectory via setStorageAt; `set_tick` does exactly that write from here.
///
/// The pool is created with NO liquidity on purpose. A slot0 write does not maintain
/// liquidity/tickBitmap/feeGrowth state, so imposed ticks are only coherent for pools with no
/// liquidity or full-range-only liquidity -- see docs/superpowers/specs/2026-07-17-price-setter-hook-design.md.
contract PriceSetterHookScript is Script {
    string constant ANVIL_MNEMONIC = "test test test test test test test test test test test junk";
    uint256 constant DEPLOYER_INDEX = 0;

    /// @dev CREATE2 Deployer Proxy, pre-deployed on anvil. Mining targets this deployer because
    /// `new Hook{salt: ...}` under `vm.broadcast` is routed through it.
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    /// @dev The hook address must carry exactly these bits in its low 14, or
    /// PoolManager.initialize reverts with HookAddressNotValid.
    uint160 constant HOOK_FLAGS = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_INITIALIZE_FLAG);

    int24 constant INIT_TICK = 0;
    uint24 constant LP_FEE = 3000;
    int24 constant TICK_SPACING = 60;

    Vm.Wallet DEPLOYER;
    IPoolManager poolManager;
    PriceSetterHook priceSetterHook;
    PoolKey key;

    function run() public {
        uint256 deployerPk = vm.deriveKey(ANVIL_MNEMONIC, uint32(DEPLOYER_INDEX));
        DEPLOYER = vm.createWallet(deployerPk);

        bytes memory constructorArgs;
        address minedHook;
        bytes32 salt;

        vm.startBroadcast(DEPLOYER.privateKey);

        poolManager = IPoolManager(address(new PoolManager(DEPLOYER.addr)));

        constructorArgs = abi.encode(poolManager);
        (minedHook, salt) =
            HookMiner.find(CREATE2_DEPLOYER, HOOK_FLAGS, type(PriceSetterHook).creationCode, constructorArgs);

        priceSetterHook = new PriceSetterHook{salt: salt}(poolManager);
        require(address(priceSetterHook) == minedHook, "PriceSetterHookScript: hook address mismatch");

        // Binding happens here: beforeInitialize records the slot0 slot and afterInitialize
        // proves it against what Pool.initialize actually stored, so a pool that initializes
        // successfully is a pool whose slot0Slot is verified.
        key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(1)),
            fee: LP_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(minedHook)
        });
        poolManager.initialize(key, TickMath.getSqrtPriceAtTick(INIT_TICK));

        vm.stopBroadcast();

        console.log("PoolManager     :", address(poolManager));
        console.log("PriceSetterHook :", address(priceSetterHook));
        console.log("tick            :", vm.toString(priceSetterHook.readTick()));
        console.log("slot0Slot       :", vm.toString(priceSetterHook.slot0Slot()));
    }

    /// @notice Print the exact (PoolManager, slot, value) triple that imposes `newTick` on the
    /// pool bound to `hookAddress`. Feed it to a node that can write storage:
    ///
    ///   cast rpc --rpc-url local anvil_setStorageAt <PoolManager> <slot> <value>
    ///
    /// which is what `make set-tick TICK=<n>` runs, and what an off-chain stochastic driver
    /// issues per step.
    /// @dev Read-only by design. Doing the write in-script via
    /// `vm.rpc("anvil_setStorageAt", ...)` does apply it node-side, but forge then unwinds the
    /// script frame and exits non-zero -- a success that looks like a failure, which would be a
    /// trap for an automated driver. Read-only vm.rpc (e.g. eth_blockNumber) is unaffected.
    /// @dev Takes the hook address explicitly so it works in its own `forge script --sig` run,
    /// where `run()` has not populated the state variables.
    function tick_payload(address hookAddress, int24 newTick) external view {
        PriceSetterHook hook = PriceSetterHook(hookAddress);

        console.log("PoolManager     :", address(hook.poolManager()));
        console.log("tick            :", vm.toString(newTick));
        console.log("slot            :", vm.toString(hook.slot0Slot()));
        console.log("value           :", vm.toString(hook.packSlot0For(newTick)));
    }
}
