// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";

// Plank-only additions to DynamicFeeMod that the reference plugin does NOT have: owner-gating on the
// config setters, calldata input-cleaning (mask to width), and the uninitialized-zero-fee state.
contract DynamicFeeModGuardsTest is PlankTestBase {
    address internal module;

    // valid config words
    bytes4 constant SEL_INIT = 0xa0b66620; // initializeDynamicFee((...))
    bytes4 constant SEL_CHANGE = 0x1d39215e; // changeFeeConfiguration((...))
    bytes4 constant SEL_GETFEE = 0xdc706982; // getCurrentFee(uint88)
    bytes4 constant SEL_OWNER = 0x8da5cb5b; // owner()

    function setUp() public {
        module = deployPlank("src/modules/premium/DynamicFeeMod.plk");
    }

    function _cfgData(bytes4 sel, uint256 a1, uint256 a2, uint256 b1, uint256 b2, uint256 g1, uint256 g2, uint256 bf)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(sel, a1, a2, b1, b2, g1, g2, bf);
    }

    function _validInit() internal pure returns (bytes memory) {
        return _cfgData(SEL_INIT, 2900, 12000, 360, 60000, 59, 8500, 100);
    }

    function _owner() internal returns (address) {
        (bool ok, bytes memory r) = module.staticcall(abi.encodeWithSelector(SEL_OWNER));
        require(ok, "owner reverted");
        return abi.decode(r, (address));
    }

    // ---- owner gate ----

    // first initializeDynamicFee sets the owner (TOFU); a second init from another caller reverts.
    function test_owner_tofu_and_reinit_guard() public {
        assertEq(_owner(), address(0), "owner unset before init");

        address alice = address(0xA11CE);
        vm.prank(alice);
        (bool ok,) = module.call(_validInit());
        assertTrue(ok, "first init succeeds");
        assertEq(_owner(), alice, "owner = first initializer");

        // a different caller cannot re-initialize
        address bob = address(0xB0B);
        vm.prank(bob);
        (bool ok2,) = module.call(_cfgData(SEL_INIT, 1000, 1000, 1, 1, 10, 10, 50));
        assertFalse(ok2, "non-owner re-init reverts");
    }

    // changeFeeConfiguration is owner-gated
    function test_owner_gates_change() public {
        address alice = address(0xA11CE);
        vm.prank(alice);
        (bool ok,) = module.call(_validInit());
        assertTrue(ok, "init");

        // non-owner change reverts
        address bob = address(0xB0B);
        vm.prank(bob);
        (bool okBob,) = module.call(_cfgData(SEL_CHANGE, 1000, 1000, 1, 1, 10, 10, 50));
        assertFalse(okBob, "non-owner change reverts");

        // owner change succeeds
        vm.prank(alice);
        (bool okAlice,) = module.call(_cfgData(SEL_CHANGE, 1000, 1000, 1, 1, 10, 10, 50));
        assertTrue(okAlice, "owner change succeeds");
    }

    // ---- input cleaning (MAJOR-2) ----

    // a gamma word with dirty high bits but low-16 == 0 must revert (masks to 0 -> validate fails),
    // exactly as a clean gamma==0 would. A non-masking module would pass validate on the raw !=0.
    function test_inputCleaning_dirtyGammaReverts() public {
        // gamma1 word = 1<<16 (bit 16 set, low 16 bits zero)
        bytes memory data = _cfgData(SEL_INIT, 2900, 12000, 360, 60000, (uint256(1) << 16), 8500, 100);
        (bool ok,) = module.call(data);
        assertFalse(ok, "dirty gamma1 (low16==0) reverts like clean gamma==0");
    }

    // high bits above uint88 in the volatility word are ignored (masked), so the fee is unchanged.
    function test_inputCleaning_dirtyVolatilityIgnored() public {
        (bool ok,) = module.call(_validInit());
        assertTrue(ok, "init");

        uint256 realVol = 1234567;
        uint256 dirtyVol = (uint256(1) << 200) | (uint256(7) << 88) | realVol; // junk above bit 88
        (bool okD, bytes memory rD) = module.staticcall(abi.encodePacked(SEL_GETFEE, dirtyVol));
        require(okD, "dirty getCurrentFee reverted");
        (bool okC, bytes memory rC) = module.staticcall(abi.encodePacked(SEL_GETFEE, realVol));
        require(okC, "clean getCurrentFee reverted");
        assertEq(abi.decode(rD, (uint256)), abi.decode(rC, (uint256)), "high bits above uint88 ignored");
    }

    // ---- uninitialized hazard (documented, not a feature) ----

    // before any init: owner == 0 and getCurrentFee == 0 (zero config -> base_fee 0). The deployer MUST
    // initialize before a pool relies on this; asserted here to pin the hazard state, not endorse it.
    function test_uninitialized_zeroFee_hazard() public {
        assertEq(_owner(), address(0), "uninitialized: owner 0");
        (bool ok, bytes memory r) = module.staticcall(abi.encodePacked(SEL_GETFEE, uint256(999999)));
        require(ok, "getCurrentFee reverted");
        assertEq(abi.decode(r, (uint256)), 0, "uninitialized: zero premium HAZARD (must init first)");
    }
}
