import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import test from "node:test";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
process.chdir(REPO_ROOT);
const READINESS_REPORT_PATH = resolve(REPO_ROOT, "devnet/local/agent-bonds-readiness/agent-bonds-readiness-report.json");

const maybeMetaTest = process.env.FLOWMEMORY_SKIP_AGENT_BONDS_META === "1" ? test.skip : test;


function seedGreenReadinessReport(): void {
  writeFileSync(READINESS_REPORT_PATH, JSON.stringify({ schema: "flowmemory.agent_bonds.readiness_report.v1", ok: true, steps: [] }, null, 2));
}

function runNodeScript(args: string[]): { status: number | null; stdout: string; stderr: string } {
  const result = spawnSync("node", args, {
    cwd: REPO_ROOT,
    encoding: "utf8",
  });
  return {
    status: result.status,
    stdout: result.stdout,
    stderr: result.stderr,
  };
}

maybeMetaTest("public launch validator fails on unresolved external sign-offs", () => {
  const result = runNodeScript([
    "infra/scripts/agent-bonds-public-launch-validate.mjs",
    "fixtures/agent-bonds/launch-approval.template.json",
    "fixtures/agent-bonds/pilot-config.template.json",
  ]);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /externalReview\.completed must be true/);
  assert.match(result.stderr, /operatorSeparation\.completed must be true/);
  assert.match(result.stderr, /runtimeEvidence\.multiOperatorRunCompleted must be true/);
  assert.match(result.stderr, /goNoGoDecision\.approved must be true/);
});

maybeMetaTest("public launch blocker verifier confirms only external sign-offs remain", () => {
  seedGreenReadinessReport();
  const result = runNodeScript([
    "infra/scripts/agent-bonds-public-launch-blockers.mjs",
  ]);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /external-only-blockers-confirmed/);
});

maybeMetaTest("goal audit confirms repo-side launch work is complete and only external signoff remains", () => {
  seedGreenReadinessReport();
  const result = runNodeScript([
    "infra/scripts/agent-bonds-goal-audit.mjs",
  ]);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /repoSideComplete/);
});

maybeMetaTest("public launch validator passes for a completed synthetic approval packet", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-agent-bonds-public-launch-"));
  const readinessPath = join(dir, "readiness.json");
  const externalReviewDocPath = join(dir, "external-review.md");
  const operatorChecklistDocPath = join(dir, "operator-checklist.md");
  const runtimeEvidenceDocPath = join(dir, "runtime-evidence.md");
  const decisionDocPath = join(dir, "go-no-go.md");
  const externalReviewArtifactPath = join(dir, "external-review.json");
  const operatorSeparationArtifactPath = join(dir, "operator-separation.json");
  const runtimeEvidenceArtifactPath = join(dir, "runtime-evidence.json");
  const decisionArtifactPath = join(dir, "go-no-go.json");
  const operatorBundlePath = join(dir, "bundle");
  const approvalPath = join(dir, "launch-approval.json");

  mkdirSync(operatorBundlePath, { recursive: true });
  writeFileSync(readinessPath, JSON.stringify({ schema: "flowmemory.agent_bonds.readiness_report.v1", ok: true }, null, 2));
  writeFileSync(externalReviewDocPath, "completed external review\n");
  writeFileSync(operatorChecklistDocPath, "completed operator separation\n");
  writeFileSync(runtimeEvidenceDocPath, "completed multi-operator runtime evidence\n");
  writeFileSync(decisionDocPath, "GO\n");

  writeFileSync(externalReviewArtifactPath, JSON.stringify({
    schema: "flowmemory.agent_bonds_external_review_attestation.v1",
    completed: true,
    reviewer: "Independent Reviewer LLC",
    reportPath: externalReviewDocPath,
    docPath: externalReviewDocPath,
    completedAt: "2026-05-20T23:00:00Z"
  }, null, 2));
  writeFileSync(operatorSeparationArtifactPath, JSON.stringify({
    schema: "flowmemory.agent_bonds_operator_separation_attestation.v1",
    completed: true,
    checklistPath: operatorChecklistDocPath,
    docPath: operatorChecklistDocPath,
    signedBy: "Owner Signoff",
    completedAt: "2026-05-20T23:05:00Z"
  }, null, 2));
  writeFileSync(runtimeEvidenceArtifactPath, JSON.stringify({
    schema: "flowmemory.agent_bonds_runtime_evidence_attestation.v1",
    multiOperatorRunCompleted: true,
    evidencePath: runtimeEvidenceDocPath,
    docPath: runtimeEvidenceDocPath,
    completedAt: "2026-05-20T23:10:00Z"
  }, null, 2));
  writeFileSync(decisionArtifactPath, JSON.stringify({
    schema: "flowmemory.agent_bonds_go_no_go_attestation.v1",
    approved: true,
    decisionOwner: "Owner",
    decisionPath: decisionDocPath,
    docPath: decisionDocPath,
    approvedAt: "2026-05-20T23:15:00Z"
  }, null, 2));

  writeFileSync(approvalPath, JSON.stringify({
    schema: "flowmemory.agent_bonds_launch_approval.v1",
    network: {
      chainId: 8453,
      networkName: "base-mainnet-capped-pilot",
    },
    pilotConfigPath: "fixtures/agent-bonds/pilot-config.template.json",
    readinessReportPath: readinessPath,
    operatorBundlePath,
    externalReview: {
      completed: true,
      reviewer: "Independent Reviewer LLC",
      reportPath: externalReviewArtifactPath,
      completedAt: "2026-05-20T23:00:00Z",
    },
    operatorSeparation: {
      completed: true,
      checklistPath: operatorSeparationArtifactPath,
      signedBy: "Owner Signoff",
      completedAt: "2026-05-20T23:05:00Z",
    },
    runtimeEvidence: {
      multiOperatorRunCompleted: true,
      evidencePath: runtimeEvidenceArtifactPath,
      completedAt: "2026-05-20T23:10:00Z",
    },
    goNoGoDecision: {
      approved: true,
      decisionOwner: "Owner",
      decisionPath: decisionArtifactPath,
      approvedAt: "2026-05-20T23:15:00Z",
    },
  }, null, 2));

  const result = runNodeScript([
    "infra/scripts/agent-bonds-public-launch-validate.mjs",
    approvalPath,
    "fixtures/agent-bonds/pilot-config.template.json",
  ]);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /flowmemory-agent-bonds-public-launch-validate/);
});

test("public launch assembler produces an approval packet that can be validated", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-agent-bonds-assemble-"));
  const readinessPath = join(dir, "readiness.json");
  const externalReviewDocPath = join(dir, "external-review.md");
  const operatorChecklistDocPath = join(dir, "operator-checklist.md");
  const runtimeEvidenceDocPath = join(dir, "runtime-evidence.md");
  const decisionDocPath = join(dir, "go-no-go.md");
  const externalReviewArtifactPath = join(dir, "external-review.json");
  const operatorSeparationArtifactPath = join(dir, "operator-separation.json");
  const runtimeEvidenceArtifactPath = join(dir, "runtime-evidence.json");
  const decisionArtifactPath = join(dir, "go-no-go.json");
  const operatorBundlePath = join(dir, "bundle");
  const assembledApprovalPath = join(dir, "launch-approval.generated.json");

  mkdirSync(operatorBundlePath, { recursive: true });
  writeFileSync(readinessPath, JSON.stringify({ schema: "flowmemory.agent_bonds.readiness_report.v1", ok: true }, null, 2));
  writeFileSync(externalReviewDocPath, "completed external review\n");
  writeFileSync(operatorChecklistDocPath, "completed operator separation\n");
  writeFileSync(runtimeEvidenceDocPath, "completed multi-operator runtime evidence\n");
  writeFileSync(decisionDocPath, "GO\n");
  writeFileSync(externalReviewArtifactPath, JSON.stringify({
    schema: "flowmemory.agent_bonds_external_review_attestation.v1",
    completed: true,
    reviewer: "Independent Reviewer LLC",
    reportPath: externalReviewDocPath,
    docPath: externalReviewDocPath,
    completedAt: "2026-05-20T23:00:00Z"
  }, null, 2));
  writeFileSync(operatorSeparationArtifactPath, JSON.stringify({
    schema: "flowmemory.agent_bonds_operator_separation_attestation.v1",
    completed: true,
    checklistPath: operatorChecklistDocPath,
    docPath: operatorChecklistDocPath,
    signedBy: "Owner Signoff",
    completedAt: "2026-05-20T23:05:00Z"
  }, null, 2));
  writeFileSync(runtimeEvidenceArtifactPath, JSON.stringify({
    schema: "flowmemory.agent_bonds_runtime_evidence_attestation.v1",
    multiOperatorRunCompleted: true,
    evidencePath: runtimeEvidenceDocPath,
    docPath: runtimeEvidenceDocPath,
    completedAt: "2026-05-20T23:10:00Z"
  }, null, 2));
  writeFileSync(decisionArtifactPath, JSON.stringify({
    schema: "flowmemory.agent_bonds_go_no_go_attestation.v1",
    approved: true,
    decisionOwner: "Owner",
    decisionPath: decisionDocPath,
    docPath: decisionDocPath,
    approvedAt: "2026-05-20T23:15:00Z"
  }, null, 2));

  const assemble = runNodeScript([
    "infra/scripts/agent-bonds-public-launch-assemble.mjs",
    assembledApprovalPath,
    "fixtures/agent-bonds/pilot-config.template.json",
    externalReviewArtifactPath,
    operatorSeparationArtifactPath,
    runtimeEvidenceArtifactPath,
    decisionArtifactPath,
    readinessPath,
    operatorBundlePath,
  ]);
  assert.equal(assemble.status, 0, assemble.stderr);
  assert.match(assemble.stdout, /flowmemory-agent-bonds-public-launch-assemble/);

  const validate = runNodeScript([
    "infra/scripts/agent-bonds-public-launch-validate.mjs",
    assembledApprovalPath,
    "fixtures/agent-bonds/pilot-config.template.json",
  ]);
  assert.equal(validate.status, 0, validate.stderr);
});
