import assert from "node:assert/strict";
import test from "node:test";

import { FlowChainClient, FlowChainRpcError } from "../src/client.ts";
import { redactFlowChainText, redactJsonValue } from "../src/redact.ts";

test("calls JSON-RPC with stable envelope shape", async () => {
  const calls: unknown[] = [];
  const client = new FlowChainClient({
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
      id: "flowchain-sdk:health",
      method: "health",
      params: {},
    },
  ]);
});

test("turns JSON-RPC errors into tagged FlowChain errors", async () => {
  const client = new FlowChainClient({
    fetchImpl: (async () => {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: "fail",
        error: { code: -32601, message: "method.not_found" },
      }), { status: 200 });
    }) as typeof fetch,
  });
  await assert.rejects(() => client.call("missing"), (error) => {
    assert.ok(error instanceof FlowChainRpcError);
    assert.equal(error.code, -32601);
    assert.equal(error.message, "method.not_found");
    return true;
  });
});

test("submits wallet send through control-plane HTTP path", async () => {
  const calls: { url: string; body: unknown }[] = [];
  const client = new FlowChainClient({
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

test("submits signed envelopes through transaction_submit", async () => {
  const calls: { url: string; body: unknown }[] = [];
  const client = new FlowChainClient({
    rpcUrl: "http://127.0.0.1:8787/rpc",
    fetchImpl: (async (url, init) => {
      calls.push({ url: String(url), body: JSON.parse(String(init?.body)) });
      return new Response(JSON.stringify({
        schema: "flowmemory.control_plane.transaction_submit_result.v0",
        accepted: true,
      }), { status: 200 });
    }) as typeof fetch,
  });
  const signedEnvelope = {
    document: { schema: "flowchain.product_transfer.v0" },
    envelope: { schema: "flowchain.local_transaction_envelope.v0" },
  };

  const result = await client.submitSignedEnvelope(signedEnvelope, {
    submittedBy: "sdk-test",
    runtimeSubmitMode: "off",
  }) as Record<string, unknown>;

  assert.equal(result.accepted, true);
  assert.deepEqual(calls, [
    {
      url: "http://127.0.0.1:8787/transactions/submit",
      body: {
        signedEnvelope,
        submittedBy: "sdk-test",
        runtimeSubmitMode: "off",
      },
    },
  ]);
});

test("waits for transaction inclusion through transaction_get", async () => {
  const calls: unknown[] = [];
  let attempts = 0;
  const client = new FlowChainClient({
    fetchImpl: (async (_url, init) => {
      attempts += 1;
      const body = JSON.parse(String(init?.body));
      calls.push(body);
      if (attempts === 1) {
        return new Response(JSON.stringify({
          jsonrpc: "2.0",
          id: "wait",
          error: { code: -32004, message: "transaction not found: tx:wait" },
        }), { status: 200 });
      }
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: "wait",
        result: {
          schema: "flowmemory.control_plane.transaction_detail.v0",
          transaction: { transactionId: "tx:wait", status: "applied" },
        },
      }), { status: 200 });
    }) as typeof fetch,
  });

  const result = await client.waitForTransaction({ txId: "tx:wait", timeoutMs: 1000, pollMs: 1 }) as Record<string, unknown>;
  assert.equal(result.schema, "flowchain.sdk.wait_transaction.v0");
  assert.equal(result.status, "included");
  assert.equal(result.attempts, 2);
  assert.deepEqual(calls.map((call) => (call as { method?: string }).method), ["transaction_get", "transaction_get"]);
});

test("wraps explorer, wallet, finality, and bridge read methods", async () => {
  const calls: { method: string; params: unknown }[] = [];
  const client = new FlowChainClient({
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

test("redacts secret-shaped diagnostics", () => {
  const text = redactFlowChainText("private_key=abc123 account=0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
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
