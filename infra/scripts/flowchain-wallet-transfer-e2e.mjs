#!/usr/bin/env node
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

import { dispatchJsonRpc, loadControlPlaneState } from "../../services/control-plane/src/index.ts";

const outDir = resolve("devnet/local/live-l1-crypto");
const reportPath = resolve(outDir, "wallet-transfer-e2e-report.json");
const vectors = JSON.parse(readFileSync(resolve("crypto/fixtures/production-l1-vectors.json"), "utf8"));
const transfer = vectors.positive.find((entry) => entry.name === "wallet-transfer");
assert.ok(transfer, "missing wallet-transfer production-L1 vector");

const dir = mkdtempSync(join(tmpdir(), "flowchain-wallet-transfer-e2e-"));
try {
  const state = loadControlPlaneState({
    txIntakePath: join(dir, "transactions.ndjson"),
    bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
  });
  const signedEnvelope = {
    document: transfer.document,
    envelope: transfer.envelope,
  };
  const accepted = dispatchJsonRpc({
    jsonrpc: "2.0",
    id: "wallet-transfer",
    method: "transaction_submit",
    params: { signedEnvelope },
  }, { state });
  assertNoRpcError(accepted, "wallet transfer");
  assert.equal(accepted.result.accepted, true);
  assert.equal(accepted.result.txId, transfer.expected.transactionId);

  const mutated = structuredClone(signedEnvelope);
  mutated.document.amount = "1";
  const rejected = dispatchJsonRpc({
    jsonrpc: "2.0",
    id: "mutated-wallet-transfer",
    method: "transaction_submit",
    params: { signedEnvelope: mutated },
  }, { state });
  assert.equal(rejected.error?.data?.reasonCode, "crypto.rejected");
  assert.ok(rejected.error.data.details.failureCodes.includes("bad-payload-hash"));

  mkdirSync(outDir, { recursive: true });
  writeFileSync(reportPath, `${JSON.stringify({
    schema: "flowchain.wallet_transfer_e2e.report.v0",
    status: "PASS",
    acceptedTxId: accepted.result.txId,
    rejectedMutationFailureCodes: rejected.error.data.details.failureCodes,
  }, null, 2)}\n`);
  console.log(`FLOWCHAIN_WALLET_TRANSFER_E2E_OK report=${reportPath}`);
} finally {
  rmSync(dir, { recursive: true, force: true });
}

function assertNoRpcError(response, label) {
  if (response?.error !== undefined) {
    throw new Error(`${label} failed: ${JSON.stringify(response.error)}`);
  }
}
