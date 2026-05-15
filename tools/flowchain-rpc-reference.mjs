#!/usr/bin/env node
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";

import {
  DEFAULT_FLOWCHAIN_RPC_URL,
  assertNoFlowChainSecrets,
  createFlowChainClient,
} from "../packages/flowchain-sdk/src/index.ts";

const args = new Set(process.argv.slice(2));
const rpcUrl = valueArg("--rpc-url") ?? process.env.FLOWCHAIN_RPC_URL ?? DEFAULT_FLOWCHAIN_RPC_URL;
const jsonPath = resolve(valueArg("--json-out") ?? "docs/sdk/rpc-reference.json");
const markdownPath = resolve(valueArg("--markdown-out") ?? "docs/sdk/rpc-reference.md");
const timeoutMs = Number(valueArg("--timeout-ms") ?? 60000);
const mode = args.has("--write") ? "write" : args.has("--check") ? "check" : "print";

function valueArg(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function stableString(value) {
  if (Array.isArray(value)) {
    return `[${value.map(stableString).join(",")}]`;
  }
  if (value !== null && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableString(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function normalizeDiscovery(discovery) {
  const methods = [...(discovery.methods ?? [])]
    .map((method) => ({
      method: method.method,
      category: method.category,
      mode: method.mode,
      stable: method.stable,
      localOnly: method.localOnly,
      productionReady: method.productionReady,
    }))
    .sort((left, right) => String(left.method).localeCompare(String(right.method)));
  return {
    schema: "flowchain.sdk.rpc_reference.v0",
    generatedFrom: "rpc_discover",
    service: discovery.service,
    protocol: discovery.protocol,
    rpcPath: discovery.rpcPath,
    chainId: discovery.chainId,
    methodCount: methods.length,
    compatibility: discovery.compatibility,
    methods,
    localOnly: discovery.localOnly,
    productionReady: discovery.productionReady,
  };
}

function markdown(reference) {
  const rows = reference.methods.map((method) =>
    `| \`${method.method}\` | ${method.category} | ${method.mode} | ${method.localOnly} | ${method.productionReady} |`,
  );
  return [
    "# FlowChain RPC Reference",
    "",
    "This file is generated from `rpc_discover` by `node tools/flowchain-rpc-reference.mjs --write`.",
    "Do not edit the method table by hand.",
    "",
    `- Service: \`${reference.service}\``,
    `- Protocol: \`${reference.protocol}\``,
    `- RPC path: \`${reference.rpcPath}\``,
    `- Method count: \`${reference.methodCount}\``,
    `- EVM JSON-RPC compatible: \`${reference.compatibility?.evmJsonRpcCompatible === true}\``,
    `- FlowChain-native JSON-RPC compatible: \`${reference.compatibility?.flowchainJsonRpcCompatible === true}\``,
    `- Production ready: \`${reference.productionReady === true}\``,
    "",
    "| Method | Category | Mode | Local only | Production ready |",
    "| --- | --- | --- | --- | --- |",
    ...rows,
    "",
  ].join("\n");
}

async function loadDiscovery() {
  if (args.has("--in-process")) {
    const { dispatchJsonRpc } = await import("../services/control-plane/src/json-rpc.ts");
    const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "rpc-reference", method: "rpc_discover" });
    if (!response || Array.isArray(response) || !("result" in response)) {
      throw new Error("in-process rpc_discover did not return a result");
    }
    return response.result;
  }
  const client = createFlowChainClient({ rpcUrl, requestTimeoutMs: timeoutMs });
  return await client.discover();
}

const reference = normalizeDiscovery(await loadDiscovery());
assertNoFlowChainSecrets(reference);
const jsonBody = `${JSON.stringify(reference, null, 2)}\n`;
const markdownBody = markdown(reference);

if (mode === "write") {
  mkdirSync(dirname(jsonPath), { recursive: true });
  writeFileSync(jsonPath, jsonBody);
  writeFileSync(markdownPath, markdownBody);
  console.log(JSON.stringify({
    schema: "flowchain.sdk.rpc_reference_update.v0",
    status: "written",
    jsonPath,
    markdownPath,
    methodCount: reference.methodCount,
  }, null, 2));
} else if (mode === "check") {
  const currentJson = readFileSync(jsonPath, "utf8");
  const currentMarkdown = readFileSync(markdownPath, "utf8");
  const status = currentJson === jsonBody && currentMarkdown === markdownBody ? "matched" : "drifted";
  if (status !== "matched") {
    console.log(JSON.stringify({
      schema: "flowchain.sdk.rpc_reference_check.v0",
      status,
      jsonPath,
      markdownPath,
      expectedDigest: stableString(reference).length,
    }, null, 2));
    process.exitCode = 1;
  } else {
    console.log(JSON.stringify({
      schema: "flowchain.sdk.rpc_reference_check.v0",
      status,
      jsonPath,
      markdownPath,
      methodCount: reference.methodCount,
    }, null, 2));
  }
} else {
  console.log(JSON.stringify(reference, null, 2));
}
