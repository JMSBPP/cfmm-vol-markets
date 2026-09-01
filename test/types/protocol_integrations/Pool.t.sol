// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {PoolVerifyV3Pool} from "../../mocks/PoolVerifyV3Pool.sol";
import {MinedRegistryV4Deployer} from "../../helpers/MinedRegistryV4Deployer.sol";
import {RegistryVerifyV4} from "../../mocks/RegistryVerifyV4.sol";
import {Deployers} from "v4-core-test/utils/Deployers.sol";
import {IHooks} from "univ4-core/interfaces/IHooks.sol";
import {Currency} from "univ4-core/types/Currency.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {AlgebraIntegralDeployer} from "../../helpers/AlgebraIntegralDeployer.sol";
import {IAlgebraFactory} from "@cryptoalgebra/integral-core/interfaces/IAlgebraFactory.sol";
import {IAlgebraPoolState} from "@cryptoalgebra/integral-core/interfaces/pool/IAlgebraPoolState.sol";

/// Univ3 factory stand-in for pool_verify registry lookup.
contract V3FactoryStub {
    address internal immutable POOL;

    constructor(address pool_) {
        POOL = pool_;
    }

    function getPool(address, address, uint24) external view returns (address) {
        return POOL;
    }
}

contract PoolTest is PlankTestBase, Deployers {
    address internal harness;
    address internal hookMiner;
    address internal constant POOL_ADDR = address(0x00000000000000000000000000000000000000AB);

    function setUp() public {
        harness = deployPlank("test/types/protocol_integrations/PoolHarness.plk");
        hookMiner = deployCfmmTypesPlank("lib/cfmm-types/src/types/uniswap_v4/Hook.plk");
    }

    function test__unit__allThreeVenuesInstantiate() public {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("venueWitness()"));
        require(ok, "venueWitness reverted");
        assertEq(abi.decode(r, (uint256)), 57, "venue codes wrong");
    }

    uint256 internal constant C0 = 0x1111;
    uint256 internal constant C1 = 0x2222;
    uint256 internal constant FEE = 3000;
    uint256 internal constant TICK_SPACING = 60;

    function test__unit__poolWordV4IsPoolIdHash() public {
        address registry = address(new RegistryVerifyV4(address(0x1)));
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "poolWordV4(uint256,uint256,uint256,uint256,uint256)",
                C0,
                C1,
                FEE,
                TICK_SPACING,
                uint256(uint160(registry))
            )
        );
        require(ok, "poolWordV4 reverted");
        assertEq(
            abi.decode(r, (uint256)),
            uint256(keccak256(abi.encode(C0, C1, FEE, TICK_SPACING, registry))),
            "V4 pool_word must be canonical PoolId hash"
        );
    }

    function test__unit__poolWordV3IsPoolAddress() public {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("poolWordV3(address,uint256,uint256)", POOL_ADDR, uint256(3000), uint256(60))
        );
        require(ok, "poolWordV3 reverted");
        assertEq(abi.decode(r, (uint256)), uint256(uint160(POOL_ADDR)), "V3 pool_word must be pool address");
    }

    function test__unit__poolFeeAlgebraRoundTrip() public {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("poolFeeAlgebra(address,uint256,uint256)", POOL_ADDR, uint256(0), uint256(60))
        );
        require(ok, "poolFeeAlgebra reverted");
        assertEq(abi.decode(r, (uint256)), 0, "Algebra pool_fee round-trip");
    }

    function test__unit__poolTickSpacingRoundTrip() public {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature("poolTickSpacingV3(address,uint256,uint256)", POOL_ADDR, uint256(3000), uint256(60))
        );
        require(ok, "poolTickSpacingV3 reverted");
        assertEq(abi.decode(r, (uint256)), 60, "tick_spacing round-trip");
    }

    function test__unit__poolV3AtReadsFeeAndTick() public {
        address pool = address(new PoolVerifyV3Pool(3000, 60));
        (bool okWord, bytes memory rWord) =
            harness.staticcall(abi.encodeWithSignature("poolV3At(address)", pool));
        require(okWord, "poolV3At reverted");
        assertEq(abi.decode(rWord, (uint256)), uint256(uint160(pool)), "pool_word is pool address");

        (bool okFee, bytes memory rFee) =
            harness.staticcall(abi.encodeWithSignature("poolFeeV3At(address)", pool));
        require(okFee, "poolFeeV3At reverted");
        assertEq(abi.decode(rFee, (uint256)), 3000, "fee from on-chain read");

        (bool okTs, bytes memory rTs) =
            harness.staticcall(abi.encodeWithSignature("poolTickSpacingV3At(address)", pool));
        require(okTs, "poolTickSpacingV3At reverted");
        assertEq(abi.decode(rTs, (uint256)), 60, "tick_spacing from on-chain read");
    }

    function test__unit__poolVerifyV3PassesWhenFactoryMatches() public {
        address pool = address(new PoolVerifyV3Pool(3000, 60));
        address factory = address(new V3FactoryStub(pool));
        (bool ok,) =
            harness.staticcall(abi.encodeWithSignature("poolVerifyV3(address,address,uint256)", factory, pool, 0));
        assertTrue(ok, "matching factory pool must verify");
    }

    function test__unit__poolVerifyV3MismatchReverts() public {
        address pool = address(new PoolVerifyV3Pool(3000, 60));
        address factory = address(new V3FactoryStub(address(0xBEEF)));
        (bool ok,) = harness.staticcall(
            abi.encodeWithSignature("poolVerifyV3(address,address,uint256)", factory, pool, 0)
        );
        assertFalse(ok, "registry mismatch must revert");
    }

    function test__unit__poolAlgebraAtReadsFeeAndTick() public {
        (address entryPoint, address pool, address t0, address t1) = _algebraPoolFixture();
        (bool okWord, bytes memory rWord) =
            harness.staticcall(abi.encodeWithSignature("poolAlgebraAt(address)", pool));
        require(okWord, "poolAlgebraAt reverted");
        assertEq(abi.decode(rWord, (uint256)), uint256(uint160(pool)), "algebra pool_word is address");

        (, , uint16 fee,, ,) = IAlgebraPoolState(pool).globalState();
        int24 tickSpacing = IAlgebraPoolState(pool).tickSpacing();

        (bool okFee, bytes memory rFee) =
            harness.staticcall(abi.encodeWithSignature("poolFeeAlgebraAt(address)", pool));
        require(okFee, "poolFeeAlgebraAt reverted");
        assertEq(abi.decode(rFee, (uint256)), uint256(fee), "algebra fee from on-chain read");

        (bool okTs, bytes memory rTs) =
            harness.staticcall(abi.encodeWithSignature("poolTickSpacingAlgebraAt(address)", pool));
        require(okTs, "poolTickSpacingAlgebraAt reverted");
        assertEq(abi.decode(rTs, (uint256)), uint256(int256(tickSpacing)), "algebra tick_spacing");

        (bool okVerify,) = harness.staticcall(
            abi.encodeWithSignature(
                "poolVerifyAlgebra(address,address,uint256,uint256)", entryPoint, pool, t0, t1
            )
        );
        assertTrue(okVerify, "algebra pool must verify against entry point");
    }

    function test__unit__poolV4AtAndVerifyRoundTrip() public {
        deployFreshManagerAndRouters();
        (Currency c0, Currency c1) = deployMintAndApprove2Currencies();
        // Dynamic fee: registry need not be CREATE2 hook-mined (see Hooks.isValidHookAddress).
        uint24 fee = 0x800000;
        int24 tickSpacing = 60;
        address registry = MinedRegistryV4Deployer.deploy(hookMiner, address(manager));
        initPool(c0, c1, IHooks(registry), fee, tickSpacing, SQRT_PRICE_1_1);

        address t0 = Currency.unwrap(c0);
        address t1 = Currency.unwrap(c1);

        (bool okAt, bytes memory rAt) = harness.staticcall(
            abi.encodeWithSignature(
                "poolV4At(uint256,uint256,uint256,uint256,uint256)",
                uint256(uint160(registry)),
                uint256(uint160(t0)),
                uint256(uint160(t1)),
                uint256(int256(tickSpacing)),
                uint256(fee)
            )
        );
        require(okAt, "poolV4At reverted");
        assertEq(
            abi.decode(rAt, (uint256)),
            uint256(keccak256(abi.encode(t0, t1, fee, tickSpacing, registry))),
            "poolV4At must return canonical PoolId"
        );

        (bool okVerify,) = harness.staticcall(
            abi.encodeWithSignature(
                "poolVerifyV4(uint256,uint256,uint256,uint256,uint256)",
                uint256(uint160(registry)),
                uint256(uint160(t0)),
                uint256(uint160(t1)),
                uint256(fee),
                uint256(int256(tickSpacing))
            )
        );
        assertTrue(okVerify, "V4 pool must verify against manager slot0");
    }

    function test__unit__nonVenueTagDoesNotCompile() public {
        Vm.FfiResult memory res = _tryBuild("fixtures/plank-negative/PoolBadVenue.plk");
        assertTrue(res.exitCode != 0, "Pool(u256) compiled");
        assertTrue(
            _contains(res.stderr, "Pool: V must be V4, V3 or Algebra"),
            "wrong failure: not Pool's guard"
        );
    }

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
