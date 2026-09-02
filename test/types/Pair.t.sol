// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "../PlankTestBase.sol";
import {PairVerifyCompliantERC20} from "../mocks/PairVerifyCompliantERC20.sol";

interface IPairHarness {
  function pair(address a, address b, uint256 assetIdx)
    external
    returns (address token0, address token1, uint256 assetIndex);
}

contract PairTest is PlankTestBase {
  IPairHarness internal pairHarness;
  PairVerifyCompliantERC20 internal asset;
  PairVerifyCompliantERC20 internal numeraire;

  function setUp() public {
    pairHarness = IPairHarness(deployPlank("test/types/PairHarness.plk"));
  }

  function test__fuzz__pairRevertsOnRawAddresses(address a, address b, uint256 assetIdx) public {
    vm.assume(a != b && a != address(0) && b != address(0));
    vm.assume(assetIdx <= 1);

    (bool ok,) = address(pairHarness).call{gas: 10_000_000}(
      abi.encodeWithSignature("pair(address,address,uint256)", a, b, assetIdx)
    );
    assertFalse(ok, "raw addresses must fail pair_verify_erc20 inside pair()");
  }

  function test__unit__pairBuildSuccess_assetSlot0() public {
    asset = new PairVerifyCompliantERC20();
    numeraire = new PairVerifyCompliantERC20();

    address a = address(asset);
    address b = address(numeraire);
    (address t0, address t1, uint256 ai) = pairHarness.pair(a, b, 0);

    address lo = a < b ? a : b;
    address hi = a < b ? b : a;
    assertEq(t0, lo);
    assertEq(t1, hi);
    assertEq(ai, a == lo ? 0 : 1);
  }

  function test__unit__pairBuildSuccess_assetSlot1() public {
    asset = new PairVerifyCompliantERC20();
    numeraire = new PairVerifyCompliantERC20();

    address a = address(asset);
    address b = address(numeraire);
    (address t0, address t1, uint256 ai) = pairHarness.pair(a, b, 1);

    address lo = a < b ? a : b;
    address hi = a < b ? b : a;
    assertEq(t0, lo);
    assertEq(t1, hi);
    assertEq(ai, a == lo ? 1 : 0);
  }
}
