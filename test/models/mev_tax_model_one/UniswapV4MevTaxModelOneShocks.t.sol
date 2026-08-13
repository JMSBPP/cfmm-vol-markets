/********************************************************************************************************/
/* // SPDX-License-Identifier: MIT								        */
/* pragma solidity ^0.8.0;									        */
/* 												        */
/* import {Test} from "forge-std/Test.sol";							        */
/* import {PlankTestBase} from "../../PlankTestBase.sol";					        */
/* import {BuildOptions, Dependency} from "plank-foundry-deployer/PlankDeployer.sol";		        */
/* 												        */
/* interface IAlgebraIntegralMevTaxModelOneShocksWriter{					        */
/*     function shock(address,int24,uint160,uint24,uint24) external;				        */
/* }												        */
/* 												        */
/* contract AlgebraIntegralMevTaxModelOneShocksTest is PlankTestBase {				        */
/*      BuildOptions model_opts;								        */
/* 												        */
/*      function setUp() public {								        */
/* 	Dependency[] memory deps = new Dependency[](10);					        */
/*         deps[0] = Dependency("v3", "lib/plankified-univ3/plank/lib");			        */
/*         deps[1] = Dependency("std", "lib/plank-monorepo/std/");				        */
/*         deps[2] = Dependency("pos_spec", "src/types/pos_spec");				        */
/*         deps[3] = Dependency("lib", "src/lib");						        */
/*         deps[4] = Dependency("types", "src/types");						        */
/*         deps[5] = Dependency("interfaces", "src/interfaces");				        */
/* 												        */
/* 	deps[6] = Dependency("model_interfaces", "src/models/mev_tax_model_one/interfaces/");	        */
/* 	deps[7] = Dependency("model_libraries", "src/models/mev_tax_model_one/libraries/");	        */
/* 	deps[8] = Dependency("model_types", "src/models/mev_tax_model_one/types");		        */
/* 	deps[9] = Dependency("model_modules", "src/models/mev_tax_model_one/modules");		        */
/* 	model_opts.dependencies = deps;								        */
/*         deployPlank("src/models/mev_tax_model_one/modules/.plk");				        */
/* 	deployPlank("src/models/mev_tax_model_one/modules/.plk");				        */
/*     }											        */
/* }												        */
/********************************************************************************************************/
