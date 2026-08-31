// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";

/// @dev LegBook(BaseNotional): open LegWeightBound, weights, stored base = ⌊n_max/b⌋.
contract LegBookTest is PlankTestBase {
    address internal harness;

    uint256 constant BOUND_PANOPTIC = 127;

    function setUp() public {
        harness = deployPlank("test/types/pos_spec/LegBookHarness.plk");
    }

    function _tryBound(uint256 b) internal returns (uint256) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("tryLegWeightBound(uint256)", b));
        require(ok, "tryLegWeightBound reverted");
        return abi.decode(r, (uint256));
    }

    function _tryWeight(uint256 bound, uint256 w) internal returns (uint256) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("tryLegWeight(uint256,uint256)", bound, w));
        require(ok, "tryLegWeight reverted");
        return abi.decode(r, (uint256));
    }

    function _bookFrom(uint256 bound, uint256 n0, uint256 n1, uint256 n2, uint256 n3)
        internal
        returns (uint256 w0, uint256 w1, uint256 w2, uint256 w3, uint256 base)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "legBookFromNotionals(uint256,uint256,uint256,uint256,uint256)",
                bound,
                n0,
                n1,
                n2,
                n3
            )
        );
        require(ok, "legBookFromNotionals reverted");
        return abi.decode(r, (uint256, uint256, uint256, uint256, uint256));
    }

    function _bookAt(uint256 bound, uint256 n0, uint256 n1, uint256 n2, uint256 n3, uint256 leg)
        internal
        returns (uint256)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "legBookAtFromNotionals(uint256,uint256,uint256,uint256,uint256,uint256)",
                bound,
                n0,
                n1,
                n2,
                n3,
                leg
            )
        );
        require(ok, "legBookAtFromNotionals reverted");
        return abi.decode(r, (uint256));
    }

    function _roundBound(uint256 b, uint256 n, uint256 nMax) internal pure returns (uint256) {
        return (b * n + nMax / 2) / nMax;
    }

    function test_legWeightBound_zeroReverts() public {
        (bool ok,) = harness.staticcall(abi.encodeWithSignature("tryLegWeightBound(uint256)", 0));
        assertFalse(ok);
    }

    function test_legWeightBound_128Reverts() public {
        (bool ok,) = harness.staticcall(abi.encodeWithSignature("tryLegWeightBound(uint256)", 128));
        assertFalse(ok);
    }

    function test_legWeightBound_panopticOk() public {
        assertEq(_tryBound(BOUND_PANOPTIC), BOUND_PANOPTIC);
    }

    function test_legWeight_zeroReverts() public {
        (bool ok,) =
            harness.staticcall(abi.encodeWithSignature("tryLegWeight(uint256,uint256)", BOUND_PANOPTIC, 0));
        assertFalse(ok);
    }

    function test_legWeight_aboveBoundReverts() public {
        (bool ok,) =
            harness.staticcall(abi.encodeWithSignature("tryLegWeight(uint256,uint256)", 10, 11));
        assertFalse(ok);
    }

    function test_legWeight_atBoundOk() public {
        assertEq(_tryWeight(BOUND_PANOPTIC, 127), 127);
        assertEq(_tryWeight(10, 10), 10);
    }

    function test_legBook_equalNotionals_maxWeightAndBase() public {
        // n_max=127 → base=1, all weights = bound
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3, uint256 base) =
            _bookFrom(BOUND_PANOPTIC, 127, 127, 127, 127);
        assertEq(w0, 127);
        assertEq(w1, 127);
        assertEq(w2, 127);
        assertEq(w3, 127);
        assertEq(base, 1);
    }

    function test_legBook_fromNotionals_matchesHaskellRoundAndBase() public {
        // Scale (100,50,25,10) by 127 so base = ⌊12700/127⌋ = 100
        uint256 n0 = 100 * 127;
        uint256 n1 = 50 * 127;
        uint256 n2 = 25 * 127;
        uint256 n3 = 10 * 127;
        uint256 nMax = n0;
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3, uint256 base) =
            _bookFrom(BOUND_PANOPTIC, n0, n1, n2, n3);
        assertEq(w0, _roundBound(BOUND_PANOPTIC, n0, nMax), "w0");
        assertEq(w1, _roundBound(BOUND_PANOPTIC, n1, nMax), "w1");
        assertEq(w2, _roundBound(BOUND_PANOPTIC, n2, nMax), "w2");
        assertEq(w3, _roundBound(BOUND_PANOPTIC, n3, nMax), "w3");
        assertEq(base, nMax / BOUND_PANOPTIC, "base");
    }

    function test_legBook_at_matchesWeights() public {
        uint256 n0 = 100 * 127;
        uint256 n1 = 50 * 127;
        uint256 n2 = 25 * 127;
        uint256 n3 = 10 * 127;
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3,) = _bookFrom(BOUND_PANOPTIC, n0, n1, n2, n3);
        assertEq(_bookAt(BOUND_PANOPTIC, n0, n1, n2, n3, 0), w0);
        assertEq(_bookAt(BOUND_PANOPTIC, n0, n1, n2, n3, 1), w1);
        assertEq(_bookAt(BOUND_PANOPTIC, n0, n1, n2, n3, 2), w2);
        assertEq(_bookAt(BOUND_PANOPTIC, n0, n1, n2, n3, 3), w3);
    }

    function test_legBook_at_leg4Reverts() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "legBookAtFromNotionals(uint256,uint256,uint256,uint256,uint256,uint256)",
                BOUND_PANOPTIC,
                127,
                127,
                127,
                127,
                4
            )
        );
        assertFalse(ok);
    }

    function test_legBook_zeroNotionalReverts() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "legBookFromNotionals(uint256,uint256,uint256,uint256,uint256)",
                BOUND_PANOPTIC,
                100,
                0,
                10,
                10
            )
        );
        assertFalse(ok);
    }

    function test_legBook_baseZeroReverts() public {
        // n_max < bound → ⌊n_max/b⌋ = 0
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "legBookFromNotionals(uint256,uint256,uint256,uint256,uint256)",
                BOUND_PANOPTIC,
                10,
                10,
                10,
                10
            )
        );
        assertFalse(ok);
    }

    function test_legBook_openBoundFifty() public {
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3, uint256 base) = _bookFrom(50, 100, 100, 100, 100);
        assertEq(w0, 50);
        assertEq(w1, 50);
        assertEq(w2, 50);
        assertEq(w3, 50);
        assertEq(base, 2);
    }
}
