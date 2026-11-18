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

import {ITick, MIN_TICK, MAX_TICK, normTickVal} from "@test/Tick.t.sol";
import {ITickSpacing} from "@test/TickSpacing.t.sol";
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

struct FuzzInputsCommon { uint256 windowIdx;uint256 windowLen;uint24 tickSpacing; uint24 premiumRate;}

function emptyArgs () pure returns(FuzzInputsCommon memory args) {args.windowIdx = 0;args.windowLen = 0; args.tickSpacing = uint24(0); args.premiumRate = uint24(0);}

struct TickDisturbance {int24 prevTick;int24 newTick;}    

function emptyTickDisturbance () pure returns(TickDisturbance memory resTickDisturbance) {
    resTickDisturbance = TickDisturbance(int24(0),int24(0));
}

struct Context {
    address io;
    address poolManager;
    address poolManagerLens;
    address positionManager;
    address target;
    bool doneIterating;
    FuzzInputsCommon args;
    TickDisturbance shock;
    PoolKey marketKey;
    PoolKeyPeriphery marketKeyPeriphery;
}
    
function empty () pure returns (Context memory ctx) {
    ctx = Context(address(0x00),address(0x00),address(0x00),address(0x00),address(0x00),false,emptyArgs(),emptyTickDisturbance(),emptyMarketKey(),emptyMarketKeyPeriphery ());
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
	address poolManager;
	address positionManager;
	address poolManagerLens;
	address underlying = makeAddr("cfmm.vol-markets.underlying");
	address numeraire =  makeAddr("cfmm.vol-markets.numeraire");
	Context globalContext;

	modifier TickAlignmentContext (Context memory ctx) {
	    IEnv(ctx.target).setIO(ctx.io);
	    _;
	}

	function initContextIntegrations () public returns(Context memory ctx) {
	    deployCodeTo(main, compilePlank("src/Main.plk"));
	    globalContext.io = main;
	    console2.log("io on global context:", globalContext.io);
	    console2.log("io size on global context:", globalContext.io.code.length);
	    deployFreshManager();

	    globalContext.poolManager = address(manager);
	    console2.log("poolManager on global context:", globalContext.poolManager);
	    globalContext.positionManager = SfpmBytecodeDeployer.deploy(
	    vm, manager, 2100000000000000000000, 2100000000000000000000, 10000);
	    console2.log("positionManager on global context:", globalContext.positionManager);
	    globalContext.poolManagerLens = address(new StateView(IPoolManagerPeriphery(address(manager))));
	    console2.log("poolManagerLens on global context:", globalContext.poolManagerLens);
	    ctx = globalContext;
	    console2.log("io on init context return:", ctx.io);
	    console2.log("io size on init context return:", ctx.io.code.length);

	}

	modifier FullContext (Context memory ctx) {
	    IEnv(ctx.target).setIO(ctx.io);
	    IMarketBuilder(ctx.io).setPair(underlying,numeraire,true);
	    IEnv(ctx.target).setPoolManager(ctx.poolManager);
	    IEnv(ctx.io).setPoolManager(ctx.poolManager);
	    IEnv(ctx.target).setPositionManager(ctx.positionManager);
	    IEnv(ctx.io).setPositionManager(ctx.positionManager);
	    _;
	}


	error FailedToDeployUniswapV4Hook();
	function setUp() public virtual {
	    Context memory globalContextInitialized = initContextIntegrations();
	    console2.log("io on globalContextInitialized on setUp:", globalContextInitialized.io);
	    console2.logBytes(abi.encode(globalContextInitialized));
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


}

