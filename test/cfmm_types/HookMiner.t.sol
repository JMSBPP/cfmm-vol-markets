// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "../PlankTestBase.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {MinimalHook} from "cfmm-types-test/mocks/MinimalHook.sol";
import {Hooks} from "univ4-core/libraries/Hooks.sol";

/// @dev Smoke test: vol-markets can compile and call cfmm-types Hook.plk via the submodule.
contract CfmmTypesHookMinerTest is PlankTestBase, Deployers {
    address internal hookMiner;

    function setUp() public {
        deployFreshManagerAndRouters();
        hookMiner = deployCfmmTypesPlank("lib/cfmm-types/src/types/uniswap_v4/Hook.plk");
    }

    function test__deploy__mineAndCreate2Hook() public {
        uint16 flags = uint16(Hooks.BEFORE_SWAP_FLAG);
        uint256 num = 42;
        bytes memory creationCode = type(MinimalHook).creationCode;
        bytes memory constructorArgs = abi.encode(num, flags);

        (bool ok, bytes memory r) = hookMiner.call(
            abi.encodeWithSignature("mineAndDeployHook(uint256,bytes,bytes)", uint256(flags), creationCode, constructorArgs)
        );
        require(ok, "mineAndDeployHook reverted");

        (address deployed, uint256 flagBits) = abi.decode(r, (address, uint256));
        assertEq(flagBits, uint256(flags) & Hooks.ALL_HOOK_MASK, "flag bits");
        assertEq(
            uint160(deployed) & Hooks.ALL_HOOK_MASK,
            uint160(flags) & Hooks.ALL_HOOK_MASK,
            "deployed addr flags"
        );
        assertGt(deployed.code.length, 0, "must deploy bytecode");
        assertEq(MinimalHook(deployed).num(), num, "constructor arg round-trip");
    }
}
