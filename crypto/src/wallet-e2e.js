// All private keys in this file are deterministic test-only values. Never use them for production.
#!/usr/bin/env node
import assert from "node:assert/strict";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

import {
  buildBridgeWithdrawalIntentDocument,
  buildProductAddLiquidityDocument,
  buildProductPoolCreateDocument,
  buildProductRemoveLiquidityDocument,
  buildProductSwapDocument,
  buildProductTokenLaunchDocument,
  buildProductTransferDocument,
  createEncryptedTestVault,
  exportLocalWalletPublicMetadata,
  keccakUtf8,
  LOCAL_TEST_UNIT_ASSET_ID,
  signWalletDocumentWithVault,
  validateLocalWalletPublicMetadata,
  verifyWalletSignedEnvelope
} from "./index.js";

import { dispatchJsonRpc, loadControlPlaneState } from "../../services/control-plane/src/index.ts";

const transferOnly = process.argv.includes("--transfer-only");
const repoRoot = resolve(import.meta.dirname, "..", "..");
const outDir = resolve(repoRoot, "localRuntime", "local", "production-network-wallet", transferOnly ? "transfer-e2e" : "wallet-e2e");
const chainId = "31337";
const password = "wallet-e2e-password";
const issuedAtUnixMs = "1778702400000";

rmSync(outDir, { recursive: true, force: true });
mkdirSync(outDir, { recursive: true });

const walletA = createEncryptedTestVault({
  password,
  label: "wallet-a",
  signerRole: "agent",
  privateKey: "0x0000000000000000000000000000000000000000000000000000000000000001",
  chainId,
  createdAtUnixMs: issuedAtUnixMs
});
const walletB = createEncryptedTestVault({
  password,
  label: "wallet-b",
  signerRole: "agent",
  privateKey: "0x0000000000000000000000000000000000000000000000000000000000000002",
  chainId,
  createdAtUnixMs: issuedAtUnixMs
});

writeJson("wallet-a.vault.local.json", walletA);
writeJson("wallet-b.vault.local.json", walletB);

const accountA = walletA.publicAccounts[0];
const accountB = walletB.publicAccounts[0];
const metadataA = exportLocalWalletPublicMetadata(walletA, { updatedAtUnixMs: issuedAtUnixMs });
const metadataB = exportLocalWalletPublicMetadata(walletB, { updatedAtUnixMs: issuedAtUnixMs });
assert.equal(validateLocalWalletPublicMetadata(metadataA, { expectedChainId: chainId }).valid, true);
assert.equal(validateLocalWalletPublicMetadata(metadataB, { expectedChainId: chainId }).valid, true);
writeJson("wallet-a-public-metadata.json", metadataA);
writeJson("wallet-b-public-metadata.json", metadataB);

const balances = new Map();
credit(accountA.address, LOCAL_TEST_UNIT_ASSET_ID, 1000000n);

const transferDocument = buildProductTransferDocument({
  fromAccountId: accountA.address,
  toAccountId: accountB.address,
  assetId: LOCAL_TEST_UNIT_ASSET_ID,
  amount: "125000",
  accountNonce: "1",
  deadlineBlock: "25",
  memo: "wallet-a-to-wallet-b-e2e"
});
const transferEnvelope = await signEnvelope(walletA, accountA.signerKeyId, transferDocument, "1");
const transferReceipt = applyTransfer({
  envelope: transferEnvelope,
  from: accountA.address,
  to: accountB.address,
  assetId: LOCAL_TEST_UNIT_ASSET_ID,
  amount: 125000n
});
writeJson(`envelopes/${transferEnvelope.txId}.json`, transferEnvelope);
writeJson("transfer-receipt.json", transferReceipt);

const txIntakePath = resolve(outDir, "api-transactions.ndjson");
const controlPlaneState = loadControlPlaneState({ txIntakePath });
const transferSubmit = dispatchJsonRpc({
  jsonrpc: "2.0",
  id: 1,
  method: "transaction_submit",
  params: {
    signedEnvelope: signedEnvelopePayload(transferDocument, transferEnvelope),
    submittedBy: "wallet-e2e"
  }
}, { state: controlPlaneState });
assert.equal(transferSubmit.result.accepted, true);

const productProof = transferOnly ? null : await signProductAndDexActions({ controlPlaneState });
const mempool = dispatchJsonRpc({ jsonrpc: "2.0", id: 3, method: "mempool_list" }, { state: controlPlaneState });
assert.ok(mempool.result.count >= (transferOnly ? 1 : 2));

const proof = {
  schema: "flowmemory.wallet_e2e_proof.v0",
  transferOnly,
  chainId,
  wallets: {
    walletA: publicWalletSummary(accountA),
    walletB: publicWalletSummary(accountB)
  },
  funding: {
    source: "local pilot credit fixture",
    account: accountA.address,
    assetId: LOCAL_TEST_UNIT_ASSET_ID,
    amount: "1000000"
  },
  transfer: {
    txId: transferEnvelope.txId,
    envelopePath: relativeOut(`envelopes/${transferEnvelope.txId}.json`),
    receipt: transferReceipt,
    submitResult: transferSubmit.result
  },
  balances: {
    before: transferReceipt.balancesBefore,
    after: transferReceipt.balancesAfter
  },
  productDex: productProof,
  controlPlane: {
    txIntakePath,
    mempoolCount: mempool.result.count
  },
  noSecretScan: assertNoPrivateMaterialInPublicOutputs(),
  boundaries: [
    "deterministic local test keys only",
    "vault files are written under ignored local-runtime/local paths",
    "public proofs contain public keys, addresses, signatures, tx ids, receipts, and balances only"
  ]
};
writeJson("wallet-e2e-proof.json", proof);

console.log(
  `FLOWMEMORY_WALLET_E2E_OK transferTxId=${transferEnvelope.txId} walletA=${accountA.address} walletB=${accountB.address} apiMempool=${mempool.result.count}`
);

async function signProductAndDexActions({ controlPlaneState }) {
  const tokenLaunch = buildProductTokenLaunchDocument({
    issuerAccountId: accountA.address,
    ownerAccountId: accountA.address,
    symbol: "FLOWT",
    name: "Flow Test Token",
    supply: "1000000000000000000000",
    accountNonce: "2"
  });
  const tokenTransfer = buildProductTransferDocument({
    fromAccountId: accountA.address,
    toAccountId: accountB.address,
    assetId: tokenLaunch.tokenId,
    amount: "25000000000000000000",
    accountNonce: "3",
    deadlineBlock: "30",
    memo: "token-transfer-e2e"
  });
  const poolCreate = buildProductPoolCreateDocument({
    creatorAccountId: accountA.address,
    baseAssetId: LOCAL_TEST_UNIT_ASSET_ID,
    quoteAssetId: tokenLaunch.tokenId,
    baseReserve: "100000",
    quoteReserve: "25000000000000000000",
    accountNonce: "4"
  });
  const addLiquidity = buildProductAddLiquidityDocument({
    providerAccountId: accountA.address,
    poolId: poolCreate.poolId,
    baseAmount: "100000",
    quoteAmount: "25000000000000000000",
    minLiquidityTokens: "1",
    deadlineBlock: "35",
    accountNonce: "5"
  });
  const swap = buildProductSwapDocument({
    traderAccountId: accountA.address,
    poolId: poolCreate.poolId,
    assetInId: LOCAL_TEST_UNIT_ASSET_ID,
    assetOutId: tokenLaunch.tokenId,
    amountIn: "1000",
    minAmountOut: "1",
    deadlineBlock: "40",
    accountNonce: "6"
  });
  const removeLiquidity = buildProductRemoveLiquidityDocument({
    providerAccountId: accountA.address,
    poolId: poolCreate.poolId,
    liquidityTokens: "1",
    minBaseAmount: "1",
    minQuoteAmount: "1",
    deadlineBlock: "45",
    accountNonce: "7"
  });
  const withdrawalIntent = buildBridgeWithdrawalIntentDocument({
    creditId: keccakUtf8("wallet-e2e-credit"),
    depositId: keccakUtf8("wallet-e2e-deposit"),
    sourceChainId: 31337,
    destinationChainId: 8453,
    token: "0x3333333333333333333333333333333333333333",
    amount: "500000",
    flowmemoryAccount: accountA.address,
    baseRecipient: "0x4444444444444444444444444444444444444444",
    requestedAt: "2026-05-14T00:00:00.000Z"
  });

  const documents = [
    ["tokenLaunch", tokenLaunch, "2"],
    ["tokenTransfer", tokenTransfer, "3"],
    ["poolCreate", poolCreate, "4"],
    ["addLiquidity", addLiquidity, "5"],
    ["swap", swap, "6"],
    ["removeLiquidity", removeLiquidity, "7"],
    ["withdrawalIntent", withdrawalIntent, "8"]
  ];
  const envelopes = {};
  for (const [name, document, nonce] of documents) {
    const envelope = await signEnvelope(walletA, accountA.signerKeyId, document, nonce);
    writeJson(`envelopes/${envelope.txId}.json`, envelope);
    envelopes[name] = {
      txId: envelope.txId,
      payloadType: envelope.payloadType,
      envelopePath: relativeOut(`envelopes/${envelope.txId}.json`),
      verification: envelope.verification
    };
  }

  const dexSubmit = dispatchJsonRpc({
    jsonrpc: "2.0",
    id: 2,
    method: "transaction_submit",
    params: {
      signedEnvelope: signedEnvelopePayload(poolCreate, readJson(resolve(outDir, envelopes.poolCreate.envelopePath))),
      submittedBy: "wallet-e2e"
    }
  }, { state: controlPlaneState });
  assert.equal(dexSubmit.result.accepted, true);

  return {
    tokenId: tokenLaunch.tokenId,
    poolId: poolCreate.poolId,
    signedActions: envelopes,
    submittedDexTxId: dexSubmit.result.txId,
    bridgeFundedFlow: {
      fundingSource: "local pilot credit fixture",
      creditedAccount: accountA.address,
      withdrawalIntentTxId: envelopes.withdrawalIntent.txId,
      buyOrSellActionTxId: envelopes.swap.txId
    }
  };
}

async function signEnvelope(vault, signerKeyId, document, nonce) {
  const envelope = await signWalletDocumentWithVault({
    vault,
    password,
    signerKeyId,
    document,
    chainId,
    nonce,
    issuedAtUnixMs
  });
  const verification = verifyWalletSignedEnvelope({ envelope, context: { chainId, expectedNonce: nonce } });
  assert.equal(verification.valid, true, document.schema);
  envelope.verification = verification;
  return envelope;
}

function signedEnvelopePayload(document, envelope) {
  return { document, envelope };
}

function applyTransfer({ envelope, from, to, assetId, amount }) {
  const before = {
    from: balanceOf(from, assetId).toString(),
    to: balanceOf(to, assetId).toString()
  };
  assert.ok(balanceOf(from, assetId) >= amount, "insufficient local E2E balance");
  debit(from, assetId, amount);
  credit(to, assetId, amount);
  return {
    schema: "flowmemory.wallet_local_transfer_receipt.v0",
    txId: envelope.txId,
    status: "applied",
    assetId,
    amount: amount.toString(),
    from,
    to,
    balancesBefore: before,
    balancesAfter: {
      from: balanceOf(from, assetId).toString(),
      to: balanceOf(to, assetId).toString()
    }
  };
}

function publicWalletSummary(account) {
  return {
    label: account.label,
    address: account.address,
    publicKey: account.publicKey,
    keyScheme: account.keyScheme,
    chainId: account.chainId,
    lastKnownNonce: account.lastKnownNonce
  };
}

function credit(account, assetId, amount) {
  balances.set(balanceKey(account, assetId), balanceOf(account, assetId) + amount);
}

function debit(account, assetId, amount) {
  balances.set(balanceKey(account, assetId), balanceOf(account, assetId) - amount);
}

function balanceOf(account, assetId) {
  return balances.get(balanceKey(account, assetId)) ?? 0n;
}

function balanceKey(account, assetId) {
  return `${account}:${assetId}`;
}

function assertNoPrivateMaterialInPublicOutputs() {
  const scanned = [
    "wallet-a-public-metadata.json",
    "wallet-b-public-metadata.json",
    "transfer-receipt.json"
  ];
  for (const file of scanned) {
    assertNoPrivateMaterial(readFileSync(resolve(outDir, file), "utf8"), file);
  }
  return {
    scannedFiles: scanned.length,
    forbiddenMarkersFound: 0,
    vaultFilesScanned: false
  };
}

function assertNoPrivateMaterial(text, label) {
  assert.doesNotMatch(text, /"privateKey"\s*:|"ciphertext"\s*:|"authTag"\s*:|"password"\s*:|seedPhrase|mnemonic|BEGIN RSA PRIVATE KEY|BEGIN OPENSSH PRIVATE KEY/i, label);
  assert.doesNotMatch(text, /https:\/\/hooks\.slack\.com|https:\/\/discord\.com\/api\/webhooks/i, label);
}

function writeJson(name, value) {
  const path = resolve(outDir, name);
  mkdirSync(resolve(path, ".."), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
  return path;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function relativeOut(name) {
  return name.replaceAll("\\", "/");
}
