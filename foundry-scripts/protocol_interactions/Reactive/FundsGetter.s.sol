// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {PlankTestBase} from "@test/PlankTestBase.sol";

contract FundsGetterScript is Script, PlankTestBase {

    address constant ETHEREUM_SEPOLIA_FEEDER = 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434;
    address execFrame = makeAddr("cfmm-vol-markets.exec-frame");
    function driftAll () public {
        vm.broadcast(vm.envUint("TESTNET_PRIVATE_KEY"));
	ETHEREUM_SEPOLIA_FEEDER.call{ value: 4e18}("");
	deployCodeTo(execFrame, compilePlank("src/ExecFrame/ExecFrame.plk"));
   }
}
