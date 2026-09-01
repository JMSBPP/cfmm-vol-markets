// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ReactiveTest} from "reactive-test-lib/base/ReactiveTest.sol";
import {PlankTestBase} from "test/PlankTestBase.sol";

contract MarketStateSocketTest is PlankTestBase, ReactiveTest {
    address market_state_socket;
    address price_hook;   // PriceSetterHook.plk -- write_price emits the Swap (via the Plank test helper)

    function setUp() public override {
        super.setUp();
        market_state_socket = deployPlank("src/modules/protocol_integrations/reactive/MarketStateSocket.plk");
        price_hook = deployPlank("src/modules/protocol_integrations/reactive/PriceSetterHook.plk");
    }

    function test_startSocket_subscribesToPoolSwap() public {
        uint256 chainId = 8453;              // Base
        address poolManager = address(0xB00C);
        bytes32 poolId = keccak256("pool");  // == VolMarketKey(V4)'s v4 pool id

        (bool ok,) = market_state_socket.call(
            abi.encodeWithSignature("startSocket(uint256,address,bytes32)", chainId, poolManager, poolId)
        );
        assertTrue(ok, "startSocket failed");

        // MockSystemContract (at SERVICE_ADDR) recorded exactly the pool's Swap subscription
        assertEq(sys.subscriptionCount(), 1, "one subscription");
        (uint256 cid, address c, uint256 t0, uint256 t1, uint256 t2, uint256 t3, address subscriber) =
            sys.subscriptions(0);
        assertEq(cid, chainId, "chain_id");
        assertEq(c, poolManager, "event emitter = PoolManager");
        assertEq(t0, 0x40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f, "Swap topic0");
        assertEq(t1, uint256(poolId), "topic1 = poolId filter");
        assertEq(t2, 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad, "topic2 = REACTIVE_IGNORE");
        assertEq(t3, 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad, "topic3 = REACTIVE_IGNORE");
        assertEq(subscriber, market_state_socket, "subscriber = socket");
    }

    function test_react_writesRealizedVolTimepointOnPriceWrite() public {
        // The callback IS the RealizedVolatility oracle (callback lib plugged in), initialized.
        address vol = deployPlank("src/modules/market_state_measurements/RealizedVolatilityMod.plk");
        vol.call(abi.encodeWithSignature("initializeTWAP(uint32,int24)", uint32(1000), int24(100)));
        market_state_socket.call(abi.encodeWithSignature("setCallback(address)", vol));

        (, bytes memory b0) = vol.staticcall(abi.encodeWithSignature("lastIndex()"));
        uint16 idxBefore = abi.decode(b0, (uint16));

        uint256 originChain = 8453;
        bytes32 poolId = keccak256("pool");
        int24 tick = 12345;
        vm.warp(2000); // fresh block time so write_timepoint records a new sample

        // subscribe to the PriceSetterHook's Swap, then move the price (write_price emits Swap)
        market_state_socket.call(
            abi.encodeWithSignature("startSocket(uint256,address,bytes32)", originChain, price_hook, poolId)
        );
        // write_price emits Swap (via PriceUpdateLogWithSwap.plk) -> react() -> Callback -> proxy ->
        // vol.onPriceUpdate (AUTOMATIC) -> write_timepoint
        triggerAndReact(
            price_hook,
            abi.encodeWithSignature("write_price(bytes32,uint160,int24)", poolId, uint160(1 << 96), tick),
            originChain
        );

        // a RealizedVol timepoint was written by the automatic callback
        (, bytes memory b1) = vol.staticcall(abi.encodeWithSignature("lastIndex()"));
        assertEq(abi.decode(b1, (uint16)), uint16(idxBefore + 1), "a RealizedVol timepoint was written on the price write");
    }
}
