// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title CFMMProtocolRegistry
/// @notice Versioned bytecode table: CFMMProtocol enum → factory/entry addresses.
///         Adding a protocol = new deployment; consumers switch registry address.
/// @dev getPool resolves a pool handle only (PoolUninitialized). No hydration.
interface ICFMMProtocolRegistry {
    enum CFMMProtocol {
        UniswapV3,
        UniswapV4,
        Camelot,
        QuickSwap
    }

    /// @notice Resolve pool address/id for (protocol, pair). Does not load fee/ts/slot0.
    /// @dev V4 may return pool id encoded in address-sized word or use a sibling API later.
    function getPool(CFMMProtocol protocol, address tokenA, address tokenB)
        external
        view
        returns (address pool);
}

/// @dev Stub: immutables / dispatch filled in when factory addresses are wired per chain.
contract CFMMProtocolRegistry is ICFMMProtocolRegistry {
    // Placeholder immutables — set in constructor per chain deployment.
    address public immutable uniswapV3Factory;
    address public immutable uniswapV4PoolManager; // or periphery entry
    address public immutable camelotFactory;
    address public immutable quickSwapFactory;

    constructor(
        address uniswapV3Factory_,
        address uniswapV4PoolManager_,
        address camelotFactory_,
        address quickSwapFactory_
    ) {
        uniswapV3Factory = uniswapV3Factory_;
        uniswapV4PoolManager = uniswapV4PoolManager_;
        camelotFactory = camelotFactory_;
        quickSwapFactory = quickSwapFactory_;
    }

    function getPool(CFMMProtocol protocol, address tokenA, address tokenB)
        external
        view
        override
        returns (address pool)
    {
        // Stub: protocol-specific factory getPool / poolByPair not wired yet.
        protocol;
        tokenA;
        tokenB;
        return address(0);
    }
}
