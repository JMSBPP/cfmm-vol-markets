// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";

interface ICEVHistory {
    function intro(uint256 sigmaF, uint256 L, uint256 sqrtP) external view returns (uint256 tick, uint256 sig);

    function introLen(uint256 k) external view returns (uint256);

    function step(uint256 sigmaF, uint256 L, uint256 sqrtP, uint256 k, uint256 j)
        external
        view
        returns (bool ok, uint256 tick, uint256 sig);
}

/// @dev Bulloak-generated names from CEVHistory.btt. Assertions filled.
contract CEVHistoryTest is PlankTestBase {
    ICEVHistory internal harness;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant Q96 = 2 ** 96;
    uint256 internal constant LN_10001 = 99995000333308000000000;
    uint256 internal constant N = 86400 / 2;
    uint256 internal constant L = 10;

    function setUp() public {
        harness = ICEVHistory(deployPlank("test/harness/types/CEVLocalTickVolatilityHarness.plk"));
    }

    function test_WhenKIsZero() external {
        // it should return intro_len 0
        // it should return step None
        assertEq(harness.introLen(0), 0);
        (bool ok,,) = harness.step(RAY, L, Q96, 0, 0);
        assertFalse(ok);
    }

    function test_WhenKIsNOrGreater() external {
        // it should return intro_len 0
        // it should return step None
        assertEq(harness.introLen(N), 0);
        assertEq(harness.introLen(N + 1), 0);
        (bool ok,,) = harness.step(RAY, L, Q96, N, 0);
        assertFalse(ok);
    }

    function test_WhenKIsAValidPrefixAndJIsNotLessThanK() external {
        // it should return intro_len K
        // it should return step None
        uint256 k = 3;
        assertEq(harness.introLen(k), k);
        (bool ok,,) = harness.step(RAY, L, Q96, k, k);
        assertFalse(ok);
    }

    function test_WhenKIsAValidPrefixAndJIsLessThanK() external {
        // it should return intro_len K
        // it should return step Some intro
        uint256 k = 3;
        uint256 j = 1;
        assertEq(harness.introLen(k), k);
        (uint256 expTick, uint256 expSig) = harness.intro(RAY, L, Q96);
        (bool ok, uint256 tick, uint256 sig) = harness.step(RAY, L, Q96, k, j);
        assertTrue(ok);
        assertEq(tick, expTick);
        assertEq(sig, expSig);
        assertEq(tick, uint256(int256(TickMath.getTickAtSqrtRatio(uint160(Q96)))));
        assertEq(sig, (RAY / (L * LN_10001)) * (RAY / (L * LN_10001)));
    }
}
