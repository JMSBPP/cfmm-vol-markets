// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "test/PlankTestBase.sol";

interface IRealizedVolatility {
    function wrapper() external view returns (address);
}

interface IInitIndex {
    function initializeTwap(address wrapper) external returns (uint256 tInit);
    function writeTimepoint(address wrapper) external;
    function timepointIndex(address wrapper) external view returns (uint256);
    function lastIndex(uint256 tInit, uint256 t) external view returns (uint256);
}

/// Integration: TimeSpacing(2) / TimeIndex.lastIndex vs Algebra timepointIndex
/// after initializeTWAP + one-bin writeTimepoint. Clock is the Plank timestamp builtin.
contract RealizedVolatilityInitIndexTest is PlankTestBase {
    IRealizedVolatility internal rv;
    IInitIndex internal harness;
    address internal wrapper;

    uint256 internal constant DT = 2;

    function setUp() public {
        rv = IRealizedVolatility(deployPlank("src/mod/RealizedVolatility.plk"));
        wrapper = rv.wrapper();
        harness = IInitIndex(deployPlank("test/harness/types/RealizedVolatilityInitIndexHarness.plk"));
    }

    function test__int__one_bin_write_timepointIndex_eq_lastIndex() public {
        uint256 tInit = harness.initializeTwap(wrapper);
        vm.warp(block.timestamp + DT);
        harness.writeTimepoint(wrapper);

        uint256 got = harness.timepointIndex(wrapper);
        uint256 want = harness.lastIndex(tInit, block.timestamp);
        assertEq(got, want);
        assertEq(want, 1);
    }
}
