// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

/// @dev CREATE SemiFungiblePositionManagerV4 from pinned `.bytecode/panoptic/` creation
///      bytecode (see `scripts/export-sfpm-bytecode.sh`). Keeps SFPM out of the root forge
///      compile graph (stack-too-deep / via_ir on e502).
library SfpmBytecodeDeployer {
    function deploy(
        Vm vm,
        IPoolManager manager,
        uint256 minEnforcedTickFillCost,
        uint256 nativeEnforcedTickFillCost,
        uint256 supplyMultiplierTickFill
    ) internal returns (address sfpm) {
        bytes memory creation = vm.parseBytes(
            vm.readFile(".bytecode/panoptic/SemiFungiblePositionManagerV4.bytecode")
        );
        bytes memory initCode = abi.encodePacked(
            creation,
            abi.encode(
                manager, minEnforcedTickFillCost, nativeEnforcedTickFillCost, supplyMultiplierTickFill
            )
        );
        assembly {
            sfpm := create(0, add(initCode, 0x20), mload(initCode))
        }
        require(sfpm != address(0), "SFPM bytecode deploy failed");
    }
}
