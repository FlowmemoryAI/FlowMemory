import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  artifactFromChunks,
  attestationEnvelopeHash,
  canonicalJsonHash,
  contractPulseId,
  devnetBlockHash,
  domainSeparator,
  emptyMerkleRoot,
  flowPulseEventArgsHash,
  flowPulseObservationId,
  flowPulseSchemaId,
  indexerCursorId,
  merkleLeafHash,
  merkleRoot,
  receiptHash,
  rootCommitment,
  rootfieldNamespaceId,
  storageReceiptCommitmentHash,
  verifierIdentity,
  verifierReportHash,
  workReceiptId,
  workerIdentity
} from "./index.js";

const validators = Object.freeze({
  artifactFromChunks,
  attestationEnvelopeHash,
  canonicalJsonHash,
  contractPulseId,
  devnetBlockHash,
  domainSeparator: ({ domainName }) => domainSeparator(domainName),
  emptyMerkleRoot,
  flowPulseEventArgsHash,
  flowPulseObservationId,
  flowPulseSchemaId,
  indexerCursorId,
  merkleLeafHash,
  merkleRoot: ({ leaves }) => merkleRoot(leaves),
  receiptHash,
  rootCommitment,
  rootfieldNamespaceId,
  storageReceiptCommitmentHash,
  verifierIdentity,
  verifierReportHash,
  workReceiptId,
  workerIdentity
});

export function validateVectors(vectorPath = resolve(import.meta.dirname, "..", "fixtures", "vectors.json")) {
  const fixture = JSON.parse(readFileSync(vectorPath, "utf8"));
  assert.equal(fixture.schema, "flowmemory.crypto.test-vectors.v0");
  assert.equal(fixture.vectorCount, fixture.vectors.length);

  for (const vector of fixture.vectors) {
    const fn = validators[vector.function];
    assert.ok(fn, `unknown vector function: ${vector.function}`);
    const result = fn(vector.input);
    const actual = vector.select ? result[vector.select] : result;
    assert.equal(actual, vector.expected, vector.name);
  }

  return fixture.vectors.length;
}

if (fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const count = validateVectors(process.argv[2]);
  console.log(`FLOWMEMORY_CRYPTO_VECTORS_OK ${count}`);
}
