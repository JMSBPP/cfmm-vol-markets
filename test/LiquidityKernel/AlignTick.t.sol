// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {PlankTestBase} from "@test/PlankTestBase.sol";
import {ITick, MIN_TICK, MAX_TICK, normTickVal} from "@test/Tick.t.sol";
import {ITickSpacing} from "@test/TickSpacing.t.sol";
import {IWindow} from "@test/Window.t.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {HookDeployer} from "@helpers/UniswapV4/HookDeployer.sol";
import {NoFeeVarianceClaimBuilderPermissions} from "@helpers/Permissions.sol";

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

interface IControllerSetter {
    function setController(address) external;
}


interface IMarketBuilder {
    function setPair(address,address,bool) external;
}

interface IMarketLens {
    function getMarketKey() external returns(bytes memory);
}

interface IEnv {
    function setIO(address) external;
    function IO() external returns(address);

    function setTickAligner(address) external;
    function setPoolManager(address) external;
    
}

interface ITickAligner {
    // TODO: Support bubble ERC-7751
    error InvalidCaller();
    function align(int24,int24) external;
}
contract AlignTickTest is PlankTestBase, Deployers, HookDeployer {

    address main = makeAddr("cfmm-vol-markets.main");
    address alignTickHarness = makeAddr("cfmm-vol-markets.alignTick");
    address poolManager;
    address underlying = makeAddr("cfmm.vol-markets.underlying");
    address numeraire =  makeAddr("cfmm.vol-markets.numeraire");
    address controller;


    function setUp() public {
	deployFreshManager();
	// Use the real PoolManager; etching its code onto another address trips noDelegateCall.
	poolManager = address(manager);
	deployCodeTo(main, plank("src/Main.plk"));
	deployCodeTo(alignTickHarness, plank("src/LiquidityKernel/AlignTick.plk"));
	deployCodeTo(underlying, plank("src/LiquidityKernel/Transfer.plk"));
	deployCodeTo(numeraire, plank("src/LiquidityKernel/Transfer.plk"));
	(bool succ, address _tmp,) = deployHook(
					       plank("src/LiquidityKernel/Controller.plk"),
					       CREATE2_FACTORY,
					       NoFeeVarianceClaimBuilderPermissions
	);
	if (succ) { controller = _tmp;}
    }
    
    modifier whenAlignIsCalledInAlignTick() {
        _;
    }

    function test_WhenAlignIsCalledInAlignTick(int24 tick1,int24 tick2) external whenAlignIsCalledInAlignTick {

	// =================== PRE-REQUIREMENTS =======================
	IEnv(alignTickHarness).setIO(main);
	IEnv(main).setTickAligner(alignTickHarness);

	// =========================TEST==============================
        // It should revert if the caller is not Main or address this
	vm.prank(makeAddr("arbitrary-caller"));
	vm.expectRevert(ITickAligner.InvalidCaller.selector);
	ITickAligner(alignTickHarness).align(tick1,tick2);

	vm.prank(IEnv(alignTickHarness).IO());
	ITickAligner(alignTickHarness).align(tick1,tick2);
	vm.prank(alignTickHarness);
        ITickAligner(alignTickHarness).align(tick1,tick2);

	// =======================================================
    }

    function test_WhenTheCallerIsMain(uint256 windowLen,uint24 tickSpacing,uint256 maxIdx) external whenAlignIsCalledInAlignTick {
	// ============PRE-CONDITIONS==================================
	// TODO: 200 is somewhat arbitrary and does not lead OOG
	uint256 windowLenCalldata = bound(windowLen, 1, 5);
	
	IEnv(alignTickHarness).setIO(main);
	IEnv(main).setTickAligner(alignTickHarness);
	IMarketBuilder(main).setPair(underlying,numeraire,true);
	IControllerSetter(main).setController(controller);
	IEnv(alignTickHarness).setPoolManager(poolManager);
	IEnv(main).setPoolManager(poolManager);
	ITickSpacing(main).set_tick_spacing(tickSpacing);
	IWindow(main).set_window(windowLenCalldata);

	uint256 maxIdxPick = bound(maxIdx,1,windowLenCalldata);
	uint256 windowIdx = 0;
	do {
	    int256 tickSeed = vm.randomInt();
	    int24 tickOnRun = SafeCastLib.toInt24(bound(int256(tickSeed),int256(MIN_TICK),int256(MAX_TICK)));

	    // First set_tick initializes the V4 pool when slot0.sqrtPriceX96 == 0 (no separate init()).
	    int24 prevTick =  ITick(main).read_tick();
	    int24 newTick = normTickVal(tickOnRun, ITickSpacing(main).read_tick_spacing());
	    // On cold start, set_tick bootstraps local tick to newTick before align → expect (newTick, newTick).
	    if (windowIdx == 0) {
		prevTick = newTick;
	    }
	    vm.expectCall(alignTickHarness,abi.encodeCall(ITickAligner.align,(prevTick,newTick)));
	    vm.expectCall(poolManager, abi.encodeCall(IPoolManager.unlock, (abi.encode(prevTick,newTick))));
	    // It should call unlock on poolManager passing the pair of ticks as unlockCalldata
	    vm.expectCall(alignTickHarness, abi.encodeCall(IUnlockCallback.unlockCallback,(abi.encode(prevTick,newTick))));
	    // It should call swap on poolManager passing the pair of ticks as unlockCalldata
	    // vm.expectCall
	    ITick(main).set_tick(tickOnRun);
	    
	 
	   
	    windowIdx++;
	// NOTE: When ticks have not been initialized read_tick is zero 
	    
         } while (windowIdx < maxIdxPick);
    }
    function test_WhenTheCallerIsAddressThis() external whenAlignIsCalledInAlignTick {
        // It should take as one of the passed ticks on calldata is an error from target tick.
        // It should call unlock on poolManager passing the pair of ticks as unlockCalldata and the error
    }

    modifier whenUnlockCallbackIsCalledInAlignTick() {
        _;
    }

    function test_WhenUnlockCallbackIsCalledInAlignTick() external whenUnlockCallbackIsCalledInAlignTick {
        // It should call the getMarketKey in Main
        // It should build SwapParams
        // It should call swap in poolManager with empty hookData, marketKey and builtSwapParams
        // It should call clearUnlock in AlignTick
        // It should fetch the current tick stored in the poolManager
    }

    function test_WhenTheCurrentTickFetchedFromPoolManagerStorageDoesNotEqualTheTickOnCalldataThatEqualedTheRead_tickFromMain(
    ) external whenUnlockCallbackIsCalledInAlignTick {
        // It should track the error
        // It should call align in AlignTick with the second tick calldata argument as the error tracked
    }

    function test_WhenClearUnlockIsCalledInAlignTick() external {
        // It should call notifyDebt on both address from marketKey
        // It should call sync in PoolManager
        // It should call settle in PoolManager
    }
}

