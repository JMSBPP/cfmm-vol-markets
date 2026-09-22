// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";
import {WeinerView} from "test/mocks/WeinerView.sol";

interface ITokenHistory {
    function intro(address weiner, uint256 sigmaF, uint256 tInit, uint256 k) external view returns (uint256 len);

    function step(address weiner, uint256 sigmaF, uint256 tInit, uint256 k, uint256 j)
        external
        view
        returns (bool ok, uint256 t, uint256 i, uint256 dw, uint256 dq);
}

/// @title TokenHistoryTest
/// @notice intro returns len=K; cells via step(j). dt=2.
contract TokenHistoryTest is PlankTestBase {
    ITokenHistory internal harness;

    uint256 internal constant DT = 2;
    uint256 internal constant WINDOW = 86400;
    uint256 internal constant N = WINDOW / DT;
    uint256 internal constant T_INIT = 1000;
    uint256 internal constant SF = 1;

    function setUp() public {
        harness = ITokenHistory(deployPlank("test/harness/types/TokenHistoryHarness.plk"));
    }

    /// n(dt=2) = Window/dt = 43200 timepoints.
    /// forge-config: default.fuzz.runs = 43200
    /// forge-config: rv-init.fuzz.runs = 43200
    /// forge-config: sigmaf.fuzz.runs = 43200
    function test__fuzz__intro_k_lt_n(uint256 k, uint256 j, uint256 dw) public {
        k = bound(k, 1, N - 1);
        j = bound(j, 0, k - 1);
        dw = bound(dw, 0, 1e18);

        WeinerView weiner = new WeinerView();
        weiner.set(j, dw);

        uint256 len = harness.intro(address(weiner), SF, T_INIT, k);
        assertEq(len, k);

        (bool ok, uint256 t, uint256 i, uint256 gotDw, uint256 dq) =
            harness.step(address(weiner), SF, T_INIT, len, j);

        assertTrue(ok);
        assertEq(t, T_INIT + j * DT);
        assertEq(i, j);
        assertEq(gotDw, dw);
        assertEq(dq, SF * dw);
    }
}
