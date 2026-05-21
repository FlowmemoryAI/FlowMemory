#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const root = process.cwd();

function run(command, args) {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
  });
  return {
    status: result.status ?? 1,
    stdout: result.stdout,
    stderr: result.stderr,
    command: [command, ...args].join(" "),
  };
}

function requireSuccess(step, label) {
  if (step.status !== 0) {
    throw new Error(`${label} failed:\n${step.stderr || step.stdout}`);
  }
}

function main() {
  const ownerInputsPath = process.argv[2] ?? "fixtures/agent-bonds/owner-inputs.template.json";
  const outputPrefix = process.argv[3] ?? "fixtures/agent-bonds/generated";

  const pilotConfigPath = `${outputPrefix}/pilot-config.json`;
  const externalReviewPath = `${outputPrefix}/approvals/external-review.json`;
  const operatorSeparationPath = `${outputPrefix}/approvals/operator-separation.json`;
  const runtimeEvidencePath = `${outputPrefix}/approvals/runtime-evidence.json`;
  const goNoGoPath = `${outputPrefix}/approvals/go-no-go.json`;
  const launchApprovalPath = `${outputPrefix}/launch-approval.json`;
  const readinessReportPath = "devnet/local/agent-bonds-readiness/agent-bonds-readiness-report.json";
  const operatorBundlePath = "out/agent-bonds-operator-bundle";

  const validateOwnerInputs = run("node", [
    "infra/scripts/agent-bonds-owner-inputs-validate.mjs",
    ownerInputsPath,
  ]);

  if (validateOwnerInputs.status !== 0) {
    console.log(JSON.stringify({
      service: "flowmemory-agent-bonds-public-launch-package",
      status: "blocked_owner_inputs",
      ownerInputsPath: resolve(root, ownerInputsPath),
      validateOwnerInputs: {
        status: validateOwnerInputs.status,
        stderr: validateOwnerInputs.stderr.trim(),
      },
    }, null, 2));
    return;
  }

  const materialize = run("node", [
    "infra/scripts/agent-bonds-owner-inputs-materialize.mjs",
    ownerInputsPath,
    pilotConfigPath,
    externalReviewPath,
    operatorSeparationPath,
    runtimeEvidencePath,
    goNoGoPath,
    launchApprovalPath,
    readinessReportPath,
    operatorBundlePath,
  ]);
  requireSuccess(materialize, "owner input materialization");

  const buildBundle = run("node", ["infra/scripts/agent-bonds-operator-bundle.mjs"]);
  requireSuccess(buildBundle, "operator bundle build");

  const validateLaunch = run("node", [
    "infra/scripts/agent-bonds-public-launch-validate.mjs",
    launchApprovalPath,
    pilotConfigPath,
  ]);

  if (validateLaunch.status === 0) {
    console.log(JSON.stringify({
      service: "flowmemory-agent-bonds-public-launch-package",
      status: "ready_for_public_launch",
      ownerInputsPath: resolve(root, ownerInputsPath),
      pilotConfigPath: resolve(root, pilotConfigPath),
      launchApprovalPath: resolve(root, launchApprovalPath),
      operatorBundlePath: resolve(root, operatorBundlePath),
    }, null, 2));
    return;
  }

  const blockerAudit = run("node", [
    "infra/scripts/agent-bonds-public-launch-blockers.mjs",
    launchApprovalPath,
    pilotConfigPath,
  ]);
  const externalOnly = blockerAudit.status === 0;
  console.log(JSON.stringify({
    service: "flowmemory-agent-bonds-public-launch-package",
    status: externalOnly ? "blocked_external_signoff" : "blocked_unexpected",
    ownerInputsPath: resolve(root, ownerInputsPath),
    pilotConfigPath: resolve(root, pilotConfigPath),
    launchApprovalPath: resolve(root, launchApprovalPath),
    operatorBundlePath: resolve(root, operatorBundlePath),
    validateLaunch: {
      status: validateLaunch.status,
      stderr: validateLaunch.stderr.trim(),
    },
    blockerAudit: {
      status: blockerAudit.status,
      stdout: blockerAudit.stdout.trim(),
      stderr: blockerAudit.stderr.trim(),
    },
  }, null, 2));
}

main();
