import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import test from "node:test";

import {
  artifactFromChunks,
  agentAccountId,
  artifactAvailabilityProofId,
  attestationEnvelopeHash,
  addEncryptedTestVaultAccount,
  bridgeCreditId,
  bridgeDepositId,
  bridgeWithdrawalId,
  bridgeWithdrawalIntentId,
  buildBridgeWithdrawalIntentDocument,
  buildPilotBridgeCreditAckDocument,
  buildProductPoolCreateDocument,
  buildProductSwapDocument,
  buildProductTokenLaunchDocument,
  buildProductTransferDocument,
  createPilotOperatorConfigFromEnv,
  challengeId,
  canonicalJsonHash,
  canonicalJson,
  controlPlaneProvenanceResponseId,
  contractPulseId,
  cursorId,
  devnetBlockHash,
  DOMAIN_STRINGS,
  domainSeparator,
  eip712DomainSeparator,
  emptyMerkleRoot,
  finalityReceiptId,
  flowPulseEventArgsHash,
  flowPulseEventSignature,
  flowPulseObservationId,
  flowPulseSchemaId,
  createEncryptedTestVault,
  exportVaultPublicMetadata,
  exportLocalWalletPublicMetadata,
  exportPilotPublicMetadata,
  hardwareSignalEnvelopeId,
  indexerCursorId,
  listVaultPublicAccounts,
  localBalanceRecordId,
  localAlphaEnvelopeReplayKey,
  localAlphaObjectId,
  localSignatureEnvelopeHash,
  localSignatureEnvelopeInput,
  localSignatureEnvelopePayload,
  localTransactionEnvelopeHash,
  localTransactionEnvelopeInput,
  localTransactionEnvelopePayload,
  localTransactionReplayKey,
  LOCAL_TEST_UNIT_ASSET_ID,
  keccakUtf8,
  memoryCellId,
  merkleLeafHash,
  merkleRoot,
  modelPassportId,
  productAddLiquidityId,
  productBridgeCreditAckId,
  pilotEnvelopeReplayKey,
  pilotBridgeCreditAckId,
  productPoolCreateId,
  productRemoveLiquidityId,
  productSwapId,
  productTokenLaunchId,
  productTransferId,
  normalizeHex,
  publicKeyFromPrivateKey,
  receiptHash,
  rootCommitment,
  rootfieldNamespaceId,
  rotateEncryptedTestVaultAccount,
  signLocalTransactionWithVault,
  signWalletDocumentWithVault,
  signDigest,
  storageReceiptCommitmentHash,
  TYPE_STRINGS,
  typedHash,
  unlockEncryptedTestVault,
  validateLocalAlphaEnvelope,
  validateLocalTransactionEnvelope,
  validateLocalWalletPublicMetadata,
  validatePilotOperatorEnvelope,
  verifierModuleId,
  verifierIdentity,
  verifierReportHash,
  verifierSignaturePayload,
  verifyDigest,
  verifyWalletSignedEnvelope,
  workReceiptId,
  workerIdentity,
  workerSignaturePayload
} from "../src/index.js";
import { validateLocalAlphaFixtures } from "../src/validate-local-alpha-fixtures.js";
import { validateProductionL1Crypto } from "../src/validate-production-l1-crypto.js";
import { validateProductTestnetFixtures } from "../src/validate-product-testnet-fixtures.js";
import { validateVectors } from "../src/validate-vectors.js";

const root = resolve(import.meta.dirname, "..");

function fixture(name) {
  return JSON.parse(readFileSync(resolve(root, "fixtures", name), "utf8"));
}

function deterministicTestPrivateKey(index) {
  const bytes = new Uint8Array(32);
  bytes[31] = index;
  return `0x${Buffer.from(bytes).toString("hex")}`;
}

const flowPulse = fixture("sample-flowpulse.json");
const observation = fixture("sample-observation.json");
const report = fixture("sample-report.json");
const localAlphaObjects = fixture("local-alpha-objects.json");
const productTestnetTransactions = fixture("product-testnet-transactions.json");

const localAlphaValidators = Object.freeze({
  agentAccountId,
  artifactAvailabilityProofId,
  bridgeCreditId,
  bridgeDepositId,
  bridgeWithdrawalId,
  bridgeWithdrawalIntentId,
  challengeId,
  controlPlaneProvenanceResponseId,
  finalityReceiptId,
  hardwareSignalEnvelopeId,
  localBalanceRecordId,
  localSignatureEnvelopeHash,
  localTransactionEnvelopeHash,
  pilotBridgeCreditAckId,
  productAddLiquidityId,
  productBridgeCreditAckId,
  productPoolCreateId,
  productRemoveLiquidityId,
  productSwapId,
  productTokenLaunchId,
  productTransferId,
  memoryCellId,
  modelPassportId,
  verifierModuleId,
  verifierReportHash,
  workReceiptId
});

function assertSchemaDocument(schemaPath, document) {
  const schema = JSON.parse(readFileSync(resolve(root, "fixtures", schemaPath), "utf8"));
  const schemaVariant = Array.isArray(schema.oneOf)
    ? schema.oneOf.find((variant) => variant.properties?.schema?.const === document.schema)
    : schema;

  assert.ok(schemaVariant, `${document.schema} schema variant not found in ${schemaPath}`);
  assert.equal(document.schema, schemaVariant.properties.schema.const);
  const allowedKeys = new Set(Object.keys(schemaVariant.properties));
  for (const key of Object.keys(document)) {
    assert.ok(allowedKeys.has(key), `${document.schema} has unexpected property ${key}`);
  }

  for (const key of schemaVariant.required) {
    assert.ok(Object.hasOwn(document, key), `${document.schema} missing ${key}`);
  }

  for (const [key, definition] of Object.entries(schemaVariant.properties)) {
    const value = document[key];
    if (value === undefined && !schemaVariant.required.includes(key)) {
      continue;
    }
    const resolved = definition.$ref
      ? schema.$defs[definition.$ref.replace("#/$defs/", "")]
      : definition;
    if (resolved.const !== undefined) {
      assert.equal(value, resolved.const, `${document.schema}.${key}`);
    }
    if (resolved.pattern) {
      assert.match(value, new RegExp(resolved.pattern), `${document.schema}.${key}`);
    }
    if (resolved.enum) {
      assert.ok(resolved.enum.includes(value), `${document.schema}.${key}`);
    }
    if (resolved.type === "integer") {
      assert.equal(Number.isInteger(value), true, `${document.schema}.${key}`);
    }
    if (resolved.type === "object") {
      assert.equal(value !== null && typeof value === "object" && !Array.isArray(value), true);
    }
  }
}

function assertNoDuplicateObjectIds(documents) {
  const seen = new Set();
  for (const document of documents) {
    const idKey = Object.keys(document).find((key) => key.endsWith("Id"));
    assert.ok(idKey, `${document.schema} should expose an id field`);
    const id = document[idKey];
    if (seen.has(id)) {
      throw new Error(`duplicate object id: ${id}`);
    }
    seen.add(id);
  }
}

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

test("computes FlowChain Local Alpha object ids and validates schema documents", () => {
  assert.equal(localAlphaObjects.schema, "flowmemory.crypto.local-alpha-object-fixtures.v0");
  assert.equal(localAlphaObjects.rdBoundary.researchCryptoCrate, "external-rd/crypto");
  assert.match(localAlphaObjects.rdBoundary.consumeAs, /Research vocabulary/);
  assert.match(localAlphaObjects.rdBoundary.operatorVaultBoundary, /no-value test keys/);

  for (const vector of localAlphaObjects.positive) {
    const fn = localAlphaValidators[vector.function];
    assert.ok(fn, `unknown local alpha object function: ${vector.function}`);
    assert.equal(fn(vector.input), vector.expected, vector.name);
    assert.equal(vector.document[vector.idField], vector.expected, `${vector.name} document id`);
    assert.equal(localAlphaObjectId(vector.document), vector.expected, `${vector.name} recomputed document id`);
    assertSchemaDocument(vector.schemaPath, vector.document);
  }
});

test("validates FlowChain Local Alpha signed object envelopes", () => {
  const documentsByName = new Map(localAlphaObjects.positive.map((entry) => [entry.name, entry.document]));
  const seenSequences = new Set();

  for (const vector of localAlphaObjects.envelopes.positive) {
    const document = documentsByName.get(vector.objectName);
    assert.ok(document, `unknown envelope object: ${vector.objectName}`);
    assertSchemaDocument(vector.schemaPath, vector.envelope);
    assert.equal(localSignatureEnvelopeHash(vector.input), vector.expected.envelopeId, vector.name);
    assert.deepEqual(localSignatureEnvelopePayload(vector.input), {
      structHash: vector.expected.envelopeId,
      signingDigest: vector.expected.signingDigest
    });
    assert.deepEqual(localSignatureEnvelopeInput(vector.envelope), vector.input);

    const result = validateLocalAlphaEnvelope({
      document,
      envelope: vector.envelope,
      context: { seenSequences }
    });
    assert.deepEqual(result, { valid: true, errors: [] }, vector.name);
    seenSequences.add(localAlphaEnvelopeReplayKey(vector.envelope));
  }
});

test("AJV validates all Local Alpha object and envelope fixtures against canonical schemas", () => {
  assert.deepEqual(validateLocalAlphaFixtures(), {
    documents: 15,
    envelopes: 15,
    transactions: 1,
    schemas: 17
  });
});

test("Local Alpha signed envelope vectors reject replay, wrong domains, missing signer, malformed roots, malformed bridge deposits, and wrong types", () => {
  const documentsByName = new Map(localAlphaObjects.positive.map((entry) => [entry.name, entry.document]));
  const envelopesByName = new Map(localAlphaObjects.envelopes.positive.map((entry) => [entry.name, entry]));

  for (const vector of localAlphaObjects.envelopes.negative) {
    const { document, envelope, context } = mutatedEnvelopeVector(vector, documentsByName, envelopesByName);
    const result = validateLocalAlphaEnvelope({ document, envelope, context });
    assert.equal(result.valid, false, vector.name);
    for (const expectedError of vector.expectErrors) {
      assert.ok(
        result.errors.includes(expectedError),
        `${vector.name} expected ${expectedError}, got ${result.errors.join(", ")}`
      );
    }
  }
});

test("validates canonical local transaction envelopes and negative vectors", () => {
  const documentsByName = new Map(localAlphaObjects.positive.map((entry) => [entry.name, entry.document]));
  const transactionsByName = new Map(localAlphaObjects.transactions.positive.map((entry) => [entry.name, entry]));
  const seenNonces = new Set();

  for (const vector of localAlphaObjects.transactions.positive) {
    const document = documentsByName.get(vector.objectName);
    assert.ok(document, `unknown transaction object: ${vector.objectName}`);
    assertSchemaDocument(vector.schemaPath, vector.envelope);
    assert.equal(localTransactionEnvelopeHash(vector.input), vector.expected.envelopeId, vector.name);
    assert.deepEqual(localTransactionEnvelopePayload(vector.input), {
      structHash: vector.expected.envelopeId,
      signingDigest: vector.expected.signingDigest
    });
    assert.deepEqual(localTransactionEnvelopeInput(vector.envelope), vector.input);

    const result = validateLocalTransactionEnvelope({
      document,
      envelope: vector.envelope,
      context: { chainId: vector.envelope.chainId, seenNonces }
    });
    assert.deepEqual(result, { valid: true, errors: [] }, vector.name);
    seenNonces.add(localTransactionReplayKey(vector.envelope));
  }

  for (const vector of localAlphaObjects.transactions.negative) {
    const { document, envelope, context } = mutatedTransactionVector(vector, documentsByName, transactionsByName);
    const result = validateLocalTransactionEnvelope({ document, envelope, context });
    assert.equal(result.valid, false, vector.name);
    for (const expectedError of vector.expectErrors) {
      assert.ok(
        result.errors.includes(expectedError),
        `${vector.name} expected ${expectedError}, got ${result.errors.join(", ")}`
      );
    }
  }
});

test("validates Product Testnet V1 wallet transaction documents, envelopes, and negative vectors", () => {
  assert.equal(productTestnetTransactions.schema, "flowmemory.crypto.product-testnet-transaction-fixtures.v0");
  assert.doesNotMatch(JSON.stringify(productTestnetTransactions.publicMetadata), /privateKey|mnemonic|seed|ciphertext/i);

  const documentsByName = new Map();
  for (const vector of productTestnetTransactions.documents.positive) {
    const fn = localAlphaValidators[vector.function];
    assert.ok(fn, `unknown product transaction function: ${vector.function}`);
    assert.equal(fn(vector.input), vector.expected, vector.name);
    assert.equal(vector.document[vector.idField], vector.expected, `${vector.name} document id`);
    assert.equal(localAlphaObjectId(vector.document), vector.expected, `${vector.name} recomputed document id`);
    assertSchemaDocument(vector.schemaPath, vector.document);
    documentsByName.set(vector.name, vector.document);
  }

  const transactionsByName = new Map();
  for (const vector of productTestnetTransactions.transactions.positive) {
    const document = documentsByName.get(vector.objectName);
    assert.ok(document, `unknown product transaction document: ${vector.objectName}`);
    assertSchemaDocument(vector.schemaPath, vector.envelope);
    assert.equal(localTransactionEnvelopeHash(vector.input), vector.expected.envelopeId, vector.name);
    assert.deepEqual(localTransactionEnvelopePayload(vector.input), {
      structHash: vector.expected.envelopeId,
      signingDigest: vector.expected.signingDigest
    });
    assert.deepEqual(localTransactionEnvelopeInput(vector.envelope), vector.input);
    assert.deepEqual(validateLocalTransactionEnvelope({
      document,
      envelope: vector.envelope,
      context: { chainId: productTestnetTransactions.chainId, expectedNonce: vector.envelope.nonce }
    }), { valid: true, errors: [] }, vector.name);
    transactionsByName.set(vector.name, vector);
  }

  for (const vector of productTestnetTransactions.transactions.negative) {
    const { document, envelope, context } = mutatedTransactionVector(vector, documentsByName, transactionsByName);
    const result = validateLocalTransactionEnvelope({ document, envelope, context });
    assert.equal(result.valid, false, vector.name);
    for (const expectedError of vector.expectErrors) {
      assert.ok(
        result.errors.includes(expectedError),
        `${vector.name} expected ${expectedError}, got ${result.errors.join(", ")}`
      );
    }
  }

  assert.deepEqual(validateProductTestnetFixtures(), {
    documents: 8,
    transactions: 8,
    negativeTransactions: 9,
    schemas: 3
  });
});

test("validates production-L1 runtime crypto vectors and exact negative failures", () => {
  assert.deepEqual(validateProductionL1Crypto(), {
    positive: 11,
    negative: 14,
    hashHelpers: 14,
    schemas: 6
  });
});

test("Local Alpha object fixtures reject swapped fields, malformed hex, duplicate ids, and changed type strings", () => {
  for (const negative of localAlphaObjects.negative) {
    if (negative.reason === "swapped-field-rejection") {
      const fn = localAlphaValidators[negative.function];
      assert.notEqual(fn(negative.input), negative.mustNotEqual, negative.name);
    }
    if (negative.reason === "malformed-hex-rejection") {
      const fn = localAlphaValidators[negative.function];
      assert.throws(() => fn(negative.input), /invalid hex/, negative.name);
    }
    if (negative.reason === "duplicate-id-rejection") {
      assert.throws(() => assertNoDuplicateObjectIds(negative.documents), /duplicate object id/, negative.name);
    }
  }

  const modelPassport = localAlphaObjects.positive.find((entry) => entry.function === "modelPassportId");
  const changedTypeString = TYPE_STRINGS.modelPassportV0.replace(
    "FlowChainModelPassportV0",
    "FlowChainModelPassportV1"
  );
  const changedTypeHash = typedHash(changedTypeString, [
    ["bytes32", modelPassport.input.providerHash],
    ["bytes32", modelPassport.input.modelFamilyHash],
    ["bytes32", modelPassport.input.versionHash],
    ["bytes32", modelPassport.input.licenseRoot],
    ["bytes32", modelPassport.input.policyRoot],
    ["bytes32", modelPassport.input.artifactRoot],
    ["bytes32", modelPassport.input.metadataHash],
    ["bytes32", modelPassport.input.nonce]
  ]);

  assert.notEqual(changedTypeHash, modelPassport.expected);
  assert.notEqual(
    domainSeparator("modelPassportId"),
    domainSeparator("flowchain.local-alpha.v1.model-passport.id")
  );
});

test("control-plane provenance response uses stable canonical JSON body hashing", () => {
  const provenance = localAlphaObjects.positive.find(
    (entry) => entry.function === "controlPlaneProvenanceResponseId"
  );
  const shuffledBody = {
    limitations: [
      "V0 binds IDs and commitments only.",
      "V0 does not prove model output correctness."
    ],
    status: "challengeable",
    subject: "local-alpha-memory-cell"
  };

  assert.equal(canonicalJsonHash(shuffledBody), provenance.input.responseBodyHash);
  assert.equal(canonicalJsonHash(provenance.document.responseBody), provenance.document.responseBodyHash);
  assert.equal(controlPlaneProvenanceResponseId(provenance.input), provenance.expected);
});

test("local encrypted test vault creates, unlocks, lists, signs, verifies, exports public metadata, and rotates accounts", async () => {
  const password = "local-test-password";
  const memoryCell = localAlphaObjects.positive.find((entry) => entry.name === "memory-cell.demo").document;
  const vault = createEncryptedTestVault({
    password,
    label: "operator",
    signerRole: "operator",
    privateKey: deterministicTestPrivateKey(1),
    createdAtUnixMs: "1778702400000"
  });

  assert.doesNotMatch(JSON.stringify(vault), /privateKey|mnemonic|seed/i);
  assert.equal(listVaultPublicAccounts(vault).length, 1);
  assert.equal(unlockEncryptedTestVault({ vault, password }).accounts.length, 1);
  await assert.rejects(
    () => signLocalTransactionWithVault({
      vault,
      password: "wrong-password",
      signerKeyId: vault.publicAccounts[0].signerKeyId,
      document: memoryCell,
      chainId: "31337",
      nonce: "1"
    }),
    /authenticate|decrypt|Unsupported/i
  );

  const expandedVault = addEncryptedTestVaultAccount({
    vault,
    password,
    label: "agent",
    signerRole: "agent",
    privateKey: deterministicTestPrivateKey(2),
    createdAtUnixMs: "1778702400001"
  });
  assert.equal(listVaultPublicAccounts(expandedVault).length, 2);

  const agentKey = listVaultPublicAccounts(expandedVault).find((account) => account.signerRole === "agent");
  const envelope = await signLocalTransactionWithVault({
    vault: expandedVault,
    password,
    signerKeyId: agentKey.signerKeyId,
    document: memoryCell,
    chainId: "31337",
    nonce: "7",
    issuedAtUnixMs: "1778702400002"
  });
  assert.deepEqual(validateLocalTransactionEnvelope({
    document: memoryCell,
    envelope,
    context: { chainId: "31337", expectedSignerId: agentKey.signerId }
  }), { valid: true, errors: [] });

  const publicExport = exportVaultPublicMetadata(expandedVault);
  assert.doesNotMatch(JSON.stringify(publicExport), /privateKey|mnemonic|ciphertext/i);
  assert.equal(publicExport.publicAccounts.length, 2);

  const rotatedVault = rotateEncryptedTestVaultAccount({
    vault: expandedVault,
    password,
    signerKeyId: agentKey.signerKeyId,
    privateKey: deterministicTestPrivateKey(5),
    createdAtUnixMs: "1778702400003"
  });
  const rotatedAccounts = listVaultPublicAccounts(rotatedVault).filter(
    (account) => account.signerId === agentKey.signerId
  );
  assert.equal(rotatedAccounts.length, 2);
  assert.equal(rotatedAccounts.some((account) => account.active === false), true);
  assert.equal(rotatedAccounts.some((account) => account.rotatedFromSignerKeyId === agentKey.signerKeyId), true);
});

test("human wallet metadata and signed envelopes cover transfer, token, DEX, withdrawal, and negative cases", async () => {
  const password = "human-wallet-test";
  const chainId = "31337";
  const issuedAtUnixMs = "1778702400000";
  const vault = createEncryptedTestVault({
    password,
    label: "wallet-a",
    signerRole: "agent",
    privateKey: "0x0000000000000000000000000000000000000000000000000000000000000001",
    chainId,
    createdAtUnixMs: issuedAtUnixMs
  });
  const recipientVault = createEncryptedTestVault({
    password,
    label: "wallet-b",
    signerRole: "agent",
    privateKey: "0x0000000000000000000000000000000000000000000000000000000000000002",
    chainId,
    createdAtUnixMs: issuedAtUnixMs
  });
  const account = vault.publicAccounts[0];
  const recipient = recipientVault.publicAccounts[0];
  const metadata = exportLocalWalletPublicMetadata(vault, { updatedAtUnixMs: issuedAtUnixMs });

  assert.deepEqual(validateLocalWalletPublicMetadata(metadata, { expectedChainId: chainId }), {
    schema: "flowchain.local_wallet_public_metadata_verification.v0",
    valid: true,
    secretFree: true,
    chainIdMatch: true,
    accountCount: 1,
    errors: []
  });
  assert.doesNotMatch(JSON.stringify(metadata), /privateKey|ciphertext|authTag|mnemonic|seedPhrase/i);

  const transfer = buildProductTransferDocument({
    fromAccountId: account.address,
    toAccountId: recipient.address,
    assetId: LOCAL_TEST_UNIT_ASSET_ID,
    amount: "100",
    accountNonce: "1",
    deadlineBlock: "25",
    memo: "human-wallet-transfer"
  });
  const envelope = await signWalletDocumentWithVault({
    vault,
    password,
    signerKeyId: account.signerKeyId,
    document: transfer,
    chainId,
    nonce: "1",
    issuedAtUnixMs
  });
  assert.equal(envelope.payload.transferId, transfer.transferId);
  assert.equal(envelope.tx.transferId, transfer.transferId);
  assert.equal(envelope.txId, envelope.localEnvelope.envelopeId);
  assert.equal(envelope.signerAddress, account.address);
  assert.deepEqual(verifyWalletSignedEnvelope({
    envelope,
    context: { chainId, expectedNonce: "1", expectedSignerAddress: account.address }
  }).errors, []);

  const tokenLaunch = buildProductTokenLaunchDocument({
    issuerAccountId: account.address,
    ownerAccountId: account.address,
    symbol: "FLOWT",
    name: "Flow Test Token",
    supply: "1000",
    accountNonce: "2"
  });
  const poolCreate = buildProductPoolCreateDocument({
    creatorAccountId: account.address,
    baseAssetId: LOCAL_TEST_UNIT_ASSET_ID,
    quoteAssetId: tokenLaunch.tokenId,
    baseReserve: "100",
    quoteReserve: "500",
    accountNonce: "3"
  });
  const swap = buildProductSwapDocument({
    traderAccountId: account.address,
    poolId: poolCreate.poolId,
    assetInId: LOCAL_TEST_UNIT_ASSET_ID,
    assetOutId: tokenLaunch.tokenId,
    amountIn: "10",
    minAmountOut: "1",
    deadlineBlock: "30",
    accountNonce: "4"
  });
  const withdrawalIntent = buildBridgeWithdrawalIntentDocument({
    creditId: keccakUtf8("human-wallet-credit"),
    depositId: keccakUtf8("human-wallet-deposit"),
    sourceChainId: 31337,
    destinationChainId: 8453,
    token: "0x3333333333333333333333333333333333333333",
    amount: "50",
    flowchainAccount: account.address,
    baseRecipient: "0x4444444444444444444444444444444444444444",
    requestedAt: "2026-05-14T00:00:00.000Z"
  });
  for (const [document, nonce] of [[tokenLaunch, "2"], [poolCreate, "3"], [swap, "4"], [withdrawalIntent, "5"]]) {
    const signed = await signWalletDocumentWithVault({
      vault,
      password,
      signerKeyId: account.signerKeyId,
      document,
      chainId,
      nonce,
      issuedAtUnixMs
    });
    assert.equal(verifyWalletSignedEnvelope({ envelope: signed, context: { chainId, expectedNonce: nonce } }).valid, true);
  }

  await assert.rejects(
    () => signWalletDocumentWithVault({
      vault,
      password: "wrong-password",
      signerKeyId: account.signerKeyId,
      document: transfer,
      chainId,
      nonce: "1",
      issuedAtUnixMs
    }),
    /authenticate|decrypt|Unsupported/i
  );

  for (const [name, mutated, expectedError] of [
    ["wrong-chain", { context: { chainId: "8453" } }, "wrong-chain-id"],
    ["stale-nonce", { context: { expectedNonce: "2" } }, "wrong-nonce"],
    ["replay", { context: { seenNonces: new Set([localTransactionReplayKey(envelope.localEnvelope)]) } }, "replay"],
    ["mutated-payload", { envelope: { ...envelope, payload: { ...transfer, amount: "101" } } }, "bad-payload-hash"],
    ["malformed-public-key", {
      envelope: {
        ...envelope,
        signer: { ...envelope.signer, publicKey: "0x1234" },
        localEnvelope: { ...envelope.localEnvelope, publicKey: "0x1234" }
      }
    }, "malformed-public-key"]
  ]) {
    const result = verifyWalletSignedEnvelope({
      envelope: mutated.envelope ?? envelope,
      context: { chainId, expectedNonce: "1", ...mutated.context }
    });
    assert.equal(result.valid, false, name);
    assert.ok(result.errors.includes(expectedError), `${name}: ${result.errors.join(", ")}`);
  }

  const secretMetadata = structuredClone(metadata);
  secretMetadata.accounts[0].privateKey = "0x1111111111111111111111111111111111111111111111111111111111111111";
  const secretResult = validateLocalWalletPublicMetadata(secretMetadata, { expectedChainId: chainId });
  assert.equal(secretResult.valid, false);
  assert.ok(secretResult.errors.includes("secret-material"));
});

test("capped real-value pilot operator messages sign, export public metadata, and fail closed", async () => {
  const password = "pilot-test-password";
  const issuedAtUnixMs = "1778702400000";
  const fakeRpcUrl = ["https://example.invalid", "redacted"].join("/");
  const vault = createEncryptedTestVault({
    password,
    label: "pilot-operator",
    signerRole: "operator",
    privateKey: deterministicTestPrivateKey(1),
    createdAtUnixMs: issuedAtUnixMs
  });
  const operator = vault.publicAccounts[0];
  const env = {
    FLOWCHAIN_PILOT_CHAIN_ID: "84532",
    FLOWCHAIN_PILOT_CONTRACT_ADDRESS: "0x1111111111111111111111111111111111111111",
    FLOWCHAIN_PILOT_OPERATOR_ID: operator.signerId,
    FLOWCHAIN_PILOT_CAP_ID: keccakUtf8("pilot-cap:test"),
    FLOWCHAIN_PILOT_CAP_ASSET_ID: keccakUtf8("asset:usdc"),
    FLOWCHAIN_PILOT_CAP_MAX_AMOUNT: "25000000",
    FLOWCHAIN_PILOT_CAP_UNIT: "USDC-6",
    FLOWCHAIN_PILOT_CAP_WINDOW_START_UNIX_MS: issuedAtUnixMs,
    FLOWCHAIN_PILOT_CAP_WINDOW_END_UNIX_MS: "1778788800000",
    FLOWCHAIN_PILOT_RPC_URL: fakeRpcUrl
  };
  const config = createPilotOperatorConfigFromEnv({ env, createdAtUnixMs: issuedAtUnixMs });
  for (const [name, envPatch, errorPattern] of [
    ["unsupported chain id", { FLOWCHAIN_PILOT_CHAIN_ID: "1" }, /unsupported pilot chain id/],
    ["malformed cap id", { FLOWCHAIN_PILOT_CAP_ID: "not-a-cap-id" }, /invalid pilot cap id/],
    ["zero max cap", { FLOWCHAIN_PILOT_CAP_MAX_AMOUNT: "0" }, /maxAmount must be positive/],
    ["used cap above max", { FLOWCHAIN_PILOT_CAP_USED_AMOUNT: "25000001" }, /usedAmount/],
    ["closed cap window", { FLOWCHAIN_PILOT_CAP_WINDOW_END_UNIX_MS: issuedAtUnixMs }, /window/],
    ["secret-shaped config path", { FLOWCHAIN_PILOT_CONFIG_PATH: "devnet/local/pilot-wallet/rpc_url.json" }, /secret material/],
    ["base mainnet non-usdc cap", { FLOWCHAIN_PILOT_CHAIN_ID: "8453", FLOWCHAIN_PILOT_CAP_UNIT: "ETH-18" }, /USDC-6/],
    ["base mainnet cap above guardrail", { FLOWCHAIN_PILOT_CHAIN_ID: "8453", FLOWCHAIN_PILOT_CAP_MAX_AMOUNT: "25000001" }, /25 USD/]
  ]) {
    assert.throws(
      () => createPilotOperatorConfigFromEnv({ env: { ...env, ...envPatch }, createdAtUnixMs: issuedAtUnixMs }),
      errorPattern,
      name
    );
  }
  const publicMetadata = exportPilotPublicMetadata({
    config,
    walletMetadata: exportVaultPublicMetadata(vault)
  });
  const mismatchedVault = createEncryptedTestVault({
    password,
    label: "other-operator",
    signerRole: "operator",
    privateKey: deterministicTestPrivateKey(2),
    createdAtUnixMs: issuedAtUnixMs
  });
  assert.throws(
    () => exportPilotPublicMetadata({ config, walletMetadata: exportVaultPublicMetadata(mismatchedVault) }),
    /active operator signer matching the pilot config/
  );
  assert.doesNotMatch(JSON.stringify(config), /redacted/i);
  assert.doesNotMatch(JSON.stringify(publicMetadata), /privateKey|mnemonic|seed|redacted|webhook|apiKey/i);
  assert.equal(publicMetadata.accounts.length, 1);
  assert.equal(config.nextCommands.some((command) => command.includes("flowchain-wallet-pilot-observe.ps1")), true);

  const document = buildPilotBridgeCreditAckDocument({
    chainId: config.chainId,
    contractAddress: config.contractAddress,
    operatorId: config.operatorId,
    creditId: keccakUtf8("pilot-credit"),
    depositId: keccakUtf8("pilot-deposit"),
    accountId: operator.signerId,
    assetId: config.pilotCap.assetId,
    amount: "5000000",
    acknowledgedAtBlockNumber: "10",
    accountNonce: "1",
    issuedAtUnixMs,
    expiresAtUnixMs: "1778706000000",
    pilotCap: config.pilotCap
  });
  assert.equal(pilotBridgeCreditAckId(document), document.pilotBridgeCreditAckId);

  const envelope = await signLocalTransactionWithVault({
    vault,
    password,
    signerKeyId: operator.signerKeyId,
    document,
    chainId: config.chainId,
    nonce: "1",
    issuedAtUnixMs
  });
  assert.deepEqual(validatePilotOperatorEnvelope({
    document,
    envelope,
    context: {
      expectedChainId: config.chainId,
      expectedContractAddress: config.contractAddress,
      expectedOperatorId: config.operatorId,
      expectedNonce: "1",
      nowUnixMs: issuedAtUnixMs
    }
  }), { valid: true, errors: [] });

  for (const [name, mutation, expectedError] of [
    ["wrong-chain", { context: { expectedChainId: "8453" } }, "wrong-chain-id"],
    ["wrong-contract", { context: { expectedContractAddress: "0x2222222222222222222222222222222222222222" } }, "wrong-contract-address"],
    ["wrong-operator", { context: { expectedOperatorId: keccakUtf8("wrong") } }, "wrong-operator"],
    ["mutated-payload", { document: { ...document, amount: "1" } }, "bad-payload-hash"],
    ["replay", { context: { seenNonces: new Set([pilotEnvelopeReplayKey(envelope)]) } }, "replay"],
    ["expired", { context: { nowUnixMs: "1778709600000" } }, "expired-message"],
    ["missing-cap", { document: withoutField(document, "pilotCap") }, "missing-cap-fields"]
  ]) {
    const result = validatePilotOperatorEnvelope({
      document: mutation.document ?? document,
      envelope,
      context: {
        expectedChainId: config.chainId,
        expectedContractAddress: config.contractAddress,
        expectedOperatorId: config.operatorId,
        ...mutation.context
      }
    });
    assert.equal(result.valid, false, name);
    assert.ok(result.errors.includes(expectedError), `${name}: ${result.errors.join(", ")}`);
  }
});

test("validates all published crypto test vectors", () => {
  assert.equal(validateVectors(), 46);
});

test("signs and verifies verifier digests with local test keys only", async () => {
  const privateKey = deterministicTestPrivateKey(1);
  const wrongPrivateKey = deterministicTestPrivateKey(2);
  const publicKey = publicKeyFromPrivateKey(privateKey);
  const wrongPublicKey = publicKeyFromPrivateKey(wrongPrivateKey);
  const digest = report.verifierSignature.expected.signingDigest;
  const wrongDigest = report.workerSignature.expected.signingDigest;

  const signature = await signDigest({ digest, privateKey });
  assert.equal(verifyDigest({ digest, signature, publicKey }), true);
  assert.equal(verifyDigest({ digest, signature, publicKey: wrongPublicKey }), false);
  assert.equal(verifyDigest({ digest: wrongDigest, signature, publicKey }), false);
});

function mutatedEnvelopeVector(vector, documentsByName, envelopesByName) {
  const base = envelopesByName.get(vector.baseEnvelope);
  assert.ok(base, `unknown base envelope: ${vector.baseEnvelope}`);
  const document = structuredClone(documentsByName.get(base.objectName));
  const envelope = structuredClone(base.envelope);
  const mutation = vector.mutation ?? {};

  if (mutation.document) {
    Object.assign(document, mutation.document);
  }
  if (mutation.documentFromDocumentField) {
    for (const [target, source] of Object.entries(mutation.documentFromDocumentField)) {
      document[target] = document[source];
    }
  }
  if (mutation.envelope) {
    const { domainFrom, ...envelopeFields } = mutation.envelope;
    Object.assign(envelope, envelopeFields);
    if (domainFrom) {
      envelope.domain = DOMAIN_STRINGS[domainFrom];
      envelope.domainSeparator = domainSeparator(domainFrom);
    }
  }
  for (const field of mutation.deleteEnvelopeFields ?? []) {
    delete envelope[field];
  }

  const context = {};
  if (mutation.contextReplay) {
    context.seenSequences = new Set([localAlphaEnvelopeReplayKey(envelope)]);
  }

  return { document, envelope, context };
}

function mutatedTransactionVector(vector, documentsByName, transactionsByName) {
  const base = transactionsByName.get(vector.baseTransaction);
  assert.ok(base, `unknown base transaction: ${vector.baseTransaction}`);
  const document = structuredClone(documentsByName.get(base.objectName));
  const envelope = structuredClone(base.envelope);
  const mutation = vector.mutation ?? {};

  if (mutation.document) {
    Object.assign(document, mutation.document);
  }
  if (mutation.envelope) {
    Object.assign(envelope, mutation.envelope);
  }
  for (const field of mutation.deleteEnvelopeFields ?? []) {
    delete envelope[field];
  }

  const context = mutation.context ? { ...mutation.context } : {};
  if (mutation.contextReplay) {
    context.seenNonces = new Set([localTransactionReplayKey(envelope)]);
  }

  return { document, envelope, context };
}

function withoutField(document, field) {
  const copy = structuredClone(document);
  delete copy[field];
  return copy;
}
