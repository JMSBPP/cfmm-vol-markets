// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {TickMath} from "univ4-core/libraries/TickMath.sol";

/// @notice On-chain realization of the lean4-spec theorem `eta_split_kernel_identity` (lean/exp/eta.lean):
///         for η ∈ (0,1), P_half(⌊η·i⌋) · P_half(i−⌊η·i⌋) = P_half(i). In the Q64.96 sqrt-price domain
///         P_half = getSqrtRatioAtTick, so the product recombines (÷2^96) to the canonical v4 price.
contract EtaSplitKernelTest is PlankTestBase {
    // FFI-deployed Plank harness (EtaSplitKernelHarness.plk):
    //   tickSplitMinus(uint256 eta, int24 i)                                    -> int24  (⌊η·i⌋)
    //   tickSplitPlus(uint256 eta, int24 i)                                     -> int24  (i − ⌊η·i⌋)
    //   etaSplitKernel(uint256 eta, int24 i)                                    -> uint160
    //   priceAtTick(uint256 tickSpacing, uint256 eta, uint256 numbRep, int24 i) -> uint160
    address internal harness;

    uint256 constant TICK_SPACING = 60;
    uint256 constant NUMB_REP     = 96;
    uint256 constant Q96          = 1 << 96;

    function setUp() public {
        harness = deployPlank("test/lib/EtaSplitKernelHarness.plk");
    }

    function testFuzz_etaSplitKernel_identity(uint256 etaRaw, int256 iRaw) public {
        uint256 eta = bound(etaRaw, 1, Q96 - 1);                               // η ∈ (0,1) in Q64.96
        int24 i = int24(bound(iRaw, TickMath.MIN_TICK, TickMath.MAX_TICK));    // |i| ≤ 887272

        // --- split legs ---
        (bool okM, bytes memory rM) =
            harness.staticcall(abi.encodeWithSignature("tickSplitMinus(uint256,int24)", eta, i));
        (bool okP, bytes memory rP) =
            harness.staticcall(abi.encodeWithSignature("tickSplitPlus(uint256,int24)", eta, i));
        assertTrue(okM && okP, "split reverted");
        int256 minus = abi.decode(rM, (int256));
        int256 plus = abi.decode(rP, (int256));

        // (1) split structure: legs sum to i, and minus is exactly ⌊η·i⌋ (arithmetic shift = floor)
        assertEq(minus + plus, int256(i), "split must sum to i");
        assertEq(minus, (int256(eta) * int256(i)) >> 96, "minus == floor(eta*i / 2^96)");

        // (2) recombined Q96 product == canonical v4 TickMath price (eta_split_kernel_identity).
        // The theorem is an exact-real identity; on-chain the composite of two round-up legs + a
        // truncating mulDiv lands within a bounded ULP of the canonical price. Relative error is
        // ≤ ~4/MIN_SQRT_RATIO ≈ 9.3e-10 (each leg is off by <1 in Q96, every leg value ≥ MIN_SQRT_RATIO);
        // 1e-8 (1e10) is ~10× that bound and still catches any real formula bug (those diverge by ticks).
        (bool okK, bytes memory rK) =
            harness.staticcall(abi.encodeWithSignature("etaSplitKernel(uint256,int24)", eta, i));
        assertTrue(okK, "etaSplitKernel reverted");
        assertApproxEqRel(
            abi.decode(rK, (uint256)),
            uint256(TickMath.getSqrtPriceAtTick(i)),
            1e10,
            "eta_split_kernel_identity: product == canonical sqrtPriceX96 (within sqrt ULP)"
        );

        // (3) PriceCoordinate.price_at_tick delegates through its subs_elasticity (= η)
        (bool okC, bytes memory rC) = harness.staticcall(
            abi.encodeWithSignature("priceAtTick(uint256,uint256,uint256,int24)", TICK_SPACING, eta, NUMB_REP, i)
        );
        assertTrue(okC, "priceAtTick reverted");
        assertEq(
            abi.decode(rC, (uint256)),
            abi.decode(rK, (uint256)),
            "price_at_tick == eta_split_kernel(subs_elasticity, tick)"
        );
    }
}
