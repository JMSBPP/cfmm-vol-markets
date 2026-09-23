// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {IntegralPoolBootstrap} from "test/helpers/Algebra/IntegralPoolBootstrap.sol";
import {IAlgebraPoolState} from "@cryptoalgebra/integral-core/interfaces/pool/IAlgebraPoolState.sol";

interface ICEVHistory {
    function introLen(uint256 k) external view returns (uint256);

    function introFromState(
        uint256 sigmaF,
        uint256 chunkTickSpacing,
        uint256 packedChunk,
        address pool,
        uint256 fee,
        uint256 poolTickSpacing,
        uint256 tInit,
        uint256 k,
        uint256 j
    ) external view returns (bool ok, uint256 tick, uint256 sig);

    function stepFromState(
        uint256 sigmaF,
        uint256 chunkTickSpacing,
        uint256 packedChunk,
        address pool,
        uint256 fee,
        uint256 poolTickSpacing,
        uint256 tInit,
        uint256 k,
        uint256 j
    )
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
    uint256 internal constant T_INIT = 1_000;
    uint256 internal constant SPACING = 60;
    uint256 internal constant PACKED = (uint256(uint24(int24(-60))) << 232)
        | (uint256(uint24(int24(60))) << 208) | L;
    address internal constant UNUSED_POOL = address(0xB001);

    function setUp() public {
        harness = ICEVHistory(deployPlank("test/harness/types/CEVLocalTickVolatilityHarness.plk"));
    }

    function test_WhenKIsZero() external {
        // it should return intro_len 0
        // it should return step None
        assertEq(harness.introLen(0), 0);
        (bool ok,,) =
            harness.stepFromState(RAY, SPACING, PACKED, UNUSED_POOL, 500, SPACING, T_INIT, 0, 0);
        assertFalse(ok);
    }

    function test_WhenKIsNOrGreater() external {
        // it should return intro_len 0
        // it should return step None
        assertEq(harness.introLen(N), 0);
        assertEq(harness.introLen(N + 1), 0);
        (bool ok,,) =
            harness.stepFromState(RAY, SPACING, PACKED, UNUSED_POOL, 500, SPACING, T_INIT, N, 0);
        assertFalse(ok);
    }

    function test_WhenKIsAValidPrefixAndJIsNotLessThanK() external {
        // it should return intro_len K
        // it should return step None
        uint256 k = 3;
        assertEq(harness.introLen(k), k);
        (bool ok,,) =
            harness.stepFromState(RAY, SPACING, PACKED, UNUSED_POOL, 500, SPACING, T_INIT, k, k);
        assertFalse(ok);
    }

    function test_WhenKIsAValidPrefixAndJIsLessThanK() external {
        // it should return intro_len K
        // it should return step Some intro from the shared chunk and observation j
        IntegralPoolBootstrap.ReadyPool memory ready = IntegralPoolBootstrap.bootstrap(vm);
        uint256 k = 3;
        uint256 j = 1;
        assertEq(harness.introLen(k), k);
        (bool introOk, uint256 expTick, uint256 expSig) = harness.introFromState(
            RAY,
            ready.tickSpacing,
            PACKED,
            ready.pool,
            ready.fee,
            ready.tickSpacing,
            T_INIT,
            k,
            j
        );
        (bool ok, uint256 tick, uint256 sig) = harness.stepFromState(
            RAY,
            ready.tickSpacing,
            PACKED,
            ready.pool,
            ready.fee,
            ready.tickSpacing,
            T_INIT,
            k,
            j
        );
        (uint160 sqrtP, int24 observedTick,,,,) = IAlgebraPoolState(ready.pool).globalState();
        uint256 ratio = (((RAY * Q96) / uint256(sqrtP)) / L) / LN_10001;

        assertTrue(introOk);
        assertTrue(ok);
        assertEq(tick, expTick);
        assertEq(sig, expSig);
        assertEq(tick, uint256(int256(observedTick)));
        assertEq(sig, ratio * ratio);
    }
}
