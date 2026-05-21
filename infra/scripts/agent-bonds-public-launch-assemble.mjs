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
  const outputPath = process.argv[2] ?? "fixtures/agent-bonds/launch-approval.generated.json";
  const pilotConfigPath = process.argv[3] ?? "fixtures/agent-bonds/pilot-config.template.json";
  const externalReviewPath = process.argv[4] ?? "fixtures/agent-bonds/approvals/external-review.template.json";
  const operatorSeparationPath = process.argv[5] ?? "fixtures/agent-bonds/approvals/operator-separation.template.json";
  const runtimeEvidencePath = process.argv[6] ?? "fixtures/agent-bonds/approvals/runtime-evidence.template.json";
  const goNoGoPath = process.argv[7] ?? "fixtures/agent-bonds/approvals/go-no-go.template.json";
  const readinessReportPath = process.argv[8] ?? "devnet/local/agent-bonds-readiness/agent-bonds-readiness-report.json";
  const operatorBundlePath = process.argv[9] ?? "out/agent-bonds-operator-bundle";

  const pilotConfig = readJson(pilotConfigPath);
  const externalReview = readJson(externalReviewPath);
  const operatorSeparation = readJson(operatorSeparationPath);
  const runtimeEvidence = readJson(runtimeEvidencePath);
  const goNoGoDecision = readJson(goNoGoPath);

  const approval = {
    schema: "flowmemory.agent_bonds_launch_approval.v1",
    network: {
      chainId: pilotConfig.network.chainId,
      networkName: pilotConfig.network.networkName,
    },
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

  const resolvedOutputPath = writeJson(outputPath, approval);
  console.log(JSON.stringify({
    service: "flowmemory-agent-bonds-public-launch-assemble",
    outputPath: resolvedOutputPath,
    pilotConfigPath: resolve(root, pilotConfigPath),
    externalReviewPath: resolve(root, externalReviewPath),
    operatorSeparationPath: resolve(root, operatorSeparationPath),
    runtimeEvidencePath: resolve(root, runtimeEvidencePath),
    goNoGoPath: resolve(root, goNoGoPath),
  }, null, 2));
}

main();
