// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";

// PanopticTokenId must pack/unpack byte-identically to Panoptic's TokenId schema
// (lib/panoptic-v2-core/contracts/types/TokenId.sol). The reference decoders are inlined verbatim
// from that file's canonical shift/mask formulas (the real TokenIdLibrary can't be imported here --
// it transitively pulls in PanopticMath -> unresolved OpenZeppelin deps).
//
// Panoptic layout (little-endian, from LSB):
//   poolId : bits [0..63]  (univ3 pattern 40 | vegoid 8 at 40 | tickSpacing 16 at 48)
//   per leg L (48-bit stride, base = 64 + 48*L):
//     asset 1b at base+0 | optionRatio 7b at base+1 | isLong 1b at base+8
//     tokenType 1b at base+9 | riskPartner 2b at base+10 | strike 24b at base+12 (signed)
//     width 12b at base+36
contract PanopticTokenIdTest is PlankTestBase {
    // FFI-deployed Plank harness (PanopticTokenIdHarness.plk):
    //   packLeg(uint256 poolId,int24 tickSpacing,uint256 leg,uint256 asset,uint256 optionRatio,
    //           uint256 isLong,uint256 tokenType,uint256 riskPartner,int24 strike,int24 width) -> uint256
    //   unpackLeg(uint256 tid,uint256 leg)
    //     -> (uint256 poolId,uint256 vegoid,int24 tickSpacing,uint256 asset,uint256 optionRatio,
    //         uint256 isLong,uint256 tokenType,uint256 riskPartner,int24 strike,int24 width)
    address internal harness;

    int24 constant I24_MIN = -8388608; // full signed 24-bit field range
    int24 constant I24_MAX = 8388607;

    function setUp() public {
        harness = deployPlank("src/types/protocol_integrations/PanopticTokenIdHarness.plk");
    }

    function _pack(
        uint256 poolId,
        int24 tickSpacing,
        uint256 leg,
        uint256 asset,
        uint256 optionRatio,
        uint256 isLong,
        uint256 tokenType,
        uint256 riskPartner,
        int24 strike,
        int24 width
    ) internal returns (uint256) {
        (bool ok, bytes memory ret) = harness.staticcall(
            abi.encodeWithSignature(
                "packLeg(uint256,int24,uint256,uint256,uint256,uint256,uint256,int24,int24)",
                poolId, tickSpacing, leg, asset, optionRatio, isLong, tokenType, riskPartner, strike, width
            )
        );
        require(ok, "packLeg reverted");
        return abi.decode(ret, (uint256));
    }

    struct Leg {
        uint256 poolId;
        uint256 vegoid;
        int24 tickSpacing;
        uint256 asset;
        uint256 optionRatio;
        uint256 isLong;
        uint256 tokenType;
        uint256 riskPartner;
        int24 strike;
        int24 width;
    }

    function _unpack(uint256 tid, uint256 leg) internal returns (Leg memory L) {
        (bool ok, bytes memory ret) =
            harness.staticcall(abi.encodeWithSignature("unpackLeg(uint256,uint256)", tid, leg));
        require(ok, "unpackLeg reverted");
        (
            L.poolId,
            L.vegoid,
            L.tickSpacing,
            L.asset,
            L.optionRatio,
            L.isLong,
            L.tokenType,
            L.riskPartner,
            L.strike,
            L.width
        ) = abi.decode(
            ret, (uint256, uint256, int24, uint256, uint256, uint256, uint256, uint256, int24, int24)
        );
    }

    // Golden vector: bit-exact against hand-computed Panoptic layout for leg index 1.
    function test_panopticTokenId_goldenVector() public {
        uint256 tid = _pack(0, 60, 1, 1, 3, 1, 1, 2, 100, 5);
        uint256 base = 64 + 48 * 1;
        uint256 expected = (uint256(uint24(60)) << 48) // tickSpacing
            + (uint256(1) << base) // asset
            + (uint256(3) << (base + 1)) // optionRatio
            + (uint256(1) << (base + 8)) // isLong
            + (uint256(1) << (base + 9)) // tokenType
            + (uint256(2) << (base + 10)) // riskPartner
            + ((uint256(100) & 0xFFFFFF) << (base + 12)) // strike
            + ((uint256(5) % 4096) << (base + 36)); // width
        assertEq(tid, expected, "golden tokenId must be bit-exact");
    }

    function testFuzz_panopticTokenId_fullLegSchema(
        uint256 poolIdR,
        int256 tsR,
        uint256 legR,
        uint256 assetR,
        uint256 orR,
        uint256 ilR,
        uint256 ttR,
        uint256 rpR,
        int256 strikeR,
        int256 widthR
    ) public {
        uint256 poolId = bound(poolIdR, 0, (uint256(1) << 48) - 1); // pattern+vegoid; tickSpacing added @48
        int24 tickSpacing = int24(bound(tsR, 1, 32767));
        uint256 leg = bound(legR, 0, 3);
        uint256 asset = bound(assetR, 0, 1);
        uint256 optionRatio = bound(orR, 0, 127);
        uint256 isLong = bound(ilR, 0, 1);
        uint256 tokenType = bound(ttR, 0, 1);
        uint256 riskPartner = bound(rpR, 0, 3);
        int24 strike = int24(bound(strikeR, I24_MIN, I24_MAX));
        int24 width = int24(bound(widthR, 0, 4095));

        uint256 tid =
            _pack(poolId, tickSpacing, leg, asset, optionRatio, isLong, tokenType, riskPartner, strike, width);
        uint256 b = 64 + leg * 48;

        // (A) local canonical decode (Panoptic TokenId.sol formulas, verbatim)
        assertEq(uint64(tid), uint64(poolId | (uint256(uint24(tickSpacing)) << 48)), "poolId low64");
        assertEq((tid >> 40) % 256, (poolId >> 40) % 256, "vegoid");
        assertEq(int24(uint24((tid >> 48) % 65536)), tickSpacing, "tickSpacing");
        assertEq((tid >> b) % 2, asset, "asset");
        assertEq((tid >> (b + 1)) % 128, optionRatio, "optionRatio");
        assertEq((tid >> (b + 8)) % 2, isLong, "isLong");
        assertEq((tid >> (b + 9)) % 2, tokenType, "tokenType");
        assertEq((tid >> (b + 10)) % 4, riskPartner, "riskPartner");
        assertEq(int24(int256(tid >> (b + 12))), strike, "strike (signed 24-bit)");
        assertEq(int24(int256((tid >> (b + 36)) % 4096)), width, "width");

        // (B) Plank decoders agree with the inputs
        Leg memory L = _unpack(tid, leg);
        assertEq(L.poolId, uint256(uint64(tid)), "plank poolId");
        assertEq(L.vegoid, (poolId >> 40) % 256, "plank vegoid");
        assertEq(L.tickSpacing, tickSpacing, "plank tickSpacing");
        assertEq(L.asset, asset, "plank asset");
        assertEq(L.optionRatio, optionRatio, "plank optionRatio");
        assertEq(L.isLong, isLong, "plank isLong");
        assertEq(L.tokenType, tokenType, "plank tokenType");
        assertEq(L.riskPartner, riskPartner, "plank riskPartner");
        assertEq(L.strike, strike, "plank strike");
        assertEq(L.width, width, "plank width");
    }

    // ---- Increment 2: vol-driven derivation from a TickBucket (Panoptic definitions) ----

    function _packFromTB(int24 low, int24 tickSpacing, int24 up, uint256 leg) internal returns (uint256) {
        (bool ok, bytes memory ret) = harness.staticcall(
            abi.encodeWithSignature("packFromTickBucket(int24,int24,int24,uint256)", low, tickSpacing, up, leg)
        );
        require(ok, "packFromTickBucket reverted");
        return abi.decode(ret, (uint256));
    }

    // Panoptic definition: strike = (tickUpper+tickLower)/2, width = (tickUpper-tickLower)/tickSpacing.
    function test_fromTickBucket_goldenVector() public {
        uint256 tid = _packFromTB(100, 10, 200, 0);
        Leg memory L = _unpack(tid, 0);
        assertEq(L.strike, int24(150), "strike = (100+200)/2");
        assertEq(L.width, int24(10), "width = (200-100)/10");
        assertEq(L.tickSpacing, int24(10), "tickSpacing");
    }

    function testFuzz_fromTickBucket(int256 lowR, uint256 upR, int256 tsR, uint256 legR) public {
        int24 tickSpacing = int24(bound(tsR, 1, 32767));
        uint256 leg = bound(legR, 0, 3);
        int256 low = bound(lowR, I24_MIN, I24_MAX);
        uint256 tsU = uint256(uint24(tickSpacing));

        // keep width = (up-low)/ts <= 4095 and up <= I24_MAX (so strike & width stay in-field)
        uint256 maxDelta = uint256(4095) * tsU;
        if (int256(maxDelta) > I24_MAX - low) maxDelta = uint256(I24_MAX - low);
        int256 up = low + int256(bound(upR, 0, maxDelta));

        int24 expStrike = int24((low + up) / 2);
        int24 expWidth = int24((up - low) / int256(tsU));

        uint256 tid = _packFromTB(int24(low), tickSpacing, int24(up), leg);
        Leg memory L = _unpack(tid, leg);

        assertEq(L.strike, expStrike, "strike == (low+up)/2");
        assertEq(L.width, expWidth, "width == (up-low)/tickSpacing");
        assertEq(L.tickSpacing, tickSpacing, "tickSpacing == tb.tickSpacing");
    }
}
