// SPDX-License-Identifier: MIT
// ^0.8.0 (not ^0.8.26): AdaptiveFee pins =0.8.20 (project convention, see MarketStatisticsTest).
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {AdaptiveFee} from "./refs/AdaptiveFee.sol"; // byte-identical vendored oracle (see the file header)

// Real AdaptiveFee (internal library) exposed for differential testing.
contract AFRef {
    function expXg4(uint256 x, uint16 g) external pure returns (uint256) {
        return AdaptiveFee.expXg4(x, g, uint256(g) ** 4);
    }
}

// The Plank AdaptiveFee port must be byte-identical to Algebra's.
contract AdaptiveFeeTest is PlankTestBase {
    address internal harness;
    AFRef internal ref;

    function setUp() public {
        harness = deployPlank("test/premium/AdaptiveFeeHarness.plk");
        ref = new AFRef();
    }

    function _expXg4(uint256 x, uint16 g) internal returns (uint256) {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("expXg4(uint256,uint16)", x, g));
        require(ok, "expXg4 reverted");
        return abi.decode(r, (uint256));
    }

    // exp_x_g4 == Algebra's expXg4 exactly over the sigmoid-relevant domain (x in [0, 6g), g in [1, u16]).
    function testFuzz_expXg4_matchesAlgebra(uint256 xR, uint16 gR) public {
        uint16 g = uint16(bound(gR, 1, type(uint16).max));
        uint256 x = bound(xR, 0, 6 * uint256(g)); // sigmoid guards x < 6g before calling
        assertEq(_expXg4(x, g), ref.expXg4(x, g), "exp_x_g4 == Algebra expXg4");
    }

    // golden anchors on the e^k table boundaries (x/g = 0,1,2 exactly) + a mid value.
    function test_expXg4_goldenTableBoundaries() public {
        assertEq(_expXg4(0, 59), ref.expXg4(0, 59), "x=0 -> e^0 branch");
        assertEq(_expXg4(59, 59), ref.expXg4(59, 59), "x/g=1 -> e^1 branch");
        assertEq(_expXg4(118, 59), ref.expXg4(118, 59), "x/g=2 -> e^2 branch");
        assertEq(_expXg4(30, 59), ref.expXg4(30, 59), "x/g~0.5 -> e^0.5 correction branch");
        assertEq(_expXg4(8500 * 5, 8500), ref.expXg4(8500 * 5, 8500), "x/g=5 -> default e^5 branch");
    }
}
