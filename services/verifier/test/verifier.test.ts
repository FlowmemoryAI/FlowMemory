import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { indexFlowPulseLogs, indexFlowPulseReceipts } from "../../indexer/src/index.ts";
import { loadIndexerFixtureLogs, loadIndexerFixtureReceipts } from "../../indexer/src/fixtures.ts";
import { loadVerifierArtifactFixture } from "../src/fixtures.ts";
import { readVerifierReports, writeVerifierReports } from "../src/persistence.ts";
import { verifyObservation, verifyObservations } from "../src/verifier.ts";

test("generates valid deterministic reports from fixture observations", () => {
  const indexerState = indexFlowPulseLogs(loadIndexerFixtureLogs());
  const reports = verifyObservations(indexerState.observations, loadVerifierArtifactFixture());
  assert.equal(reports.length, 1);
  assert.equal(reports[0].reportCore.status, "valid");
  assert.match(reports[0].reportId, /^0x[0-9a-f]{64}$/);
});

test("marks missing artifacts unresolved", () => {
  const [observation] = indexFlowPulseLogs(loadIndexerFixtureLogs()).observations;
  const report = verifyObservation(observation, {
    resolverPolicyId: "flowmemory.resolver.policy.v0.empty",
    artifactsByUri: {},
  });
  assert.equal(report.reportCore.status, "unresolved");
  assert.deepEqual(report.reportCore.reasonCodes, ["artifact.unavailable"]);
});

test("marks commitment mismatch as invalid", () => {
  const [observation] = indexFlowPulseLogs(loadIndexerFixtureLogs()).observations;
  const resolver = loadVerifierArtifactFixture();
  resolver.artifactsByUri[observation.uri] = {
    kind: "rootfield-registration",
    schemaHash: "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    metadataHash: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
  };

  const report = verifyObservation(observation, resolver);
  assert.equal(report.reportCore.status, "invalid");
  assert.equal(report.reportCore.reasonCodes.includes("commitment.mismatch"), true);
});

test("marks unknown pulse types unsupported", () => {
  const [observation] = indexFlowPulseLogs(loadIndexerFixtureLogs()).observations;
  const report = verifyObservation({ ...observation, pulseType: "99" }, loadVerifierArtifactFixture());
  assert.equal(report.reportCore.status, "unsupported");
});

test("marks artifacts over fixture policy size unresolved", () => {
  const [observation] = indexFlowPulseLogs(loadIndexerFixtureLogs()).observations;
  const report = verifyObservation(observation, {
    ...loadVerifierArtifactFixture(),
    maxArtifactBytes: 1,
  });

  assert.equal(report.reportCore.status, "unresolved");
  assert.deepEqual(report.reportCore.reasonCodes, ["artifact.too_large"]);
});

test("generates all verifier statuses from receipt fixtures", () => {
  const indexerState = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
    finalizedBlockNumber: "123458",
  });
  const reports = verifyObservations(indexerState.observations, loadVerifierArtifactFixture());
  const counts = reports.reduce<Record<string, number>>((acc, report) => {
    acc[report.reportCore.status] = (acc[report.reportCore.status] ?? 0) + 1;
    return acc;
  }, {});

  assert.deepEqual(counts, {
    invalid: 1,
    reorged: 1,
    unresolved: 1,
    unsupported: 1,
    valid: 3,
  });
});

test("persists deterministic verifier report JSON", () => {
  const indexerState = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
    finalizedBlockNumber: "123458",
  });
  const reports = verifyObservations(indexerState.observations, loadVerifierArtifactFixture());
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-verifier-"));
  const path = join(dir, "reports.json");

  try {
    writeVerifierReports(path, reports);
    const firstWrite = readFileSync(path, "utf8");
    writeVerifierReports(path, reports);
    const secondWrite = readFileSync(path, "utf8");
    const persisted = readVerifierReports(path);

    assert.equal(firstWrite, secondWrite);
    assert.equal(persisted.schema, "flowmemory.verifier.persistence.v0");
    assert.equal(persisted.reports.length, 7);
    assert.equal("createdAt" in persisted.reports[0].reportCore, false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("ships a verifier report JSON schema fixture", () => {
  const schemaPath = join(process.cwd(), "fixtures", "verification-report.schema.json");
  const schema = JSON.parse(readFileSync(schemaPath, "utf8")) as { $id: string };
  assert.equal(schema.$id, "flowmemory.verifier.report.v0");
});
