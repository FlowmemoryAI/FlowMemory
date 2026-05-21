#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import Ajv2020 from "ajv/dist/2020.js";

const root = process.cwd();
const schemaPath = resolve(root, "schemas/flowmemory/agent-bonds-launch-approval.schema.json");
const externalReviewSchemaPath = resolve(root, "schemas/flowmemory/agent-bonds-external-review-attestation.schema.json");
const operatorSeparationSchemaPath = resolve(root, "schemas/flowmemory/agent-bonds-operator-separation-attestation.schema.json");
const runtimeEvidenceSchemaPath = resolve(root, "schemas/flowmemory/agent-bonds-runtime-evidence-attestation.schema.json");
const goNoGoSchemaPath = resolve(root, "schemas/flowmemory/agent-bonds-go-no-go-attestation.schema.json");

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function requireExisting(path, label, issues) {
  if (!existsSync(resolve(root, path))) {
    issues.push(`${label} is missing: ${path}`);
    return false;
  }
  return true;
}

function placeholder(value) {
  return typeof value === "string" && /PENDING|template/i.test(value);
}

function validateWithSchema(ajv, schema, value, label, issues) {
  const validate = ajv.compile(schema);
  if (!validate(value)) {
    issues.push(`${label} schema validation failed: ${JSON.stringify(validate.errors)}`);
    return false;
  }
  return true;
}

function validateAttestation(ajv, approvalSection, artifactPath, schema, label, issues) {
  if (!requireExisting(artifactPath, `${label} artifact`, issues)) {
    return null;
  }
  const artifact = readJson(resolve(root, artifactPath));
  if (!validateWithSchema(ajv, schema, artifact, `${label} artifact`, issues)) {
    return null;
  }

  if (artifact.completed !== undefined && approvalSection.completed !== artifact.completed) {
    issues.push(`${label} completed flag mismatch between launch approval and artifact`);
  }
  if (artifact.multiOperatorRunCompleted !== undefined && approvalSection.multiOperatorRunCompleted !== artifact.multiOperatorRunCompleted) {
    issues.push(`${label} multiOperatorRunCompleted mismatch between launch approval and artifact`);
  }
  if (artifact.approved !== undefined && approvalSection.approved !== artifact.approved) {
    issues.push(`${label} approved mismatch between launch approval and artifact`);
  }

  const pathKeys = ["reportPath", "checklistPath", "evidencePath", "decisionPath"];
  for (const key of pathKeys) {
    if (approvalSection[key] !== undefined && approvalSection[key] !== artifactPath) {
      issues.push(`${label} path mismatch between launch approval and artifact`);
    }
  }

  if (artifact.docPath !== undefined) {
    requireExisting(artifact.docPath, `${label} docPath`, issues);
  }
  if (artifact.reportPath !== undefined) {
    requireExisting(artifact.reportPath, `${label} reportPath`, issues);
  }
  if (artifact.checklistPath !== undefined) {
    requireExisting(artifact.checklistPath, `${label} checklistPath`, issues);
  }
  if (artifact.evidencePath !== undefined) {
    requireExisting(artifact.evidencePath, `${label} evidencePath`, issues);
  }
  if (artifact.decisionPath !== undefined) {
    requireExisting(artifact.decisionPath, `${label} decisionPath`, issues);
  }

  for (const value of Object.values(artifact)) {
    if (placeholder(value)) {
      issues.push(`${label} artifact still contains placeholder value: ${value}`);
    }
  }

  return artifact;
}

function main() {
  const approvalPath = resolve(root, process.argv[2] ?? "fixtures/agent-bonds/launch-approval.template.json");
  const pilotConfigPath = resolve(root, process.argv[3] ?? "fixtures/agent-bonds/pilot-config.template.json");
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  const approvalSchema = readJson(schemaPath);
  const externalReviewSchema = readJson(externalReviewSchemaPath);
  const operatorSeparationSchema = readJson(operatorSeparationSchemaPath);
  const runtimeEvidenceSchema = readJson(runtimeEvidenceSchemaPath);
  const goNoGoSchema = readJson(goNoGoSchemaPath);
  const approval = readJson(approvalPath);
  const pilotConfig = readJson(pilotConfigPath);

  if (!validateWithSchema(ajv, approvalSchema, approval, "launch approval", [])) {
    const validate = ajv.compile(approvalSchema);
    validate(approval);
    throw new Error(`Launch approval schema validation failed:\n${JSON.stringify(validate.errors, null, 2)}`);
  }

  const issues = [];
  requireExisting(approval.pilotConfigPath, "pilotConfigPath", issues);
  requireExisting(approval.readinessReportPath, "readinessReportPath", issues);
  requireExisting(approval.operatorBundlePath, "operatorBundlePath", issues);

  if (approval.externalReview.completed !== true) {
    issues.push("externalReview.completed must be true");
  }
  if (approval.operatorSeparation.completed !== true) {
    issues.push("operatorSeparation.completed must be true");
  }
  if (approval.runtimeEvidence.multiOperatorRunCompleted !== true) {
    issues.push("runtimeEvidence.multiOperatorRunCompleted must be true");
  }
  if (approval.goNoGoDecision.approved !== true) {
    issues.push("goNoGoDecision.approved must be true");
  }

  for (const value of [
    approval.externalReview.reviewer,
    approval.externalReview.completedAt,
    approval.operatorSeparation.signedBy,
    approval.operatorSeparation.completedAt,
    approval.runtimeEvidence.completedAt,
    approval.goNoGoDecision.decisionOwner,
    approval.goNoGoDecision.approvedAt,
  ]) {
    if (placeholder(value)) {
      issues.push(`placeholder value present: ${value}`);
    }
  }

  if (approval.network.chainId !== pilotConfig.network.chainId) {
    issues.push("launch approval chainId must match pilot config chainId");
  }
  if (approval.network.networkName !== pilotConfig.network.networkName) {
    issues.push("launch approval networkName must match pilot config networkName");
  }

  const readiness = readJson(resolve(root, approval.readinessReportPath));
  if (readiness.ok !== true) {
    issues.push("readiness report must be green");
  }

  validateAttestation(ajv, approval.externalReview, approval.externalReview.reportPath, externalReviewSchema, "externalReview", issues);
  validateAttestation(ajv, approval.operatorSeparation, approval.operatorSeparation.checklistPath, operatorSeparationSchema, "operatorSeparation", issues);
  validateAttestation(ajv, approval.runtimeEvidence, approval.runtimeEvidence.evidencePath, runtimeEvidenceSchema, "runtimeEvidence", issues);
  validateAttestation(ajv, approval.goNoGoDecision, approval.goNoGoDecision.decisionPath, goNoGoSchema, "goNoGoDecision", issues);

  if (issues.length > 0) {
    throw new Error(`Agent Bonds public launch validation failed:\n- ${issues.join("\n- ")}`);
  }

  console.log(JSON.stringify({
    service: "flowmemory-agent-bonds-public-launch-validate",
    approvalPath,
    pilotConfigPath,
    ok: true,
  }, null, 2));
}

main();
