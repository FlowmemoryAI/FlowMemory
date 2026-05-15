import assert from "node:assert/strict";
import test from "node:test";

import {
  FlowChainAccountNotFoundError,
  FlowChainBridgeNotReadyError,
  FlowChainMalformedEnvelopeError,
  FlowChainMissingLiveConfigError,
  FlowChainRpcMethodUnavailableError,
  FlowChainRpcUnreachableError,
  FlowChainUnsignedEnvelopeError,
  assertNoFlowChainSecrets,
  createFlowChainClient,
  createLocalSignedEnvelope,
  findFlowChainSecret,
  redactFlowChainSecrets,
  validateSignedEnvelope,
} from "../src/index.ts";
import type { FlowChainRpcRequest, JsonObject } from "../src/index.ts";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function rpcFetch(handler: (request: FlowChainRpcRequest, url: string) => unknown): typeof fetch {
  return (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (init?.method === "GET") {
      if (url.endsWith("/rpc/discover")) {
        return jsonResponse({ schema: "flowchain.rpc.discovery.v0", methods: [] });
      }
      if (url.endsWith("/rpc/readiness")) {
        return jsonResponse({ schema: "flowchain.rpc.readiness.v0", publicRpcReady: false, missingProductionEnvNames: ["FLOWCHAIN_RPC_PUBLIC_URL"] });
      }
    }
    const request = JSON.parse(String(init?.body ?? "{}")) as FlowChainRpcRequest;
    const result = handler(request, url);
    return jsonResponse(result);
  }) as typeof fetch;
}

test("calls FlowChain-native JSON-RPC methods and browser-safe mirrors", async () => {
  const client = createFlowChainClient({
    fetch: rpcFetch((request) => ({
      jsonrpc: "2.0",
      id: request.id,
      result: {
        schema: request.method === "rpc_discover" ? "flowchain.rpc.discovery.v0" : "flowmemory.control_plane.chain_status.v0",
        method: request.method,
      },
    })),
  });

  const discovery = await client.discover();
  const chainStatus = await client.chainStatus();
  const httpDiscovery = await client.discoverHttp();

  assert.equal(discovery.schema, "flowchain.rpc.discovery.v0");
  assert.equal(chainStatus.method, "chain_status");
  assert.equal(httpDiscovery.schema, "flowchain.rpc.discovery.v0");
});

test("maps stable RPC errors to tagged SDK errors", async () => {
  const methodClient = createFlowChainClient({
    fetch: rpcFetch((request) => ({
      jsonrpc: "2.0",
      id: request.id,
      error: {
        code: -32601,
        message: "control-plane method not found",
        data: { reasonCode: "method.not_found" },
      },
    })),
  });
  await assert.rejects(methodClient.rpc("flow_sendTransaction"), FlowChainRpcMethodUnavailableError);

  const accountClient = createFlowChainClient({
    fetch: rpcFetch((request) => ({
      jsonrpc: "2.0",
      id: request.id,
      error: {
        code: -32004,
        message: "account not found",
        data: { reasonCode: "object.not_found" },
      },
    })),
  });
  await assert.rejects(accountClient.accountGet("account:missing"), FlowChainAccountNotFoundError);
});

test("reports unreachable RPC without leaking request bodies", async () => {
  const client = createFlowChainClient({
    rpcUrl: "http://127.0.0.1:1/rpc",
    fetch: (async () => {
      throw new Error("connection refused");
    }) as typeof fetch,
  });

  await assert.rejects(client.chainStatus(), FlowChainRpcUnreachableError);
});

test("validates signed envelopes before submitting writes", async () => {
  assert.throws(() => validateSignedEnvelope(null), FlowChainMalformedEnvelopeError);
  assert.throws(() => validateSignedEnvelope({ schema: "x", tx: {} }), FlowChainUnsignedEnvelopeError);

  const envelope = createLocalSignedEnvelope({
    type: "TransferLocalTestUnits",
    transferId: "transfer:sdk-test",
    fromAccountId: "local-account:a",
    toAccountId: "local-account:b",
    amountUnits: 1,
    memo: "sdk-test",
  });
  assert.equal(envelope.schema, "flowchain.local_transaction_envelope.v0");
});

test("submits signed envelopes only through transaction_submit", async () => {
  const seen: JsonObject[] = [];
  const client = createFlowChainClient({
    fetch: rpcFetch((request) => {
      seen.push(request as unknown as JsonObject);
      return {
        jsonrpc: "2.0",
        id: request.id,
        result: {
          schema: "flowmemory.control_plane.transaction_submit_result.v0",
          accepted: true,
          txId: "tx:sdk-unit",
          forwardedTo: "local-runtime-state",
        },
      };
    }),
  });

  const receipt = await client.submitSignedTransaction(createLocalSignedEnvelope({
    type: "CreateLocalTestUnitBalance",
    accountId: "local-account:sdk-unit",
    owner: "operator:sdk-unit",
  }), { runtimeSubmit: true, submittedBy: "operator:sdk-unit" });

  assert.equal(receipt.accepted, true);
  assert.equal(seen[0].method, "transaction_submit");
  assert.equal(((seen[0].params as JsonObject).runtimeSubmit), true);
});

test("redacts and rejects secret-shaped output", () => {
  const value = {
    rpcCredential: "https://user:pass@example.invalid",
    nested: {
      note: `private key: 0x${"1".repeat(64)}`,
    },
  };

  assert.equal(findFlowChainSecret(value)?.reasonCode, "secret.key_name");
  assert.throws(() => assertNoFlowChainSecrets(value), /secret-shaped material/);
  const redacted = redactFlowChainSecrets(value) as JsonObject;
  assert.equal(redacted.rpcCredential, "[REDACTED]");
  assert.equal((redacted.nested as JsonObject).note, "[REDACTED]");
});

test("fails closed for missing public RPC and bridge readiness", async () => {
  const client = createFlowChainClient({
    fetch: rpcFetch((request) => ({
      jsonrpc: "2.0",
      id: request.id,
      result: request.method === "bridge_live_readiness"
        ? {
            schema: "flowmemory.control_plane.bridge_live_readiness.v0",
            failClosedStatus: "BLOCKED",
            readyForOperatorLivePilot: false,
            missingEnvNames: ["FLOWCHAIN_BASE8453_RPC_URL"],
            envValuesPrinted: false,
          }
        : {
            schema: "flowchain.rpc.readiness.v0",
            publicRpcReady: false,
            missingProductionEnvNames: ["FLOWCHAIN_RPC_PUBLIC_URL"],
            envValuesPrinted: false,
          },
    })),
  });

  await assert.rejects(client.assertPublicRpcReady(), FlowChainMissingLiveConfigError);
  await assert.rejects(client.assertBridgeReady(), FlowChainBridgeNotReadyError);
});
