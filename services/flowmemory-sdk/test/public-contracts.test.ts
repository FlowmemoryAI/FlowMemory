import assert from "node:assert/strict";
import test from "node:test";

import { bytesToHex, decodeBytes32Word, decodeUint256Word, hexToBytes, keccak256Utf8, normalizeAddress, normalizeBytes32 } from "../../shared/src/index.ts";
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
  PUBLIC_AGENT_CONTRACT_EVENT_TOPICS,
  buildPublicAgentLaunchTransaction,
  buildPublicAgentLaunchTypedData,
  buildPublicSwarmCreateTransaction,
  decodePublicContractReceipt,
  signPublicAgentLaunchIntent,
  submitPreparedContractTransaction,
  waitForTransactionReceipt,
} from "../src/public-contracts.ts";

function decodeAddressWord(data: Uint8Array, wordIndex: number): string {
  const word = decodeBytes32Word(data, wordIndex);
  return normalizeAddress(`0x${word.slice(-40)}`);
}


class FakeProvider {
  readonly requests: Array<{ method: string; params?: unknown[] }> = [];
  readonly responses: Record<string, unknown[]>;

  constructor(responses: Record<string, unknown[]>) {
    this.responses = responses;
  }

  async request(args: { method: string; params?: unknown[] }): Promise<unknown> {
    this.requests.push(args);
    const queue = this.responses[args.method];
    assert.ok(queue, `unexpected method ${args.method}`);
    assert.ok(queue.length > 0, `no response queued for ${args.method}`);
    const next = queue.shift();
    if (next instanceof Error) throw next;
    return next;
  }
}

function samplePublicAgentIntent() {
  const classConfig = listPublicAgentClasses()[0];
  assert.ok(classConfig);
  return buildPublicAgentLaunchIntent(
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
}

function topicAddress(address: string): string {
  return normalizeBytes32(`0x${"0".repeat(24)}${normalizeAddress(address).slice(2)}`);
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

test("builds EIP-712 launch typed data and signs through an external provider", async () => {
  const intent = samplePublicAgentIntent();
  const factory = "0x3000000000000000000000000000000000000003";
  const typedDataRequest = buildPublicAgentLaunchTypedData({ factory, chainId: 31337, intent });
  const expectedHashes = buildPublicAgentLaunchContractHashes(intent, {
    chainId: 31337,
    verifyingContract: factory,
  });
  assert.deepEqual(typedDataRequest.hashes, expectedHashes);
  assert.equal(typedDataRequest.typedData.primaryType, "LaunchIntent");
  assert.equal(typedDataRequest.typedData.domain.verifyingContract, normalizeAddress(factory));
  assert.equal(typedDataRequest.typedData.message.rootsHash, expectedHashes.rootsHash);
  assert.equal(typedDataRequest.typedData.message.configHash, expectedHashes.configHash);
  assert.equal(typedDataRequest.typedData.message.lineageHash, expectedHashes.lineageHash);
  assert.equal(typedDataRequest.typedData.message.fundingHash, expectedHashes.fundingHash);

  const provider = new FakeProvider({
    eth_signTypedData_v4: [`0x${"22".repeat(65)}`],
  });
  const signature = await signPublicAgentLaunchIntent({ provider, factory, chainId: 31337, intent });
  assert.equal(signature, `0x${"22".repeat(65)}`);
  assert.equal(provider.requests.length, 1);
  assert.equal(provider.requests[0]?.method, "eth_signTypedData_v4");
  assert.equal(provider.requests[0]?.params?.[0], normalizeAddress(intent.owner));
  const typedData = JSON.parse(String(provider.requests[0]?.params?.[1]));
  assert.equal(typedData.message.rootsHash, expectedHashes.rootsHash);
  assert.equal(JSON.stringify(provider.requests).includes("privateKey"), false);
});

test("submits prepared contract transactions through an external provider", async () => {
  const intent = samplePublicAgentIntent();
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
  const provider = new FakeProvider({
    eth_sendTransaction: [`0x${"aa".repeat(32)}`],
  });

  const submitted = await submitPreparedContractTransaction({
    provider,
    from: "0x4000000000000000000000000000000000000004",
    tx: prepared.tx,
  });

  assert.equal(submitted.transactionHash, `0x${"aa".repeat(32)}`);
  assert.deepEqual(provider.requests[0], {
    method: "eth_sendTransaction",
    params: [{
      from: "0x4000000000000000000000000000000000000004",
      to: "0x3000000000000000000000000000000000000003",
      data: prepared.tx.data,
      value: "0x0",
    }],
  });
});

test("waits for transaction receipt without accepting raw secrets", async () => {
  const txHash = `0x${"ab".repeat(32)}`;
  const receipt = {
    transactionHash: txHash,
    status: "0x1",
    blockNumber: "0x10",
    logs: [],
  };
  const provider = new FakeProvider({
    eth_getTransactionReceipt: [null, receipt],
  });

  const observed = await waitForTransactionReceipt({
    provider,
    transactionHash: txHash,
    options: { maxAttempts: 2, pollIntervalMs: 0 },
  });

  assert.equal(observed.transactionHash, txHash);
  assert.equal(observed.status, "0x1");
  assert.equal(provider.requests.length, 2);
});

test("decodes public agent and swarm receipt events", () => {
  const txHash = `0x${"cd".repeat(32)}`;
  const launchIntentHash = keccak256Utf8("launch.intent");
  const launchId = keccak256Utf8("launch.id");
  const agentId = keccak256Utf8("agent.id");
  const swarmId = keccak256Utf8("swarm.id");
  const creator = "0x5000000000000000000000000000000000000005";
  const receipt = {
    transactionHash: txHash,
    status: "0x1",
    logs: [
      {
        address: "0x3000000000000000000000000000000000000003",
        topics: [
          PUBLIC_AGENT_CONTRACT_EVENT_TOPICS.AgentLaunched,
          launchIntentHash,
          launchId,
          agentId,
        ],
        data: "0x",
        transactionHash: txHash,
        logIndex: "0x0",
      },
      {
        address: "0x3000000000000000000000000000000000000004",
        topics: [
          PUBLIC_AGENT_CONTRACT_EVENT_TOPICS.SwarmLaunched,
          swarmId,
          topicAddress(creator),
        ],
        data: "0x",
        transactionHash: txHash,
        logIndex: "0x1",
      },
    ],
  };

  const decoded = decodePublicContractReceipt(receipt);
  assert.equal(decoded.successful, true);
  assert.equal(decoded.events.length, 2);
  assert.deepEqual(decoded.agentLaunches, [{
    launchIntentHash,
    launchId,
    agentId,
    address: "0x3000000000000000000000000000000000000003",
  }]);
  assert.deepEqual(decoded.swarmLaunches, [{
    swarmId,
    creator: normalizeAddress(creator),
    address: "0x3000000000000000000000000000000000000004",
  }]);
});
