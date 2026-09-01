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
///      "unknown module 'interfaces'". These roots MUST stay in lockstep with `PLANK_DEP`
///      in the Makefile -- that is the list `make compile-plank` builds with, and a test that
///      deploys with a different set is not testing what the gate compiled.
///
///      Keep in sync with Makefile:PLANK_DEP.
abstract contract PlankTestBase is Test, PlankDeployer {
    /// @dev The module roots. `pos_spec` is declared separately from `types` because many
    ///      sources still import it bare (`pos_spec::X`) rather than via `types::pos_spec::X`.
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

    /// @dev cfmm-types Plank roots (`lib/cfmm-types`). Uses `types=lib/cfmm-types/src/types`
    ///      so Hook/Create2 compile without colliding with vol-markets `src/types`.
    ///      Keep in sync with Makefile:CFMM_TYPES_PLANK_DEP.
    function cfmmTypesPlankOpts() internal pure returns (BuildOptions memory opts) {
        opts.backend = "sona";

        Dependency[] memory deps = new Dependency[](2);
        deps[0] = Dependency("std", "lib/cfmm-types/lib/plank-monorepo/std/");
        deps[1] = Dependency("types", "lib/cfmm-types/src/types");
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
