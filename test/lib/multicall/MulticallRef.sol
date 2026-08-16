// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title MulticallRef
/// @notice Solidity reference for the multicall differential — OUR semantics, NOT Solady's
///         self-delegatecall Multicallable: an external `call` to ONE target for each pre-encoded
///         payload, revert-all on any failure, no return. This is the independent oracle the Plank
///         execute_batch is diffed against; the caller (this contract) is msg.sender at the
///         target, exactly as the Plank harness's evm_call makes the harness msg.sender.
contract MulticallRef {
    function multicall(address target, bytes[] calldata calls) external {
        for (uint256 i = 0; i < calls.length; i++) {
            (bool ok, ) = target.call(calls[i]);
            if (!ok) revert("MulticallRef: call failed");
        }
    }
}
