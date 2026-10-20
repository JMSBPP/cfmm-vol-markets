// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

interface ILiquidityChunkMinterAlgebra {
    error PoolSpacingMismatch();
    error ZeroAdapter();
    error ZeroPayer();
    error ZeroBeneficiary();

    function mintAlgebra(
        address adapter,
        address pool,
        uint256 fee,
        uint256 poolTickSpacing,
        address payer,
        address beneficiary,
        address leftoversRecipient,
        uint256 chunkTickSpacing,
        uint256 packedChunk
    )
        external
        view
        returns (
            address returnedAdapter,
            address returnedPool,
            uint256 returnedFee,
            uint256 returnedPoolTickSpacing,
            address returnedPayer,
            address returnedBeneficiary,
            address returnedLeftoversRecipient,
            uint256 returnedChunkTickSpacing,
            uint256 returnedPackedChunk
        );
}

/// @dev Bulloak-generated names from LiquidityChunkMinterAlgebra.btt. Assertions filled.
contract LiquidityChunkMinterAlgebraTest is PlankTestBase {
    ILiquidityChunkMinterAlgebra internal harness;

    address internal constant ADAPTER = address(0xA11CE);
    address internal constant POOL = address(0xB001);
    address internal constant PAYER = address(0xCAFE);
    address internal constant BENEFICIARY = address(0xBEEF);
    address internal constant LEFTOVERS = address(0xD00D);
    uint256 internal constant FEE = 3000;
    uint256 internal constant SPACING = 10;

    function setUp() public {
        harness =
            ILiquidityChunkMinterAlgebra(deployPlank("test/harness/types/LiquidityChunkMinterHarness.plk"));
    }

    function test_WhenPoolSpacingDiffersFromChunkSpacing() external {
        // it should revert with PoolSpacingMismatch
        vm.expectRevert(ILiquidityChunkMinterAlgebra.PoolSpacingMismatch.selector);
        harness.mintAlgebra(
            ADAPTER, POOL, FEE, 20, PAYER, BENEFICIARY, LEFTOVERS, SPACING, _pack(-100, 100, 1)
        );
    }

    function test_WhenAdapterIsZero() external {
        // it should revert with ZeroAdapter
        vm.expectRevert(ILiquidityChunkMinterAlgebra.ZeroAdapter.selector);
        harness.mintAlgebra(
            address(0), POOL, FEE, SPACING, PAYER, BENEFICIARY, LEFTOVERS, SPACING, _pack(-100, 100, 1)
        );
    }

    function test_WhenPayerIsZero() external {
        // it should revert with ZeroPayer
        vm.expectRevert(ILiquidityChunkMinterAlgebra.ZeroPayer.selector);
        harness.mintAlgebra(
            ADAPTER, POOL, FEE, SPACING, address(0), BENEFICIARY, LEFTOVERS, SPACING, _pack(-100, 100, 1)
        );
    }

    function test_WhenBeneficiaryIsZero() external {
        // it should revert with ZeroBeneficiary
        vm.expectRevert(ILiquidityChunkMinterAlgebra.ZeroBeneficiary.selector);
        harness.mintAlgebra(
            ADAPTER, POOL, FEE, SPACING, PAYER, address(0), LEFTOVERS, SPACING, _pack(-100, 100, 1)
        );
    }

    function test_WhenTheAlgebraMintCommandIsValid() external {
        // it should preserve the common command fields
        // it should preserve the leftovers recipient
        // it should preserve the typed liquidity chunk
        uint256 packed = _pack(-100, 100, 123);
        (
            address adapter,
            address pool,
            uint256 fee,
            uint256 poolSpacing,
            address payer,
            address beneficiary,
            address leftovers,
            uint256 chunkSpacing,
            uint256 returnedPacked
        ) = harness.mintAlgebra(
            ADAPTER, POOL, FEE, SPACING, PAYER, BENEFICIARY, LEFTOVERS, SPACING, packed
        );

        assertEq(adapter, ADAPTER);
        assertEq(pool, POOL);
        assertEq(fee, FEE);
        assertEq(poolSpacing, SPACING);
        assertEq(payer, PAYER);
        assertEq(beneficiary, BENEFICIARY);
        assertEq(leftovers, LEFTOVERS);
        assertEq(chunkSpacing, SPACING);
        assertEq(returnedPacked, packed);
    }

    function _pack(int24 lower, int24 upper, uint128 liquidity) private pure returns (uint256) {
        return (uint256(uint24(lower)) << 232) | (uint256(uint24(upper)) << 208) | uint256(liquidity);
    }
}
