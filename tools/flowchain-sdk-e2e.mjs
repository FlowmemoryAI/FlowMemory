#!/usr/bin/env node
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  assertNoFlowChainSecrets,
  createFlowChainClient,
  createLocalSignedEnvelope,
  findFlowChainSecret,
} from "../packages/flowchain-sdk/src/index.ts";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const agentRunDir = resolve(repoRoot, "docs/agent-runs/live-product-sdk-docs");
const runtimeDir = resolve(repoRoot, "devnet/local/sdk-e2e/runtime");
const runtimeStatePath = resolve(runtimeDir, "state.json");
const runtimeLaunchStatePath = resolve(runtimeDir, "launch-v0-state.json");
const reportPath = resolve(agentRunDir, "flowchain-sdk-e2e-report.json");
const publicRpcEnv = [
  "FLOWCHAIN_RPC_PUBLIC_URL",
  "FLOWCHAIN_RPC_ALLOWED_ORIGINS",
  "FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE",
  "FLOWCHAIN_RPC_TLS_TERMINATED",
  "FLOWCHAIN_RPC_STATE_BACKUP_PATH",
];
const baseBridgeEnv = [
  "FLOWCHAIN_PILOT_OPERATOR_ACK",
  "FLOWCHAIN_BASE8453_RPC_URL",
  "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
  "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
  "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
  "FLOWCHAIN_BASE8453_FROM_BLOCK",
  "FLOWCHAIN_BASE8453_TO_BLOCK",
  "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
  "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
  "FLOWCHAIN_PILOT_CONFIRMATIONS",
];

function saveAndClearEnv(names) {
  const saved = new Map();
  for (const name of names) {
    saved.set(name, process.env[name]);
    delete process.env[name];
  }
  return () => {
    for (const [name, value] of saved) {
      if (value === undefined) {
        delete process.env[name];
      } else {
        process.env[name] = value;
      }
    }
  };
}

async function runCommand(command, args, label, options = {}) {
  return await new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, {
      cwd: repoRoot,
      windowsHide: true,
      env: { ...process.env, ...(options.env ?? {}) },
      shell: false,
    });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", reject);
    child.on("close", (status) => {
      const summary = {
        label,
        command: [command, ...args].join(" "),
        status,
        stdout: stdout.trim(),
        stderr: stderr.trim(),
      };
      if (status !== 0 && options.allowFailure !== true) {
        reject(new Error(`${label} failed: ${summary.stderr || summary.stdout}`));
        return;
      }
      resolvePromise(summary);
    });
  });
}

function parseJsonOutput(summary) {
  const text = summary.stdout.trim();
  const first = text.indexOf("{");
  const last = text.lastIndexOf("}");
  if (first < 0 || last < first) {
    throw new Error(`${summary.label} did not print JSON`);
  }
  return JSON.parse(text.slice(first, last + 1));
}

async function readBody(req) {
  return await new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("error", reject);
    req.on("end", () => resolve(body));
  });
}

async function startRpcServer() {
  const { dispatchJsonRpc } = await import("../services/control-plane/src/json-rpc.ts");
  const { loadControlPlaneState } = await import("../services/control-plane/src/fixture-state.ts");
  const jsonHeaders = {
    "access-control-allow-headers": "content-type",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-origin": "*",
    "content-type": "application/json",
  };
  const server = createServer((req, res) => {
    const state = loadControlPlaneState();
    const write = (statusCode, body) => {
      res.writeHead(statusCode, jsonHeaders);
      res.end(`${JSON.stringify(body)}\n`);
    };
    if (req.method === "OPTIONS") {
      res.writeHead(204, jsonHeaders);
      res.end();
      return;
    }
    if (req.method === "GET" && req.url === "/rpc/discover") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "discover", method: "rpc_discover" }, { state });
      write(200, response?.result ?? response);
      return;
    }
    if (req.method === "GET" && req.url === "/rpc/readiness") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "readiness", method: "rpc_readiness" }, { state });
      write(200, response?.result ?? response);
      return;
    }
    if (req.method !== "POST" || req.url !== "/rpc") {
      write(404, { error: "not found" });
      return;
    }
    readBody(req).then((body) => {
      try {
        write(200, dispatchJsonRpc(JSON.parse(body), { state }));
      } catch (error) {
        write(400, {
          jsonrpc: "2.0",
          id: null,
          error: {
            code: -32700,
            message: error instanceof Error ? error.message : "parse error",
            data: { reasonCode: "parse.error", localOnly: true },
          },
        });
      }
    }).catch((error) => {
      write(400, { error: error instanceof Error ? error.message : "request read error" });
    });
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  assert.equal(typeof address, "object");
  assert.notEqual(address, null);
  return {
    server,
    rpcUrl: `http://127.0.0.1:${address.port}/rpc`,
  };
}

function queuedTxId(receipt) {
  const queued = receipt.runtimeSubmission?.queued;
  if (!Array.isArray(queued) || typeof queued[0] !== "string") {
    throw new Error("runtime submission did not return a queued tx id");
  }
  return queued[0];
}

function scanTextFile(path) {
  const text = readFileSync(path, "utf8");
  const finding = findFlowChainSecret(text);
  if (finding !== null) {
    throw new Error(`secret-shaped material in ${path}: ${finding.reasonCode}`);
  }
}

function verifyDocsAndExamples(discovery) {
  const requiredFiles = [
    "docs/developer/quickstart.md",
    "docs/developer/wallet-integration.md",
    "docs/developer/bridge-integration.md",
    "docs/developer/node-operator.md",
    "docs/developer/app-builder.md",
    "docs/developer/troubleshooting.md",
    "docs/sdk/README.md",
    "docs/sdk/release-versioning.md",
    "docs/sdk/rpc-reference.md",
    "docs/sdk/rpc-reference.json",
    "examples/flowchain-node-local/index.mjs",
    "examples/flowchain-browser-vite/index.html",
    "examples/flowchain-browser-vite/src/main.js",
    "examples/flowchain-bridge-readiness/index.mjs",
    "examples/flowchain-wallet-send/index.mjs",
  ];
  for (const relativePath of requiredFiles) {
    scanTextFile(resolve(repoRoot, relativePath));
  }
  const quickstart = readFileSync(resolve(repoRoot, "docs/developer/quickstart.md"), "utf8");
  for (const snippet of [
    "node tools/flowchain-devkit.mjs discover --json",
    "node examples/flowchain-node-local/index.mjs",
    "npm run flowchain:sdk:e2e",
  ]) {
    assert.ok(quickstart.includes(snippet), `quickstart missing snippet: ${snippet}`);
  }
  const reference = JSON.parse(readFileSync(resolve(repoRoot, "docs/sdk/rpc-reference.json"), "utf8"));
  assert.equal(reference.generatedFrom, "rpc_discover");
  assert.equal(reference.methodCount, discovery.methodCount);
  assert.equal(reference.compatibility.evmJsonRpcCompatible, false);
}

mkdirSync(agentRunDir, { recursive: true });
rmSync(runtimeDir, { recursive: true, force: true });
mkdirSync(runtimeDir, { recursive: true });
const restoreEnv = saveAndClearEnv([...publicRpcEnv, ...baseBridgeEnv]);
process.env.FLOWCHAIN_CONTROL_PLANE_LOCAL_DEVNET_PATH = runtimeStatePath;
process.env.FLOWCHAIN_CONTROL_PLANE_LOCAL_DEVNET_LAUNCH_PATH = runtimeLaunchStatePath;

let server;
try {
  const commands = [];
  commands.push(await runCommand("cargo", [
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    runtimeStatePath,
    "init",
  ], "runtime init"));

  const started = await startRpcServer();
  server = started.server;
  const client = createFlowChainClient({ rpcUrl: started.rpcUrl });

  const discovery = await client.discover();
  assert.equal(discovery.schema, "flowchain.rpc.discovery.v0");
  assert.equal(discovery.compatibility?.evmJsonRpcCompatible, false);
  const readiness = await client.readiness();
  assert.equal(readiness.envValuesPrinted, false);
  assert.ok(readiness.missingProductionEnvNames?.includes("FLOWCHAIN_RPC_PUBLIC_URL"));
  const bridgeReadiness = await client.bridgeReadiness();
  assert.equal(bridgeReadiness.envValuesPrinted, false);
  assert.ok(bridgeReadiness.missingEnvNames?.includes("FLOWCHAIN_BASE8453_RPC_URL"));

  commands.push(await runCommand("node", [
    "tools/flowchain-rpc-reference.mjs",
    "--rpc-url",
    started.rpcUrl,
    "--timeout-ms",
    "60000",
    "--check",
  ], "rpc reference check"));

  const sourceAccount = "local-account:sdk-e2e:source";
  const destinationAccount = "local-account:sdk-e2e:destination";
  const submittedBy = "operator:flowchain-sdk-e2e";
  await client.submitSignedTransaction(createLocalSignedEnvelope({
    type: "CreateLocalTestUnitBalance",
    accountId: sourceAccount,
    owner: submittedBy,
  }, submittedBy), { runtimeSubmit: true, submittedBy });
  await client.submitSignedTransaction(createLocalSignedEnvelope({
    type: "CreateLocalTestUnitBalance",
    accountId: destinationAccount,
    owner: submittedBy,
  }, submittedBy), { runtimeSubmit: true, submittedBy });
  await client.submitSignedTransaction(createLocalSignedEnvelope({
    type: "FaucetLocalTestUnits",
    faucetRecordId: "faucet:sdk-e2e:source",
    accountId: sourceAccount,
    recipient: submittedBy,
    amountUnits: 100,
    reason: "flowchain-sdk-e2e",
  }, submittedBy), { runtimeSubmit: true, submittedBy });
  const transferReceipt = await client.submitSignedTransaction(createLocalSignedEnvelope({
    type: "TransferLocalTestUnits",
    transferId: "transfer:sdk-e2e:source-to-destination",
    fromAccountId: sourceAccount,
    toAccountId: destinationAccount,
    amountUnits: 7,
    memo: "flowchain-sdk-e2e",
  }, submittedBy), { runtimeSubmit: true, submittedBy });
  const transferTxId = queuedTxId(transferReceipt);

  const mempool = await client.mempoolList({ limit: 100 });
  assert.ok((mempool.transactions ?? []).some((row) => row.transactionId === transferTxId));

  commands.push(await runCommand("cargo", [
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    runtimeStatePath,
    "run",
    "--blocks",
    "1",
  ], "produce block"));

  const blocks = await client.blockList({ source: "local-devnet", includeTransactions: true, limit: 10 });
  const producedBlock = blocks.blocks.find((block) => Array.isArray(block.txIds) && block.txIds.includes(transferTxId));
  assert.ok(producedBlock, "block_list should include SDK transfer tx");
  const block = await client.blockGet({ blockHash: producedBlock.blockHash, includeTransactions: true });
  const transaction = await client.transactionGet({ txId: transferTxId });
  const account = await client.accountGet(destinationAccount);
  const balance = await client.balanceGet(destinationAccount);
  const finality = await client.finalityGet({ objectId: transferTxId });
  const provenance = await client.provenanceGet({ objectId: transferTxId });
  assert.equal(transaction.transaction.status, "applied");
  assert.equal(balance.amount, "7");
  assert.equal(account.account.accountId, destinationAccount);
  assert.equal(finality.schema, "flowmemory.control_plane.finality.v0");
  assert.equal(provenance.objectId, transferTxId);

  const cliDiscover = await runCommand("node", [
    "tools/flowchain-devkit.mjs",
    "discover",
    "--rpc-url",
    started.rpcUrl,
    "--json",
  ], "devkit discover --json");
  commands.push(cliDiscover);
  const cliJson = parseJsonOutput(cliDiscover);
  assert.equal(cliJson.schema, "flowchain.rpc.discovery.v0");

  const bridgeExample = await runCommand("node", [
    "examples/flowchain-bridge-readiness/index.mjs",
    "--rpc-url",
    started.rpcUrl,
  ], "bridge readiness example");
  commands.push(bridgeExample);
  const bridgeExampleJson = parseJsonOutput(bridgeExample);
  assert.equal(bridgeExampleJson.status, "blocked");

  const nodeExample = await runCommand("node", [
    "examples/flowchain-node-local/index.mjs",
    "--rpc-url",
    started.rpcUrl,
    "--state",
    runtimeStatePath,
  ], "node local example");
  commands.push(nodeExample);
  const nodeExampleJson = parseJsonOutput(nodeExample);
  assert.equal(nodeExampleJson.status, "passed");

  verifyDocsAndExamples(discovery);

  const report = {
    schema: "flowchain.sdk_e2e_report.v0",
    status: "passed",
    generatedAt: new Date().toISOString(),
    endpointHost: "127.0.0.1",
    runtimeStatePath,
    discovery: {
      methodCount: discovery.methodCount,
      evmJsonRpcCompatible: discovery.compatibility?.evmJsonRpcCompatible,
      flowchainJsonRpcCompatible: discovery.compatibility?.flowchainJsonRpcCompatible,
    },
    readiness: {
      status: readiness.status,
      publicRpcReady: readiness.publicRpcReady,
      missingProductionEnvNames: readiness.missingProductionEnvNames,
      envValuesPrinted: readiness.envValuesPrinted,
    },
    bridgeReadiness: {
      failClosedStatus: bridgeReadiness.failClosedStatus,
      readyForOperatorLivePilot: bridgeReadiness.readyForOperatorLivePilot,
      missingEnvNames: bridgeReadiness.missingEnvNames,
      envValuesPrinted: bridgeReadiness.envValuesPrinted,
    },
    transaction: {
      txId: transferTxId,
      status: transaction.transaction.status,
      destinationBalance: balance.amount,
      blockHash: producedBlock.blockHash,
      blockNumber: producedBlock.blockNumber,
    },
    checks: {
      sdkUnitTests: "run separately by npm test --prefix packages/flowchain-sdk",
      rpcReferenceMatched: true,
      mempoolVisibleBeforeBlock: true,
      blockRead: block.schema === "flowmemory.control_plane.block_detail.v0",
      transactionRead: true,
      accountRead: true,
      balanceRead: true,
      finalityRead: true,
      provenanceRead: true,
      cliJson: true,
      exampleCommand: true,
      docsSnippetsChecked: true,
      noSecrets: true,
    },
    commands: commands.map((command) => ({
      label: command.label,
      status: command.status,
      stdoutLength: command.stdout.length,
      stderrLength: command.stderr.length,
    })),
    reportPath,
    localOnly: true,
    productionReady: false,
  };
  assertNoFlowChainSecrets(report);
  writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));
} finally {
  if (server) {
    await new Promise((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
  }
  restoreEnv();
}
