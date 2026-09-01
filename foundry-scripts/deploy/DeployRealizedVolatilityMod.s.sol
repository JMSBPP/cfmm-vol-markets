// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";
import {PlankDeployBase} from "./PlankDeployBase.s.sol";

/// @notice Deploys RealizedVolatilityMod -- the Algebra-byte-exact vol oracle the stochastic
/// price diffusion feeds (writeTimepoint directly).
/// Optionally seeds the buffer when INIT_TS/INIT_TICK env vars are set.
/// ABI + events: src/interfaces/fee_volatility/RealizedVolatilityInterface.plk
/// (E3 TimepointWritten + E6 WindowChanged topic0s included).
contract DeployRealizedVolatilityMod is PlankDeployBase {
    function run() public returns (address mod) {
        uint256 initTs = vm.envOr("INIT_TS", uint256(0));
        int256 initTick = vm.envOr("INIT_TICK", int256(0));

        vm.startBroadcast(deployerKey());
        mod = plankDeployFFI("src/modules/fee_volatility/RealizedVolatilityMod.plk", plankOpts());
        if (initTs != 0) {
            (bool ok,) = mod.call(
                abi.encodeWithSignature("initializeTWAP(uint32,int24)", uint32(initTs), int24(initTick))
            );
            require(ok, "initializeTWAP failed");
        }
        vm.stopBroadcast();

        console.log("RealizedVolatilityMod :", mod);
        console.log("seeded                :", initTs != 0);
        console.log("E3 topic0             : 0x44d3c76a584327df3a91e46e185e97959195c01202945078eebb23b19c161415");
        console.log("E6 topic0             : 0x046630eacacfeb3f36a64fd8cb291b41c3e78bcd57f8733e12b9afeb69968b47");
    }
}
