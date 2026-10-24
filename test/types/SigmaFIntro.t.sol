// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {console2} from "forge-std/console2.sol";

interface ISigmaFIntro {
    function intro(uint256) external returns (uint256);
}

/// @dev Bulloak-generated names from SigmaFIntro.btt. Assertions filled.
/// Admissible σ_F^{RAY} band matches CEVStateRunnerRunJ (#147): [1e-6, 1e-3] · RAY.
/// Review: single when-leaf with multiple it-comments (#142).
contract SigmaFIntroTest is PlankTestBase {
    ISigmaFIntro internal harness;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant RAY_UNIT =
        0x0000000000000000000000000000000000000000033b2e3c9fd0803ce8000000;
    /// Admissible σ_F as fraction of L (SQD-backed): [1e-6, 1e-3].
    uint256 internal constant SIGMA_F_HUMAN_MIN = 1e21; // 1e-6 * RAY
    uint256 internal constant SIGMA_F_HUMAN_MAX = 1e24; // 1e-3 * RAY

    function setUp() public {
        harness = ISigmaFIntro(deployPlank("test/harness/types/SigmaFHarness.plk"));
    }

    function test_WhenGivenRayScaleWordsIncludingAdmissibleSigma_F(uint256 sigmaFRaw) external {
        // it should round-trip rayVal through intro
        assertEq(harness.intro(0), 0);
        assertEq(harness.intro(RAY_UNIT), RAY_UNIT);
        assertEq(harness.intro(42), 42);

        // it should round-trip admissible sigma_F min 1e21
        assertEq(harness.intro(SIGMA_F_HUMAN_MIN), SIGMA_F_HUMAN_MIN);

        // it should round-trip admissible sigma_F max 1e24
        assertEq(harness.intro(SIGMA_F_HUMAN_MAX), SIGMA_F_HUMAN_MAX);

        // it should round-trip fuzzed admissible sigma_F
        uint256 sigmaF = bound(sigmaFRaw, SIGMA_F_HUMAN_MIN, SIGMA_F_HUMAN_MAX);
        console2.log("\\(\\sigma_F\\):", sigmaF / (RAY / 1e6));
        console2.log("\\(\\sigma_F^{RAY}\\):", sigmaF);
        assertEq(harness.intro(sigmaF), sigmaF);
    }
}
