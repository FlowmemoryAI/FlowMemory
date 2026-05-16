import assert from "node:assert/strict";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { findSecret } from "../../shared/src/index.ts";
import { spawnCargoSync } from "./cargo.ts";
import { dispatchJsonRpc } from "./json-rpc.ts";
import { runControlPlaneSmoke } from "./smoke.ts";
import type { JsonObject, JsonValue, RpcSuccessResponse } from "./types.ts";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const outDir = resolve(repoRoot, "devnet/local/rpc-e2e");
const runtimeDir = resolve(outDir, "runtime");
const runtimeStatePath = resolve(runtimeDir, "state.json");
const txIntakePath = resolve(runtimeDir, "intake", "transactions.ndjson");
const bridgeObservationIntakePath = resolve(runtimeDir, "intake", "bridge-observations.ndjson");
const localDevnetLaunchPath = resolve(runtimeDir, "launch-v0-state.json");
mkdirSync(outDir, { recursive: true });
rmSync(runtimeDir, { recursive: true, force: true });
mkdirSync(runtimeDir, { recursive: true });

const runtimePaths = {
  localDevnetPath: runtimeStatePath,
  localDevnetLaunchPath,
  txIntakePath,
  bridgeObservationIntakePath,
};

function runCargoJson(args: string[], label: string): JsonObject {
  const result = spawnCargoSync(args, {
    cwd: repoRoot,
    encoding: "utf8",
    windowsHide: true,
  });
  if (result.error !== undefined) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`${label} failed: ${result.stderr || result.stdout}`);
  }
  try {
    return JSON.parse(result.stdout) as JsonObject;
  } catch {
    // Bounded node mode prints one compact JSON object per block plus a final status.
  }
  const jsonLine = result.stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.startsWith("{") && line.endsWith("}"))
    .at(-1);
  if (jsonLine === undefined) {
    throw new Error(`${label} did not print a JSON object`);
  }
  return JSON.parse(jsonLine) as JsonObject;
}

function rpc(method: string, params: JsonObject = {}): JsonObject {
  const response = dispatchJsonRpc(
    { jsonrpc: "2.0", id: method, method, params },
    { paths: runtimePaths },
  ) as RpcSuccessResponse;
  assert.equal(response.jsonrpc, "2.0");
  assert.equal(response.id, method);
  assert.ok("result" in response, `${method} should return a result`);
  return response.result as JsonObject;
}

function signedEnvelope(tx: JsonObject, signer: string): JsonObject {
  return {
    schema: "flowchain.rpc_e2e.signed_envelope.v0",
    tx,
    signature: {
      scheme: "local-e2e-placeholder",
      signer,
      digest: "local-e2e-digest",
    },
  };
}

const smoke = runControlPlaneSmoke({
  txIntakePath: resolve(outDir, "transactions.ndjson"),
  bridgeObservationIntakePath: resolve(outDir, "bridge-observations.ndjson"),
});

const discovery = dispatchJsonRpc({ jsonrpc: "2.0", id: "discover", method: "rpc_discover" }) as RpcSuccessResponse;
const readiness = dispatchJsonRpc({ jsonrpc: "2.0", id: "readiness", method: "rpc_readiness" }) as RpcSuccessResponse;

assert.equal((discovery.result as JsonObject).schema, "flowchain.rpc.discovery.v0");
assert.equal((readiness.result as JsonObject).schema, "flowchain.rpc.readiness.v0");
assert.equal((readiness.result as JsonObject).envValuesPrinted, false);

const methods = ((discovery.result as JsonObject).methods as JsonObject[]).map((entry) => String(entry.method));
for (const requiredMethod of [
  "rpc_discover",
  "rpc_readiness",
  "health",
  "node_status",
  "chain_status",
  "block_list",
  "block_get",
  "transaction_submit",
  "mempool_list",
  "account_get",
  "balance_get",
  "wallet_balance_list",
  "bridge_live_readiness",
  "bridge_credit_status",
]) {
  assert.ok(methods.includes(requiredMethod), `rpc discovery is missing ${requiredMethod}`);
}

runCargoJson([
  "run",
  "--manifest-path",
  "crates/flowmemory-devnet/Cargo.toml",
  "--",
  "--state",
  runtimeStatePath,
  "init",
], "runtime init");

const accountId = "local-account:rpc-e2e:primary";
const createAccount = rpc("transaction_submit", {
  signedEnvelope: signedEnvelope({
    type: "CreateLocalTestUnitBalance",
    accountId,
    owner: "operator:rpc-e2e",
  }, "operator:rpc-e2e"),
  submittedBy: "operator:rpc-e2e",
  runtimeSubmit: true,
});
const faucet = rpc("transaction_submit", {
  signedEnvelope: signedEnvelope({
    type: "FaucetLocalTestUnits",
    faucetRecordId: "faucet:rpc-e2e:primary",
    accountId,
    recipient: "operator:rpc-e2e",
    amountUnits: 77,
    reason: "rpc-e2e-runtime-submit",
  }, "operator:rpc-e2e"),
  submittedBy: "operator:rpc-e2e",
  runtimeSubmit: true,
});

const createQueued = ((createAccount.runtimeSubmission as JsonObject).queued as JsonValue[]).map(String);
const faucetQueued = ((faucet.runtimeSubmission as JsonObject).queued as JsonValue[]).map(String);
assert.equal(createAccount.forwardedTo, "local-runtime-state");
assert.equal(faucet.forwardedTo, "local-runtime-state");
assert.equal(createQueued.length, 1);
assert.equal(faucetQueued.length, 1);

const mempoolBeforeBlock = rpc("mempool_list", { limit: 25 });
assert.ok(Number(mempoolBeforeBlock.count) >= 2, "runtime-submitted txs should be visible before block production");

const firstBlockRun = runCargoJson([
  "run",
  "--manifest-path",
  "crates/flowmemory-devnet/Cargo.toml",
  "--",
  "--state",
  runtimeStatePath,
  "run",
  "--blocks",
  "1",
], "produce block");
assert.equal(firstBlockRun.blocksProduced, 1);

const localBlocks = (rpc("block_list", { source: "local-devnet", includeTransactions: true, limit: 10 }).blocks as JsonObject[]);
const producedBlock = localBlocks.find((block) => {
  const txIds = Array.isArray(block.txIds) ? block.txIds.map(String) : [];
  return faucetQueued.every((txId) => txIds.includes(txId));
});
assert.ok(producedBlock, "block_list should expose the runtime-produced block with the RPC-submitted tx");

const blockDetail = rpc("block_get", {
  blockHash: String(producedBlock.blockHash),
  includeTransactions: true,
});
const block = blockDetail.block as JsonObject;
assert.ok(Array.isArray(block.receipts));
assert.ok((block.receipts as JsonObject[]).some((receipt) => receipt.txId === faucetQueued[0] && receipt.status === "applied"));

const transactionDetail = rpc("transaction_get", { txId: faucetQueued[0] });
assert.equal((transactionDetail.transaction as JsonObject).status, "applied");

const account = rpc("account_get", { accountId });
assert.equal((account.account as JsonObject).accountId, accountId);
assert.equal(((account.balance as JsonObject).amount), "77");

const balance = rpc("balance_get", { accountId });
assert.equal(balance.amount, "77");

const tokenBalance = rpc("token_balance_get", { accountId, tokenId: "local-test-unit" });
assert.equal((tokenBalance.balance as JsonObject).amount, "77");

const provenance = rpc("provenance_get", { objectId: faucetQueued[0] });
assert.equal(provenance.objectId, faucetQueued[0]);

runCargoJson([
  "run",
  "--manifest-path",
  "crates/flowmemory-devnet/Cargo.toml",
  "--",
  "--state",
  runtimeStatePath,
  "--node-dir",
  resolve(runtimeDir, "node"),
  "node",
  "--node-id",
  "node:rpc-e2e:restart",
  "--block-ms",
  "50",
  "--max-blocks",
  "1",
], "restart bounded node");

const restartedBalance = rpc("balance_get", { accountId });
assert.equal(restartedBalance.amount, "77");

const restartedStatus = rpc("node_status");
assert.ok(Number(restartedStatus.latestBlockNumber ?? 0) >= Number(block.blockNumber ?? 0));

const report = {
  schema: "flowchain.rpc_e2e_report.v0",
  status: "passed",
  generatedAt: new Date().toISOString(),
  smokeMethodCount: smoke.methodCount,
  discoveredMethodCount: (discovery.result as JsonObject).methodCount,
  requiredMethodsChecked: true,
  readinessStatus: (readiness.result as JsonObject).status,
  publicRpcReady: (readiness.result as JsonObject).publicRpcReady,
  missingProductionEnvNames: (readiness.result as JsonObject).missingProductionEnvNames,
  runtimeSubmitChecked: true,
  mempoolVisibleBeforeBlock: true,
  blockReadChecked: true,
  transactionReadChecked: true,
  accountBalanceChecked: true,
  tokenBalanceChecked: true,
  provenanceChecked: true,
  restartContinuityChecked: true,
  runtime: {
    statePath: runtimeStatePath,
    accountId,
    createTxId: createQueued[0],
    faucetTxId: faucetQueued[0],
    blockNumber: block.blockNumber,
    blockHash: block.blockHash,
    balanceAfterRestart: restartedBalance.amount,
  },
  localOnly: true,
  productionReady: false,
  reportPath: resolve(outDir, "flowchain-rpc-e2e-report.json"),
};

const secretFinding = findSecret(report);
assert.equal(secretFinding, null, `rpc e2e report contains secret-shaped material: ${JSON.stringify(secretFinding)}`);

writeFileSync(report.reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));
