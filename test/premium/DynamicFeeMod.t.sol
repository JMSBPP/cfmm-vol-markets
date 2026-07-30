// SPDX-License-Identifier: MIT
// ^0.8.0: the vendored plugin oracle + Algebra config libs pin =0.8.20 (project convention).
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {AlgebraFeeConfiguration} from "@cryptoalgebra/dynamic-fee-plugin/types/AlgebraFeeConfiguration.sol";
import {DynamicFeePluginImplementation} from "./refs/DynamicFeePluginImplementation.sol";

// The Plank DynamicFeeMod must match the real (vendored) DynamicFeePluginImplementation on its full
// stateful surface: initializeDynamicFee, getCurrentFee (incl. short-circuit), getFeeConfig. Owner-gate
// + input-cleaning are Plank-only additions, tested in DynamicFeeModGuards.t.sol.
contract DynamicFeeModTest is PlankTestBase {
    address internal module; // Plank DynamicFeeMod (deployed via FFI)
    DynamicFeePluginImplementation internal oracle;

    function setUp() public {
        module = deployPlank("src/modules/premium/DynamicFeeMod.plk");
        oracle = new DynamicFeePluginImplementation();
    }

    // init BOTH with the same config (identical calldata; module also captures owner = this test).
    function _initBoth(AlgebraFeeConfiguration memory cfg) internal {
        oracle.initializeDynamicFee(cfg);
        (bool ok,) = module.call(abi.encodeCall(DynamicFeePluginImplementation.initializeDynamicFee, (cfg)));
        require(ok, "module initializeDynamicFee reverted");
    }

    function _moduleGetFee(uint88 vol) internal returns (uint256) {
        (bool ok, bytes memory r) = module.staticcall(abi.encodeWithSignature("getCurrentFee(uint88)", vol));
        require(ok, "module getCurrentFee reverted");
        return abi.decode(r, (uint256));
    }

    function _moduleGetConfig()
        internal
        returns (uint256 a1, uint256 a2, uint256 b1, uint256 b2, uint256 g1, uint256 g2, uint256 bf)
    {
        (bool ok, bytes memory r) = module.staticcall(abi.encodeWithSignature("getFeeConfig()"));
        require(ok, "module getFeeConfig reverted");
        (a1, a2, b1, b2, g1, g2, bf) = abi.decode(r, (uint256, uint256, uint256, uint256, uint256, uint256, uint256));
    }

    function _validCfg(uint16 a1R, uint16 a2R, uint32 b1, uint32 b2, uint16 g1R, uint16 g2R, uint16 bfR)
        internal
        pure
        returns (AlgebraFeeConfiguration memory)
    {
        // alpha1+alpha2+baseFee <= 65535 ; gammas >= 1
        uint16 a1 = uint16(uint256(a1R) % 20001);
        uint16 a2 = uint16(uint256(a2R) % 20001);
        uint16 bf = uint16(uint256(bfR) % 20001);
        uint16 g1 = uint16((uint256(g1R) % type(uint16).max) + 1);
        uint16 g2 = uint16((uint256(g2R) % type(uint16).max) + 1);
        return AlgebraFeeConfiguration(a1, a2, b1, b2, g1, g2, bf);
    }

    // getCurrentFee == the real plugin over fuzzed valid configs x uint88 vol (covers short-circuit + get_fee).
    function testFuzz_getCurrentFee_matchesPlugin(
        uint88 vol, uint16 a1R, uint16 a2R, uint32 b1, uint32 b2, uint16 g1R, uint16 g2R, uint16 bfR
    ) public {
        AlgebraFeeConfiguration memory cfg = _validCfg(a1R, a2R, b1, b2, g1R, g2R, bfR);
        _initBoth(cfg);
        assertEq(_moduleGetFee(vol), uint256(oracle.getCurrentFee(vol)), "getCurrentFee == plugin");
    }

    // getFeeConfig == the real plugin (7 fields round-trip)
    function testFuzz_getFeeConfig_matchesPlugin(
        uint16 a1R, uint16 a2R, uint32 b1, uint32 b2, uint16 g1R, uint16 g2R, uint16 bfR
    ) public {
        AlgebraFeeConfiguration memory cfg = _validCfg(a1R, a2R, b1, b2, g1R, g2R, bfR);
        _initBoth(cfg);
        (uint256 a1, uint256 a2, uint256 pb1, uint256 pb2, uint256 g1, uint256 g2, uint256 bf) = _moduleGetConfig();
        (uint16 oa1, uint16 oa2, uint32 ob1, uint32 ob2, uint16 og1, uint16 og2, uint16 obf) = oracle.getFeeConfig();
        assertEq(a1, oa1, "alpha1");
        assertEq(a2, oa2, "alpha2");
        assertEq(pb1, ob1, "beta1");
        assertEq(pb2, ob2, "beta2");
        assertEq(g1, og1, "gamma1");
        assertEq(g2, og2, "gamma2");
        assertEq(bf, obf, "baseFee");
    }

    // short-circuit: alpha1=alpha2=0 => getCurrentFee == baseFee for all vol, matching the plugin.
    function test_getCurrentFee_shortCircuit() public {
        AlgebraFeeConfiguration memory cfg = AlgebraFeeConfiguration(0, 0, 360, 60000, 59, 8500, 250);
        _initBoth(cfg);
        assertEq(_moduleGetFee(0), 250, "vol=0 -> baseFee");
        assertEq(_moduleGetFee(type(uint88).max), 250, "vol=max -> baseFee (short-circuit)");
        assertEq(_moduleGetFee(1234567), uint256(oracle.getCurrentFee(1234567)), "== plugin");
    }
}
