// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IExpMathWrapper, ExpMathWrapper} from "utils/ExpMathWrapper.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {ExpMath} from "bunni-v2/src/lib/ExpMath.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";


interface ITickVolatilityLib{
    function lnWad(int256) external returns(uint256);
    function lnQ96(int256) external returns(uint256);
    function tick_volatility_tick(uint256) external returns(int24);
    function tick_volatility_sqrt_price_X64x96(uint256) external returns(uint160);
    function set_implementation(address) external;
}

contract TickVolatilityLibTest is Test, PlankDeployer {
       ITickVolatilityLib tickVolatilityImpl;

       BuildOptions opts;
       function setUp() public {
	    opts.backend = "sona";
	    Dependency[] memory deps = new Dependency[](5);
	    deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
	    deps[1] = Dependency("std", "lib/plank-monorepo/std/");
	    deps[2] = Dependency("pos_spec", "src/types/pos_spec");
	    deps[3] = Dependency("lib","src/lib");
	    deps[4] = Dependency("types", "src/types");
	    opts.dependencies = deps;
	    address wrapper = address(new ExpMathWrapper());
	    tickVolatilityImpl = ITickVolatilityLib(plankDeployFFI("test/lib/pos_spec/TickVolatilityLibHelper.plk", opts));
	    tickVolatilityImpl.set_implementation(wrapper);
	}

       function test_fuzz__tickVolatilityLnVolX96LnWadSuccess (uint256 volLevel) public {
	   vm.assume(volLevel <= type(uint64).max && volLevel > 0);

	   uint256 actualLnVolX96 = tickVolatilityImpl.lnQ96(int256(volLevel));
	   uint256 expectedLnVolX96 = uint256(ExpMath.lnQ96(int256(volLevel << 96)));
	   uint256 expectedLnVolWAD = uint256(FixedPointMathLib.lnWad(int256(volLevel*1e18)));
	   uint256 actualLnVolWAD = tickVolatilityImpl.lnWad(int256(volLevel));
	   assertEq(actualLnVolX96, expectedLnVolX96);
	   assertEq(expectedLnVolWAD, actualLnVolWAD);
	   
       }

       function test__fuzz__tickVolatilitySqrtPriceX64x96AndTickSuccess(uint256 volLevel) public {
	   vm.assume(volLevel <= type(uint64).max && volLevel > 0);
	   uint160 actualSqrtPrice = tickVolatilityImpl.tick_volatility_sqrt_price_X64x96(volLevel);
	   uint160 expectedSqrtPrice = uint160(volLevel << 96);
	   assertEq(expectedSqrtPrice,actualSqrtPrice);
	   int24 expectedTick = TickMath.getTickAtSqrtRatio(expectedSqrtPrice);
	   int24 actualTick = tickVolatilityImpl.tick_volatility_tick(volLevel);
	   assertEq(expectedTick, actualTick);
       }

       
}
