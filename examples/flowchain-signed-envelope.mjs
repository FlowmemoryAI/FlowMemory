import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { FlowChainClient, redactFlowChainText } from "../services/flowchain-sdk/src/index.ts";
import {
  buildProductTransferDocument,
  createEncryptedTestVault,
  LOCAL_TEST_UNIT_ASSET_ID,
  signWalletDocumentWithVault,
  verifyWalletSignedEnvelope,
} from "../crypto/src/index.js";

function asRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function parseArgs(argv) {
  const options = {
    rpcUrl: process.env.FLOWCHAIN_RPC_URL ?? "http://127.0.0.1:8787/rpc",
    timeoutMs: Number.parseInt(process.env.FLOWCHAIN_RPC_TIMEOUT_MS ?? "30000", 10),
    chainId: process.env.FLOWCHAIN_CHAIN_ID ?? "31337",
    nonce: Date.now().toString(),
    amount: "1",
    submit: !argv.includes("--no-submit"),
    submittedBy: "flowchain-signed-envelope-example",
    writePath: null,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--rpc") options.rpcUrl = argv[++index] ?? options.rpcUrl;
    else if (arg === "--timeout-ms") options.timeoutMs = Number.parseInt(argv[++index] ?? "30000", 10);
    else if (arg === "--chain-id") options.chainId = argv[++index] ?? options.chainId;
    else if (arg === "--nonce") options.nonce = argv[++index] ?? options.nonce;
    else if (arg === "--amount") options.amount = argv[++index] ?? options.amount;
    else if (arg === "--submitted-by") options.submittedBy = argv[++index] ?? options.submittedBy;
    else if (arg === "--write") options.writePath = argv[++index] ?? null;
    else if (arg === "--submit") options.submit = true;
    else if (arg === "--no-submit") options.submit = false;
    else throw new Error(`unknown argument: ${arg}`);
  }
  if (!/^\d+$/.test(options.nonce)) throw new Error("--nonce must be an unsigned integer string");
  if (!/^\d+$/.test(options.amount) || BigInt(options.amount) <= 0n) {
    throw new Error("--amount must be a positive unsigned integer string");
  }
  return options;
}

function writeJson(path, value) {
  const fullPath = resolve(path);
  mkdirSync(dirname(fullPath), { recursive: true });
  writeFileSync(fullPath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
  return fullPath;
}

function findMempoolTx(mempool, txId) {
  return asArray(asRecord(mempool).transactions)
    .map(asRecord)
    .find((row) => row.transactionId === txId || row.txId === txId) ?? null;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const issuedAtUnixMs = Date.now().toString();
  const password = `flowchain-local-dev-pack-${process.pid}-${issuedAtUnixMs}`;
  const walletA = createEncryptedTestVault({
    password,
    label: "dev-pack-signed-envelope-a",
    signerRole: "agent",
    chainId: options.chainId,
    createdAtUnixMs: issuedAtUnixMs,
  });
  const walletB = createEncryptedTestVault({
    password,
    label: "dev-pack-signed-envelope-b",
    signerRole: "agent",
    chainId: options.chainId,
    createdAtUnixMs: issuedAtUnixMs,
  });
  const accountA = walletA.publicAccounts[0];
  const accountB = walletB.publicAccounts[0];
  const document = buildProductTransferDocument({
    fromAccountId: accountA.address,
    toAccountId: accountB.address,
    assetId: LOCAL_TEST_UNIT_ASSET_ID,
    amount: options.amount,
    accountNonce: options.nonce,
    deadlineBlock: "0",
    memo: `flowchain-signed-envelope-example-${options.nonce}`,
  });
  const signedEnvelope = await signWalletDocumentWithVault({
    vault: walletA,
    password,
    signerKeyId: accountA.signerKeyId,
    document,
    chainId: options.chainId,
    nonce: options.nonce,
    issuedAtUnixMs,
  });
  const verification = verifyWalletSignedEnvelope({
    envelope: signedEnvelope,
    context: { chainId: options.chainId, expectedNonce: options.nonce },
  });
  if (verification.valid !== true) {
    throw new Error(`signed envelope verification failed: ${verification.rejectionReason ?? "unknown"}`);
  }

  const writtenPath = options.writePath === null ? null : writeJson(options.writePath, signedEnvelope);
  const client = new FlowChainClient({
    rpcUrl: options.rpcUrl,
    timeoutMs: Number.isFinite(options.timeoutMs) && options.timeoutMs > 0 ? options.timeoutMs : 30000,
  });
  const submit = options.submit
    ? asRecord(await client.submitSignedEnvelope(signedEnvelope, {
        submittedBy: options.submittedBy,
        runtimeSubmitMode: "off",
      }))
    : null;
  const txId = asRecord(submit).txId ?? asRecord(asRecord(submit).crypto).transactionId ?? null;
  const mempool = options.submit && typeof txId === "string"
    ? await client.mempoolList({ limit: 50 })
    : null;
  const mempoolTx = typeof txId === "string" ? findMempoolTx(mempool, txId) : null;
  const transactionDetail = typeof txId === "string"
    ? await client.transactionGet({ txId }).catch(() => null)
    : null;
  const transactionDetailFound = asRecord(transactionDetail).schema === "flowmemory.control_plane.transaction_detail.v0";

  console.log(JSON.stringify({
    schema: "flowchain.example.signed_envelope.v0",
    status: verification.valid && (!options.submit || asRecord(submit).accepted === true) ? "passed" : "failed",
    rpcEndpoint: redactFlowChainText(options.rpcUrl),
    chainId: options.chainId,
    submitted: options.submit,
    submitAccepted: asRecord(submit).accepted === true,
    submitStatus: asRecord(submit).status ?? null,
    txId,
    mempoolIntakeFound: mempoolTx !== null || transactionDetailFound,
    transactionDetailFound,
    writtenPath,
    signer: {
      address: accountA.address,
      signerKeyId: accountA.signerKeyId,
      keyScheme: accountA.keyScheme,
    },
    recipient: {
      address: accountB.address,
      keyScheme: accountB.keyScheme,
    },
    document: {
      schema: document.schema,
      transferId: document.transferId,
      amount: document.amount,
      assetId: document.assetId,
    },
    verification: {
      valid: verification.valid,
      signatureValid: verification.signatureValid,
      chainIdMatch: verification.chainIdMatch,
      transactionId: verification.transactionId,
      replayKey: verification.replayKey,
    },
    localOnly: true,
    noLiveBroadcast: true,
    noSecrets: true,
  }, null, 2));
}

main().catch((error) => {
  console.error(error instanceof Error ? redactFlowChainText(error.message) : redactFlowChainText(String(error)));
  process.exitCode = 1;
});
