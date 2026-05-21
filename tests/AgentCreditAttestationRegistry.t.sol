// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgentCreditAttestationRegistry} from "../contracts/AgentCreditAttestationRegistry.sol";

interface CreditVm {
    function warp(uint256 newTimestamp) external;
}

contract AgentCreditAttestationRegistryTest {
    CreditVm private constant vm = CreditVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    AgentCreditAttestationRegistry private registry;
    address private agent = address(0xB00D);
    bytes32 private scope = keccak256("policy.objective-data-low-risk");

    function setUp() public {
        registry = new AgentCreditAttestationRegistry(address(this));
        registry.setAuthorizedAttester(address(this), true);
    }

    function testPublishAndValidateAttestation() public {
        uint64 expiresAt = uint64(block.timestamp + 1 days);
        bytes32 scoreHash = keccak256("score.hash");
        registry.publishAttestation(agent, scope, 720, 1, expiresAt, scoreHash);
        require(registry.isAttestationValid(agent, scope, 700, 2), "attestation valid");
    }

    function testExpiredOrWeakAttestationsFailValidation() public {
        uint64 expiresAt = uint64(block.timestamp + 1 days);
        bytes32 scoreHash = keccak256("score.hash.weak");
        registry.publishAttestation(agent, scope, 600, 3, expiresAt, scoreHash);
        require(!registry.isAttestationValid(agent, scope, 700, 2), "weak attestation invalid");

        vm.warp(block.timestamp + 2 days);
        require(!registry.isAttestationValid(agent, scope, 500, 5), "expired attestation invalid");
    }
}
