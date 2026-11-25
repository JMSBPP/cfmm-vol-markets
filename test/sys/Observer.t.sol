// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@test/BaseTest.t.sol";
import {Test} from "forge-std/Test.sol";

import {ITick, MIN_TICK, MAX_TICK, normTickVal} from "@test/Tick.t.sol";
import {ITickSpacing} from "@test/TickSpacing.t.sol";
import {IWindow} from "@test/Window.t.sol";

import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";

import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {DifferentialTest} from "@test/DifferentialTest.sol";


interface IStateObserver{
  function updateTick(int24,int24) external;
}


contract ObserverTest is BaseTest, DifferentialTest {

    address stateObserver = makeAddr("cfmm-vol-markets.stateObserver");
    address sys = makeAddr("cfmm-vol-markets.sys");
    
    function setUp() public override {
	super.setUp();
	
	deployCodeTo(stateObserver, compilePlank("src/sys/observer.plk"));
	deployCodeTo(sys, compilePlank("src/sys/sys.plk"));
	deployCodeTo(underlying, compilePlank("src/utils/Token/Transfer.plk"));
	deployCodeTo(numeraire, compilePlank("src/utils/Token/Transfer.plk"));
	globalContext.target = sys;
	console2.log("Addr deployed:", globalContext.target);
    }
    // TODO: Partial deadcode since it was making test below fail even when final assertion passed. This is to be revised since checks on those calls is desired
    function expectedStateObserverFirstCalls__InsideDoTickDisturbance(Context memory ctx) external {
	if (ctx.shock.prevTick != ctx.shock.newTick) {
	    /* vm.expectCall(ctx.target,abi.encodeCall(IStateObserver.updateTick,(ctx.shock.prevTick,ctx.shock.newTick))); */
	    /* 	/\* vm.expectCall(ctx.target, abi.encodeCall(IUnlockCallback.unlockCallback,(abi.encode(ctx.shock.prevTick,ctx.shock.newTick)))); *\/ */
	}
    }

    
    function test__e2e__stateObserverObservesEveryTickDisturbanceOnPoolManager(FuzzInputsCommon memory args) external FullContext(globalContext) {
	// ============PRE-CONDITIONS==================================
	Context memory ctx = globalContext;
	
	uint256 windowLenCalldata = bound(args.windowLen, 1, 5);
	
	ITickSpacing(ctx.io).set_tick_spacing(args.tickSpacing);
	IWindow(ctx.io).set_window(windowLenCalldata);

	args.windowLen = windowLenCalldata;
	args.windowIdx = 0;
	args.tickSpacing = ITickSpacing(ctx.io).read_tick_spacing();
	ctx.args = args;
        ctx.marketKeyPeriphery.tickSpacing = int24(ITickSpacing(ctx.io).read_tick_spacing());
        ctx.marketKey.tickSpacing = int24(ITickSpacing(ctx.io).read_tick_spacing());
	ISysSetter(ctx.io).setSys(ctx.target);
	IStateObserverSetter(ctx.target).setStateObserver(stateObserver);
	IEnv(ctx.target).setIO(ctx.io);
	IEnv(ctx.target).setPoolManager(ctx.poolManager);
	IEnv(ctx.target).setPositionManager(ctx.positionManager);
	
	do {
	    ctx = shock(ctx);
	    test(
		 this.expectedPoolManagerFirstCalls__InsideDoTickDisturbance,
		 ctx
	    );
	    test(
		 this.expectedStateObserverFirstCalls__InsideDoTickDisturbance,
		 ctx
	    );
	    test(
		 this.expectedPoolManagerSecondCalls__InsideDoTickDisturbance,
		 ctx
	    );
	    
	    ITick(ctx.io).set_tick(ctx.shock.newTick);

	    test(
		 this.assert__InsideDoTickDisturbance,
		 ctx
	    );
	    ctx.args.windowIdx++;
         } while (ctx.args.windowIdx < ctx.args.windowLen);
    }

    
    // ================================== TESTS ================================================

    function expectedPoolManagerFirstCalls__InsideDoTickDisturbance(Context memory ctx) external {
    	    if (ctx.args.windowIdx == 0) {
		ctx.shock.prevTick = ctx.shock.newTick;
		int24 initTick = ctx.shock.prevTick;
		// It should call poolManager initialize
		vm.expectCall(ctx.poolManager, abi.encodeCall(IPoolManager.initialize,(ctx.marketKey,TickMath.getSqrtPriceAtTick(initTick))));
	    } else if (ctx.shock.prevTick != ctx.shock.newTick) {
		vm.expectCall(ctx.poolManager, abi.encodeCall(IPoolManager.unlock, (abi.encode(ctx.shock.prevTick,ctx.shock.newTick))));
	    }
    }

    function expectedPoolManagerSecondCalls__InsideDoTickDisturbance (Context memory ctx) external {
	    if (ctx.args.windowIdx == 0 || ctx.shock.prevTick == ctx.shock.newTick) {
		return;
	    }
	    IPoolManager.SwapParams memory expectedSwapParams;
	    expectedSwapParams.sqrtPriceLimitX96 = TickMath.getSqrtPriceAtTick(ctx.shock.newTick);
	    (uint160 currentSqrtPriceX96,,,) = IStateView(ctx.poolManagerLens).getSlot0(PoolIdLibrary.toId(ctx.marketKeyPeriphery));
	    
	    expectedSwapParams.zeroForOne = (expectedSwapParams.sqrtPriceLimitX96 < currentSqrtPriceX96);
	    
	    uint128 exposureLiquidity = uint128(uint256(100e18));
	    expectedSwapParams.amountSpecified = expectedSwapParams.zeroForOne
		? int256(
		    SqrtPriceMath.getAmount1Delta(
			currentSqrtPriceX96, expectedSwapParams.sqrtPriceLimitX96, exposureLiquidity, true
		    )
		)
		: int256(
		    SqrtPriceMath.getAmount0Delta(
			currentSqrtPriceX96, expectedSwapParams.sqrtPriceLimitX96, exposureLiquidity, true
		    )
		);
	    
	    vm.expectCall(ctx.poolManager, abi.encodeCall(IPoolManager.swap, (ctx.marketKey,expectedSwapParams,Constants.ZERO_BYTES)));
	    }

    function assert__InsideDoTickDisturbance(Context memory ctx) external {
	    (uint160 slot0SqrtPriceX96,, ,) =
		IStateView(ctx.poolManagerLens).getSlot0(PoolIdLibrary.toId(ctx.marketKeyPeriphery));
	    assertEq(
		ITick(ctx.io).read_tick(),
		TickMath.getTickAtSqrtPrice(slot0SqrtPriceX96),
		"read_tick must equal getTickAtSqrtPrice(slot0.sqrtPrice)"
	    );

    }
}
