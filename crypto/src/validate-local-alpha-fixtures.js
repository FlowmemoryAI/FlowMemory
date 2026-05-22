import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const defaultFixturePath = resolve(import.meta.dirname, "..", "fixtures", "local-alpha-objects.json");

export function validateLocalAlphaFixtures(fixturePath = defaultFixturePath) {
  const fixture = readJson(fixturePath);
  assert.equal(fixture.schema, "flowmemory.crypto.local-alpha-object-fixtures.v0");

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

  let documentCount = 0;
  for (const vector of fixture.positive) {
    validateDocument(vector.schemaPath, vector.document, vector.name);
    documentCount += 1;
  }

  let envelopeCount = 0;
  for (const vector of fixture.envelopes.positive) {
    validateDocument(vector.schemaPath, vector.envelope, vector.name);
    envelopeCount += 1;
  }

  let transactionCount = 0;
  for (const vector of fixture.transactions?.positive ?? []) {
    validateDocument(vector.schemaPath, vector.envelope, vector.name);
    transactionCount += 1;
  }

  return {
    documents: documentCount,
    envelopes: envelopeCount,
    transactions: transactionCount,
    schemas: validators.size
  };
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

if (fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const result = validateLocalAlphaFixtures(process.argv[2]);
  console.log(
    `FLOWMEMORY_LOCAL_ALPHA_FIXTURES_OK documents=${result.documents} envelopes=${result.envelopes} transactions=${result.transactions} schemas=${result.schemas}`
  );
}
