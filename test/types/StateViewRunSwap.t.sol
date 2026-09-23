// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {IntegralPoolBootstrap} from "test/helpers/Algebra/IntegralPoolBootstrap.sol";

interface IStateViewRunSwap {
    function runSwap(
        address pool,
        uint256 fee,
        uint256 tickSpacing,
        uint256 amount,
        uint256 dir,
        address token,
        address from,
        address to,
        uint256 binJ
    ) external returns (bool ok);
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

/// @dev Bulloak-generated names from StateViewRunSwap.btt. Assertions filled.
contract StateViewRunSwapTest is PlankTestBase {
    IStateViewRunSwap internal harness;
    IAlgebraMintCallbackAdapter internal mintAdapter;
    IntegralPoolBootstrap.ReadyPool internal algebraReady;

    address internal constant PAYER = address(0xA11CE);
    address internal constant TO = address(0xB0B);
    address internal constant LEFTOVERS = address(0xD00D);
    uint256 internal constant SEED = 1e24;
    uint256 internal constant SWAP_IN = 10_000;

    bytes32 internal constant ERC20_POS = keccak256("erc20");

    function setUp() public {
        harness = IStateViewRunSwap(deployPlank("test/harness/types/StateViewHarness.plk"));
        mintAdapter = IAlgebraMintCallbackAdapter(deployPlank("test/helpers/Algebra/AlgebraMintCallbackAdapter.plk"));
        algebraReady = IntegralPoolBootstrap.bootstrap(vm);
        _seedPoolTokens();
        _mintBootstrapLiquidity();
    }

    function test_WhenPoolAddressIsZero() external {
        // it should return run_swap None
        bool ok = harness.runSwap(
            address(0), algebraReady.fee, algebraReady.tickSpacing, SWAP_IN, 0, algebraReady.token0, PAYER, TO, 0
        );
        assertFalse(ok);
    }

    function test_WhenFlowAmountIsZero() external {
        // it should return run_swap None
        bool ok = harness.runSwap(
            algebraReady.pool,
            algebraReady.fee,
            algebraReady.tickSpacing,
            0,
            0,
            algebraReady.token0,
            PAYER,
            TO,
            0
        );
        assertFalse(ok);
    }

    function test_WhenSwapCallFails() external {
        // it should return run_swap None — payer not approved for harness callback
        bool ok = harness.runSwap(
            algebraReady.pool,
            algebraReady.fee,
            algebraReady.tickSpacing,
            SWAP_IN,
            0,
            algebraReady.token0,
            address(0xDEAD),
            TO,
            1
        );
        assertFalse(ok);
    }

    function test_WhenSwapCallSucceeds() external {
        // it should return run_swap Some — Integral pool + swap callback settlement
        bool ok = harness.runSwap(
            algebraReady.pool,
            algebraReady.fee,
            algebraReady.tickSpacing,
            SWAP_IN,
            0,
            algebraReady.token0,
            PAYER,
            TO,
            1
        );
        assertTrue(ok);
    }

    function _mintBootstrapLiquidity() internal {
        uint256 spacing = algebraReady.tickSpacing == 0 ? 1 : algebraReady.tickSpacing;
        int24 s = int24(uint24(spacing));
        int24 lower = s * -2;
        int24 upper = s * 2;
        uint256 packed = (uint256(uint24(lower)) << 232) | (uint256(uint24(upper)) << 208) | uint256(uint128(1_000_000_000_000));

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
}
