import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  DEFAULT_FLOWCHAIN_RPC_URL,
  assertNoFlowChainSecrets,
  createFlowChainClient,
  createLocalSignedEnvelope,
} from "../../packages/flowchain-sdk/src/index.ts";

function arg(name, fallback) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : fallback;
}

const rpcUrl = arg("rpc-url", process.env.FLOWCHAIN_RPC_URL ?? DEFAULT_FLOWCHAIN_RPC_URL);
const statePath = arg(
  "state",
  process.env.FLOWCHAIN_CONTROL_PLANE_LOCAL_DEVNET_PATH ?? "devnet/local/state.json",
);
const sourceAccount = arg("source", `local-account:node-example:source`);
const destinationAccount = arg("destination", `local-account:node-example:destination`);
const submittedBy = "operator:flowchain-node-example";
const client = createFlowChainClient({ rpcUrl });
const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

async function waitForApplied(txId, attempts = 20) {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const detail = await client.transactionGet({ txId });
      const status = detail.transaction?.status ?? detail.status;
      if (status === "applied") {
        return detail;
      }
    } catch {
      // The transaction is not visible until the runtime produces a block.
    }
    await new Promise((resolveTimeout) => setTimeout(resolveTimeout, 250));
  }
  throw new Error(`transaction was not applied: ${txId}`);
}

function produceBlock() {
  const result = spawnSync("cargo", [
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    resolve(repoRoot, statePath),
    "run",
    "--blocks",
    "1",
  ], {
    cwd: repoRoot,
    encoding: "utf8",
    windowsHide: true,
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout || "block production failed");
  }
  return JSON.parse(result.stdout);
}

const discovery = await client.discover();
const readiness = await client.readiness();

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
  faucetRecordId: `faucet:node-example:${Date.now()}`,
  accountId: sourceAccount,
  recipient: submittedBy,
  amountUnits: 25,
  reason: "flowchain-node-local-example",
}, submittedBy), { runtimeSubmit: true, submittedBy });

const transfer = await client.submitSignedTransaction(createLocalSignedEnvelope({
  type: "TransferLocalTestUnits",
  transferId: `transfer:node-example:${Date.now()}`,
  fromAccountId: sourceAccount,
  toAccountId: destinationAccount,
  amountUnits: 5,
  memo: "flowchain-node-local-example",
}, submittedBy), { runtimeSubmit: true, submittedBy });

const mempool = await client.mempoolList({ limit: 25 });
const blockRun = produceBlock();
const applied = await waitForApplied(String(transfer.runtimeSubmission?.queued?.[0] ?? transfer.txId));
const sourceBalance = await client.balanceGet(sourceAccount);
const destinationBalance = await client.balanceGet(destinationAccount);
const finality = await client.finalityList({ limit: 1 });

const report = {
  schema: "flowchain.example.node_local.v0",
  status: "passed",
  discovery: {
    schema: discovery.schema,
    methodCount: discovery.methodCount,
    evmJsonRpcCompatible: discovery.compatibility?.evmJsonRpcCompatible,
  },
  readiness: {
    schema: readiness.schema,
    status: readiness.status,
    publicRpcReady: readiness.publicRpcReady,
    missingProductionEnvNames: readiness.missingProductionEnvNames,
    envValuesPrinted: readiness.envValuesPrinted,
  },
  mempoolCountBeforeBlock: mempool.count,
  blocksProduced: blockRun.blocksProduced,
  transferTxId: applied.transaction?.transactionId ?? applied.transaction?.txId ?? transfer.txId,
  balances: {
    [sourceAccount]: sourceBalance.amount,
    [destinationAccount]: destinationBalance.amount,
  },
  finalitySchema: finality.schema,
  localOnly: true,
  productionReady: false,
};

assertNoFlowChainSecrets(report);
console.log(JSON.stringify(report, null, 2));
