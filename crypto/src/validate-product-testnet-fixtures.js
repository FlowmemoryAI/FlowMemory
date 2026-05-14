import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

import {
  localAlphaObjectId,
  localTransactionEnvelopeHash,
  localTransactionEnvelopeInput,
  localTransactionEnvelopePayload,
  localTransactionReplayKey,
  validateLocalTransactionEnvelope
} from "./index.js";

const defaultFixturePath = resolve(import.meta.dirname, "..", "fixtures", "product-testnet-transactions.json");

export function validateProductTestnetFixtures(fixturePath = defaultFixturePath) {
  const fixture = readJson(fixturePath);
  assert.equal(fixture.schema, "flowmemory.crypto.product-testnet-transaction-fixtures.v0");

  const fixtureDir = resolve(fixturePath, "..");
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats(ajv);
  const validators = new Map();
  const validateDocument = (schemaPath, document, label) => {
    const absoluteSchemaPath = resolve(fixtureDir, schemaPath);
    let validate = validators.get(absoluteSchemaPath);
    if (!validate) {
      validate = ajv.compile(readJson(absoluteSchemaPath));
      validators.set(absoluteSchemaPath, validate);
    }
    if (!validate(document)) {
      throw new Error(`${label} failed schema validation: ${ajv.errorsText(validate.errors)}`);
    }
  };

  assertNoSecrets(fixture.publicMetadata);

  const documentsByName = new Map();
  for (const vector of fixture.documents.positive) {
    validateDocument(vector.schemaPath, vector.document, vector.name);
    assert.equal(localAlphaObjectId(vector.document), vector.expected, vector.name);
    assert.equal(vector.document[vector.idField], vector.expected, `${vector.name} document id`);
    documentsByName.set(vector.name, vector.document);
  }

  const transactionsByName = new Map();
  for (const vector of fixture.transactions.positive) {
    const document = documentsByName.get(vector.objectName);
    assert.ok(document, `unknown product transaction document: ${vector.objectName}`);
    validateDocument(vector.schemaPath, vector.envelope, vector.name);
    assert.equal(localTransactionEnvelopeHash(vector.input), vector.expected.envelopeId, vector.name);
    assert.deepEqual(localTransactionEnvelopePayload(vector.input), {
      structHash: vector.expected.envelopeId,
      signingDigest: vector.expected.signingDigest
    });
    assert.deepEqual(localTransactionEnvelopeInput(vector.envelope), vector.input);
    assert.equal(vector.envelope.payloadHash, vector.expected.payloadHash, `${vector.name} payload hash`);
    assert.deepEqual(
      validateLocalTransactionEnvelope({
        document,
        envelope: vector.envelope,
        context: { chainId: fixture.chainId, expectedNonce: vector.envelope.nonce }
      }),
      { valid: true, errors: [] },
      vector.name
    );
    transactionsByName.set(vector.name, vector);
  }

  for (const vector of fixture.transactions.negative) {
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

  return {
    documents: fixture.documents.positive.length,
    transactions: fixture.transactions.positive.length,
    negativeTransactions: fixture.transactions.negative.length,
    schemas: validators.size
  };
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

function assertNoSecrets(value) {
  assert.doesNotMatch(
    JSON.stringify(value),
    /privateKey|mnemonic|seed|ciphertext|authTag|password/i,
    "public product-testnet wallet metadata must not include secrets"
  );
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

if (fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const result = validateProductTestnetFixtures(process.argv[2]);
  console.log(
    `FLOWCHAIN_PRODUCT_TESTNET_TRANSACTIONS_OK documents=${result.documents} transactions=${result.transactions} negativeTransactions=${result.negativeTransactions} schemas=${result.schemas}`
  );
}
