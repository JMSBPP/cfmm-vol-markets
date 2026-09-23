// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {FlowToken} from "test/mocks/FlowToken.sol";
import {IntegralPoolBootstrap} from "test/helpers/Algebra/IntegralPoolBootstrap.sol";

interface IAlgebraMintCallbackAdapter {
    function runMint(
        address pool,
        uint256 fee,
        uint256 poolTickSpacing,
        address payer,
        address beneficiary,
        address leftoversRecipient,
        uint256 chunkTickSpacing,
        uint256 packedChunk
    ) external returns (bool ok, uint256 amount0, uint256 amount1, uint256 liquidityActual);
}

/// @dev Bulloak names from LiquidityChunkMinterRunAlgebra.btt.
contract LiquidityChunkMinterRunAlgebraTest is PlankTestBase {
    IAlgebraMintCallbackAdapter internal adapter;
    IntegralPoolBootstrap.ReadyPool internal ready;

    address internal constant PAYER = address(0xCAFE);
    address internal constant BENEFICIARY = address(0xBEEF);
    address internal constant LEFTOVERS = address(0xD00D);
    uint256 internal constant SEED = 1e24;

    bytes32 internal constant ERC20_POS = keccak256("erc20");

    function setUp() public {
        adapter = IAlgebraMintCallbackAdapter(deployPlank("test/helpers/Algebra/AlgebraMintCallbackAdapter.plk"));
        ready = IntegralPoolBootstrap.bootstrap(vm);
        _seedFlowToken(ready.token0);
        _seedFlowToken(ready.token1);
    }

    function test_WhenRunMintExecutesOnABootstrappedAlgebraPoolWithFundedPayer() external {
        int24 spacing = int24(uint24(ready.tickSpacing));
        int24 lower = spacing * -2;
        int24 upper = spacing * 2;
        uint256 packed = _pack(lower, upper, 1_000_000);

        (bool ok, uint256 amount0, uint256 amount1, uint256 liquidityActual) = adapter.runMint(
            ready.pool,
            ready.fee,
            ready.tickSpacing,
            PAYER,
            BENEFICIARY,
            LEFTOVERS,
            ready.tickSpacing,
            packed
        );

        assertTrue(ok, "run_mint expected Some");
        assertGt(liquidityActual, 0, "liquidity_actual");
        assertTrue(amount0 > 0 || amount1 > 0, "token payment");
    }

    function _seedFlowToken(address token) internal {
        _seedBalance(token, PAYER, SEED);
        _seedAllowance(token, PAYER, address(adapter), SEED);
    }

    function _seedBalance(address token, address owner, uint256 amt) internal {
        vm.store(token, keccak256(abi.encode(owner, ERC20_POS)), bytes32(amt));
    }

    function _seedAllowance(address token, address owner, address spender, uint256 amt) internal {
        bytes32 ownerMap = keccak256(abi.encode(owner, bytes32(uint256(ERC20_POS) + 2)));
        vm.store(token, keccak256(abi.encode(spender, ownerMap)), bytes32(amt));
    }

    function _pack(int24 lower, int24 upper, uint128 liquidity) private pure returns (uint256) {
        return (uint256(uint24(lower)) << 232) | (uint256(uint24(upper)) << 208) | uint256(liquidity);
    }
}
