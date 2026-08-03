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
        harness = deployPlank("test/protocol_integrations/MarketIdHarness.plk");
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

    function test_marketId_keyRoundTripsAndIdIsItsHash() public {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0x1111)),
            currency1: Currency.wrap(address(0x2222)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        (bool ok, bytes memory ret) = harness.staticcall(
            abi.encodeWithSignature(
                "marketFromPoolKey(address,address,uint24,int24,address)",
                Currency.unwrap(key.currency0), Currency.unwrap(key.currency1),
                key.fee, key.tickSpacing, address(key.hooks)
            )
        );
        assertTrue(ok, "harness call reverted");
        (bytes32 id, address c0, address c1, uint24 fee, int24 tickSpacing, address hooks) =
            abi.decode(ret, (bytes32, address, address, uint24, int24, address));

        // key round-trips the PoolKey fields
        assertEq(c0, Currency.unwrap(key.currency0), "currency0");
        assertEq(c1, Currency.unwrap(key.currency1), "currency1");
        assertEq(uint256(fee), uint256(key.fee), "fee");
        assertEq(int256(tickSpacing), int256(key.tickSpacing), "tickSpacing");
        assertEq(hooks, address(key.hooks), "hooks");

        // id is the hash of the stored key (and equals the canonical PoolId)
        assertEq(id, PoolId.unwrap(key.toId()), "id == canonical PoolId");
        assertEq(id, keccak256(abi.encode(c0, c1, fee, tickSpacing, hooks)), "id == keccak256(stored key)");
    }
}
