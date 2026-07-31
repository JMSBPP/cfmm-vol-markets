// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankDeployer, BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {TickBitmap} from "univ4-core/libraries/TickBitmap.sol";
import {TickMath} from "@cryptoalgebra/integral-core/libraries/TickMath.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import "bunni-v2/src/lib/Math.sol" as BunniMathLib;


interface IVolRangeWidthType {
    function pack_vol_range_width(uint24,uint24) external returns (bytes32);
    function unpack_vol_range_width(bytes32) external returns (uint24, uint24);
    function vol_range_width_bounds(uint24) external returns(uint24, uint24);
    function build_vol_range_width(uint24,int24,int24) external returns(uint24, uint24);
    function add_vol_range_width(uint24,uint24,uint24,uint24) external returns(uint24,uint24);
    function sub_vol_range_width(uint24,uint24,uint24,uint24) external returns(uint24, uint24);
    function eq_vol_range_width(uint24,uint24,uint24,uint24) external returns(bool);
    function neq_vol_range_width(uint24,uint24,uint24,uint24) external returns(bool);
    function leq_vol_range_width(uint24,uint24,uint24,uint24) external returns(bool);
    function geq_vol_range_width(uint24,uint24,uint24,uint24) external returns(bool);
}

contract VolRangeWidthTest is Test , PlankDeployer{

    IVolRangeWidthType volRangeWidthImpl;
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
	volRangeWidthImpl = IVolRangeWidthType(plankDeployFFI("test/types/pos_spec/VolRangeWidthHelper.plk", opts));

    }

    function test__fuzz__volWidthRangePackUnpack_valid(
						       uint24 _width,
						       uint24 _tickSpacing
    ) public {
	_width = uint24(bound(_width, 1, type(uint24).max));
	_tickSpacing = uint24(bound(_tickSpacing, 1, 200));

	// tickSpacing packs at bit 24 (width is the low 24-bit field), matching the canonical
	// pack_vol_range_width: (width & 0xFFFFFF) | ((tickSpacing & 0xFFFFFF) << 24). This test
	// previously shifted by 32, so unpack read a garbage tickSpacing (>200) and the helper's
	// completeness check reverted.
	bytes32 packed = bytes32(uint256(_width) | (uint256(_tickSpacing) << 24));

	(uint24 width, uint24 tickSpacing) =
	    volRangeWidthImpl.unpack_vol_range_width(packed);

	assertEq(width, _width);
	assertEq(tickSpacing, _tickSpacing);
    }

    function test__fuzz__volWidthRangePackUnpack_invalid(
							 uint24 _width,
							 uint24 _tickSpacing
    ) public {
 	vm.assume(_width == 0 || _tickSpacing == 0 || _tickSpacing > 200);

	bytes32 packed = bytes32(uint256(_width) | (uint256(_tickSpacing) << 32));

	vm.expectRevert();
	volRangeWidthImpl.unpack_vol_range_width(packed);
    }

    function test__fuzz__volRangeWidthBounds_valid(uint24 tickSpacing) public {
	vm.assume(tickSpacing > 0 && tickSpacing <= 200);
	(int24 tickMaxPerTickSpacing, int24 tickMinPerTickSpacing ) =
	    (TickBitmap.compress(TickMath.MAX_TICK, int24(tickSpacing))*int24(tickSpacing), TickBitmap.compress(TickMath.MIN_TICK,int24(tickSpacing))*int24(tickSpacing));
	uint24 maxVolRangeWidthVal = uint24(FixedPointMathLib.abs(int256(tickMaxPerTickSpacing) - int256(tickMinPerTickSpacing)) / tickSpacing);
	(uint24 actualMaxVolRangeWidthVal, uint24 _tickSpacing) = volRangeWidthImpl.vol_range_width_bounds(tickSpacing);
	assertEq(maxVolRangeWidthVal, actualMaxVolRangeWidthVal);
	assertEq(tickSpacing, _tickSpacing);
    }

    function test__fuzz__volRangeWidthBounds_invalid(uint24 tickSpacing) public {
	vm.assume(tickSpacing == 0 || tickSpacing > 200);
	vm.expectRevert();
	volRangeWidthImpl.vol_range_width_bounds(tickSpacing);
    }

    function test__fuzz__volWidthRangeBuildVolRangeWidth_valid (uint24 tickSpacing, int24 tickLower, int24 tickUpper) public {
	(uint24 width, uint24 _tickSpacing )= volRangeWidthImpl.build_vol_range_width(tickSpacing, tickLower, tickUpper);
	
	int24 lower = tickLower;
	int24 upper = tickUpper;

	if (lower > upper) { (lower, upper) = (upper, lower);}
	(int24 roundedLower, int24 roundedUpper) = (BunniMathLib.roundTickSingle(lower, int24(tickSpacing)),BunniMathLib.roundTickSingle(upper, int24(tickSpacing)));
	uint24 expectedWidth = uint24(uint256(int256(roundedUpper - roundedLower) / int256(uint256(tickSpacing))));

	assertEq(tickSpacing, _tickSpacing);
	assertEq(expectedWidth, width);
    }

    function test__fuzz__volWidthRangeBuildVolRangeWidth_invalidTickSpacing(uint24 tickSpacing, int24 tickLower, int24 tickUpper) public {
	vm.assume(tickSpacing == 0 || tickSpacing > 200);
	vm.expectRevert();
	volRangeWidthImpl.build_vol_range_width(tickSpacing, tickLower, tickUpper);
    }

    function test__fuzz__volWidthRangeBuildVolRangeWidth_invalidTickBounds(uint24 tickSpacing, int24 tickLower, int24 tickUpper) public {
	 (int24 tickMaxPerTickSpacing, int24 tickMinPerTickSpacing ) =
	    (TickBitmap.compress(TickMath.MAX_TICK, int24(tickSpacing))*int24(tickSpacing), TickBitmap.compress(TickMath.MIN_TICK,int24(tickSpacing))*int24(tickSpacing));
	 vm.assume(tickUpper > tickMaxPerTickSpacing || tickLower < tickMinPerTickSpacing);
	 vm.expectRevert();
	 volRangeWidthImpl.build_vol_range_width(tickSpacing, tickLower, tickUpper);
    }

function test__fuzz__volWidthRangeSub_valid(
    uint24 ts1,
    uint24 w1,
    uint24 w2
) public {
    ts1 = uint24(bound(ts1, 1, 200));
    w1 = uint24(bound(w1, 1, type(uint24).max));
    w2 = uint24(bound(w2, 1, type(uint24).max));

    (uint24 wSub, uint24 tsSub) =
        volRangeWidthImpl.sub_vol_range_width(w1, ts1, w2, ts1);

    uint24 expected =
        w1 >= w2 ? w1 - w2 : w2 - w1;

    assertEq(tsSub, ts1);
    assertEq(wSub, expected);
}
 function test__fuzz__volWidthRangeAdd_valid(
    uint24 ts,
    uint24 w1,
    uint24 w2
) public {
    ts = uint24(bound(ts, 1, 200));
    // Bound w1 to leave headroom so w1 + w2 cannot overflow uint24 AND the w2 bound stays
    // well-formed. Previously w1 could reach type(uint24).max, making the w2 bound
    // `bound(w2, 1, max - w1)` collapse to bound(_, 1, 0) -> "Max is less than min".
    w1 = uint24(bound(w1, 1, type(uint24).max - 1));
    w2 = uint24(bound(w2, 1, type(uint24).max - w1));

    (uint24 wAdd, uint24 tsAdd) =
        volRangeWidthImpl.add_vol_range_width(w1, ts, w2, ts);

    assertEq(tsAdd, ts);
    assertEq(wAdd, w1 + w2);
}

 function test__fuzz__volWidthRangeSub_spacingMismatch_reverts(
    uint24 ts1,
    uint24 ts2,
    uint24 w1,
    uint24 w2
) public {
    vm.assume(ts1 > 0 && ts1 <= 200);
    vm.assume(ts2 > 0 && ts2 <= 200);
    vm.assume(ts1 != ts2);
    vm.assume(w1 > 0 && w2 > 0);

    vm.expectRevert();
    volRangeWidthImpl.sub_vol_range_width(w1, ts1, w2, ts2);
}

function test__fuzz__volWidthRangeEq_valid(
    uint24 ts,
    uint24 w1,
    uint24 w2
) public {
    ts = uint24(bound(ts, 1, 200));
    vm.assume(w1 > 0 && w2 > 0);

    bool eq = volRangeWidthImpl.eq_vol_range_width(w1, ts, w2, ts);

    assertEq(eq, w1 == w2);
}

function test__fuzz__volWidthRangeEq_spacingMismatch_reverts(
    uint24 ts1,
    uint24 ts2,
    uint24 w1,
    uint24 w2
) public {
    vm.assume(ts1 > 0 && ts1 <= 200);
    vm.assume(ts2 > 0 && ts2 <= 200);
    vm.assume(ts1 != ts2);
    vm.assume(w1 > 0 && w2 > 0);

    vm.expectRevert();
    volRangeWidthImpl.eq_vol_range_width(w1, ts1, w2, ts2);
}

 function test__fuzz__volWidthRangeNeq_valid(
    uint24 ts,
    uint24 w1,
    uint24 w2
) public {
    ts = uint24(bound(ts, 1, 200));
    vm.assume(w1 > 0 && w2 > 0);

    bool neq = volRangeWidthImpl.neq_vol_range_width(w1, ts, w2, ts);

    assertEq(neq, w1 != w2);
}

function test__fuzz__volWidthRangeNeq_spacingMismatch_reverts(
    uint24 ts1,
    uint24 ts2,
    uint24 w1,
    uint24 w2
) public {
    vm.assume(ts1 > 0 && ts1 <= 200);
    vm.assume(ts2 > 0 && ts2 <= 200);
    vm.assume(ts1 != ts2);
    vm.assume(w1 > 0 && w2 > 0);

    vm.expectRevert();
    volRangeWidthImpl.neq_vol_range_width(w1, ts1, w2, ts2);
}

 function test__fuzz__volWidthRangeLeq_valid(
    uint24 ts,
    uint24 w1,
    uint24 w2
) public {
    ts = uint24(bound(ts, 1, 200));
    vm.assume(w1 > 0 && w2 > 0);

    bool leq = volRangeWidthImpl.leq_vol_range_width(w1, ts, w2, ts);

    assertEq(leq, w1 <= w2);
}

function test__fuzz__volWidthRangeLeq_spacingMismatch_reverts(
    uint24 ts1,
    uint24 ts2,
    uint24 w1,
    uint24 w2
) public {
    vm.assume(ts1 > 0 && ts1 <= 200);
    vm.assume(ts2 > 0 && ts2 <= 200);
    vm.assume(ts1 != ts2);
    vm.assume(w1 > 0 && w2 > 0);

    vm.expectRevert();
    volRangeWidthImpl.leq_vol_range_width(w1, ts1, w2, ts2);
}

 function test__fuzz__volWidthRangeGeq_valid(
    uint24 ts,
    uint24 w1,
    uint24 w2
) public {
    ts = uint24(bound(ts, 1, 200));
    vm.assume(w1 > 0 && w2 > 0);

    bool geq = volRangeWidthImpl.geq_vol_range_width(w1, ts, w2, ts);

    assertEq(geq, w1 >= w2);
}

function test__fuzz__volWidthRangeGeq_spacingMismatch_reverts(
    uint24 ts1,
    uint24 ts2,
    uint24 w1,
    uint24 w2
) public {
    vm.assume(ts1 > 0 && ts1 <= 200);
    vm.assume(ts2 > 0 && ts2 <= 200);
    vm.assume(ts1 != ts2);
    vm.assume(w1 > 0 && w2 > 0);

    vm.expectRevert();
    volRangeWidthImpl.geq_vol_range_width(w1, ts1, w2, ts2);
}
 
}
