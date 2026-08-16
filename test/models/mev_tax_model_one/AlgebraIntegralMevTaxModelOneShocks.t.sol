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
import {stdJson} from "forge-std/StdJson.sol";
import {IAlgebraPoolActions} from "@cryptoalgebra/integral-core/interfaces/pool/IAlgebraPoolActions.sol";
import {IAlgebraPoolPermissionedActions} from "@cryptoalgebra/integral-core/interfaces/pool/IAlgebraPoolPermissionedActions.sol";
import {IAlgebraSwapCallback} from "@cryptoalgebra/integral-core/interfaces/callback/IAlgebraSwapCallback.sol";

interface IAlgebraIntegralShocksWriter{
    function init(address,address,address) external;
    function shock(address,int24,uint160,uint24,uint24) external;
}

address constant NULL_DEPLOYER = address(0x00);
uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
uint256 constant MAX_SUPPLY = type(uint256).max;
bytes constant ZERO_BYTES = new bytes(0);

// The delegated handoff contract: the off-chain GAMS→JSON component (follow-up issue,
// post-merge) MUST write the solver output here. VOLUME_PATH.md §3 is the byte shape.
string constant VOLUME_PATH_JSON = "test/models/mev_tax_model_one/fixtures/volume_path.json";

// Seeded liquidity band edges (mirror Constants.plk: SQRT_PRICE_1_4 = 2^95, SQRT_PRICE_4_1 = 2^97).
// The pool has liquidity ONLY in price [1/4, 4], so these — not TickMath's extremes — are the
// swap price limits. A swap capped at an edge under-fills, which the replay loop's full-consumption
// guard turns into a loud failure. The LAST swap instead limits at SQRT_PRICE_1_1 (start price) so
// it halts exactly at tick 0 (VOLUME_PATH.md §3).
uint160 constant SQRT_PRICE_1_4 = 39614081257132168796771975168;   // 2^95
uint160 constant SQRT_PRICE_4_1 = 158456325028528675187087900672;  // 2^97


contract AlgebraIntegralMevTaxModelOneShocksTest is PlankTestBase, IAlgebraSwapCallback {
     BuildOptions model_opts;
     IAlgebraIntegralShocksWriter shocks_writer;
     DeployAlgebraFactoryScript deploy_algebra;

     address activePool;
     MockERC20 token0;  // asset      (token0 < token1 enforced in _createPool)
     MockERC20 token1;  // numeraire

     using stdJson for string;
     
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

     /// @notice Algebra swap payment callback — pays the pool exactly what each swap owes.
     /// Positive delta = tokens owed to the pool by this swapper; the test holds both tokens
     /// (minted in _createPool), so it can always settle. The VOLUME_PATH replay drives these.
     function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
         require(msg.sender == activePool, "callback: caller is not the pool");
         if (amount0Delta > 0) token0.transfer(activePool, uint256(amount0Delta));
         if (amount1Delta > 0) token1.transfer(activePool, uint256(amount1Delta));
     }

     /// @notice Test-side trigger only: deploys the token pair, mints, and calls the plank writer's
     /// init — which is what actually creates the pool, initializes it at SQRT_PRICE_1_1, and seeds
     /// UNIT_LIQUIDITY across [1_4, 4_1] (AlgebraIntegralShocksWriterMod.plk, SELECTOR_INIT). Stores
     /// activePool/token0/token1. Mints to the writer (funds the init seed) AND to this test (settles
     /// the temporary direct-swap callback, deleted when the writer owns swap payment).
     function _createPool() internal {
         MockERC20 tokenA = new MockERC20("TOKEN_A", "TOKEN_A", 18);
         MockERC20 tokenB = new MockERC20("TOKEN_B", "TOKEN_B", 18);
         (token0, token1) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
         assert(address(token0) < address(token1));

         uint256 mintEach = type(uint128).max;  // >> the ~2.8e19 path volume; two holders, no totalSupply overflow
         token0.mint(address(shocks_writer), mintEach);
         token1.mint(address(shocks_writer), mintEach);
         token0.mint(address(this), mintEach);
         token1.mint(address(this), mintEach);

         shocks_writer.init(deploy_algebra.algebra_factory(), address(token0), address(token1));
         activePool = IAlgebraFactory(deploy_algebra.algebra_factory()).poolByPair(address(token0), address(token1));
         assertNotEq(activePool, address(0x00));
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

     function test__priceInvarianceUnderVolumePath() public {
         if (!vm.exists(VOLUME_PATH_JSON)) {
             vm.skip(true, "awaiting volume_path.json - off-chain GAMS->JSON bridge, delegated post-merge");
             return;
         }

         string memory json = vm.readFile(VOLUME_PATH_JSON);

         // §3: sqrtPriceX96/liquidity are JSON STRINGS (exceed the 53-bit double-exact ceiling) —
         // read as strings and parse to integers, NEVER as JSON numbers/doubles.
         uint160 fxSqrtPrice = uint160(vm.parseUint(json.readString(".sqrtPriceX96")));
         uint128 fxLiquidity = uint128(vm.parseUint(json.readString(".liquidity")));
         int256[] memory dQx = json.readIntArray(".dQx");
         uint256 nEvents = json.readUint(".nEvents");

         require(nEvents > 0, "empty path");
         assertEq(dQx.length, nEvents, "dQx length must equal nEvents");

         _createPool();

         // The fixture must have been solved for THIS pool's state, or the replay is meaningless.
         (uint160 sqrtPrice, , , , , ) = IAlgebraPoolState(activePool).globalState();
         assertEq(uint256(sqrtPrice), uint256(fxSqrtPrice), "pool sqrtPrice != fixture sqrtPriceX96");
         assertEq(uint256(IAlgebraPoolState(activePool).liquidity()), uint256(fxLiquidity), "pool liquidity != fixture liquidity");

         // TODO(shocks_writer SELECTOR_NEXT): route the dQx path through shocks_writer with shocks
         // as hookData — NOT a direct pool.swap from the test. Snapshot tick before, price-limit the
         // last swap at SQRT_PRICE_1_1 (VOLUME_PATH.md §3), then assert tickAfter == tickBefore. That
         // follow-up implements SELECTOR_NEXT (a stub today) and deletes the temporary
         // algebraSwapCallback above once the writer owns swap payment.
     }

}
