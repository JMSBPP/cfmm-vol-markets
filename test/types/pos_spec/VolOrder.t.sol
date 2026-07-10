// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";

interface IVolOrderType {
    function set_vol_order_vol_strike(uint256,uint88) external returns(uint256);

    function set_vol_order_skew(uint24,uint24, uint88, uint16,uint16) external returns(uint24,uint24, uint88, uint16);

    function set_vol_order_range_width(uint24,uint24, uint88, uint16,uint24,uint24) external returns(uint24,uint24, uint88, uint16);

    function tick_bucket_from_vol_order(uint88,uint16,uint24,uint24, int24) external returns(int24,uint24,int24);
}

struct VolOrder {
    uint24 width;
    uint24 tickSpacing;
    uint88 vol_strike;
    uint16 skew;
}
function packVolOrder(VolOrder memory o) pure returns (uint256) {
    return
        (uint256(o.width) << 128)
        | (uint256(o.tickSpacing) << 104)
        | (uint256(o.vol_strike) << 16)
        | uint256(o.skew);
}

function unpackVolOrder(uint256 raw) pure returns (VolOrder memory o) {
    uint256 x = uint256(raw);

    o.width = uint24(x >> 128);
    o.tickSpacing = uint24(x >> 104);
    o.vol_strike = uint88(x >> 16);
    o.skew = uint16(x);
}
    
    
contract VolOrderTest is Test, PlankDeployer {
     BuildOptions opts;
     IVolOrderType volOrderImpl;

     VolOrder vol_order_state;
     
     function setUp() public {
	opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](5);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
	deps[1] = Dependency("std", "lib/plank-monorepo/std/");
	deps[2] = Dependency("pos_spec", "src/types/pos_spec");
	deps[3] = Dependency("lib","src/lib");
	deps[4] = Dependency("types", "src/types");
	opts.dependencies = deps;

	// note: Setting a initial state of a vol_order to be
	// width = |-120 - 120 | / 20
	// todo: value of vol_strike is not realistic yet
	vol_order_state = VolOrder(uint24(120),uint24(20),uint88(1),uint16(type(uint16).max /2));

	volOrderImpl = IVolOrderType(plankDeployFFI("test/types/pos_spec/VolOrderHelper.plk", opts));

     }

     function test__fuzz__volOrderSetVolStrikeValid(uint88 volLevel) public {
	     VolOrder memory before_vol_order_state = vol_order_state;
	     volLevel = uint88(bound(uint256(volLevel), 1, type(uint64).max));
	     VolOrder memory after_vol_order_state = unpackVolOrder(volOrderImpl.set_vol_order_vol_strike(packVolOrder(vol_order_state),volLevel));
	     vol_order_state = after_vol_order_state;
	     assertEq(vol_order_state.vol_strike, volLevel);
	     assertEq(before_vol_order_state.width, vol_order_state.width);
	     assertEq(vol_order_state.skew, before_vol_order_state.skew);
	     assertEq(before_vol_order_state.tickSpacing, vol_order_state.tickSpacing);
	 
     }

}
 
