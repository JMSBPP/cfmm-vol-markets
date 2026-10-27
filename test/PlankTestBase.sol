// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";

/// @title PlankTestBase
/// @notice Single source of truth for the Plank module roots used when deploying `.plk`
///         entrypoints from Foundry.
///
/// @dev Every `.t.sol` previously hand-rolled its own `Dependency[]`, and they had already
///      drifted apart: none of them declared the `interfaces` root, so any test deploying a
///      module that imports `interfaces::` (e.g. VolOrderManagerMod) failed with
///      "unknown module 'interfaces'". These roots MUST stay in lockstep with `just plank`.
abstract contract PlankTestBase is Test, PlankDeployer {
    /// @dev Same roots as `just plank` (latest plank-target std + TickMoments).
    function plankOpts() internal pure returns (BuildOptions memory opts) {
        opts.backend = "sona";

        Dependency[] memory deps = new Dependency[](3);
        deps[0] = Dependency("std", "plank-target/std/");
        deps[1] = Dependency("TickMoments", "src/TickMoments/");
        deps[2] = Dependency("custom_utils", "src/utils");

        opts.dependencies = deps;
    }

    /// @dev cfmm-types Plank roots (`lib/cfmm-types`). Uses `types=lib/cfmm-types/src/types`
    ///      so Hook/Create2 compile without colliding with vol-markets `src/types`.
    function cfmmTypesPlankOpts() internal pure returns (BuildOptions memory opts) {
        opts.backend = "sona";

        Dependency[] memory deps = new Dependency[](2);
        deps[0] = Dependency("std", "lib/cfmm-types/lib/plank-monorepo/std/");
        deps[1] = Dependency("cfmm_types", "lib/cfmm-types/src/types");
        opts.dependencies = deps;
    }

    /// @notice Compile and deploy a `.plk` entrypoint with the standard module roots.
    function deployPlank(string memory path) internal returns (address) {
        return plankDeployFFI(path, plankOpts());
    }

    /// @notice Deploy a cfmm-types `.plk` entrypoint (Hook miner, etc.).
    function deployCfmmTypesPlank(string memory path) internal returns (address) {
        return plankDeployFFI(path, cfmmTypesPlankOpts());
    }
}
