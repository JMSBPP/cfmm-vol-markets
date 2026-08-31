// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PlankTestBase} from "../../../PlankTestBase.sol";
import {TokenId} from "@types/TokenId.sol";

/// @title VolPositionPanopticTokenIdTest
/// @notice Task 2: `vol_position_panoptic_token_id` writes LegBook weights as optionRatio.
/// @dev Harness calls `vol_position_from_ladder` + `vol_position_panoptic_token_id`.
contract VolPositionPanopticTokenIdTest is PlankTestBase {
    address internal harness;

    uint256 constant SYM_STRIKE = 1;
    uint256 constant SYM_SKEW = 32768;
    uint256 constant SYM_VEGA = 1e18;
    int24 constant SYM_TS = 10;

    uint256 constant WIDE_WIDTH = 4000;

    uint256 constant BOUND_PANOPTIC = 127;
    uint256 constant OR_MIN_DEFAULT = 8;

    struct VolPositionMintView {
        uint256 tokenId;
        uint256 w0;
        uint256 w1;
        uint256 w2;
        uint256 w3;
        uint256 base;
    }

    function setUp() public {
        harness = deployPlank("test/types/protocol_integrations/panoptic-v2/VolPositionPanopticTokenIdHarness.plk");
    }

    function _volPositionPanopticTokenId(
        uint256 orMin,
        uint256 bound,
        uint256 strike,
        uint256 width,
        uint256 skew,
        uint256 vega,
        uint256 ts,
        uint64 poolId
    ) internal returns (VolPositionMintView memory v) {
        (bool ok, bytes memory r) = harness.staticcall(
            abi.encodeWithSignature(
                "volPositionPanopticTokenId(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)",
                orMin,
                bound,
                strike,
                width,
                skew,
                vega,
                ts,
                uint256(poolId)
            )
        );
        require(ok, "volPositionPanopticTokenId reverted");
        (uint256 tid, uint256 w0, uint256 w1, uint256 w2, uint256 w3, uint256 base) =
            abi.decode(r, (uint256, uint256, uint256, uint256, uint256, uint256));
        v = VolPositionMintView({tokenId: tid, w0: w0, w1: w1, w2: w2, w3: w3, base: base});
    }

    function _optionRatio(uint256 tid, uint256 leg) internal pure returns (uint256) {
        return (tid >> (64 + 48 * leg + 1)) & 0x7f;
    }

    function test_volPositionPanopticTokenId_wide_ratiosMatchBook() public {
        VolPositionMintView memory v = _volPositionPanopticTokenId(
            OR_MIN_DEFAULT, BOUND_PANOPTIC, SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)), 0
        );

        assertEq(_optionRatio(v.tokenId, 0), v.w0, "leg0 optionRatio");
        assertEq(_optionRatio(v.tokenId, 1), v.w1, "leg1 optionRatio");
        assertEq(_optionRatio(v.tokenId, 2), v.w2, "leg2 optionRatio");
        assertEq(_optionRatio(v.tokenId, 3), v.w3, "leg3 optionRatio");

        assertGt(v.w0, 1, "wide fixture: w0 > 1");
        assertGt(v.w3, 1, "wide fixture: w3 > 1");
    }

    function test_volPositionPanopticTokenId_wide_passesPanopticValidate() public {
        VolPositionMintView memory v = _volPositionPanopticTokenId(
            OR_MIN_DEFAULT, BOUND_PANOPTIC, SYM_STRIKE, WIDE_WIDTH, SYM_SKEW, SYM_VEGA, uint256(uint24(SYM_TS)), 0
        );
        TokenId.wrap(v.tokenId).validate();
    }
}
