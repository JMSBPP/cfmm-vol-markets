// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";

/// @notice Shared base for the module deployment scripts: the SAME module roots the test
/// suite compiles with (PlankTestBase.plankOpts, restated -- scripts must not import test/),
/// plus the anvil deployer convention the off-chain drivers (haskell rpc_api) already use.
///
/// USAGE (local rig): anvil &  then
///   forge script foundry-scripts/deploy/Deploy<Module>.s.sol --rpc-url local --broadcast --ffi --via-ir
/// The printed addresses + the interface files under src/interfaces/ (selectors AND event
/// topic0s) are the complete off-chain contract.
abstract contract PlankDeployBase is Script, PlankDeployer {
    string constant ANVIL_MNEMONIC = "test test test test test test test test test test test junk";
    uint256 constant DEPLOYER_INDEX = 0;

    function plankOpts() internal pure returns (BuildOptions memory opts) {
        opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](6);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
        deps[1] = Dependency("std", "lib/plank-monorepo/std/");
        deps[2] = Dependency("pos_spec", "src/types/pos_spec");
        deps[3] = Dependency("lib", "src/lib");
        deps[4] = Dependency("types", "src/types");
        deps[5] = Dependency("interfaces", "src/interfaces");
        opts.dependencies = deps;
    }

    function deployerKey() internal returns (uint256) {
        // PRIVATE_KEY env overrides the anvil default, so the same scripts serve a real node.
        return vm.envOr("PRIVATE_KEY", vm.deriveKey(ANVIL_MNEMONIC, uint32(DEPLOYER_INDEX)));
    }
}
