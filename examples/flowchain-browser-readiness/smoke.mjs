import assert from "node:assert/strict";

import {
  checkFlowChainBrowserReadiness,
  normalizeFlowChainOrigin,
  redactFlowChainBrowserText,
} from "./browser-readiness.js";

const calls = [];

async function fetchMock(url) {
  const parsed = new URL(url);
  calls.push(parsed.pathname);
  if (parsed.pathname === "/rpc/discover") {
    return Response.json({
      schema: "flowchain.rpc.discovery.v0",
      methodCount: 82,
      publicReadyMethodCount: 0,
    });
  }
  if (parsed.pathname === "/rpc/readiness") {
    return Response.json({
      schema: "flowchain.rpc.readiness.v0",
      publicRpcReady: false,
      productionReady: false,
      publicReadyMethodCount: 0,
      missingProductionEnvNames: [
        "FLOWCHAIN_RPC_PUBLIC_URL",
        "FLOWCHAIN_RPC_TLS_TERMINATED",
        "FLOWCHAIN_BASE8453_RPC_URL",
      ],
    });
  }
  return Response.json({ schema: "unexpected" }, { status: 404 });
}

const summary = await checkFlowChainBrowserReadiness({
  origin: "http://user:password@127.0.0.1:8787/",
  fetchImpl: fetchMock,
});

assert.equal(normalizeFlowChainOrigin("http://127.0.0.1:8787/"), "http://127.0.0.1:8787");
assert.equal(summary.schema, "flowchain.example.browser_readiness.v1");
assert.deepEqual(calls, ["/rpc/discover", "/rpc/readiness"]);
assert.equal(summary.methodCount, 82);
assert.equal(summary.publicReadyMethodCount, 0);
assert.equal(summary.publicRpcReady, false);
assert.equal(summary.productionReady, false);
assert.equal(summary.safeToSharePublicly, false);
assert.ok(summary.missingProductionEnvNames.includes("FLOWCHAIN_RPC_PUBLIC_URL"));
assert.equal(summary.rpcOrigin.includes("password"), false);
assert.equal(redactFlowChainBrowserText("https://example.invalid/rpc?token=secret").includes("secret"), false);

const serialized = JSON.stringify(summary);
assert.equal(/privateKey|private_key|seed phrase|mnemonic|apiKey|webhook|bearer|password|passphrase/i.test(serialized), false);

console.log(JSON.stringify({
  schema: "flowchain.example.browser_readiness_smoke.v0",
  status: "passed",
  endpointCalls: calls,
  safeToSharePublicly: summary.safeToSharePublicly,
  noSecrets: true,
}, null, 2));
