// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {PlankTestBase} from "test/PlankTestBase.sol";
import {RegistryVerifyV4} from "test/mocks/RegistryVerifyV4.sol";
import {MinedRegistryV4Deployer} from "test/helpers/MinedRegistryV4Deployer.sol";
import {PoolVerifyV3Pool} from "test/mocks/PoolVerifyV3Pool.sol";
import {AlgebraIntegralDeployer} from "test/helpers/AlgebraIntegralDeployer.sol";
import {IAlgebraFactory} from "@cryptoalgebra/integral-core/interfaces/IAlgebraFactory.sol";
import {IAlgebraPoolState} from "@cryptoalgebra/integral-core/interfaces/pool/IAlgebraPoolState.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {Currency} from "univ4-core/types/Currency.sol";

/// Univ3 factory stand-in: `getPool(address,address,uint24)`. SFPM V3 resolves its pool exactly
/// this way, which is why KEY-03 verifies against the registry rather than deriving via CREATE2.
contract V3FactoryStub {
    address internal immutable POOL;

    constructor(address pool_) {
        POOL = pool_;
    }

    function getPool(address, address, uint24) external view returns (address) {
        return POOL;
    }
}

/// Phase 2.5 (KEY-01): VolMarketKey(V) is a comptime type constructor over a VENUE tag.
///
/// The property under test is a TYPE-LEVEL one, so the evidence is split in two:
///   - the POSITIVE side is that the harness compiles with all three venues instantiated AND
///     reachable from run{} -- plank never type-checks an unreachable branch, which is how the
///     Phase 2 negative test was caught being meaningless on gate 33181644493;
///   - the NEGATIVE side is a fixture that must FAIL to compile, asserted on the error TEXT rather
///     than the exit code, because a fixture containing a typo also fails to compile.
contract VolMarketKeyTest is PlankTestBase, Deployers {
    address harness;
    address hookMiner;
    address v4Registry;

    function setUp() public {
        harness = deployPlank("test/protocol_integrations/VolMarketKeyHarness.plk");
        hookMiner = deployCfmmTypesPlank("lib/cfmm-types/src/types/uniswap_v4/Hook.plk");
        v4Registry = address(new RegistryVerifyV4(address(0x1)));
    }

    // ---- what must compile ---------------------------------------------------------------------

    /// venueWitness() instantiates all three venue keys and returns a per-venue code, so the
    /// assertion is not merely "it compiled": a mis-wired comptime branch changes the value.
    ///   venue_code(V4)=1, (V3)=2, (Algebra)=3  ->  1 | 2<<2 | 3<<4 = 57
    function test__unit__allThreeVenuesInstantiate() public {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("venueWitness()"));
        require(ok, "venueWitness reverted");
        assertEq(abi.decode(r, (uint256)), 57, "venue codes wrong: a comptime branch is mis-wired");
    }

    function test__unit__builderEmptyIsIncompleteCompleteKeyPasses() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("keyIsComplete()", v4Registry)
        );
        assertTrue(ok, "empty must be incomplete and full key must be complete");
    }

    function test__unit__builderPathMatchesAtomicCtor() public {
        (bool okLit, bytes memory rLit) =
            harness.staticcall(abi.encodeWithSignature("v4PoolId(uint256)", v4Registry));
        (bool okBld, bytes memory rBld) = harness.staticcall(
            abi.encodeWithSignature("buildV4PoolWordViaBuilder(uint256)", v4Registry)
        );
        require(okLit, "v4PoolId reverted");
        require(okBld, "buildV4PoolWordViaBuilder reverted");
        assertEq(abi.decode(rLit, (uint256)), abi.decode(rBld, (uint256)), "builder must match atomic ctor");
    }

    /// Golden path: None -> Some(pair) -> Some(registry) -> Some(pool) in memory, then every
    /// accessor agrees with the atomic vol_market_key(V4, Some, Some, Some) shortcut.
    function test__unit__goldenPathFillsKeyInMemory() public {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("goldenPathCompletenessBitmap(uint256)", v4Registry)
        );
        require(ok, "goldenPathCompletenessBitmap reverted");
        assertEq(
            abi.decode(r, (uint256)),
            0xff,
            "incremental in-memory build must pass all completeness stages and accessors"
        );
    }

    // ---- KEY-06 / F1: the asset/numeraire inversion ---------------------------------------------

    /// Panoptic's `asset` bit names the CASH token that positionSize is denominated in
    /// (TokenId.sol:112-116; PanopticMath.getLiquidityChunk "in TradFi, the asset is always cash").
    /// This protocol calls that token the NUMERAIRE and calls the OTHER one the asset, so the
    /// mapping INVERTS asset_index.
    ///
    /// BOTH values are asserted deliberately: a copy instead of a NOT agrees at asset_index == 1
    /// and differs only at 0, so a single-value test would pass on the wrong implementation.
    ///
    /// This is the highest-consequence assertion in the phase. Inverted, the builder emits a
    /// STRUCTURALLY VALID tokenId denominated in the wrong token: Panoptic's validate() passes,
    /// the position mints, position_size_for_target_vega inverts the wrong formula, and nothing
    /// reverts. It survives a green gate, which is why the phase's criterion 9 singles it out.
    function test__unit__panopticAssetBitInvertsAssetIndex() public {
        (bool ok0, bytes memory r0) =
            harness.staticcall(abi.encodeWithSignature("panopticAssetBit(uint256)", uint256(0)));
        require(ok0, "panopticAssetBit(0) reverted");
        assertEq(
            abi.decode(r0, (uint256)),
            1,
            "asset_index 0 (currency0 is the asset) => numeraire is currency1 => Panoptic bit 1"
        );

        (bool ok1, bytes memory r1) =
            harness.staticcall(abi.encodeWithSignature("panopticAssetBit(uint256)", uint256(1)));
        require(ok1, "panopticAssetBit(1) reverted");
        assertEq(
            abi.decode(r1, (uint256)),
            0,
            "asset_index 1 (currency1 is the asset) => numeraire is currency0 => Panoptic bit 0"
        );
    }

    /// asset_index indexes a PAIR, so its domain is {0, 1}. Anything else is a caller error and
    /// must revert rather than be silently masked -- a masked 2 would read as 0 and pick the wrong
    /// currency, which is the same failure as the inversion with a different cause.
    function test__unit__assetIndexAboveOneReverts() public {
        (bool ok,) =
            harness.staticcall(abi.encodeWithSignature("panopticAssetBit(uint256)", uint256(2)));
        assertFalse(ok, "asset_index == 2 must revert, not mask to 0");
    }

    // ---- KEY-03: the pool address is VERIFIED against the venue registry -----------------------

    /// Never CREATE2-derived, so no POOL_INIT_CODE_HASH is pinned anywhere and the same code works
    /// across forks and chains where a patched pool contract would change the init hash.
    function test__unit__v3PoolAddressVerifiedAgainstTheFactory() public {
        address pool = address(new PoolVerifyV3Pool(3000, 60));
        address factory = address(new V3FactoryStub(pool));
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("verifyPoolV3(address,address)", factory, pool)
        );
        assertTrue(ok, "a pool matching the registry must verify");
    }

    function test__unit__v3PoolAddressMismatchReverts() public {
        address pool = address(new PoolVerifyV3Pool(3000, 60));
        address factory = address(new V3FactoryStub(address(0xBEEF)));
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("verifyPoolV3(address,address)", factory, address(0xDEAD))
        );
        assertFalse(ok, "a pool the registry does not know must revert");
    }

    function test__unit__algebraPoolAddressVerifiedAgainstTheFactory() public {
        (address entryPoint, address pool, address t0, address t1) = _algebraPoolFixture();
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "verifyPoolAlgebra(address,address,uint256,uint256)", entryPoint, pool, t0, t1
            )
        );
        assertTrue(ok, "algebra pool matching poolByPair must verify");
    }

    function test__unit__algebraPoolAddressMismatchReverts() public {
        (address entryPoint,, address t0, address t1) = _algebraPoolFixture();
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature(
                "verifyPoolAlgebra(address,address,uint256,uint256)",
                entryPoint,
                address(0xDEAD),
                t0,
                t1
            )
        );
        assertFalse(ok, "algebra mismatch must revert");
    }

    // ---- KEY-03b: vol_market_key_*_at resolve + verify -----------------------------------------

    function test__unit__keyV3AtReadsFeeAndTick() public {
        address pool = address(new PoolVerifyV3Pool(3000, 60));
        address factory = address(new V3FactoryStub(pool));

        (bool okWord, bytes memory rWord) = harness.staticcall(
            abi.encodeWithSignature("keyV3AtPoolWord(address,address)", factory, pool)
        );
        require(okWord, "keyV3AtPoolWord reverted");
        assertEq(abi.decode(rWord, (uint256)), uint256(uint160(pool)), "pool_word is pool address");

        (bool okFee, bytes memory rFee) =
            harness.staticcall(abi.encodeWithSignature("keyV3AtFee(address,address)", factory, pool));
        require(okFee, "keyV3AtFee reverted");
        assertEq(abi.decode(rFee, (uint256)), 3000, "fee from on-chain read");

        (bool okTs, bytes memory rTs) = harness.staticcall(
            abi.encodeWithSignature("keyV3AtTickSpacing(address,address)", factory, pool)
        );
        require(okTs, "keyV3AtTickSpacing reverted");
        assertEq(abi.decode(rTs, (uint256)), 60, "tick_spacing from on-chain read");
    }

    function test__unit__verifyPoolV3AtPassesWhenFactoryMatches() public {
        address pool = address(new PoolVerifyV3Pool(3000, 60));
        address factory = address(new V3FactoryStub(pool));
        (bool ok,) =
            harness.staticcall(abi.encodeWithSignature("verifyPoolV3At(address,address)", factory, pool));
        assertTrue(ok, "vol_market_key_v3_at + verify_pool must pass when factory matches");
    }

    function test__unit__verifyPoolV3AtMismatchReverts() public {
        address pool = address(new PoolVerifyV3Pool(3000, 60));
        address factory = address(new V3FactoryStub(address(0xBEEF)));
        (bool ok,) =
            harness.staticcall(abi.encodeWithSignature("verifyPoolV3At(address,address)", factory, pool));
        assertFalse(ok, "vol_market_key_v3_at verify must revert on registry mismatch");
    }

    function test__unit__keyAlgebraAtAndVerify() public {
        (address entryPoint, address pool, address t0, address t1) = _algebraPoolFixture();

        (bool okWord, bytes memory rWord) = harness.staticcall(
            abi.encodeWithSignature(
                "keyAlgebraAtPoolWord(address,address,uint256,uint256)", entryPoint, pool, t0, t1
            )
        );
        require(okWord, "keyAlgebraAtPoolWord reverted");
        assertEq(abi.decode(rWord, (uint256)), uint256(uint160(pool)), "algebra pool_word is address");

        (bool okVerify,) = harness.staticcall(
            abi.encodeWithSignature(
                "verifyPoolAlgebraAt(address,address,uint256,uint256)", entryPoint, pool, t0, t1
            )
        );
        assertTrue(okVerify, "vol_market_key_algebra_at + verify_pool must pass");
    }

    function test__unit__keyV4AtAndVerifyRoundTrip() public {
        deployFreshManagerAndRouters();
        (Currency c0, Currency c1) = deployMintAndApprove2Currencies();
        uint24 fee = 0x800000;
        int24 tickSpacing = 60;
        address registry = MinedRegistryV4Deployer.deploy(hookMiner, address(manager));
        initPool(c0, c1, IHooks(registry), fee, tickSpacing, SQRT_PRICE_1_1);

        address t0 = Currency.unwrap(c0);
        address t1 = Currency.unwrap(c1);

        (bool okAt, bytes memory rAt) = harness.staticcall(
            abi.encodeWithSignature(
                "keyV4AtPoolWord(uint256,uint256,uint256,uint256,uint256)",
                uint256(uint160(registry)),
                uint256(uint160(t0)),
                uint256(uint160(t1)),
                uint256(int256(tickSpacing)),
                uint256(fee)
            )
        );
        require(okAt, "keyV4AtPoolWord reverted");
        assertEq(
            abi.decode(rAt, (uint256)),
            uint256(keccak256(abi.encode(t0, t1, fee, tickSpacing, registry))),
            "vol_market_key_v4_at must return canonical PoolId"
        );

        (bool okVerify,) = harness.staticcall(
            abi.encodeWithSignature(
                "verifyPoolV4At(uint256,uint256,uint256,uint256,uint256)",
                uint256(uint160(registry)),
                uint256(uint160(t0)),
                uint256(uint160(t1)),
                uint256(fee),
                uint256(int256(tickSpacing))
            )
        );
        assertTrue(okVerify, "vol_market_key_v4_at + verify_pool must pass against manager slot0");
    }

    /// vol_market_key_v4_at must agree with vol_market_key(V4, Some, Some, Some(pool_v4_at_keyed(...))).
    function test__unit__goldenPathV4AtMatchesLiteral() public {
        deployFreshManagerAndRouters();
        (Currency c0, Currency c1) = deployMintAndApprove2Currencies();
        uint24 fee = 0x800000;
        int24 tickSpacing = 60;
        address registry = MinedRegistryV4Deployer.deploy(hookMiner, address(manager));
        initPool(c0, c1, IHooks(registry), fee, tickSpacing, SQRT_PRICE_1_1);

        address t0 = Currency.unwrap(c0);
        address t1 = Currency.unwrap(c1);

        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "goldenPathV4AtMatchesLiteral(uint256,uint256,uint256,uint256,uint256)",
                uint256(uint160(registry)),
                uint256(uint160(t0)),
                uint256(uint160(t1)),
                uint256(int256(tickSpacing)),
                uint256(fee)
            )
        );
        require(ok, "goldenPathV4AtMatchesLiteral reverted");
        assertEq(
            abi.decode(r, (uint256)),
            1,
            "vol_market_key_v4_at must match explicit Some(...) literal assembly"
        );
    }

    /// The v4 pool id is keccak256 over the 5-field PoolKey -- the same value MarketId.plk's
    /// market_id_from_pool_key computes, which VolMarketKey(V4) subsumes rather than duplicates.
    function test__unit__v4PoolIdIsTheCanonicalUniV4PoolId() public {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("v4PoolId(uint256)", v4Registry));
        require(ok, "v4PoolId reverted");
        assertEq(
            abi.decode(r, (uint256)),
            uint256(keccak256(abi.encode(C0, C1, FEE, TICK_SPACING, v4Registry))),
            "must equal the canonical univ4 PoolId"
        );
    }

    /// vol_market_key + pair + registry_v4 + pool_v4 must agree with the literal struct path.
    function test__unit__v4KeyBuiltViaPairMatchesLiteral() public {
        (bool okLit, bytes memory rLit) =
            harness.staticcall(abi.encodeWithSignature("v4PoolId(uint256)", v4Registry));
        (bool okPair, bytes memory rPair) =
            harness.staticcall(abi.encodeWithSignature("v4KeyViaPair(uint256)", v4Registry));
        require(okLit, "v4PoolId reverted");
        require(okPair, "v4KeyViaPair reverted");
        assertEq(
            abi.decode(rLit, (uint256)),
            abi.decode(rPair, (uint256)),
            "pair-built key must match literal path"
        );
    }

    // The fixed key the harness builds for the V4 arm. Kept in both places deliberately: if they
    // drift, v4PoolIdIsTheCanonicalUniV4PoolId fails, which is the intended alarm.
    uint256 internal constant C0 = 0x1111;
    uint256 internal constant C1 = 0x2222;
    uint256 internal constant FEE = 3000;
    uint256 internal constant TICK_SPACING = 60;

    function _sortedCurrencies(uint256 a, uint256 b) internal pure returns (uint256 t0, uint256 t1) {
        return a < b ? (a, b) : (b, a);
    }

    /// Ported from MarketId.t.sol's round-trip test before that file is retired (KEY-05).
    ///
    /// The fixed-key test above pins ONE value. This pins the STRUCTURE: every one of the five
    /// PoolKey fields must feed the hash, so a field omitted from the keccak buffer, or two fields
    /// transposed, changes the id and is caught. MarketId.plk proved this by handing back the
    /// stored key; VolMarketKey IS the key, so the equivalent evidence is field sensitivity.
    ///
    /// pair() sorts token addresses before they enter the hash; expected keccak uses the same order.
    /// Registry and Pair now use addr, so fuzz inputs must fit uint160 (addr_from_u256 reverts otherwise).
    function test__fuzz__everyPoolKeyFieldFeedsTheV4PoolId(
        uint256 c0,
        uint256 c1,
        uint24 fee,
        uint24 tickSpacing
    ) public {
        vm.assume(c0 <= type(uint160).max);
        vm.assume(c1 <= type(uint160).max);
        vm.assume(c0 != c1);
        // XOR-1 perturbation of c0 must not make pair() see equal currencies.
        vm.assume(c0 != (c1 ^ 1));
        address registry = address(new RegistryVerifyV4(address(0x1)));
        uint256 got = _v4PoolIdFor(registry, c0, c1, fee, tickSpacing);
        (uint256 t0, uint256 t1) = _sortedCurrencies(c0, c1);
        assertEq(
            got,
            uint256(keccak256(abi.encode(t0, t1, uint256(fee), uint256(tickSpacing), registry))),
            "the id must be keccak over exactly these five fields, in sorted currency order"
        );

        // Perturbing any single field must change the id. XOR 1 rather than + 1: the fuzzer found
        // that `hooks + 1` panics with 0x11 when hooks == type(uint256).max (run 28 of
        // 33211646329). XOR flips the low bit, always changes the value, and cannot overflow.
        assertTrue(got != _v4PoolIdFor(registry, c0 ^ 1, c1, fee, tickSpacing), "currency0 not hashed");
        assertTrue(got != _v4PoolIdFor(registry, c0, c1 ^ 1, fee, tickSpacing), "currency1 not hashed");
        assertTrue(
            got != _v4PoolIdFor(registry, c0, c1, uint256(fee) ^ 1, tickSpacing), "fee not hashed"
        );
        assertTrue(
            got != _v4PoolIdFor(registry, c0, c1, fee, uint256(tickSpacing) ^ 1),
            "tickSpacing not hashed"
        );
        address registry2 = address(new RegistryVerifyV4(address(0x2)));
        assertTrue(
            got != _v4PoolIdFor(registry2, c0, c1, fee, tickSpacing), "registry (hooks) not hashed"
        );
    }

    function _v4PoolIdFor(address registry, uint256 c0, uint256 c1, uint256 fee, uint256 ts)
        internal
        returns (uint256)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "v4PoolIdFor(uint256,uint256,uint256,uint256,uint256)",
                registry,
                c0,
                c1,
                fee,
                ts
            )
        );
        require(ok, "v4PoolIdFor reverted");
        return abi.decode(r, (uint256));
    }

    // ---- what must NOT compile -----------------------------------------------------------------

    /// VolMarketKey.plk guards V with is_venue, so a non-venue tag is OUR error, not a stray one
    /// from deeper in std. The stderr match is what makes this test mean something: without it a
    /// typo in the fixture would produce the same non-zero exit and the test would pass vacuously.
    function test__unit__nonVenueTagDoesNotCompile() public {
        Vm.FfiResult memory r = _tryBuild("fixtures/plank-negative/VolMarketKeyBadVenue.plk");
        assertTrue(
            r.exitCode != 0, "VolMarketKey(u256) compiled; is_venue must reject a non-venue V"
        );
        assertTrue(
            _contains(r.stderr, "VolMarketKey: V must be V4, V3 or Algebra"),
            "wrong failure: not VolMarketKey's guard"
        );
    }

    // ---- helpers -----------------------------------------------------------------------------

    function _algebraPoolFixture()
        internal
        returns (address entryPoint, address pool, address t0, address t1)
    {
        MockERC20 tokenA = new MockERC20("TOKEN_A", "TOKEN_A", 18);
        MockERC20 tokenB = new MockERC20("TOKEN_B", "TOKEN_B", 18);
        if (address(tokenA) < address(tokenB)) {
            t0 = address(tokenA);
            t1 = address(tokenB);
        } else {
            t0 = address(tokenB);
            t1 = address(tokenA);
        }
        AlgebraIntegralDeployer.Deployment memory d = AlgebraIntegralDeployer.deploy(vm);
        entryPoint = d.entryPoint;
        pool = IAlgebraFactory(d.factory).createPool(t0, t1, ZERO_BYTES);
        assertNotEq(pool, address(0));
    }

    /// `plank build <path>` with the same module roots as PlankTestBase.plankOpts(), no deploy.
    /// Copied from test/types/pos_spec/VolOrderType.t.sol so the two negative harnesses stay in step.
    function _tryBuild(string memory path) internal returns (Vm.FfiResult memory) {
        string[] memory a = new string[](17);
        a[0] = "plank";
        a[1] = "build";
        a[2] = path;
        a[3] = "--backend";
        a[4] = "sona";
        a[5] = "--dep";
        a[6] = "v3=lib/plankified-univ3/plank/lib";
        a[7] = "--dep";
        a[8] = "std=lib/plank-monorepo/std/";
        a[9] = "--dep";
        a[10] = "pos_spec=src/types/pos_spec";
        a[11] = "--dep";
        a[12] = "lib=src/lib";
        a[13] = "--dep";
        a[14] = "types=src/types";
        a[15] = "--dep";
        a[16] = "interfaces=src/interfaces";
        return vm.tryFfi(a);
    }

    function _contains(bytes memory hay, string memory needle) internal pure returns (bool) {
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > hay.length) return false;
        for (uint256 i = 0; i + n.length <= hay.length; i++) {
            bool m = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (hay[i + j] != n[j]) {
                    m = false;
                    break;
                }
            }
            if (m) return true;
        }
        return false;
    }
}
