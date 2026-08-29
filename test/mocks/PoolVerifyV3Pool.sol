// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract PoolVerifyV3Pool {
    uint24 public immutable FEE;
    int24 public immutable TICK_SPACING;

    constructor(uint24 fee_, int24 tickSpacing_) {
        FEE = fee_;
        TICK_SPACING = tickSpacing_;
    }

    function fee() external view returns (uint24) {
        return FEE;
    }

    function tickSpacing() external view returns (int24) {
        return TICK_SPACING;
    }
}
