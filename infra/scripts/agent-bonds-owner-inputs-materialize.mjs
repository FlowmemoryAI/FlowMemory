#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const root = process.cwd();

function readJson(path) {
  return JSON.parse(readFileSync(resolve(root, path), "utf8"));
}

function writeJson(path, value) {
  const resolved = resolve(root, path);
  mkdirSync(dirname(resolved), { recursive: true });
  writeFileSync(resolved, `${JSON.stringify(value, null, 2)}\n`);
  return resolved;
}

function main() {
  const ownerInputsPath = process.argv[2] ?? "fixtures/agent-bonds/owner-inputs.template.json";
  const pilotConfigPath = process.argv[3] ?? "fixtures/agent-bonds/pilot-config.generated.json";
  const externalReviewPath = process.argv[4] ?? "fixtures/agent-bonds/approvals/external-review.generated.json";
  const operatorSeparationPath = process.argv[5] ?? "fixtures/agent-bonds/approvals/operator-separation.generated.json";
  const runtimeEvidencePath = process.argv[6] ?? "fixtures/agent-bonds/approvals/runtime-evidence.generated.json";
  const goNoGoPath = process.argv[7] ?? "fixtures/agent-bonds/approvals/go-no-go.generated.json";
  const launchApprovalPath = process.argv[8] ?? "fixtures/agent-bonds/launch-approval.generated.json";
  const readinessReportPath = process.argv[9] ?? "local-runtime/local/agent-bonds-readiness/agent-bonds-readiness-report.json";
  const operatorBundlePath = process.argv[10] ?? "out/agent-bonds-operator-bundle";

  const ownerInputs = readJson(ownerInputsPath);

  const pilotConfig = {
    schema: "flowmemory.agent_bonds_pilot_config.v1",
    network: ownerInputs.network,
    contracts: ownerInputs.contracts,
    roles: {
      multisigOwners: ownerInputs.roles.multisigOwners,
      threshold: ownerInputs.roles.threshold,
      pauseGuardian: ownerInputs.roles.pauseGuardian,
      resolutionAuthority: ownerInputs.roles.resolutionAuthority,
      requesters: [ownerInputs.roles.requester],
      agents: [ownerInputs.roles.agent],
      verifiers: [ownerInputs.roles.designatedVerifier],
      confirmingVerifiers: [ownerInputs.roles.confirmingVerifier],
    },
    caps: ownerInputs.caps,
    policy: {
      policyId: "0x733a73a684bcb3791ba85b0bec92565825d06b89b9a868d81f634490efa85c40",
      requiredConfirmations: ownerInputs.policy.requiredConfirmations,
      minAvailabilityWindowSeconds: ownerInputs.policy.minAvailabilityWindowSeconds,
    },
    custody: {
      slitherPassed: true,
      readinessReportPath,
    },
    docs: {
      boundaryDoc: "docs/AGENT_BONDS_PUBLIC_LAUNCH_BOUNDARY.md",
      runbookDoc: "docs/OPERATIONS/AGENT_BONDS_CAPPED_PILOT_RUNBOOK.md",
      reviewDoc: "docs/reviews/AGENT_BONDS_V1_SECURITY_REVIEW.md",
    },
  };

  const externalReview = {
    schema: "flowmemory.agent_bonds_external_review_attestation.v1",
    completed: false,
    reviewer: ownerInputs.signoffs.externalReviewer,
    reportPath: "docs/reviews/AGENT_BONDS_EXTERNAL_AUDIT_REPORT.md",
    docPath: "docs/OPERATIONS/AGENT_BONDS_EXTERNAL_REVIEW_PACKET.md",
    completedAt: "PENDING",
    notes: "Generated from owner inputs. Replace completed/completedAt after independent external review is finished.",
  };

  const operatorSeparation = {
    schema: "flowmemory.agent_bonds_operator_separation_attestation.v1",
    completed: false,
    checklistPath: "docs/OPERATIONS/AGENT_BONDS_OPERATOR_SEPARATION_CHECKLIST.md",
    docPath: "docs/OPERATIONS/AGENT_BONDS_CAPPED_PILOT_RUNBOOK.md",
    signedBy: ownerInputs.signoffs.ownerSigner,
    completedAt: "PENDING",
    notes: "Generated from owner inputs. Replace completed/completedAt after real operator separation sign-off.",
  };

  const runtimeEvidence = {
    schema: "flowmemory.agent_bonds_runtime_evidence_attestation.v1",
    multiOperatorRunCompleted: false,
    evidencePath: "docs/reviews/AGENT_BONDS_MULTI_OPERATOR_RUNTIME_EVIDENCE.md",
    docPath: "docs/OPERATIONS/AGENT_BONDS_MONITORING_AND_RECOVERY.md",
    completedAt: "PENDING",
    notes: `Generated from owner inputs. Runtime evidence owner: ${ownerInputs.signoffs.runtimeOperator}. Replace after a real multi-operator rehearsal or run.`,
  };

  const goNoGoDecision = {
    schema: "flowmemory.agent_bonds_go_no_go_attestation.v1",
    approved: false,
    decisionOwner: ownerInputs.signoffs.goNoGoOwner,
    decisionPath: "docs/DECISIONS/AGENT_BONDS_CAPPED_PILOT_GO_NO_GO.md",
    docPath: "docs/OPERATIONS/AGENT_BONDS_PUBLIC_LAUNCH_APPROVAL.md",
    approvedAt: "PENDING",
    notes: "Generated from owner inputs. Replace approved/approvedAt after the final owner decision.",
  };

  writeJson(pilotConfigPath, pilotConfig);
  writeJson(externalReviewPath, externalReview);
  writeJson(operatorSeparationPath, operatorSeparation);
  writeJson(runtimeEvidencePath, runtimeEvidence);
  writeJson(goNoGoPath, goNoGoDecision);

  const launchApproval = {
    schema: "flowmemory.agent_bonds_launch_approval.v1",
    network: ownerInputs.network,
    pilotConfigPath,
    readinessReportPath,
    operatorBundlePath,
    externalReview: {
      completed: externalReview.completed,
      reviewer: externalReview.reviewer,
      reportPath: externalReviewPath,
      completedAt: externalReview.completedAt,
    },
    operatorSeparation: {
      completed: operatorSeparation.completed,
      checklistPath: operatorSeparationPath,
      signedBy: operatorSeparation.signedBy,
      completedAt: operatorSeparation.completedAt,
    },
    runtimeEvidence: {
      multiOperatorRunCompleted: runtimeEvidence.multiOperatorRunCompleted,
      evidencePath: runtimeEvidencePath,
      completedAt: runtimeEvidence.completedAt,
    },
    goNoGoDecision: {
      approved: goNoGoDecision.approved,
      decisionOwner: goNoGoDecision.decisionOwner,
      decisionPath: goNoGoPath,
      approvedAt: goNoGoDecision.approvedAt,
    },
  };

  const resolvedLaunchApprovalPath = writeJson(launchApprovalPath, launchApproval);
  console.log(JSON.stringify({
    service: "flowmemory-agent-bonds-owner-inputs-materialize",
    ownerInputsPath: resolve(root, ownerInputsPath),
    pilotConfigPath: resolve(root, pilotConfigPath),
    externalReviewPath: resolve(root, externalReviewPath),
    operatorSeparationPath: resolve(root, operatorSeparationPath),
    runtimeEvidencePath: resolve(root, runtimeEvidencePath),
    goNoGoPath: resolve(root, goNoGoPath),
    launchApprovalPath: resolvedLaunchApprovalPath,
  }, null, 2));
}

main();
