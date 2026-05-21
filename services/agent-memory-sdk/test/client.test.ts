import assert from "node:assert/strict";
import { once } from "node:events";
import test from "node:test";

import { startControlPlaneServer } from "../../control-plane/src/server.ts";
import { AgentMemoryClient, AgentMemoryError, AgentMemoryRpcClient } from "../src/index.ts";

const FIXTURE_AGENT_ID = "0x54b047dd7daa6ef87caefa5e0ad8e38051c899bff154438d77bd1d02545512f9";
const TASK_KIND = "0xc9e6d2fdcdd866ffc316ab98456f2ddaa565949a49c74b3866afccf3f8d96daa";
const EVIDENCE_REQUIREMENT = "0x26e2697356633bb0f5aede8e3740160536621b5f39c3fa17b0fbe3e8ebd40a34";
const TASK_ID = "0x939bceec9246a8c9ddb76aa07937b32d767f97ef91846c1ff28d6e96afdae9cd";

test("loads fixture-backed agent config and memory", () => {
  const client = new AgentMemoryClient();
  const agent = client.getAgent(FIXTURE_AGENT_ID);
  const hotMemory = client.getHotMemory(FIXTURE_AGENT_ID);

  assert.equal(agent.agentId, FIXTURE_AGENT_ID);
  assert.equal(agent.status, "active");
  assert.equal(hotMemory.agentId, FIXTURE_AGENT_ID);
  assert.equal(hotMemory.failureCount, 0);
});

test("builds API data Agent Bonds quote and create request from fixtures", () => {
  const client = new AgentMemoryClient();
  const template = client.getApiDataBondTemplate();
  const quote = client.quoteApiDataBond();
  const createRequest = client.createApiDataBondedTask();

  assert.equal(template.envelope.envelopeId, "env_api_data_recourse_001");
  assert.equal(quote.decision.status, "approved");
  assert.equal(typeof (quote.decision.policyAttestation as Record<string, unknown>).attestationId, "string");
  assert.equal(createRequest.method, "openTaskWithRecourse");
  assert.deepEqual(createRequest.recourseDecision, quote.decision);
});

test("encodes observation and previews deterministic step", () => {
  const client = new AgentMemoryClient();
  const observation = client.encodeTaskObservation({
    taskContract: "0x3000000000000000000000000000000000000003",
    taskId: TASK_ID,
    taskKind: TASK_KIND,
    taskKindName: "docs-review",
    evidenceRequirement: EVIDENCE_REQUIREMENT,
    evidenceRequirementName: "public",
    rewardToken: "0x0000000000000000000000000000000000000000",
    rewardAmount: 1000000000000000000n,
    deadlineBlock: 18000000n,
    taskStatus: "open",
    recentFailureCount: 0,
    humanReviewRequired: false,
  });
  const preview = client.previewStep({ agentId: FIXTURE_AGENT_ID, observation });

  assert.equal(preview.action, "ACCEPT_TASK");
  assert.equal(preview.reasonCode, "TASK_KIND_ALLOWED");
  assert.equal(preview.maxValue, 0n);
});

test("submits expected preview and replays receipt", () => {
  const client = new AgentMemoryClient();
  const observation = client.encodeTaskObservation({
    taskContract: "0x3000000000000000000000000000000000000003",
    taskId: TASK_ID,
    taskKind: TASK_KIND,
    taskKindName: "docs-review",
    evidenceRequirement: EVIDENCE_REQUIREMENT,
    evidenceRequirementName: "public",
    rewardToken: "0x0000000000000000000000000000000000000000",
    rewardAmount: 1000000000000000000n,
    deadlineBlock: 18000000n,
    taskStatus: "open",
    recentFailureCount: 0,
    humanReviewRequired: false,
  });
  const preview = client.previewStep({ agentId: FIXTURE_AGENT_ID, observation });
  const submitted = client.step({
    agentId: FIXTURE_AGENT_ID,
    observation,
    expectedPreview: preview,
    expectedSequence: preview.sequence,
    maxValue: preview.maxValue,
  });
  const receipt = client.waitForStepReceipt(submitted.hash);
  const replay = client.replayStep(receipt);

  assert.equal(replay.status, "verified");
  assert.equal(replay.actionReceiptId, receipt.actionReceiptId);
  assert.equal(replay.checks.every((check) => check.status === "pass"), true);
});

test("rejects mismatched chain ids and preview hashes", () => {
  assert.throws(() => new AgentMemoryClient({ chainId: 1 }), (error: unknown) => {
    assert.ok(error instanceof AgentMemoryError);
    assert.equal(error.code, "CHAIN_ID_MISMATCH");
    return true;
  });

  const client = new AgentMemoryClient();
  const observation = client.encodeTaskObservation({
    taskContract: "0x3000000000000000000000000000000000000003",
    taskId: TASK_ID,
    taskKind: TASK_KIND,
    taskKindName: "docs-review",
    evidenceRequirement: EVIDENCE_REQUIREMENT,
    evidenceRequirementName: "public",
    rewardToken: "0x0000000000000000000000000000000000000000",
    rewardAmount: 1000000000000000000n,
    deadlineBlock: 18000000n,
    taskStatus: "open",
    recentFailureCount: 0,
    humanReviewRequired: false,
  });
  const preview = client.previewStep({ agentId: FIXTURE_AGENT_ID, observation });
  assert.throws(
    () => client.step({
      agentId: FIXTURE_AGENT_ID,
      observation,
      expectedPreview: { ...preview, previewHash: "0x0000000000000000000000000000000000000000000000000000000000000001" },
      expectedSequence: preview.sequence,
      maxValue: preview.maxValue,
    }),
    (error: unknown) => {
      assert.ok(error instanceof AgentMemoryError);
      assert.equal(error.code, "PREVIEW_MISMATCH");
      return true;
    },
  );
});

test("loads task scout and Agent Bonds quote through control-plane RPC mode", async () => {
  const fixtureModule = await import("../../../fixtures/base-agent-memory/task-scout-v0.json", { with: { type: "json" } });
  const rpcFixture = fixtureModule.default;
  const fetchImpl: typeof fetch = async (_input, init) => {
    const payload = JSON.parse(String(init?.body)) as { method: string; params: { agentId: string } };
    if (payload.method === "base_agent_memory_task_scout_get") {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: payload.method,
        result: {
          schema: "flowmemory.control_plane.base_agent_memory_task_scout.v1",
          scout: { agentId: rpcFixture.agentConfig.agentId, rootfieldId: rpcFixture.agentConfig.rootfieldId },
          fixture: rpcFixture,
          replayReport: rpcFixture.verifierReport,
          localOnly: true,
        },
      }), { status: 200, headers: { "content-type": "application/json" } });
    }
    if (payload.method === "base_agent_memory_replay_get") {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: payload.method,
        result: {
          schema: "flowmemory.control_plane.base_agent_memory_replay.v1",
          agentId: payload.params.agentId,
          rootfieldId: rpcFixture.agentConfig.rootfieldId,
          report: rpcFixture.verifierReport,
          localOnly: true,
        },
      }), { status: 200, headers: { "content-type": "application/json" } });
    }
    if (payload.method === "agent_bond_recourse_decision_quote") {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: payload.method,
        result: {
          schema: "flowmemory.control_plane.agent_bond_recourse_decision_quote.v1",
          decision: {
            decisionId: "decision_api_data_001",
            envelopeId: "env_api_data_recourse_001",
            status: "approved",
            policyAttestation: {
              attestationId: "0xc8484c2e045fa38c4202d549cf1bfd26660c2f3c4958d8d1b6818648c0b38112",
            },
          },
          localOnly: true,
        },
      }), { status: 200, headers: { "content-type": "application/json" } });
    }
    throw new Error(`unexpected RPC method ${payload.method}`);
  };

  const client = new AgentMemoryRpcClient({ rpcUrl: "http://127.0.0.1:8787/rpc", chainId: 84532, fetchImpl });
  const agent = await client.getAgent(FIXTURE_AGENT_ID);
  const observation = client.encodeTaskObservation({
    taskContract: "0x3000000000000000000000000000000000000003",
    taskId: TASK_ID,
    taskKind: TASK_KIND,
    taskKindName: "docs-review",
    evidenceRequirement: EVIDENCE_REQUIREMENT,
    evidenceRequirementName: "public",
    rewardToken: "0x0000000000000000000000000000000000000000",
    rewardAmount: 1000000000000000000n,
    deadlineBlock: 18000000n,
    taskStatus: "open",
    recentFailureCount: 0,
    humanReviewRequired: false,
  });
  const preview = await client.previewStep({ agentId: agent.agentId, observation });
  const submitted = await client.step({
    agentId: agent.agentId,
    observation,
    expectedPreview: preview,
    expectedSequence: preview.sequence,
    maxValue: preview.maxValue,
  });
  const receipt = await client.waitForStepReceipt(submitted.hash, agent.agentId);
  const replay = await client.replayStep(receipt, agent.agentId);
  const view = await client.getAgentMemoryView(agent.agentId);
  const quote = await client.quoteAgentBondRecourse({ agentId: "agent_data_001" });
  const createRequest = await client.createApiDataBondedTask({ agentId: "agent_data_001" });

  assert.equal(agent.agentId, FIXTURE_AGENT_ID);
  assert.equal(preview.action, "ACCEPT_TASK");
  assert.equal(replay.status, "verified");
  assert.equal(view.agentId, FIXTURE_AGENT_ID);
  assert.equal(quote.decision.status, "approved");
  assert.equal(createRequest.method, "openTaskWithRecourse");
});

test("runs against a live local control-plane server", async () => {
  const server = startControlPlaneServer({ host: "127.0.0.1", port: 0 });
  try {
    server.listen(0, "127.0.0.1");
    await once(server, "listening");
    const address = server.address();
    if (address === null || typeof address === "string") {
      throw new Error("missing server address");
    }
    const client = new AgentMemoryRpcClient({ rpcUrl: `http://127.0.0.1:${address.port}/rpc`, chainId: 84532 });
    const agent = await client.getAgent(FIXTURE_AGENT_ID);
    const observation = client.encodeTaskObservation({
      taskContract: "0x3000000000000000000000000000000000000003",
      taskId: TASK_ID,
      taskKind: TASK_KIND,
      taskKindName: "docs-review",
      evidenceRequirement: EVIDENCE_REQUIREMENT,
      evidenceRequirementName: "public",
      rewardToken: "0x0000000000000000000000000000000000000000",
      rewardAmount: 1000000000000000000n,
      deadlineBlock: 18000000n,
      taskStatus: "open",
      recentFailureCount: 0,
      humanReviewRequired: false,
    });
    const preview = await client.previewStep({ agentId: agent.agentId, observation });
    const submitted = await client.step({
      agentId: agent.agentId,
      observation,
      expectedPreview: preview,
      expectedSequence: preview.sequence,
      maxValue: preview.maxValue,
    });
    const receipt = await client.waitForStepReceipt(submitted.hash, agent.agentId);
    const replay = await client.replayStep(receipt, agent.agentId);

    assert.equal(agent.agentId, FIXTURE_AGENT_ID);
    assert.equal(preview.action, "ACCEPT_TASK");
    assert.equal(replay.status, "verified");
  } finally {
    server.close();
    await once(server, "close");
  }
});
