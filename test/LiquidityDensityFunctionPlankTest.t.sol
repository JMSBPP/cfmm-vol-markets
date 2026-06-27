// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {LiquidityDensityFunctionTest} from "bunni-v2/test/ldf/LiquidityDensityFunctionTest.sol";
import {ILiquidityDensityFunction} from "bunni-v2/src/interfaces/ILiquidityDensityFunction.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";

contract LiquidityDensityFunctionPlankTest is PlankDeployer , LiquidityDensityFunctionTest {
       uint256 internal constant MIN_ALPHA = 1e3;
       uint256 internal constant MAX_ALPHA = 12e8;
 
        function _setUpLDF() internal override {
	    BuildOptions memory opts;
	    opts.backend = 'sona';
	    Dependency[] memory deps = new Dependency[](1);
	    deps[0] = Dependency("v3","lib/plankified-univ3/plank/lib");
	    opts.dependencies = deps;
	    ldf = ILiquidityDensityFunction(
					    plankDeployFFI(
							   "src/ldf/GeometricDistribution.plk",
							   opts
					    )
	    );
	}

      function test_liquidityDensity_sumUpToOne(
						int24 tickSpacing,
						int24 minTick,
						int24 length,
						uint256 alpha
      )
        external
        virtual
    {

        alpha = bound(alpha, MIN_ALPHA, MAX_ALPHA);
        vm.assume(alpha != 1e8); // 1e8 is a special case that causes overflow
        tickSpacing = int24(bound(tickSpacing, MIN_TICK_SPACING, MAX_TICK_SPACING));
 
    }

    function test_query_cumulativeAmounts(
        int24 currentTick,
        int24 tickSpacing,
        int24 minTick,
        int24 length,
        uint256 alpha
    ) external virtual {    }

    function test_inverseCumulativeAmount0(
        uint256 liquidity,
        uint256 cumulativeAmount0,
        int24 tickSpacing,
        int24 minTick,
        int24 length,
        uint256 alpha
    ) external virtual { }

    function test_inverseCumulativeAmount1(
        uint256 liquidity,
        uint256 cumulativeAmount1,
        int24 tickSpacing,
        int24 minTick,
        int24 length,
        uint256 alpha
    ) external virtual {    }

    function test_boundary_static_invalidWhenOutOfBounds(int24 tickSpacing) external view {    }

    function test_boundary_dynamic_boundedWhenDecoding(int24 tickSpacing) external view { }	

}
