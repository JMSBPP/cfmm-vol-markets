// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.26;

import  "@test/BaseTest.t.sol";
import {IWindow, WINDOW_SLOT} from "@test/Window.t.sol";
import {ReactiveTest} from "reactive-test-lib/base/ReactiveTest.sol";
import {ReactiveSimulator} from "reactive-test-lib/simulator/ReactiveSimulator.sol";
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
}


uint256 constant ANVIL_CHAIN_ID = 31337;
// cast keccak "Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)"
uint256 constant SWAP_TOPIC = 0x40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f;
uint256 constant DEFAULT_ORIGIN_CHAIN_ID = ANVIL_CHAIN_ID;


uint256 constant BLACKLIST_CONTRACT_TOPIC0 = 0x930136576d6bd679046e0c2e6212ce4cacec0401db71e9a27f906d2bab5e08f3;


contract SocketCfgHelper is PlankTestBase {
    ControlContext controlCtx;
    struct SocketCfg {
	uint256 originChainId;
	uint256 poolManagerWord;
	uint256 swapTopic; // to be renamed
	bytes32 marketId;
	uint256 swapCaller; // to be remamed
        uint256 windowLen;
    }

    function socketCode(SocketCfg memory socketCfg) internal returns (bytes memory res){
	res = abi.encodePacked(compilePlank("src/ExecFrame/ExecFrame.plk"), socketCfg.originChainId, socketCfg.poolManagerWord, socketCfg.swapTopic, socketCfg.marketId, socketCfg.swapCaller, socketCfg.windowLen);
    }	

    function defaultSocketCfgFromCtx (Context memory ctx) internal returns(SocketCfg memory socketCfg) {
	socketCfg = SocketCfg(DEFAULT_ORIGIN_CHAIN_ID, uint256(uint160(ctx.poolManager)), SWAP_TOPIC,PoolId.unwrap(PoolIdLibrary.toId(ctx.marketKey)),uint256(uint160(controlCtx.sys)),ctx.args.windowLen);
    }

    function chainIdParametrizedSocketCfgFromAllCtx(Context memory ctx, ControlContext memory _controlCtx, uint256 _chainId) internal returns(SocketCfg memory socketCfg) {
	socketCfg = SocketCfg(_chainId, uint256(uint160(ctx.poolManager)), SWAP_TOPIC,PoolId.unwrap(PoolIdLibrary.toId(ctx.marketKey)),uint256(uint160(_controlCtx.sys)),ctx.args.windowLen);
    }

}

contract ExecFrameTest is BaseTest ,ReactiveTest, SocketCfgHelper {

    address execFrame = makeAddr("ExecFrame");
    address payable constant SYSTEM = payable(0x8888888888888888888888888888888888888888);
    uint256 constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;
    // cast keccak256 VolMarkets.WindowDelta
    bytes32 constant WINDOW_DELTA_SLOT =  0x1b4b73d375546c14f6ff7f6dff232f25863af6e4386a09b46e36a1ac979855e0;
    uint256 REACTIVE_CHAIN_ID = 1597;
    uint256 LASNA_CHAIN_ID = 5318007;

    uint256 DEFAULT_ORIGIN_CHAIN_ID = ANVIL_CHAIN_ID;


    address targetPlaceholder;


    uint24 constant DEFAULT_TICK_SPACING = uint24(60);
    uint256 constant MIN_WINDOW_LEN = 1;
    uint256 constant ZERO_WINDOW_IDX = 0;
    
    function setUp() public override(BaseTest, ReactiveTest) {
	BaseTest.setUp();
	ReactiveTest.setUp();
	deployCodeTo(underlying, compilePlank("src/utils/Token/Transfer.plk"));
	deployCodeTo(numeraire, compilePlank("src/utils/Token/Transfer.plk"));
    }

    function WhenExecFrameSocketIsDeployed(Context memory ctx) external FullContext(ctx){
	console2.log("io:", ctx.io);
	console2.log("pm:", ctx.poolManager);
	ITickSpacing(ctx.io).set_tick_spacing(DEFAULT_TICK_SPACING);
	ctx.marketKey.tickSpacing = int24(ITickSpacing(ctx.io).read_tick_spacing());
	IWindow(ctx.io).set_window(ctx.args.windowLen);
	if (!(vm.getChainId() == REACTIVE_CHAIN_ID ||vm.getChainId() == LASNA_CHAIN_ID)) {
		vm.expectRevert(IExecFrame.ExecFrameInvalidEnv.selector);
		deployCodeTo(execFrame, socketCode(defaultSocketCfgFromCtx(ctx)));
		
	}

	vm.chainId(LASNA_CHAIN_ID);
	vm.etch(SYSTEM,vm.parseBytes(vm.readFile(".bytecode/reactive/system.bytecode")));

	vm.expectCall(SYSTEM,abi.encodeCall(ISubscriptionService.subscribe, (LASNA_CHAIN_ID,SYSTEM,BLACKLIST_CONTRACT_TOPIC0,uint256(uint160(execFrame)),REACTIVE_IGNORE,REACTIVE_IGNORE)));
	
        vm.expectCall(SYSTEM,abi.encodeCall(IPayable.debt, (execFrame)));
	vm.expectEmit(false,false,false,true,execFrame);
	emit IReactiveCost.ReactiveCostLog(true,IPayable(payable(SYSTEM)).debt(execFrame));
	vm.expectEmit(true, false, false, false, execFrame);
        emit IExecFrame.ExecFrameWindowLen(ctx.args.windowLen);
	// It should subscribe to MarketKeyMarketId on the ReactiveNetwork
	
	vm.expectCall(SYSTEM, abi.encodeCall(ISubscriptionService.subscribe, (DEFAULT_ORIGIN_CHAIN_ID,ctx.poolManager,SWAP_TOPIC,uint256(PoolId.unwrap(PoolIdLibrary.toId(ctx.marketKey))), uint256(uint160(controlCtx.sys)), REACTIVE_IGNORE)));
	
        deployCodeTo(execFrame, socketCode(defaultSocketCfgFromCtx(ctx)));

	// It should store  windowCalldata on WINDOW_SLOT
	assertEq(ctx.args.windowLen,leftWord(uint256(vm.load(execFrame,WINDOW_SLOT))));
	assertEq(ZERO_WINDOW_IDX, rightWord(uint256(vm.load(execFrame,WINDOW_SLOT))));

	// It should set remainingStateUpdatesToListena to windowCalldata

	assertEq(IExecFrame(execFrame).remainingStateUpdatesToListen(), ctx.args.windowLen);
	// It should have its state as listening
	assertTrue(IExecFrame(execFrame).listening());
	// TO BE EVALUATED
	// It should calculate WindowGasBudgetUpperBound
	// It should log if WindowLenCalldata exceeds WindowGasBudgetUpperBound
 
    }

    function test__fuzz__WhenExecFrameSocketIsDeployed(FuzzInputsCommon memory args) external {
	Context memory ctx = globalContext;
	
	ctx.args.windowLen = bound(args.windowLen, 1, 5);
	test(
	     this.WhenExecFrameSocketIsDeployed,
	     ctx
	);
    }

    
    /* function WhenStateUpdateDuringWindowLength(Context memory ctx) external FullContext(ctx){ */
    /* 	ITickSpacing(ctx.io).set_tick_spacing(DEFAULT_TICK_SPACING); */
    /* 	ctx.marketKey.tickSpacing = int24(ITickSpacing(ctx.io).read_tick_spacing()); */
    /* 	IWindow(ctx.io).set_window(ctx.args.windowLen); */
	
    /* 	vm.etch(SYSTEM,vm.parseBytes(vm.readFile(".bytecode/reactive/system.bytecode"))); */

	
    /* 	/\* deployCodeTo(execFrame, socketCode(defaultSocketCfgFromCtx(ctx))); *\/ */

	
    /* 	/\* registerChain(ctx.poolManager, DEFAULT_ORIGIN_CHAIN_ID); *\/ */
    /* 	/\* registerChain(ctx.io, DEFAULT_ORIGIN_CHAIN_ID); *\/ */
    /* 	/\* registerChain(execFrame, LASNA_CHAIN_ID); *\/ */
    /* 	/\* registerChain(SYSTEM, LASNA_CHAIN_ID);     *\/ */
    /* /\* 	uint256 windowIdx = 0; *\/ */

    /* /\* 	do { *\/ */
    /* /\* 	    /\\* windowIdx++; *\\/ *\/ */
    /* /\* 	    /\\* if (windowIdx == ctx.args.windowLen + 1) { *\\/ *\/ */
    /* // /\* 	    /\\* 	assertFalse(IExecFrame(execFrame).listening()); *\\/ *\/ */
    /* /\* 	    /\\* } *\\/ *\/ */
    /* /\* 	    /\\* ctx = shock(ctx); *\\/ *\/ */
    /* /\* 	    vm.assume(ctx.shock.newTick != ITick(ctx.io).read_tick()); *\/ */
	    
    /* /\* 	/\\*     ReactiveSimulator.simulateReaction( *\\/ *\/ */
    /* /\* 	/\\* 				       vm, *\\/ *\/ */
    /* /\* 	/\\* 				       ctx.io, *\\/ *\/ */
    /* /\* 	/\\* 				       abi.encodeCall( *\\/ *\/ */
    /* /\* 	/\\* 						      ITick.set_tick, *\\/ *\/ */
    /* /\* 	/\\* 						      (tickOnRun) *\\/ *\/ */
    /* /\* 	/\\* 				       ), *\\/ *\/ */
    /* /\* 	/\\* 				       0, *\\/ *\/ */
    /* /\* 	/\\* 				       DEFAULT_ORIGIN_CHAIN_ID, *\\/ *\/ */
    /* /\* 	/\\* 				       MockSystemContract(SYSTEM), *\\/ *\/ */
    /* /\* 	/\\* 				       proxy, *\\/ *\/ */
    /* /\* 	/\\* 				       rvmId, *\\/ *\/ */
    /* /\* 	/\\* 				       LASNA_CHAIN_ID *\\/ *\/ */
    /* /\* 	/\\*     ); *\\/ *\/ */
    /* /\* 	} while (windowIdx <= ctx.args.windowLen + 1); *\/ */
    /* } */
    
    /* function test__fuzz__WhenStateUpdateDuringWindowLength(FuzzInputsCommon memory args) */
    /*     external */
    /* { */
    /* 	Context memory ctx = globalContext; */
	
    /* 	ctx.args.windowLen = bound(args.windowLen, 1, 5); */
    /* 	test( */
    /* 	     this.WhenStateUpdateDuringWindowLength, */
    /* 	     ctx */
    /* 	); */

    /*     // It should set windowLen to WindowGasBudgetUpperBound in storage */
    /* } */

}

