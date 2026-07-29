// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

// The Plank rpow port must match solady's FixedPointMathLib.rpow exactly — it is the reference Bunni's
// LDFs use for the geometric kernel's alpha^i (xi^i). Tested in the LDF regime: base <= Q96 (fixed-point
// <= 1.0, so no overflow), integer exponent = tick index within the window.
contract FixedPointMathTest is PlankTestBase {
    // FFI-deployed Plank harness (FixedPointMathHarness.plk):
    //   rpow(uint256 x, uint256 y, uint256 b) -> uint256
    address internal harness;

    uint256 constant Q96 = 1 << 96;

    function setUp() public {
        harness = deployPlank("src/lib/math/FixedPointMathHarness.plk");
    }

    function _rpow(uint256 x, uint256 y, uint256 b) internal returns (uint256) {
        (bool ok, bytes memory ret) =
            harness.staticcall(abi.encodeWithSignature("rpow(uint256,uint256,uint256)", x, y, b));
        require(ok, "rpow reverted");
        return abi.decode(ret, (uint256));
    }

    function test_rpow_golden() public {
        assertEq(_rpow(Q96 / 2, 2, Q96), Q96 / 4, "0.5^2 == 0.25 in Q96");
    }

    function testFuzz_rpow_matchesSolady(uint256 xR, uint256 yR) public {
        uint256 x = bound(xR, 0, Q96); // base <= 1.0 (Q96): the LDF regime, no overflow
        uint256 y = bound(yR, 0, 4095); // exponent = tick index within the LDF window
        assertEq(_rpow(x, y, Q96), FixedPointMathLib.rpow(x, y, Q96), "plank rpow must equal solady rpow");
    }
}
