// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/// @title IssuanceRefMock
/// @notice Reference for VegaIssuanceLib. haircutRiskPrice/issueShares mirror the Plank lib
///         (ceil then floor) over solady's 512-bit fullMulDiv; `composed` is the tolerance-0
///         diff target; `direct` is the one-sided `composed <= direct` bound (risk.md §4).
///         Both paths use fullMulDiv so NO artificial deposit cap shrinks the corpus.
/// @dev solady's fullMulDivUp is the IDENTICAL round-up primitive to full_math.plk's
///      mulDivRoundingUp: both compute floor via fullMulDiv/mulDiv, add 1 iff mulmod(x,y,d)!=0,
///      revert on d==0 (via the floor call), and revert if the +1 would overflow to 2^256.
///      Confirmed by reading FixedPointMathLib.fullMulDivUp against full_math.plk:58-67.
contract IssuanceRefMock {
    uint256 internal constant Q96 = 1 << 96; // 2^96

    function haircutRiskPrice(uint256 oracleX96, uint256 hX96) public pure returns (uint256) {
        require(oracleX96 != 0, "oracle==0");
        require(hX96 < Q96, "h>=1");
        return FixedPointMathLib.fullMulDivUp(oracleX96, Q96, Q96 - hX96); // ceil
    }

    function issueShares(uint256 deposit, uint256 pRiskX96) public pure returns (uint256) {
        return FixedPointMathLib.fullMulDiv(deposit, Q96, pRiskX96); // floor; reverts pRisk==0
    }

    function composed(uint256 deposit, uint256 oracleX96, uint256 hX96) external pure returns (uint256) {
        return issueShares(deposit, haircutRiskPrice(oracleX96, hX96));
    }

    function direct(uint256 deposit, uint256 oracleX96, uint256 hX96) external pure returns (uint256) {
        require(oracleX96 != 0, "oracle==0");
        require(hX96 < Q96, "h>=1");
        return FixedPointMathLib.fullMulDiv(deposit, Q96 - hX96, oracleX96); // floor
    }
}
