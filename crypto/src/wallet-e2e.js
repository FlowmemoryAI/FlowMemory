#!/usr/bin/env node
import assert from "node:assert/strict";

import { bytesToHex } from "./encoding.js";
import { buildProductionL1Vectors } from "./production-l1-vectors.js";
import {
  createEncryptedTestVault,
  exportVaultPublicMetadata,
  signLocalTransactionWithVault
} from "./wallet.js";
import { verifyFlowchainEnvelope } from "./runtime-validation.js";
import { assertFlowchainPublicMetadataContainsNoSecrets } from "./identity.js";

const password = "local-test-password";
const vectors = await buildProductionL1Vectors();
const transfer = vectors.positive.find((entry) => entry.name === "wallet-transfer");
const vault = createEncryptedTestVault({
  password,
  label: "wallet-e2e-user",
  signerRole: "user",
  privateKey: deterministicTestPrivateKey(1),
  createdAtUnixMs: vectors.issuedAtUnixMs
});
const publicMetadata = exportVaultPublicMetadata(vault);
assertFlowchainPublicMetadataContainsNoSecrets(publicMetadata);

const signer = vault.publicAccounts[0];
const envelope = await signLocalTransactionWithVault({
  vault,
  password,
  signerKeyId: signer.signerKeyId,
  document: transfer.document,
  chainId: vectors.chainId,
  nonce: "1",
  issuedAtUnixMs: vectors.issuedAtUnixMs,
  expiresAtUnixMs: vectors.expiresAtUnixMs,
  networkProfile: vectors.networkProfile,
  payloadType: "wallet_transfer"
});

const ok = verifyFlowchainEnvelope({
  document: transfer.document,
  envelope,
  context: { chainId: vectors.chainId, networkProfile: vectors.networkProfile, expectedNonce: "1" }
});
assert.equal(ok.ok, true, ok.failureCodes.join(", "));

const mutated = verifyFlowchainEnvelope({
  document: { ...transfer.document, amount: "2" },
  envelope,
  context: { chainId: vectors.chainId, networkProfile: vectors.networkProfile, expectedNonce: "1" }
});
assert.equal(mutated.ok, false);
assert.ok(mutated.failureCodes.includes("bad-payload-hash"));

const wrongChain = verifyFlowchainEnvelope({
  document: transfer.document,
  envelope,
  context: { chainId: "31338", networkProfile: vectors.networkProfile, expectedNonce: "1" }
});
assert.equal(wrongChain.ok, false);
assert.ok(wrongChain.failureCodes.includes("wrong-chain-id"));

console.log(JSON.stringify({
  schema: "flowmemory.crypto.wallet_e2e_result.v0",
  ok: true,
  transactionId: ok.transactionId,
  signerAccountId: ok.signerAccountId,
  mutationFailure: mutated.failureCodes,
  wrongChainFailure: wrongChain.failureCodes
}, null, 2));

function deterministicTestPrivateKey(index) {
  const bytes = new Uint8Array(32);
  bytes[31] = index;
  return bytesToHex(bytes);
}
