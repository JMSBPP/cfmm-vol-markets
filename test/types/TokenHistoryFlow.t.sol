// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {FlowToken} from "test/mocks/FlowToken.sol";
import {WeinerView} from "test/mocks/WeinerView.sol";

interface ITokenHistoryFlow {
    function runAll(address weiner, uint256 sigmaF, uint256 tInit, uint256 k, address token, address from, address to)
        external
        returns (bool);
}

/// @title TokenHistoryFlowTest
/// @notice run_k: all j<K Xfers. Fuzz K ∈ [1, 128].
contract TokenHistoryFlowTest is PlankTestBase {
    ITokenHistoryFlow internal harness;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant T_INIT = 1000;
    /// runAll ≈ 34e3 + 11.8e3·K; K=128 → 1.54M. Algebra K<n=43200 does not fit a block.
    uint256 internal constant RUN_ALL_K_MAX = 128;

    function setUp() public {
        harness = ITokenHistoryFlow(deployPlank("test/harness/types/TokenHistoryFlowHarness.plk"));
    }

    /// forge-config: default.fuzz.runs = 256
    /// forge-config: rv_init.fuzz.runs = 256
    function test__fuzz__run_all_k(uint256 kRaw, uint256 seed) public {
        uint256 k = bound(kRaw, 1, RUN_ALL_K_MAX);
        WeinerView weiner = new WeinerView();
        uint256 total;
        int256 netFrom;
        for (uint256 j = 0; j < k; j++) {
            uint256 mag = bound(uint256(keccak256(abi.encode(seed, j))), 1, 1e6);
            bool neg = uint256(keccak256(abi.encode(seed, j, uint256(1)))) & 1 == 1;
            uint256 dw = mag;
            if (neg) {
                unchecked {
                    dw = uint256(0) - mag;
                }
            }
            weiner.set(j, dw);
            total += mag;
            netFrom += neg ? int256(mag) : -int256(mag);
        }

        FlowToken token = new FlowToken();
        address from = address(0xA11CE);
        address to = address(0xB0B);
        _seedBalance(address(token), from, total);
        _seedBalance(address(token), to, total);
        _seedAllowance(address(token), from, address(harness), total);
        _seedAllowance(address(token), to, address(harness), total);

        bool ok = harness.runAll(address(weiner), RAY, T_INIT, k, address(token), from, to);
        assertTrue(ok);
        assertEq(token.balanceOf(from), uint256(int256(total) + netFrom));
        assertEq(token.balanceOf(to), uint256(int256(total) - netFrom));
    }

    bytes32 internal constant ERC20_POS = keccak256("erc20");

    function _seedBalance(address _token, address _owner, uint256 _amt) internal {
        vm.store(_token, keccak256(abi.encode(_owner, ERC20_POS)), bytes32(_amt));
    }

    function _seedAllowance(address _token, address _owner, address _spender, uint256 _amt) internal {
        bytes32 ownerMap = keccak256(abi.encode(_owner, bytes32(uint256(ERC20_POS) + 2)));
        vm.store(_token, keccak256(abi.encode(_spender, ownerMap)), bytes32(_amt));
    }
}
