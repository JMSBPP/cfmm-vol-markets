// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";

import {LiveContext} from "@script/deploy/deploy.s.sol";
import {ITick, usableMax, usableMin, ITickSpacing} from "@test/Tick.t.sol";
import {IStateObserver} from "@test/sys/Observer.t.sol";
import {IExecFrame} from "@test/ExecFrame/ExecFrame.t.sol";
import {SocketContext} from "@script/protocol_interactions/Reactive/deploy.s.sol";

uint256 constant SEPOLIA_CHAIN_ID = 11155111;
int24 constant INIT_TICK = int24(0);
int24 constant SOME_TICK = int24(420);

contract VolMarketsStateTestAndScript is Script, Test ,LiveContext {
   function setUp() public {}
   function getSocketContext() internal returns(SocketContext memory _socketCtx) {
       string memory json = vm.readFile(
					 "./foundry-scripts/out/protocol_interactions/Reactive//socket-context.json"
	);
	_socketCtx.execFrame = abi.decode(vm.parseJson(json, "$['exec-frame']"), (address));	
    }

    function init() public {
	vm.broadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
	ITick(globalContext().io).set_tick(INIT_TICK);
    }

    function disturb() public {
	vm.broadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
	ITick(globalContext().io).set_tick(SOME_TICK);

    }
    function test__live__unit__WhenDisturbWithDelayObserverTracksDelay() public {
	uint32 fixedSecondsDelay = 300;
	vm.startBroadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
	uint256 windowLenSeed = vm.randomUint();
	uint256 windowCalldata = bound(windowLenSeed,2,5);
	uint256 windowIdx = 0;
	uint24 currentTickSpacing = ITickSpacing(globalContext().io).read_tick_spacing();
	do {
	    int24 prevTick = ITick(globalContext().io).read_tick();
	    int256 tickSeed = vm.randomInt();
	    int24 tickCalldata = int24(bound(tickSeed,int256(usableMin(int24(currentTickSpacing))), int256(usableMax(int24(currentTickSpacing)))));
	    vm.assume(tickCalldata != prevTick);	    
	    ITick(globalContext().io).set_tick(tickCalldata);
	    liveSleep(fixedSecondsDelay);
	    waitOnCallback();
	    assertGt(IStateObserver(controlContext().observer).windowDelta(IStateObserver.WindowDeltaType.Seconds), fixedSecondsDelay);
	    windowIdx++;
	} while(windowIdx<= windowCalldata);
    }
    
    function waitOnCallback() internal {
	string[] memory cmds = new string[](2);
	cmds[0] = "sleep";
	cmds[1] = "300";
	vm.ffi(cmds);
    }
    
    function liveSleep(uint32 delay) internal {
	string[] memory cmds = new string[](2);
	cmds[0] = "sleep";
	cmds[1] = "180"; 
	vm.ffi(cmds);
    }

    function disturbMultiRandom() public {
	vm.startBroadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
	uint256 windowLenSeed = vm.randomUint();
	uint256 windowCalldata = bound(windowLenSeed,2,5);
	uint256 windowIdx = 0;
	uint24 currentTickSpacing = ITickSpacing(globalContext().io).read_tick_spacing();
	do {
	    int24 prevTick = ITick(globalContext().io).read_tick();
	    int256 tickSeed = vm.randomInt();
	    int24 tickCalldata = int24(bound(tickSeed,int256(usableMin(int24(currentTickSpacing))), int256(usableMax(int24(currentTickSpacing)))));
	    vm.assume(tickCalldata != prevTick);	    
	    ITick(globalContext().io).set_tick(tickCalldata);
	    windowIdx++;
	} while(windowIdx<= windowCalldata);
	vm.stopBroadcast();
    }
    // note: this requires rpc-url to be lasna or reactive
    function queryIsSocketListening() public {
	  vm.broadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
	  IExecFrame(getSocketContext().execFrame).listening();
    }
    
    function queryRemainingEvtsOnSocket() public {
	 vm.broadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
	 IExecFrame(getSocketContext().execFrame).remainingStateUpdatesToListen();
    }
	    
}
