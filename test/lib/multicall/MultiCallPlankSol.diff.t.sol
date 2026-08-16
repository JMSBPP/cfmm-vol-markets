// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PlankTestBase} from "../../PlankTestBase.sol";
import {MulticallTargetMock} from "./MulticallTargetMock.sol";
import {MulticallRef} from "./MulticallRef.sol";

/// @notice Differential: the Plank multicall (execute_batch, FFI-deployed) vs the Solidity
/// MulticallRef oracle. Same bytes[] batch through both, each against its own recorder; assert
/// identical forwarded-calldata sequence + order + revert-all, and that each mock sees ITS
/// executor as msg.sender (harness for Plank, ref for Solidity — the writer-context property).
contract MultiCallPlankSolDiffTest is PlankTestBase {
    address harness;              // Plank multicall (execute_batch)
    MulticallRef ref;             // Solidity oracle
    bytes4 constant SEL = 0x00c25829; // multicall(address,bytes[])

    function setUp() public {
        harness = deployPlank("test/lib/multicall/MulticallHarness.plk");
        ref = new MulticallRef();
    }

    function _callPlank(address target, bytes[] memory calls) internal returns (bool ok) {
        (ok, ) = harness.call(abi.encodeWithSelector(SEL, target, calls));
    }

    function _assertEquivalent(bytes[] memory calls) internal {
        MulticallTargetMock mp = new MulticallTargetMock();
        MulticallTargetMock mr = new MulticallTargetMock();
        assertTrue(_callPlank(address(mp), calls), "plank multicall reverted");
        ref.multicall(address(mr), calls);

        assertEq(mp.count(), calls.length, "plank count");
        assertEq(mr.count(), calls.length, "ref count");
        for (uint256 i = 0; i < calls.length; i++) {
            assertEq(mp.dataAt(i), calls[i], "plank calldata fidelity"); // byte-exact
            assertEq(keccak256(mp.dataAt(i)), keccak256(mr.dataAt(i)), "plank==ref calldata");
            assertEq(mp.senderAt(i), harness, "plank sender == harness"); // load-bearing
            assertEq(mr.senderAt(i), address(ref), "ref sender == ref");
        }
    }

    function test__unit__diff_variedLengths() public {
        bytes[] memory calls = new bytes[](3);
        calls[0] = hex"deadbeef"; // 4 bytes
        calls[1] = abi.encode(uint256(42), uint256(7)); // 64 bytes (2 words)
        calls[2] = hex"0011223344556677889900aabbccddeeff0102030405"; // 22 bytes (sub-word tail)
        _assertEquivalent(calls);
    }

    function test__unit__diff_singleCall() public {
        bytes[] memory calls = new bytes[](1);
        calls[0] = hex"cafe";
        _assertEquivalent(calls);
    }

    function test__unit__diff_emptyBatch() public {
        bytes[] memory calls = new bytes[](0);
        MulticallTargetMock mp = new MulticallTargetMock();
        assertTrue(_callPlank(address(mp), calls), "empty batch must not revert");
        assertEq(mp.count(), 0, "empty batch touches nothing");
    }

    function test__unit__revertAll_middleCallReverts() public {
        bytes[] memory calls = new bytes[](3);
        calls[0] = hex"aa";
        calls[1] = hex"bb";
        calls[2] = hex"cc";
        MulticallTargetMock mp = new MulticallTargetMock();
        mp.setRevertAt(1);
        assertFalse(_callPlank(address(mp), calls), "plank must revert the whole batch");
    }
}
