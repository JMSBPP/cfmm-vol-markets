// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";

interface ICEVLocalTickVolatility {
    error ZeroLiquidity();
    error ZeroSqrtPrice();
    error SigmaOverflowU88();

    function intro(uint256 sigmaF, uint256 L, uint256 sqrtP) external view returns (uint256 tick, uint256 sig);
}

/// @dev Bulloak-generated names from CEVLocalTickVolatility.btt. Assertions filled.
contract CEVLocalTickVolatilityTest is PlankTestBase {
    ICEVLocalTickVolatility internal harness;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant Q96 = 2 ** 96;
    uint256 internal constant LN_10001 = 99995000333308000000000;

    function setUp() public {
        harness = ICEVLocalTickVolatility(deployPlank("test/harness/types/CEVLocalTickVolatilityHarness.plk"));
    }

    function test_WhenLIsZero() external {
        // it should revert ZeroLiquidity
        vm.expectRevert(ICEVLocalTickVolatility.ZeroLiquidity.selector);
        harness.intro(RAY, 0, Q96);
    }

    function test_WhenLIsNonzeroAndSqrt_pIsZero() external {
        // it should revert ZeroSqrtPrice
        vm.expectRevert(ICEVLocalTickVolatility.ZeroSqrtPrice.selector);
        harness.intro(RAY, 10, 0);
    }

    function test_WhenLAndSqrt_pAreNonzeroAndSigmaOverflowsU88() external {
        // it should revert SigmaOverflowU88
        vm.expectRevert(ICEVLocalTickVolatility.SigmaOverflowU88.selector);
        harness.intro(RAY, 1, uint256(TickMath.MIN_SQRT_RATIO));
    }

    function test_WhenLAndSqrt_pAreNonzeroAndSigmaFitsU88() external {
        // it should return tick Tick(sqrt_p) and sigma
        uint256 L = 10;
        uint256 sqrtP = Q96;
        uint256 ratio = RAY / (L * LN_10001);
        (uint256 tick, uint256 sig) = harness.intro(RAY, L, sqrtP);
        assertEq(tick, uint256(int256(TickMath.getTickAtSqrtRatio(uint160(sqrtP)))));
        assertEq(sig, ratio * ratio);
    }
}
