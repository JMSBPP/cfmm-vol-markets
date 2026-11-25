// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "@test/PlankTestBase.sol";

import {console2} from "forge-std/console2.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {Constants} from "v4-core-test/utils/Constants.sol";
import {HookDeployer} from "@helpers/UniswapV4/HookDeployer.sol";
import {SfpmBytecodeDeployer} from "@helpers/UniswapV4/SfpmBytecodeDeployer.sol";

import {StateView} from "v4-periphery/lens/StateView.sol";
import {IStateView} from "v4-periphery/interfaces/IStateView.sol";
import {IPoolManager as IPoolManagerPeriphery, PoolId} from "v4-periphery/interfaces/IStateView.sol";

import {PoolKey as PoolKeyPeriphery} from "v4-periphery/lens/ReservesLens.sol";
import {Currency as CurrencyPeriphery} from "v4-periphery/PositionDescriptor.sol";
import {IHooks as IHooksPeriphery} from "v4-periphery/libraries/PathKey.sol";
import {PoolIdLibrary} from "v4-periphery/lens/ReservesLens.sol";


import {NoFeeVarianceClaimBuilderPermissions} from "@helpers/Permissions.sol";

import {ITick, MIN_TICK, MAX_TICK, normTickVal, usableMin, usableMax} from "@test/Tick.t.sol";
import {ITickSpacing, MAX_TICK_SPACING} from "@test/TickSpacing.t.sol";

import {IWindow} from "./Window.t.sol";

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";


function  emptyMarketKey() pure returns (PoolKey memory marketKey) {
    marketKey = PoolKey(Currency.wrap(address(0x00)),Currency.wrap(address(0x00)),uint24(0),int24(0),IHooks(address(0x00)));
}
function emptyMarketKeyPeriphery () pure returns (PoolKeyPeriphery memory marketKeyPeriphery) {
    marketKeyPeriphery = PoolKeyPeriphery(CurrencyPeriphery.wrap(address(0x00)),CurrencyPeriphery.wrap(address(0x00)),uint24(0),int24(0),IHooksPeriphery(address(0x00)));
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
    function setPoolManager(address) external;
    function setPositionManager(address) external;

    // todo: this is tmp
    function setTickAligner(address) external;
}


interface ISysSetter{
    function setSys(address) external;
}

interface IStateObserverSetter {
    function setStateObserver(address) external;
}

struct FuzzInputsCommon { uint256 windowIdx;uint256 windowLen;uint24 tickSpacing; uint24 premiumRate;}

function emptyArgs () pure returns(FuzzInputsCommon memory args) {args.windowIdx = 0;args.windowLen = 0; args.tickSpacing = uint24(0); args.premiumRate = uint24(0);}

struct TickDisturbance {int24 prevTick;int24 newTick;}    

function emptyTickDisturbance () pure returns(TickDisturbance memory resTickDisturbance) {
    resTickDisturbance = TickDisturbance(int24(0),int24(0));
}

struct ControlContext {
    address sys;
    address observer;
}

struct Context {
    address io;
    address poolManager;
    address poolManagerLens;
    address positionManager;
    address target;
    bool doneIterating;
    ControlContext controlContext;
    FuzzInputsCommon args;
    TickDisturbance shock;
    PoolKey marketKey;
    PoolKeyPeriphery marketKeyPeriphery;
}

function emptyControlContext () pure returns (ControlContext memory controlCtx){
    controlCtx = ControlContext(address(0x00), address(0x00));
}

function empty () pure returns (Context memory ctx) {
    ctx = Context(address(0x00),address(0x00),address(0x00),address(0x00),address(0x00),false,emptyControlContext(),emptyArgs(),emptyTickDisturbance(),emptyMarketKey(),emptyMarketKeyPeriphery ());
}


function stepWindow(Context memory ctx) pure returns (Context memory resCtx) {
    resCtx = ctx;
    resCtx.doneIterating = ctx.args.windowLen <= ctx.args.windowIdx; 
    if (!resCtx.doneIterating) { resCtx.args.windowIdx = ctx.args.windowIdx + 1;}
}

function endWindowCycleIfDone(Context memory ctx) pure {
    if (ctx.doneIterating) {return;}
}


contract BaseTest is PlankTestBase, Deployers, HookDeployer {
        address main = makeAddr("cfmm-vol-markets.main");
	address system = makeAddr("cfmm-vol-markets.sys");
	address stateObserver = makeAddr("cfmm-vol-markets.stateObserver");
	address poolManager;
	address positionManager;
	address poolManagerLens;
	address underlying = makeAddr("cfmm.vol-markets.underlying");
	address numeraire =  makeAddr("cfmm.vol-markets.numeraire");
	
	Context globalContext;
	ControlContext controlContext;

	function initControlContext () public returns(ControlContext memory _controlCtx) {
	    deployCodeTo(system, compilePlank("src/sys/sys.plk"));
	    deployCodeTo(stateObserver, compilePlank("src/sys/observer.plk"));
	    _controlCtx = ControlContext(system, stateObserver);
	    ISysSetter(globalContext.io).setSys(_controlCtx.sys);
	    IStateObserverSetter(_controlCtx.sys).setStateObserver(_controlCtx.observer);
	    IEnv(_controlCtx.sys).setIO(globalContext.io);
	    IEnv(_controlCtx.sys).setPoolManager(globalContext.poolManager);
	    IEnv(_controlCtx.sys).setPositionManager(globalContext.positionManager);
	}
	
	modifier TickAlignmentContext (Context memory ctx) {
	    
	    IEnv(ctx.target).setIO(ctx.io);
	    _;
	}

	function initContextIntegrations () public returns(Context memory ctx) {
	    deployCodeTo(main, compilePlank("src/Main.plk"));
	    globalContext.io = main;
	    deployFreshManager();

	    globalContext.poolManager = address(manager);
	    globalContext.positionManager = SfpmBytecodeDeployer.deploy(
	    vm, manager, 2100000000000000000000, 2100000000000000000000, 10000);
	    globalContext.poolManagerLens = address(new StateView(IPoolManagerPeriphery(address(manager))));
	    ctx = globalContext;

	}

	modifier FullContext (Context memory ctx) {
	    IMarketBuilder(ctx.io).setPair(underlying,numeraire,true);
	    IEnv(ctx.io).setPoolManager(ctx.poolManager);
	    IEnv(ctx.io).setPositionManager(ctx.positionManager);
	    PoolKey memory marketKey = abi.decode(IMarketLens(ctx.io).getMarketKey(), (PoolKey));
	    PoolKeyPeriphery memory marketKeyPeriphery = abi.decode(IMarketLens(ctx.io).getMarketKey(), (PoolKeyPeriphery));
	    globalContext.marketKey = marketKey;
            globalContext.marketKeyPeriphery = marketKeyPeriphery;
	    globalContext.controlContext = initControlContext();
	    _;
	}

        function setMarket (FuzzInputsCommon memory args) internal returns (Context memory ctx){
	            ctx.args.windowLen = bound(args.windowLen, 1, 5);
		    IWindow(ctx.io).set_window(ctx.args.windowLen);
		    ctx.args.tickSpacing = uint24(bound(args.tickSpacing, 60, MAX_TICK_SPACING));
		    ITickSpacing(ctx.io).set_tick_spacing(ctx.args.tickSpacing);
		    IWindow(ctx.io).set_window(ctx.args.windowLen);
	}

	error FailedToDeployUniswapV4Hook();
	function setUp() public virtual {
	   initContextIntegrations();
	}

	function deployUniswapV4Hook(string memory path) internal returns(address hookDeployed) {
	    (bool succ, address _tmp,) = deployHook(
					       compilePlank(path),
					       CREATE2_FACTORY,
					       NoFeeVarianceClaimBuilderPermissions
	    );
	    if (succ) { hookDeployed = _tmp;}
	    if (hookDeployed == address(0x00)) { revert FailedToDeployUniswapV4Hook();}
	    return hookDeployed;
	}

       function shock(Context memory ctx) internal returns(Context memory resCtx){
	    resCtx = ctx;
	    int256 tickSeed = vm.randomInt();
	    int24 tickOnRun = SafeCastLib.toInt24(bound(int256(tickSeed),int256(MIN_TICK),int256(MAX_TICK)));
	    int24 newTick = normTickVal(tickOnRun, ITickSpacing(ctx.io).read_tick_spacing());
	    int24 prevTick =  ITick(ctx.io).read_tick();
	    resCtx.shock = TickDisturbance(prevTick,newTick);
    }

    ///@dev error to supply
    error RevertWithFailureStatus(bool status);
    error DifferentialTestAssertionFailed();

    // slot where HEVM stores a bool representing whether or not an assertion has failed
    bytes32 HEVM_FAILED_SLOT = bytes32("failed");

    // hash of the bytes surfaced by `revert RevertWithFailureStatus(false)`
    bytes32 PASSING_HASH = keccak256(
        abi.encodeWithSelector(RevertWithFailureStatus.selector, false)
    );

    ///@dev reverts after function body with HEVM failure status, which clears all state changes
    ///     but still surfaces assertion failure status.
    modifier stateless() {
        _;
        revert RevertWithFailureStatus(readHevmFailureSlot());
    }

    ///@dev revert if the supplied bytes do not match the expected "passing" revert bytes
    function assertPass(bytes memory reason) internal view {
        // hash the reason and compare to the hash of the passing revert bytes
        if (keccak256(reason) != PASSING_HASH) {
            revert DifferentialTestAssertionFailed();
        }
    }

    ///@dev read the failure slot of the HEVM using the vm.load cheatcode
    ///     Returns true if there was an assertion failure. recorded.
    function readHevmFailureSlot() internal view returns (bool) {
        return vm.load(address(vm), HEVM_FAILED_SLOT) == bytes32(uint256(1));
    }

    function test(function(Context memory) external fn, Context memory context)
        internal
    {
        try fn(context) { }
        catch (bytes memory reason) {
            assertPass(reason);
        }
    }
       
}

