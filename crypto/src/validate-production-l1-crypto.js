import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

import {
  bridgeSourceEventReplayKey,
  flowchainTransactionId,
  localAlphaObjectId,
  localTransactionReplayKey,
  verifyFlowchainEnvelope
} from "./index.js";

const defaultFixturePath = resolve(import.meta.dirname, "..", "fixtures", "production-l1-vectors.json");

export function validateProductionL1Crypto(fixturePath = defaultFixturePath) {
  const fixture = readJson(fixturePath);
  assert.equal(fixture.schema, "flowmemory.crypto.production-l1-vectors.v0");
  assertNoSecrets(fixture);
  assertRuntimeValidationHasNoWalletImport();

  const fixtureDir = resolve(fixturePath, "..");
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats(ajv);
  const validators = new Map();

  const positives = new Map();
  for (const vector of fixture.positive) {
    validateDocument({ ajv, validators, fixtureDir, document: vector.document, label: vector.name });
    validateEnvelope({ ajv, validators, fixtureDir, envelope: vector.envelope, label: vector.name });
    assert.equal(localAlphaObjectId(vector.document), vector.expected.objectId, `${vector.name} object id`);
    assert.equal(vector.envelope.payloadHash, vector.expected.payloadHash, `${vector.name} payload hash`);
    assert.equal(vector.envelope.envelopeId, vector.expected.envelopeId, `${vector.name} envelope id`);
    assert.equal(vector.envelope.signingDigest, vector.expected.signingDigest, `${vector.name} signing digest`);
    assert.equal(flowchainTransactionId(vector.envelope), vector.expected.transactionId, `${vector.name} tx id`);

    const result = verifyFlowchainEnvelope({
      document: vector.document,
      envelope: vector.envelope,
      context: {
        chainId: fixture.chainId,
        networkProfile: fixture.networkProfile,
        expectedNonce: vector.envelope.nonce
      }
    });
    assert.equal(result.ok, true, `${vector.name}: ${result.failureCodes.join(", ")}`);
    assert.equal(result.transactionId, vector.expected.transactionId, `${vector.name} runtime tx id`);
    assert.equal(result.payloadHash, vector.expected.payloadHash, `${vector.name} runtime payload hash`);
    positives.set(vector.name, vector);
  }

  for (const vector of fixture.negative) {
    const base = positives.get(vector.base);
    assert.ok(base, `unknown negative base: ${vector.base}`);
    const document = { ...base.document, ...(vector.mutation.document ?? {}) };
    const envelope = { ...base.envelope, ...(vector.mutation.envelope ?? {}) };
    const context = negativeContext({ fixture, base, envelope, vector });
    const result = verifyFlowchainEnvelope({ document, envelope, context });
    assert.equal(result.ok, false, vector.name);
    assert.deepEqual(result.failureCodes.sort(), vector.expectFailureCodes, vector.name);
    assert.ok(
      result.failureCodes.includes(vector.primaryFailureCode),
      `${vector.name} missing ${vector.primaryFailureCode}: ${result.failureCodes.join(", ")}`
    );
  }

  return {
    positive: fixture.positive.length,
    negative: fixture.negative.length,
    hashHelpers: Object.keys(fixture.hashHelpers).length,
    schemas: validators.size
  };
}

function validateDocument({ ajv, validators, fixtureDir, document, label }) {
  const schemaPath = documentSchemaPath(document.schema);
  const validate = schemaValidator({ ajv, validators, path: resolve(fixtureDir, schemaPath) });
  if (!validate(document)) {
    throw new Error(`${label} document failed schema validation: ${ajv.errorsText(validate.errors)}`);
  }
}

function validateEnvelope({ ajv, validators, fixtureDir, envelope, label }) {
  const validate = schemaValidator({
    ajv,
    validators,
    path: resolve(fixtureDir, "../../schemas/flowmemory/local-transaction-envelope.schema.json")
  });
  if (!validate(envelope)) {
    throw new Error(`${label} envelope failed schema validation: ${ajv.errorsText(validate.errors)}`);
  }
}

function schemaValidator({ ajv, validators, path }) {
  let validate = validators.get(path);
  if (!validate) {
    validate = ajv.compile(readJson(path));
    validators.set(path, validate);
  }
  return validate;
}

function documentSchemaPath(schema) {
  if (schema.startsWith("flowchain.product_")) {
    return "../../schemas/flowmemory/product-transaction.schema.json";
  }
  const bySchema = {
    "flowchain.local_balance_record.v0": "../../schemas/flowmemory/local-balance-record.schema.json",
    "flowchain.bridge_credit.v0": "../../schemas/flowmemory/bridge-credit.schema.json",
    "flowmemory.bridge_withdrawal_intent.v0": "../../schemas/flowmemory/bridge-withdrawal-intent.schema.json",
    "flowchain.finality_receipt.v0": "../../schemas/flowmemory/finality-receipt.schema.json"
  };
  const path = bySchema[schema];
  if (!path) {
    throw new Error(`no schema path for ${schema}`);
  }
  return path;
}

function negativeContext({ fixture, base, envelope, vector }) {
  const context = {
    chainId: fixture.chainId,
    networkProfile: fixture.networkProfile,
    expectedNonce: envelope.nonce,
    ...(vector.mutation.context ?? {})
  };
  switch (vector.mutation.contextKind) {
    case "duplicate-nonce":
      context.seenNonces = new Set([localTransactionReplayKey(base.envelope)]);
      break;
    case "duplicate-tx-id":
      context.seenTransactionIds = new Set([base.envelope.transactionId]);
      break;
    case "duplicate-bridge-source-event":
      context.bridgeSourceEvent = fixture.bridgeSourceEvent;
      context.seenBridgeSourceEvents = new Set([bridgeSourceEventReplayKey(fixture.bridgeSourceEvent)]);
      break;
    default:
      break;
  }
  return context;
}

function assertRuntimeValidationHasNoWalletImport() {
  const runtimeSource = readFileSync(resolve(import.meta.dirname, "runtime-validation.js"), "utf8");
  assert.doesNotMatch(runtimeSource, /wallet\.js|wallet-cli|vault/i, "runtime validation must not import wallet/vault code");
}

function assertNoSecrets(value) {
  const serialized = JSON.stringify(value);
  assert.doesNotMatch(
    serialized,
    /privateKey|private_key|seedPhrase|seed phrase|mnemonic|ciphertext|authTag|password|rpc[-_]?credential|rpc[-_]?url|api[-_]?key|webhook/i,
    "production-L1 crypto fixture contains secret-shaped material"
  );
  assert.doesNotMatch(
    serialized,
    /https:\/\/hooks\.slack\.com|https:\/\/discord\.com\/api\/webhooks/i,
    "production-L1 crypto fixture contains webhook-shaped material"
  );
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

if (fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const result = validateProductionL1Crypto(process.argv[2]);
  console.log(
    `FLOWCHAIN_PRODUCTION_L1_CRYPTO_OK positive=${result.positive} negative=${result.negative} hashHelpers=${result.hashHelpers} schemas=${result.schemas}`
  );
}
