// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {VolatilityOracle} from "@cryptoalgebra/volatility-oracle-plugin/libraries/VolatilityOracle.sol";

/// @title AlgebraVolatilityKernelMock
/// @notice Exposes Algebra's `internal pure` VolatilityOracle._volatilityOnRange as an external
///         function, so the variance kernel can be differentially tested against Plank's
///         calculate_realized_volatility in isolation from the ring buffer and storage.
///
/// @dev NAME: deliberately NOT `MockVolatilityOracle` -- the package already ships
///      contracts/test/MockVolatilityOracle.sol (an IVolatilityOracle tick-cumulative double
///      that does NOT expose this kernel). Shadowing it would be a permanent source of "which
///      mock is this?" confusion.
///
/// @dev PRAGMA: pinned `=0.8.20` to match VolatilityOracle.sol's own pin, not `^0.8.0`.
///
/// @dev This is a THIN wrapper on purpose. It adds no bounds checks, no masking and no uint88
///      truncation: the point is to observe Algebra's kernel EXACTLY as production calls it.
///      The uint88 claim is Algebra's own comment ("always fits 88 bits" GIVEN the int24/uint32
///      preconditions); returning the full uint256 lets the Phase 9 fuzz assert on the wider,
///      strictly stronger surface.
contract AlgebraVolatilityKernelMock {
    /// @notice Algebra's argument order: (dt, tick0, tick1, avgTick0, avgTick1).
    /// @dev NOTE this order DIFFERS from Plank's calculate_realized_volatility
    ///      (avg_tick0, avg_tick1, tick0, tick1, dt). Do not "align" them.
    /// @dev dt MUST be >= 1. At dt = 0 this reverts with Panic 0x12 (division by zero) -- Solidity's
    ///      `/` reverts even inside `unchecked` -- while the EVM's SDIV returns 0 silently. That is
    ///      a KNOWN, EXCLUDED divergence, not a bug to paper over.
    function volatilityOnRange(
        int256 dt,
        int256 tick0,
        int256 tick1,
        int256 avgTick0,
        int256 avgTick1
    ) external pure returns (uint256) {
        return VolatilityOracle._volatilityOnRange(dt, tick0, tick1, avgTick0, avgTick1);
    }
}
