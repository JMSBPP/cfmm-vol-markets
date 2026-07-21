// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {LibCall} from "bunni-v2/lib/solady/src/utils/LibCall.sol";

/// @title PriceImpactKernelPlankdiffTest
/// @notice Diffs the GAMS price-impact kernel (post-trade sqrt price, eta=1/2) against the
///         on-chain Uniswap V3 `getNextSqrtPriceFromAmount0RoundingUp` (add=true, token0-input)
///         exposed by `PriceImpactKernelHarness.plk` — the building block under CESLongPayoff.
/// @dev The harness is a pure reader, so no fork is required: it is deployed locally and queried
///      directly. The fixture is pinned to eta=1/2 (the only EVM-testable weight) and the
///      token0-input rounding-up path (add=true); both invariants are guarded before the diff.
contract PriceImpactKernelPlankdiffTest is Test, PlankDeployer {
    // getNextSqrtPriceFromAmount0RoundingUp(uint160,uint128,uint256,bool)
    bytes4 constant SEL = 0x157f652f;
    // EPS = 1e3 (1e-15 relative). Producer's exact-integer EVM replica over all 723 rows:
    // max_rel_error 2.02e-16, 0 rows over EPS, ~4.95x headroom. Loosen only with recorded evidence.
    uint256 constant EPS = 1e3;
    uint256 constant TWO_96 = 79228162514264337593543950336; // 2^96

    string constant FIXTURE = "test/gamsDiff/fixtures/price_impact_kernel.json";
    uint256 constant EXPECTED_ROWS = 723; // 1 spacing x 241 ticks x 3 dx

    address public HARNESS;

    function setUp() public {
        BuildOptions memory opts;
        opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](1);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
        opts.dependencies = deps;
        HARNESS = plankDeployFFI("test/gamsUtils/PriceImpactKernelHarness.plk", opts);
    }

    /// @dev Forward (sqrtP, L, amount, add) at calldata offsets 4/36/68/100 and decode the
    ///      uint256 post-trade sqrt price.
    function _next(uint160 sqrtP, uint128 L, uint256 amount, bool add) internal view returns (uint256) {
        return abi.decode(
            LibCall.staticCallContract(HARNESS, abi.encodeWithSelector(SEL, sqrtP, L, amount, add)),
            (uint256)
        );
    }

    /// @notice The on-chain harness only implements the token0-input rounding-up path at the
    ///         balanced weight. Guard the fixture's shape/pinning so a regeneration that flips
    ///         `add`, changes liquidity, or alters the grid size reddens here rather than
    ///         silently diffing against an incomparable curve.
    function test_fixtureShapePinned() public view {
        string memory json = vm.readFile(FIXTURE);
        assertEq(vm.parseJsonUint(json, ".count"), EXPECTED_ROWS, "fixture row count drifted");
        assertTrue(vm.parseJsonBool(json, ".add"), "fixture must be the add=true (token0-input) path");
        assertEq(vm.parseJsonUint(json, ".liquidity"), 1e18, "fixture liquidity must be 1e18 (L-bar)");
    }

    function test_PriceImpact_matches_getNextSqrtPriceFromAmount0RoundingUp() public view {
        string memory json = vm.readFile(FIXTURE);
        int256[] memory ticks = vm.parseJsonIntArray(json, ".ticks");
        uint256[] memory sqrtPIn = vm.parseJsonUintArray(json, ".sqrtPX96In");
        uint256[] memory amount0In = vm.parseJsonUintArray(json, ".amount0In");
        uint256[] memory expected = vm.parseJsonUintArray(json, ".expectedSqrtPriceX96");
        uint256 liquidity = vm.parseJsonUint(json, ".liquidity");

        assertEq(ticks.length, EXPECTED_ROWS, "ticks length");
        assertEq(sqrtPIn.length, EXPECTED_ROWS, "sqrtPX96In length");
        assertEq(amount0In.length, EXPECTED_ROWS, "amount0In length");
        assertEq(expected.length, EXPECTED_ROWS, "expectedSqrtPriceX96 length");

        bool sawSanity;
        for (uint256 i = 0; i < ticks.length; i++) {
            uint256 actual = _next(uint160(sqrtPIn[i]), uint128(liquidity), amount0In[i], true);

            // Numeric equivalence against the GAMS reference within the verified tolerance.
            assertApproxEqRel(actual, expected[i], EPS);

            // Token0-input strictly lowers the sqrt price: post-trade < pre-trade for every row.
            assertLt(actual, sqrtPIn[i], "post-trade sqrt price must be below pre-trade");

            // Spot sanity: at tick 0 (sqrtP ~ 2^96) a medium token0 input lands below 2^96.
            if (ticks[i] == 0 && amount0In[i] == 1e17) {
                assertLt(actual, TWO_96, "tick0 medium-dx post-trade price should be < 2^96");
                sawSanity = true;
            }
        }
        assertTrue(sawSanity, "sanity row (tick 0, dx=1e17) not found");
    }
}
