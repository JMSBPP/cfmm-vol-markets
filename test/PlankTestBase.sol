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
/// @dev Inherits plank-diff-tests `BaseTest` (`deployCodeTo`, `plank`) so etched Plank
///      contracts get runtime bytecode (initcode → call → etch return data), not raw initcode.
abstract contract PlankTestBase is BaseTest {
    /// @dev Same roots as `just plank` (latest plank-target std + TickMoments).
    function plankOpts() internal pure returns (BuildOptions memory opts) {
        opts.backend = "sona";

        Dependency[] memory deps = new Dependency[](5);
        deps[0] = Dependency("std", "plank-target/std/");
        deps[1] = Dependency("TickMoments", "src/TickMoments/");
        deps[2] = Dependency("custom_utils", "src/utils");
	deps[3] = Dependency("Asset", "src/Asset");
	deps[4] = Dependency("LiquidityKernel", "src/LiquidityKernel/");
	
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

    function baseBuildOptions() internal pure override returns (BuildOptions memory) {
        return plankOpts();
    }

    function plankBuild(string memory sourcePath, BuildOptions memory options)
        internal
        override
        returns (bytes memory)
    {
        return plankBuildFFI(sourcePath, options);
    }

    function plank(string memory sourcePath) internal override returns (bytes memory) {
        return plankBuildFFI(sourcePath, plankOpts());
    }

    function plank(string memory sourcePath, string memory evmVersionOverride)
        internal
        override
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
