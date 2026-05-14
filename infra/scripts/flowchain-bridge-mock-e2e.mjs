#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const bridgeRelayerRoot = resolve(repoRoot, "services/bridge-relayer");
const reportDir = resolve(repoRoot, "devnet/local/live-l1-protocol");
const reportPath = resolve(reportDir, "bridge-mock-e2e-report.json");

function run(label, command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? repoRoot,
    stdio: "inherit",
    env: process.env
  });
  if (result.status !== 0) {
    const reason = result.error ? `: ${result.error.message}` : "";
    throw new Error(`${label} failed${reason}`);
  }
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

run(
  "bridge mock observer",
  process.execPath,
  [
    "src/observe-base-lockbox.ts",
    "--mode",
    "mock",
    "--fixture",
    "../../fixtures/bridge/base-sepolia-mock-deposit.json",
    "--out",
    "out/bridge-observation.json",
    "--credit-out",
    "out/bridge-credit.json",
    "--handoff-out",
    "out/bridge-runtime-handoff.json"
  ],
  { cwd: bridgeRelayerRoot }
);
run("live L1 protocol verifier", process.execPath, ["infra/scripts/flowchain-live-l1-protocol-verify.mjs"]);

const observationPath = resolve(repoRoot, "services/bridge-relayer/out/bridge-observation.json");
const creditPath = resolve(repoRoot, "services/bridge-relayer/out/bridge-credit.json");
const handoffPath = resolve(repoRoot, "services/bridge-relayer/out/bridge-runtime-handoff.json");
for (const path of [observationPath, creditPath, handoffPath]) {
  if (!existsSync(path)) throw new Error(`bridge mock output missing: ${path}`);
}

const observation = readJson(observationPath);
const credit = readJson(creditPath);
const handoff = readJson(handoffPath);
if (!observation.observationId || !credit.creditId || !Array.isArray(handoff.credits)) {
  throw new Error("bridge mock output did not include observation, credit, and handoff credit objects");
}

writeJson(reportPath, {
  schema: "flowchain.bridge_mock_e2e.report.v0",
  generatedAt: new Date().toISOString(),
  finalStatus: "PASS",
  observationPath,
  creditPath,
  handoffPath,
  protocolReportPath: resolve(reportDir, "protocol-conformance-report.json")
});

console.log(`FLOWCHAIN_BRIDGE_MOCK_E2E_PASS report=${reportPath}`);
