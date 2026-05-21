// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TwoStepOwnable} from "../../shared/TwoStepOwnable.sol";
import {IAgentShellFactory} from "../interfaces/IAgentShellFactory.sol";
import {AgentExecutionShell} from "./AgentExecutionShell.sol";

contract AgentShellFactory is TwoStepOwnable, IAgentShellFactory {
    address public immutable runtime;
    mapping(bytes32 agentId => address shell) public shellOfAgent;
    mapping(address launcher => bool authorized) public isAuthorizedLauncher;

    error ZeroRuntime();
    error ZeroOwnerAddress();
    error UnauthorizedLauncher(address caller);
    error ShellAlreadyExists(bytes32 agentId);

    event AuthorizedLauncherSet(address indexed launcher, bool authorized);
    event AgentShellCreated(bytes32 indexed agentId, address indexed shell, address indexed shellOwner, bytes32 graduationRoot);

    constructor(address runtime_, address initialOwner) TwoStepOwnable(initialOwner) {
        if (runtime_ == address(0)) revert ZeroRuntime();
        runtime = runtime_;
    }

    function setAuthorizedLauncher(address launcher, bool authorized) external onlyOwner {
        if (launcher == address(0)) revert ZeroOwnerAddress();
        isAuthorizedLauncher[launcher] = authorized;
        emit AuthorizedLauncherSet(launcher, authorized);
    }

    function graduateAgentToShell(bytes32 agentId, address shellOwner, bytes32 graduationRoot)
        external
        returns (address shell)
    {
        if (!isAuthorizedLauncher[msg.sender]) revert UnauthorizedLauncher(msg.sender);
        if (shellOwner == address(0)) revert ZeroOwnerAddress();
        if (shellOfAgent[agentId] != address(0)) revert ShellAlreadyExists(agentId);
        AgentExecutionShell deployed = new AgentExecutionShell(shellOwner, runtime, agentId, bytes32(0), graduationRoot);
        shell = address(deployed);
        shellOfAgent[agentId] = shell;
        emit AgentShellCreated(agentId, shell, shellOwner, graduationRoot);
    }
}
