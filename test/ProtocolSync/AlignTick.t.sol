/* // SPDX-License-Identifier: UNLICENSED */
/* pragma solidity 0.8.26; */

/* import "@test/BaseTest.t.sol"; */
/* import {ITick, MIN_TICK, MAX_TICK, normTickVal} from "@test/Tick.t.sol"; */
/* import {ITickSpacing} from "@test/TickSpacing.t.sol"; */
/* import {IWindow} from "@test/Window.t.sol"; */

/* import {TickMath} from "v4-core/libraries/TickMath.sol"; */
/* import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol"; */

/* import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol"; */
/* import {SafeCastLib} from "solady/utils/SafeCastLib.sol"; */


/* interface IControllerSetter { */
/*     function setController(address) external; */
/* } */


/* interface IEnvTickAligner { */
/*     function setTickAligner(address) external; */
/* } */

/* interface ITickAligner { */
/*     // TODO: Support bubble ERC-7751 */
/*     error InvalidCaller(); */
/*     error AlignCalldataMalformed(); */
/*     function align(int24,int24) external; */
/* } */

/* contract DiffTestStateObserverAlignTick  is BaseTest { */
/*     function setUp () public override virtual { */
/* 	super.setUp(); */
/*     } */
    
/*     struct Context {address poolManager; address poolManagerLens;address target;PoolKey marketKey; PoolKeyPeriphery marketKeyPeriphery;} */
/* 	struct TickDisturbance {int24 prevTick;int24 newTick;} */
/* 	function shock() internal returns(TickDisturbance memory tickDisturbance){ */
/* 	    int256 tickSeed = vm.randomInt(); */
/* 	    int24 tickOnRun = SafeCastLib.toInt24(bound(int256(tickSeed),int256(MIN_TICK),int256(MAX_TICK))); */

/* 	    int24 prevTick =  ITick(main).read_tick(); */
/* 	    tickDisturbance = TickDisturbance(prevTick,tickOnRun); */
/*          } */
    
/* 	function expectedPoolManagerFirstCalls__InsideDoTickDisturbance(Context memory ctx,uint256 windowIdx, TickDisturbance memory step) internal { */
/*     	    if (windowIdx == 0) { */
/* 		step.prevTick = step.newTick; */
/* 		int24 initTick = step.prevTick; */
/* 		// It should call poolManager initialize */
/* 		vm.expectCall(ctx.poolManager, abi.encodeCall(IPoolManager.initialize,(ctx.marketKey,TickMath.getSqrtPriceAtTick(initTick)))); */
/* 	    } else if (step.prevTick != step.newTick) { */
/* 		vm.expectCall(ctx.poolManager, abi.encodeCall(IPoolManager.unlock, (abi.encode(step.prevTick,step.newTick)))); */
/* 	    } */
/*     } */

/*     function expectedPoolManagerSecondCalls__InsideDoTickDisturbance (Context memory ctx,uint256 windowIdx,int24 prevTick, int24 newTick) */
/* 	    internal { */
/* 	    if (windowIdx == 0 || prevTick == newTick) { */
/* 		return; */
/* 	    } */
/* 	    IPoolManager.SwapParams memory expectedSwapParams; */
/* 	    expectedSwapParams.sqrtPriceLimitX96 = TickMath.getSqrtPriceAtTick(newTick); */
/* 	    (uint160 currentSqrtPriceX96,,,) = IStateView(ctx.poolManagerLens).getSlot0(PoolIdLibrary.toId(ctx.marketKeyPeriphery)); */
	    
/* 	    expectedSwapParams.zeroForOne = (expectedSwapParams.sqrtPriceLimitX96 < currentSqrtPriceX96); */
	    
/* 	    uint128 exposureLiquidity = uint128(uint256(100e18)); */
/* 	    expectedSwapParams.amountSpecified = expectedSwapParams.zeroForOne */
/* 		? int256( */
/* 		    SqrtPriceMath.getAmount1Delta( */
/* 			currentSqrtPriceX96, expectedSwapParams.sqrtPriceLimitX96, exposureLiquidity, true */
/* 		    ) */
/* 		) */
/* 		: int256( */
/* 		    SqrtPriceMath.getAmount0Delta( */
/* 			currentSqrtPriceX96, expectedSwapParams.sqrtPriceLimitX96, exposureLiquidity, true */
/* 		    ) */
/* 		); */
	    
/* 	    vm.expectCall(ctx.poolManager, abi.encodeCall(IPoolManager.swap, (ctx.marketKey,expectedSwapParams,Constants.ZERO_BYTES))); */
/* 	    } */

/*     function invariant__InsideDoTickDisturbance(Context memory ctx) internal { */
/* 	    (uint160 slot0SqrtPriceX96,, ,) = */
/* 		IStateView(ctx.poolManagerLens).getSlot0(PoolIdLibrary.toId(ctx.marketKeyPeriphery)); */
/* 	    assertEq( */
/* 		ITick(main).read_tick(), */
/* 		TickMath.getTickAtSqrtPrice(slot0SqrtPriceX96), */
/* 		"read_tick must equal getTickAtSqrtPrice(slot0.sqrtPrice)" */
/* 	    ); */

/*     } */
/* } */

/* contract AlignTickTest is DiffTestStateObserverAlignTick { */

/*     address alignTickHarness; */
/*     address controller; */
    

/*     function setUp() public override { */
/* 	super.setUp(); */
/* 	controller = deployUniswapV4Hook("src/Controllers/Controller.plk"); */
	
/* 	deployCodeTo(alignTickHarness, compilePlank("src/ProtocolSync/AlignTick.plk")); */
/* 	deployCodeTo(underlying, compilePlank("src/utils/Token/Transfer.plk")); */
/* 	deployCodeTo(numeraire, compilePlank("src/utils/Token/Transfer.plk")); */
/*     } */
    
/*     function test_WhenAlignIsCalledInAlignTick(int24 tick1,int24 tick2) external TickAlignmentContext(setTarget(globalContext, alignTickHarness))  { */

/* 	// =================== PRE-REQUIREMENTS ======================= */
/* 	IEnvTickAligner(main).setTickAligner(alignTickHarness); */

/* 	// =========================TEST============================== */
/*         // It should revert if the caller is not Main or address this */
/* 	vm.prank(makeAddr("arbitrary-caller")); */
/* 	vm.expectRevert(ITickAligner.InvalidCaller.selector); */
/* 	ITickAligner(alignTickHarness).align(tick1,tick2); */

/* 	vm.prank(IEnv(alignTickHarness).IO()); */
/* 	// It should revert it tick1 equals tick2 */
/* 	if (tick1 == tick2) { */
/* 	    vm.expectRevert(ITickAligner.AlignCalldataMalformed.selector); */
/* 	}  */
/* 	ITickAligner(alignTickHarness).align(tick1,tick2); */
 
/* 	vm.prank(alignTickHarness); */
/* 	if (tick1 == tick2) { */
/* 	    vm.expectRevert(ITickAligner.AlignCalldataMalformed.selector); */
/* 	} */
/*         ITickAligner(alignTickHarness).align(tick1,tick2); */

/* 	// ======================================================= */
/*     } */
/*     function expectedAlignTickFirstCalls__InsideDoTickDisturbance(Context memory ctx,uint256 windowIdx,TickDisturbance memory input) internal { */
/* 	if (input.prevTick != input.newTick) { */
/* 		vm.expectCall(alignTickHarness,abi.encodeCall(ITickAligner.align,(input.prevTick,input.newTick))); */
/* 		vm.expectCall(alignTickHarness, abi.encodeCall(IUnlockCallback.unlockCallback,(abi.encode(input.prevTick,input.newTick)))); */
		
/* 	} */
/*     } */
    
/*     function test_WhenTheCallerIsMain(uint256 windowLen,uint24 tickSpacing,uint256 maxIdx) external FullContext { */
/* 	// ============PRE-CONDITIONS================================== */
/* 	IControllerSetter(main).setController(controller); */
/* 	IEnvTickAligner(main).setTickAligner(alignTickHarness); */

	
/* 	uint256 windowLenCalldata = bound(windowLen, 1, 5); */
/* 	ITickSpacing(main).set_tick_spacing(tickSpacing); */
/* 	IWindow(main).set_window(windowLenCalldata); */

/* 	uint256 maxIdxPick = bound(maxIdx,1,windowLenCalldata); */
/* 	PoolKey memory marketKey = abi.decode(IMarketLens(main).getMarketKey(), (PoolKey)); */
/* 	PoolKeyPeriphery memory marketKeyPeriphery = abi.decode(IMarketLens(main).getMarketKey(), (PoolKeyPeriphery)); */
	
/* 	uint256 windowIdx = 0; */
/* 	do { */
/* 	    TickDisturbance memory tickDisturbance = shock(); */
/* 	    int24 tickOnRun = tickDisturbance.newTick; */
/* 	    tickDisturbance.newTick = normTickVal(tickOnRun, ITickSpacing(main).read_tick_spacing()); */
/* 	    expectedPoolManagerFirstCalls__InsideDoTickDisturbance(ctx, windowIdx, tickDisturbance); */
/* 	    expectedAlignTickFirstCalls__InsideDoTickDisturbance(ctx, windowIdx, tickDisturbance); */
/* 	    expectedPoolManagerSecondCalls__InsideDoTickDisturbance(ctx, windowIdx, tickDisturbance.prevTick, tickDisturbance.newTick); */

/* 	    ITick(main).set_tick(tickOnRun); */
/* 	    invariant__InsideDoTickDisturbance(ctx); */
/* 	    windowIdx++; */

/*          } while (windowIdx < maxIdxPick); */
/*     } */

/*     function test_WhenTheCallerIsAddressThis() external { */
/*         // It should take as one of the passed ticks on calldata is an error from target tick. */
/*         // It should call unlock on poolManager passing the pair of ticks as unlockCalldata and the error */
/* 	vm.skip(true); */
/*     } */


/*     function test_WhenUnlockCallbackIsCalledInAlignTick() external { */
/*         // It should call the getMarketKey in Main */
/*         // It should build SwapParams */
/*         // It should call swap in poolManager with empty hookData, marketKey and builtSwapParams */
/*         // It should call clearUnlock in AlignTick */
/*         // It should fetch the current tick stored in the poolManager */
/* 	vm.skip(true); */
/*     } */

/*     function test_WhenTheCurrentTickFetchedFromPoolManagerStorageDoesNotEqualTheTickOnCalldataThatEqualedTheRead_tickFromMain() external { */
/*         // It should track the error */
/*         // It should call align in AlignTick with the second tick calldata argument as the error tracked */
/* 	vm.skip(true); */
/*     } */

/*     function test_WhenClearUnlockIsCalledInAlignTick() external { */
/*         // It should call notifyDebt on both address from marketKey */
/*         // It should call sync in PoolManager */
/*         // It should call settle in PoolManager */
/* 	vm.skip(true); */
/*     } */
/* } */

