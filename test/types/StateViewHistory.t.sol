// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {IntegralPoolBootstrap} from "test/helpers/Algebra/IntegralPoolBootstrap.sol";
import {IAlgebraPoolState} from "@cryptoalgebra/integral-core/interfaces/pool/IAlgebraPoolState.sol";

interface IStateViewHistory {
    function introLen(uint256 k) external view returns (uint256);

    function step(address pool, uint256 fee, uint256 tickSpacing, uint256 tInit, uint256 k, uint256 j)
        external
        view
        returns (bool ok, uint256 t, uint256 tick, uint256 sqrtP);
}

/// @dev Bulloak-generated names from StateViewHistory.btt. Assertions filled.
contract StateViewHistoryTest is PlankTestBase {
    IStateViewHistory internal harness;

    address internal constant FAKE_POOL = address(0xB001);
    uint256 internal constant FEE = 500;
    uint256 internal constant TICK_SPACING = 60;
    uint256 internal constant BAR_DT = 2;
    uint256 internal constant N = 86400 / BAR_DT;

    function setUp() public {
        harness = IStateViewHistory(deployPlank("test/harness/types/StateViewHarness.plk"));
    }

    function test_WhenKIsZero() external {
        // it should return intro_len 0
        // it should return step None
        assertEq(harness.introLen(0), 0);
        (bool ok,,,) = harness.step(FAKE_POOL, FEE, TICK_SPACING, block.timestamp, 0, 0);
        assertFalse(ok);
    }

    function test_WhenKIsNOrGreater() external {
        // it should return intro_len 0
        // it should return step None
        assertEq(harness.introLen(N), 0);
        assertEq(harness.introLen(N + 1), 0);
        (bool ok,,,) = harness.step(FAKE_POOL, FEE, TICK_SPACING, block.timestamp, N, 0);
        assertFalse(ok);
    }

    function test_WhenKIsAValidPrefixAndJIsNotLessThanK() external {
        // it should return intro_len K
        // it should return step None
        uint256 k = 3;
        assertEq(harness.introLen(k), k);
        (bool ok,,,) = harness.step(FAKE_POOL, FEE, TICK_SPACING, block.timestamp, k, k);
        assertFalse(ok);
    }

    function test_WhenKIsAValidPrefixAndJIsLessThanK() external {
        // it should return intro_len K
        // it should return step Some cell at t_init plus j times dt
        IntegralPoolBootstrap.ReadyPool memory ready = IntegralPoolBootstrap.bootstrap(vm);
        uint256 tInit = block.timestamp;
        uint256 k = 3;
        uint256 j = 1;

        assertEq(harness.introLen(k), k);

        (uint160 sqrtPriceX96, int24 tick,,,,) = IAlgebraPoolState(ready.pool).globalState();

        (bool ok, uint256 t, uint256 tickOut, uint256 sqrtOut) =
            harness.step(ready.pool, ready.fee, ready.tickSpacing, tInit, k, j);

        assertTrue(ok);
        assertEq(t, tInit + j * BAR_DT);
        assertEq(tickOut, uint256(int256(tick)));
        assertEq(sqrtOut, uint256(sqrtPriceX96));
    }
}
