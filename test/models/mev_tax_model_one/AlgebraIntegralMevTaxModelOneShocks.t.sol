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
import {IAlgebraPlugin} from "@cryptoalgebra/integral-core/interfaces/plugin/IAlgebraPlugin.sol";
import {PositionValue} from "@cryptoalgebra/integral-periphery/libraries/PositionValue.sol";
import {INonfungiblePositionManager} from "@cryptoalgebra/integral-periphery/interfaces/INonfungiblePositionManager.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";

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

// keccak256("Shock(address,int24,uint24,uint24)") — ShockLib.shock_emit; topic1 = pool (indexed).
bytes32 constant SHOCK_TOPIC0 = 0x21b0e4f81f5ef89be4325ca74966f2fb8f57a217e284dd3e0a276fff55987d64;

// The writer implements the INonfungiblePositionManager subset PositionValue reads (positions +
// poolDeployer), exposing its own seeded liquidity as tokenId 1. Until that plank surface exists,
// PositionValue.total reverts (RED). See the north-star test below.
uint256 constant WRITER_POSITION_ID = 1;

// keccak256("SwapFee(address,uint24,uint24)") — the pool emits this with the applied override.
bytes32 constant SWAPFEE_TOPIC0 = 0x9443903d84c9719611bd4bba871daaf18a3950d00d5d78b1a2fa701f76df54ff;
// v6.0 shock payload: flags=0b010 (txlVolmNormRate only), rate = 222 pips = phi_M for the north-star.
uint24 constant NORTH_STAR_PHI_M = 222;


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
             vm.skip(true, "awaiting volume_path.json - off-chain rpc_api bridge (#25), delegated");
             return;
         }

         string memory json = vm.readFile(VOLUME_PATH_JSON);

         // Pool identity (#29): ATTACH to the live pool the path was solved against, at its block —
         // never construct a fresh one. `pool` is the attach target; `blockNumber` pins the fork
         // (a >53-bit JSON STRING, per §3); `chainId` is the wrong-network guard.
         address fxPool = json.readAddress(".pool");
         uint256 fxBlockNumber = vm.parseUint(json.readString(".blockNumber"));
         uint256 fxChainId = json.readUint(".chainId");

         // §3: sqrtPriceX96/liquidity are JSON STRINGS (exceed the 53-bit double-exact ceiling) —
         // read as strings and parse to integers, NEVER as JSON numbers/doubles.
         uint160 fxSqrtPrice = uint160(vm.parseUint(json.readString(".sqrtPriceX96")));
         uint128 fxLiquidity = uint128(vm.parseUint(json.readString(".liquidity")));
         int256[] memory dQx = json.readIntArray(".dQx");
         uint256 nEvents = json.readUint(".nEvents");

         require(nEvents > 0, "empty path");
         assertEq(dQx.length, nEvents, "dQx length must equal nEvents");

         // Gate A guard: skips (naming the endpoint + arm) when no rig serves the fork. Below runs only
         // when a live rig is attached — so CI's --offline forge job skips here, unblocking #45's gate.
         if (!_attachPool(fxPool, fxBlockNumber, fxChainId)) return;

         // The fixture must have been solved for THIS pool's state; pinned to fxBlockNumber this is a
         // determinism guard, not a race (issue #29).
         (uint160 sqrtPrice, , , , , ) = IAlgebraPoolState(activePool).globalState();
         assertEq(uint256(sqrtPrice), uint256(fxSqrtPrice), "pool sqrtPrice != fixture sqrtPriceX96");
         assertEq(uint256(IAlgebraPoolState(activePool).liquidity()), uint256(fxLiquidity), "pool liquidity != fixture liquidity");

         // TODO(#26 SELECTOR_NEXT): route the dQx path through the pool's ON-FORK plugin
         // (IAlgebraPoolState(activePool).plugin()) — NOT setUp's in-process shocks_writer, which has
         // no code on the fork — with shocks as hookData. Snapshot tick, replay (last swap limited at
         // SQRT_PRICE_1_1, VOLUME_PATH.md §3), assert tickAfter == tickBefore.
     }

     /// @notice #29 + Gate A: ATTACH to the live rig the fixture was published against, at its block —
     /// never construct a fresh pool. EXPLICIT EXCEPTION to #29's "never skip / fail-loud" rule, written
     /// here so the two rules stop contradicting: this is a LIVE-RIG INTEGRATION test, run as the
     /// sequence deploy-rig -> capture-loop -> forge -> deploy-rig --stop. On CI the forge job runs
     /// --offline with no rig, so when NO node is reachable at the endpoint, or its head is below the
     /// fork target, this SKIPS and NAMES the endpoint + which arm failed (a bare skip would fail-open,
     /// the shape 23-RESEARCH forbids). #29's fail-loud STILL governs the rig-present-but-wrong cases:
     /// wrong chainId and attach-not-construct both `require`-revert below, never skip. Endpoint resolves
     /// ETH_RPC_URL -> foundry.toml `local` default. Returns false (already skipped) when no rig serves
     /// the fork; true when attached.
     function _attachPool(address fxPool, uint256 fxBlockNumber, uint256 fxChainId)
         internal
         returns (bool attached)
     {
         string memory url = vm.envOr("ETH_RPC_URL", vm.rpcUrl("local"));

         // Liveness arms, fails-CLOSED. __rigHead forks in an EXTERNAL self-call so the cheatcode revert
         // on an unreachable/offline endpoint is a catchable external-call revert (a same-contract
         // cheatcode revert is not try/catch-able). Arm 1: no node reachable. Arm 2: head < fork target.
         try this.__rigHead(url) returns (uint256 head) {
             if (head < fxBlockNumber) {
                 vm.skip(true, string.concat(
                     "VolumePath: rig head ", vm.toString(head), " < fork target ",
                     vm.toString(fxBlockNumber), " at ", url,
                     " -- run deploy-rig -> capture-loop -> this test on the SAME rig (its forkHeight)."
                 ));
                 return false;
             }
         } catch {
             vm.skip(true, string.concat(
                 "VolumePath: no node reachable at ", url,
                 " -- live-rig integration test; CI's --offline forge job has no rig, so it skips here."
             ));
             return false;
         }

         console2.log("VolumePath: attaching to", url);
         vm.createSelectFork(url, fxBlockNumber); // rig confirmed live above; fails loud on a real problem
         require(block.chainid == fxChainId, "VolumePath: wrong chain (check ETH_RPC_URL)");
         require(fxPool.code.length > 0, "VolumePath: pool not deployed on fork (attach, not construct)");
         activePool = fxPool;
         // TODO(Gate B): `.pool` is the PoolManager (v4-style singleton, per the fixture's topic1 ruling),
         // NOT an Algebra pool contract -- token0()/token1()/globalState()/liquidity() on it revert. The
         // dQx replay must read pool state via PoolManager.extsload keyed by poolId (as the loop does),
         // not through IAlgebraPool* on activePool. The guard skips before this on the offline gate.
         token0 = MockERC20(IAlgebraPoolImmutables(activePool).token0());
         token1 = MockERC20(IAlgebraPoolImmutables(activePool).token1());
         return true;
     }

     /// @dev External so a fork attempt against an unreachable/offline endpoint reverts as a CATCHABLE
     /// external-call revert (a same-contract cheatcode revert cannot be try/catch-ed). Returns the
     /// reachable rig's head block; _attachPool compares it to the fork target and skips if below.
     function __rigHead(string calldata url) external returns (uint256) {
         uint256 forkId = vm.createFork(url); // reverts (caught by _attachPool) if unreachable/offline
         vm.selectFork(forkId);
         return block.number;
     }

     /// @notice EXEC-03: the writer, as the pool's plugin, must set pluginConfig during init to
     /// BEFORE_SWAP_FLAG | DYNAMIC_FEE = 0x81 — so the pool calls beforeSwap with the swap hookData
     /// and honors beforeSwap's feeOverride (fee-0). RED until SELECTOR_INIT calls setPluginConfig;
     /// this also settles empirically whether the plugin is authorized to call it.
     function test__unit__pluginConfigEnablesBeforeSwapAndDynamicFee() public {
         MockERC20 tokenA = new MockERC20("TOKEN_A", "TOKEN_A", 18);
         MockERC20 tokenB = new MockERC20("TOKEN_B", "TOKEN_B", 18);
         MockERC20 asset;
         MockERC20 numeraire;
         if (address(tokenA) < address(tokenB)) { asset = tokenA; numeraire = tokenB; } else { asset = tokenB; numeraire = tokenA; }

         asset.mint(address(shocks_writer), MAX_SUPPLY);
         numeraire.mint(address(shocks_writer), MAX_SUPPLY);
         shocks_writer.init(deploy_algebra.algebra_factory(), address(asset), address(numeraire));
         address pool = IAlgebraFactory(deploy_algebra.algebra_factory()).poolByPair(address(asset), address(numeraire));

         (, , , uint8 pluginConfig, , ) = IAlgebraPoolState(pool).globalState();
         assertEq(uint256(pluginConfig), 0x81, "writer must set pluginConfig = BEFORE_SWAP | DYNAMIC_FEE");
     }

     /// @notice #34: the writer's beforeSwap decodes the packed shock hookData, emits the Shock event
     /// keyed by the calling pool, and returns feeOverride = phi_M = the shock's txlVolmNormRate (the
     /// MEV tax, applied via DYNAMIC_FEE). Calls beforeSwap directly, pranked as the pool.
     function test__unit__beforeSwap_emitsShock_andAppliesPhiM() public {
         _createPool();
         bytes memory hookData = abi.encodePacked(uint8(0x02), uint24(222)); // v6.0: txlVolmNormRate only

         vm.recordLogs();
         vm.prank(activePool);
         (bytes4 sel, uint24 feeOverride, uint24 pluginFee) =
             IAlgebraPlugin(address(shocks_writer)).beforeSwap(
                 address(this), address(this), true, int256(1), SQRT_PRICE_1_1, false, hookData
             );
         assertEq(sel, IAlgebraPlugin.beforeSwap.selector, "returns beforeSwap selector");
         assertEq(uint256(feeOverride), 222, "feeOverride = phi_M (the shock's txlVolmNormRate)");
         assertEq(uint256(pluginFee), 0, "pluginFee = 0");

         Vm.Log[] memory logs = vm.getRecordedLogs();
         bool found;
         for (uint256 i = 0; i < logs.length; i++) {
             if (logs[i].topics[0] == SHOCK_TOPIC0) {
                 found = true;
                 assertEq(address(uint160(uint256(logs[i].topics[1]))), activePool, "indexed pool == caller");
                 (int24 tick, uint24 norm, uint24 decay) = abi.decode(logs[i].data, (int24, uint24, uint24));
                 assertEq(tick, int24(0), "tickDiff 0");
                 assertEq(norm, uint24(222), "txlVolmNormRate 222");
                 assertEq(decay, uint24(0), "txlVolmDecay 0");
             }
         }
         assertTrue(found, "Shock event emitted");
     }

     /// @notice #33: the writer serves the INonfungiblePositionManager subset PositionValue reads
     /// (positions + poolDeployer). PositionValue.total must return the writer's seeded-position value
     /// WITHOUT reverting — the value is non-zero (there is real seeded liquidity). RED until #33.
     function test__unit__writerAsNfpm_positionValueReadable() public {
         _createPool();
         INonfungiblePositionManager nfpm = INonfungiblePositionManager(address(shocks_writer));
         (uint160 sqrtP, , , , , ) = IAlgebraPoolState(activePool).globalState();
         (uint256 a0, uint256 a1) = PositionValue.total(nfpm, WRITER_POSITION_ID, sqrtP);
         assertTrue(a0 > 0 || a1 > 0, "writer NFPM position must have non-zero value");
     }

     /// @notice NORTH-STAR (hard-RED, self-contained, never skips): the MEV-tax thesis in one test.
     /// A price round-trip (out, then back to the start price) leaves the tick UNCHANGED (price
     /// invariant), yet the LP's position value — read via the periphery PositionValue library, with
     /// the WRITER ITSELF standing in as the INonfungiblePositionManager — is STRICTLY GREATER after
     /// than before. At the invariant price the principal term is identical, so the entire positive
     /// delta is fees accrued: the LP captured value on a net-zero price move.
     ///
     /// LOCKS the goal — stays RED until ALL of:
     ///   (1) the writer implements the INonfungiblePositionManager subset (positions + poolDeployer),
     ///       else PositionValue.total reverts here;
     ///   (2) the round-trip closes the tick (the writer's swap routing / #26 SELECTOR_NEXT);
     ///   (3) the model applies a non-zero MEV fee (phi_M) on-chain, else fees == 0 and the payoff is
     ///       not strictly positive (today beforeSwap returns feeOverride = 0).
     function test__e2e__priceInvariantWithPositiveLpPayoff() public {
         _createPool(); // writer creates + seeds the pool at SQRT_PRICE_1_1 across [1/4, 4]

         INonfungiblePositionManager nfpm = INonfungiblePositionManager(address(shocks_writer));

         (uint160 sqrtBefore, int24 tickBefore, , , , ) = IAlgebraPoolState(activePool).globalState();
         (uint256 a0Before, uint256 a1Before) = PositionValue.total(nfpm, WRITER_POSITION_ID, sqrtBefore);

         // Self-contained round-trip through the plugin (beforeSwap fires -> shock + fee). The last leg
         // limits at SQRT_PRICE_1_1 so price halts exactly at tick 0.
         bytes memory shockData = abi.encodePacked(uint8(0x02), NORTH_STAR_PHI_M);
         vm.recordLogs();
         // out: sell token0, price down (stops short of the 1/4 band edge)
         IAlgebraPoolActions(activePool).swap(address(this), true, int256(1e16), SQRT_PRICE_1_4 + 1, shockData);
         // back: sell token1, price up, halting EXACTLY at the start price (tick 0)
         IAlgebraPoolActions(activePool).swap(address(this), false, int256(1e18), SQRT_PRICE_1_1, shockData);

         (uint160 sqrtAfter, int24 tickAfter, , , , ) = IAlgebraPoolState(activePool).globalState();
         (uint256 a0After, uint256 a1After) = PositionValue.total(nfpm, WRITER_POSITION_ID, sqrtAfter);

         // (a) price invariant — the round-trip returns to the start
         assertEq(tickAfter, tickBefore, "price must return to start (invariant round-trip)");

         // (b) the applied fee is the MEV tax phi_M (the shock's txlVolmNormRate), NOT the pool default
         //     500 — so the payoff traces to the tax, not the vanilla fee. beforeSwap returns
         //     feeOverride = phi_M; the pool emits SwapFee(overrideFee = phi_M) per swap.
         Vm.Log[] memory logs = vm.getRecordedLogs();
         uint256 taxedSwaps;
         for (uint256 i = 0; i < logs.length; i++) {
             if (logs[i].topics[0] == SWAPFEE_TOPIC0) {
                 (uint24 overrideFee, ) = abi.decode(logs[i].data, (uint24, uint24));
                 assertEq(uint256(overrideFee), uint256(NORTH_STAR_PHI_M), "applied fee must be phi_M (the MEV tax), not the default");
                 taxedSwaps++;
             }
         }
         assertEq(taxedSwaps, 2, "both round-trip swaps must apply the tax");

         // (c) strictly positive LP payoff — at the invariant price the whole delta is fees from phi_M
         assertGt(a0After, a0Before, "LP fee payoff in token0 must be strictly positive");
         assertGt(a1After, a1Before, "LP fee payoff in token1 must be strictly positive");
     }

}
