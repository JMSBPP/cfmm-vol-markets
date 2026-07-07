// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {ExpMath} from "bunni-v2/src/lib/ExpMath.sol";

struct TickVolatility {
    uint256 vol;
}
interface ITickVolatilityType{
    function volQ64x96(TickVolatility memory tick_volatility) external returns(TickVolatility memory q64x96TickVol);

    function volWAD(TickVolatility memory tick_volatility) external returns(TickVolatility memory wadTickVol);

}

contract TickVolatilityLibHarness {
    function lnVolX96(TickVolatility memory tick_volatility) internal pure returns(uint160){

    }
    function lnVolWAD(TickVolatility memory tick_volatility) internal pure returns(uint160){

    }

    function tickVolatilitySqrtPriceX64x96(TickVolatility memory tick_volatility) internal pure returns(uint160){

    }

    function tickVolatilityTick(TickVolatility memory tick_volatility) internal pure returns(int24){

    }
    
}

contract TickVolatilityTest is Test, PlankDeployer {
    ITickVolatilityType tickVolatilityImpl;
    TickVolatilityLibHarness tickVolatilityLib;
    BuildOptions opts;

    function setUp() public {
	opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](4);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
	deps[1] = Dependency("std", "lib/plank-monorepo/std/");
	deps[2] = Dependency("pos_spec", "src/types/pos_spec");
	deps[3] = Dependency("lib","src/lib");
	opts.dependencies = deps;

	tickVolatilityImpl = ITickVolatilityType(plankDeployFFI("test/types/pos_spec/TickVolatilityHelper.plk", opts));

	
						 

    }

    function test__fuzz__tickVolatilityVolQ64x96__Valid(uint88 tickVol) public {
	uint160 expectedVolQ64x96 = uint160(tickVol*ExpMath.Q96);
	TickVolatility memory tick_volatility = TickVolatility(uint256(tickVol));
	TickVolatility memory actualVolQ64x96 = tickVolatilityImpl.volQ64x96(tick_volatility);
	assertEq(uint160(actualVolQ64x96.vol), expectedVolQ64x96);
    }
}
