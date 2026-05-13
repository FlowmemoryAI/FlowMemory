#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  attestationEnvelopeHash,
  flowPulseEventArgsHash,
  flowPulseObservationId,
  receiptHash,
  verifierReportHash
} from "./index.js";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");

function readJson(path) {
  return JSON.parse(readFileSync(resolve(root, path), "utf8"));
}

const flowPulse = readJson("fixtures/sample-flowpulse.json");
const observation = readJson("fixtures/sample-observation.json");
const report = readJson("fixtures/sample-report.json");

const observationId = flowPulseObservationId(observation.input);
const eventArgsHash = flowPulseEventArgsHash(flowPulse.input);
const computedReceiptHash = receiptHash({
  ...observation.receipt,
  observationId,
  eventArgsHash
});
const reportId = verifierReportHash({
  ...report.input,
  observationId,
  receiptHash: computedReceiptHash
});
const computedAttestationEnvelopeHash = attestationEnvelopeHash({
  ...report.attestationEnvelope.input,
  subjectHash: reportId
});

console.log(
  JSON.stringify(
    {
      pulseId: flowPulse.expected.pulseId,
      observationId,
      eventArgsHash,
      receiptHash: computedReceiptHash,
      artifactRoot: observation.receipt.artifactRoot,
      reportId,
      attestationEnvelopeHash: computedAttestationEnvelopeHash
    },
    null,
    2
  )
);
