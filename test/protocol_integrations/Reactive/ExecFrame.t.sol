// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import  "@test/BaseTest.t.sol";
import {IWindow, WINDOW_SLOT} from "@test/Window.t.sol";
import {ReactiveTest} from "reactive-test-lib/base/ReactiveTest.sol";
import {CallbackResult} from "reactive-test-lib/interfaces/IReactiveInterfaces.sol";
import {ReactiveSimulator} from "reactive-test-lib/simulator/ReactiveSimulator.sol";
import {ReactiveConstants} from "reactive-test-lib/constants/ReactiveConstants.sol";
import {MockSystemContract} from "reactive-test-lib/mock/MockSystemContract.sol";

// todo: utils to be placed in other place

function leftWord(uint256 raw) pure returns (uint256) {
    return raw >> 128;
}

function rightWord(uint256 raw) pure returns (uint256) {
    return uint256(uint128(raw));
}

// note: vendored due to comp issue incompatibility
interface IPayable {
    receive() external payable;
    function debt(address contract_) external view returns (uint256 debt_);
}

interface ISubscriptionService {
    function subscribe(
        uint256 chainId_,
        address contract_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external;
    function unsubscribe(
        uint256 chainId_,
        address contract_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external;
}

interface IReactiveCost{
    event ReactiveCostLog(bool,uint256);
}
interface IExecFrame {
    event ExecFrameWindowLen(uint256);
    error ExecFrameInvalidEnv();
    function listening() external returns(bool);
    function remainingStateUpdatesToListen() external returns(uint256);
    function stateUpdatesListenedCount() external returns(uint256);
}


uint256 constant ANVIL_CHAIN_ID = 31337;
uint256 constant DEFAULT_ORIGIN_CHAIN_ID = ANVIL_CHAIN_ID;
uint256 constant DEFAULT_CALLBACK_CHAIN_ID = DEFAULT_ORIGIN_CHAIN_ID;
uint256 constant NO_EVENTS_LISTENED = 0;

// cast keccak "Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)"
uint256 constant SWAP_TOPIC = 0x40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f;


uint256 constant BLACKLIST_CONTRACT_TOPIC0 = 0x930136576d6bd679046e0c2e6212ce4cacec0401db71e9a27f906d2bab5e08f3;

address constant SYSTEM = 0x8888888888888888888888888888888888888888;



contract SocketCfgHelper is PlankTestBase {
    struct SocketCfg {
	uint256 originChainId;
	address poolManager;
	uint256 swapTopic; // to be renamed
	bytes32 marketId;
        address sys; // to be remamed
        uint256 windowLen;
	address service;
	uint256 callbackChainId;
    }


     function encodeSocketCfg (SocketCfg memory socketCfg) internal returns(bytes memory res) {
	 res =  abi.encode(socketCfg.originChainId, socketCfg.poolManager, socketCfg.swapTopic, socketCfg.marketId, socketCfg.sys, socketCfg.windowLen, socketCfg.service, socketCfg.callbackChainId);
     }	
    function socketCode(SocketCfg memory socketCfg) internal returns (bytes memory res){
	res = bytes.concat(compilePlank("src/ExecFrame/ExecFrame.plk"), encodeSocketCfg(socketCfg));
    }	

 function defaultSocketCfgFromCtx (Context memory ctx) internal returns(SocketCfg memory socketCfg) {
     socketCfg = SocketCfg(DEFAULT_ORIGIN_CHAIN_ID, ctx.poolManager, SWAP_TOPIC,PoolId.unwrap(PoolIdLibrary.toId(ctx.marketKey)),ctx.controlContext.sys,ctx.args.windowLen, SYSTEM, DEFAULT_CALLBACK_CHAIN_ID);
    }

    function chainIdParametrizedSocketCfgFromAllCtx(Context memory ctx, uint256 _chainId) internal returns(SocketCfg memory socketCfg) {
	socketCfg = SocketCfg(_chainId, ctx.poolManager, SWAP_TOPIC,PoolId.unwrap(PoolIdLibrary.toId(ctx.marketKey)),ctx.controlContext.sys,ctx.args.windowLen, SYSTEM, DEFAULT_CALLBACK_CHAIN_ID);
    }

    function serviceContractParametrizedSocketCfgFromCtx(Context memory ctx, address service) internal returns(SocketCfg memory socketCfg) {
	socketCfg = SocketCfg(DEFAULT_ORIGIN_CHAIN_ID, ctx.poolManager, SWAP_TOPIC,PoolId.unwrap(PoolIdLibrary.toId(ctx.marketKey)),ctx.controlContext.sys,ctx.args.windowLen, service, DEFAULT_CALLBACK_CHAIN_ID);
    }

}


function expectedCallbackChainIdOnExecFrameBytecode(address src)
     returns (uint256 word)
{
    uint256 size = src.code.length;

    assembly ("memory-safe") {
        extcodecopy(src, 0x00, sub(size, 32), 32)
        word := mload(0x00)
    }
}

function expectedServiceOnExecFrameBytecode(address src)
     returns (uint256 word)
{
    uint256 size = src.code.length;

    assembly ("memory-safe") {
        extcodecopy(src, 0x00, sub(size, 64), 32)
        word := mload(0x00)
    }
}

function expectedWindowLenOnExecFrameBytecode(address src)
     returns (uint256 word)
{
    uint256 size = src.code.length;

    assembly ("memory-safe") {
        extcodecopy(src, 0x00, sub(size, 96), 32)
        word := mload(0x00)
    }
}

function expectedSysOnExecFrameBytecode(address src)
     returns (uint256 word)
{
    uint256 size = src.code.length;

    assembly ("memory-safe") {
        extcodecopy(src, 0x00, sub(size, 128), 32)
        word := mload(0x00)
    }
}


function expectedMarketIdWordOnExecFrameBytecode(address src)
     returns (uint256 word)
{
    uint256 size = src.code.length;

    assembly ("memory-safe") {
        extcodecopy(src, 0x00, sub(size, 160), 32)
        word := mload(0x00)
    }
}

function expectedSwapTopicOnExecFrameBytecode(address src)
     returns (uint256 word)
{
    uint256 size = src.code.length;

    assembly ("memory-safe") {
        extcodecopy(src, 0x00, sub(size, 192), 32)
        word := mload(0x00)
    }
}

function expectedPoolManagerOnExecFrameBytecode(address src)
     returns (uint256 word)
{
    uint256 size = src.code.length;

    assembly ("memory-safe") {
        extcodecopy(src, 0x00, sub(size, 224), 32)
        word := mload(0x00)
    }
}

function expectedOriginChainIdOnExecFrameBytecode(address src)
     returns (uint256 word)
{
    uint256 size = src.code.length;

    assembly ("memory-safe") {
        extcodecopy(src, 0x00, sub(size, 256), 32)
        word := mload(0x00)
    }
}


contract ExecFrameTest is BaseTest ,ReactiveTest, SocketCfgHelper {

    address execFrame = makeAddr("ExecFrame");
    uint256 constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;
    // cast keccak256 VolMarkets.WindowDelta
    bytes32 constant WINDOW_DELTA_SLOT =  0x1b4b73d375546c14f6ff7f6dff232f25863af6e4386a09b46e36a1ac979855e0;

    // cast keccak cfmm_types.foreignChainId
    bytes32 constant FOREIGN_CHAIN_ID_BASE_SLOT = 0xd3dd022752a804842501aebe79d73a952ddee21bb4040e7073417bfad31ac5a3;
    
    uint256 REACTIVE_CHAIN_ID = 1597;
    uint256 LASNA_CHAIN_ID = 5318007;


    address targetPlaceholder;
    uint24 constant DEFAULT_TICK_SPACING = uint24(60);
    uint256 constant MIN_WINDOW_LEN = 1;
    uint256 constant ZERO_WINDOW_IDX = 0;


    function AnvilAndReactive(Context memory ctx, ReactiveContext memory _reactiveContext) external returns(uint256){
	registerChain(ctx.poolManager, ANVIL_CHAIN_ID);
	registerChain(ctx.io, ANVIL_CHAIN_ID);
	registerChain(ctx.controlContext.sys, ANVIL_CHAIN_ID);
	registerChain(ctx.controlContext.observer, ANVIL_CHAIN_ID);
	registerChain(_reactiveContext.callback, ANVIL_CHAIN_ID);
	registerChain(_reactiveContext.reactive, ReactiveConstants.REACTIVE_CHAIN_ID);
	registerChain(_reactiveContext.service, ReactiveConstants.REACTIVE_CHAIN_ID);
    }

    struct ReactiveContext {
	address reactive;
	address service;
	address callback;
    }
	
    function defaultReactiveContext(Context memory ctx) internal returns(ReactiveContext memory _reactiveContext) { _reactiveContext = ReactiveContext ({reactive: execFrame,service: address(sys),callback: ctx.controlContext.sys }); }
    
    modifier ReactiveContextSync (Context memory ctx, ReactiveContext memory _reactiveContext,function (Context memory, ReactiveContext memory) external returns (uint256) chainIdsDispatcher) {
	chainIdsDispatcher(ctx, _reactiveContext);
	_;
    }
    
    function setUp() public override(BaseTest, ReactiveTest) {
	BaseTest.setUp();
	ReactiveTest.setUp();
	deployCodeTo(underlying, compilePlank("src/utils/Token/Transfer.plk"));
	deployCodeTo(numeraire, compilePlank("src/utils/Token/Transfer.plk"));
    }

    function WhenExecFrameSocketIsDeployed(Context memory ctx) external FullContext(ctx) SaveContext(ctx){
	
	vm.expectCall(address(sys),abi.encodeCall(ISubscriptionService.subscribe, (vm.getChainId(),address(sys),BLACKLIST_CONTRACT_TOPIC0,uint256(uint160(execFrame)),REACTIVE_IGNORE,REACTIVE_IGNORE)));
	uint256 marketIdWord = uint256(PoolId.unwrap(PoolIdLibrary.toId(ctx.marketKey)));
	vm.expectCall(address(sys), abi.encodeCall(ISubscriptionService.subscribe, (DEFAULT_ORIGIN_CHAIN_ID,ctx.poolManager,SWAP_TOPIC, marketIdWord, uint256(uint160(ctx.controlContext.sys)), REACTIVE_IGNORE)));
	
        vm.expectCall(address(sys) ,abi.encodeCall(IPayable.debt, (execFrame)));
	vm.expectEmit(false,false,false,true,execFrame);
	emit IReactiveCost.ReactiveCostLog(true,0);
	vm.expectEmit(true, false, false, false, execFrame);
        emit IExecFrame.ExecFrameWindowLen(ctx.args.windowLen);
	// It should subscribe to MarketKeyMarketId on the ReactiveNetwork
		
	deployCodeTo(execFrame, socketCode(serviceContractParametrizedSocketCfgFromCtx(ctx, address(sys))));
		     
	// It should store the service address on its bytecode
	assertEq(DEFAULT_CALLBACK_CHAIN_ID,expectedCallbackChainIdOnExecFrameBytecode(execFrame));
	assertEq(uint256(uint160(address(sys))), expectedServiceOnExecFrameBytecode(execFrame));
	assertEq(ctx.args.windowLen, expectedWindowLenOnExecFrameBytecode(execFrame));
	assertEq(uint256(uint160(ctx.controlContext.sys)), expectedSysOnExecFrameBytecode(execFrame));
	assertEq(marketIdWord, expectedMarketIdWordOnExecFrameBytecode(execFrame));
	assertEq(SWAP_TOPIC, expectedSwapTopicOnExecFrameBytecode(execFrame));
	assertEq(uint256(uint160(ctx.poolManager)), expectedPoolManagerOnExecFrameBytecode(execFrame));
	assertEq(DEFAULT_ORIGIN_CHAIN_ID, expectedOriginChainIdOnExecFrameBytecode(execFrame));


	console2.logBytes(execFrame.code);
	// It should set remainingStateUpdatesToListena to windowLen
	assertEq(IExecFrame(execFrame).remainingStateUpdatesToListen(), ctx.args.windowLen);
	assertEq(IExecFrame(execFrame).stateUpdatesListenedCount(), NO_EVENTS_LISTENED);
	// It should have its state as listening
	assertTrue(IExecFrame(execFrame).listening());
	// TO BE EVALUATED
	// It should calculate WindowGasBudgetUpperBound
	// It should log if WindowLenCalldata exceeds WindowGasBudgetUpperBound
 
    }

    function test__fuzz__WhenExecFrameSocketIsDeployed(FuzzInputsCommon memory args) external {
	Context memory ctx = globalContext;
	ctx = setMarket(args);
	test(
	     this.WhenExecFrameSocketIsDeployed,
	     ctx
	);
    }

    
    function WhenStateUpdateDuringWindowLength(Context memory ctx) external FullContext(ctx) ReactiveContextSync(ctx, defaultReactiveContext(ctx), this.AnvilAndReactive){
	deployCodeTo(execFrame, socketCode(serviceContractParametrizedSocketCfgFromCtx(ctx, address(sys))));
	
	uint256 windowIdx = 0;
	do {
	    ctx = shock(ctx);
	    vm.assume(ctx.shock.newTick != ITick(ctx.io).read_tick());
	    CallbackResult[] memory results = triggerAndReact(
							      ctx.io,
							      abi.encodeCall(
									     ITick.set_tick,
									     (ctx.shock.newTick)
							      ),
							      ANVIL_CHAIN_ID
	    );

	    
	    assertTrue(results[0].success);
	} while (windowIdx <= ctx.args.windowLen);
	assertFalse(IExecFrame(execFrame).listening());
    }
    
    function test__fuzz__WhenStateUpdateDuringWindowLength(FuzzInputsCommon memory args)
        external
    {
	Context memory ctx = globalContext;
	ctx = setMarket(args);
	test(
	     this.WhenStateUpdateDuringWindowLength,
	     ctx
	);

        // It should set windowLen to WindowGasBudgetUpperBound in storage
    }

}

