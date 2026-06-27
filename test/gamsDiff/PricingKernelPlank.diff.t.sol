// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {stdMath} from "forge-std/StdMath.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {LibCall} from "bunni-v2/lib/solady/src/utils/LibCall.sol";

/// @title PricingKernelPlankdiffTest
/// @notice Diffs the GAMS pricing kernel's tick -> sqrtPriceX96 mapping against the
///         on-chain Uniswap V3 reference exposed by `PriceKernelHarness.plk`.
/// @dev The harness is a pure reader (`getSqrtRatioAtTick(int24) returns (uint256)`),
///      so no fork is required: it is deployed locally and queried directly.
///      The fixture is the GAMS tunablePricingKernel at the balanced weight eta = 1/2
///      (fixture field "eta": 0.5), which reduces to the fixed sqrt priceKernel ==
///      getSqrtRatioAtTick. eta = 1/2 is the ONLY elasticity with an on-chain
///      counterpart, so this diff is pinned there; eta != 1/2 is off-chain only.
contract PricingKernelPlankdiffTest is Test, PlankDeployer {
    // getSqrtRatioAtTick(int24)
    bytes4 constant SEL_GET_SQRT_RATIO_AT_TICK = 0x986cfba3;

    address public PRICE_KERNEL;

    function setUp() public {
        BuildOptions memory opts;
        opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](1);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
        opts.dependencies = deps;

        PRICE_KERNEL = plankDeployFFI("test/gamsUtils/PriceKernelHarness.plk", opts);
    }

    /// @dev Forward the raw int24 tick as its sign-extended 32-byte word, matching the
    ///      harness's calldata contract, and decode the uint256 sqrtPriceX96 result.
    function _getSqrtRatioAtTick(int24 tick) internal view returns (uint256) {
        return abi.decode(
            LibCall.staticCallContract(
                PRICE_KERNEL,
                abi.encodeWithSelector(SEL_GET_SQRT_RATIO_AT_TICK, tick)
            ),
            (uint256)
        );
    }

    // EPS = 1e3  (1e-15 relative; float64 noise floor ~2.2e-16 -> ~4x headroom)
    uint256 constant EPS = 1e3;
    uint256 constant TWO_96 = 79228162514264337593543950336; // 2^96

    function test_PricingKernel_matches_getSqrtRatioAtTick() public view {
        string memory json = vm.readFile("test/gamsDiff/fixtures/pricing_kernel.json");
        int256[] memory ticks = vm.parseJsonIntArray(json, ".ticks");
        uint256[] memory expected = vm.parseJsonUintArray(json, ".expectedSqrtPriceX96");
        assertEq(ticks.length, expected.length, "fixture array length mismatch");
        assertEq(ticks.length, 241, "expected 241 ticks (s1 slice)");

        // sign-extension regression guard: endpoints straddle 2^96
        assertLt(_getSqrtRatioAtTick(-120), TWO_96, "tick -120 should be < 2^96");
        assertGt(_getSqrtRatioAtTick(int24(120)), TWO_96, "tick 120 should be > 2^96");

        for (uint256 i = 0; i < ticks.length; i++) {
            uint256 actual = _getSqrtRatioAtTick(int24(ticks[i]));
            assertApproxEqRel(actual, expected[i], EPS);
        }
    }
}
