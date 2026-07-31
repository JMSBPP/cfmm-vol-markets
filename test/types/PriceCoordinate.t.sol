// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../PlankTestBase.sol";

contract PriceCoordinateTest is PlankTestBase {
    // FFI-deployed Plank harness:
    //   coordinate(uint256,uint256,uint256) -> (bytes32,uint256,uint256,uint256)
    //     args  : tick_spacing, subs_elasticity (η, Q64.96), numb_rep
    //     return: (id, tick_spacing, subs_elasticity, numb_rep)
    address internal harness;

    uint256 constant NUMB_REP_Q64_96 = 96; // fixed-point scale tag (shared by η and sqrtPriceX96)

    function setUp() public {
        harness = deployPlank("test/types/PriceCoordinateHarness.plk");
    }

    // A PriceCoordinate round-trips every field losslessly, and its id is the canonical
    // keccak256 fingerprint of the frame params — for ANY (tick_spacing, η). One call proves both.
    function testFuzz_coordinate_roundTripsFieldsAndIdIsKeccakOfParams(uint256 tickSpacing, uint256 eta) public {
        (bool ok, bytes memory ret) = harness.staticcall(
            abi.encodeWithSignature("coordinate(uint256,uint256,uint256)", tickSpacing, eta, NUMB_REP_Q64_96)
        );
        assertTrue(ok, "harness call reverted");
        (bytes32 id, uint256 ts, uint256 subs, uint256 numbRep) =
            abi.decode(ret, (bytes32, uint256, uint256, uint256));

        // fields round-trip losslessly
        assertEq(ts, tickSpacing, "tick_spacing");
        assertEq(subs, eta, "subs_elasticity");
        assertEq(numbRep, NUMB_REP_Q64_96, "numb_rep");

        // id is the keccak fingerprint of the stored frame params
        assertEq(id, keccak256(abi.encode(tickSpacing, eta, NUMB_REP_Q64_96)), "id == keccak256(params)");
    }
}
