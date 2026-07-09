// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";

interface IVolOrderType {
    function set_vol_order_vol_strike(uint88) external returns(uint88,uint16,uint24,uint24);

    function set_vol_order_skew(uint16) external returns(uint88,uint16,uint24,uint24);

    function set_vol_order_range_width(uint24,uint24) external returns(uint88,uint16,uint24,uint24);

    function tick_bucket_from_vol_order(uint88,uint16,uint24,uint24) external returns(int24,uint24,int24);
}
contract VolOrderTest is Test, PlankDeployer {
     BuildOptions opts;
     IVolOrderType volOrderImpl;

     function setUp() public {
	opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](4);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
	deps[1] = Dependency("std", "lib/plank-monorepo/std/");
	deps[2] = Dependency("pos_spec", "src/types/pos_spec");
	deps[3] = Dependency("lib","src/lib");
	opts.dependencies = deps;

	volOrderImpl = IVolOrderType(plankDeployFFI("test/types/pos_spec/VolOrderHelper.plk", opts));

     }

     function test__placeholder() public {}

}
