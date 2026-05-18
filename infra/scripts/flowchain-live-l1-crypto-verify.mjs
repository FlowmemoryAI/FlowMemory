#!/usr/bin/env node
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

import { validateProductionL1Crypto } from "../../crypto/src/validate-production-l1-crypto.js";
import {
  assertFlowchainPublicMetadataContainsNoSecrets,
} from "../../crypto/src/identity.js";
import {
  bridgeSourceEventReplayKey,
  flowchainBlockHash,
  flowchainBridgeEvidenceHash,
  flowchainBridgeObservationId,
  flowchainFinalityReceiptId,
  flowchainReceiptRoot,
  flowchainTransactionId,
} from "../../crypto/src/production-l1.js";
import { canonicalJsonHash, keccakUtf8 } from "../../crypto/src/hashes.js";
import { dispatchJsonRpc, loadControlPlaneState } from "../../services/control-plane/src/index.ts";

const outDir = resolve("devnet/local/live-l1-crypto");
const matrixPath = resolve(outDir, "crypto-enforcement-matrix.json");
const reportPath = resolve(outDir, "live-l1-crypto-verify-report.json");

const vectors = readJson("crypto/fixtures/production-l1-vectors.json");
const transfer = vector("wallet-transfer");
const finality = vector("validator-finality");
const bridgeCredit = vector("bridge-credit-authority");
const bridgeDeposit = readJson("fixtures/bridge/base8453-pilot-mock-deposit.json");
const bridgeObservation = bridgeObservationFromDeposit(bridgeDeposit);

const checks = [];
let status = "PASS";
let failure;

try {
  checks.push({ name: "validateProductionL1Crypto", result: validateProductionL1Crypto() });
  for (const metadata of Object.values(vectors.accounts)) {
    assertFlowchainPublicMetadataContainsNoSecrets(metadata);
  }

  assert.equal(canonicalJsonHash(transfer.document), transfer.envelope.payloadHash);
  assert.equal(flowchainTransactionId(transfer.envelope), transfer.expected.transactionId);
  assert.equal(flowchainBlockHash(blockHashInput()), vectors.hashHelpers.blockHash);
  assert.equal(
    flowchainFinalityReceiptId(finalityHashInput()),
    vectors.hashHelpers.finalityReceiptId,
  );
  assert.equal(
    bridgeSourceEventReplayKey(vectors.bridgeSourceEvent),
    vectors.hashHelpers.replayKeys.bridgeSourceEvent,
  );
  assert.equal(
    flowchainBridgeObservationId(vectors.bridgeSourceEvent),
    vectors.hashHelpers.bridgeObservationId,
  );
  assert.equal(
    flowchainBridgeEvidenceHash(bridgeEvidenceInput()),
    vectors.hashHelpers.bridgeEvidenceHash,
  );

  checks.push(runtimeTransactionChecks());
  checks.push(runtimeBridgeChecks());
} catch (error) {
  status = "CODE-BLOCKED";
  failure = error instanceof Error ? error.stack ?? error.message : String(error);
}

const matrix = buildMatrix(status, failure);
mkdirSync(outDir, { recursive: true });
writeFileSync(matrixPath, `${JSON.stringify(matrix, null, 2)}\n`);
writeFileSync(reportPath, `${JSON.stringify({
  schema: "flowchain.live_l1_crypto.verify_report.v0",
  status,
  matrixPath: "devnet/local/live-l1-crypto/crypto-enforcement-matrix.json",
  checks,
  failure,
}, null, 2)}\n`);

if (status !== "PASS") {
  console.error(`FLOWCHAIN_LIVE_L1_CRYPTO_${status}`);
  if (failure) {
    console.error(failure);
  }
  process.exitCode = 1;
} else {
  console.log(`FLOWCHAIN_LIVE_L1_CRYPTO_PASS matrix=${matrixPath} report=${reportPath}`);
}

function runtimeTransactionChecks() {
  const dir = mkdtempSync(join(tmpdir(), "flowchain-live-l1-crypto-tx-"));
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
      id: "accepted-transfer",
      method: "transaction_submit",
      params: { signedEnvelope },
    }, { state });
    assertNoRpcError(accepted, "accepted transfer");
    assert.equal(accepted.result.accepted, true);
    assert.equal(accepted.result.status, "accepted_crypto_verified");

    const missingEnvelope = dispatchJsonRpc({
      jsonrpc: "2.0",
      id: "missing-envelope",
      method: "transaction_submit",
      params: { transaction: transfer.document },
    }, { state });
    assertRpcError(missingEnvelope, "params.invalid", "missing envelope");

    const duplicate = dispatchJsonRpc({
      jsonrpc: "2.0",
      id: "duplicate-transfer",
      method: "transaction_submit",
      params: { signedEnvelope },
    }, { state });
    assertCryptoErrorIncludes(duplicate, "duplicate-nonce", "duplicate transfer nonce");

    const wrongDomain = dispatchJsonRpc({
      jsonrpc: "2.0",
      id: "wrong-domain",
      method: "transaction_submit",
      params: {
        signedEnvelope: {
          document: transfer.document,
          envelope: {
            ...transfer.envelope,
            domain: "flowchain.production-l1.v0.transaction-envelope:profile:private-lan:chain:31337",
          },
        },
      },
    }, { state });
    assertCryptoErrorIncludes(wrongDomain, "wrong-domain", "wrong domain");

    const wrongChainId = dispatchJsonRpc({
      jsonrpc: "2.0",
      id: "wrong-chain-id",
      method: "transaction_submit",
      params: {
        signedEnvelope: {
          document: transfer.document,
          envelope: {
            ...transfer.envelope,
            chainId: "1",
          },
        },
      },
    }, { state });
    assertCryptoErrorIncludes(wrongChainId, "wrong-chain-id", "wrong chain ID");

    const wrongSignerRole = dispatchJsonRpc({
      jsonrpc: "2.0",
      id: "wrong-signer-role",
      method: "transaction_submit",
      params: {
        signedEnvelope: {
          document: finality.document,
          envelope: {
            ...finality.envelope,
            signerRole: "user",
            signerRoleCode: 10,
          },
        },
      },
    }, { state });
    assertCryptoErrorIncludes(wrongSignerRole, "wrong-signer", "wrong signer role");

    const mutatedPayload = dispatchJsonRpc({
      jsonrpc: "2.0",
      id: "mutated-payload",
      method: "transaction_submit",
      params: {
        signedEnvelope: {
          document: {
            ...transfer.document,
            amount: "1",
          },
          envelope: transfer.envelope,
        },
      },
    }, { state });
    assertCryptoErrorIncludes(mutatedPayload, "bad-payload-hash", "mutated payload");

    const malformedPublicKey = dispatchJsonRpc({
      jsonrpc: "2.0",
      id: "malformed-public-key",
      method: "transaction_submit",
      params: {
        signedEnvelope: {
          document: transfer.document,
          envelope: {
            ...transfer.envelope,
            publicKey: "0x1234",
          },
        },
      },
    }, { state });
    assertCryptoErrorIncludes(malformedPublicKey, "malformed-public-key", "malformed public key");

    return {
      name: "runtimeTransactionChecks",
      acceptedTxId: accepted.result.txId,
      rejected: [
        "missing-envelope",
        "duplicate-nonce",
        "wrong-domain",
        "wrong-chain-id",
        "wrong-signer-role",
        "mutated-payload",
        "malformed-public-key",
      ],
    };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function runtimeBridgeChecks() {
  const dir = mkdtempSync(join(tmpdir(), "flowchain-live-l1-crypto-bridge-"));
  try {
    const state = loadControlPlaneState({
      bridgeObservationPath: join(dir, "missing-observation.json"),
      bridgeRuntimeHandoffPath: join(dir, "missing-handoff.json"),
      bridgeObservationIntakePath: join(dir, "bridge-observations.ndjson"),
      txIntakePath: join(dir, "transactions.ndjson"),
    });
    const accepted = dispatchJsonRpc({
      jsonrpc: "2.0",
      id: "bridge-observation",
      method: "bridge_observation_submit",
      params: { observation: bridgeObservation },
    }, { state });
    assertNoRpcError(accepted, "accepted bridge observation");
    assert.equal(accepted.result.accepted, true);

    const duplicate = dispatchJsonRpc({
      jsonrpc: "2.0",
      id: "bridge-duplicate",
      method: "bridge_observation_submit",
      params: { observation: bridgeObservation },
    }, { state });
    assertCryptoErrorIncludes(duplicate, "duplicate-bridge-replay-key", "duplicate bridge replay key");

    const mutated = structuredClone(bridgeObservation);
    mutated.deposit.amount = "1";
    const mutatedPayload = dispatchJsonRpc({
      jsonrpc: "2.0",
      id: "bridge-mutated",
      method: "bridge_observation_submit",
      params: { observation: mutated },
    }, { state });
    assertCryptoErrorIncludes(mutatedPayload, "wrong-bridge-observation-id", "mutated bridge payload");

    return {
      name: "runtimeBridgeChecks",
      observationId: accepted.result.observationId,
      replayKey: accepted.result.crypto.replayKey,
      rejected: ["duplicate-bridge-replay-key", "wrong-bridge-observation-id"],
    };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function buildMatrix(matrixStatus, blockedReason) {
  const requiredItems = [
    ["canonical-json-hashing", "canonical JSON hashing", [
      "crypto/src/hashes.js canonicalJsonHash",
      "transaction_submit verifies envelope.payloadHash against canonical JSON document",
    ]],
    ["keccak-typed-ids", "Keccak typed IDs", [
      "crypto/src/production-l1.js and crypto/src/objects.js typedHash helpers",
      "production-L1 vector validator recomputes object, transaction, bridge, and finality IDs",
    ]],
    ["merkle-state-roots", "Merkle/state roots", [
      "crypto/src/merkle.js merkleRoot",
      "production-L1 flowchainTxRoot/ReceiptRoot/EventRoot/AccountStateRoot/TokenStateRoot/DexStateRoot vectors",
    ]],
    ["block-hashes", "block hashes", [
      "flowchainBlockHash vector check",
    ]],
    ["transaction-ids", "transaction IDs", [
      "flowchainTransactionId vector check",
      "control-plane transaction_submit stores verified transactionId",
    ]],
    ["secp256k1-signatures-public-key", "secp256k1 signatures and public-key metadata", [
      "verifyFlowchainEnvelope validates secp256k1 digest signatures",
      "production-L1 negatives cover malformed public key and signature",
    ]],
    ["local-transaction-envelopes", "local transaction envelopes", [
      "control-plane transaction_submit accepts only flowchain.local_transaction_envelope.v0 document/envelope pairs",
      "missing envelope is rejected before intake",
    ]],
    ["wallet-public-metadata", "wallet public metadata", [
      "assertFlowchainPublicMetadataContainsNoSecrets over production-L1 public account metadata",
      "wallet public metadata schemas omit private material",
    ]],
    ["bridge-replay-keys", "bridge replay keys", [
      "bridgeSourceEventReplayKey binds source chain, lockbox, tx hash, and log index",
      "bridge_observation_submit rejects duplicate replay keys",
    ]],
    ["bridge-evidence-hashes", "bridge evidence hashes", [
      "flowchainBridgeEvidenceHash vector check",
      "bridge relayer release evidence uses crypto evidence hash",
    ]],
    ["finality-receipt-ids", "finality receipt IDs", [
      "flowchainFinalityReceiptId vector check",
      "validator-finality envelope requires validator signer role",
    ]],
    ["validator-operator-key-references", "validator/operator key references", [
      "FlowChain account roles derive role-gated account IDs from public keys",
      "production-L1 negatives reject wrong signer role for finality and bridge authority envelopes",
    ]],
  ];

  const items = requiredItems.map(([id, primitive, evidence]) => ({
    id,
    primitive,
    implemented: matrixStatus === "PASS",
    enforcedByRuntime: matrixStatus === "PASS",
    tested: matrixStatus === "PASS",
    liveL1Required: true,
    blockedReason: matrixStatus === "PASS" ? null : blockedReason ?? "live L1 crypto verification failed",
    evidence,
  }));
  const blocked = items.filter((item) => item.liveL1Required && (
    item.implemented !== true
    || item.enforcedByRuntime !== true
    || item.tested !== true
    || item.blockedReason !== null
  ));
  return {
    schema: "flowchain.live_l1_crypto.enforcement_matrix.v0",
    status: blocked.length === 0 ? "PASS" : "CODE-BLOCKED",
    generatedAt: new Date().toISOString(),
    command: "npm run flowchain:crypto:live-l1:verify",
    matrixRule: "Every liveL1Required item must be implemented, runtime-enforced, tested, and unblocked.",
    blockedCount: blocked.length,
    items,
  };
}

function blockHashInput() {
  return {
    chainId: vectors.chainId,
    networkProfile: vectors.networkProfile,
    blockNumber: "9",
    parentHash: keccakUtf8("block:8"),
    txRoot: vectors.hashHelpers.txRoot,
    receiptRoot: vectors.hashHelpers.receiptRoot,
    eventRoot: vectors.hashHelpers.eventRoot,
    accountStateRoot: vectors.hashHelpers.accountStateRoot,
    tokenStateRoot: vectors.hashHelpers.tokenStateRoot,
    dexStateRoot: vectors.hashHelpers.dexStateRoot,
    timestampUnixMs: vectors.issuedAtUnixMs,
  };
}

function finalityHashInput() {
  return {
    chainId: vectors.chainId,
    blockNumber: "9",
    blockHash: vectors.hashHelpers.blockHash,
    stateRoot: vectors.hashHelpers.accountStateRoot,
    validatorSetRoot: canonicalJsonHash(Object.values(vectors.accounts).map((account) => account.accountId)),
    round: "1",
    voteRoot: flowchainReceiptRoot([vectors.accounts.validator.accountId, vectors.hashHelpers.blockHash]),
  };
}

function bridgeEvidenceInput() {
  return {
    sourceEventReplayKey: vectors.hashHelpers.replayKeys.bridgeSourceEvent,
    observationId: vectors.hashHelpers.bridgeObservationId,
    creditId: vectors.hashHelpers.bridgeCreditId,
    depositId: bridgeCredit.document.depositId,
    localChainId: vectors.chainId,
    evidencePayloadHash: canonicalJsonHash({
      source: vectors.bridgeSourceEvent,
      localRecipient: vectors.accounts.user.accountId,
      creditAmount: vectors.bridgeSourceEvent.amount,
    }),
  };
}

function bridgeObservationFromDeposit(deposit, mode = "base-mainnet-pilot") {
  return {
    schema: "flowmemory.bridge_deposit_observation.v0",
    observationId: flowchainBridgeObservationId({
      sourceChainId: deposit.sourceChainId,
      lockbox: deposit.sourceContract,
      token: deposit.token,
      depositor: deposit.sender,
      recipient: deposit.flowchainRecipient,
      amount: deposit.amount,
      txHash: deposit.txHash,
      logIndex: deposit.logIndex,
      blockNumber: deposit.sourceBlockNumber ?? "0",
      eventNonce: deposit.nonce ?? "0",
    }),
    replayKey: bridgeSourceEventReplayKey({
      sourceChainId: deposit.sourceChainId,
      lockbox: deposit.sourceContract,
      txHash: deposit.txHash,
      logIndex: deposit.logIndex,
    }),
    observedAt: "2026-05-13T00:00:00.000Z",
    mode,
    productionReady: false,
    deposit,
    guardrails: {
      explicitChainId: true,
      explicitContract: true,
      explicitBlockRange: true,
      noSecrets: true,
      approvedContract: true,
    },
  };
}

function vector(name) {
  const result = vectors.positive.find((entry) => entry.name === name);
  assert.ok(result, `missing production-L1 vector ${name}`);
  return result;
}

function assertNoRpcError(response, label) {
  if (response?.error !== undefined) {
    throw new Error(`${label} failed: ${JSON.stringify(response.error)}`);
  }
}

function assertRpcError(response, reasonCode, label) {
  assert.equal(response?.error?.data?.reasonCode, reasonCode, `${label}: ${JSON.stringify(response)}`);
}

function assertCryptoErrorIncludes(response, failureCode, label) {
  assertRpcError(response, "crypto.rejected", label);
  const failureCodes = response.error.data.details?.failureCodes ?? [];
  assert.ok(failureCodes.includes(failureCode), `${label} missing ${failureCode}: ${failureCodes.join(",")}`);
}

function readJson(path) {
  return JSON.parse(readFileSync(resolve(path), "utf8"));
}
