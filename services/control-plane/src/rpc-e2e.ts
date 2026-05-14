import assert from "node:assert/strict";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { findSecret } from "../../shared/src/index.ts";
import { dispatchJsonRpc } from "./json-rpc.ts";
import { runControlPlaneSmoke } from "./smoke.ts";
import type { JsonObject, RpcSuccessResponse } from "./types.ts";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const outDir = resolve(repoRoot, "devnet/local/rpc-e2e");
mkdirSync(outDir, { recursive: true });

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
  localOnly: true,
  productionReady: false,
  reportPath: resolve(outDir, "flowchain-rpc-e2e-report.json"),
};

const secretFinding = findSecret(report);
assert.equal(secretFinding, null, `rpc e2e report contains secret-shaped material: ${JSON.stringify(secretFinding)}`);

writeFileSync(report.reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify(report, null, 2));
