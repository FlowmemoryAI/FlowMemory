import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

import {
  localTransactionReplayKey,
  validateLocalTransactionEnvelope
} from "./transactions.js";

const defaultFixturePath = resolve(import.meta.dirname, "..", "fixtures", "local-transaction-vectors.json");

export function validateLocalTransactionFixtures(fixturePath = defaultFixturePath) {
  const fixture = readJson(fixturePath);
  assert.equal(fixture.schema, "flowmemory.crypto.local-transaction-vectors.v0");

  const fixtureDir = resolve(fixturePath, "..");
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats(ajv);
  const transactionEnvelopeSchema = ajv.compile(
    readJson(resolve(fixtureDir, "../../schemas/flowmemory/local-transaction-envelope.schema.json"))
  );
  const walletPublicSchema = ajv.compile(
    readJson(resolve(fixtureDir, "../../schemas/flowmemory/local-wallet-public-metadata.schema.json"))
  );

  assert.equal(walletPublicSchema(fixture.publicWalletMetadata), true, ajv.errorsText(walletPublicSchema.errors));

  let positive = 0;
  for (const vector of fixture.positive) {
    assert.equal(transactionEnvelopeSchema(vector.envelope), true, ajv.errorsText(transactionEnvelopeSchema.errors));
    const result = validateLocalTransactionEnvelope({
      envelope: vector.envelope,
      context: { expectedChainId: fixture.chainId }
    });
    assert.deepEqual(result, { valid: true, errors: [] }, vector.name);
    positive += 1;
  }

  let negative = 0;
  const positives = new Map(fixture.positive.map((entry) => [entry.name, entry.envelope]));
  for (const vector of fixture.negative) {
    const envelope = mutateEnvelope(positives.get(vector.baseEnvelope), vector.mutation);
    const context = { expectedChainId: fixture.chainId };
    if (vector.mutation?.contextReplay) {
      context.seenNonces = new Set([localTransactionReplayKey(envelope)]);
    }
    const result = validateLocalTransactionEnvelope({ envelope, context });
    assert.equal(result.valid, false, vector.name);
    for (const expectedError of vector.expectErrors) {
      assert.ok(
        result.errors.includes(expectedError),
        `${vector.name} expected ${expectedError}, got ${result.errors.join(", ")}`
      );
    }
    negative += 1;
  }

  return { positive, negative };
}

function mutateEnvelope(baseEnvelope, mutation = {}) {
  assert.ok(baseEnvelope, "unknown base envelope");
  const envelope = structuredClone(baseEnvelope);

  if (mutation.envelope) {
    Object.assign(envelope, mutation.envelope);
  }
  if (mutation.signer) {
    Object.assign(envelope.signer, mutation.signer);
  }
  if (mutation.payload) {
    envelope.payload = {
      ...envelope.payload,
      ...mutation.payload
    };
  }
  if (mutation.payloadObject) {
    envelope.payload.object = {
      ...envelope.payload.object,
      ...mutation.payloadObject
    };
  }
  if (mutation.deleteSignerFields) {
    for (const field of mutation.deleteSignerFields) {
      delete envelope.signer[field];
    }
  }

  return envelope;
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

if (fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const result = validateLocalTransactionFixtures(process.argv[2]);
  console.log(`FLOWMEMORY_LOCAL_TRANSACTION_VECTORS_OK positive=${result.positive} negative=${result.negative}`);
}
