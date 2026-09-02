// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PlankTestBase} from "../PlankTestBase.sol";
import {PairVerifyCompliantERC20} from "../mocks/PairVerifyCompliantERC20.sol";


contract PairTest is PlankTestBase {
    address harness;
    function setUp() public {
        harness = deployPlank("test/types/PairHarness.plk");
    }

    function test__placeholder() public{}

}
