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
