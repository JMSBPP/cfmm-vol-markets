// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";


interface IVolRangeWidthType {
    function pack_vol_range_width(uint24,uint24) external returns (bytes32);
    function unpack_vol_range_width(bytes32) external returns (uint24, uint24);
}

contract VolRangeWidthTest is Test , PlankDeployer{

    IVolRangeWidthType volRangeWidthImpl;
    BuildOptions opts;

    function setUp() public {
	opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](3);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
	deps[1] = Dependency("std", "lib/plank-monorepo/std/");
	deps[2] = Dependency("pos_spec", "src/types/pos_spec");

	opts.dependencies = deps;
	volRangeWidthImpl = IVolRangeWidthType(plankDeployFFI("test/types/pos_spec/VolRangeWidthHelper.plk", opts));

    }

    function test__fuzz__volWidthRangePackUnpack(bytes32 _packed) public {
	if (uint256(_packed) > 0xffffffffffff ) {
	    vm.expectRevert();
	}
	
	(uint24 width, uint24 tickSpacing) = volRangeWidthImpl.unpack_vol_range_width(_packed);
    }
}
