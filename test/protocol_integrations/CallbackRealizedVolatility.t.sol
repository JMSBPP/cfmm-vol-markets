// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

contract CallbackRealizedVolatilityTest is PlankTestBase {
    address cb;
    function setUp() public { cb = deployPlank("src/modules/protocol_integrations/CallbackRealizedVolatilityMod.plk"); }

    function test_onPriceUpdate_acksReceipt() public {
        bytes32 poolId = keccak256("pool");
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // 1.0
        int24 tick = -12345;

        (bool ok,) = cb.call(
            abi.encodeWithSignature(
                "onPriceUpdate(address,bytes32,uint160,int24)", address(0xBEEF), poolId, sqrtPriceX96, tick
            )
        );
        assertTrue(ok, "onPriceUpdate failed");

        // ACK: the callback recorded the receipt (placeholder for the RealizedVol timepoint write)
        (bool ok2, bytes memory ret) = cb.staticcall(abi.encodeWithSignature("lastUpdate()"));
        assertTrue(ok2, "lastUpdate failed");
        (bytes32 gotPool, uint160 gotSqrtP, int24 gotTick, uint256 count) =
            abi.decode(ret, (bytes32, uint160, int24, uint256));
        assertEq(gotPool, poolId, "poolId");
        assertEq(gotSqrtP, sqrtPriceX96, "sqrtPriceX96");
        assertEq(int256(gotTick), int256(tick), "tick");
        assertEq(count, 1, "updateCount");
    }
}
