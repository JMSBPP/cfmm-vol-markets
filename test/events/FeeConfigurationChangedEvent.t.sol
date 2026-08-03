// SPDX-License-Identifier: MIT
// ^0.8.0: the vendored Algebra config libs pin =0.8.20 (project convention).
pragma solidity ^0.8.0;

import {PlankTestBase} from "../PlankTestBase.sol";
import {Vm} from "forge-std/Vm.sol";
import {AlgebraFeeConfiguration} from "@cryptoalgebra/dynamic-fee-plugin/types/AlgebraFeeConfiguration.sol";
import {DynamicFeePluginImplementation} from "../premium/refs/DynamicFeePluginImplementation.sol";

// ===========================================================================================
// EV-04: E4 FeeConfigurationChanged on DynamicFeeMod
// (.planning/events-subgraph-gams-SPEC.md D4/E4, D8).
//
//   E4 FeeConfigurationChanged(bytes32 indexed poolId, uint16 alpha1, uint16 alpha2,
//                              uint32 beta1, uint32 beta2, uint16 gamma1, uint16 gamma2,
//                              uint16 baseFee)
//
// Field names and widths are Algebra's AlgebraFeeConfiguration VERBATIM (the faithful-port
// rule); the doc-symbol mapping (alpha_j, beta_j, gamma_j, phi-bar = baseFee -- Theta_phi)
// lives in the data contract. poolId is the PERMANENT module-global sentinel bytes32(0)
// (spec D2): this module NEVER emits a real poolId; the pool-keyed hook is a new emitter.
//
// MUTANTS this file kills (spec EV battery):
//   - missing emit on initialize / change        -> the two expectEmit tests
//   - wrong topic0 / signature-string drift      -> test__unit__topicZeroMatchesSolc
//   - field-order swap (alpha/gamma/baseFee are
//     all uint16 -- order is ONLY pinned by the
//     solc-encoded expectation)                  -> byte-exact expectEmit, distinct values
//   - emit-before-validate (config rejected but
//     event emitted)                             -> test__unit__invalidChangeEmitsNothing
//   - emit on the unauthorized path              -> test__unit__unauthorizedChangeEmitsNothing
// ===========================================================================================
contract FeeConfigurationChangedEventTest is PlankTestBase {
    event FeeConfigurationChanged(
        bytes32 indexed poolId,
        uint16 alpha1,
        uint16 alpha2,
        uint32 beta1,
        uint32 beta2,
        uint16 gamma1,
        uint16 gamma2,
        uint16 baseFee
    );

    /// @dev Restated from VolEventsLib.plk
    ///      (cast keccak "FeeConfigurationChanged(bytes32,uint16,uint16,uint32,uint32,uint16,uint16,uint16)").
    bytes32 internal constant TOPIC0_FEE_CONFIGURATION_CHANGED =
        0x0b849672f272805103d1934909aaee0c4e1400438ff5365f6d9d147cb07ed6cf;

    address internal module;

    // Distinct values per field ON PURPOSE: alpha1/alpha2/gamma1/gamma2/baseFee share a width,
    // so only distinct values make the solc-encoded expectation kill a field-order swap.
    AlgebraFeeConfiguration internal CFG =
        AlgebraFeeConfiguration({alpha1: 2900, alpha2: 12000, beta1: 360, beta2: 60000, gamma1: 59, gamma2: 8500, baseFee: 100});

    function setUp() public {
        module = deployPlank("src/modules/premium/DynamicFeeMod.plk");
    }

    function _call(bytes memory cd) internal returns (bool ok) {
        (ok,) = module.call(cd);
    }

    function test__unit__topicZeroMatchesSolc() public pure {
        assertEq(
            FeeConfigurationChanged.selector,
            TOPIC0_FEE_CONFIGURATION_CHANGED,
            "pinned cast-keccak constant == solc's canonical topic0"
        );
    }

    function test__unit__initializeEmitsFeeConfigurationChanged() public {
        vm.expectEmit(true, true, true, true, module);
        emit FeeConfigurationChanged(
            bytes32(0), CFG.alpha1, CFG.alpha2, CFG.beta1, CFG.beta2, CFG.gamma1, CFG.gamma2, CFG.baseFee
        );
        assertTrue(
            _call(abi.encodeCall(DynamicFeePluginImplementation.initializeDynamicFee, (CFG))),
            "initializeDynamicFee succeeds"
        );
    }

    function test__unit__changeEmitsFeeConfigurationChanged() public {
        assertTrue(_call(abi.encodeCall(DynamicFeePluginImplementation.initializeDynamicFee, (CFG))), "init");

        AlgebraFeeConfiguration memory next =
            AlgebraFeeConfiguration({alpha1: 100, alpha2: 200, beta1: 3, beta2: 4, gamma1: 5, gamma2: 6, baseFee: 7});
        vm.expectEmit(true, true, true, true, module);
        emit FeeConfigurationChanged(
            bytes32(0), next.alpha1, next.alpha2, next.beta1, next.beta2, next.gamma1, next.gamma2, next.baseFee
        );
        assertTrue(
            _call(abi.encodeCall(DynamicFeePluginImplementation.changeFeeConfiguration, (next))),
            "changeFeeConfiguration succeeds"
        );
    }

    // A rejected config (gamma == 0 fails validate) reverts and must not emit -- and a revert
    // discards logs at the EVM level, so the REAL assertion is that the call FAILS; the
    // recordLogs count then documents the no-emit outcome explicitly.
    function test__unit__invalidChangeEmitsNothing() public {
        assertTrue(_call(abi.encodeCall(DynamicFeePluginImplementation.initializeDynamicFee, (CFG))), "init");
        AlgebraFeeConfiguration memory bad =
            AlgebraFeeConfiguration({alpha1: 1, alpha2: 1, beta1: 1, beta2: 1, gamma1: 0, gamma2: 1, baseFee: 1});
        vm.recordLogs();
        assertFalse(
            _call(abi.encodeCall(DynamicFeePluginImplementation.changeFeeConfiguration, (bad))),
            "invalid config reverts"
        );
        assertEq(vm.getRecordedLogs().length, 0, "rejected config emits nothing");
    }

    // A non-owner change reverts (owner-gate) and must not emit.
    function test__unit__unauthorizedChangeEmitsNothing() public {
        assertTrue(_call(abi.encodeCall(DynamicFeePluginImplementation.initializeDynamicFee, (CFG))), "init");
        vm.recordLogs();
        vm.prank(address(0xBAD));
        (bool ok,) = module.call(abi.encodeCall(DynamicFeePluginImplementation.changeFeeConfiguration, (CFG)));
        assertFalse(ok, "non-owner change reverts");
        assertEq(vm.getRecordedLogs().length, 0, "unauthorized change emits nothing");
    }
}
