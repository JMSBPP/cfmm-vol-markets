// SPDX-License-Identifier: BUSL-1.1
// VENDORED byte-identical from @cryptoalgebra/dynamic-fee-plugin@2.2.0
// contracts/libraries/DynamicFeeStorage.sol. Only change: pragma relaxed =0.8.20 -> >=0.8.0 and the
// config-type import repointed to the dep path. Used only by the vendored differential oracle.
pragma solidity >=0.8.0;

import { AlgebraFeeConfigurationU144 } from '@cryptoalgebra/dynamic-fee-plugin/types/AlgebraFeeConfigurationU144.sol';

/// @dev Shared namespaced storage for DynamicFee plugin (used by connector + implementation).
library DynamicFeeStorage {
  /// @dev keccak256(abi.encode(uint256(keccak256("erc7201:algebra.storage.dynamicfee")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 internal constant NAMESPACE = 0xfbbf1a562c70d290e080160018965a1e5db682cf55e666eca8f391a4ceef9a00;

  struct Layout {
    AlgebraFeeConfigurationU144 feeConfig;
  }

  function layout() internal pure returns (Layout storage l) {
    bytes32 position = NAMESPACE;
    assembly {
      l.slot := position
    }
  }
}
