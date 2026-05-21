// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "../../shared/TwoStepOwnable.sol";

contract AgentExecutionShell is TwoStepOwnable {
    bytes32 public immutable parentAgentId;
    bytes32 public immutable classId;
    bytes32 public immutable graduationRoot;
    address public immutable runtime;
    bool public active;

    event ShellActivated(address indexed shell, bytes32 indexed parentAgentId, bytes32 indexed graduationRoot);
    event ShellPaused(address indexed shell, bool active, bytes32 reasonCode);

    constructor(address initialOwner, address runtime_, bytes32 parentAgentId_, bytes32 classId_, bytes32 graduationRoot_)
        TwoStepOwnable(initialOwner)
    {
        parentAgentId = parentAgentId_;
        classId = classId_;
        graduationRoot = graduationRoot_;
        runtime = runtime_;
        active = true;
        emit ShellActivated(address(this), parentAgentId_, graduationRoot_);
    }

    function setActive(bool value, bytes32 reasonCode) external onlyOwner {
        active = value;
        emit ShellPaused(address(this), value, reasonCode);
    }
}
