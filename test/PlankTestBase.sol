// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseTest} from "../plank-target/plankc/plank-diff-tests/test/BaseTest.sol";
import {BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {PushableStringsLib} from "plank-foundry-deployer/mini-vm.sol";

/// @title PlankTestBase
/// @notice Single source of truth for the Plank module roots used when deploying `.plk`
///         entrypoints from Foundry.
///
/// @dev Every `.t.sol` previously hand-rolled its own `Dependency[]`, and they had already
///      drifted apart: none of them declared the `interfaces` root, so any test deploying a
///      module that imports `interfaces::` (e.g. VolOrderManagerMod) failed with
///      "unknown module 'interfaces'". These roots MUST stay in lockstep with `just plank`.
///
/// @dev Inherits plank-diff-tests `BaseTest` for `deployCodeTo` (etch initcode → call → etch
///      runtime). Do not `override` BaseTest.`plank` / `baseBuildOptions` — those are no longer
///      virtual on plank main; use `compilePlank` / `plankOpts` instead.
abstract contract PlankTestBase is BaseTest {
    /// @dev Same roots as `just plank` (latest plank-target std + TickMoments).
    function plankOpts() internal pure returns (BuildOptions memory opts) {
        opts.backend = "sona";

        Dependency[] memory deps = new Dependency[](10);
        deps[0] = Dependency("std", "plank-target/std/");
        deps[1] = Dependency("TickMoments", "src/TickMoments/");
        deps[2] = Dependency("custom_utils", "src/utils");
        deps[3] = Dependency("Asset", "src/Asset");
        deps[4] = Dependency("ProtocolSync", "src/ProtocolSync/");
        deps[5] = Dependency("Controllers", "src/Controllers/");
        deps[6] = Dependency("Exposure", "src/Exposure/");
        deps[7] = Dependency("Premium", "src/Premium");
        deps[8] = Dependency("Instrument", "src/Instrument");
        deps[9] = Dependency("app", "src/app");

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

    /// @notice Compile a `.plk` entrypoint with vol-markets module roots (not BaseTest.plank).
    function compilePlank(string memory sourcePath) internal returns (bytes memory) {
        return plankBuildFFI(sourcePath, plankOpts());
    }

    function compilePlank(string memory sourcePath, string memory evmVersionOverride)
        internal
        returns (bytes memory)
    {
        BuildOptions memory options = plankOpts();
        if (bytes(evmVersionOverride).length != 0) {
            options = options.withEvmVersion(evmVersionOverride);
        }
        return plankBuildFFI(sourcePath, options);
    }

    /// @notice Compile and deploy a `.plk` entrypoint with the standard module roots.
    function deployPlank(string memory path) internal returns (address) {
        return plankDeployFFI(path, plankOpts());
    }

    function deployPlank(string memory path, bytes memory extraArgs) internal returns (address) {
        BuildOptions memory opts = plankOpts();
        opts.extraArgs = PushableStringsLib.push(opts.extraArgs, string(extraArgs));
        return plankDeployFFI(path, opts);
    }

    /// @notice Deploy a cfmm-types `.plk` entrypoint (Hook miner, etc.).
    function deployCfmmTypesPlank(string memory path) internal returns (address) {
        return plankDeployFFI(path, cfmmTypesPlankOpts());
    }
}
