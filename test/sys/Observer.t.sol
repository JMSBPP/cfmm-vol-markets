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

interface ISysSetter{
    function setSys(address) external;
}

interface IStateObserverSetter {
    function setStateObserver(address) external;
}

interface IStateObserver{
  function updateTick(int24,int24) external;
}


contract DiffTestStateObserverAlignTick  is BaseTest {
    function setUp () public override virtual {
	super.setUp();
    }
    
    struct Context {address poolManager; address poolManagerLens;address target;PoolKey marketKey; PoolKeyPeriphery marketKeyPeriphery;}
	struct TickDisturbance {int24 prevTick;int24 newTick;}

	function shock() internal returns(TickDisturbance memory tickDisturbance){
	    int256 tickSeed = vm.randomInt();
	    int24 tickOnRun = SafeCastLib.toInt24(bound(int256(tickSeed),int256(MIN_TICK),int256(MAX_TICK)));

	    int24 prevTick =  ITick(main).read_tick();
	    tickDisturbance = TickDisturbance(prevTick,tickOnRun);
         }
    
	function expectedPoolManagerFirstCalls__InsideDoTickDisturbance(Context memory ctx,uint256 windowIdx, TickDisturbance memory step) internal {
    	    if (windowIdx == 0) {
		step.prevTick = step.newTick;
		int24 initTick = step.prevTick;
		// It should call poolManager initialize
		vm.expectCall(ctx.poolManager, abi.encodeCall(IPoolManager.initialize,(ctx.marketKey,TickMath.getSqrtPriceAtTick(initTick))));
	    } else if (step.prevTick != step.newTick) {
		vm.expectCall(ctx.poolManager, abi.encodeCall(IPoolManager.unlock, (abi.encode(step.prevTick,step.newTick))));
	    }
    }

    function expectedPoolManagerSecondCalls__InsideDoTickDisturbance (Context memory ctx,uint256 windowIdx,int24 prevTick, int24 newTick) internal {
	    if (windowIdx == 0 || prevTick == newTick) {
		return;
	    }
	    IPoolManager.SwapParams memory expectedSwapParams;
	    expectedSwapParams.sqrtPriceLimitX96 = TickMath.getSqrtPriceAtTick(newTick);
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

    function invariant__InsideDoTickDisturbance(Context memory ctx) internal {
	    (uint160 slot0SqrtPriceX96,, ,) =
		IStateView(ctx.poolManagerLens).getSlot0(PoolIdLibrary.toId(ctx.marketKeyPeriphery));
	    assertEq(
		ITick(main).read_tick(),
		TickMath.getTickAtSqrtPrice(slot0SqrtPriceX96),
		"read_tick must equal getTickAtSqrtPrice(slot0.sqrtPrice)"
	    );

    }
}

contract ObserverTest is DiffTestStateObserverAlignTick {

    address stateObserver = makeAddr("cfmm-vol-markets.stateObserver");
    address sys = makeAddr("cfmm-vol-markets.sys");
    
    function setUp() public override {
	super.setUp();
	deployCodeTo(stateObserver, compilePlank("src/sys/observer.plk"));
	deployCodeTo(sys, compilePlank("src/sys/sys.plk"));
	deployCodeTo(target,compilePlank("src/sys/sys.plk"));
	deployCodeTo(underlying, compilePlank("src/utils/Token/Transfer.plk"));
	deployCodeTo(numeraire, compilePlank("src/utils/Token/Transfer.plk"));
	
    }

    function expectedStateObserverFirstCalls__InsideDoTickDisturbance(Context memory ctx,uint256 windowIdx,TickDisturbance memory input) internal {
	if (input.prevTick != input.newTick) {
	    vm.expectCall(sys,abi.encodeCall(IStateObserver.updateTick,(input.prevTick,input.newTick)));
		vm.expectCall(sys, abi.encodeCall(IUnlockCallback.unlockCallback,(abi.encode(input.prevTick,input.newTick))));
		
	}
    }

    function test_WhenTheCallerIsMain(uint256 windowLen,uint24 tickSpacing,uint256 maxIdx) external FullContext {
	// ============PRE-CONDITIONS==================================
	ISysSetter(main).setSys(sys);
	IStateObserverSetter(sys).setStateObserver(stateObserver);
	IEnv(sys).setIO(main);
	IEnv(sys).setPoolManager(poolManager);
	IEnv(sys).setPositionManager(positionManager);

	uint256 windowLenCalldata = bound(windowLen, 1, 5);
	ITickSpacing(main).set_tick_spacing(tickSpacing);
	IWindow(main).set_window(windowLenCalldata);
	
	uint256 maxIdxPick = bound(maxIdx,1,windowLenCalldata);
	PoolKey memory marketKey = abi.decode(IMarketLens(main).getMarketKey(), (PoolKey));
	PoolKeyPeriphery memory marketKeyPeriphery = abi.decode(IMarketLens(main).getMarketKey(), (PoolKeyPeriphery));
	
	uint256 windowIdx = 0;
	Context memory ctx = Context (poolManager,poolManagerLens,target,marketKey,marketKeyPeriphery);
	do {
	    TickDisturbance memory tickDisturbance = shock();
	    int24 tickOnRun = tickDisturbance.newTick;
	    tickDisturbance.newTick = normTickVal(tickOnRun, ITickSpacing(main).read_tick_spacing());
	    expectedPoolManagerFirstCalls__InsideDoTickDisturbance(ctx, windowIdx, tickDisturbance);
	    expectedStateObserverFirstCalls__InsideDoTickDisturbance(ctx, windowIdx, tickDisturbance);
	    expectedPoolManagerSecondCalls__InsideDoTickDisturbance(ctx, windowIdx, tickDisturbance.prevTick, tickDisturbance.newTick);

	    ITick(main).set_tick(tickOnRun);
	    invariant__InsideDoTickDisturbance(ctx);
	    windowIdx++;
	 
         } while (windowIdx < maxIdxPick);
    }
    

    

}
