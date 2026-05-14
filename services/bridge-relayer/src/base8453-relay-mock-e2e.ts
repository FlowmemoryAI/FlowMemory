import assert from "node:assert/strict";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { assertNoSecrets } from "../../shared/src/index.ts";
import {
  DEFAULT_CONFIRMATIONS,
  DEFAULT_POLL_MS,
  runRelayOnce,
  type RelayMonitorOptions,
} from "./base8453-relay-monitor.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const OUT_DIR = "devnet/local/live-base8453-relay";
const FIXTURE = "fixtures/bridge/base8453-pilot-mock-deposit.json";
const APPROVED_LOCKBOX = "0x1111111111111111111111111111111111111111";
const SUPPORTED_TOKEN = "0x3333333333333333333333333333333333333333";

function repoPath(path: string): string {
  return resolve(REPO_ROOT, path);
}

function relativeToRepo(path: string): string {
  return relative(REPO_ROOT, resolve(path)).replace(/\\/g, "/");
}

function writeJson(path: string, value: unknown): void {
  const outPath = repoPath(path);
  mkdirSync(dirname(outPath), { recursive: true });
  assertNoSecrets(value);
  writeFileSync(outPath, `${JSON.stringify(value, null, 2)}\n`);
}

function options(): RelayMonitorOptions {
  return {
    mode: "mock-pilot",
    fixturePath: repoPath(FIXTURE),
    lockboxAddress: APPROVED_LOCKBOX,
    approvedLockboxAddress: APPROVED_LOCKBOX,
    supportedTokens: [SUPPORTED_TOKEN],
    latestBlockOverride: "112",
    confirmations: DEFAULT_CONFIRMATIONS,
    pollMs: DEFAULT_POLL_MS,
    maxScanBlocks: 500n,
    recoveryWindowBlocks: 128n,
    maxUsd: "1",
    maxDepositAmount: "20000000",
    totalCapAmount: "40000000",
    checkpointPath: `${OUT_DIR}/checkpoint.json`,
    statusOutPath: `${OUT_DIR}/status.json`,
    reportOutPath: `${OUT_DIR}/relay-report.json`,
    handoffOutPath: `${OUT_DIR}/bridge-runtime-handoff.json`,
    runtimeStatePath: `${OUT_DIR}/relay-credit-application-state.json`,
    nodeStatePath: `${OUT_DIR}/mock-node-state.json`,
    nodeDir: `${OUT_DIR}/mock-node`,
    nodeSubmitMode: "direct",
    nodeWaitMs: 5_000,
    monitor: false,
    iterations: 1,
    acknowledgePilot: true,
    acknowledgeRealFunds: true,
  };
}

const outPath = repoPath(OUT_DIR);
rmSync(outPath, { recursive: true, force: true });
mkdirSync(outPath, { recursive: true });

const firstRun = await runRelayOnce(options());
assert.equal(firstRun.status.overallStatus, "READY");
assert.equal(firstRun.status.summary.creditAppliedToRunningL1Node, 1);
assert.equal(firstRun.report.counts.applied, 1);
assert.equal(firstRun.report.counts.idempotent, 0);
assert.ok(firstRun.report.firstSpendableTimestamp, "first run must produce a spendable timestamp");

const replayRun = await runRelayOnce(options());
assert.equal(replayRun.status.overallStatus, "READY");
assert.equal(replayRun.status.previousReadyPreserved, true);
assert.equal(replayRun.status.summary.duplicateIdempotentReplay, 1);
assert.equal(replayRun.report.counts.applied, 0);
assert.equal(replayRun.report.counts.idempotent, 1);
assert.equal(replayRun.status.summary.invalidDirectTransferOrReverted, 0);

const report = {
  schema: "flowmemory.base8453_low_latency_mock_e2e_report.v0",
  generatedAt: new Date().toISOString(),
  status: "passed",
  confirmationDepth: DEFAULT_CONFIRMATIONS,
  pollMs: DEFAULT_POLL_MS,
  firstRun: {
    status: firstRun.status.overallStatus,
    latestBaseBlock: firstRun.report.latestBaseBlock,
    scanFrom: firstRun.report.scanFrom,
    scanTo: firstRun.report.scanTo,
    applied: firstRun.report.counts.applied,
    idempotent: firstRun.report.counts.idempotent,
    firstSpendableTimestamp: firstRun.report.firstSpendableTimestamp,
  },
  replayRun: {
    status: replayRun.status.overallStatus,
    previousReadyPreserved: replayRun.status.previousReadyPreserved,
    applied: replayRun.report.counts.applied,
    idempotent: replayRun.report.counts.idempotent,
    invalid: replayRun.report.counts.invalid,
  },
  artifacts: {
    checkpoint: relativeToRepo(repoPath(`${OUT_DIR}/checkpoint.json`)),
    status: relativeToRepo(repoPath(`${OUT_DIR}/status.json`)),
    relayReport: relativeToRepo(repoPath(`${OUT_DIR}/relay-report.json`)),
    handoff: relativeToRepo(repoPath(`${OUT_DIR}/bridge-runtime-handoff.json`)),
    runtimeState: relativeToRepo(repoPath(`${OUT_DIR}/relay-credit-application-state.json`)),
    nodeState: relativeToRepo(repoPath(`${OUT_DIR}/mock-node-state.json`)),
  },
  releaseBroadcast: false,
  noSecrets: true,
};

writeJson(`${OUT_DIR}/mock-e2e-report.json`, report);
console.log(`Base 8453 low-latency mock relay E2E passed: ${relativeToRepo(repoPath(`${OUT_DIR}/mock-e2e-report.json`))}`);
