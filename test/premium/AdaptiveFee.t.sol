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

    function sigmoid(uint256 x, uint16 g, uint16 alpha, uint256 beta) external pure returns (uint256) {
        return AdaptiveFee.sigmoid(x, g, alpha, beta);
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

    // ---- Increment 3: sigmoid ----

    function _sigmoid(uint256 x, uint16 g, uint16 alpha, uint256 beta) internal returns (uint256) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("sigmoid(uint256,uint16,uint16,uint256)", x, g, alpha, beta));
        require(ok, "sigmoid reverted");
        return abi.decode(r, (uint256));
    }

    // sigmoid == Algebra exactly across both branches (x>beta / x<=beta) and both guards.
    function testFuzz_sigmoid_matchesAlgebra(uint256 xR, uint16 gR, uint16 alpha, uint32 beta) public {
        uint16 g = uint16(bound(gR, 1, type(uint16).max));
        // x spans below/above beta and beyond the +-6g guard bands
        uint256 x = bound(xR, 0, uint256(beta) + 12 * uint256(g) + 1);
        assertEq(_sigmoid(x, g, alpha, beta), ref.sigmoid(x, g, alpha, beta), "sigmoid == Algebra");
    }

    // guards + branches: x-beta >= 6g -> alpha ; beta-x >= 6g -> 0 ; and the two ratio branches.
    function test_sigmoid_goldenGuards() public {
        // upper guard: x well above beta => saturates to alpha
        assertEq(_sigmoid(60000 + 6 * 59, 59, 2900, 60000), 2900, "x-beta >= 6g -> alpha");
        assertEq(_sigmoid(60000 + 6 * 59, 59, 2900, 60000), ref.sigmoid(60000 + 6 * 59, 59, 2900, 60000), "== Algebra");
        // lower guard: x well below beta => 0
        assertEq(_sigmoid(0, 59, 2900, 60000), 0, "beta-x >= 6g -> 0");
        // mid, upper branch (x just above beta)
        assertEq(_sigmoid(60100, 8500, 12000, 60000), ref.sigmoid(60100, 8500, 12000, 60000), "upper ratio == Algebra");
        // mid, lower branch (x just below beta)
        assertEq(_sigmoid(59900, 8500, 12000, 60000), ref.sigmoid(59900, 8500, 12000, 60000), "lower ratio == Algebra");
    }
}
