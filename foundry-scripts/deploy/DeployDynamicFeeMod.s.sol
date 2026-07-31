// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";
import {PlankDeployBase} from "./PlankDeployBase.s.sol";

/// @notice Deploys DynamicFeeMod (module-keyed AdaptiveFee). Owner is TOFU on the first
/// initializeDynamicFee call -- the DEPLOYER makes that call here with the default Algebra
/// config so ownership is captured in the same broadcast (research-rig hygiene).
/// ABI + events: src/interfaces/premium/DynamicFeeInterface.plk (E4 topic0 included).
contract DeployDynamicFeeMod is PlankDeployBase {
    function run() public returns (address mod) {
        vm.startBroadcast(deployerKey());
        mod = plankDeployFFI("src/modules/premium/DynamicFeeMod.plk", plankOpts());
        // Algebra default config (alpha1, alpha2, beta1, beta2, gamma1, gamma2, baseFee)
        (bool ok,) = mod.call(
            abi.encodeWithSignature(
                "initializeDynamicFee((uint16,uint16,uint32,uint32,uint16,uint16,uint16))",
                uint16(2900), uint16(12000), uint32(360), uint32(60000), uint16(59), uint16(8500), uint16(100)
            )
        );
        require(ok, "initializeDynamicFee failed");
        vm.stopBroadcast();

        console.log("DynamicFeeMod :", mod);
        console.log("owner (TOFU)  : the deployer, captured in-broadcast");
        console.log("E4 topic0     : 0x0b849672f272805103d1934909aaee0c4e1400438ff5365f6d9d147cb07ed6cf");
    }
}
