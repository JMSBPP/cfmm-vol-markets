// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {
    CFMMProtocolRegistry,
    ICFMMProtocolRegistry
} from "src/modules/CFMMProtocolRegistry.sol";

/// @dev Resolve-only stub suite — factory dispatch wired in a follow-up.
contract CFMMProtocolRegistryTest is Test {
    CFMMProtocolRegistry internal registry;

    function setUp() public {
        registry = new CFMMProtocolRegistry(
            address(0x1), address(0x2), address(0x3), address(0x4)
        );
    }

    function test__unit__immutablesPinnedInBytecode() public view {
        assertEq(registry.uniswapV3Factory(), address(0x1));
        assertEq(registry.uniswapV4PoolManager(), address(0x2));
        assertEq(registry.camelotFactory(), address(0x3));
        assertEq(registry.quickSwapFactory(), address(0x4));
    }

    function test__unit__getPoolStubReturnsZero() public view {
        address pool = registry.getPool(
            ICFMMProtocolRegistry.CFMMProtocol.UniswapV3, address(0xA), address(0xB)
        );
        assertEq(pool, address(0));
    }
}
