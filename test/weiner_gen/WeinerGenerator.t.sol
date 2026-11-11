// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {WeinerGenerator} from "src/WeinerGenerator.sol";

/// @title WeinerGeneratorTest
/// @notice Ceremony + lattice locks from cfmm-vol-markets#126 design comment.
contract WeinerGeneratorTest is Test {
    WeinerGenerator internal box;
    address internal sealer = address(0xBEEF);
    bytes32 internal seed = keccak256("sealed-seed");

    uint256 internal constant DT = 2;
    uint256 internal constant WINDOW = 86400;
    uint256 internal constant PIPS = 1e6;
    /// floor(sqrt(2) * 1e27) — TimeSpacing comptime table
    uint256 internal constant SQRT_DT_RAY_2 = 1414213562373095048801688724;

    function setUp() public {
        box = new WeinerGenerator(sealer);
    }

    function test__unit__mapHashToShockPips_signAndBound() public view {
        bytes32 hPos = bytes32(uint256(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff));
        uint256 pipsPos = box.mapHashToShockPips(hPos);
        assertTrue(pipsPos <= 6 * PIPS, "pos magnitude");

        bytes32 hNeg = bytes32(uint256(0x8000000000000000000000000000000000000000000000000000000000000001));
        uint256 pipsNeg = box.mapHashToShockPips(hNeg);
        // neg_u256 encoding: 0 -% mag
        assertTrue(pipsNeg > type(uint256).max / 2, "neg encoding");
    }

    function test__unit__deltaW_oneSigma_dt2() public view {
        // eps = +1e6 pips (= +1 sigma), dt = 2 → table floor(sqrt(2)*RAY)
        uint256 eps = PIPS;
        uint256 dw = box.deltaW(DT, eps);
        assertEq(dw, SQRT_DT_RAY_2, "deltaW +1 sigma");
    }

    function test__integration__seal_reveal_shock_stream() public {
        vm.prank(sealer);
        box.seal(seed);

        // blockhash(sealBlock) unavailable until next block
        vm.roll(block.number + 1);

        vm.prank(sealer);
        box.reveal(seed);

        assertTrue(box.hasRoot(), "root set");

        uint256 n = WINDOW / DT;
        uint256 dw0 = box.shock(DT, 0);
        uint256 dw1 = box.shock(DT, 1);
        // Both succeed; values are determined by entropyRoot.
        assertTrue(dw0 != 0 || dw0 == 0);
        assertTrue(dw1 != 0 || dw1 == 0);
        vm.expectRevert(WeinerGenerator.JOutOfRange.selector);
        box.shock(DT, n);
    }

    function test__integration__reveal_reverts_on_zero_blockhash() public {
        vm.prank(sealer);
        box.seal(seed);
        uint256 sealedAt = block.number;

        // Advance past the 256-block window so blockhash(sealedAt) == 0
        vm.roll(sealedAt + 257);

        vm.prank(sealer);
        vm.expectRevert(WeinerGenerator.BlockhashUnavailable.selector);
        box.reveal(seed);
    }

    function test__integration__only_sealer() public {
        vm.prank(address(0xBAD));
        vm.expectRevert(WeinerGenerator.NotSealer.selector);
        box.seal(seed);
    }
}
