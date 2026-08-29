// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {PoolVerifyV3Pool} from "../../mocks/PoolVerifyV3Pool.sol";

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

contract PoolTest is PlankTestBase {
    address internal harness;
    address internal constant POOL_ADDR = address(0x00000000000000000000000000000000000000AB);

    function setUp() public {
        harness = deployPlank("test/types/protocol_integrations/PoolHarness.plk");
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
    uint256 internal constant HOOKS = 0x3333;

    function test__unit__poolWordV4IsPoolIdHash() public {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "poolWordV4(uint256,uint256,uint256,uint256,uint256)",
                C0,
                C1,
                FEE,
                TICK_SPACING,
                HOOKS
            )
        );
        require(ok, "poolWordV4 reverted");
        assertEq(
            abi.decode(r, (uint256)),
            uint256(keccak256(abi.encode(C0, C1, FEE, TICK_SPACING, HOOKS))),
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

    function test__unit__nonVenueTagDoesNotCompile() public {
        Vm.FfiResult memory res = _tryBuild("fixtures/plank-negative/PoolBadVenue.plk");
        assertTrue(res.exitCode != 0, "Pool(u256) compiled");
        assertTrue(
            _contains(res.stderr, "Pool: V must be V4, V3 or Algebra"),
            "wrong failure: not Pool's guard"
        );
    }

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
