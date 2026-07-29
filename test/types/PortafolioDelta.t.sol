// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {BalanceDelta, toBalanceDelta, BalanceDeltaLibrary} from "univ4-core/types/BalanceDelta.sol";

// Real v4-core BalanceDelta as the differential oracle (imports cleanly: BalanceDelta -> SafeCast -> CustomRevert).
contract BDRef {
    function pack(int128 a0, int128 a1) external pure returns (int256) {
        return BalanceDelta.unwrap(toBalanceDelta(a0, a1));
    }

    function amt0(int256 d) external pure returns (int128) {
        return BalanceDeltaLibrary.amount0(BalanceDelta.wrap(d));
    }

    function amt1(int256 d) external pure returns (int128) {
        return BalanceDeltaLibrary.amount1(BalanceDelta.wrap(d));
    }

    function add_(int256 a, int256 b) external pure returns (int256) {
        return BalanceDelta.unwrap(BalanceDelta.wrap(a) + BalanceDelta.wrap(b));
    }

    function sub_(int256 a, int256 b) external pure returns (int256) {
        return BalanceDelta.unwrap(BalanceDelta.wrap(a) - BalanceDelta.wrap(b));
    }
}

// PortafolioDelta must match v4-core BalanceDelta exactly (pack, amount0/1, add/sub incl. int128-overflow revert).
contract PortafolioDeltaTest is PlankTestBase {
    // FFI-deployed Plank harness (PortafolioDeltaHarness.plk):
    //   toDelta(int128 a0,int128 a1) -> int256 ; amt0(int256) -> int128 ; amt1(int256) -> int128
    //   deltaAdd(int256,int256) -> int256 ; deltaSub(int256,int256) -> int256   (add/sub revert on int128 overflow)
    address internal harness;
    BDRef internal ref;

    int128 constant I128_MIN = type(int128).min;
    int128 constant I128_MAX = type(int128).max;

    function setUp() public {
        harness = deployPlank("test/types/PortafolioDeltaHarness.plk");
        ref = new BDRef();
    }

    function _toDelta(int128 a0, int128 a1) internal returns (int256) {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("toDelta(int128,int128)", a0, a1));
        require(ok, "toDelta reverted");
        return abi.decode(r, (int256));
    }

    function _amt0(int256 d) internal returns (int128) {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("amt0(int256)", d));
        require(ok, "amt0 reverted");
        return abi.decode(r, (int128));
    }

    function _amt1(int256 d) internal returns (int128) {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("amt1(int256)", d));
        require(ok, "amt1 reverted");
        return abi.decode(r, (int128));
    }

    function _add(int256 a, int256 b) internal returns (bool ok, int256 res) {
        bytes memory r;
        (ok, r) = harness.staticcall(abi.encodeWithSignature("deltaAdd(int256,int256)", a, b));
        if (ok) res = abi.decode(r, (int256));
    }

    function _sub(int256 a, int256 b) internal returns (bool ok, int256 res) {
        bytes memory r;
        (ok, r) = harness.staticcall(abi.encodeWithSignature("deltaSub(int256,int256)", a, b));
        if (ok) res = abi.decode(r, (int256));
    }

    // pack + accessors match BalanceDelta over the full int128 range (the sign handling is the whole subtlety)
    function testFuzz_pack_amounts_matchBalanceDelta(int128 a0, int128 a1) public {
        int256 d = _toDelta(a0, a1);
        assertEq(d, ref.pack(a0, a1), "pack == BalanceDelta");
        assertEq(_amt0(d), a0, "amount0 round-trips");
        assertEq(_amt1(d), a1, "amount1 round-trips");
    }

    // add matches BalanceDelta when no int128 overflow (bound to half-range so both succeed)
    function testFuzz_add_matchesBalanceDelta(int128 a0, int128 a1, int128 b0, int128 b1) public {
        a0 = int128(bound(a0, I128_MIN / 2, I128_MAX / 2));
        a1 = int128(bound(a1, I128_MIN / 2, I128_MAX / 2));
        b0 = int128(bound(b0, I128_MIN / 2, I128_MAX / 2));
        b1 = int128(bound(b1, I128_MIN / 2, I128_MAX / 2));
        int256 a = ref.pack(a0, a1);
        int256 b = ref.pack(b0, b1);
        (bool ok, int256 res) = _add(a, b);
        assertTrue(ok, "add reverted in range");
        assertEq(res, ref.add_(a, b), "add == BalanceDelta");
    }

    function testFuzz_sub_matchesBalanceDelta(int128 a0, int128 a1, int128 b0, int128 b1) public {
        a0 = int128(bound(a0, I128_MIN / 2, I128_MAX / 2));
        a1 = int128(bound(a1, I128_MIN / 2, I128_MAX / 2));
        b0 = int128(bound(b0, I128_MIN / 2, I128_MAX / 2));
        b1 = int128(bound(b1, I128_MIN / 2, I128_MAX / 2));
        int256 a = ref.pack(a0, a1);
        int256 b = ref.pack(b0, b1);
        (bool ok, int256 res) = _sub(a, b);
        assertTrue(ok, "sub reverted in range");
        assertEq(res, ref.sub_(a, b), "sub == BalanceDelta");
    }

    // load-bearing golden vectors: isolate the masking / sign logic
    function test_golden_signs() public {
        // (0,-1): amount0 must decode to 0 (sar must not pick up amount1's sign bits)
        int256 d1 = _toDelta(0, -1);
        assertEq(d1, ref.pack(0, -1), "(0,-1) pack");
        assertEq(_amt0(d1), int128(0), "(0,-1) amount0 == 0");
        assertEq(_amt1(d1), int128(-1), "(0,-1) amount1 == -1");
        // (-1,0): amount1 must decode to 0 despite amount0 all-ones
        int256 d2 = _toDelta(-1, 0);
        assertEq(_amt0(d2), int128(-1), "(-1,0) amount0 == -1");
        assertEq(_amt1(d2), int128(0), "(-1,0) amount1 == 0");
        // INT128_MIN asymmetric
        int256 d3 = _toDelta(I128_MIN, I128_MAX);
        assertEq(_amt0(d3), I128_MIN, "min/max amount0");
        assertEq(_amt1(d3), I128_MAX, "min/max amount1");
        // non-revert negative add
        (bool ok, int256 r) = _add(ref.pack(0, -5), ref.pack(0, 3));
        assertTrue(ok, "negative add must not revert");
        assertEq(_amt1(r), int128(-2), "(0,-5)+(0,3) amount1 == -2");
    }

    // int128 overflow must revert (matches SafeCast.toInt128)
    function test_add_overflow_reverts() public {
        (bool ok,) = _add(ref.pack(I128_MAX, 0), ref.pack(1, 0));
        assertFalse(ok, "amount0 overflow reverts");
        (bool ok2,) = _sub(ref.pack(I128_MIN, 0), ref.pack(1, 0));
        assertFalse(ok2, "amount0 underflow reverts");
    }
}
