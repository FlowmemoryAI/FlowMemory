import assert from "node:assert/strict";
import test from "node:test";

import { bytesToHex, decodeBytes32Word, decodeUint256Word, hexToBytes, keccak256Utf8, normalizeAddress } from "../../shared/src/index.ts";
import {
  buildPublicAgentLaunchIntent,
  buildPublicAgentLaunchContractHashes,
  listPublicAgentClasses,
} from "../../flowmemory/src/public-agent-network.ts";
import {
  buildPublicSwarmLaunchIntent,
  buildPublicSwarmLaunchContractHashes,
  listPublicSwarmClasses,
} from "../../flowmemory/src/public-swarm-network.ts";
import {
  buildPublicAgentLaunchTransaction,
  buildPublicSwarmCreateTransaction,
} from "../src/public-contracts.ts";

function decodeAddressWord(data: Uint8Array, wordIndex: number): string {
  const word = decodeBytes32Word(data, wordIndex);
  return normalizeAddress(`0x${word.slice(-40)}`);
}

test("builds direct AgentFactory launch calldata with contract hashes", () => {
  const classConfig = listPublicAgentClasses()[0];
  assert.ok(classConfig);
  const intent = buildPublicAgentLaunchIntent(
    {
      owner: "0x1000000000000000000000000000000000000001",
      classId: classConfig.classId,
      objectiveText: "Launch a task scout",
      profileText: "Public task scout profile",
      toolSetRoot: "0xd6717d12f7068dbdbdfd4e9444d1aadf133b650aeb92fa44f2c1667af14e3c94",
      autonomyLevel: 2,
      riskLevel: 1,
      bondToken: "0x2000000000000000000000000000000000000001",
      bondAmount: "10000000000000000000",
      fuelToken: "0x2000000000000000000000000000000000000001",
      initialFuelAmount: "5000000000000000000",
      discoverable: true,
    },
    {
      rootfieldId: keccak256Utf8("rootfield.public.task-scout.alpha"),
      validAfter: "1",
      validUntil: "2",
      nonce: "0",
      salt: keccak256Utf8("launch.alpha"),
    },
  );

  const prepared = buildPublicAgentLaunchTransaction({
    factory: "0x3000000000000000000000000000000000000003",
    chainId: 31337,
    intent,
    ownerSignature: `0x${"11".repeat(65)}`,
    payment: {
      sponsorMode: true,
      sponsor: "0x4000000000000000000000000000000000000004",
    },
  });

  assert.equal(prepared.tx.method, "launchAgent");
  assert.equal(prepared.tx.to, "0x3000000000000000000000000000000000000003");
  assert.equal(prepared.tx.value, "0x0");
  assert.equal(prepared.signatureBytesLength, 65);
  const expectedHashes = buildPublicAgentLaunchContractHashes(intent, {
    chainId: 31337,
    verifyingContract: prepared.tx.to,
  });
  assert.deepEqual(prepared.hashes, expectedHashes);

  const data = hexToBytes(prepared.tx.data);
  assert.equal(bytesToHex(data.subarray(0, 4)), keccak256Utf8("launchAgent((address,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint8,uint8,bytes32,bytes32,address,uint256,address,uint256,bool,uint64,uint64,uint64,bytes32),bytes,(bool,address))").slice(0, 10));
  const body = data.subarray(4);
  assert.equal(decodeAddressWord(body, 0), normalizeAddress(intent.owner));
  assert.equal(decodeBytes32Word(body, 2), intent.classId);
  assert.equal(decodeBytes32Word(body, 10), intent.launchSpecRoot);
  assert.equal(decodeUint256Word(body, 24), 27n * 32n);
  assert.equal(decodeUint256Word(body, 25), 1n);
  assert.equal(decodeAddressWord(body, 26), normalizeAddress("0x4000000000000000000000000000000000000004"));
  const signatureOffset = Number(decodeUint256Word(body, 24));
  const signatureSection = body.subarray(signatureOffset);
  assert.equal(decodeUint256Word(signatureSection, 0), 65n);
});

test("rejects invalid direct AgentFactory signature length", () => {
  const classConfig = listPublicAgentClasses()[0];
  assert.ok(classConfig);
  const intent = buildPublicAgentLaunchIntent(
    {
      owner: "0x1000000000000000000000000000000000000001",
      classId: classConfig.classId,
      objectiveText: "Launch a task scout",
      profileText: "Public task scout profile",
      toolSetRoot: "0xd6717d12f7068dbdbdfd4e9444d1aadf133b650aeb92fa44f2c1667af14e3c94",
      autonomyLevel: 2,
      riskLevel: 1,
      bondToken: "0x2000000000000000000000000000000000000001",
      bondAmount: "10000000000000000000",
      fuelToken: "0x2000000000000000000000000000000000000001",
      initialFuelAmount: "5000000000000000000",
      discoverable: true,
    },
    {
      rootfieldId: keccak256Utf8("rootfield.public.task-scout.alpha"),
      validAfter: "1",
      validUntil: "2",
      nonce: "0",
      salt: keccak256Utf8("launch.alpha"),
    },
  );

  assert.throws(
    () => buildPublicAgentLaunchTransaction({
      factory: "0x3000000000000000000000000000000000000003",
      chainId: 31337,
      intent,
      ownerSignature: "0x1234",
    }),
    /ownerSignature must be 65 bytes/,
  );
});

test("builds direct SwarmFactory create calldata with members", () => {
  const swarmClass = listPublicSwarmClasses()[0];
  assert.ok(swarmClass);
  const intent = buildPublicSwarmLaunchIntent(
    {
      creator: "0x1000000000000000000000000000000000000001",
      swarmClass: swarmClass.swarmClass,
      missionText: "Research a launch opportunity",
      profileText: "Research swarm profile",
      budgetAsset: "0x2000000000000000000000000000000000000001",
      initialBudget: "1000000000000000000",
    },
    {
      validAfter: "1",
      validUntil: "2",
      nonce: "0",
      salt: keccak256Utf8("swarm.alpha"),
    },
  );

  const prepared = buildPublicSwarmCreateTransaction({
    factory: "0x3000000000000000000000000000000000000003",
    chainId: 31337,
    policyId: keccak256Utf8("policy.research-swarm.v0"),
    intent,
    initialMembers: [
      {
        memberType: "wallet",
        wallet: "0x5000000000000000000000000000000000000005",
        role: keccak256Utf8("founder"),
        permissionsRoot: keccak256Utf8("founder.permissions"),
        weight: 100,
        active: true,
      },
      {
        memberType: "agent",
        agentId: keccak256Utf8("agent.alpha"),
        role: keccak256Utf8("researcher"),
        permissionsRoot: keccak256Utf8("researcher.permissions"),
        weight: 50,
        active: true,
      },
    ],
  });

  assert.equal(prepared.tx.method, "createSwarm");
  assert.equal(prepared.memberCount, 2);
  const expectedHashes = buildPublicSwarmLaunchContractHashes(intent, {
    chainId: 31337,
    factory: prepared.tx.to,
  });
  assert.deepEqual(prepared.hashes, expectedHashes);

  const data = hexToBytes(prepared.tx.data);
  assert.equal(bytesToHex(data.subarray(0, 4)), keccak256Utf8("createSwarm(bytes32,(address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,address,uint256,uint64,uint64,uint64,bytes32,bytes32),(uint8,address,bytes32,bytes32,address,bytes32,bytes32,uint16,bool,uint64,uint64)[])").slice(0, 10));
  const body = data.subarray(4);
  assert.equal(decodeBytes32Word(body, 0), keccak256Utf8("policy.research-swarm.v0"));
  assert.equal(decodeAddressWord(body, 1), normalizeAddress(intent.creator));
  assert.equal(decodeBytes32Word(body, 2), intent.swarmClass);
  assert.equal(decodeUint256Word(body, 15), 16n * 32n);
  const memberOffset = Number(decodeUint256Word(body, 15));
  const memberSection = body.subarray(memberOffset);
  assert.equal(decodeUint256Word(memberSection, 0), 2n);
  const memberWords = 11;
  const firstMemberOffset = 32;
  const secondMemberOffset = 32 + memberWords * 32;
  assert.equal(decodeUint256Word(memberSection.subarray(firstMemberOffset), 0), 0n);
  assert.equal(decodeAddressWord(memberSection.subarray(firstMemberOffset), 1), normalizeAddress("0x5000000000000000000000000000000000000005"));
  assert.equal(decodeUint256Word(memberSection.subarray(secondMemberOffset), 0), 1n);
  assert.equal(decodeBytes32Word(memberSection.subarray(secondMemberOffset), 2), keccak256Utf8("agent.alpha"));
});
