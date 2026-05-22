import assert from "node:assert/strict";
import test from "node:test";

import { FlowMemoryClient, FlowMemoryRpcError } from "../src/client.ts";
import { redactFlowMemoryText, redactJsonValue } from "../src/redact.ts";

test("calls JSON-RPC with stable envelope shape", async () => {
  const calls: unknown[] = [];
  const client = new FlowMemoryClient({
    rpcUrl: "http://127.0.0.1:8787/rpc",
    fetchImpl: (async (_url, init) => {
      calls.push(JSON.parse(String(init?.body)));
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: "ok", result: { schema: "ok" } }), { status: 200 });
    }) as typeof fetch,
  });
  const result = await client.call("health", {});
  assert.deepEqual(result, { schema: "ok" });
  assert.deepEqual(calls, [
    {
      jsonrpc: "2.0",
      id: "flowmemory-sdk:health",
      method: "health",
      params: {},
    },
  ]);
});

test("turns JSON-RPC errors into tagged FlowMemory errors", async () => {
  const client = new FlowMemoryClient({
    fetchImpl: (async () => {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: "fail",
        error: { code: -32601, message: "method.not_found" },
      }), { status: 200 });
    }) as typeof fetch,
  });
  await assert.rejects(() => client.call("missing"), (error) => {
    assert.ok(error instanceof FlowMemoryRpcError);
    assert.equal(error.code, -32601);
    assert.equal(error.message, "method.not_found");
    return true;
  });
});

test("submits wallet send through control-plane HTTP path", async () => {
  const calls: { url: string; body: unknown }[] = [];
  const client = new FlowMemoryClient({
    rpcUrl: "http://127.0.0.1:8787/rpc",
    fetchImpl: (async (url, init) => {
      calls.push({ url: String(url), body: JSON.parse(String(init?.body)) });
      return new Response(JSON.stringify({ schema: "flowmemory.control_plane.wallet_send_result.v0" }), { status: 200 });
    }) as typeof fetch,
  });
  const result = await client.walletSend({
    fromAccountId: "local-account:sender",
    toAccountId: "local-account:recipient",
    amountUnits: "1",
  });
  assert.equal((result as { schema?: string }).schema, "flowmemory.control_plane.wallet_send_result.v0");
  assert.deepEqual(calls, [
    {
      url: "http://127.0.0.1:8787/wallets/send",
      body: {
        fromAccountId: "local-account:sender",
        toAccountId: "local-account:recipient",
        amountUnits: "1",
      },
    },
  ]);
});

test("wraps explorer, wallet, finality, and bridge read methods", async () => {
  const calls: { method: string; params: unknown }[] = [];
  const client = new FlowMemoryClient({
    fetchImpl: (async (_url, init) => {
      const body = JSON.parse(String(init?.body)) as { method: string; params: unknown };
      calls.push({ method: body.method, params: body.params });
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: "ok", result: { schema: body.method } }), { status: 200 });
    }) as typeof fetch,
  });

  await client.blockList({ limit: 2 });
  await client.blockGet({ blockNumber: "1" });
  await client.transactionList({ limit: 2 });
  await client.transactionGet({ txId: "tx:1" });
  await client.accountList({ limit: 2 });
  await client.balanceGet({ accountId: "account:1" });
  await client.walletMetadataList({ limit: 2 });
  await client.faucetEventList({ limit: 2 });
  await client.finalityGet({ objectId: "object:1" });
  await client.bridgeCreditStatus({ creditId: "credit:1" });
  await client.withdrawalList({ limit: 2 });

  assert.deepEqual(calls.map((call) => call.method), [
    "block_list",
    "block_get",
    "transaction_list",
    "transaction_get",
    "account_list",
    "balance_get",
    "wallet_metadata_list",
    "faucet_event_list",
    "finality_get",
    "bridge_credit_status",
    "withdrawal_list",
  ]);
  assert.deepEqual(calls[1]?.params, { blockNumber: "1" });
  assert.deepEqual(calls[5]?.params, { accountId: "account:1" });
  assert.deepEqual(calls[9]?.params, { creditId: "credit:1" });
});

test("wraps base agent memory control-plane methods", async () => {
  const calls: { method: string; params: unknown }[] = [];
  const client = new FlowMemoryClient({
    fetchImpl: (async (_url, init) => {
      const body = JSON.parse(String(init?.body)) as { method: string; params: unknown };
      calls.push({ method: body.method, params: body.params });
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: "ok", result: { schema: body.method } }), { status: 200 });
    }) as typeof fetch,
  });

  await client.baseAgentMemoryScoutList({ limit: 2 });
  await client.baseAgentMemoryScoutGet({ agentId: "agent:fixture" });
  await client.baseAgentMemoryReplayGet({ agentId: "agent:fixture" });

  assert.deepEqual(calls.map((call) => call.method), [
    "base_agent_memory_task_scout_list",
    "base_agent_memory_task_scout_get",
    "base_agent_memory_replay_get",
  ]);
  assert.deepEqual(calls[1]?.params, { agentId: "agent:fixture" });
});

test("wraps public agent network discovery and preview methods", async () => {
  const calls: { method: string; params: unknown }[] = [];
  const client = new FlowMemoryClient({
    fetchImpl: (async (_url, init) => {
      const body = JSON.parse(String(init?.body)) as { method: string; params: unknown };
      calls.push({ method: body.method, params: body.params });
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: "ok", result: { schema: body.method } }), { status: 200 });
    }) as typeof fetch,
  });

  await client.publicAgentNetworkClassesList({ limit: 5 });
  await client.publicAgentNetworkClassGet({ classId: "class:task-scout" });
  await client.publicAgentNetworkToolsList({ limit: 5 });
  await client.publicAgentNetworkToolSetGet({ toolSetRoot: "toolset:task-scout" });
  await client.publicAgentLaunchPreview({ owner: "0x1", classId: "0x2", objectiveText: "goal", profileText: "profile", toolSetRoot: "0x3", autonomyLevel: 2, riskLevel: 1, bondToken: "0x0", bondAmount: "0", fuelToken: "0x0", initialFuelAmount: "0", discoverable: true });

  assert.deepEqual(calls.map((call) => call.method), [
    "public_agent_network_classes_list",
    "public_agent_network_class_get",
    "public_agent_network_tools_list",
    "public_agent_network_tool_set_get",
    "public_agent_launch_preview",
  ]);
});

test("wraps public agent launch intent, discovery, and swarm replay methods", async () => {
  const calls: { method: string; params: unknown }[] = [];
  const client = new FlowMemoryClient({
    fetchImpl: (async (_url, init) => {
      const body = JSON.parse(String(init?.body)) as { method: string; params: unknown };
      calls.push({ method: body.method, params: body.params });
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: "ok", result: { schema: body.method } }), { status: 200 });
    }) as typeof fetch,
  });

  await client.publicAgentLaunchIntentGet({ owner: "0x1", classId: "0x2", objectiveText: "goal", profileText: "profile", toolSetRoot: "0x3", autonomyLevel: 2, riskLevel: 1, bondToken: "0x0", bondAmount: "0", fuelToken: "0x0", initialFuelAmount: "0", discoverable: true, rootfieldId: "0x4", validAfter: "1", validUntil: "2", nonce: "0", salt: "0x5" });
  await client.publicAgentLaunchGet({});
  await client.publicAgentDiscover({ limit: 5 });
  await client.publicSwarmGet({});
  await client.publicSwarmReplayGet({});
  assert.deepEqual(calls.map((call) => call.method), [
    "public_agent_launch_intent_get",
    "public_agent_launch_get",
    "public_agent_discover",
    "public_swarm_get",
    "public_swarm_replay_get",
  ]);
});
test("wraps public swarm discovery and preview methods", async () => {
  const calls: { method: string; params: unknown }[] = [];
  const client = new FlowMemoryClient({
    fetchImpl: (async (_url, init) => {
      const body = JSON.parse(String(init?.body)) as { method: string; params: unknown };
      calls.push({ method: body.method, params: body.params });
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: "ok", result: { schema: body.method } }), { status: 200 });
    }) as typeof fetch,
  });

  await client.publicSwarmClassesList({ limit: 5 });
  await client.publicSwarmClassGet({ swarmClass: "class:research-swarm" });
  await client.publicSwarmLaunchPreview({ creator: "0x1", swarmClass: "0x2", missionText: "mission", profileText: "profile", budgetAsset: "0x3", initialBudget: "10" });
  assert.deepEqual(calls.map((call) => call.method), [
    "public_swarm_classes_list",
    "public_swarm_class_get",
    "public_swarm_launch_preview",
  ]);
});
test("redacts secret-shaped diagnostics", () => {
  const text = redactFlowMemoryText("private_key=abc123 account=0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
  assert.equal(text.includes("abc123"), false);
  assert.equal(text.includes("0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"), true);

  const json = redactJsonValue({
    public: "ok",
    noSecrets: true,
    tokenDefinitions: 1,
    seedPhrase: "word word word",
    nested: { webhook: "https://example.invalid/hook" },
  });
  assert.deepEqual(json, {
    public: "ok",
    noSecrets: true,
    tokenDefinitions: 1,
    seedPhrase: "[REDACTED]",
    nested: { webhook: "[REDACTED]" },
  });
});
