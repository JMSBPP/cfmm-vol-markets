// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ReactiveTest} from "reactive-test-lib/base/ReactiveTest.sol";
import {PlankTestBase} from "test/PlankTestBase.sol";

/// @notice Minimal origin emitting the exact univ4 Swap event (topic0 == 0x40e9…112f).
contract SwapEmitter {
    event Swap(
        bytes32 indexed id, address indexed sender,
        int128 amount0, int128 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick, uint24 fee
    );
    function emitSwap(bytes32 id, uint160 sqrtPriceX96, int24 tick) external {
        emit Swap(id, msg.sender, int128(1), int128(-1), sqrtPriceX96, uint128(1e18), tick, uint24(3000));
    }
}

contract MarketStateSocketTest is PlankTestBase, ReactiveTest{
    // note: This necesarily is a fork test, we are monittring Base Uni v4 pool manager where there
    // is the deepest more active panoptic pool
    address market_state_socket;
    function setUp() public override {
        super.setUp();
	market_state_socket = deployPlank("src/modules/protocol_integrations/MarketStateSocket.plk");
    }

    function test_startSocket_subscribesToPoolSwap() public {
        uint256 chainId = 8453;              // Base
        address poolManager = address(0xB00C);
        bytes32 poolId = keccak256("pool");  // == MarketId.id

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

    function test_react_deliversSwapPriceUpdateToCallback() public {
        address cb = deployPlank("src/modules/protocol_integrations/CallbackRealizedVolatilityMod.plk");
        (bool okSet,) = market_state_socket.call(abi.encodeWithSignature("setCallback(address)", cb));
        assertTrue(okSet, "setCallback failed");

        SwapEmitter pool = new SwapEmitter();
        uint256 originChain = 8453;
        bytes32 poolId = keccak256("pool");
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // 1.0
        int24 tick = -12345;

        // subscribe to THIS pool's Swap, then drive a real Swap through the reactive lifecycle
        (bool okStart,) = market_state_socket.call(
            abi.encodeWithSignature("startSocket(uint256,address,bytes32)", originChain, address(pool), poolId)
        );
        assertTrue(okStart, "startSocket failed");
        triggerAndReact(
            address(pool),
            abi.encodeWithSignature("emitSwap(bytes32,uint160,int24)", poolId, sqrtPriceX96, tick),
            originChain
        );

        // the callback RECEIVED the forwarded price update
        (bool okRead, bytes memory ret) = cb.staticcall(abi.encodeWithSignature("lastUpdate()"));
        assertTrue(okRead, "lastUpdate failed");
        (bytes32 gotPool, uint160 gotSqrtP, int24 gotTick, uint256 count) =
            abi.decode(ret, (bytes32, uint160, int24, uint256));
        assertEq(gotPool, poolId, "poolId");
        assertEq(gotSqrtP, sqrtPriceX96, "sqrtPrice");
        assertEq(int256(gotTick), int256(tick), "tick");
        assertEq(count, 1, "callback received exactly once");
    }
}
