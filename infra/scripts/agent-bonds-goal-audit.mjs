#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const REPORT_PATH = resolve(REPO_ROOT, "local-runtime/local/agent-bonds-readiness/goal-audit-report.json");

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function mustExist(path, label, failures) {
  if (!existsSync(resolve(REPO_ROOT, path))) {
    failures.push(`${label} missing: ${path}`);
    return false;
  }
  return true;
}

function run(command, args) {
  return spawnSync(command, args, {
    cwd: REPO_ROOT,
    encoding: "utf8",
  });
}

function status(ok, evidence, blockerType = null) {
  return { ok, evidence, blockerType };
}

function main() {
  process.chdir(REPO_ROOT);
  const failures = [];

  const readinessPath = "local-runtime/local/agent-bonds-readiness/agent-bonds-readiness-report.json";
  const replayPath = "fixtures/agent-bonds/replay-report.json";
  const economicPath = "fixtures/agent-bonds/economic-sim-report.json";
  const blockerCheck = run("node", ["infra/scripts/agent-bonds-public-launch-blockers.mjs"]);

  mustExist(readinessPath, "readiness report", failures);
  mustExist(replayPath, "replay report", failures);
  mustExist(economicPath, "economic simulation", failures);
  mustExist("docs/AGENT_BONDS_PUBLIC_LAUNCH_BOUNDARY.md", "public boundary doc", failures);
  mustExist("docs/reviews/AGENT_BONDS_GOAL_COMPLETION_MATRIX.md", "goal matrix doc", failures);

  const readiness = readJson(resolve(REPO_ROOT, readinessPath));
  const replay = readJson(resolve(REPO_ROOT, replayPath));
  const economic = readJson(resolve(REPO_ROOT, economicPath));

  const deliverables = {
    verifierTrustReduction: status(readiness.ok === true, ["contracts/AgentBondManager.sol", "tests/AgentBondManager.t.sol"]),
    contractAuditEvidence: status(readiness.ok === true, ["docs/reviews/AGENT_BONDS_V1_SECURITY_REVIEW.md", "npm run contracts:hardening:slither"]),
    custodyControls: status(readiness.ok === true, ["contracts/shared/TwoStepOwnable.sol", "contracts/AgentBondTimelockedMultisig.sol", "contracts/AgentBondManager.sol"]),
    pilotCaps: status(readiness.ok === true, ["fixtures/agent-bonds/pilot-config.template.json", "infra/scripts/agent-bonds-pilot-config-validate.mjs"]),
    artifactAvailability: status(readiness.ok === true, ["schemas/flowmemory/task-bond-availability-proof.schema.json", "contracts/AgentBondManager.sol"]),
    economicTesting: status(Array.isArray(economic.scenarios) && economic.scenarios.length >= 6, [economicPath]),
    runtimeAndRecovery: status(readiness.ok === true, [readinessPath, "services/control-plane/src/methods.ts", "docs/OPERATIONS/AGENT_BONDS_MONITORING_AND_RECOVERY.md"]),
    reproducibility: status(replay.match === true, [replayPath, "out/agent-bonds-operator-bundle/"]),
    publicDocs: status(true, ["docs/AGENT_BONDS_PUBLIC_LAUNCH_BOUNDARY.md", "docs/OPERATIONS/AGENT_BONDS_PUBLIC_LAUNCH_APPROVAL.md"]),
    publicLaunchApproval: status(false, ["fixtures/agent-bonds/launch-approval.template.json", "infra/scripts/agent-bonds-public-launch-validate.mjs"], "external-signoff"),
  };

  if (blockerCheck.status !== 0) {
    failures.push(`blocker audit failed: ${blockerCheck.stderr || blockerCheck.stdout}`);
  }

  const report = {
    schema: "flowmemory.agent_bonds.goal_audit_report.v1",
    generatedAt: new Date().toISOString(),
    deliverables,
    blockerAudit: {
      ok: blockerCheck.status === 0,
      stdout: blockerCheck.stdout.trim(),
      stderr: blockerCheck.stderr.trim(),
    },
    failures,
    repoSideComplete: failures.length === 0 && Object.entries(deliverables).every(([key, value]) => key === "publicLaunchApproval" ? value.blockerType === "external-signoff" : value.ok === true),
  };

  mkdirSync(dirname(REPORT_PATH), { recursive: true });
  writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`);

  if (!report.repoSideComplete) {
    throw new Error(`Agent Bonds goal audit failed. See ${REPORT_PATH}`);
  }

  console.log(JSON.stringify({
    service: "flowmemory-agent-bonds-goal-audit",
    reportPath: REPORT_PATH,
    repoSideComplete: report.repoSideComplete,
  }, null, 2));
}

main();
