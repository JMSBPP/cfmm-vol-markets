// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TickMath} from "@cryptoalgebra/integral-core/contracts/libraries/TickMath.sol";

contract TmpAlgebraImportTest is Test {
    function test_algebraTickMathImport() public pure {
        int24 tick = TickMath.getTickAtSqrtRatio(TickMath.getSqrtRatioAtTick(0));
        assertEq(tick, 0);
    }
}
