// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {FlowToken} from "test/mocks/FlowToken.sol";

interface ISigmaF {
    function tokenAmount(uint256 sigmaF, uint256 deltaW) external view returns (uint256);
    function run(uint256 sigmaF, uint256 deltaW, address token, address from, address to)
        external
        returns (bool);
}

/// @title SigmaFTest
/// @notice Public product TokenAmount = (σ_F · |ΔW|) / RAY. #128
contract SigmaFTest is PlankTestBase {
    ISigmaF internal harness;

    uint256 internal constant RAY = 1e27;
    /// TimeSpacing / DeltaW index — TokenFlow is per this unit of time.
    uint256 internal constant DT = 2;
    /// floor(√2 · RAY) — Weiner +1σ ΔW at dt = 2
    uint256 internal constant SQRT_DT_RAY_2 = 1414213562373095048801688724;

    function setUp() public {
        harness = ISigmaF(deployPlank("test/harness/types/SigmaFHarness.plk"));
    }

    function test__beh__tokenAmount_oneRay_times_oneSigmaDt2_is_sqrt2Ray() public {
        vm.warp(block.timestamp + DT);
        uint256 got = harness.tokenAmount(RAY, SQRT_DT_RAY_2);
        assertEq(got, SQRT_DT_RAY_2);
    }

    function test__beh__tokenAmount_negativeDeltaW_same_magnitude() public {
        vm.warp(block.timestamp + DT);
        uint256 dwNeg;
        unchecked {
            dwNeg = uint256(0) - SQRT_DT_RAY_2;
        }
        uint256 got = harness.tokenAmount(RAY, dwNeg);
        assertEq(got, SQRT_DT_RAY_2);
    }

    function test__beh__run_positive_transfers_from_to() public {
        vm.warp(block.timestamp + DT);
        FlowToken token = new FlowToken();
        address from = address(0xA11CE);
        address to = address(0xB0B);
        uint256 amt = harness.tokenAmount(RAY, SQRT_DT_RAY_2);
        _seedBalance(address(token), from, amt);
        _seedAllowance(address(token), from, address(harness), amt);

        bool ok = harness.run(RAY, SQRT_DT_RAY_2, address(token), from, to);
        assertTrue(ok);
        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(to), amt);
    }

    function test__beh__run_negative_transfers_to_from() public {
        vm.warp(block.timestamp + DT);
        FlowToken token = new FlowToken();
        address from = address(0xA11CE);
        address to = address(0xB0B);
        uint256 dwNeg;
        unchecked {
            dwNeg = uint256(0) - SQRT_DT_RAY_2;
        }
        uint256 amt = harness.tokenAmount(RAY, dwNeg);
        _seedBalance(address(token), to, amt);
        _seedAllowance(address(token), to, address(harness), amt);

        bool ok = harness.run(RAY, dwNeg, address(token), from, to);
        assertTrue(ok);
        assertEq(token.balanceOf(to), 0);
        assertEq(token.balanceOf(from), amt);
    }

    /// run(io(amt,+)) with allowance and no balance → Outcome.None (ABI false).
    function test__beh__run_insufficient_balance_is_revert() public {
        vm.warp(block.timestamp + DT);
        FlowToken token = new FlowToken();
        address from = address(0xA11CE);
        address to = address(0xB0B);
        uint256 amt = harness.tokenAmount(RAY, SQRT_DT_RAY_2);
        _seedAllowance(address(token), from, address(harness), amt);

        bool ok = harness.run(RAY, SQRT_DT_RAY_2, address(token), from, to);
        assertFalse(ok);
        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(to), 0);
    }

    /// Compose ERC-8042 `keccak256("erc20")`: balanceOf at +0, allowance at +2.
    bytes32 internal constant ERC20_POS = keccak256("erc20");

    function _seedBalance(address _token, address _owner, uint256 _amt) internal {
        vm.store(_token, keccak256(abi.encode(_owner, ERC20_POS)), bytes32(_amt));
    }

    function _seedAllowance(address _token, address _owner, address _spender, uint256 _amt)
        internal
    {
        bytes32 ownerMap = keccak256(abi.encode(_owner, bytes32(uint256(ERC20_POS) + 2)));
        vm.store(_token, keccak256(abi.encode(_spender, ownerMap)), bytes32(_amt));
    }
}
