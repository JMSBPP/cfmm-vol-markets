// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {LiveContext} from "@script/deploy/deploy.s.sol";
import {SocketCfgHelper} from  "@test/ExecFrame/ExecFrame.t.sol";

struct SocketContext {
    address execFrame;
}

    
uint256 constant SEPOLIA_CHAIN_ID = 11155111;
uint256 constant EXPECTED_TEN_CALL_COST = 111246000000000000;

contract ExecFrameDeployer is Script, SocketCfgHelper, LiveContext {
    function getSocketContext() internal returns(SocketContext memory _socketCtx) {
       string memory json = vm.readFile(
					 "./foundry-scripts/out/protocol_interactions/Reactive//socket-context.json"
	);
	_socketCtx.execFrame = abi.decode(vm.parseJson(json, "$['exec-frame']"), (address));	
    }

    SocketContext socketContext;
    
    function deployExecFrame () public {
	  marketKeySet = true;
	  vm.startBroadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
	  address execFrame = deployCode(socketCode(chainIdParametrizedSocketCfgFromAllCtx(globalContext(), controlContext(), SEPOLIA_CHAIN_ID)));
	  string memory socket_json = vm.serializeAddress("socket-context", "exec-frame", execFrame);
	  execFrame.call{value: EXPECTED_TEN_CALL_COST}("");
	  
	  vm.stopBroadcast();
	  vm.writeJson(socket_json, "./foundry-scripts/out/protocol_interactions/Reactive/socket-context.json");
    }

}
