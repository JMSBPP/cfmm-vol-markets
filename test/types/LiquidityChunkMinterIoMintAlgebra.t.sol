// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {IntegralPoolBootstrap} from "test/helpers/Algebra/IntegralPoolBootstrap.sol";

interface ILiquidityChunkMinterIoMintAlgebra {
    function ioMintAlgebra(
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

/// @dev Bulloak names from LiquidityChunkMinterIoMintAlgebra.btt. Setup per NOTES.md.
contract LiquidityChunkMinterIoMintAlgebraTest is PlankTestBase {
    ILiquidityChunkMinterIoMintAlgebra internal harness;
    IntegralPoolBootstrap.ReadyPool internal algebra;
    address internal noopAdapter;

    address internal constant PAYER = address(0xCAFE);
    address internal constant BENEFICIARY = address(0xBEEF);
    address internal constant LEFTOVERS = address(0xD00D);

    function setUp() public {
        harness = ILiquidityChunkMinterIoMintAlgebra(
            deployPlank("test/harness/types/LiquidityChunkMinterHarness.plk")
        );
        noopAdapter = deployPlank("test/helpers/NoOpCallback.plk");
        algebra = IntegralPoolBootstrap.bootstrap(vm);
    }

    function test_WhenAValidAlgebraMintCommandIsWrappedInIoMint() external {
        // it should preserve the full command as IO inner
        int24 spacing = int24(uint24(algebra.tickSpacing));
        int24 lower = spacing * -2;
        int24 upper = spacing * 2;
        uint256 packed = _pack(lower, upper, 123);

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
        ) = harness.ioMintAlgebra(
            noopAdapter,
            algebra.pool,
            algebra.fee,
            algebra.tickSpacing,
            PAYER,
            BENEFICIARY,
            LEFTOVERS,
            algebra.tickSpacing,
            packed
        );

        assertEq(adapter, noopAdapter);
        assertEq(pool, algebra.pool);
        assertEq(fee, algebra.fee);
        assertEq(poolSpacing, algebra.tickSpacing);
        assertEq(payer, PAYER);
        assertEq(beneficiary, BENEFICIARY);
        assertEq(leftovers, LEFTOVERS);
        assertEq(chunkSpacing, algebra.tickSpacing);
        assertEq(returnedPacked, packed);
    }

    function _pack(int24 lower, int24 upper, uint128 liquidity) private pure returns (uint256) {
        return (uint256(uint24(lower)) << 232) | (uint256(uint24(upper)) << 208) | uint256(liquidity);
    }
}
