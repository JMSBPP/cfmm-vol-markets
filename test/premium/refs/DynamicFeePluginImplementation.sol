// SPDX-License-Identifier: BUSL-1.1
// VENDORED byte-identical from @cryptoalgebra/dynamic-fee-plugin@2.2.0
// contracts/DynamicFeePluginImplementation.sol -- the differential oracle for DynamicFeeMod. Changes
// vs upstream: pragma relaxed =0.8.20 -> >=0.8.0; AdaptiveFee/DynamicFeeStorage imports repointed to
// the vendored copies; config types to the dep path; the `is IDynamicFeePluginImplementation`
// interface inheritance dropped (immaterial to behavior, avoids vendoring the interface). The four
// method bodies are verbatim. It has NO access control (the real one is gated by a delegatecall
// connector) -- which makes it directly deployable + callable as an oracle, and is exactly why the
// Plank module ADDS an owner gate (tested separately).
pragma solidity >=0.8.0;

import '@cryptoalgebra/dynamic-fee-plugin/types/AlgebraFeeConfiguration.sol';
import { AlgebraFeeConfigurationU144, AlgebraFeeConfigurationU144Lib } from '@cryptoalgebra/dynamic-fee-plugin/types/AlgebraFeeConfigurationU144.sol';
import './AdaptiveFee.sol';
import './DynamicFeeStorage.sol';

/// @title DynamicFee Plugin Implementation (vendored oracle)
contract DynamicFeePluginImplementation {
  using AlgebraFeeConfigurationU144Lib for AlgebraFeeConfiguration;

  function initializeDynamicFee(AlgebraFeeConfiguration memory config) external {
    AdaptiveFee.validateFeeConfiguration(config);
    DynamicFeeStorage.layout().feeConfig = config.pack();
  }

  function getCurrentFee(uint88 volatilityAverage) external view returns (uint16 fee) {
    AlgebraFeeConfigurationU144 feeConfig_ = DynamicFeeStorage.layout().feeConfig;

    if (feeConfig_.alpha1() | feeConfig_.alpha2() == 0) return feeConfig_.baseFee();
    return AdaptiveFee.getFee(volatilityAverage, feeConfig_);
  }

  function changeFeeConfiguration(AlgebraFeeConfiguration calldata config) external {
    AdaptiveFee.validateFeeConfiguration(config);
    DynamicFeeStorage.layout().feeConfig = config.pack();
  }

  function getFeeConfig()
    external
    view
    returns (uint16 alpha1, uint16 alpha2, uint32 beta1, uint32 beta2, uint16 gamma1, uint16 gamma2, uint16 baseFee)
  {
    AlgebraFeeConfigurationU144 feeConfig_ = DynamicFeeStorage.layout().feeConfig;

    (alpha1, alpha2) = (feeConfig_.alpha1(), feeConfig_.alpha2());
    (beta1, beta2) = (feeConfig_.beta1(), feeConfig_.beta2());
    (gamma1, gamma2) = (feeConfig_.gamma1(), feeConfig_.gamma2());
    baseFee = feeConfig_.baseFee();
  }
}
