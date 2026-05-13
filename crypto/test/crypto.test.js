import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import test from "node:test";

import {
  artifactFromChunks,
  attestationEnvelopeHash,
  canonicalJsonHash,
  canonicalJson,
  contractPulseId,
  cursorId,
  devnetBlockHash,
  domainSeparator,
  eip712DomainSeparator,
  emptyMerkleRoot,
  flowPulseEventArgsHash,
  flowPulseEventSignature,
  flowPulseObservationId,
  flowPulseSchemaId,
  indexerCursorId,
  keccakUtf8,
  merkleLeafHash,
  merkleRoot,
  normalizeHex,
  publicKeyFromPrivateKey,
  receiptHash,
  rootCommitment,
  rootfieldNamespaceId,
  signDigest,
  storageReceiptCommitmentHash,
  verifierIdentity,
  verifierReportHash,
  verifierSignaturePayload,
  verifyDigest,
  workReceiptId,
  workerIdentity,
  workerSignaturePayload
} from "../src/index.js";
import { validateVectors } from "../src/validate-vectors.js";

const root = resolve(import.meta.dirname, "..");

function fixture(name) {
  return JSON.parse(readFileSync(resolve(root, "fixtures", name), "utf8"));
}

const flowPulse = fixture("sample-flowpulse.json");
const observation = fixture("sample-observation.json");
const report = fixture("sample-report.json");

test("canonicalJson sorts object keys recursively", () => {
  assert.equal(canonicalJson({ b: 2, a: { d: 4, c: 3 } }), '{"a":{"c":3,"d":4},"b":2}');
});

test("canonicalJson normalizes hex case before hashing", () => {
  const left = { z: "0xABCDEF", a: { d: 4, c: "0xDEADBEEF" } };
  const right = { a: { c: "0xdeadbeef", d: 4 }, z: "0xabcdef" };
  assert.equal(canonicalJsonHash(left), canonicalJsonHash(right));
  assert.equal(normalizeHex("0xABCDEF"), "0xabcdef");
  assert.throws(() => normalizeHex("0xzz"), /invalid hex characters/);
});

test("exports named domain separators and cursor/root identity helpers", () => {
  const artifact = artifactFromChunks(observation.artifact);
  const cursorInput = {
    sourceId: keccakUtf8("indexer:base-flowpulse"),
    streamId: keccakUtf8("flowpulse:rootfield.beta"),
    sequence: 1,
    observationId: observation.expected.observationId,
    previousCursorId: "0x0000000000000000000000000000000000000000000000000000000000000000"
  };
  const namespaceInput = {
    chainId: observation.input.chainId,
    registry: "0x0000000000000000000000000000000000000000",
    rootfieldId: flowPulse.input.rootfieldId,
    schemaHash: keccakUtf8("flowmemory.rootfield.beta.v0")
  };
  const workReceiptInput = {
    observationId: observation.expected.observationId,
    receiptHash: observation.expected.receiptHash,
    workerId: report.workerSignature.input.workerId,
    workerSequence: report.workerSignature.input.workerSequence,
    nonce: report.workerSignature.input.nonce
  };
  const operatorId = keccakUtf8("operator:flowmemory-labs-devnet");

  assert.equal(
    domainSeparator("flowPulseObservationId"),
    "0x7a42d0c550a1e18a737aa6627ab6a76a6524750e0ee78d73a3b489f662e82474"
  );
  assert.equal(cursorId(cursorInput), indexerCursorId(cursorInput));
  assert.equal(
    rootfieldNamespaceId(namespaceInput),
    "0x6da665da25815ab5c3ee446af87a6883ad577c7a218c2f3140e3bd171548a806"
  );
  assert.equal(
    rootCommitment({
      rootfieldId: flowPulse.input.rootfieldId,
      root: artifact.contentMerkleRoot,
      artifactCommitment: artifact.artifactRoot,
      parentPulseId: flowPulse.input.parentPulseId,
      sequence: flowPulse.input.sequence
    }),
    "0xfa69bad84d06fa38d6928c3d8e50e926c2ef5ec0ed446858f350b49d75532e0b"
  );
  assert.equal(workReceiptId(workReceiptInput), "0xb7404c2b88e7f6a1991dfc5294f8f78932cbbf00ebecf302a1139950672f81f9");
  assert.equal(
    workerIdentity({
      operatorId,
      workerKeyId: report.workerSignature.input.workerKeyId,
      scopeHash: keccakUtf8("scope:base:rootfield.beta")
    }),
    "0x356c8e272ea376e5313a0bae08f9f154355c1658a526f557bd950bbb74c7065a"
  );
  assert.equal(
    verifierIdentity({
      operatorId,
      verifierKeyId: report.verifierSignature.input.verifierKeyId,
      verifierSetRoot: report.verifierSignature.input.verifierSetRoot
    }),
    "0xaf8489608eca0cfb4b25880355fd5d36ad96df15005906191c21bd6d58f6d9c6"
  );
  assert.equal(
    devnetBlockHash({
      chainId: observation.input.chainId,
      blockNumber: observation.input.blockNumber,
      parentHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
      stateRoot: keccakUtf8("state:flowmemory:devnet"),
      timestamp: flowPulse.input.occurredAt
    }),
    "0x90cb545229eb785f0583ca5abafb3da199a5c68a1aa8ef140e169c024ca48e54"
  );
});

test("computes FlowPulse schema id, event signature, pulse id, and event args hash", () => {
  assert.equal(flowPulseSchemaId(), flowPulse.expected.schemaId);
  assert.equal(flowPulseEventSignature(), flowPulse.expected.eventSignature);
  assert.equal(contractPulseId(flowPulse.contractInput), flowPulse.expected.pulseId);
  assert.equal(flowPulseEventArgsHash(flowPulse.input), flowPulse.expected.eventArgsHash);
});

test("computes FlowPulse observation id and receipt hash", () => {
  const observationId = flowPulseObservationId(observation.input);
  const eventArgsHash = flowPulseEventArgsHash(flowPulse.input);
  assert.equal(observationId, observation.expected.observationId);
  assert.equal(
    receiptHash({ ...observation.receipt, observationId, eventArgsHash }),
    observation.expected.receiptHash
  );
});

test("computes artifact commitment, Merkle root, and storage receipt commitment", () => {
  const artifact = artifactFromChunks(observation.artifact);
  assert.equal(artifact.contentMerkleRoot, observation.expected.contentMerkleRoot);
  assert.equal(artifact.artifactRoot, observation.expected.artifactRoot);
  assert.equal(merkleLeafHash(artifact.manifest.chunks[0]), artifact.leafHashes[0]);
  assert.equal(merkleRoot(artifact.leafHashes), observation.expected.contentMerkleRoot);
  assert.equal(emptyMerkleRoot(), "0xd696a744928cde1db971775966b90e254e54e2cc4a8952b099f9db5ef7bf3434");
  assert.equal(
    storageReceiptCommitmentHash(observation.storage),
    observation.expected.storageReceiptCommitment
  );
});

test("computes deterministic verifier report hash", () => {
  assert.equal(verifierReportHash(report.input), report.expected.reportId);
});

test("computes EIP-712 worker and verifier signature payloads", () => {
  const versionHash = keccakUtf8("0");
  const workerDomainSeparator = eip712DomainSeparator({
    nameHash: keccakUtf8("FlowMemory Worker"),
    versionHash,
    chainId: report.eip712.chainId,
    verifyingContract: report.eip712.verifyingContract,
    salt: report.eip712.deploymentId
  });
  const verifierDomainSeparator = eip712DomainSeparator({
    nameHash: keccakUtf8("FlowMemory Verifier"),
    versionHash,
    chainId: report.eip712.chainId,
    verifyingContract: report.eip712.verifyingContract,
    salt: report.eip712.deploymentId
  });

  assert.equal(workerDomainSeparator, report.workerSignature.expected.domainSeparator);
  assert.equal(verifierDomainSeparator, report.verifierSignature.expected.domainSeparator);
  assert.deepEqual(
    workerSignaturePayload({
      domainSeparator: workerDomainSeparator,
      ...report.workerSignature.input
    }),
    {
      structHash: report.workerSignature.expected.structHash,
      signingDigest: report.workerSignature.expected.signingDigest
    }
  );
  assert.deepEqual(
    verifierSignaturePayload({
      domainSeparator: verifierDomainSeparator,
      ...report.verifierSignature.input
    }),
    {
      structHash: report.verifierSignature.expected.structHash,
      signingDigest: report.verifierSignature.expected.signingDigest
    }
  );
});

test("computes generic attestation envelope hash", () => {
  assert.equal(
    attestationEnvelopeHash(report.attestationEnvelope.input),
    report.attestationEnvelope.expected.attestationEnvelopeHash
  );
});

test("observation id changes when reorg-sensitive block hash changes", () => {
  const changed = flowPulseObservationId({
    ...observation.input,
    blockHash: "0x3333333333333333333333333333333333333333333333333333333333333333"
  });
  assert.notEqual(changed, observation.expected.observationId);
});

test("receipt-adjacent fields fail closed when changed", () => {
  const artifact = artifactFromChunks(observation.artifact);
  const changedLog = flowPulseObservationId({ ...observation.input, logIndex: 4 });
  const changedUri = flowPulseEventArgsHash({
    ...flowPulse.input,
    uriHash: keccakUtf8("ipfs://different-metadata")
  });
  const swappedMerkleRoot = merkleRoot([
    artifact.leafHashes[1],
    artifact.leafHashes[0],
    artifact.leafHashes[2]
  ]);
  const wrongVerifierSet = verifierSignaturePayload({
    domainSeparator: report.verifierSignature.expected.domainSeparator,
    ...report.verifierSignature.input,
    verifierSetRoot: keccakUtf8("wrong-verifier-set")
  });

  assert.notEqual(changedLog, observation.expected.observationId);
  assert.notEqual(changedUri, flowPulse.expected.eventArgsHash);
  assert.notEqual(swappedMerkleRoot, observation.expected.contentMerkleRoot);
  assert.notEqual(wrongVerifierSet.signingDigest, report.verifierSignature.expected.signingDigest);
});

test("validates all published crypto test vectors", () => {
  assert.equal(validateVectors(), 21);
});

test("signs and verifies verifier digests with local test keys only", async () => {
  const privateKey = "0x0000000000000000000000000000000000000000000000000000000000000001";
  const wrongPrivateKey = "0x0000000000000000000000000000000000000000000000000000000000000002";
  const publicKey = publicKeyFromPrivateKey(privateKey);
  const wrongPublicKey = publicKeyFromPrivateKey(wrongPrivateKey);
  const digest = report.verifierSignature.expected.signingDigest;
  const wrongDigest = report.workerSignature.expected.signingDigest;

  const signature = await signDigest({ digest, privateKey });
  assert.equal(verifyDigest({ digest, signature, publicKey }), true);
  assert.equal(verifyDigest({ digest, signature, publicKey: wrongPublicKey }), false);
  assert.equal(verifyDigest({ digest: wrongDigest, signature, publicKey }), false);
});
