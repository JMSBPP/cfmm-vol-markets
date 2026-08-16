// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title MulticallTargetMock
/// @notice Records every call it receives (sender + full calldata) for the multicall differential.
///         The catch-all `fallback` captures the arbitrary calldata a multicall forwards; the test
///         uses payloads that do not collide with the four view selectors below.
///         If `revertAtIndex >= 0`, the call at that index reverts — to exercise revert-all.
contract MulticallTargetMock {
    struct Recv {
        address sender;
        bytes data;
    }

    Recv[] internal received;
    int256 public revertAtIndex = -1;

    function setRevertAt(int256 idx) external {
        revertAtIndex = idx;
    }

    fallback() external payable {
        if (revertAtIndex >= 0 && received.length == uint256(revertAtIndex)) {
            revert("MulticallTargetMock: forced revert");
        }
        Recv storage r = received.push();
        r.sender = msg.sender;
        r.data = msg.data;
    }

    function count() external view returns (uint256) {
        return received.length;
    }

    function senderAt(uint256 i) external view returns (address) {
        return received[i].sender;
    }

    function dataAt(uint256 i) external view returns (bytes memory) {
        return received[i].data;
    }
}
