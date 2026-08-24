// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console} from "forge-std/console.sol";
import {BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {PlankDeployBase} from "../deploy/PlankDeployBase.s.sol";

/// @notice CHAIN-01 (#26): deploys ShockWriterMod, the deployable Shock emitter the rpc_api live
/// loop drives (offchain/rig/capture-loop.sh, SHOCK_EMITTER=ShockWriter). One mined call to
/// `shock(address,int24,uint24,uint24)` emits a single canonical
/// `Shock(address indexed pool, int24 tickDiff, uint24 txlVolmNormRate, uint24 txlVolmDecay)`
/// (topic0 0x21b0e4f8…55987d64). Deployed via plankDeployFFI as a top-level CREATE so deploy-rig.sh
/// records its address under contracts.ShockWriter exactly as it records the other plank contracts.
///
/// The loop keys eth_getLogs on THIS deployed address (decode_shock refuses WrongEmitter), so the
/// address landing in the manifest is what matters; the pool argument is truthfully driven with
/// contracts.PoolManager and is not used to locate state.
contract DeployShockWriter is PlankDeployBase {
    /// @dev plankOpts() carries the base deps but not the model closure; ShockWriterMod imports
    /// model_libraries (Shock + ShockLib), so add model_interfaces + model_libraries here. Deps
    /// mirror the ShockRoundTrip harness's proven set (scripts must not import test/).
    function shockWriterOpts() internal pure returns (BuildOptions memory opts) {
        opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](8);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
        deps[1] = Dependency("std", "lib/plank-monorepo/std/");
        deps[2] = Dependency("pos_spec", "src/types/pos_spec");
        deps[3] = Dependency("lib", "src/lib");
        deps[4] = Dependency("types", "src/types");
        deps[5] = Dependency("interfaces", "src/interfaces");
        deps[6] = Dependency("model_interfaces", "src/models/mev_tax_model_one/interfaces/");
        deps[7] = Dependency("model_libraries", "src/models/mev_tax_model_one/libraries/");
        opts.dependencies = deps;
    }

    function run() public returns (address shockWriter) {
        vm.startBroadcast(deployerKey());
        shockWriter =
            plankDeployFFI("src/models/mev_tax_model_one/modules/ShockWriterMod.plk", shockWriterOpts());
        vm.stopBroadcast();

        console.log("ShockWriter   :", shockWriter);
        console.log("selector shock: 0x5342da2b  shock(address,int24,uint24,uint24)");
        console.log("event topic0  : 0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64");
    }
}
