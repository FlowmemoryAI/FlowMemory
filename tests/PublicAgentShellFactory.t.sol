// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentShellFactory} from "../contracts/public-agent-network/shell/AgentShellFactory.sol";
import {AgentExecutionShell} from "../contracts/public-agent-network/shell/AgentExecutionShell.sol";

interface Vm {
    function expectRevert() external;
}

contract PublicAgentShellFactoryTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    AgentShellFactory private factory;

    error AssertionFailed();

    function setUp() public {
        factory = new AgentShellFactory(address(0x1234), address(this));
    }

    function testAuthorizedLauncherCreatesShell() public {
        bytes32 agentId = keccak256("agent.shell.alpha");
        factory.setAuthorizedLauncher(address(this), true);
        address shell = factory.graduateAgentToShell(agentId, address(this), keccak256("graduation.root"));
        _assertTrue(shell != address(0));
        _assertTrue(factory.shellOfAgent(agentId) == shell);
        _assertTrue(AgentExecutionShell(shell).parentAgentId() == agentId);
    }

    function testUnauthorizedLauncherCannotCreateShell() public {
        vm.expectRevert();
        factory.graduateAgentToShell(keccak256("agent.shell.beta"), address(this), keccak256("graduation.root"));
    }

    function _assertTrue(bool value) private pure {
        if (!value) revert AssertionFailed();
    }
}
