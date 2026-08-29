// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "../PlankTestBase.sol";
import {PairVerifyCompliantERC20} from "../mocks/PairVerifyCompliantERC20.sol";
import {PairVerifyBadTransferERC20} from "../mocks/PairVerifyBadTransferERC20.sol";
import {PairVerifyBadAllowanceERC20} from "../mocks/PairVerifyBadAllowanceERC20.sol";

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

    function test__unit__compliantErc20Errors_matchOz() public {
        PairVerifyCompliantERC20 t = new PairVerifyCompliantERC20();
        (bool ok1, bytes memory d1) = address(t).call(
            abi.encodeWithSelector(PairVerifyCompliantERC20.transfer.selector, address(this), uint256(1))
        );
        assertFalse(ok1);
        assertEq(bytes4(d1), bytes4(0xe450d38c));

        vm.prank(address(harness));
        (bool ok2, bytes memory d2) = address(t).call(
            abi.encodeWithSelector(
                PairVerifyCompliantERC20.transferFrom.selector, address(harness), address(harness), uint256(1)
            )
        );
        assertFalse(ok2);
        assertEq(bytes4(d2), bytes4(0xfb8f41b2));
    }

    function _pairVerifyErc20(address a, address b, uint256 assetIdx) internal {
        (bool ok,) = harness.call{gas: 10_000_000}(
            abi.encodeWithSignature("pairVerifyErc20(address,address,uint256)", a, b, assetIdx)
        );
        require(ok, "pairVerifyErc20 reverted");
    }

    function test__unit__pairVerifyErc20_acceptsCompliantTokens() public {
        PairVerifyCompliantERC20 t0 = new PairVerifyCompliantERC20();
        PairVerifyCompliantERC20 t1 = new PairVerifyCompliantERC20();
        _pairVerifyErc20(address(t0), address(t1), 0);
    }

    function test__unit__pairVerifyErc20_rejectsBadTransfer() public {
        PairVerifyBadTransferERC20 t0 = new PairVerifyBadTransferERC20();
        PairVerifyCompliantERC20 t1 = new PairVerifyCompliantERC20();
        (bool ok,) = harness.call{gas: 10_000_000}(
            abi.encodeWithSignature("pairVerifyErc20(address,address,uint256)", address(t0), address(t1), 0)
        );
        assertFalse(ok, "bad transfer token must fail verify");
    }

    function test__unit__pairVerifyErc20_rejectsBadAllowance() public {
        PairVerifyCompliantERC20 t0 = new PairVerifyCompliantERC20();
        PairVerifyBadAllowanceERC20 t1 = new PairVerifyBadAllowanceERC20();
        (bool ok,) = harness.call{gas: 10_000_000}(
            abi.encodeWithSignature("pairVerifyErc20(address,address,uint256)", address(t0), address(t1), 0)
        );
        assertFalse(ok, "wrong allowance revert must fail verify");
    }

    function test__unit__pairVerifyErc20_rejectsEoa() public {
        address eoa = address(0xBEEF);
        PairVerifyCompliantERC20 t1 = new PairVerifyCompliantERC20();
        (bool ok,) = harness.call{gas: 10_000_000}(
            abi.encodeWithSignature("pairVerifyErc20(address,address,uint256)", eoa, address(t1), 0)
        );
        assertFalse(ok, "EOA must fail balanceOf probe");
    }
}
