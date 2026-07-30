// SPDX-License-Identifier: MIT
// ^0.8.0 (not ^0.8.26): the Algebra dynamic-fee libs pin =0.8.20; matches the project convention for
// tests touching @cryptoalgebra libs (see test/MarketStatisticsTest.t.sol, PlankTestBase).
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";
import {AlgebraFeeConfiguration} from "@cryptoalgebra/dynamic-fee-plugin/types/AlgebraFeeConfiguration.sol";
import {
    AlgebraFeeConfigurationU144,
    AlgebraFeeConfigurationU144Lib
} from "@cryptoalgebra/dynamic-fee-plugin/types/AlgebraFeeConfigurationU144.sol";

// Real Algebra config packing as the differential oracle (internal library -> external wrapper).
contract AFCRef {
    function pack(uint16 a1, uint16 a2, uint32 b1, uint32 b2, uint16 g1, uint16 g2, uint16 bf)
        external
        pure
        returns (uint256)
    {
        AlgebraFeeConfiguration memory cfg = AlgebraFeeConfiguration(a1, a2, b1, b2, g1, g2, bf);
        return AlgebraFeeConfigurationU144.unwrap(AlgebraFeeConfigurationU144Lib.pack(cfg));
    }

    function unpack(uint256 c)
        external
        pure
        returns (uint16, uint16, uint32, uint32, uint16, uint16, uint16)
    {
        AlgebraFeeConfigurationU144 packed = AlgebraFeeConfigurationU144.wrap(uint144(c));
        return (
            packed.alpha1(),
            packed.alpha2(),
            packed.beta1(),
            packed.beta2(),
            packed.gamma1(),
            packed.gamma2(),
            packed.baseFee()
        );
    }
}

// The Plank AlgebraFeeConfiguration + U144 packing must be byte-identical to Algebra's.
contract AlgebraFeeConfigTest is PlankTestBase {
    address internal harness;
    AFCRef internal ref;

    function setUp() public {
        harness = deployPlank("test/premium/AlgebraFeeConfigHarness.plk");
        ref = new AFCRef();
    }

    function _pack(uint16 a1, uint16 a2, uint32 b1, uint32 b2, uint16 g1, uint16 g2, uint16 bf)
        internal
        returns (uint256)
    {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "pack(uint16,uint16,uint32,uint32,uint16,uint16,uint16)", a1, a2, b1, b2, g1, g2, bf
            )
        );
        require(ok, "pack reverted");
        return abi.decode(r, (uint256));
    }

    function _unpack(uint256 c)
        internal
        returns (uint256 a1, uint256 a2, uint256 b1, uint256 b2, uint256 g1, uint256 g2, uint256 bf)
    {
        (bool ok, bytes memory r) = harness.staticcall(abi.encodeWithSignature("unpack(uint256)", c));
        require(ok, "unpack reverted");
        (a1, a2, b1, b2, g1, g2, bf) = abi.decode(r, (uint256, uint256, uint256, uint256, uint256, uint256, uint256));
    }

    // pack matches Algebra's uint144 layout exactly
    function testFuzz_pack_matchesAlgebra(
        uint16 a1, uint16 a2, uint32 b1, uint32 b2, uint16 g1, uint16 g2, uint16 bf
    ) public {
        assertEq(_pack(a1, a2, b1, b2, g1, g2, bf), ref.pack(a1, a2, b1, b2, g1, g2, bf), "pack == Algebra");
    }

    // accessors decode each field, and round-trip through pack
    function testFuzz_unpack_roundTrips(
        uint16 a1, uint16 a2, uint32 b1, uint32 b2, uint16 g1, uint16 g2, uint16 bf
    ) public {
        uint256 c = _pack(a1, a2, b1, b2, g1, g2, bf);
        (uint256 pa1, uint256 pa2, uint256 pb1, uint256 pb2, uint256 pg1, uint256 pg2, uint256 pbf) = _unpack(c);
        assertEq(pa1, a1, "alpha1");
        assertEq(pa2, a2, "alpha2");
        assertEq(pb1, b1, "beta1");
        assertEq(pb2, b2, "beta2");
        assertEq(pg1, g1, "gamma1");
        assertEq(pg2, g2, "gamma2");
        assertEq(pbf, bf, "baseFee");

        // and the Plank accessors agree with Algebra's on the same packed word
        (uint16 ra1, uint16 ra2, uint32 rb1, uint32 rb2, uint16 rg1, uint16 rg2, uint16 rbf) = ref.unpack(c);
        assertEq(pa1, ra1, "alpha1 == Algebra");
        assertEq(pb1, rb1, "beta1 == Algebra");
        assertEq(pbf, rbf, "baseFee == Algebra");
        (rb2, rg1, rg2); // silence unused
    }

    // golden: Algebra's initialFeeConfiguration values pack to a known layout
    function test_pack_goldenInitialConfig() public {
        // alpha1=2900, alpha2=12000, beta1=360, beta2=60000, gamma1=59, gamma2=8500, baseFee=100
        uint256 c = _pack(2900, 12000, 360, 60000, 59, 8500, 100);
        assertEq(c & 0xffff, 2900, "alpha1 @0");
        assertEq((c >> 16) & 0xffff, 12000, "alpha2 @16");
        assertEq((c >> 32) & 0xffffffff, 360, "beta1 @32");
        assertEq((c >> 64) & 0xffffffff, 60000, "beta2 @64");
        assertEq((c >> 96) & 0xffff, 59, "gamma1 @96");
        assertEq((c >> 112) & 0xffff, 8500, "gamma2 @112");
        assertEq((c >> 128) & 0xffff, 100, "baseFee @128");
    }
}
