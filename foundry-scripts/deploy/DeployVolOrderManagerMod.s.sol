// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";
import {PlankDeployBase} from "./PlankDeployBase.s.sol";

/// @notice Deploys VolOrderManagerMod -- the V2 vol-order registry the stochastic order
/// generator drives. ABI + event topic0s: src/interfaces/pos_spec/VolOrderManagerInterface.plk
/// (create_order(uint88,uint24,uint16,uint96) = 0x98d950ec; batch 0x81357911 with the V2
/// input word skew|strike<<16|width<<104|targetVega<<128; E1 VolOrderCreated v2 topic0
/// 0x18bd4d46...). Off-chain layouts: .planning/rpc-api-volorder-v2-HANDOFF.md.
contract DeployVolOrderManagerMod is PlankDeployBase {
    function run() public returns (address mod) {
        vm.startBroadcast(deployerKey());
        mod = plankDeployFFI("src/modules/pos_spec/VolOrderManagerMod.plk", plankOpts());
        vm.stopBroadcast();

        console.log("VolOrderManagerMod :", mod);
        console.log("create_order       : 0x98d950ec (uint88,uint24,uint16,uint96)");
        console.log("create_orders      : 0x81357911 (uint256,uint256[]) V2 word semantics");
        console.log("E1 topic0          : 0x18bd4d460f8957f6b903aec33a3229ee1bf02b6e303c5178c5aa49a70b9de4e6");
    }
}
