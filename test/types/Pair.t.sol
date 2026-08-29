// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "../PlankTestBase.sol";

contract PairTest is PlankTestBase {
    address internal harness;
    address internal constant ADDR_LO = address(0x0000000000000000000000000000000000000001);
    address internal constant ADDR_HI = address(0x0000000000000000000000000000000000000002);

    function setUp() public {
        harness = deployPlank("test/types/PairHarness.plk");
    }

    function _pair(address a, address b, uint256 assetIdx)
        internal
        returns (address token0, address token1, uint256 assetIndex)
    {
        (bool ok, bytes memory ret) = harness.staticcall(
            abi.encodeWithSignature("pair(address,address,uint256)", a, b, assetIdx)
        );
        require(ok, "pair reverted");
        return abi.decode(ret, (address, address, uint256));
    }

    function test__unit__noSwap_assetSlot0() public {
        (address t0, address t1, uint256 ai) = _pair(ADDR_LO, ADDR_HI, 0);
        assertEq(t0, ADDR_LO);
        assertEq(t1, ADDR_HI);
        assertEq(ai, 0);
    }

    function test__unit__noSwap_assetSlot1() public {
        (address t0, address t1, uint256 ai) = _pair(ADDR_LO, ADDR_HI, 1);
        assertEq(t0, ADDR_LO);
        assertEq(t1, ADDR_HI);
        assertEq(ai, 1);
    }

    function test__unit__swap_assetSlot0() public {
        (address t0, address t1, uint256 ai) = _pair(ADDR_HI, ADDR_LO, 0);
        assertEq(t0, ADDR_LO);
        assertEq(t1, ADDR_HI);
        assertEq(ai, 1);
    }

    function test__unit__swap_assetSlot1() public {
        (address t0, address t1, uint256 ai) = _pair(ADDR_HI, ADDR_LO, 1);
        assertEq(t0, ADDR_LO);
        assertEq(t1, ADDR_HI);
        assertEq(ai, 0);
    }

    function test__unit__assetCanonicalRegardlessOfCalldataOrder() public {
        (address t0a, address t1a, uint256 aia) = _pair(ADDR_LO, ADDR_HI, 0);
        (address t0b, address t1b, uint256 aib) = _pair(ADDR_HI, ADDR_LO, 1);
        assertEq(t0a, t0b);
        assertEq(t1a, t1b);
        assertEq(aia, aib);
        assertEq(aia, 0, "ADDR_LO is asset in both paths");
    }

    function test__unit__equalAddressesRevert() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("pair(address,address,uint256)", ADDR_LO, ADDR_LO, 0)
        );
        assertFalse(ok, "a == b must revert");
    }

    function test__unit__assetIdxAboveOneReverts() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("pair(address,address,uint256)", ADDR_LO, ADDR_HI, 2)
        );
        assertFalse(ok, "asset_idx > 1 must revert, not mask");
    }
}
