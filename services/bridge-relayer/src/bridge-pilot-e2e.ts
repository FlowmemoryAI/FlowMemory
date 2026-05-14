import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { assertNoSecrets } from "../../shared/src/index.ts";
import {
  BASE_MAINNET_CHAIN_ID,
  BASE_MAINNET_CHAIN_ID_HEX,
  parseBridgeArgs,
  runBridgePipeline,
  type BridgeCredit,
  type BridgeDeposit,
  type BridgeMode,
  type BridgePipelineResult,
  type BridgeWithdrawalIntent,
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
  supportedToken: string;
}

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const DEFAULT_FIXTURE = resolve(REPO_ROOT, "fixtures/bridge/base8453-pilot-mock-deposit.json");
const DEFAULT_DUPLICATE_FIXTURE = resolve(REPO_ROOT, "fixtures/bridge/base8453-pilot-duplicate-mock-deposits.json");
const DEFAULT_OUT_DIR = resolve(REPO_ROOT, "services/bridge-relayer/out/real-value-pilot-e2e");
const DEFAULT_APPROVED_LOCKBOX = "0x1111111111111111111111111111111111111111";
const DEFAULT_SUPPORTED_TOKEN = "0x3333333333333333333333333333333333333333";
const WRONG_APPROVED_LOCKBOX = "0x9999999999999999999999999999999999999999";
const SECOND_FLOWCHAIN_RECIPIENT = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";

interface BridgeLocalUsageProof {
  schema: "flowmemory.bridge_local_usage_proof.v0";
  generatedAt: string;
  creditId: `0x${string}`;
  sourceRecipient: `0x${string}`;
  secondRecipient: `0x${string}`;
  transfer: {
    transferId: `0x${string}`;
    amount: string;
    status: "prepared";
    broadcast: false;
  };
  balances: {
    creditedWalletAfterCredit: string;
    creditedWalletAfterTransfer: string;
    secondWalletAfterTransfer: string;
  };
  productOrDexFlow: {
    supportedByCommand: "npm run flowchain:product-e2e";
    bridgeRelayerExecutesProductTrade: false;
    status: "covered_by_existing_local_gate";
  };
  localOnly: true;
  noSecrets: true;
}

interface BridgeWithdrawalAuthorization {
  schema: "flowmemory.bridge_withdrawal_authorization.v0";
  generatedAt: string;
  authorizationId: `0x${string}`;
  withdrawalIntentId: `0x${string}`;
  creditId: `0x${string}`;
  depositId: `0x${string}`;
  flowchainChainId: "flowchain-local-pilot-v0";
  destinationChainId: number;
  token: `0x${string}`;
  amount: string;
  flowchainAccount: `0x${string}`;
  baseRecipient: `0x${string}`;
  withdrawalNonce: string;
  signedBy: `0x${string}`;
  signatureScheme: "flowchain-pilot-deterministic-test-signature-v0";
  signedPayloadHash: `0x${string}`;
  signature: `0x${string}`;
  localOnly: true;
  noSecrets: true;
}

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
  let supportedToken = DEFAULT_SUPPORTED_TOKEN;

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
      supportedToken = argValue(args, index, arg);
      index += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

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
    supportedToken,
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
    "--supported-token",
    options.supportedToken,
    "--apply-credit",
    "--withdrawal-intent",
    "--runtime-state",
    statePath,
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

function stableProofId(schema: string, value: unknown): `0x${string}` {
  return `0x${createHash("sha256").update(JSON.stringify({ schema, value })).digest("hex")}`;
}

function makeLocalUsageProof(credit: BridgeCredit): BridgeLocalUsageProof {
  assert.equal(credit.status, "applied");
  const creditedAmount = BigInt(credit.amount);
  assert.ok(creditedAmount > 0n, "local usage proof requires a positive credited amount");
  const transferAmount = creditedAmount / 2n > 0n ? creditedAmount / 2n : creditedAmount;
  const creditedWalletAfterTransfer = creditedAmount - transferAmount;
  const transferId = stableProofId("flowmemory.bridge_local_transfer.v0", {
    creditId: credit.creditId,
    from: credit.flowchainRecipient,
    to: SECOND_FLOWCHAIN_RECIPIENT,
    amount: transferAmount.toString(),
  });

  return {
    schema: "flowmemory.bridge_local_usage_proof.v0",
    generatedAt: new Date().toISOString(),
    creditId: credit.creditId,
    sourceRecipient: credit.flowchainRecipient,
    secondRecipient: SECOND_FLOWCHAIN_RECIPIENT,
    transfer: {
      transferId,
      amount: transferAmount.toString(),
      status: "prepared",
      broadcast: false,
    },
    balances: {
      creditedWalletAfterCredit: creditedAmount.toString(),
      creditedWalletAfterTransfer: creditedWalletAfterTransfer.toString(),
      secondWalletAfterTransfer: transferAmount.toString(),
    },
    productOrDexFlow: {
      supportedByCommand: "npm run flowchain:product-e2e",
      bridgeRelayerExecutesProductTrade: false,
      status: "covered_by_existing_local_gate",
    },
    localOnly: true,
    noSecrets: true,
  };
}

function makeWithdrawalAuthorization(
  withdrawal: BridgeWithdrawalIntent,
  deposit: BridgeDeposit,
): BridgeWithdrawalAuthorization {
  const flowchainChainId = "flowchain-local-pilot-v0";
  const withdrawalNonce = deposit.nonce;
  const signedPayloadHash = stableProofId("flowmemory.bridge_withdrawal_payload.v0", {
    withdrawalIntentId: withdrawal.withdrawalIntentId,
    creditId: withdrawal.creditId,
    depositId: withdrawal.depositId,
    flowchainChainId,
    destinationChainId: withdrawal.destinationChainId,
    token: withdrawal.token,
    amount: withdrawal.amount,
    flowchainAccount: withdrawal.flowchainAccount,
    baseRecipient: withdrawal.baseRecipient,
    withdrawalNonce,
  });
  const signature = stableProofId("flowmemory.bridge_withdrawal_signature.v0", {
    signedBy: withdrawal.flowchainAccount,
    signedPayloadHash,
    signatureScheme: "flowchain-pilot-deterministic-test-signature-v0",
  });

  return {
    schema: "flowmemory.bridge_withdrawal_authorization.v0",
    generatedAt: new Date().toISOString(),
    authorizationId: stableProofId("flowmemory.bridge_withdrawal_authorization.v0", {
      withdrawalIntentId: withdrawal.withdrawalIntentId,
      signedPayloadHash,
      signature,
    }),
    withdrawalIntentId: withdrawal.withdrawalIntentId,
    creditId: withdrawal.creditId,
    depositId: withdrawal.depositId,
    flowchainChainId,
    destinationChainId: withdrawal.destinationChainId,
    token: withdrawal.token,
    amount: withdrawal.amount,
    flowchainAccount: withdrawal.flowchainAccount,
    baseRecipient: withdrawal.baseRecipient,
    withdrawalNonce,
    signedBy: withdrawal.flowchainAccount,
    signatureScheme: "flowchain-pilot-deterministic-test-signature-v0",
    signedPayloadHash,
    signature,
    localOnly: true,
    noSecrets: true,
  };
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

async function assertNegativeCoverage(options: PilotE2EOptions): Promise<{
  wrongChainRejected: boolean;
  unapprovedContractRejected: boolean;
}> {
  await assert.rejects(
    () => runBridgePipeline(parseBridgeArgs(pipelineArgs({
      ...options,
      fixturePath: resolve(REPO_ROOT, "fixtures/bridge/base-sepolia-mock-deposit.json"),
    }, resolve(options.outDir, "wrong-chain-state.json")))),
    /pilot deposit must be from Base chain 8453/,
  );

  await assert.rejects(
    () => runBridgePipeline(parseBridgeArgs(pipelineArgs({
      ...options,
      approvedLockbox: WRONG_APPROVED_LOCKBOX,
    }, resolve(options.outDir, "unapproved-state.json")))),
    /unapproved bridge lockbox address/,
  );

  return {
    wrongChainRejected: true,
    unapprovedContractRejected: true,
  };
}

async function main(): Promise<void> {
  const options = parsePilotE2EArgs(process.argv.slice(2));
  rmSync(options.outDir, { recursive: true, force: true });
  mkdirSync(options.outDir, { recursive: true });

  console.log(`Step 1 complete: resolved bridge pilot E2E mode ${options.mode}.`);
  console.log("Next operator command: node services/bridge-relayer/src/bridge-pilot-e2e.ts --mode mock-pilot");

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
  const localUsage = makeLocalUsageProof(credit);
  const withdrawalAuthorization = makeWithdrawalAuthorization(withdrawal, observation.deposit);

  const observationPath = resolve(options.outDir, "bridge-observation.json");
  const creditPath = resolve(options.outDir, "bridge-credit.json");
  const evidencePath = resolve(options.outDir, "bridge-pilot-evidence.json");
  const releaseEvidencePath = resolve(options.outDir, "bridge-release-evidence.json");
  const withdrawalPath = resolve(options.outDir, "bridge-withdrawal-intent.json");
  const withdrawalAuthorizationPath = resolve(options.outDir, "bridge-withdrawal-authorization.json");
  const localUsagePath = resolve(options.outDir, "bridge-local-usage-proof.json");
  const handoffPath = resolve(options.outDir, "bridge-runtime-handoff.json");
  const replayHandoffPath = resolve(options.outDir, "bridge-replay-handoff.json");

  writeJson(observationPath, observation);
  writeJson(creditPath, credit);
  writeJson(evidencePath, evidence);
  writeJson(releaseEvidencePath, releaseEvidence);
  writeJson(withdrawalPath, withdrawal);
  writeJson(withdrawalAuthorizationPath, withdrawalAuthorization);
  writeJson(localUsagePath, localUsage);
  writeJson(handoffPath, firstRun.handoff);
  writeJson(replayHandoffPath, duplicateRun.handoff);

  [
    observation,
    credit,
    evidence,
    releaseEvidence,
    withdrawal,
    withdrawalAuthorization,
    localUsage,
    firstRun.handoff,
    replayRun.handoff,
    duplicateRun.handoff,
  ].forEach((artifact) => assertNoSecrets(artifact));

  const report = {
    schema: "flowmemory.bridge_real_value_pilot_e2e_report.v0",
    generatedAt: new Date().toISOString(),
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
      withdrawalAuthorizationPath: relativeToRepo(withdrawalAuthorizationPath),
      localUsagePath: relativeToRepo(localUsagePath),
      runtimeHandoffPath: relativeToRepo(handoffPath),
      replayHandoffPath: relativeToRepo(replayHandoffPath),
      applicationStatePath: relativeToRepo(statePath),
    },
    deterministicIds: {
      observationId: observation.observationId,
      replayKey: observation.replayKey,
      creditId: credit.creditId,
      evidenceId: evidence.evidenceId,
      releaseEvidenceId: releaseEvidence.releaseEvidenceId,
      withdrawalIntentId: withdrawal.withdrawalIntentId,
      withdrawalAuthorizationId: withdrawalAuthorization.authorizationId,
      localTransferId: localUsage.transfer.transferId,
    },
    supportedToken: options.supportedToken,
    localUsage: {
      transferPrepared: true,
      secondRecipient: localUsage.secondRecipient,
      transferAmount: localUsage.transfer.amount,
      productOrDexCoveredBy: localUsage.productOrDexFlow.supportedByCommand,
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
    negativeCoverage,
    requiredEnvironmentVariables: [
      "FLOWCHAIN_BASE8453_RPC_URL",
      "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
      "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
      "FLOWCHAIN_BASE8453_FROM_BLOCK",
      "FLOWCHAIN_BASE8453_TO_BLOCK",
      "FLOWCHAIN_PILOT_CONFIRMATIONS",
      "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
      "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
      "FLOWCHAIN_PILOT_MAX_USD",
      "FLOWCHAIN_PILOT_OPERATOR_ACK",
    ],
    liveObserverCommand: "powershell -NoProfile -ExecutionPolicy Bypass -File infra/scripts/bridge-base-mainnet-pilot-observe.ps1 -OperatorAck -ApplyCredit -WithdrawalIntent",
    noSecrets: true,
  };
  assertNoSecrets(report);

  const reportPath = resolve(options.outDir, "bridge-real-value-pilot-e2e-report.json");
  writeJson(reportPath, report);

  console.log("Step 5 complete: bridge pilot E2E artifacts were written.");
  console.log(`Next operator command: Get-Content ${relativeToRepo(reportPath)}`);
  console.log(`Bridge pilot E2E report: ${relativeToRepo(reportPath)}`);
}

await main();
