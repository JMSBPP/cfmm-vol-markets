// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "@test/PlankTestBase.sol";
import {console2} from "forge-std/console2.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {Constants} from "v4-core-test/utils/Constants.sol";
import {HookDeployer} from "@helpers/UniswapV4/HookDeployer.sol";
import {SfpmBytecodeDeployer} from "@helpers/UniswapV4/SfpmBytecodeDeployer.sol";
import {StateView} from "v4-periphery/lens/StateView.sol";
import {IStateView} from "v4-periphery/interfaces/IStateView.sol";
import {IPoolManager as IPoolManagerPeriphery, PoolId} from "v4-periphery/interfaces/IStateView.sol";

import {PoolKey as PoolKeyPeriphery} from "v4-periphery/lens/ReservesLens.sol";
import {PoolIdLibrary} from "v4-periphery/lens/ReservesLens.sol";

import {NoFeeVarianceClaimBuilderPermissions} from "@helpers/Permissions.sol";

interface IMarketBuilder {
    function setPair(address,address,bool) external;
}

interface IMarketLens {
    function getMarketKey() external returns(bytes memory);
}

interface IEnv {
    function setIO(address) external;
    function IO() external returns(address);
    function setPoolManager(address) external;
    function setPositionManager(address) external;
}

contract BaseTest is PlankTestBase, Deployers, HookDeployer {
        address main = makeAddr("cfmm-vol-markets.main");
	address target = makeAddr("cfmm-vol-markets.test.target");
	address poolManager;
	address positionManager;
	address poolManagerLens;
	address underlying = makeAddr("cfmm.vol-markets.underlying");
	address numeraire =  makeAddr("cfmm.vol-markets.numeraire");

	modifier TickAlignmentContext () {
	    IEnv(target).setIO(main);
	    _;
	}
	// call to non-contract address 0x164fAe1BAFeAe4E678D34Fb7E1Da8A2Ec7a1E6B9
	modifier FullContext () {
	    IEnv(target).setIO(main);
	    IMarketBuilder(main).setPair(underlying,numeraire,true);
	    IEnv(target).setPoolManager(poolManager);
	    IEnv(main).setPoolManager(poolManager);
	    IEnv(target).setPositionManager(positionManager);
	    IEnv(main).setPositionManager(positionManager);
	    _;
	}


	error FailedToDeployUniswapV4Hook();
	function setUp() public virtual {
	    deployFreshManager();
	    poolManager = address(manager);
	    positionManager = SfpmBytecodeDeployer.deploy(
	    vm, manager, 2100000000000000000000, 2100000000000000000000, 10000);
	    poolManagerLens = address(new StateView(IPoolManagerPeriphery(address(manager))));
	    deployCodeTo(main, compilePlank("src/Main.plk"));
	}

	function deployUniswapV4Hook(string memory path) internal returns(address hookDeployed) {
	    (bool succ, address _tmp,) = deployHook(
					       compilePlank(path),
					       CREATE2_FACTORY,
					       NoFeeVarianceClaimBuilderPermissions
	    );
	    if (succ) { hookDeployed = _tmp;}
	    if (hookDeployed == address(0x00)) { revert FailedToDeployUniswapV4Hook();}
	    return hookDeployed;
	}
}

