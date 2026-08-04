// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {ExpMath} from "bunni-v2/src/lib/ExpMath.sol";

struct TickVolatility {
    uint256 vol;
}
    
interface ITickVolatilityType{
    function volQ64x96(uint256) external returns(TickVolatility memory q64x96TickVol);

    function volWAD(uint256) external returns(TickVolatility memory wadTickVol);

}


contract TickVolatilityTest is Test, PlankDeployer {
    ITickVolatilityType tickVolatilityImpl;
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

	tickVolatilityImpl = ITickVolatilityType(plankDeployFFI("test/types/pos_spec/TickVolatilityHelper.plk", opts));
						 

    }

    function test__fuzz__tickVolatilityVolQ64x96Wad__Valid(uint88 tickVol) public {
	vm.assume(uint256(tickVol) <= type(uint64).max);
	uint256 expectedVolQ64x96 = uint256(tickVol)<< 96;
	uint256 expectedVolWAD = uint256(tickVol) * 1e18;
	TickVolatility memory actualVolQ64x96 = tickVolatilityImpl.volQ64x96(uint256(tickVol));
	TickVolatility memory actualVolWAD = tickVolatilityImpl.volWAD(uint256(tickVol));
	assertEq(actualVolQ64x96.vol, expectedVolQ64x96);
	assertEq(actualVolWAD.vol, expectedVolWAD);
	
    }
}
