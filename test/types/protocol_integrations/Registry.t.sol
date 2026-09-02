// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {RegistryVerifyV4} from "../../mocks/RegistryVerifyV4.sol";
import {RegistryVerifyV4NoIHooks} from "../../mocks/RegistryVerifyV4NoIHooks.sol";
import {RegistryVerifyV3Factory} from "../../mocks/RegistryVerifyV3Factory.sol";
import {RegistryVerifyBadInterface} from "../../mocks/RegistryVerifyBadInterface.sol";
import {AlgebraIntegralDeployer} from "../../helpers/AlgebraIntegralDeployer.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {Hooks} from "univ4-core/libraries/Hooks.sol";

import {MockCounterHook} from "v4-hooks-public/test/mocks/MockCounterHook.sol";

import {IAlgebraPluginFactory} from "@cryptoalgebra/integral-core/interfaces/plugin/IAlgebraPluginFactory.sol";
import {IAlgebraCustomPoolEntryPoint} from "@cryptoalgebra/integral-periphery/interfaces/IAlgebraCustomPoolEntryPoint.sol";



interface IRegistryV4{
    function setRegistry(address) external returns(address);
}

interface IHookMiner {
    function createHook(bytes32) external returns(IHooks);
}

contract RegistryTest is Deployers ,PlankTestBase {
    IRegistryV4 registryHarness;
    IHookMiner hookMiner;
    function setUp() public {
        registryHarness = IRegistryV4(deployPlank("test/types/protocol_integrations/RegistryHarness.plk"));	hookMiner = IHookMiner(deployPlank("lib/cfmm-types/src/types/uniswap_v4/Hook.plk"));

        deployFreshManagerAndRouters();
    }

    function test__fuzz__goldenPath(bytes32 fuzzedHookSalt) public {
	
	/* IHooks hookSucc = IHooks(regsitryHarness(address(hookMiner.createHook(fuzzedHookSalt)))); */
    }


}

