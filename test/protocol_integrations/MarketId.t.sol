// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";        // FFI deployPlank harness
import {PoolKey} from "univ4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "univ4-core/types/PoolId.sol";
import {Currency} from "univ4-core/types/Currency.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";

contract MarketIdTest is PlankTestBase {
    using PoolIdLibrary for PoolKey;

    // FFI-deployed Plank harness exposing: idFromPoolKey(address,address,uint24,int24,address) -> bytes32
    address internal harness;

    function setUp() public {
        harness = deployPlank("src/types/protocol_integrations/MarketIdHarness.plk");
    }

    function test_marketId_idEqualsCanonicalUniV4PoolId() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0x1111)),
            currency1: Currency.wrap(address(0x2222)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        bytes32 expected = PoolId.unwrap(key.toId());          // == keccak256(abi.encode(key))

        (bool ok, bytes memory ret) = harness.staticcall(
            abi.encodeWithSignature(
                "idFromPoolKey(address,address,uint24,int24,address)",
                Currency.unwrap(key.currency0), Currency.unwrap(key.currency1),
                key.fee, key.tickSpacing, address(key.hooks)
            )
        );
        assertTrue(ok, "harness call reverted");
        assertEq(abi.decode(ret, (bytes32)), expected, "MarketId.id must equal canonical univ4 PoolId");
    }
}
