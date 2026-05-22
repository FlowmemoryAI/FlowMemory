#!/usr/bin/env node
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const REPORT_PATH = resolve(REPO_ROOT, "devnet/local/agent-bonds-readiness/agent-bonds-readiness-report.json");

function runStep(name, command, args, env = {}) {
  const executable = process.platform === "win32" ? "cmd.exe" : command;
  const finalArgs = process.platform === "win32"
    ? ["/d", "/s", "/c", [command, ...args].join(" ")]
    : args;
  const startedAt = new Date().toISOString();
  const result = spawnSync(executable, finalArgs, {
    cwd: REPO_ROOT,
    stdio: "inherit",
    env: { ...process.env, ...env },
  });
  return {
    name,
    command: [command, ...args].join(" "),
    startedAt,
    finishedAt: new Date().toISOString(),
    exitCode: result.status ?? 1,
    ok: result.status === 0,
  };
}

function writeReport(steps) {
  mkdirSync(dirname(REPORT_PATH), { recursive: true });
  const report = {
    schema: "flowmemory.agent_bonds.readiness_report.v1",
    generatedAt: new Date().toISOString(),
    repoRoot: REPO_ROOT,
    steps,
    ok: steps.every((step) => step.ok),
  };
  writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`);
  return report;
}


function main() {
  process.chdir(REPO_ROOT);
  const steps = [];
  steps.push(runStep("generate agent-bonds fixture", "npm", ["run", "flowmemory:agent-bonds:v1"]));
  steps.push(runStep("replay agent-bonds fixture", "npm", ["run", "flowmemory:agent-bonds:replay"]));
  steps.push(runStep("simulate agent-bonds economics", "npm", ["run", "flowmemory:agent-bonds:simulate"]));
  steps.push(runStep("validate capped pilot config", "npm", ["run", "flowmemory:agent-bonds:pilot-config:validate", "--", "fixtures/agent-bonds/pilot-config.template.json"]));
  steps.push(runStep("build operator bundle", "npm", ["run", "flowmemory:agent-bonds:operator-bundle"]));
  steps.push(runStep("test agent-bond contracts", "forge", ["test", "--match-path", "tests/AgentBondManager.t.sol"]));
  steps.push(runStep("test timelocked multisig", "forge", ["test", "--match-path", "tests/AgentBondTimelockedMultisig.t.sol"]));
  steps.push(runStep("run slither hardening gate", "node", ["infra/scripts/agent-bonds-contract-hardening.mjs"]));
  steps.push(runStep("test control-plane runtime", "npm", ["test", "--prefix", "services/control-plane"]));

  // The public-launch blocker and goal-audit checks intentionally read the
  // readiness report. Write the non-circular repo-side evidence first so a
  // prior failed run cannot poison the next run.
  writeReport(steps);

  steps.push(runStep("verify only external public-launch blockers remain", "npm", ["run", "flowmemory:agent-bonds:public-launch:blockers"]));
  steps.push(runStep("audit goal deliverables", "npm", ["run", "flowmemory:agent-bonds:goal-audit"]));
  writeReport(steps);
  steps.push(runStep("test flowmemory Agent Bonds services", "npm", ["run", "test:agent-bonds", "--prefix", "services/flowmemory"], { FLOWMEMORY_SKIP_AGENT_BONDS_META: "1" }));
  steps.push(runStep("test dashboard", "npm", ["test", "--prefix", "apps/dashboard"]));
  steps.push(runStep("check launch claims", "node", ["infra/scripts/check-unsafe-claims.mjs"]));

  const report = writeReport(steps);

  if (!report.ok) {
    throw new Error(`Agent Bonds readiness failed. See ${REPORT_PATH}`);
  }

  console.log(JSON.stringify({ service: "flowmemory-agent-bonds-readiness", reportPath: REPORT_PATH, steps: steps.length }, null, 2));
}

main();
