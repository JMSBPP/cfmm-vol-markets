/***********************************************************************************************************************/
/* // SPDX-License-Identifier: MIT										       */
/* pragma solidity ^0.8.26;											       */
/* 														       */
/* import {Test} from "forge-std/Test.sol";									       */
/* import {PoolManager} from "univ4-core/PoolManager.sol";							       */
/* import {IPoolManager} from "univ4-core/interfaces/IPoolManager.sol";						       */
/* import {IHooks} from "univ4-core/interfaces/IHooks.sol";							       */
/* import {Hooks} from "univ4-core/libraries/Hooks.sol";							       */
/* import {PoolKey} from "univ4-core/types/PoolKey.sol";							       */
/* import {PoolId} from "univ4-core/types/PoolId.sol";								       */
/* import {Currency} from "univ4-core/types/Currency.sol";							       */
/* import {Slot0, Slot0Library} from "univ4-core/types/Slot0.sol";						       */
/* import {TickMath} from "univ4-core/libraries/TickMath.sol";							       */
/* import {CustomRevert} from "univ4-core/libraries/CustomRevert.sol";						       */
/* import {PriceSetterHook} from "../../../src/modules/protocol_integrations/PriceSetterHook.sol";		       */
/* import {TickCheat} from "./TickCheat.sol" ;									       */
/* import {Deployers} from "v4-core-test/utils/Deployers.sol";							       */
/* 														       */
/* contract PriceSetterHookTest is Deployers, Test{								       */
/* 														       */
/*     PriceSetterHook internal hook;										       */
/* 														       */
/*     // Namespaced flag address: only bits 13 (beforeInitialize) and 12 (afterInitialize)			       */
/*     // of the low 14 are set; 0x4444 << 20 keeps it clear of precompiles.					       */
/*     address internal constant HOOK_ADDRESS = address(							       */
/*         uint160(0x4444 << 20) | uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_INITIALIZE_FLAG)		       */
/*     );													       */
/* 														       */
/*     int24 internal constant INIT_TICK = 1000;								       */
/* 														       */
/*     function setUp() public {										       */
/*         deployFreshManager();										       */
/* 	// todo: Create a HookDeployer.plk helper and deploy it such that it does				       */
/* 	// - masking												       */
/* 	// - mining												       */
/*         deployCodeTo(											       */
/*             "src/modules/protocol_integrations/PriceSetterHook.sol:PriceSetterHook",				       */
/*             abi.encode(IPoolManager(address(manager))),							       */
/*             HOOK_ADDRESS											       */
/*         );													       */
/*         hook = PriceSetterHook(HOOK_ADDRESS);								       */
/*         key = PoolKey({											       */
/*             currency0: Currency.wrap(address(0x1111)),							       */
/*             currency1: Currency.wrap(address(0x2222)),							       */
/*             fee: LP_FEE,											       */
/*             tickSpacing: 60,											       */
/*             hooks: IHooks(HOOK_ADDRESS)									       */
/*         });													       */
/*         manager.initialize(key, TickMath.getSqrtPriceAtTick(INIT_TICK));					       */
/*         													       */
/*     }													       */
/* 														       */
/*     function test_binding_recordsPoolIdAndVerifiedSlot() public view {					       */
/*         assertEq(PoolId.unwrap(hook.poolId()), PoolId.unwrap(key.toId()), "poolId mismatch");		       */
/*         // Independent recomputation of the slot formula: _pools mapping sits at slot 6.			       */
/*         bytes32 expectedSlot = keccak256(abi.encodePacked(PoolId.unwrap(key.toId()), uint256(6)));		       */
/*         assertEq(hook.slot0Slot(), expectedSlot, "slot0Slot mismatch");					       */
/*         assertTrue(hook.slot0Slot() != bytes32(0), "unbound");						       */
/*     }													       */
/* 														       */
/*     function test_reads_matchInitializeValues() public view {						       */
/*         assertEq(hook.readTick(), INIT_TICK, "tick");							       */
/*         assertEq(hook.readSqrtPriceX96(), TickMath.getSqrtPriceAtTick(INIT_TICK), "sqrtPrice");		       */
/*     }													       */
/* 														       */
/*     /// forge-config: default.fuzz.runs = 256								       */
/*     function testFuzz_setTick_slot0ConsistentAndFeesPreserved(int24 t) public {				       */
/*         // MAX_TICK excluded: price domain is half-open, tick == MAX_TICK is unreachable			       */
/*         // for a real pool and getTickAtSqrtPrice reverts at MAX_SQRT_PRICE.					       */
/*         t = int24(bound(int256(t), int256(TickMath.MIN_TICK), int256(TickMath.MAX_TICK - 1)));		       */
/* 														       */
/*         TickCheat.setTick(vm, IPoolManager(address(manager)), hook, t);					       */
/* 														       */
/*         assertEq(hook.readTick(), t, "tick");								       */
/*         assertEq(hook.readSqrtPriceX96(), TickMath.getSqrtPriceAtTick(t), "sqrtPrice");			       */
/*         // Round-trip: the imposed slot0 is a price a real pool could hold.					       */
/*         assertEq(TickMath.getTickAtSqrtPrice(hook.readSqrtPriceX96()), t, "round-trip");			       */
/* 														       */
/*         // vm.load is the independent oracle: it bypasses the extsload path entirely				       */
/*         // (StateLibrary.getSlot0 would be circular -- same slot math, same extsload).			       */
/*         bytes32 raw = vm.load(address(manager), hook.slot0Slot());						       */
/*         assertEq(raw, Slot0.unwrap(hook.readSlot0()), "extsload vs vm.load");				       */
/* 														       */
/*         Slot0 slot0 = Slot0.wrap(raw);									       */
/*         assertEq(slot0.protocolFee(), SEEDED_PROTOCOL_FEE, "protocolFee bits clobbered");			       */
/*         assertEq(slot0.lpFee(), LP_FEE, "lpFee bits clobbered");						       */
/*     }													       */
/* 														       */
/*     function test_packSlot0For_revertsOutOfBounds() public {							       */
/*         vm.expectRevert(abi.encodeWithSelector(TickMath.InvalidTick.selector, TickMath.MAX_TICK + 1));	       */
/*         hook.packSlot0For(TickMath.MAX_TICK + 1);								       */
/*         vm.expectRevert(abi.encodeWithSelector(TickMath.InvalidTick.selector, TickMath.MIN_TICK - 1));	       */
/*         hook.packSlot0For(TickMath.MIN_TICK - 1);								       */
/*     }													       */
/* 														       */
/*     function test_secondInitialize_revertsAlreadyBound_wrapped() public {					       */
/*         PoolKey memory key2 = PoolKey({									       */
/*             currency0: Currency.wrap(address(0x1111)),							       */
/*             currency1: Currency.wrap(address(0x2222)),							       */
/*             fee: LP_FEE,											       */
/*             tickSpacing: 10, // different key, same hook							       */
/*             hooks: IHooks(HOOK_ADDRESS)									       */
/*         });													       */
/*         // ERC-7751: PoolManager wraps hook reverts; second field is the hook FUNCTION			       */
/*         // selector (bytes4 of the call payload), inner reason is the raw custom error.			       */
/*         vm.expectRevert(											       */
/*             abi.encodeWithSelector(										       */
/*                 CustomRevert.WrappedError.selector,								       */
/*                 HOOK_ADDRESS,										       */
/*                 IHooks.beforeInitialize.selector,								       */
/*                 abi.encodeWithSelector(PriceSetterHook.AlreadyBound.selector),				       */
/*                 abi.encodeWithSelector(Hooks.HookCallFailed.selector)					       */
/*             )												       */
/*         );													       */
/*         manager.initialize(key2, TickMath.getSqrtPriceAtTick(0));						       */
/*     }													       */
/* 														       */
/*     function test_unboundHook_readsAndPackRevert_NotBound() public {						       */
/*         PriceSetterHook fresh = new PriceSetterHook(IPoolManager(address(manager)));				       */
/*         vm.expectRevert(PriceSetterHook.NotBound.selector);							       */
/*         fresh.readTick();											       */
/*         vm.expectRevert(PriceSetterHook.NotBound.selector);							       */
/*         fresh.readSqrtPriceX96();										       */
/*         vm.expectRevert(PriceSetterHook.NotBound.selector);							       */
/*         fresh.packSlot0For(0);										       */
/*     }													       */
/* 														       */
/*     function test_directCalls_revertNotPoolManager() public {						       */
/*         vm.expectRevert(PriceSetterHook.NotPoolManager.selector);						       */
/*         hook.beforeInitialize(address(this), key, 0);							       */
/*         vm.expectRevert(PriceSetterHook.NotPoolManager.selector);						       */
/*         hook.afterInitialize(address(this), key, 0, 0);							       */
/*     }													       */
/* 														       */
/*     // Defensive branches unreachable through manager.initialize (AlreadyBound fires				       */
/*     // first); exercised via direct pranked calls for branch coverage.					       */
/*     function test_afterInitialize_wrongKey_revertsWrongPool() public {					       */
/*         PoolKey memory other = PoolKey({									       */
/*             currency0: Currency.wrap(address(0x1111)),							       */
/*             currency1: Currency.wrap(address(0x2222)),							       */
/*             fee: LP_FEE,											       */
/*             tickSpacing: 10,											       */
/*             hooks: IHooks(HOOK_ADDRESS)									       */
/*         });													       */
/*         vm.prank(address(manager));										       */
/*         vm.expectRevert(PriceSetterHook.WrongPool.selector);							       */
/*         hook.afterInitialize(address(this), other, 0, 0);							       */
/*     }													       */
/* 														       */
/*     function test_afterInitialize_mismatchedValues_revertsSlotVerificationFailed() public {			       */
/*         // Bound pool's stored tick is INIT_TICK; claim a different tick/price.				       */
/*         vm.prank(address(manager));										       */
/*         vm.expectRevert(											       */
/*             abi.encodeWithSelector(										       */
/*                 PriceSetterHook.SlotVerificationFailed.selector, INIT_TICK + 1, INIT_TICK			       */
/*             )												       */
/*         );													       */
/*         hook.afterInitialize(address(this), key, TickMath.getSqrtPriceAtTick(INIT_TICK + 1), INIT_TICK + 1);	       */
/*     }													       */
/* }														       */
/***********************************************************************************************************************/
