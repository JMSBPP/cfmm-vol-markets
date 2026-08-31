// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";

/// @dev LegWeight {1..127} + LegBook quantize round(127·n_k/n_max) — Haskell binToLegs ors.
contract LegBookTest is PlankTestBase {
    address internal harness;

    function setUp() public {
        harness = deployPlank("test/types/pos_spec/LegBookHarness.plk");
    }

    function _tryLegWeight(uint256 w) internal returns (uint256) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("tryLegWeight(uint256)", w));
        require(ok, "tryLegWeight reverted");
        return abi.decode(r, (uint256));
    }

    function _bookWeights(uint256 n0, uint256 n1, uint256 n2, uint256 n3)
        internal
        returns (uint256 w0, uint256 w1, uint256 w2, uint256 w3)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "legBookWeightsFromNotionals(uint256,uint256,uint256,uint256)", n0, n1, n2, n3
            )
        );
        require(ok, "legBookWeightsFromNotionals reverted");
        return abi.decode(r, (uint256, uint256, uint256, uint256));
    }

    function _bookAt(uint256 n0, uint256 n1, uint256 n2, uint256 n3, uint256 leg)
        internal
        returns (uint256)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "legBookAtFromNotionals(uint256,uint256,uint256,uint256,uint256)",
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

    function _round127(uint256 n, uint256 nMax) internal pure returns (uint256) {
        return (127 * n + nMax / 2) / nMax;
    }

    function test_legWeight_zeroReverts() public {
        (bool ok,) = harness.staticcall(abi.encodeWithSignature("tryLegWeight(uint256)", 0));
        assertFalse(ok, "w=0 must revert");
    }

    function test_legWeight_oneOk() public {
        assertEq(_tryLegWeight(1), 1);
    }

    function test_legWeight_maxOk() public {
        assertEq(_tryLegWeight(127), 127);
    }

    function test_legWeight_128Reverts() public {
        (bool ok,) = harness.staticcall(abi.encodeWithSignature("tryLegWeight(uint256)", 128));
        assertFalse(ok, "w=128 must revert");
    }

    function test_legBook_equalNotionals_allMaxWeight() public {
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3) = _bookWeights(10, 10, 10, 10);
        assertEq(w0, 127);
        assertEq(w1, 127);
        assertEq(w2, 127);
        assertEq(w3, 127);
    }

    function test_legBook_fromNotionals_matchesHaskellRound() public {
        uint256 n0 = 100;
        uint256 n1 = 50;
        uint256 n2 = 25;
        uint256 n3 = 10;
        uint256 nMax = 100;
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3) = _bookWeights(n0, n1, n2, n3);
        assertEq(w0, _round127(n0, nMax), "w0");
        assertEq(w1, _round127(n1, nMax), "w1");
        assertEq(w2, _round127(n2, nMax), "w2");
        assertEq(w3, _round127(n3, nMax), "w3");
    }

    function test_legBook_at_matchesWeights() public {
        (uint256 w0, uint256 w1, uint256 w2, uint256 w3) = _bookWeights(100, 50, 25, 10);
        assertEq(_bookAt(100, 50, 25, 10, 0), w0);
        assertEq(_bookAt(100, 50, 25, 10, 1), w1);
        assertEq(_bookAt(100, 50, 25, 10, 2), w2);
        assertEq(_bookAt(100, 50, 25, 10, 3), w3);
    }

    function test_legBook_at_leg4Reverts() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "legBookAtFromNotionals(uint256,uint256,uint256,uint256,uint256)",
                10,
                10,
                10,
                10,
                4
            )
        );
        assertFalse(ok, "leg>=4 must revert");
    }

    function test_legBook_zeroNotionalReverts() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "legBookWeightsFromNotionals(uint256,uint256,uint256,uint256)", 100, 0, 10, 10
            )
        );
        assertFalse(ok, "n_k=0 must revert");
    }
}
