import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { assertNoSecrets } from "../../shared/src/index.ts";
import {
  BASE_MAINNET_CHAIN_ID,
  BASE_MAINNET_CHAIN_ID_HEX,
  MAX_BLOCK_RANGE,
  ZERO_ADDRESS,
  fixtureDeposits,
  makeBridgeCredit,
  makeRuntimeHandoff,
  parseBridgeArgs,
  readLatestBlockNumber,
  runBridgePipeline,
  type BridgeMode,
  type BridgeObservation,
  type BridgePipelineResult,
  type BridgeRuntimeCreditApplication,
  type BridgeRuntimeHandoff,
} from "./observe-base-lockbox.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
export const LIVE_BASE8453_LOCKBOX = "0xe731Bc6b117d92deDCA40a7ccAec11d16205026a".toLowerCase() as `0x${string}`;
export const DEFAULT_RELAY_DIR = "devnet/local/live-base8453-relay";
export const DEFAULT_CONFIRMATIONS = 12;
export const DEFAULT_POLL_MS = 5_000;
export const DEFAULT_MAX_SCAN_BLOCKS = 500n;
export const DEFAULT_RECOVERY_WINDOW_BLOCKS = 128n;
export const DEFAULT_NODE_WAIT_MS = 60_000;
export const PILOT_ACK_VALUE = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT";

type RelayMode = Extract<BridgeMode, "mock-pilot" | "base-mainnet-pilot">;
type NodeSubmitMode = "inbox" | "direct" | "off";

export type RelayDepositLifecycleStatus =
  | "no_deposits_observed"
  | "deposit_observed_not_confirmation_eligible"
  | "deposit_observed_and_queued"
  | "credit_applied_to_running_l1_node"
  | "duplicate_idempotent_replay"
  | "invalid_direct_transfer"
  | "invalid_reverted_transaction"
  | "invalid_wrong_contract"
  | "invalid_missing_bridge_deposit_event";

export type RelayOverallStatus =
  | "NO_DEPOSITS_OBSERVED"
  | "OBSERVED_PENDING_CONFIRMATIONS"
  | "OBSERVED_QUEUED"
  | "READY"
  | "IDEMPOTENT_REPLAY"
  | "INVALID_OR_REVERTED";

export interface RelayMonitorOptions {
  mode: RelayMode;
  rpcUrl?: string;
  fixturePath?: string;
  lockboxAddress: `0x${string}`;
  approvedLockboxAddress: `0x${string}`;
  supportedTokens: `0x${string}`[];
  startBlock?: string;
  latestBlockOverride?: string;
  confirmations: number;
  pollMs: number;
  maxScanBlocks: bigint;
  recoveryWindowBlocks: bigint;
  maxUsd: string;
  maxDepositAmount: string;
  totalCapAmount: string;
  checkpointPath: string;
  statusOutPath: string;
  reportOutPath: string;
  handoffOutPath: string;
  runtimeStatePath: string;
  nodeStatePath: string;
  nodeDir: string;
  nodeSubmitMode: NodeSubmitMode;
  nodeWaitMs: number;
  monitor: boolean;
  iterations: number;
  acknowledgePilot: boolean;
  acknowledgeRealFunds: boolean;
}

interface RelayCheckpoint {
  schema: "flowmemory.base8453_live_relay_checkpoint.v0";
  updatedAt: string;
  chainId: typeof BASE_MAINNET_CHAIN_ID;
  lockbox: `0x${string}`;
  confirmationDepth: number;
  maxScanBlocks: string;
  recoveryWindowBlocks: string;
  lastLatestBlock: string;
  lastConfirmedScanFrom: string | null;
  lastConfirmedScanTo: string | null;
  nextConfirmedScanFrom: string | null;
  observedReplayKeys: `0x${string}`[];
  appliedReplayKeys: `0x${string}`[];
  idempotentReplayKeys: `0x${string}`[];
  statusPath: string;
  handoffPath: string;
  noSecrets: true;
}

interface RelayDepositStatusRow {
  txHash?: `0x${string}`;
  logIndex?: number;
  depositId?: `0x${string}`;
  replayKey?: `0x${string}`;
  sourceBlockNumber?: string;
  status: RelayDepositLifecycleStatus;
  detail: string;
}

interface NodeCreditIngestResult {
  creditId: `0x${string}`;
  applicationId: `0x${string}`;
  depositId: `0x${string}`;
  replayKey: `0x${string}`;
  accountId: `0x${string}`;
  amount: string;
  status: "queued_to_running_node_inbox" | "direct_applied_to_local_node_state" | "spendable" | "not_submitted" | "failed";
  queuedTxIds: string[];
  commandStatus?: number | null;
  error?: string;
  firstSpendableAt?: string;
  creditedAtBlock?: string;
}

interface NodeIngestSummary {
  schema: "flowmemory.base8453_live_relay_node_ingest.v0";
  mode: NodeSubmitMode;
  nodeStatePath: string;
  nodeDir: string;
  submittedCount: number;
  spendableCount: number;
  firstSpendableAt?: string;
  results: NodeCreditIngestResult[];
  noSecrets: true;
}

export interface RelayStatusFile {
  schema: "flowmemory.base8453_live_relay_status.v0";
  generatedAt: string;
  overallStatus: RelayOverallStatus;
  reason: string;
  mode: RelayMode;
  sourceChain: {
    chainId: typeof BASE_MAINNET_CHAIN_ID;
    chainIdHex: typeof BASE_MAINNET_CHAIN_ID_HEX;
  };
  lockbox: `0x${string}`;
  latestBaseBlock: string;
  scanFrom: string | null;
  scanTo: string | null;
  pendingScanFrom: string | null;
  pendingScanTo: string | null;
  confirmationDepth: number;
  pollMs: number;
  maxScanBlocks: string;
  recoveryWindowBlocks: string;
  checkpointPath: string;
  handoffPath: string;
  runtimeStatePath: string;
  summary: {
    noDepositsObserved: boolean;
    observedNotConfirmationEligible: number;
    observedQueued: number;
    creditAppliedToRunningL1Node: number;
    duplicateIdempotentReplay: number;
    invalidDirectTransferOrReverted: number;
    appliedRelayCredits: number;
  };
  deposits: RelayDepositStatusRow[];
  nodeIngest: NodeIngestSummary;
  releaseBroadcast: false;
  previousReadyPreserved: boolean;
  noSecrets: true;
}

export interface RelayReport {
  schema: "flowmemory.base8453_live_relay_report.v0";
  generatedAt: string;
  status: RelayOverallStatus;
  latestBaseBlock: string;
  scanFrom: string | null;
  scanTo: string | null;
  confirmationDepth: number;
  deposits: RelayDepositStatusRow[];
  counts: {
    applied: number;
    idempotent: number;
    queued: number;
    pendingConfirmations: number;
    invalid: number;
  };
  handoffPath: string;
  runningL1IngestResult: NodeIngestSummary;
  firstSpendableTimestamp?: string;
  releaseBroadcast: false;
  noSecrets: true;
}

export interface RelayRunResult {
  checkpoint: RelayCheckpoint;
  status: RelayStatusFile;
  report: RelayReport;
  handoff: BridgeRuntimeHandoff;
  confirmedPipeline: BridgePipelineResult;
  pendingObservations: BridgeObservation[];
}

function nowIso(): string {
  return new Date().toISOString();
}

function repoPath(path: string): string {
  return resolve(REPO_ROOT, path);
}

function relativeToRepo(path: string): string {
  return relative(REPO_ROOT, resolve(path)).replace(/\\/g, "/");
}

function maybeReadJson<T>(path: string): T | null {
  const resolved = repoPath(path);
  return existsSync(resolved) ? JSON.parse(readFileSync(resolved, "utf8")) as T : null;
}

function writeJson(path: string, value: unknown): void {
  const outPath = repoPath(path);
  mkdirSync(dirname(outPath), { recursive: true });
  assertNoSecrets(value);
  writeFileSync(outPath, `${JSON.stringify(value, null, 2)}\n`);
}

function env(name: string): string | undefined {
  const value = process.env[name];
  return value === undefined || value.trim() === "" ? undefined : value;
}

function argValue(args: string[], index: number, name: string): string {
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function asPositiveInteger(value: string, name: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
  return parsed;
}

function asNonNegativeBlock(value: string, name: string): bigint {
  if (!/^[0-9]+$/.test(value)) {
    throw new Error(`${name} must be a decimal block number`);
  }
  return BigInt(value);
}

function asAddress(value: string, name: string): `0x${string}` {
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) {
    throw new Error(`${name} must be a 20-byte hex address`);
  }
  return value.toLowerCase() as `0x${string}`;
}

function parseAddressList(value: string, name: string): `0x${string}`[] {
  return value
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0)
    .map((entry) => asAddress(entry, name));
}

function parseBigIntOption(value: string | undefined, fallback: bigint, name: string): bigint {
  if (value === undefined) {
    return fallback;
  }
  const parsed = asNonNegativeBlock(value, name);
  if (parsed === 0n) {
    throw new Error(`${name} must be greater than zero`);
  }
  return parsed;
}

function loadCheckpoint(path: string): RelayCheckpoint | null {
  const checkpoint = maybeReadJson<RelayCheckpoint>(path);
  if (checkpoint === null) {
    return null;
  }
  if (checkpoint.schema !== "flowmemory.base8453_live_relay_checkpoint.v0") {
    throw new Error("unsupported relay checkpoint schema");
  }
  return checkpoint;
}

function loadPreviousStatus(path: string): RelayStatusFile | null {
  const status = maybeReadJson<RelayStatusFile>(path);
  if (status === null) {
    return null;
  }
  if (status.schema !== "flowmemory.base8453_live_relay_status.v0") {
    return null;
  }
  return status;
}

function previousWasReady(status: RelayStatusFile | null): boolean {
  return status?.overallStatus === "READY" || (status?.summary.creditAppliedToRunningL1Node ?? 0) > 0;
}

function uniqueObservations(observations: BridgeObservation[]): BridgeObservation[] {
  const seen = new Set<string>();
  const unique: BridgeObservation[] = [];
  for (const observation of observations) {
    const key = `${observation.replayKey}:${observation.deposit.txHash}:${observation.deposit.logIndex}`;
    if (!seen.has(key)) {
      seen.add(key);
      unique.push(observation);
    }
  }
  return unique;
}

function emptyPipeline(mode: RelayMode, handoffPath: string): BridgePipelineResult {
  const handoff = makeRuntimeHandoff(mode, [], [], [], [], [], [], handoffPath);
  return {
    observations: [],
    credits: [],
    withdrawalIntents: [],
    runtimeApplications: [],
    pilotEvidence: [],
    releaseEvidences: [],
    handoff,
  };
}

function pipelineArgsForRange(options: RelayMonitorOptions, fromBlock: bigint, toBlock: bigint): string[] {
  return [
    "--mode",
    "base-mainnet-pilot",
    "--rpc-url",
    options.rpcUrl ?? "",
    "--lockbox-address",
    options.lockboxAddress,
    "--approved-lockbox",
    options.approvedLockboxAddress,
    ...options.supportedTokens.flatMap((token) => ["--supported-token", token]),
    "--from-block",
    fromBlock.toString(),
    "--to-block",
    toBlock.toString(),
    "--confirmations",
    options.confirmations.toString(),
    "--acknowledge-pilot",
    "--acknowledge-real-funds",
    "--max-usd",
    options.maxUsd,
    "--max-deposit-amount",
    options.maxDepositAmount,
    "--total-cap-amount",
    options.totalCapAmount,
    "--apply-credit",
    "--runtime-state",
    repoPath(options.runtimeStatePath),
  ];
}

function pendingArgsForRange(options: RelayMonitorOptions, fromBlock: bigint, toBlock: bigint): string[] {
  return [
    "--mode",
    "base-mainnet-canary",
    "--rpc-url",
    options.rpcUrl ?? "",
    "--lockbox-address",
    options.lockboxAddress,
    "--approved-lockbox",
    options.approvedLockboxAddress,
    ...options.supportedTokens.flatMap((token) => ["--supported-token", token]),
    "--from-block",
    fromBlock.toString(),
    "--to-block",
    toBlock.toString(),
    "--acknowledge-real-funds",
    "--max-usd",
    options.maxUsd,
  ];
}

async function runConfirmedPipeline(
  options: RelayMonitorOptions,
  scanFrom: bigint | null,
  scanTo: bigint | null,
): Promise<BridgePipelineResult> {
  if (options.mode === "mock-pilot") {
    return runBridgePipeline(parseBridgeArgs([
      "--mode",
      "mock-pilot",
      "--fixture",
      options.fixturePath ?? "",
      "--approved-lockbox",
      options.approvedLockboxAddress,
      ...options.supportedTokens.flatMap((token) => ["--supported-token", token]),
      "--confirmations",
      options.confirmations.toString(),
      "--acknowledge-pilot",
      "--max-usd",
      options.maxUsd,
      "--max-deposit-amount",
      options.maxDepositAmount,
      "--total-cap-amount",
      options.totalCapAmount,
      "--apply-credit",
      "--runtime-state",
      repoPath(options.runtimeStatePath),
    ]));
  }
  if (scanFrom === null || scanTo === null || scanTo < scanFrom) {
    return emptyPipeline(options.mode, options.handoffOutPath);
  }
  return runBridgePipeline(parseBridgeArgs(pipelineArgsForRange(options, scanFrom, scanTo)));
}

async function readPendingObservations(
  options: RelayMonitorOptions,
  pendingFrom: bigint | null,
  pendingTo: bigint | null,
): Promise<BridgeObservation[]> {
  if (options.mode === "mock-pilot") {
    return [];
  }
  if (pendingFrom === null || pendingTo === null || pendingTo < pendingFrom) {
    return [];
  }
  const pending = await runBridgePipeline(parseBridgeArgs(pendingArgsForRange(options, pendingFrom, pendingTo)));
  return pending.observations;
}

function fixtureLatestBlock(options: RelayMonitorOptions): bigint {
  if (options.latestBlockOverride !== undefined) {
    return asNonNegativeBlock(options.latestBlockOverride, "--latest-block");
  }
  const deposits = fixtureDeposits(JSON.parse(readFileSync(repoPath(options.fixturePath ?? ""), "utf8")));
  const maxFixtureBlock = deposits.reduce((max, deposit) => {
    const block = deposit.sourceBlockNumber === undefined ? 0n : BigInt(deposit.sourceBlockNumber);
    return block > max ? block : max;
  }, 0n);
  return maxFixtureBlock + BigInt(options.confirmations);
}

async function latestBaseBlock(options: RelayMonitorOptions): Promise<bigint> {
  if (options.mode === "mock-pilot") {
    return fixtureLatestBlock(options);
  }
  return readLatestBlockNumber(options.rpcUrl ?? "");
}

interface ScanWindow {
  latestBlock: bigint;
  confirmedTo: bigint | null;
  scanFrom: bigint | null;
  scanTo: bigint | null;
  pendingFrom: bigint | null;
  pendingTo: bigint | null;
}

function boundedWidth(from: bigint, to: bigint): bigint {
  return to >= from ? to - from + 1n : 0n;
}

function determineWindow(options: RelayMonitorOptions, checkpoint: RelayCheckpoint | null, latestBlock: bigint): ScanWindow {
  const confirmationDepth = BigInt(options.confirmations);
  const startBlock = options.startBlock !== undefined
    ? asNonNegativeBlock(options.startBlock, "--from-block")
    : latestBlock > options.recoveryWindowBlocks
      ? latestBlock - options.recoveryWindowBlocks + 1n
      : 0n;
  const confirmedTo = latestBlock >= confirmationDepth ? latestBlock - confirmationDepth : null;
  if (confirmedTo === null || confirmedTo < startBlock) {
    return {
      latestBlock,
      confirmedTo,
      scanFrom: null,
      scanTo: null,
      pendingFrom: startBlock <= latestBlock ? startBlock : null,
      pendingTo: startBlock <= latestBlock ? latestBlock : null,
    };
  }

  const checkpointTo = checkpoint?.lastConfirmedScanTo === null || checkpoint?.lastConfirmedScanTo === undefined
    ? null
    : BigInt(checkpoint.lastConfirmedScanTo);
  const recoveryFloor = confirmedTo > options.recoveryWindowBlocks
    ? confirmedTo - options.recoveryWindowBlocks + 1n
    : 0n;
  const checkpointFloor = checkpointTo === null
    ? recoveryFloor
    : checkpointTo > options.recoveryWindowBlocks
      ? checkpointTo - options.recoveryWindowBlocks + 1n
      : 0n;
  let scanFrom = [startBlock, recoveryFloor, checkpointFloor].reduce((max, value) => value > max ? value : max, 0n);
  const scanTo = confirmedTo;
  if (boundedWidth(scanFrom, scanTo) > options.maxScanBlocks) {
    scanFrom = scanTo - options.maxScanBlocks + 1n;
  }
  if (boundedWidth(scanFrom, scanTo) > MAX_BLOCK_RANGE) {
    throw new Error(`relay scan range exceeds hard max ${MAX_BLOCK_RANGE.toString()} blocks`);
  }

  const pendingFrom = confirmedTo + 1n <= latestBlock ? confirmedTo + 1n : null;
  let boundedPendingFrom = pendingFrom;
  if (pendingFrom !== null && boundedWidth(pendingFrom, latestBlock) > options.maxScanBlocks) {
    boundedPendingFrom = latestBlock - options.maxScanBlocks + 1n;
  }

  return {
    latestBlock,
    confirmedTo,
    scanFrom,
    scanTo,
    pendingFrom: boundedPendingFrom,
    pendingTo: boundedPendingFrom === null ? null : latestBlock,
  };
}

function applicationByCredit(
  applications: BridgeRuntimeCreditApplication[],
): Map<`0x${string}`, BridgeRuntimeCreditApplication> {
  return new Map(applications.map((application) => [application.creditId, application]));
}

function readNodeState(path: string): Record<string, unknown> | null {
  return maybeReadJson<Record<string, unknown>>(path);
}

function creditIsSpendable(application: BridgeRuntimeCreditApplication, state: Record<string, unknown> | null): {
  spendable: boolean;
  creditedAtBlock?: string;
} {
  if (state === null) {
    return { spendable: false };
  }
  const records = state.faucetRecords;
  if (records !== null && typeof records === "object" && !Array.isArray(records)) {
    for (const value of Object.values(records as Record<string, Record<string, unknown>>)) {
      if (String(value.reason ?? "").includes(application.applicationId)) {
        return {
          spendable: true,
          creditedAtBlock: value.creditedAtBlock === undefined ? undefined : String(value.creditedAtBlock),
        };
      }
    }
  }
  const balances = state.localTestUnitBalances;
  if (balances !== null && typeof balances === "object" && !Array.isArray(balances)) {
    const balance = (balances as Record<string, Record<string, unknown>>)[application.flowchainRecipient];
    if (balance !== undefined && BigInt(String(balance.units ?? "0")) >= BigInt(application.amount)) {
      return { spendable: true, creditedAtBlock: balance.updatedAtBlock === undefined ? undefined : String(balance.updatedAtBlock) };
    }
  }
  return { spendable: false };
}

async function waitForSpendable(
  applications: BridgeRuntimeCreditApplication[],
  nodeStatePath: string,
  waitMs: number,
): Promise<Map<`0x${string}`, { firstSpendableAt: string; creditedAtBlock?: string }>> {
  const spendable = new Map<`0x${string}`, { firstSpendableAt: string; creditedAtBlock?: string }>();
  if (applications.length === 0 || waitMs <= 0) {
    return spendable;
  }
  const deadline = Date.now() + waitMs;
  while (Date.now() <= deadline) {
    const state = readNodeState(nodeStatePath);
    for (const application of applications) {
      if (spendable.has(application.applicationId)) {
        continue;
      }
      const result = creditIsSpendable(application, state);
      if (result.spendable) {
        spendable.set(application.applicationId, {
          firstSpendableAt: nowIso(),
          creditedAtBlock: result.creditedAtBlock,
        });
      }
    }
    if (spendable.size === applications.length) {
      return spendable;
    }
    await new Promise((resolveSleep) => setTimeout(resolveSleep, 1_000));
  }
  return spendable;
}

function runCargo(args: string[]): { status: number | null; stdout: string; stderr: string } {
  const targetDir = repoPath(`devnet/local/cargo-target/bridge-relay-${process.pid}`);
  mkdirSync(targetDir, { recursive: true });
  const result = spawnSync("cargo", args, {
    cwd: REPO_ROOT,
    encoding: "utf8",
    env: {
      ...process.env,
      CARGO_TARGET_DIR: targetDir,
    },
  });
  if (result.error !== undefined) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout || `cargo exited ${result.status}`);
  }
  return {
    status: result.status,
    stdout: result.stdout,
    stderr: result.stderr,
  };
}

function queuedTxIds(stdout: string): string[] {
  try {
    const payload = JSON.parse(stdout) as { queued?: unknown };
    return Array.isArray(payload.queued) ? payload.queued.map(String) : [];
  } catch {
    return [];
  }
}

function assertAmountFitsU64(amount: string): void {
  const parsed = BigInt(amount);
  if (parsed <= 0n || parsed > 18_446_744_073_709_551_615n) {
    throw new Error(`credit amount cannot be queued to local node as u64 test units: ${amount}`);
  }
}

async function submitApplicationsToNode(
  options: RelayMonitorOptions,
  applications: BridgeRuntimeCreditApplication[],
): Promise<NodeIngestSummary> {
  const applied = applications.filter((application) => application.status === "applied");
  const results: NodeCreditIngestResult[] = [];
  if (options.nodeSubmitMode === "off" || applied.length === 0) {
    return {
      schema: "flowmemory.base8453_live_relay_node_ingest.v0",
      mode: options.nodeSubmitMode,
      nodeStatePath: relativeToRepo(repoPath(options.nodeStatePath)),
      nodeDir: relativeToRepo(repoPath(options.nodeDir)),
      submittedCount: 0,
      spendableCount: 0,
      results: applied.map((application) => ({
        creditId: application.creditId,
        applicationId: application.applicationId,
        depositId: application.depositId,
        replayKey: application.replayKey,
        accountId: application.flowchainRecipient,
        amount: application.amount,
        status: "not_submitted",
        queuedTxIds: [],
      })),
      noSecrets: true,
    };
  }

  for (const application of applied) {
    try {
      assertAmountFitsU64(application.amount);
      const reason = `base8453-bridge-credit:${application.applicationId}`;
      const args = [
        "run",
        "--manifest-path",
        "crates/flowmemory-devnet/Cargo.toml",
        "--",
        "--state",
        repoPath(options.nodeStatePath),
        "--node-dir",
        repoPath(options.nodeDir),
        "faucet",
        "--account",
        application.flowchainRecipient,
        "--amount",
        application.amount,
        "--reason",
        reason,
        "--authorized-by",
        "bridge-relayer:base8453",
      ];
      if (options.nodeSubmitMode === "direct") {
        args.push("--direct");
      }
      const queued = runCargo(args);
      if (options.nodeSubmitMode === "direct") {
        runCargo([
          "run",
          "--manifest-path",
          "crates/flowmemory-devnet/Cargo.toml",
          "--",
          "--state",
          repoPath(options.nodeStatePath),
          "--node-dir",
          repoPath(options.nodeDir),
          "start",
          "--blocks",
          "1",
        ]);
      }
      results.push({
        creditId: application.creditId,
        applicationId: application.applicationId,
        depositId: application.depositId,
        replayKey: application.replayKey,
        accountId: application.flowchainRecipient,
        amount: application.amount,
        status: options.nodeSubmitMode === "direct" ? "direct_applied_to_local_node_state" : "queued_to_running_node_inbox",
        queuedTxIds: queuedTxIds(queued.stdout),
        commandStatus: queued.status,
      });
    } catch (error) {
      results.push({
        creditId: application.creditId,
        applicationId: application.applicationId,
        depositId: application.depositId,
        replayKey: application.replayKey,
        accountId: application.flowchainRecipient,
        amount: application.amount,
        status: "failed",
        queuedTxIds: [],
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  const spendable = await waitForSpendable(applied, options.nodeStatePath, options.nodeWaitMs);
  for (const result of results) {
    const ready = spendable.get(result.applicationId);
    if (ready !== undefined) {
      result.status = "spendable";
      result.firstSpendableAt = ready.firstSpendableAt;
      result.creditedAtBlock = ready.creditedAtBlock;
    }
  }

  const firstSpendableAt = results
    .map((result) => result.firstSpendableAt)
    .filter((value): value is string => value !== undefined)
    .sort()[0];
  return {
    schema: "flowmemory.base8453_live_relay_node_ingest.v0",
    mode: options.nodeSubmitMode,
    nodeStatePath: relativeToRepo(repoPath(options.nodeStatePath)),
    nodeDir: relativeToRepo(repoPath(options.nodeDir)),
    submittedCount: results.filter((result) => result.status !== "not_submitted" && result.status !== "failed").length,
    spendableCount: results.filter((result) => result.status === "spendable").length,
    firstSpendableAt,
    results,
    noSecrets: true,
  };
}

function depositRows(
  confirmedPipeline: BridgePipelineResult,
  pendingObservations: BridgeObservation[],
  nodeIngest: NodeIngestSummary,
): RelayDepositStatusRow[] {
  const appByCredit = applicationByCredit(confirmedPipeline.runtimeApplications);
  const nodeByApplication = new Map(nodeIngest.results.map((result) => [result.applicationId, result]));
  const rows: RelayDepositStatusRow[] = [];
  for (const credit of confirmedPipeline.credits) {
    const observation = confirmedPipeline.observations.find((candidate) => candidate.replayKey === credit.replayKey);
    const application = appByCredit.get(credit.creditId);
    const nodeResult = application === undefined ? undefined : nodeByApplication.get(application.applicationId);
    let status: RelayDepositLifecycleStatus = "deposit_observed_and_queued";
    let detail = "Deposit is confirmation-eligible and queued for local runtime credit.";
    if (application?.status === "idempotent_replay") {
      status = "duplicate_idempotent_replay";
      detail = "Replay key was already applied; duplicate read was treated as idempotent.";
    } else if (credit.rejectionReason === "duplicate_replay_key" || credit.rejectionReason === "already_applied_replay_key") {
      status = "duplicate_idempotent_replay";
      detail = `Duplicate credit rejected without erasing prior application: ${credit.rejectionReason}.`;
    } else if (nodeResult?.status === "spendable") {
      status = "credit_applied_to_running_l1_node";
      detail = "Credit was observed in local FlowChain node state.";
    }
    rows.push({
      txHash: credit.source.txHash,
      logIndex: credit.source.logIndex,
      depositId: credit.depositId,
      replayKey: credit.replayKey,
      sourceBlockNumber: observation?.deposit.sourceBlockNumber,
      status,
      detail,
    });
  }
  for (const observation of pendingObservations) {
    rows.push({
      txHash: observation.deposit.txHash,
      logIndex: observation.deposit.logIndex,
      depositId: observation.deposit.depositId,
      replayKey: observation.replayKey,
      sourceBlockNumber: observation.deposit.sourceBlockNumber,
      status: "deposit_observed_not_confirmation_eligible",
      detail: `Deposit is observed but waiting for ${observation.guardrails.confirmation?.depth ?? DEFAULT_CONFIRMATIONS} confirmations.`,
    });
  }
  return rows;
}

function overallStatus(rows: RelayDepositStatusRow[], nodeIngest: NodeIngestSummary, previousReady: boolean): {
  status: RelayOverallStatus;
  reason: string;
  previousReadyPreserved: boolean;
} {
  const invalid = rows.filter((row) => row.status.startsWith("invalid_")).length;
  const spendable = rows.filter((row) => row.status === "credit_applied_to_running_l1_node").length;
  const queued = rows.filter((row) => row.status === "deposit_observed_and_queued").length;
  const pending = rows.filter((row) => row.status === "deposit_observed_not_confirmation_eligible").length;
  const idempotent = rows.filter((row) => row.status === "duplicate_idempotent_replay").length;
  if (invalid > 0) {
    return { status: "INVALID_OR_REVERTED", reason: "Invalid, direct-transfer, wrong-contract, or reverted transaction observed.", previousReadyPreserved: false };
  }
  if (spendable > 0 || nodeIngest.spendableCount > 0) {
    return { status: "READY", reason: "At least one credit is spendable in the local FlowChain node state.", previousReadyPreserved: false };
  }
  if (previousReady && idempotent > 0) {
    return { status: "READY", reason: "Duplicate replay was idempotent and prior READY result was preserved.", previousReadyPreserved: true };
  }
  if (queued > 0) {
    return { status: "OBSERVED_QUEUED", reason: "A confirmation-eligible deposit was observed and queued for node ingest.", previousReadyPreserved: false };
  }
  if (pending > 0) {
    return { status: "OBSERVED_PENDING_CONFIRMATIONS", reason: "A deposit was observed but is not confirmation-eligible yet.", previousReadyPreserved: false };
  }
  if (idempotent > 0) {
    return { status: "IDEMPOTENT_REPLAY", reason: "Only duplicate/idempotent replay reads were observed.", previousReadyPreserved: false };
  }
  return { status: "NO_DEPOSITS_OBSERVED", reason: "No BridgeDeposit events were observed in the bounded relay window.", previousReadyPreserved: false };
}

function makeCheckpoint(
  options: RelayMonitorOptions,
  window: ScanWindow,
  rows: RelayDepositStatusRow[],
  status: RelayStatusFile,
): RelayCheckpoint {
  return {
    schema: "flowmemory.base8453_live_relay_checkpoint.v0",
    updatedAt: status.generatedAt,
    chainId: BASE_MAINNET_CHAIN_ID,
    lockbox: options.lockboxAddress,
    confirmationDepth: options.confirmations,
    maxScanBlocks: options.maxScanBlocks.toString(),
    recoveryWindowBlocks: options.recoveryWindowBlocks.toString(),
    lastLatestBlock: window.latestBlock.toString(),
    lastConfirmedScanFrom: window.scanFrom?.toString() ?? null,
    lastConfirmedScanTo: window.scanTo?.toString() ?? null,
    nextConfirmedScanFrom: window.scanTo === null ? null : (window.scanTo + 1n).toString(),
    observedReplayKeys: rows
      .map((row) => row.replayKey)
      .filter((value): value is `0x${string}` => value !== undefined)
      .sort(),
    appliedReplayKeys: rows
      .filter((row) => row.status === "credit_applied_to_running_l1_node" || row.status === "deposit_observed_and_queued")
      .map((row) => row.replayKey)
      .filter((value): value is `0x${string}` => value !== undefined)
      .sort(),
    idempotentReplayKeys: rows
      .filter((row) => row.status === "duplicate_idempotent_replay")
      .map((row) => row.replayKey)
      .filter((value): value is `0x${string}` => value !== undefined)
      .sort(),
    statusPath: relativeToRepo(repoPath(options.statusOutPath)),
    handoffPath: relativeToRepo(repoPath(options.handoffOutPath)),
    noSecrets: true,
  };
}

function makeStatusAndReport(
  options: RelayMonitorOptions,
  window: ScanWindow,
  rows: RelayDepositStatusRow[],
  nodeIngest: NodeIngestSummary,
  previousStatus: RelayStatusFile | null,
): { status: RelayStatusFile; report: RelayReport } {
  const generatedAt = nowIso();
  const state = overallStatus(rows, nodeIngest, previousWasReady(previousStatus));
  const pending = rows.filter((row) => row.status === "deposit_observed_not_confirmation_eligible").length;
  const queued = rows.filter((row) => row.status === "deposit_observed_and_queued").length;
  const ready = rows.filter((row) => row.status === "credit_applied_to_running_l1_node").length;
  const idempotent = rows.filter((row) => row.status === "duplicate_idempotent_replay").length;
  const invalid = rows.filter((row) => row.status.startsWith("invalid_")).length;
  const status: RelayStatusFile = {
    schema: "flowmemory.base8453_live_relay_status.v0",
    generatedAt,
    overallStatus: state.status,
    reason: state.reason,
    mode: options.mode,
    sourceChain: {
      chainId: BASE_MAINNET_CHAIN_ID,
      chainIdHex: BASE_MAINNET_CHAIN_ID_HEX,
    },
    lockbox: options.lockboxAddress,
    latestBaseBlock: window.latestBlock.toString(),
    scanFrom: window.scanFrom?.toString() ?? null,
    scanTo: window.scanTo?.toString() ?? null,
    pendingScanFrom: window.pendingFrom?.toString() ?? null,
    pendingScanTo: window.pendingTo?.toString() ?? null,
    confirmationDepth: options.confirmations,
    pollMs: options.pollMs,
    maxScanBlocks: options.maxScanBlocks.toString(),
    recoveryWindowBlocks: options.recoveryWindowBlocks.toString(),
    checkpointPath: relativeToRepo(repoPath(options.checkpointPath)),
    handoffPath: relativeToRepo(repoPath(options.handoffOutPath)),
    runtimeStatePath: relativeToRepo(repoPath(options.runtimeStatePath)),
    summary: {
      noDepositsObserved: rows.length === 0,
      observedNotConfirmationEligible: pending,
      observedQueued: queued,
      creditAppliedToRunningL1Node: ready,
      duplicateIdempotentReplay: idempotent,
      invalidDirectTransferOrReverted: invalid,
      appliedRelayCredits: nodeIngest.results.length,
    },
    deposits: rows,
    nodeIngest,
    releaseBroadcast: false,
    previousReadyPreserved: state.previousReadyPreserved,
    noSecrets: true,
  };
  const report: RelayReport = {
    schema: "flowmemory.base8453_live_relay_report.v0",
    generatedAt,
    status: status.overallStatus,
    latestBaseBlock: status.latestBaseBlock,
    scanFrom: status.scanFrom,
    scanTo: status.scanTo,
    confirmationDepth: status.confirmationDepth,
    deposits: rows,
    counts: {
      applied: queued + ready,
      idempotent,
      queued,
      pendingConfirmations: pending,
      invalid,
    },
    handoffPath: status.handoffPath,
    runningL1IngestResult: nodeIngest,
    firstSpendableTimestamp: nodeIngest.firstSpendableAt,
    releaseBroadcast: false,
    noSecrets: true,
  };
  return { status, report };
}

function writeCombinedHandoff(
  options: RelayMonitorOptions,
  confirmedPipeline: BridgePipelineResult,
  pendingObservations: BridgeObservation[],
): BridgeRuntimeHandoff {
  const allObservations = uniqueObservations([...confirmedPipeline.observations, ...pendingObservations]);
  const confirmedReplayKeys = new Set(confirmedPipeline.credits.map((credit) => credit.replayKey));
  const pendingCredits = pendingObservations
    .filter((observation) => !confirmedReplayKeys.has(observation.replayKey))
    .map((observation) => makeBridgeCredit(observation, "pending"));
  const handoff = makeRuntimeHandoff(
    options.mode,
    allObservations,
    [...confirmedPipeline.credits, ...pendingCredits],
    confirmedPipeline.withdrawalIntents,
    confirmedPipeline.runtimeApplications,
    confirmedPipeline.pilotEvidence,
    confirmedPipeline.releaseEvidences,
    options.handoffOutPath,
  );
  writeJson(options.handoffOutPath, handoff);
  return handoff;
}

export async function runRelayOnce(options: RelayMonitorOptions): Promise<RelayRunResult> {
  if (options.maxScanBlocks > MAX_BLOCK_RANGE) {
    throw new Error(`--max-scan-blocks cannot exceed ${MAX_BLOCK_RANGE.toString()}`);
  }
  if (options.recoveryWindowBlocks > options.maxScanBlocks) {
    throw new Error("--recovery-window-blocks must be less than or equal to --max-scan-blocks");
  }
  if (options.mode === "base-mainnet-pilot" && (!options.acknowledgePilot || !options.acknowledgeRealFunds)) {
    throw new Error(`Base 8453 relay requires ${PILOT_ACK_VALUE} acknowledgement or explicit acknowledgement flags`);
  }

  const checkpoint = loadCheckpoint(options.checkpointPath);
  const previousStatus = loadPreviousStatus(options.statusOutPath);
  const latestBlock = await latestBaseBlock(options);
  const window = determineWindow(options, checkpoint, latestBlock);
  const confirmedPipeline = await runConfirmedPipeline(options, window.scanFrom, window.scanTo);
  const pendingObservations = await readPendingObservations(options, window.pendingFrom, window.pendingTo);
  const handoff = writeCombinedHandoff(options, confirmedPipeline, pendingObservations);
  const nodeIngest = await submitApplicationsToNode(options, confirmedPipeline.runtimeApplications);
  const rows = depositRows(confirmedPipeline, pendingObservations, nodeIngest);
  const { status, report } = makeStatusAndReport(options, window, rows, nodeIngest, previousStatus);
  const nextCheckpoint = makeCheckpoint(options, window, rows, status);

  writeJson(options.statusOutPath, status);
  writeJson(options.reportOutPath, report);
  writeJson(options.checkpointPath, nextCheckpoint);

  return {
    checkpoint: nextCheckpoint,
    status,
    report,
    handoff,
    confirmedPipeline,
    pendingObservations,
  };
}

export function parseRelayArgs(args: string[]): RelayMonitorOptions {
  let mode: RelayMode = "base-mainnet-pilot";
  let fixturePath: string | undefined;
  let rpcUrl = env("FLOWCHAIN_BASE8453_RPC_URL");
  let lockboxAddress = asAddress(env("FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS") ?? LIVE_BASE8453_LOCKBOX, "--lockbox-address");
  let approvedLockboxAddress = asAddress(env("FLOWCHAIN_BASE8453_APPROVED_LOCKBOX_ADDRESS") ?? env("FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS") ?? LIVE_BASE8453_LOCKBOX, "--approved-lockbox");
  let supportedTokens = parseAddressList(env("FLOWCHAIN_BASE8453_SUPPORTED_TOKEN") ?? ZERO_ADDRESS, "--supported-token");
  let supportedTokensExplicit = env("FLOWCHAIN_BASE8453_SUPPORTED_TOKEN") !== undefined;
  let startBlock = env("FLOWCHAIN_BASE8453_FROM_BLOCK");
  let latestBlockOverride: string | undefined;
  let confirmations = asPositiveInteger(env("FLOWCHAIN_PILOT_CONFIRMATIONS") ?? String(DEFAULT_CONFIRMATIONS), "--confirmations");
  let pollMs = asPositiveInteger(env("FLOWCHAIN_BASE8453_RELAY_POLL_MS") ?? String(DEFAULT_POLL_MS), "--poll-ms");
  let maxScanBlocks = parseBigIntOption(env("FLOWCHAIN_BASE8453_RELAY_MAX_SCAN_BLOCKS"), DEFAULT_MAX_SCAN_BLOCKS, "--max-scan-blocks");
  let recoveryWindowBlocks = parseBigIntOption(env("FLOWCHAIN_BASE8453_RELAY_RECOVERY_WINDOW_BLOCKS"), DEFAULT_RECOVERY_WINDOW_BLOCKS, "--recovery-window-blocks");
  let maxUsd = env("FLOWCHAIN_PILOT_MAX_USD") ?? "1";
  let maxDepositAmount = env("FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI") ?? "";
  let totalCapAmount = env("FLOWCHAIN_PILOT_TOTAL_CAP_WEI") ?? "";
  let checkpointPath = `${DEFAULT_RELAY_DIR}/checkpoint.json`;
  let statusOutPath = `${DEFAULT_RELAY_DIR}/status.json`;
  let reportOutPath = `${DEFAULT_RELAY_DIR}/relay-report.json`;
  let handoffOutPath = `${DEFAULT_RELAY_DIR}/bridge-runtime-handoff.json`;
  let runtimeStatePath = `${DEFAULT_RELAY_DIR}/relay-credit-application-state.json`;
  let nodeStatePath = "devnet/local/state.json";
  let nodeDir = "devnet/local/node";
  let nodeSubmitMode: NodeSubmitMode = "inbox";
  let nodeWaitMs = DEFAULT_NODE_WAIT_MS;
  let monitor = false;
  let iterations = 1;
  let acknowledgePilot = env("FLOWCHAIN_PILOT_OPERATOR_ACK") === PILOT_ACK_VALUE;
  let acknowledgeRealFunds = env("FLOWCHAIN_PILOT_OPERATOR_ACK") === PILOT_ACK_VALUE;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--mode") {
      const value = argValue(args, index, arg);
      if (value !== "mock-pilot" && value !== "base-mainnet-pilot") {
        throw new Error("--mode must be mock-pilot or base-mainnet-pilot");
      }
      mode = value;
      index += 1;
    } else if (arg === "--fixture") {
      fixturePath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--rpc-url") {
      rpcUrl = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--lockbox-address") {
      lockboxAddress = asAddress(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--approved-lockbox") {
      approvedLockboxAddress = asAddress(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--supported-token") {
      if (!supportedTokensExplicit) {
        supportedTokens = [];
        supportedTokensExplicit = true;
      }
      supportedTokens.push(asAddress(argValue(args, index, arg), arg));
      index += 1;
    } else if (arg === "--supported-tokens") {
      supportedTokens = parseAddressList(argValue(args, index, arg), arg);
      supportedTokensExplicit = true;
      index += 1;
    } else if (arg === "--from-block" || arg === "--start-block") {
      startBlock = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--latest-block") {
      latestBlockOverride = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--confirmations") {
      confirmations = asPositiveInteger(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--poll-ms") {
      pollMs = asPositiveInteger(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--max-scan-blocks") {
      maxScanBlocks = parseBigIntOption(argValue(args, index, arg), DEFAULT_MAX_SCAN_BLOCKS, arg);
      index += 1;
    } else if (arg === "--recovery-window-blocks") {
      recoveryWindowBlocks = parseBigIntOption(argValue(args, index, arg), DEFAULT_RECOVERY_WINDOW_BLOCKS, arg);
      index += 1;
    } else if (arg === "--max-usd") {
      maxUsd = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--max-deposit-amount") {
      maxDepositAmount = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--total-cap-amount") {
      totalCapAmount = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--checkpoint") {
      checkpointPath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--status-out") {
      statusOutPath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--report-out") {
      reportOutPath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--handoff-out") {
      handoffOutPath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--runtime-state") {
      runtimeStatePath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--node-state") {
      nodeStatePath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--node-dir") {
      nodeDir = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--node-mode") {
      const value = argValue(args, index, arg);
      if (value !== "inbox" && value !== "direct" && value !== "off") {
        throw new Error("--node-mode must be inbox, direct, or off");
      }
      nodeSubmitMode = value;
      index += 1;
    } else if (arg === "--no-node-submit") {
      nodeSubmitMode = "off";
    } else if (arg === "--node-wait-ms") {
      nodeWaitMs = asPositiveInteger(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--monitor") {
      monitor = true;
      iterations = 0;
    } else if (arg === "--once") {
      monitor = false;
      iterations = 1;
    } else if (arg === "--iterations") {
      iterations = asPositiveInteger(argValue(args, index, arg), arg);
      monitor = iterations !== 1;
      index += 1;
    } else if (arg === "--acknowledge-pilot") {
      acknowledgePilot = true;
    } else if (arg === "--acknowledge-real-funds") {
      acknowledgeRealFunds = true;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  if (mode === "mock-pilot" && fixturePath === undefined) {
    throw new Error("--fixture is required in mock-pilot relay mode");
  }
  if (mode === "base-mainnet-pilot" && (rpcUrl === undefined || rpcUrl.trim() === "")) {
    throw new Error("FLOWCHAIN_BASE8453_RPC_URL or --rpc-url is required for Base 8453 relay mode");
  }
  if (maxDepositAmount === "" || totalCapAmount === "") {
    throw new Error("FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI and FLOWCHAIN_PILOT_TOTAL_CAP_WEI are required for relay credit caps");
  }
  if (pollMs > DEFAULT_POLL_MS) {
    throw new Error(`--poll-ms must be ${DEFAULT_POLL_MS} or lower for the pilot relay`);
  }

  return {
    mode,
    rpcUrl,
    fixturePath,
    lockboxAddress,
    approvedLockboxAddress,
    supportedTokens: [...new Set(supportedTokens)].sort() as `0x${string}`[],
    startBlock,
    latestBlockOverride,
    confirmations,
    pollMs,
    maxScanBlocks,
    recoveryWindowBlocks,
    maxUsd,
    maxDepositAmount,
    totalCapAmount,
    checkpointPath,
    statusOutPath,
    reportOutPath,
    handoffOutPath,
    runtimeStatePath,
    nodeStatePath,
    nodeDir,
    nodeSubmitMode,
    nodeWaitMs,
    monitor,
    iterations,
    acknowledgePilot: mode === "mock-pilot" ? true : acknowledgePilot,
    acknowledgeRealFunds: mode === "mock-pilot" ? true : acknowledgeRealFunds,
  };
}

async function runRelayCli(options: RelayMonitorOptions): Promise<void> {
  console.log(`Base 8453 relay mode: ${options.mode}`);
  console.log(`Lockbox: ${options.lockboxAddress}`);
  console.log(`Confirmation depth: ${options.confirmations}`);
  console.log(`Polling interval: ${options.pollMs}ms`);
  console.log(`Max scan blocks: ${options.maxScanBlocks.toString()}`);
  console.log("Broadcast: false; release transactions are never sent by this relay.");

  let completed = 0;
  for (;;) {
    const result = await runRelayOnce(options);
    completed += 1;
    console.log(
      `Relay cycle complete: status=${result.status.overallStatus}, scan=${result.status.scanFrom ?? "none"}-${result.status.scanTo ?? "none"}, applied=${result.report.counts.applied}, idempotent=${result.report.counts.idempotent}`,
    );
    if (!options.monitor && completed >= options.iterations) {
      break;
    }
    if (options.monitor && options.iterations > 0 && completed >= options.iterations) {
      break;
    }
    await new Promise((resolveSleep) => setTimeout(resolveSleep, options.pollMs));
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  await runRelayCli(parseRelayArgs(process.argv.slice(2)));
}
