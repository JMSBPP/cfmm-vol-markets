// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {LibCall} from "bunni-v2/lib/solady/src/utils/LibCall.sol";

/// @title PricingKernelPlankdiffTest
/// @notice Diffs the GAMS pricing kernel's tick -> sqrtPriceX96 mapping against the
///         on-chain Uniswap V3 reference exposed by `PriceKernelHarness.plk`.
/// @dev The harness is a pure reader (`getSqrtRatioAtTick(int24) returns (uint256)`),
///      so no fork is required: it is deployed locally and queried directly.
contract PricingKernelPlankdiffTest is Test, PlankDeployer {
    // getSqrtRatioAtTick(int24)
    bytes4 constant SEL_GET_SQRT_RATIO_AT_TICK = 0x986cfba3;

    address public PRICE_KERNEL;
    BuildOptions opts;

    function setUp() public {
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
}
