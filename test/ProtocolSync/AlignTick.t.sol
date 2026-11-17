// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "@test/BaseTest.t.sol";
import {ITick, MIN_TICK, MAX_TICK, normTickVal} from "@test/Tick.t.sol";
import {ITickSpacing} from "@test/TickSpacing.t.sol";
import {IWindow} from "@test/Window.t.sol";

import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";


import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";


interface IControllerSetter {
    function setController(address) external;
}


interface IEnvTickAligner {
    function setTickAligner(address) external;
}

interface ITickAligner {
    // TODO: Support bubble ERC-7751
    error InvalidCaller();
    error AlignCalldataMalformed();
    function align(int24,int24) external;
}

contract AlignTickTest is BaseTest {

    address alignTickHarness;
    address controller;
    

    function setUp() public override {
	super.setUp();
	controller = deployUniswapV4Hook("src/Controllers/Controller.plk");
	
	deployCodeTo(target, compilePlank("src/ProtocolSync/AlignTick.plk"));
	deployCodeTo(underlying, compilePlank("src/utils/Token/Transfer.plk"));
	deployCodeTo(numeraire, compilePlank("src/utils/Token/Transfer.plk"));
	alignTickHarness = target;
    }
    
    function test_WhenAlignIsCalledInAlignTick(int24 tick1,int24 tick2) external TickAlignmentContext  {

	// =================== PRE-REQUIREMENTS =======================
	IEnvTickAligner(main).setTickAligner(alignTickHarness);

	// =========================TEST==============================
        // It should revert if the caller is not Main or address this
	vm.prank(makeAddr("arbitrary-caller"));
	vm.expectRevert(ITickAligner.InvalidCaller.selector);
	ITickAligner(alignTickHarness).align(tick1,tick2);

	vm.prank(IEnv(alignTickHarness).IO());
	// It should revert it tick1 equals tick2
	if (tick1 == tick2) {
	    vm.expectRevert(ITickAligner.AlignCalldataMalformed.selector);
	} 
	ITickAligner(alignTickHarness).align(tick1,tick2);
 
	vm.prank(alignTickHarness);
	if (tick1 == tick2) {
	    vm.expectRevert(ITickAligner.AlignCalldataMalformed.selector);
	}
        ITickAligner(alignTickHarness).align(tick1,tick2);

	// =======================================================
    }

    function test_WhenTheCallerIsMain(uint256 windowLen,uint24 tickSpacing,uint256 maxIdx) external FullContext {
	// ============PRE-CONDITIONS==================================
	IControllerSetter(main).setController(controller);
	IEnvTickAligner(main).setTickAligner(alignTickHarness);
	// TODO: 200 is somewhat arbitrary and does not lead OOG
	uint256 windowLenCalldata = bound(windowLen, 1, 5);
	ITickSpacing(main).set_tick_spacing(tickSpacing);
	IWindow(main).set_window(windowLenCalldata);

	uint256 maxIdxPick = bound(maxIdx,1,windowLenCalldata);
	PoolKey memory marketKey = abi.decode(IMarketLens(main).getMarketKey(), (PoolKey));
	PoolKeyPeriphery memory marketKeyPeriphery = abi.decode(IMarketLens(main).getMarketKey(), (PoolKeyPeriphery));
	
	uint256 windowIdx = 0;
	do {
	    int256 tickSeed = vm.randomInt();
	    int24 tickOnRun = SafeCastLib.toInt24(bound(int256(tickSeed),int256(MIN_TICK),int256(MAX_TICK)));

	    int24 prevTick =  ITick(main).read_tick();
	    int24 newTick = normTickVal(tickOnRun, ITickSpacing(main).read_tick_spacing());
	    // On cold start, prevTick == newTick and cold start is the same as pool initialization.
	    // since at the type level we do not accept equal ticks on alignCalldata, then at initialization align is not called
	    if (windowIdx == 0) {
		prevTick = newTick;
		int24 initTick = prevTick;
		// It should call poolManager initialize
		vm.expectCall(poolManager, abi.encodeCall(IPoolManager.initialize,(marketKey,TickMath.getSqrtPriceAtTick(initTick))));
	    } else if (prevTick != newTick) {
		// Main skips align when normalized ticks are equal (AlignCalldataMalformed otherwise)
		vm.expectCall(alignTickHarness,abi.encodeCall(ITickAligner.align,(prevTick,newTick)));
		vm.expectCall(poolManager, abi.encodeCall(IPoolManager.unlock, (abi.encode(prevTick,newTick))));
	    // It should call unlock on poolManager passing the pair of ticks as unlockCalldata
		vm.expectCall(alignTickHarness, abi.encodeCall(IUnlockCallback.unlockCallback,(abi.encode(prevTick,newTick))));
	    // It should call swap on poolManager passing not revertible swap "SwapParams" (bool, int256 ,uint160)
	    IPoolManager.SwapParams memory expectedSwapParams;
	    expectedSwapParams.sqrtPriceLimitX96 = TickMath.getSqrtPriceAtTick(newTick);
	    (uint160 currentSqrtPriceX96,,,) = IStateView(poolManagerLens).getSlot0(PoolIdLibrary.toId(marketKeyPeriphery));
	    expectedSwapParams.zeroForOne = (expectedSwapParams.sqrtPriceLimitX96 < currentSqrtPriceX96);
	    // Matches ExposureAndDirectionAwareTickDistance: L = DEFAULT_EXPOSURE_SIZE (100e18).
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
	    console2.log("Expected Zero for one:",  expectedSwapParams.zeroForOne);
	    vm.expectCall(poolManager, abi.encodeCall(IPoolManager.swap, (marketKey,expectedSwapParams,Constants.ZERO_BYTES)));
	    }
	    ITick(main).set_tick(tickOnRun);

	    // Invariant: read_tick equals the canonical tick of slot0.sqrtPrice
	    (uint160 slot0SqrtPriceX96,, ,) =
		IStateView(poolManagerLens).getSlot0(PoolIdLibrary.toId(marketKeyPeriphery));
	    assertEq(
		ITick(main).read_tick(),
		TickMath.getTickAtSqrtPrice(slot0SqrtPriceX96),
		"read_tick must equal getTickAtSqrtPrice(slot0.sqrtPrice)"
	    );
	    
	    windowIdx++;
	    
         } while (windowIdx < maxIdxPick);
    }
    function test_WhenTheCallerIsAddressThis() external {
        // It should take as one of the passed ticks on calldata is an error from target tick.
        // It should call unlock on poolManager passing the pair of ticks as unlockCalldata and the error
	vm.skip(true);
    }


    function test_WhenUnlockCallbackIsCalledInAlignTick() external {
        // It should call the getMarketKey in Main
        // It should build SwapParams
        // It should call swap in poolManager with empty hookData, marketKey and builtSwapParams
        // It should call clearUnlock in AlignTick
        // It should fetch the current tick stored in the poolManager
	vm.skip(true);
    }

    function test_WhenTheCurrentTickFetchedFromPoolManagerStorageDoesNotEqualTheTickOnCalldataThatEqualedTheRead_tickFromMain() external {
        // It should track the error
        // It should call align in AlignTick with the second tick calldata argument as the error tracked
	vm.skip(true);
    }

    function test_WhenClearUnlockIsCalledInAlignTick() external {
        // It should call notifyDebt on both address from marketKey
        // It should call sync in PoolManager
        // It should call settle in PoolManager
	vm.skip(true);
    }
}

