// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {DeployAlgebraFactoryScript} from "foundry-scripts/mev_tax_model_one/DeployAlgebraFactory.s.sol";
import {IAlgebraFactory} from "@cryptoalgebra/integral-core/interfaces/IAlgebraFactory.sol";
import {IAlgebraPoolDeployer} from "@cryptoalgebra/integral-core/interfaces/IAlgebraPoolDeployer.sol";
import {IAlgebraPoolState} from "@cryptoalgebra/integral-core/interfaces/pool/IAlgebraPoolState.sol";
import {IAlgebraPoolImmutables} from "@cryptoalgebra/integral-core/interfaces/pool/IAlgebraPoolImmutables.sol";

interface IAlgebraIntegralShocksWriter{
    function init(address,address,address) external;
    function shock(address,int24,uint160,uint24,uint24) external;
}

address constant NULL_DEPLOYER = address(0x00);
uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
uint256 constant MAX_SUPPLY = type(uint256).max;
bytes constant ZERO_BYTES = new bytes(0);


contract AlgebraIntegralMevTaxModelOneShocksTest is PlankTestBase {
     BuildOptions model_opts;
     IAlgebraIntegralShocksWriter shocks_writer;
     DeployAlgebraFactoryScript deploy_algebra;
     
     function setUp() public {
	model_opts.backend = "sona";

	Dependency[] memory deps = new Dependency[](11);
        deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");
        deps[1] = Dependency("std", "lib/plank-monorepo/std/");
        deps[2] = Dependency("pos_spec", "src/types/pos_spec");
        deps[3] = Dependency("lib", "src/lib");
        deps[4] = Dependency("types", "src/types");
        deps[5] = Dependency("interfaces", "src/interfaces");
	
	deps[6] = Dependency("model_interfaces", "src/models/mev_tax_model_one/interfaces/");
	deps[7] = Dependency("model_libraries", "src/models/mev_tax_model_one/libraries/");
	deps[8] = Dependency("model_types", "src/models/mev_tax_model_one/types");
	deps[9] = Dependency("model_modules", "src/models/mev_tax_model_one/modules");
	
	model_opts.dependencies = deps;
        shocks_writer = IAlgebraIntegralShocksWriter(plankDeployFFI("src/models/mev_tax_model_one/modules/AlgebraIntegralShocksWriterMod.plk",model_opts));

	deploy_algebra = new DeployAlgebraFactoryScript();
	deploy_algebra.run();

	vm.startPrank(IAlgebraFactory(deploy_algebra.algebra_factory()).owner());
	IAlgebraFactory(deploy_algebra.algebra_factory()).setDefaultPluginFactory(address(shocks_writer));

	vm.stopPrank();
	
	
     }

     function test__placeholder() public {
	 MockERC20 tokenA = new MockERC20("TOKEN_A", "TOKEN_A", 18);
	 MockERC20 tokenB = new MockERC20("TOKEN_B", "TOKEN_B", 18);

	 MockERC20 asset;
	 MockERC20 numeraire;

	 if (address(tokenA) < address(tokenB)) { asset = tokenA;  numeraire = tokenB; } else { asset = tokenB;numeraire = tokenA;}

        assert(address(asset) < address(numeraire));

	asset.mint(address(shocks_writer), MAX_SUPPLY);
	numeraire.mint(address(shocks_writer), MAX_SUPPLY);
        
	shocks_writer.init(deploy_algebra.algebra_factory(), address(asset), address(numeraire));
	address pool = IAlgebraFactory(deploy_algebra.algebra_factory()).poolByPair(address(asset),address(numeraire));

	assertNotEq(pool,address(0x00));
	assertEq(IAlgebraPoolImmutables(pool).token0(), address(asset));
	assertEq(IAlgebraPoolState(pool).plugin(),address(shocks_writer));

     }
     
}
