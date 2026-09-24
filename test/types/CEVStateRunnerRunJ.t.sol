// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {console2} from "forge-std/console2.sol";
import {PlankTestBase} from "test/PlankTestBase.sol";
import {IntegralPoolBootstrap} from "test/helpers/Algebra/IntegralPoolBootstrap.sol";
import {IAlgebraPoolState} from "@cryptoalgebra/integral-core/interfaces/pool/IAlgebraPoolState.sol";

interface ICEVStateRunnerRunJ {
    function runJ(
        uint256 sigmaF,
        uint256 packedChunk,
        address pool,
        uint256 j,
        address token,
        address from
    ) external returns (bool ok, uint256 tick, uint256 sig);
}

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

/// @dev Bulloak-generated names from CEVStateRunnerRunJ.btt (#147 B2). Assertions filled.
contract CEVStateRunnerRunJTest is PlankTestBase {
    ICEVStateRunnerRunJ internal harness;
    IAlgebraMintCallbackAdapter internal mintAdapter;
    IntegralPoolBootstrap.ReadyPool internal algebraReady;

    address internal constant PAYER = address(0xA11CE);
    address internal constant LEFTOVERS = address(0xD00D);
    uint256 internal constant SEED = 1e24;
    uint256 internal constant RAY = 1e27;
    uint256 internal constant CHUNK_L = 1_000_000_000_000;
    uint256 internal constant DT = 2;
    /// Admissible σ_F as fraction of L (SQD-backed): [1e-6, 1e-3].
    uint256 internal constant SIGMA_F_HUMAN_MIN = 1e21; // 1e-6 * RAY
    uint256 internal constant SIGMA_F_HUMAN_MAX = 1e24; // 1e-3 * RAY

    bytes32 internal constant ERC20_POS = keccak256("erc20");

    function setUp() public {
        harness = ICEVStateRunnerRunJ(deployPlank("test/harness/types/CEVStateRunnerHarness.plk"));
        mintAdapter = IAlgebraMintCallbackAdapter(deployPlank("test/helpers/Algebra/AlgebraMintCallbackAdapter.plk"));
        algebraReady = IntegralPoolBootstrap.bootstrap(vm);
        _seedPoolTokens();
        _mintBootstrapLiquidity();
    }

    function test_WhenTimestampAndPrevrandaoAreAvailableAndSigmaFIsAdmissible(
        uint256 prevrandaoSeed,
        uint256 sigmaFRaw
    ) external {
        // it should return Some with observed tick and sigma for each j in 0 through 10
        // it should yield different cells across j
        vm.prevrandao(bytes32(prevrandaoSeed));
        uint256 sigmaF = bound(sigmaFRaw, SIGMA_F_HUMAN_MIN, SIGMA_F_HUMAN_MAX);
        console2.log("\\(\\sigma_F\\):", sigmaF / (RAY / 1e6)); // ppm of unit fraction for readability
        console2.log("\\(\\sigma_F^{RAY}\\):", sigmaF);

        uint256 spacing = algebraReady.tickSpacing == 0 ? 1 : algebraReady.tickSpacing;
        int24 s = int24(uint24(spacing));
        uint256 packed = _pack(s * -2, s * 2, uint128(CHUNK_L));

        uint256 t0 = block.timestamp;
        uint256[11] memory ticks;
        uint256[11] memory sigs;

        for (uint256 j = 0; j <= 10; j++) {
            vm.warp(t0 + j * DT);
            (bool ok, uint256 tick, uint256 sig) = harness.runJ(
                sigmaF,
                packed,
                algebraReady.pool,
                j,
                algebraReady.token0,
                PAYER
            );
            assertTrue(ok, "run_j Some");
            assertTrue(sig < (1 << 88), "sigma in u88");
            ticks[j] = tick;
            sigs[j] = sig;
        }

        for (uint256 a = 0; a <= 10; a++) {
            for (uint256 b = a + 1; b <= 10; b++) {
                assertTrue(ticks[a] != ticks[b] || sigs[a] != sigs[b], "cells collide across j");
            }
        }

        (uint160 sqrtP,,,,,) = IAlgebraPoolState(algebraReady.pool).globalState();
        assertTrue(sqrtP > 0, "pool live");
    }

    function _mintBootstrapLiquidity() internal {
        uint256 spacing = algebraReady.tickSpacing == 0 ? 1 : algebraReady.tickSpacing;
        int24 s = int24(uint24(spacing));
        uint256 packed = _pack(s * -2, s * 2, uint128(CHUNK_L));

        (bool mintOk,,,) = mintAdapter.runMint(
            algebraReady.pool,
            algebraReady.fee,
            spacing,
            PAYER,
            PAYER,
            LEFTOVERS,
            spacing,
            packed
        );
        assertTrue(mintOk, "bootstrap mint");
    }

    function _seedPoolTokens() internal {
        _seedBalance(algebraReady.token0, PAYER, SEED);
        _seedBalance(algebraReady.token1, PAYER, SEED);
        _seedAllowance(algebraReady.token0, PAYER, address(harness), SEED);
        _seedAllowance(algebraReady.token1, PAYER, address(harness), SEED);
        _seedAllowance(algebraReady.token0, PAYER, address(mintAdapter), SEED);
        _seedAllowance(algebraReady.token1, PAYER, address(mintAdapter), SEED);
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
