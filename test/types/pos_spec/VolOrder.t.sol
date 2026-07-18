// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";

interface IVolOrderType {
    function set_vol_order_vol_strike(uint256,uint88) external returns(uint256);

    function set_vol_order_skew(uint256,uint16) external returns(uint256);

    function set_vol_order_range_width(uint256,uint256) external returns(uint256);

    function tick_bucket_from_vol_order(uint256) external returns(uint256);
}

struct TickBucket {
    int24 low;
    uint24 tickSpacing;
    int24 up;
}

struct VolRangeWidth {
    uint24 width;
    uint24 tickSpacing;
}

struct VolOrder {
    uint24 width;
    uint24 tickSpacing;
    uint88 vol_strike;
    uint16 skew;
}

function packTickBucket(TickBucket memory tb) pure returns (uint256) {
    return
        (uint256(uint24(tb.low)) & 0xFFFFFF) |
        ((uint256(tb.tickSpacing) & 0xFFFFFF) << 24) |
        ((uint256(uint24(tb.up)) & 0xFFFFFF) << 48);
}

function unpackTickBucket(uint256 packed) pure returns (TickBucket memory) {
    return TickBucket({
        low: int24(uint24(packed & 0xFFFFFF)),
        tickSpacing: uint24((packed >> 24) & 0xFFFFFF),
        up: int24(uint24((packed >> 48) & 0xFFFFFF))
    });
}

function packVolRangeWidth(VolRangeWidth memory vrw) pure returns (uint256) {
    return
        (uint256(vrw.width) & 0xFFFFFF) |
        ((uint256(vrw.tickSpacing) & 0xFFFFFF) << 24);
}

function unpackVolRangeWidth(uint256 packed) pure returns (VolRangeWidth memory) {
    return VolRangeWidth({
        width: uint24(packed & 0xFFFFFF),
        tickSpacing: uint24((packed >> 24) & 0xFFFFFF)
    });
}

function packVolOrder(VolOrder memory o) pure returns (uint256) {
    return
        ((uint256(o.width) & 0xFFFFFF) << 128) |
        ((uint256(o.tickSpacing) & 0xFFFFFF) << 104) |
        ((uint256(o.vol_strike) & 0xFFFFFFFFFFFFFFFFFFFFFF) << 16) |
        (uint256(o.skew) & 0xFFFF);
}

function unpackVolOrder(uint256 packed) pure returns (VolOrder memory) {
    return VolOrder({
        width: uint24((packed >> 128) & 0xFFFFFF),
        tickSpacing: uint24((packed >> 104) & 0xFFFFFF),
        vol_strike: uint88((packed >> 16) & 0xFFFFFFFFFFFFFFFFFFFFFF),
        skew: uint16(packed & 0xFFFF)
    });
}

contract VolOrderTest is Test, PlankDeployer {
     BuildOptions opts;
     IVolOrderType volOrderImpl;

     VolOrder vol_order_state;
     VolRangeWidth vol_range_width_state;
     int24 TICK_STATE;

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
	vol_range_width_state = VolRangeWidth(uint24(120),uint24(20));
	// note: vol strike taken from querying getSingleTimepoint https://arbiscan.io/address/0x00977203ea61A7960B2317E006e3b9D7D4223E46#readContract
	vol_order_state = VolOrder(vol_range_width_state.width,vol_range_width_state.tickSpacing,uint88( 826165723479),uint16(type(uint16).max /2));
	TICK_STATE = int24(20);
	volOrderImpl = IVolOrderType(plankDeployFFI("test/types/pos_spec/VolOrderHelper.plk", opts));

     }

     // todo: We need invalid test cases coverage

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

     function test__fuzz__volOrderSetSkewValid(uint16 skew) public {
	    VolOrder memory before_vol_order_state = vol_order_state;
	    skew = uint16(bound(uint256(skew), 1, type(uint16).max -1));
	    VolOrder memory after_vol_order_state = unpackVolOrder(volOrderImpl.set_vol_order_skew(packVolOrder(vol_order_state),skew));
	     vol_order_state = after_vol_order_state;
	     assertEq(vol_order_state.vol_strike, before_vol_order_state.vol_strike);
	     assertEq(before_vol_order_state.width, vol_order_state.width);
	     assertEq(vol_order_state.skew, skew);
	     assertEq(before_vol_order_state.tickSpacing, vol_order_state.tickSpacing);
     }

     function test__fuzz__volOrderSetVolRangeWidth(uint24 tick_spacing,uint24 width) public {

	    tick_spacing = uint24(bound(uint256(tick_spacing), 1, 200));
	    // 1774544 = |MIN_TICK - MAX_TICK|
	    width = uint24(bound(uint256(width), 1 ,1774544 / uint256(tick_spacing)));
	    VolOrder memory before_vol_order_state = vol_order_state;
	    vol_range_width_state = VolRangeWidth(width,tick_spacing);
	    VolOrder memory after_vol_order_state = unpackVolOrder(volOrderImpl.set_vol_order_range_width(packVolOrder(vol_order_state),packVolRangeWidth(vol_range_width_state)));
	     vol_order_state = after_vol_order_state;
	     assertEq(vol_order_state.vol_strike, before_vol_order_state.vol_strike);
	     assertEq(width, vol_order_state.width);
	     assertEq(vol_order_state.skew, before_vol_order_state.skew);
	     assertEq(tick_spacing, vol_order_state.tickSpacing);
     }

     function test__unit__volOrderTickBucketFromVolOrderValid() public {
	 console2.log("An agent has a vol strike of 112 bp, which maps to");
	 console2.log("V_now      = 826,165,723,479");
	 console2.log("V_86400ago = 825,083,484,644");
	 console2.log("dV         =   1,082,238,835");
	 console2.log("T          = 86,400");
	 console2.log("sqrt{dv/T} = 112");

	 console2.log("vol_strike(112 bp) = ", vol_order_state.vol_strike);
	 console2.log("Agent submits a range width of :", vol_order_state.width);
	 console2.log("And a skew of 1/2 which maps on u16 to:",vol_order_state.skew);
	 
	 console2.log("Considering the current tick is:", TICK_STATE);
	 TickBucket memory bucket_from_order = unpackTickBucket(volOrderImpl.tick_bucket_from_vol_order(packVolOrder(vol_order_state)));
	 console2.log("This means placing a tick bucket on:");
	 console2.log("low = ", bucket_from_order.low);
	 console2.log("up = ", bucket_from_order.up);
     }

}
 
