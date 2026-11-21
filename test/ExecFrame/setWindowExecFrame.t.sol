// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import  "@test/BaseTest.t.sol";
import {DifferentialTest} from "@test/DifferentialTest.sol";
import {IWindow} from "@test/Window.t.sol";
import {ReactiveTest} from "reactive-test-lib/base/ReactiveTest.sol";

// note: vendored due to incompatible comp versions
interface ISubscriptionService {
    /// @notice Subscribes the calling contract to receive events matching the criteria specified.
    /// @param chainId_ EIP155 source chain ID for the event (as a `uint256`), or `0` for all chains.
    /// @param contract_ Contract address to monitor, or `0` for all contracts.
    /// @param topic0_ Topic 0 to monitor, or `REACTIVE_IGNORE` for all topics.
    /// @param topic1_ Topic 1 to monitor, or `REACTIVE_IGNORE` for all topics.
    /// @param topic2_ Topic 2 to monitor, or `REACTIVE_IGNORE` for all topics.
    /// @param topic3_ Topic 3 to monitor, or `REACTIVE_IGNORE` for all topics.
    function subscribe(
        uint256 chainId_,
        address contract_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external;

    /// @notice Removes active subscription of the calling contract, matching the criteria specified, if one exists.
    /// @param chainId_ Chain ID criterion of the original subscription.
    /// @param contract_ Contract address criterion of the original subscription.
    /// @param topic0_ Topic 0 criterion of the original subscription.
    /// @param topic1_ Topic 0 criterion of the original subscription.
    /// @param topic2_ Topic 0 criterion of the original subscription.
    /// @param topic3_ Topic 0 criterion of the original subscription.
    function unsubscribe(
        uint256 chainId_,
        address contract_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external;
}

interface IExecFrame {
    event ExecFrameWindowLen(uint256);
    error ExecFrameInvalidEnv();
}


uint256 constant ANVIL_CHAIN_ID = 31337;

contract WindowExecFrameTest is DifferentialTest ,ReactiveTest {


    address execFrame = makeAddr("ExecFrame");
    address payable constant SYSTEM = payable(0x8888888888888888888888888888888888888888);
    uint256 constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;
    
    
    uint256 REACTIVE_CHAIN_ID = 1597;

    uint256 DEFAULT_ORIGIN_CHAIN_ID = ANVIL_CHAIN_ID;

    // cast keccak "Swap(bytes32,address,int128,int128,uint160,uint128,int24,uint24)"
    uint256 constant SWAP_TOPIC = 0x40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f;

    function setUp() public override(BaseTest, ReactiveTest) {
	BaseTest.setUp();
	ReactiveTest.setUp();
    }

    modifier whenSetWindowIsCalledWithWindowLenCalldata() {
        _;
    }

    function WhenSetWindowIsCalledWithWindowLenCalldata(Context memory ctx) external {
	// vm.chainId(REACTIVE_CHAIN_ID);
	console2.log("io:", ctx.io);
	console2.log("pm:", ctx.poolManager);
	
	IWindow(ctx.io).set_window(ctx.args.windowLen);
	
	console2.logBytes(abi.encodePacked(compilePlank("src/ExecFrame/ExecFrame.plk"),ctx.args.windowLen,REACTIVE_CHAIN_ID,ctx.poolManager,ctx.io));
	vm.expectRevert(IExecFrame.ExecFrameInvalidEnv.selector);
	deployCodeTo(execFrame, abi.encodePacked(compilePlank("src/ExecFrame/ExecFrame.plk"),ctx.args.windowLen,DEFAULT_ORIGIN_CHAIN_ID,ctx.poolManager,ctx.io));

	vm.chainId(REACTIVE_CHAIN_ID);
	vm.etch(SYSTEM,vm.parseBytes(vm.readFile(".bytecode/reactive/system.bytecode")));
	vm.expectEmit(true, false, false, false, execFrame);
        emit IExecFrame.ExecFrameWindowLen(ctx.args.windowLen);
	// It should subscribe to MarketKeyMarketId on the ReactiveNetwork
	
	vm.expectCall(SYSTEM, abi.encodeCall(ISubscriptionService.subscribe, (DEFAULT_ORIGIN_CHAIN_ID,ctx.poolManager,SWAP_TOPIC, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE)));
	

	deployCodeTo(execFrame, abi.encodePacked(compilePlank("src/ExecFrame/ExecFrame.plk"),ctx.args.windowLen,DEFAULT_ORIGIN_CHAIN_ID,ctx.poolManager,ctx.io));
	
	// It should calculate WindowGasBudgetUpperBound
	// It should log if WindowLenCalldata exceeds WindowGasBudgetUpperBound
        // It should set windowIdx to zero in storage
        // It should set windowDelta to WindowCalldata in storage
        // It should set ExFrame state on Window to listening
 
    }

    function test__fuzz__WhenSetWindowIsCalledWithWindowLenCalldata(FuzzInputsCommon memory args) external whenSetWindowIsCalledWithWindowLenCalldata {
	Context memory ctx = globalContext;
	
	ctx.args.windowLen = bound(args.windowLen, 1, 5);
 	test(
	     this.WhenSetWindowIsCalledWithWindowLenCalldata,
	     ctx
	);
    }

    function test_WhenWindowLenCalldataExceedsWindowGasBudgetUpperBound()
        external
        whenSetWindowIsCalledWithWindowLenCalldata
    {
        // It should set windowLen to WindowGasBudgetUpperBound in storage
    }

    function test_WhenWindowLenCalldataDoesNotExceedWindowGasBudgetUpperBound()
        external
        whenSetWindowIsCalledWithWindowLenCalldata
    {
        // It should set windowLen to WindowLenCalldata in storage
    }
}

