// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {PlankTestBase} from "test/PlankTestBase.sol";
import {RegistryVerifyV4} from "test/mocks/RegistryVerifyV4.sol";
import {AlgebraIntegralDeployer} from "test/helpers/AlgebraIntegralDeployer.sol";
import {IAlgebraFactory} from "@cryptoalgebra/integral-core/interfaces/IAlgebraFactory.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

/// Minimal stand-in for BOTH SFPMs: they share the signature
/// `getPoolId(bytes memory id, uint8 vegoid) external view returns (uint64)`
/// (SemiFungiblePositionManagerV4.sol:1369, V3.sol:1558). `id` is a DYNAMIC type, so a caller must
/// encode offset and length words -- the stub decodes nothing and simply returns what it was built
/// with, which is enough to exercise agreement and disagreement.
contract SfpmStub {
    uint64 internal immutable ID;

    constructor(uint64 id_) {
        ID = id_;
    }

    function getPoolId(bytes calldata, uint8) external view returns (uint64) {
        return ID;
    }
}

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
contract VolMarketKeyTest is PlankTestBase {
    bytes internal constant ZERO_BYTES = new bytes(0);

    address harness;
    address v4Registry;

    function setUp() public {
        harness = deployPlank("test/protocol_integrations/VolMarketKeyHarness.plk");
        v4Registry = address(new RegistryVerifyV4(address(uint160(HOOKS)), address(0x1)));
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

    // ---- KEY-02: the pool PATTERN is 40 bits and VENUE-SPECIFIC ---------------------------------

    /// SFPM V4: uint40(uint256(PoolId.unwrap(idV4))) -- the LOW 40 bits of the v4 PoolId.
    function test__fuzz__v4PatternIsTheLowFortyBits(uint256 idV4) public {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("v4Pattern(uint256)", idV4));
        require(ok, "v4Pattern reverted");
        assertEq(abi.decode(r, (uint256)), idV4 & ((uint256(1) << 40) - 1), "V4 pattern = low 40");
    }

    /// SFPM V3: uint40(uint160(univ3pool) >> 120) -- the HIGH 40 bits of the 160-bit ADDRESS.
    /// Not the low bits. This is the half of KEY-02 most likely to be written wrong by analogy
    /// with V4, so it is asserted independently rather than derived from the V4 case.
    function test__fuzz__v3PatternIsTheHighFortyBitsOfTheAddress(address pool) public {
        uint256 a = uint256(uint160(pool));
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("v3Pattern(uint256)", a));
        require(ok, "v3Pattern reverted");
        assertEq(abi.decode(r, (uint256)), (a >> 120) & ((uint256(1) << 40) - 1), "V3 = addr >> 120");
    }

    /// The two derivations must not be assumed identical. Fed the same word they disagree, which
    /// is the property a shared implementation would silently break.
    function test__unit__v3AndV4PatternsDifferForTheSameWord() public {
        // Leading 00 is REQUIRED, not cosmetic: a bare 40-hex-digit literal is parsed by solc as an
        // address literal and rejected for a bad checksum (Error 9429). Same numeric value.
        uint256 w = 0x001234567890abcdef1122334455667788aabbccdd;
        (, bytes memory r4) = harness.staticcall(abi.encodeWithSignature("v4Pattern(uint256)", w));
        (, bytes memory r3) = harness.staticcall(abi.encodeWithSignature("v3Pattern(uint256)", w));
        assertTrue(
            abi.decode(r4, (uint256)) != abi.decode(r3, (uint256)),
            "the venue patterns must not be assumed identical"
        );
    }

    /// poolId = [16b tickSpacing at 48][8b vegoid at 40][40b pattern at 0]  (PanopticMath.sol:28).
    /// The in-contract prose in both SFPMs says "most significant 48 bits"; the CODE says 40, and
    /// the code is what this mirrors.
    function test__fuzz__composePoolIdLayout(uint40 pattern, uint8 vegoid, uint16 tickSpacing)
        public
    {
        // vegoid is 1..255. CONSTRUCTED into range, not filtered with vm.assume -- the project's
        // differential discipline is that corpora are built rather than rejected, so no run is
        // discarded and the non-vacuity of the 256 runs is not silently eroded.
        uint256 v = bound(uint256(vegoid), 1, 255);

        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "composePoolId(uint256,uint256,uint256)",
                uint256(pattern),
                v,
                uint256(tickSpacing)
            )
        );
        require(ok, "composePoolId reverted");
        uint256 id = abi.decode(r, (uint256));
        assertEq(id & ((uint256(1) << 40) - 1), pattern, "pattern at 0..39");
        assertEq((id >> 40) & 0xff, v, "vegoid at 40..47");
        assertEq((id >> 48) & 0xffff, tickSpacing, "tickSpacing at 48..63");
    }

    /// vegoid == 0 is rejected at composition, not just at the payload: the poolId itself would
    /// otherwise carry a value the SFPM refuses (Errors.InvalidTokenIdParameter(0)).
    function test__unit__composePoolIdRejectsZeroVegoid() public {
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("composePoolId(uint256,uint256,uint256)", uint256(1), uint256(0), uint256(60))
        );
        assertFalse(ok, "vegoid == 0 must revert at composition");
    }

    // ---- KEY-03: the pool address is VERIFIED against the venue registry -----------------------

    /// Never CREATE2-derived, so no POOL_INIT_CODE_HASH is pinned anywhere and the same code works
    /// across forks and chains where a patched pool contract would change the init hash.
    function test__unit__v3PoolAddressVerifiedAgainstTheFactory() public {
        address pool = address(0xBEEF);
        address factory = address(new V3FactoryStub(pool));
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("verifyPoolV3(address,address)", factory, pool)
        );
        assertTrue(ok, "a pool matching the registry must verify");
    }

    function test__unit__v3PoolAddressMismatchReverts() public {
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

    // ---- KEY-02: the poolId is a CANDIDATE, verified against the SFPM --------------------------

    /// The Panoptic poolId is STATEFUL: both SFPMs loop
    ///   while (s_poolIdToKey[poolId].tickSpacing != 0) poolId = incrementPoolPattern(poolId)
    /// on a 40-bit pattern collision, and enforce the stored value at mint. So deriving it purely
    /// yields a candidate, not an answer. When the SFPM agrees, the candidate is returned.
    function test__unit__poolIdCandidateMatchingTheSfpmIsReturned() public {
        uint64 expected = _expectedV4PoolId(VEGOID, TICK_SPACING);
        address sfpm = address(new SfpmStub(expected));
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("panopticPoolIdV4(uint256,address,uint256)", v4Registry, sfpm, uint256(VEGOID))
        );
        require(ok, "matching candidate reverted");
        assertEq(abi.decode(r, (uint256)), expected, "the verified candidate must be returned");
    }

    /// A collision-incremented poolId must fail with OUR error at build time rather than inside
    /// Panoptic at mint with InvalidTokenIdParameter -- an error pointing at the derivation, not at
    /// a contract three calls away.
    function test__unit__poolIdCollisionMismatchReverts() public {
        uint64 incremented = _expectedV4PoolId(VEGOID, TICK_SPACING) + 1;
        address sfpm = address(new SfpmStub(incremented));
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("panopticPoolIdV4(uint256,address,uint256)", v4Registry, sfpm, uint256(VEGOID))
        );
        assertFalse(ok, "a collision-incremented poolId must revert at build time");
    }

    /// The v4 pool id is keccak256 over the 5-field PoolKey -- the same value MarketId.plk's
    /// market_id_from_pool_key computes, which VolMarketKey(V4) subsumes rather than duplicates.
    function test__unit__v4PoolIdIsTheCanonicalUniV4PoolId() public {
        (bool ok, bytes memory r) =
            harness.staticcall(abi.encodeWithSignature("v4PoolId(uint256)", v4Registry));
        require(ok, "v4PoolId reverted");
        assertEq(
            abi.decode(r, (uint256)),
            uint256(keccak256(abi.encode(C0, C1, FEE, TICK_SPACING, HOOKS))),
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
    uint256 internal constant HOOKS = 0x3333;
    uint8 internal constant VEGOID = 8;

    function _expectedV4PoolId(uint8 vegoid, uint256 tickSpacing) internal pure returns (uint64) {
        uint256 poolIdV4 = uint256(keccak256(abi.encode(C0, C1, FEE, TICK_SPACING, HOOKS)));
        uint256 pattern = poolIdV4 & ((uint256(1) << 40) - 1);
        return uint64(pattern | (uint256(vegoid) << 40) | (tickSpacing << 48));
    }

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
        uint24 tickSpacing,
        uint256 hooks
    ) public {
        vm.assume(c0 <= type(uint160).max);
        vm.assume(c1 <= type(uint160).max);
        vm.assume(hooks <= type(uint160).max);
        vm.assume(c0 != c1);
        // XOR-1 perturbation of c0 must not make pair() see equal currencies.
        vm.assume(c0 != (c1 ^ 1));
        uint256 got = _v4PoolIdFor(c0, c1, fee, tickSpacing, hooks);
        (uint256 t0, uint256 t1) = _sortedCurrencies(c0, c1);
        assertEq(
            got,
            uint256(keccak256(abi.encode(t0, t1, uint256(fee), uint256(tickSpacing), hooks))),
            "the id must be keccak over exactly these five fields, in sorted currency order"
        );

        // Perturbing any single field must change the id. XOR 1 rather than + 1: the fuzzer found
        // that `hooks + 1` panics with 0x11 when hooks == type(uint256).max (run 28 of
        // 33211646329). XOR flips the low bit, always changes the value, and cannot overflow.
        assertTrue(got != _v4PoolIdFor(c0 ^ 1, c1, fee, tickSpacing, hooks), "currency0 not hashed");
        assertTrue(got != _v4PoolIdFor(c0, c1 ^ 1, fee, tickSpacing, hooks), "currency1 not hashed");
        assertTrue(
            got != _v4PoolIdFor(c0, c1, uint256(fee) ^ 1, tickSpacing, hooks), "fee not hashed"
        );
        assertTrue(
            got != _v4PoolIdFor(c0, c1, fee, uint256(tickSpacing) ^ 1, hooks),
            "tickSpacing not hashed"
        );
        assertTrue(got != _v4PoolIdFor(c0, c1, fee, tickSpacing, hooks ^ 1), "hooks not hashed");
    }

    function _v4PoolIdFor(uint256 c0, uint256 c1, uint256 fee, uint256 ts, uint256 hooks)
        internal
        returns (uint256)
    {
        address registry = address(new RegistryVerifyV4(address(uint160(hooks)), address(0x1)));
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

    /// KEY-04: there is no PanopticFactoryAlgebra, so the Algebra arm has no Panoptic continuation
    /// and must not be given a synthetic one. The dead end is a type-level fact.
    function test__unit__algebraKeyIntoPanopticArmDoesNotCompile() public {
        Vm.FfiResult memory r = _tryBuild("fixtures/plank-negative/VolMarketKeyAlgebraToPanoptic.plk");
        assertTrue(r.exitCode != 0, "an Algebra key reached the Panoptic arm");
        assertTrue(
            _contains(r.stderr, "VolMarketKey: the Panoptic arm accepts only V4 or V3"),
            "wrong failure: not the Panoptic-arm guard"
        );
    }


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
        string[] memory a = new string[](19);
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
        a[17] = "--dep";
        a[18] = "helpers=test/protocol_integrations/helpers";
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
