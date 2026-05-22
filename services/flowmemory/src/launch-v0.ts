import { spawnSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { DEFAULT_LAUNCH_CORE_PATHS, generateLaunchCore } from "./generate-launch-core.ts";
import { writeAgentBondFixture } from "./agent-bonds.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");

function runStep(name: string, command: string, args: string[]): void {
  console.log(`\n[launch:v0] ${name}`);
  const executable = process.platform === "win32" ? "cmd.exe" : command;
  const finalArgs = process.platform === "win32"
    ? ["/d", "/s", "/c", [command, ...args].join(" ")]
    : args;
  const result = spawnSync(executable, finalArgs, {
    cwd: REPO_ROOT,
    stdio: "inherit",
  });

  if (result.status !== 0) {
    throw new Error(`${name} failed with exit code ${result.status ?? "unknown"}${result.error ? `: ${result.error.message}` : ""}`);
  }
}

export function runLaunchV0(): void {
  process.chdir(REPO_ROOT);
  mkdirSync("fixtures/launch-core/generated/local-runtime", { recursive: true });
  mkdirSync("local-runtime/local", { recursive: true });

  runStep("observe FlowPulse fixtures with indexer", "npm", [
    "run",
    "index:fixtures",
    "--prefix",
    "services/indexer",
  ]);

  runStep("create verifier reports from indexed observations", "npm", [
    "run",
    "verify:fixtures",
    "--prefix",
    "services/verifier",
  ]);

  runStep("run no-value local runtime handoff", "cargo", [
    "run",
    "--manifest-path",
    "crates/flowmemory-local-runtime/Cargo.toml",
    "--",
    "--state",
    "local-runtime/local/launch-v0-state.json",
    "demo",
    "--out-dir",
    "fixtures/launch-core/generated/local-runtime",
  ]);

  runStep("validate FlowRouter hardware POC fixture", "python", [
    "hardware/simulator/flowrouter_sim.py",
    "--validate-file",
    DEFAULT_LAUNCH_CORE_PATHS.hardwarePath,
  ]);

  console.log("\n[launch:v0] generate Agent Bonds v1 fixture");
  writeAgentBondFixture();

  console.log("\n[launch:v0] generate Rootflow, Flow Memory, and Base agent-memory task scout state");
  const { launchCore } = generateLaunchCore(DEFAULT_LAUNCH_CORE_PATHS);

  console.log(JSON.stringify({
    service: "flowmemory-launch-v0",
    loadedFlowPulses: launchCore.acceptance.loadedFlowPulses,
    indexedObservations: launchCore.acceptance.indexedObservations,
    verifierReports: launchCore.acceptance.verifierReports,
    rootflowTransitions: launchCore.acceptance.rootflowTransitions,
    memorySignals: launchCore.memorySignals.length,
    memoryReceipts: launchCore.memoryReceipts.length,
    rootfieldBundles: launchCore.rootfieldBundles.length,
    agentMemoryViews: launchCore.agentMemoryViews.length,
    taskScoutFixture: DEFAULT_LAUNCH_CORE_PATHS.agentMemoryFixturePath,
    taskScoutView: DEFAULT_LAUNCH_CORE_PATHS.agentMemoryViewPath,
    taskScoutReplay: DEFAULT_LAUNCH_CORE_PATHS.agentMemoryReplayPath,
    dashboardFixture: DEFAULT_LAUNCH_CORE_PATHS.dashboardOutPath,
    dashboardRuntimeData: DEFAULT_LAUNCH_CORE_PATHS.dashboardRuntimePath,
    localOnly: true,
  }, null, 2));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  runLaunchV0();
}
