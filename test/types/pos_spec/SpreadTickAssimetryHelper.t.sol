// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import "bunni-v2/src/lib/Math.sol" as BunniMathV2;

interface ISpreadTickAssimetryType{
    function split_tick(uint16,uint24,uint24,int24) external returns(int24,uint24,int24);
    function tick_from_splitted_tick_bucket(uint16,uint24,uint24,int24,uint24,int24) external returns(int24);
}

contract SpreadTickAssimetryTest is Test, PlankDeployer {
    ISpreadTickAssimetryType spreadTickAssimetryImpl;
    BuildOptions opts;

     function setUp() public {
	opts.backend = "sona";
        Dependency[] memory deps = new Dependency[](4);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
	deps[1] = Dependency("std", "lib/plank-monorepo/std/");
	deps[2] = Dependency("pos_spec", "src/types/pos_spec");
	deps[3] = Dependency("lib","src/lib");
	opts.dependencies = deps;
	spreadTickAssimetryImpl = ISpreadTickAssimetryType(plankDeployFFI("test/types/pos_spec/SpreadTickAssimetryHelper.plk", opts));

     }

     function test__fuzz__spreadTickAssimetrySplitTick__Valid(uint16 spread ,uint24 rangeWidth, uint24 _tickSpacing, int24 tick) public {
	 _tickSpacing = uint24(bound(uint256(_tickSpacing), 1, 200));
	 (int24 tickLower ,uint24 tickSpacing ,int24 tickUpper) = spreadTickAssimetryImpl.split_tick(spread, rangeWidth, _tickSpacing, tick);
	 assertEq(_tickSpacing, tickSpacing);
	 int256 right = int256(FixedPointMathLib.mulDiv(uint256(rangeWidth),uint256(spread),type(uint16).max));
	 int24 expectedTickLower = BunniMathV2.roundTickSingle(tick - int24(int256(int256(uint256(rangeWidth)) - right)), int24(_tickSpacing));
	 assertEq(expectedTickLower, tickLower);
	 int24 expectedTickUp = BunniMathV2.roundTickSingle(tick + int24(right), int24(_tickSpacing));

     }

     function test__fuzz__spreadTickAssimetrySplitTick__InvalidTickSpacing(uint16 spread ,uint24 rangeWidth, uint24 _tickSpacing, int24 tick) public {
	 vm.assume(_tickSpacing > 200 || _tickSpacing == 0);
	 vm.expectRevert();
	 spreadTickAssimetryImpl.split_tick(spread, rangeWidth, _tickSpacing, tick);
     }

     function test__fuzz__tickFromSplittedTickBucket__Valid(uint16 spread ,uint24 rangeWidth,uint24 tickSpacing1 ,int24 tickLower,uint24 tickSpacing2, int24 tickUpper) public {
	 tickSpacing1 = uint24(bound(uint256(tickSpacing1), 1, 200));
	 tickSpacing2 = uint24(bound(uint256(tickSpacing2), 1, 200));
	 vm.assume(tickSpacing1 == tickSpacing2);

	 vm.assume(tickLower < tickUpper);
	 spread = uint16(bound(uint256(spread), 0, type(uint16).max -1));
	 (int24 adjustedTickLow, int24 adjustedTickUp) = (BunniMathV2.roundTickSingle(tickLower,int24(tickSpacing1)), BunniMathV2.roundTickSingle(tickUpper, int24(tickSpacing1)));

	 int256 expected =
    (
        int256(adjustedTickLow) * int256(uint256(spread))
        + int256(adjustedTickUp) * int256(uint256(type(uint16).max - spread))
    ) / int256(uint256(type(uint16).max));

    int24 expectedTick = int24(expected);
    int24 tick = spreadTickAssimetryImpl.tick_from_splitted_tick_bucket(spread,rangeWidth,tickSpacing1,tickLower,tickSpacing2,tickUpper);

	 assertEq(expectedTick, tick);
	 
     }

     // todo: More tests are required

     
     
}
