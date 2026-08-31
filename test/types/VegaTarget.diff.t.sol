// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankDiffTestBase} from "../diff/PlankDiffTestBase.sol";
import {LiquidityChunkTest} from "panoptic-v2-core/test/foundry/types/LiquidityChunk.t.sol";
import {LiquidityChunk} from "@types/LiquidityChunk.sol";
import {VegaTargetTest} from "./VegaTargetTest.t.sol";

/// @dev Shared scalar API for differential exec — Panoptic and Plank oracles both implement it.
interface IChunkOracle {
    function packedAddLiq(uint128 amount) external view returns (uint256 packed, uint256 liq);
    function packedAddTickLower(int24 tickLower_) external view returns (uint256 packed, int256 tick);
    function packedAddTickUpper(int24 tickUpper_) external view returns (uint256 packed, int256 tick);
    function packedFromTicks(int24 tickLower_, int24 tickUpper_, uint128 amount)
        external
        view
        returns (uint256 packed, int256 tl, int256 tu, uint256 liq);
    function packedUpdateTickLower(int24 y1, int24 y2) external view returns (uint256 packed1, uint256 packed2);
    function packedUpdateTickUpper(int24 y1, int24 y2) external view returns (uint256 packed1, uint256 packed2);
    function tickLowerOf(uint256 packed) external view returns (int256);
    function tickUpperOf(uint256 packed) external view returns (int256);
    function vegaAmountOf(uint256 packed) external view returns (uint256);
}

/// @dev Panoptic oracle — extends {LiquidityChunkTest}; harness is the reference implementation.
contract PanopticChunkOracle is LiquidityChunkTest, IChunkOracle {
    function packedAddLiq(uint128 amount) external view returns (uint256 packed, uint256 liq) {
        LiquidityChunk x = harness.addLiquidity(LiquidityChunk.wrap(0), amount);
        packed = uint256(LiquidityChunk.unwrap(x));
        liq = harness.liquidity(x);
    }

    function packedAddTickLower(int24 tickLower_) external view returns (uint256 packed, int256 tick) {
        LiquidityChunk x = harness.addTickLower(LiquidityChunk.wrap(0), tickLower_);
        packed = uint256(LiquidityChunk.unwrap(x));
        tick = harness.tickLower(x);
    }

    function packedAddTickUpper(int24 tickUpper_) external view returns (uint256 packed, int256 tick) {
        LiquidityChunk x = harness.addTickUpper(LiquidityChunk.wrap(0), tickUpper_);
        packed = uint256(LiquidityChunk.unwrap(x));
        tick = harness.tickUpper(x);
    }

    function packedFromTicks(int24 tickLower_, int24 tickUpper_, uint128 amount)
        external
        view
        returns (uint256 packed, int256 tl, int256 tu, uint256 liq)
    {
        LiquidityChunk x = harness.createChunk(tickLower_, tickUpper_, amount);
        packed = uint256(LiquidityChunk.unwrap(x));
        tl = harness.tickLower(x);
        tu = harness.tickUpper(x);
        liq = harness.liquidity(x);
    }

    function packedUpdateTickLower(int24 y1, int24 y2) external view returns (uint256 packed1, uint256 packed2) {
        LiquidityChunk x = harness.updateTickLower(LiquidityChunk.wrap(0), y1);
        packed1 = uint256(LiquidityChunk.unwrap(x));
        x = harness.updateTickLower(x, y2);
        packed2 = uint256(LiquidityChunk.unwrap(x));
    }

    function packedUpdateTickUpper(int24 y1, int24 y2) external view returns (uint256 packed1, uint256 packed2) {
        LiquidityChunk x = harness.updateTickUpper(LiquidityChunk.wrap(0), y1);
        packed1 = uint256(LiquidityChunk.unwrap(x));
        x = harness.updateTickUpper(x, y2);
        packed2 = uint256(LiquidityChunk.unwrap(x));
    }

    function tickLowerOf(uint256 packed) external view returns (int256) {
        return harness.tickLower(LiquidityChunk.wrap(packed));
    }

    function tickUpperOf(uint256 packed) external view returns (int256) {
        return harness.tickUpper(LiquidityChunk.wrap(packed));
    }

    function vegaAmountOf(uint256 packed) external view returns (uint256) {
        return harness.liquidity(LiquidityChunk.wrap(packed));
    }
}

/// @dev Plank oracle — extends {VegaTargetTest}; harness is the Plank-deployed entrypoint.
contract VegaTargetOracle is VegaTargetTest, IChunkOracle {
    function packedAddLiq(uint128 amount) external view returns (uint256 packed, uint256 liq) {
        packed = harness.addVegaAmount(harness.packEmpty(), amount);
        liq = harness.vegaAmount(packed);
    }

    function packedAddTickLower(int24 tickLower_) external view returns (uint256 packed, int256 tick) {
        packed = harness.addTickLower(harness.packEmpty(), int256(tickLower_));
        tick = harness.tickLower(packed);
    }

    function packedAddTickUpper(int24 tickUpper_) external view returns (uint256 packed, int256 tick) {
        packed = harness.addTickUpper(harness.packEmpty(), int256(tickUpper_));
        tick = harness.tickUpper(packed);
    }

    function packedFromTicks(int24 tickLower_, int24 tickUpper_, uint128 amount)
        external
        view
        returns (uint256 packed, int256 tl, int256 tu, uint256 liq)
    {
        packed = harness.packFromTicks(int256(tickLower_), int256(tickUpper_), amount);
        tl = harness.tickLower(packed);
        tu = harness.tickUpper(packed);
        liq = harness.vegaAmount(packed);
    }

    function packedUpdateTickLower(int24 y1, int24 y2) external view returns (uint256 packed1, uint256 packed2) {
        packed1 = harness.updateTickLower(harness.packEmpty(), int256(y1));
        packed2 = harness.updateTickLower(packed1, int256(y2));
    }

    function packedUpdateTickUpper(int24 y1, int24 y2) external view returns (uint256 packed1, uint256 packed2) {
        packed1 = harness.updateTickUpper(harness.packEmpty(), int256(y1));
        packed2 = harness.updateTickUpper(packed1, int256(y2));
    }

    function tickLowerOf(uint256 packed) external view returns (int256) {
        return harness.tickLower(packed);
    }

    function tickUpperOf(uint256 packed) external view returns (int256) {
        return harness.tickUpper(packed);
    }

    function vegaAmountOf(uint256 packed) external view returns (uint256) {
        return harness.vegaAmount(packed);
    }
}

/// @title VegaTargetDiffTest
/// @notice Differential: Panoptic {LiquidityChunkTest} vs Plank {VegaTargetTest}, tol 0.
///
/// @dev Pattern from Seaport {FulfillAvailableAdvancedOrderCriteria}: same `exec` twice with
///      the implementation swapped in `Context.oracle`, then explicit packed-word equality.
contract VegaTargetDiffTest is PlankDiffTestBase {
    PanopticChunkOracle internal panoptic;
    VegaTargetOracle internal plank;

    struct Context {
        IChunkOracle oracle;
        int24 tickLower;
        int24 tickUpper;
        uint128 amount;
    }

    function setUp() public {
        panoptic = new PanopticChunkOracle();
        panoptic.setUp();
        plank = new VegaTargetOracle();
        plank.setUp();
    }

    /// @dev Seaport {FulfillAvailableAdvancedOrderCriteria.test}: stateless exec via assertPass.
    function test(function(Context memory) external fn, Context memory context) internal {
        try fn(context) {} catch (bytes memory reason) {
            assertPass(reason);
        }
    }

    function test_differential__Success_AddLiq(uint128 y) public {
        Context memory ctx = Context({oracle: panoptic, tickLower: 0, tickUpper: 0, amount: y});
        test(this.execAddLiq, ctx);
        ctx.oracle = plank;
        test(this.execAddLiq, ctx);
        _assertPackedAddLiqEq(y);
        diffComparisons++;
        _requireComparisonRan();
    }

    function test_differential__Success_TickLower(int24 y) public {
        Context memory ctx = Context({oracle: panoptic, tickLower: y, tickUpper: 0, amount: 0});
        test(this.execTickLower, ctx);
        ctx.oracle = plank;
        test(this.execTickLower, ctx);
        _assertPackedTickLowerEq(y);
        diffComparisons++;
        _requireComparisonRan();
    }

    function test_differential__Success_TickUpper(int24 y) public {
        Context memory ctx = Context({oracle: panoptic, tickLower: 0, tickUpper: y, amount: 0});
        test(this.execTickUpper, ctx);
        ctx.oracle = plank;
        test(this.execTickUpper, ctx);
        _assertPackedTickUpperEq(y);
        diffComparisons++;
        _requireComparisonRan();
    }

    function test_differential__Success_AddTicksLiquidity(int24 y, int24 z, uint128 u) public {
        Context memory ctx = Context({oracle: panoptic, tickLower: y, tickUpper: z, amount: u});
        test(this.execAddTicksLiquidity, ctx);
        ctx.oracle = plank;
        test(this.execAddTicksLiquidity, ctx);
        _assertPackedFromTicksEq(y, z, u);
        diffComparisons++;
        _requireComparisonRan();
    }

    function test_differential__Success_updateTickLower(int24 y1, int24 y2) public {
        Context memory ctx = Context({oracle: panoptic, tickLower: y1, tickUpper: y2, amount: 0});
        test(this.execUpdateTickLower, ctx);
        ctx.oracle = plank;
        test(this.execUpdateTickLower, ctx);
        _assertPackedUpdateTickLowerEq(y1, y2);
        diffComparisons++;
        _requireComparisonRan();
    }

    function test_differential__Success_updateTickUpper(int24 y1, int24 y2) public {
        Context memory ctx = Context({oracle: panoptic, tickLower: y1, tickUpper: y2, amount: 0});
        test(this.execUpdateTickUpper, ctx);
        ctx.oracle = plank;
        test(this.execUpdateTickUpper, ctx);
        _assertPackedUpdateTickUpperEq(y1, y2);
        diffComparisons++;
        _requireComparisonRan();
    }

    /// @dev Mirrors {LiquidityChunkTest.test_Success_AddLiq} on `ctx.oracle` only.
    function execAddLiq(Context memory ctx) external stateless {
        (, uint256 liq) = ctx.oracle.packedAddLiq(ctx.amount);
        assertEq(liq, ctx.amount);
    }

    /// @dev Mirrors {LiquidityChunkTest.test_Success_TickLower} on `ctx.oracle` only.
    function execTickLower(Context memory ctx) external stateless {
        (, int256 tick) = ctx.oracle.packedAddTickLower(ctx.tickLower);
        assertEq(tick, int256(ctx.tickLower));
    }

    /// @dev Mirrors {LiquidityChunkTest.test_Success_TickUpper} on `ctx.oracle` only.
    function execTickUpper(Context memory ctx) external stateless {
        (, int256 tick) = ctx.oracle.packedAddTickUpper(ctx.tickUpper);
        assertEq(tick, int256(ctx.tickUpper));
    }

    /// @dev Mirrors {LiquidityChunkTest.test_Success_AddTicksLiquidity} on `ctx.oracle` only.
    function execAddTicksLiquidity(Context memory ctx) external stateless {
        (, int256 tl, int256 tu, uint256 liq) =
            ctx.oracle.packedFromTicks(ctx.tickLower, ctx.tickUpper, ctx.amount);
        assertEq(tl, int256(ctx.tickLower));
        assertEq(tu, int256(ctx.tickUpper));
        assertEq(liq, ctx.amount);
    }

    /// @dev Mirrors {LiquidityChunkTest.test_Success_updateTickLower} on `ctx.oracle` only.
    function execUpdateTickLower(Context memory ctx) external stateless {
        (uint256 p1, uint256 p2) = ctx.oracle.packedUpdateTickLower(ctx.tickLower, ctx.tickUpper);
        assertEq(ctx.oracle.tickLowerOf(p1), int256(ctx.tickLower));
        assertEq(ctx.oracle.tickLowerOf(p2), int256(ctx.tickUpper));
    }

    /// @dev Mirrors {LiquidityChunkTest.test_Success_updateTickUpper} on `ctx.oracle` only.
    function execUpdateTickUpper(Context memory ctx) external stateless {
        (uint256 p1, uint256 p2) = ctx.oracle.packedUpdateTickUpper(ctx.tickLower, ctx.tickUpper);
        assertEq(ctx.oracle.tickUpperOf(p1), int256(ctx.tickLower));
        assertEq(ctx.oracle.tickUpperOf(p2), int256(ctx.tickUpper));
    }

    function _assertPackedAddLiqEq(uint128 amount) internal view {
        (uint256 pPacked, uint256 pLiq) = panoptic.packedAddLiq(amount);
        (uint256 vPacked, uint256 vLiq) = plank.packedAddLiq(amount);
        assertEq(pPacked, vPacked, "addLiq: packed word, tol 0");
        assertEq(pLiq, vLiq, "addLiq: vega amount, tol 0");
    }

    function _assertPackedTickLowerEq(int24 tickLower_) internal view {
        (uint256 pPacked, int256 pTick) = panoptic.packedAddTickLower(tickLower_);
        (uint256 vPacked, int256 vTick) = plank.packedAddTickLower(tickLower_);
        assertEq(pPacked, vPacked, "tickLower: packed word, tol 0");
        assertEq(pTick, vTick, "tickLower: tick, tol 0");
    }

    function _assertPackedTickUpperEq(int24 tickUpper_) internal view {
        (uint256 pPacked, int256 pTick) = panoptic.packedAddTickUpper(tickUpper_);
        (uint256 vPacked, int256 vTick) = plank.packedAddTickUpper(tickUpper_);
        assertEq(pPacked, vPacked, "tickUpper: packed word, tol 0");
        assertEq(pTick, vTick, "tickUpper: tick, tol 0");
    }

    function _assertPackedFromTicksEq(int24 tickLower_, int24 tickUpper_, uint128 amount) internal view {
        (uint256 pPacked, int256 pTL, int256 pTU, uint256 pLiq) =
            panoptic.packedFromTicks(tickLower_, tickUpper_, amount);
        (uint256 vPacked, int256 vTL, int256 vTU, uint256 vLiq) =
            plank.packedFromTicks(tickLower_, tickUpper_, amount);
        assertEq(pPacked, vPacked, "createChunk: packed word, tol 0");
        assertEq(pTL, vTL, "createChunk: tickLower, tol 0");
        assertEq(pTU, vTU, "createChunk: tickUpper, tol 0");
        assertEq(pLiq, vLiq, "createChunk: vega amount, tol 0");
    }

    function _assertPackedUpdateTickLowerEq(int24 y1, int24 y2) internal view {
        (uint256 p1, uint256 p2) = panoptic.packedUpdateTickLower(y1, y2);
        (uint256 v1, uint256 v2) = plank.packedUpdateTickLower(y1, y2);
        assertEq(p1, v1, "updateTickLower: first packed word, tol 0");
        assertEq(p2, v2, "updateTickLower: second packed word, tol 0");
    }

    function _assertPackedUpdateTickUpperEq(int24 y1, int24 y2) internal view {
        (uint256 p1, uint256 p2) = panoptic.packedUpdateTickUpper(y1, y2);
        (uint256 v1, uint256 v2) = plank.packedUpdateTickUpper(y1, y2);
        assertEq(p1, v1, "updateTickUpper: first packed word, tol 0");
        assertEq(p2, v2, "updateTickUpper: second packed word, tol 0");
    }
}
