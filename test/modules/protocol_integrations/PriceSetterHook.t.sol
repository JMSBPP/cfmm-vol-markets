// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PoolManager} from "univ4-core/PoolManager.sol";
import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {Hooks} from "univ4-core/libraries/Hooks.sol";
import {PoolKey} from "univ4-core/types/PoolKey.sol";
import {PoolId} from "univ4-core/types/PoolId.sol";
import {Currency} from "univ4-core/types/Currency.sol";
import {Slot0, Slot0Library} from "univ4-core/types/Slot0.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";
import {CustomRevert} from "univ4-core/libraries/CustomRevert.sol";
import {PriceSetterHook} from "../../../src/modules/protocol_integrations/PriceSetterHook.sol";

contract PriceSetterHookTest is Test {
    using Slot0Library for Slot0;

    PoolManager internal manager;
    PriceSetterHook internal hook;
    PoolKey internal key;

    // Namespaced flag address: only bits 13 (beforeInitialize) and 12 (afterInitialize)
    // of the low 14 are set; 0x4444 << 20 keeps it clear of precompiles.
    address internal constant HOOK_ADDRESS = address(
        uint160(0x4444 << 20) | uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_INITIALIZE_FLAG)
    );

    int24 internal constant INIT_TICK = 1000;
    uint24 internal constant LP_FEE = 3000;
    // (oneForZero = 500) << 12 | (zeroForOne = 400); both <= MAX_PROTOCOL_FEE (1000)
    uint24 internal constant SEEDED_PROTOCOL_FEE = uint24((500 << 12) | 400);

    function setUp() public {
        manager = new PoolManager(address(this));
        deployCodeTo(
            "src/modules/protocol_integrations/PriceSetterHook.sol:PriceSetterHook",
            abi.encode(IPoolManager(address(manager))),
            HOOK_ADDRESS
        );
        hook = PriceSetterHook(HOOK_ADDRESS);
        key = PoolKey({
            currency0: Currency.wrap(address(0x1111)),
            currency1: Currency.wrap(address(0x2222)),
            fee: LP_FEE,
            tickSpacing: 60,
            hooks: IHooks(HOOK_ADDRESS)
        });
        manager.initialize(key, TickMath.getSqrtPriceAtTick(INIT_TICK));
        // Seed nonzero protocolFee bits so fee-bit preservation is observable (initialize
        // leaves protocolFee = 0, and asserting 0 == 0 would be vacuous).
        manager.setProtocolFeeController(address(this));
        manager.setProtocolFee(key, SEEDED_PROTOCOL_FEE);
    }

    function test_binding_recordsPoolIdAndVerifiedSlot() public view {
        assertEq(PoolId.unwrap(hook.poolId()), PoolId.unwrap(key.toId()), "poolId mismatch");
        // Independent recomputation of the slot formula: _pools mapping sits at slot 6.
        bytes32 expectedSlot = keccak256(abi.encodePacked(PoolId.unwrap(key.toId()), uint256(6)));
        assertEq(hook.slot0Slot(), expectedSlot, "slot0Slot mismatch");
        assertTrue(hook.slot0Slot() != bytes32(0), "unbound");
    }

    function test_reads_matchInitializeValues() public view {
        assertEq(hook.readTick(), INIT_TICK, "tick");
        assertEq(hook.readSqrtPriceX96(), TickMath.getSqrtPriceAtTick(INIT_TICK), "sqrtPrice");
    }
}
