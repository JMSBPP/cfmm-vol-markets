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
import {TickCheat} from "./TickCheat.sol";

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

    /// forge-config: default.fuzz.runs = 256
    function testFuzz_setTick_slot0ConsistentAndFeesPreserved(int24 t) public {
        // MAX_TICK excluded: price domain is half-open, tick == MAX_TICK is unreachable
        // for a real pool and getTickAtSqrtPrice reverts at MAX_SQRT_PRICE.
        t = int24(bound(int256(t), int256(TickMath.MIN_TICK), int256(TickMath.MAX_TICK - 1)));

        TickCheat.setTick(vm, IPoolManager(address(manager)), hook, t);

        assertEq(hook.readTick(), t, "tick");
        assertEq(hook.readSqrtPriceX96(), TickMath.getSqrtPriceAtTick(t), "sqrtPrice");
        // Round-trip: the imposed slot0 is a price a real pool could hold.
        assertEq(TickMath.getTickAtSqrtPrice(hook.readSqrtPriceX96()), t, "round-trip");

        // vm.load is the independent oracle: it bypasses the extsload path entirely
        // (StateLibrary.getSlot0 would be circular -- same slot math, same extsload).
        bytes32 raw = vm.load(address(manager), hook.slot0Slot());
        assertEq(raw, Slot0.unwrap(hook.readSlot0()), "extsload vs vm.load");

        Slot0 slot0 = Slot0.wrap(raw);
        assertEq(slot0.protocolFee(), SEEDED_PROTOCOL_FEE, "protocolFee bits clobbered");
        assertEq(slot0.lpFee(), LP_FEE, "lpFee bits clobbered");
    }

    function test_packSlot0For_revertsOutOfBounds() public {
        vm.expectRevert(abi.encodeWithSelector(TickMath.InvalidTick.selector, TickMath.MAX_TICK + 1));
        hook.packSlot0For(TickMath.MAX_TICK + 1);
        vm.expectRevert(abi.encodeWithSelector(TickMath.InvalidTick.selector, TickMath.MIN_TICK - 1));
        hook.packSlot0For(TickMath.MIN_TICK - 1);
    }
}
