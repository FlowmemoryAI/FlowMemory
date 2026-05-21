import assert from "node:assert/strict";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { assertNoSecrets, canonicalJson } from "../../shared/src/index.ts";
import {
  BASE_MAINNET_CHAIN_ID,
  BASE_MAINNET_CHAIN_ID_HEX,
  parseBridgeArgs,
  runBridgePipeline,
  type BridgeMode,
  type BridgePipelineResult,
} from "./observe-base-lockbox.ts";

type PilotE2EMode = Extract<BridgeMode, "mock-pilot" | "base-mainnet-pilot">;

interface PilotE2EOptions {
  mode: PilotE2EMode;
  fixturePath: string;
  duplicateFixturePath: string;
  outDir: string;
  approvedLockbox: string;
  rpcEndpoint?: string;
  lockboxAddress?: string;
  fromBlock?: string;
  toBlock?: string;
  confirmations: string;
  maxUsd: string;
  maxDepositAmount: string;
  totalCapAmount: string;
  supportedTokens: string[];
  assetDecimals: string;
}

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const DEFAULT_FIXTURE = resolve(REPO_ROOT, "fixtures/bridge/base8453-pilot-mock-deposit.json");
const DEFAULT_DUPLICATE_FIXTURE = resolve(REPO_ROOT, "fixtures/bridge/base8453-pilot-duplicate-mock-deposits.json");
const DEFAULT_OUT_DIR = resolve(REPO_ROOT, "services/bridge-relayer/out/real-value-pilot-e2e");
const DEFAULT_APPROVED_LOCKBOX = "0x1111111111111111111111111111111111111111";
const DEFAULT_SUPPORTED_TOKEN = "0x3333333333333333333333333333333333333333";
const WRONG_APPROVED_LOCKBOX = "0x9999999999999999999999999999999999999999";

function argValue(args: string[], index: number, name: string): string {
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function parsePilotE2EArgs(args: string[]): PilotE2EOptions {
  let mode: PilotE2EMode = "mock-pilot";
  let fixturePath = DEFAULT_FIXTURE;
  let duplicateFixturePath = DEFAULT_DUPLICATE_FIXTURE;
  let outDir = DEFAULT_OUT_DIR;
  let approvedLockbox = DEFAULT_APPROVED_LOCKBOX;
  let rpcEndpoint: string | undefined;
  let lockboxAddress: string | undefined;
  let fromBlock: string | undefined;
  let toBlock: string | undefined;
  let confirmations = "2";
  let maxUsd = "1";
  let maxDepositAmount = "20000000";
  let totalCapAmount = "20000000";
  let supportedTokens = [DEFAULT_SUPPORTED_TOKEN];
  let assetDecimals = "6";

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
      fixturePath = resolve(argValue(args, index, arg));
      index += 1;
    } else if (arg === "--duplicate-fixture") {
      duplicateFixturePath = resolve(argValue(args, index, arg));
      index += 1;
    } else if (arg === "--out-dir") {
      outDir = resolve(argValue(args, index, arg));
      index += 1;
    } else if (arg === "--approved-lockbox") {
      approvedLockbox = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--rpc-endpoint") {
      rpcEndpoint = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--lockbox-address") {
      lockboxAddress = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--from-block") {
      fromBlock = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--to-block") {
      toBlock = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--confirmations") {
      confirmations = argValue(args, index, arg);
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
    } else if (arg === "--supported-token") {
      supportedTokens = [...supportedTokens, argValue(args, index, arg)];
      index += 1;
    } else if (arg === "--supported-tokens") {
      supportedTokens = argValue(args, index, arg)
        .split(",")
        .map((token) => token.trim())
        .filter(Boolean);
      index += 1;
    } else if (arg === "--asset-decimals") {
      assetDecimals = argValue(args, index, arg);
      index += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  supportedTokens = [...new Set(supportedTokens.map((token) => token.toLowerCase()))];

  if (mode === "base-mainnet-pilot") {
    const missing = [
      ["--rpc-endpoint", rpcEndpoint],
      ["--lockbox-address", lockboxAddress],
      ["--from-block", fromBlock],
      ["--to-block", toBlock],
    ].filter(([, value]) => value === undefined).map(([name]) => name);
    if (missing.length > 0) {
      throw new Error(`base-mainnet-pilot E2E requires ${missing.join(", ")}`);
    }
  }

  return {
    mode,
    fixturePath,
    duplicateFixturePath,
    outDir,
    approvedLockbox,
    rpcEndpoint,
    lockboxAddress,
    fromBlock,
    toBlock,
    confirmations,
    maxUsd,
    maxDepositAmount,
    totalCapAmount,
    supportedTokens,
    assetDecimals,
  };
}

function pipelineArgs(options: PilotE2EOptions, statePath: string, fixturePath = options.fixturePath): string[] {
  const common = [
    "--approved-lockbox",
    options.approvedLockbox,
    "--confirmations",
    options.confirmations,
    "--acknowledge-pilot",
    "--max-usd",
    options.maxUsd,
    "--max-deposit-amount",
    options.maxDepositAmount,
    "--total-cap-amount",
    options.totalCapAmount,
    "--asset-decimals",
    options.assetDecimals,
    "--apply-credit",
    "--withdrawal-intent",
    "--runtime-state",
    statePath,
    ...options.supportedTokens.flatMap((token) => ["--supported-token", token]),
  ];

  if (options.mode === "mock-pilot") {
    return [
      "--mode",
      "mock-pilot",
      "--fixture",
      fixturePath,
      ...common,
    ];
  }

  return [
    "--mode",
    "base-mainnet-pilot",
    "--rpc-url",
    options.rpcEndpoint ?? "",
    "--lockbox-address",
    options.lockboxAddress ?? "",
    "--from-block",
    options.fromBlock ?? "",
    "--to-block",
    options.toBlock ?? "",
    "--acknowledge-real-funds",
    ...common,
  ];
}

function writeJson(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  assertNoSecrets(value);
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function relativeToRepo(path: string): string {
  return relative(REPO_ROOT, path).replace(/\\/g, "/");
}

function first<T>(values: T[], name: string): T {
  const value = values[0];
  assert.ok(value !== undefined, `${name} must contain at least one entry`);
  return value;
}

async function runFirstAndReplay(options: PilotE2EOptions, statePath: string): Promise<{
  firstRun: BridgePipelineResult;
  replayRun: BridgePipelineResult;
}> {
  const firstRun = await runBridgePipeline(parseBridgeArgs(pipelineArgs(options, statePath)));
  const firstCredit = first(firstRun.credits, "first credits");
  const firstApplication = first(firstRun.runtimeApplications, "first runtime applications");
  const firstWithdrawal = first(firstRun.withdrawalIntents, "first withdrawal intents");
  const firstEvidence = first(firstRun.pilotEvidence, "first pilot evidence");
  const firstReleaseEvidence = first(firstRun.releaseEvidences, "first release evidence");

  assert.equal(firstCredit.status, "applied");
  assert.equal(firstApplication.status, "applied");
  assert.equal(firstApplication.applyCount, 1);
  assert.equal(firstEvidence.creditApplication.appliedExactlyOnce, true);
  assert.equal(firstWithdrawal.broadcast, false);
  assert.equal(firstReleaseEvidence.releaseCall.broadcast, false);

  const replayRun = await runBridgePipeline(parseBridgeArgs(pipelineArgs(options, statePath)));
  const replayCredit = first(replayRun.credits, "replay credits");
  const replayApplication = first(replayRun.runtimeApplications, "replay runtime applications");
  const replayEvidence = first(replayRun.pilotEvidence, "replay pilot evidence");

  assert.equal(replayCredit.status, "rejected");
  assert.equal(replayCredit.rejectionReason, "already_applied_replay_key");
  assert.equal(replayApplication.status, "idempotent_replay");
  assert.equal(replayApplication.applyCount, 0);
  assert.equal(replayEvidence.replay.decision, "already_applied_idempotent");
  assert.equal(replayRun.withdrawalIntents.length, 0);

  return { firstRun, replayRun };
}

async function runDuplicateReplay(options: PilotE2EOptions, statePath: string): Promise<BridgePipelineResult> {
  const duplicateRun = await runBridgePipeline(parseBridgeArgs(pipelineArgs(options, statePath, options.duplicateFixturePath)));
  const applied = duplicateRun.credits.filter((credit) => credit.status === "applied");
  const rejected = duplicateRun.credits.filter((credit) => credit.status === "rejected");

  assert.equal(duplicateRun.observations.length, 2);
  assert.equal(applied.length, 1);
  assert.equal(rejected.length, 1);
  assert.equal(rejected[0]?.rejectionReason, "duplicate_replay_key");
  assert.equal(duplicateRun.handoff.replayProtection.duplicateReplayKeys.length, 1);
  assert.equal(duplicateRun.withdrawalIntents.length, 1);
  return duplicateRun;
}

function buildExactValueReport(firstRun: BridgePipelineResult): Record<string, unknown> {
  const observation = first(firstRun.observations, "observations");
  const credit = first(firstRun.credits, "credits");
  const application = first(firstRun.runtimeApplications, "runtime applications");
  const withdrawal = first(firstRun.withdrawalIntents, "withdrawal intents");
  const releaseEvidence = first(firstRun.releaseEvidences, "release evidence");

  const amounts = {
    eventAmount: observation.deposit.amount,
    observedDepositAmount: observation.deposit.amount,
    pendingCreditAmount: credit.amount,
    creditApplicationRequestAmount: application.amount,
    runtimeWalletCreditAmount: application.amount,
    transferAmount: withdrawal.amount,
    withdrawalIntentAmount: withdrawal.amount,
    releaseEvidenceAmount: releaseEvidence.releaseCall.amount,
  };
  const uniqueAmounts = new Set(Object.values(amounts));
  assert.equal(uniqueAmounts.size, 1, canonicalJson({ amounts }));

  assert.equal(credit.token, observation.deposit.token);
  assert.equal(withdrawal.token, credit.token);
  assert.equal(releaseEvidence.releaseCall.token, withdrawal.token);
  assert.deepEqual(credit.asset, observation.asset);
  assert.deepEqual(application.asset, credit.asset);
  assert.deepEqual(withdrawal.asset, credit.asset);
  assert.deepEqual(releaseEvidence.asset, credit.asset);
  assert.equal(withdrawal.flowchainAccount, credit.flowchainRecipient);
  assert.equal(releaseEvidence.releaseCall.recipient, withdrawal.baseRecipient);

  return {
    schema: "flowmemory.bridge_exact_value_report.v0",
    generatedAt: new Date().toISOString(),
    mode: firstRun.handoff.mode,
    allAmountsEqual: true,
    amountSourceOfTruth: "uint256 decimal string",
    amounts,
    assetIdentity: {
      sourceChainId: observation.deposit.sourceChainId,
      sourceToken: observation.deposit.token,
      destinationAssetId: credit.asset.destinationAssetId,
      decimals: credit.asset.decimals,
      flowchainRecipient: credit.flowchainRecipient,
      baseRecipient: withdrawal.baseRecipient,
      txHash: observation.deposit.txHash,
      logIndex: observation.deposit.logIndex,
      creditId: credit.creditId,
    },
    replayKey: observation.replayKey,
    depositId: observation.deposit.depositId,
    noSecrets: true,
  };
}

function failedCheckNames(checks: Record<string, boolean>): string[] {
  return Object.entries(checks)
    .filter(([, passed]) => passed !== true)
    .map(([name]) => name);
}

async function assertNegativeCoverage(options: PilotE2EOptions): Promise<{
  wrongChainRejected: boolean;
  wrongChainRejectionReason: string;
  unapprovedContractRejected: boolean;
  unapprovedContractRejectionReason: string;
}> {
  const wrongChainRun = await runBridgePipeline(parseBridgeArgs(pipelineArgs({
      ...options,
      fixturePath: resolve(REPO_ROOT, "fixtures/bridge/base-sepolia-mock-deposit.json"),
    }, resolve(options.outDir, "wrong-chain-state.json"))));
  const wrongChainCredit = first(wrongChainRun.credits, "wrong-chain credits");
  assert.equal(wrongChainCredit.status, "rejected");
  assert.equal(wrongChainCredit.rejectionReason, "wrong_source_chain");
  assert.equal(wrongChainRun.runtimeApplications.filter((application) => application.status === "applied").length, 0);
  assert.equal(wrongChainRun.withdrawalIntents.length, 0);
  assert.equal(wrongChainRun.releaseEvidences.length, 0);

  const unapprovedRun = await runBridgePipeline(parseBridgeArgs(pipelineArgs({
      ...options,
      approvedLockbox: WRONG_APPROVED_LOCKBOX,
    }, resolve(options.outDir, "unapproved-state.json"))));
  const unapprovedCredit = first(unapprovedRun.credits, "unapproved credits");
  assert.equal(unapprovedCredit.status, "rejected");
  assert.equal(unapprovedCredit.rejectionReason, "unapproved_lockbox");
  assert.equal(unapprovedRun.runtimeApplications.filter((application) => application.status === "applied").length, 0);
  assert.equal(unapprovedRun.withdrawalIntents.length, 0);
  assert.equal(unapprovedRun.releaseEvidences.length, 0);

  return {
    wrongChainRejected: true,
    wrongChainRejectionReason: wrongChainCredit.rejectionReason,
    unapprovedContractRejected: true,
    unapprovedContractRejectionReason: unapprovedCredit.rejectionReason,
  };
}

async function main(): Promise<void> {
  const options = parsePilotE2EArgs(process.argv.slice(2));
  rmSync(options.outDir, { recursive: true, force: true });
  mkdirSync(options.outDir, { recursive: true });

  console.log(`Step 1 complete: resolved bridge pilot E2E mode ${options.mode}.`);
  console.log("Next operator command: npm run flowchain:real-value-pilot:bridge");

  const statePath = resolve(options.outDir, "bridge-credit-application-state.json");
  const duplicateStatePath = resolve(options.outDir, "bridge-duplicate-credit-application-state.json");
  const { firstRun, replayRun } = await runFirstAndReplay(options, statePath);
  console.log("Step 2 complete: first local credit application and same-event replay were checked.");
  console.log("Next operator command: Get-Content services/bridge-relayer/out/real-value-pilot-e2e/bridge-pilot-evidence.json");

  const duplicateRun = await runDuplicateReplay(options, duplicateStatePath);
  console.log("Step 3 complete: duplicate deposit fixture replay was rejected with evidence.");
  console.log("Next operator command: Get-Content services/bridge-relayer/out/real-value-pilot-e2e/bridge-replay-handoff.json");

  const negativeCoverage = await assertNegativeCoverage(options);
  console.log("Step 4 complete: wrong-chain and unapproved-contract negative checks passed.");
  console.log("Next operator command: npm test --prefix services/bridge-relayer");

  const observation = first(firstRun.observations, "observations");
  const credit = first(firstRun.credits, "credits");
  const evidence = first(firstRun.pilotEvidence, "pilot evidence");
  const withdrawal = first(firstRun.withdrawalIntents, "withdrawal intents");
  const releaseEvidence = first(firstRun.releaseEvidences, "release evidence");
  const firstApplication = first(firstRun.runtimeApplications, "first applications");
  const replayApplication = first(replayRun.runtimeApplications, "replay applications");
  const replayCredit = first(replayRun.credits, "replay credits");

  const observationPath = resolve(options.outDir, "bridge-observation.json");
  const creditPath = resolve(options.outDir, "bridge-credit.json");
  const evidencePath = resolve(options.outDir, "bridge-pilot-evidence.json");
  const releaseEvidencePath = resolve(options.outDir, "bridge-release-evidence.json");
  const withdrawalPath = resolve(options.outDir, "bridge-withdrawal-intent.json");
  const handoffPath = resolve(options.outDir, "bridge-runtime-handoff.json");
  const replayHandoffPath = resolve(options.outDir, "bridge-replay-handoff.json");
  const exactValuePath = resolve(options.outDir, "bridge-exact-value-report.json");
  const exactValueReport = buildExactValueReport(firstRun);

  writeJson(observationPath, observation);
  writeJson(creditPath, credit);
  writeJson(evidencePath, evidence);
  writeJson(releaseEvidencePath, releaseEvidence);
  writeJson(withdrawalPath, withdrawal);
  writeJson(handoffPath, firstRun.handoff);
  writeJson(replayHandoffPath, duplicateRun.handoff);
  writeJson(exactValuePath, exactValueReport);

  [
    observation,
    credit,
    evidence,
    releaseEvidence,
    withdrawal,
    firstRun.handoff,
    replayRun.handoff,
    duplicateRun.handoff,
    exactValueReport,
  ].forEach((artifact) => assertNoSecrets(artifact));

  const checks = {
    sourceChainIsBase8453: observation.deposit.sourceChainId === BASE_MAINNET_CHAIN_ID,
    firstCreditApplied: credit.status === "applied",
    firstApplicationAppliedOnce: firstApplication.status === "applied" && firstApplication.applyCount === 1,
    replayCreditRejected: replayCredit.status === "rejected",
    replayApplicationIdempotent: replayApplication.status === "idempotent_replay" && replayApplication.applyCount === 0,
    duplicateReplayRejected: duplicateRun.handoff.replayProtection.duplicateReplayKeys.length > 0,
    exactValueConserved: (exactValueReport as { allAmountsEqual?: unknown }).allAmountsEqual === true,
    wrongChainRejected: negativeCoverage.wrongChainRejected === true,
    unapprovedContractRejected: negativeCoverage.unapprovedContractRejected === true,
    withdrawalIntentCreated: withdrawal.status === "requested",
    releaseEvidenceNoBroadcast: releaseEvidence.releaseCall.broadcast === false,
    noLiveBroadcast: releaseEvidence.releaseCall.broadcast === false,
    noSecrets: true,
  };
  const failedChecks = failedCheckNames(checks);
  assert.deepEqual(failedChecks, [], canonicalJson({ failedChecks, checks }));

  const report = {
    schema: "flowmemory.bridge_real_value_pilot_e2e_report.v0",
    generatedAt: new Date().toISOString(),
    status: "passed",
    mode: options.mode,
    sourceChain: {
      chainId: BASE_MAINNET_CHAIN_ID,
      chainIdHex: BASE_MAINNET_CHAIN_ID_HEX,
    },
    productionReady: false,
    broadcast: false,
    artifacts: {
      observationPath: relativeToRepo(observationPath),
      creditPath: relativeToRepo(creditPath),
      pilotEvidencePath: relativeToRepo(evidencePath),
      releaseEvidencePath: relativeToRepo(releaseEvidencePath),
      withdrawalIntentPath: relativeToRepo(withdrawalPath),
      runtimeHandoffPath: relativeToRepo(handoffPath),
      replayHandoffPath: relativeToRepo(replayHandoffPath),
      applicationStatePath: relativeToRepo(statePath),
      exactValueReportPath: relativeToRepo(exactValuePath),
    },
    deterministicIds: {
      observationId: observation.observationId,
      replayKey: observation.replayKey,
      creditId: credit.creditId,
      evidenceId: evidence.evidenceId,
      releaseEvidenceId: releaseEvidence.releaseEvidenceId,
      withdrawalIntentId: withdrawal.withdrawalIntentId,
    },
    exactlyOnce: {
      firstApplicationStatus: first(firstRun.runtimeApplications, "first applications").status,
      replayApplicationStatus: first(replayRun.runtimeApplications, "replay applications").status,
      replayCreditStatus: first(replayRun.credits, "replay credits").status,
      appliedOnce: true,
    },
    replayProtection: {
      duplicateReplayKeys: duplicateRun.handoff.replayProtection.duplicateReplayKeys,
      rejectedCreditIds: duplicateRun.credits
        .filter((replayCredit) => replayCredit.status === "rejected")
        .map((replayCredit) => replayCredit.creditId),
      decision: "duplicate_replay_key_rejected",
    },
    withdrawalReleaseEvidence: {
      withdrawalIntentId: withdrawal.withdrawalIntentId,
      releaseEvidenceId: releaseEvidence.releaseEvidenceId,
      broadcast: releaseEvidence.releaseCall.broadcast,
      method: releaseEvidence.releaseCall.method,
    },
    exactValueConservation: exactValueReport,
    negativeCoverage,
    requiredEnvironmentVariables: [
      "FLOWCHAIN_BASE8453_RPC_URL",
      "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
      "FLOWCHAIN_BASE8453_FROM_BLOCK",
      "FLOWCHAIN_BASE8453_TO_BLOCK",
      "FLOWCHAIN_BASE8453_CONFIRMATIONS",
      "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
      "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
      "FLOWCHAIN_PILOT_MAX_USD",
      "FLOWCHAIN_PILOT_OPERATOR_ACK",
    ],
    liveObserverCommand: "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/bridge-base-mainnet-pilot-observe.ps1 -OperatorAck -ApplyCredit -WithdrawalIntent",
    noSecrets: true,
    checks,
    failedChecks,
  };
  assertNoSecrets(report);

  const reportPath = resolve(options.outDir, "bridge-real-value-pilot-e2e-report.json");
  writeJson(reportPath, report);

  console.log("Step 5 complete: bridge pilot E2E artifacts were written.");
  console.log(`Next operator command: Get-Content ${relativeToRepo(reportPath)}`);
  console.log(`Bridge pilot E2E report: ${relativeToRepo(reportPath)}`);
}

await main();
