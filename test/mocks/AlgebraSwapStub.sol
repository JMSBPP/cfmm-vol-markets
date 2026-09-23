// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @dev Minimal Algebra-shaped pool for StateView `run_swap` define tests (no callback).
contract AlgebraSwapStub {
    bool internal failNext;

    function setFailNext(bool fail) external {
        failNext = fail;
    }

    function swap(address, bool, int256, uint160, bytes calldata)
        external
        view
        returns (int256 amount0, int256 amount1)
    {
        if (failNext) {
            revert("AlgebraSwapStub: swap failed");
        }
        return (1, 1);
    }
}
