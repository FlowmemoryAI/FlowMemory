// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BaseAgentMemoryTaskTargetMock
/// @notice Local/test target contract for actual deployed-log task-scout e2e runs.
contract BaseAgentMemoryTaskTargetMock {
    bytes32 public lastTaskId;
    address public lastCaller;
    string public lastUri;
    uint256 public acceptCount;

    event TaskAccepted(bytes32 indexed taskId, address indexed caller, string uri, uint256 acceptCount);

    function acceptTask(bytes32 taskId, string calldata uri) external {
        lastTaskId = taskId;
        lastCaller = msg.sender;
        lastUri = uri;
        acceptCount += 1;
        emit TaskAccepted(taskId, msg.sender, uri, acceptCount);
    }
}
