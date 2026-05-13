import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  canonicalJson,
  decodeAddressTopic,
  decodeBytes32Word,
  decodeUint256Word,
  hexToBytes,
  keccak256Utf8,
  normalizeAddress,
  normalizeBytes32,
} from "../../shared/src/index.ts";

export const BASE_MAINNET_CHAIN_ID = 8453;
export const BASE_SEPOLIA_CHAIN_ID = 84532;
export const LOCAL_ANVIL_CHAIN_ID = 31337;
export const MAX_CANARY_USD = 25;
export const MAX_BLOCK_RANGE = 5_000n;
export const BRIDGE_DEPOSIT_EVENT_SIGNATURE_TEXT =
  "BridgeDeposit(bytes32,uint256,address,address,uint256,bytes32,uint256,bytes32)";
export const BRIDGE_DEPOSIT_TOPIC0 = keccak256Utf8(BRIDGE_DEPOSIT_EVENT_SIGNATURE_TEXT);
export const FIXED_TEST_OBSERVED_AT = "2026-05-13T00:00:00.000Z";

type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue | undefined };

export type BridgeSourceChainId =
  | typeof LOCAL_ANVIL_CHAIN_ID
  | typeof BASE_SEPOLIA_CHAIN_ID
  | typeof BASE_MAINNET_CHAIN_ID;

export type BridgeMode = "mock" | "local-anvil" | "base-sepolia" | "base-mainnet-canary";

export interface BridgeDeposit {
  schema: "flowmemory.bridge_deposit.v0";
  depositId: `0x${string}`;
  sourceChainId: BridgeSourceChainId;
  sourceContract: `0x${string}`;
  txHash: `0x${string}`;
  logIndex: number;
  sourceBlockNumber?: string;
  sourceBlockHash?: `0x${string}`;
  transactionIndex?: number;
  token: `0x${string}`;
  amount: string;
  sender: `0x${string}`;
  flowchainRecipient: `0x${string}`;
  nonce: string;
  metadataHash?: `0x${string}`;
  status: "observed" | "accepted_local" | "rejected" | "released" | "failed";
}

export interface BridgeObservation {
  schema: "flowmemory.bridge_deposit_observation.v0";
  observationId: `0x${string}`;
  replayKey: `0x${string}`;
  observedAt: string;
  mode: BridgeMode;
  productionReady: false;
  deposit: BridgeDeposit;
  guardrails: {
    explicitChainId: boolean;
    explicitContract: boolean;
    explicitBlockRange: boolean;
    noSecrets: boolean;
    maxUsd?: number;
  };
}

export interface BridgeObservationSet {
  schema: "flowmemory.bridge_observation_set.v0";
  observationSetId: `0x${string}`;
  observedAt: string;
  mode: BridgeMode;
  productionReady: false;
  count: number;
  observations: BridgeObservation[];
}

export interface BridgeCredit {
  schema: "flowmemory.bridge_credit.v0";
  creditId: `0x${string}`;
  observationId: `0x${string}`;
  depositId: `0x${string}`;
  replayKey: `0x${string}`;
  source: {
    chainId: BridgeSourceChainId;
    contract: `0x${string}`;
    txHash: `0x${string}`;
    logIndex: number;
  };
  token: `0x${string}`;
  amount: string;
  flowchainRecipient: `0x${string}`;
  status: "pending" | "applied" | "rejected";
  pendingReason?: string;
  appliedAt?: string;
  rejectionReason?: string;
  localOnly: true;
  productionReady: false;
}

export interface BridgeCreditSet {
  schema: "flowmemory.bridge_credit_set.v0";
  creditSetId: `0x${string}`;
  generatedAt: string;
  count: number;
  credits: BridgeCredit[];
  productionReady: false;
}

export interface BridgeWithdrawalIntent {
  schema: "flowmemory.bridge_withdrawal_intent.v0";
  withdrawalIntentId: `0x${string}`;
  creditId: `0x${string}`;
  depositId: `0x${string}`;
  sourceChainId: BridgeSourceChainId;
  destinationChainId: BridgeSourceChainId;
  token: `0x${string}`;
  amount: string;
  flowchainAccount: `0x${string}`;
  baseRecipient: `0x${string}`;
  status: "requested" | "cancelled" | "released_test_record" | "rejected";
  requestedAt: string;
  testMode: true;
  broadcast: false;
  releasePolicy: "test_record_only";
  productionReady: false;
}

export interface BridgeWithdrawalIntentSet {
  schema: "flowmemory.bridge_withdrawal_intent_set.v0";
  withdrawalIntentSetId: `0x${string}`;
  generatedAt: string;
  count: number;
  withdrawalIntents: BridgeWithdrawalIntent[];
  productionReady: false;
}

export interface BridgeRuntimeHandoff {
  schema: "flowmemory.bridge_runtime_handoff.v0";
  handoffId: `0x${string}`;
  generatedAt: string;
  mode: BridgeMode;
  productionReady: false;
  localOnly: true;
  observations: BridgeObservation[];
  credits: BridgeCredit[];
  withdrawalIntents: BridgeWithdrawalIntent[];
  replayProtection: {
    strategy: "source-chain-contract-tx-log-deposit";
    replayKeys: `0x${string}`[];
    duplicateReplayKeys: `0x${string}`[];
  };
  runtimeIntake: {
    status: "handoff_file";
    consumer: "flowchain-runtime-agent";
    expectedPath: string;
    note: string;
  };
  workbenchTimeline: {
    phase: "deposit_observed" | "credit_pending" | "credit_applied" | "withdrawal_requested";
    status: "observed" | "pending" | "applied" | "requested";
    objectId: `0x${string}`;
    title: string;
    summary: string;
  }[];
  workbenchRecords: {
    sectionKey: "transactions" | "receipts" | "finality" | "rawJson";
    id: `0x${string}`;
    kind: string;
    title: string;
    summary: string;
    status: "observed" | "pending" | "verified";
    facts: { label: string; value: string }[];
    rawRef: `0x${string}`;
  }[];
  limitations: string[];
}

interface CliOptions {
  mode: BridgeMode;
  fixturePath?: string;
  outPath: string;
  creditOutPath?: string;
  handoffOutPath?: string;
  withdrawalOutPath?: string;
  rpcUrl?: string;
  lockboxAddress?: `0x${string}`;
  fromBlock?: string;
  toBlock?: string;
  expectedChainId?: BridgeSourceChainId;
  acknowledgeRealFunds: boolean;
  maxUsd?: number;
  applyCredit: boolean;
  withdrawalIntent: boolean;
  withdrawalBaseRecipient?: `0x${string}`;
}

export interface BridgePipelineResult {
  observations: BridgeObservation[];
  credits: BridgeCredit[];
  withdrawalIntents: BridgeWithdrawalIntent[];
  handoff: BridgeRuntimeHandoff;
}

interface RpcLog {
  address: string;
  topics: string[];
  data: string;
  blockNumber?: string;
  blockHash?: string;
  transactionHash: string;
  transactionIndex?: string;
  logIndex: string;
  removed?: boolean;
}

function stableId(schema: string, value: JsonValue): `0x${string}` {
  return keccak256Utf8(canonicalJson({ schema, value }));
}

function argValue(args: string[], index: number, name: string): string {
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function asAddress(value: string, name: string): `0x${string}` {
  try {
    return normalizeAddress(value) as `0x${string}`;
  } catch {
    throw new Error(`${name} must be a 20-byte hex address`);
  }
}

function asHash(value: string, name: string): `0x${string}` {
  try {
    return normalizeBytes32(value) as `0x${string}`;
  } catch {
    throw new Error(`${name} must be a 32-byte hex value`);
  }
}

function asDecimalString(value: unknown, name: string): string {
  const text = String(value);
  if (!/^[0-9]+$/.test(text)) {
    throw new Error(`${name} must be a decimal string`);
  }
  return text;
}

function asNonNegativeInteger(value: unknown, name: string): number {
  const number = Number(value);
  if (!Number.isInteger(number) || number < 0) {
    throw new Error(`${name} must be a non-negative integer`);
  }
  return number;
}

function asBlock(value: string, name: string): bigint {
  if (!/^[0-9]+$/.test(value)) {
    throw new Error(`${name} must be a decimal block number`);
  }
  return BigInt(value);
}

function asSourceChainId(value: unknown, name: string): BridgeSourceChainId {
  const chainId = Number(value);
  if (
    chainId !== LOCAL_ANVIL_CHAIN_ID
    && chainId !== BASE_SEPOLIA_CHAIN_ID
    && chainId !== BASE_MAINNET_CHAIN_ID
  ) {
    throw new Error(`${name} must be ${LOCAL_ANVIL_CHAIN_ID}, ${BASE_SEPOLIA_CHAIN_ID}, or ${BASE_MAINNET_CHAIN_ID}`);
  }
  return chainId as BridgeSourceChainId;
}

function expectedChainIdForMode(mode: BridgeMode, explicit?: BridgeSourceChainId): BridgeSourceChainId {
  if (explicit !== undefined) {
    return explicit;
  }
  if (mode === "local-anvil") {
    return LOCAL_ANVIL_CHAIN_ID;
  }
  if (mode === "base-sepolia") {
    return BASE_SEPOLIA_CHAIN_ID;
  }
  return BASE_MAINNET_CHAIN_ID;
}

export function parseBridgeArgs(args: string[]): CliOptions {
  let mode: CliOptions["mode"] = "mock";
  let fixturePath: string | undefined;
  let outPath = "out/bridge-observation.json";
  let creditOutPath: string | undefined;
  let handoffOutPath: string | undefined;
  let withdrawalOutPath: string | undefined;
  let rpcUrl: string | undefined;
  let lockboxAddress: `0x${string}` | undefined;
  let fromBlock: string | undefined;
  let toBlock: string | undefined;
  let expectedChainId: BridgeSourceChainId | undefined;
  let acknowledgeRealFunds = false;
  let maxUsd: number | undefined;
  let applyCredit = false;
  let withdrawalIntent = false;
  let withdrawalBaseRecipient: `0x${string}` | undefined;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--mode") {
      const value = argValue(args, index, arg);
      if (
        value !== "mock"
        && value !== "local-anvil"
        && value !== "base-sepolia"
        && value !== "base-mainnet-canary"
      ) {
        throw new Error("--mode must be mock, local-anvil, base-sepolia, or base-mainnet-canary");
      }
      mode = value;
      index += 1;
    } else if (arg === "--fixture") {
      fixturePath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--out") {
      outPath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--credit-out") {
      creditOutPath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--handoff-out") {
      handoffOutPath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--withdrawal-out") {
      withdrawalOutPath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--rpc-url") {
      rpcUrl = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--lockbox-address") {
      lockboxAddress = asAddress(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--from-block") {
      fromBlock = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--to-block") {
      toBlock = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--expected-chain-id") {
      expectedChainId = asSourceChainId(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--acknowledge-real-funds") {
      acknowledgeRealFunds = true;
    } else if (arg === "--max-usd") {
      maxUsd = Number(argValue(args, index, arg));
      index += 1;
    } else if (arg === "--apply-credit") {
      applyCredit = true;
    } else if (arg === "--withdrawal-intent") {
      withdrawalIntent = true;
    } else if (arg === "--withdrawal-base-recipient") {
      withdrawalBaseRecipient = asAddress(argValue(args, index, arg), arg);
      index += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  if (mode === "mock" && !fixturePath) {
    throw new Error("--fixture is required in mock mode");
  }

  if (mode !== "mock") {
    if (!rpcUrl || !lockboxAddress || !fromBlock || !toBlock) {
      throw new Error("--rpc-url, --lockbox-address, --from-block, and --to-block are required for RPC reads");
    }
    const from = asBlock(fromBlock, "--from-block");
    const to = asBlock(toBlock, "--to-block");
    if (to < from) {
      throw new Error("--to-block must be greater than or equal to --from-block");
    }
    if ((to - from) > MAX_BLOCK_RANGE) {
      throw new Error(`block range is too wide; max is ${MAX_BLOCK_RANGE.toString()} blocks`);
    }
  }

  if (mode === "base-mainnet-canary") {
    if (!acknowledgeRealFunds) {
      throw new Error("Base mainnet canary requires --acknowledge-real-funds");
    }
    if (maxUsd === undefined || !Number.isFinite(maxUsd) || maxUsd <= 0 || maxUsd > MAX_CANARY_USD) {
      throw new Error(`Base mainnet canary requires --max-usd <= ${MAX_CANARY_USD}`);
    }
  }

  return {
    mode,
    fixturePath,
    outPath,
    creditOutPath,
    handoffOutPath,
    withdrawalOutPath,
    rpcUrl,
    lockboxAddress,
    fromBlock,
    toBlock,
    expectedChainId,
    acknowledgeRealFunds,
    maxUsd,
    applyCredit,
    withdrawalIntent,
    withdrawalBaseRecipient,
  };
}

export function validateDeposit(value: unknown): BridgeDeposit {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("bridge deposit fixture must be an object");
  }
  const deposit = value as Record<string, unknown>;
  if (deposit.schema !== "flowmemory.bridge_deposit.v0") {
    throw new Error("unsupported bridge deposit schema");
  }
  const status = deposit.status;
  if (status !== "observed") {
    throw new Error("fixture status must be observed");
  }

  return {
    schema: "flowmemory.bridge_deposit.v0",
    depositId: asHash(String(deposit.depositId), "depositId"),
    sourceChainId: asSourceChainId(deposit.sourceChainId, "sourceChainId"),
    sourceContract: asAddress(String(deposit.sourceContract), "sourceContract"),
    txHash: asHash(String(deposit.txHash), "txHash"),
    logIndex: asNonNegativeInteger(deposit.logIndex, "logIndex"),
    sourceBlockNumber: deposit.sourceBlockNumber === undefined
      ? undefined
      : asDecimalString(deposit.sourceBlockNumber, "sourceBlockNumber"),
    sourceBlockHash: deposit.sourceBlockHash === undefined
      ? undefined
      : asHash(String(deposit.sourceBlockHash), "sourceBlockHash"),
    transactionIndex: deposit.transactionIndex === undefined
      ? undefined
      : asNonNegativeInteger(deposit.transactionIndex, "transactionIndex"),
    token: asAddress(String(deposit.token), "token"),
    amount: asDecimalString(deposit.amount, "amount"),
    sender: asAddress(String(deposit.sender), "sender"),
    flowchainRecipient: asHash(String(deposit.flowchainRecipient), "flowchainRecipient"),
    nonce: asDecimalString(deposit.nonce, "nonce"),
    metadataHash: deposit.metadataHash === undefined ? undefined : asHash(String(deposit.metadataHash), "metadataHash"),
    status,
  };
}

function fixtureDeposits(fixture: unknown): BridgeDeposit[] {
  if (fixture !== null && typeof fixture === "object" && !Array.isArray(fixture)) {
    const maybeBatch = fixture as Record<string, unknown>;
    if (Array.isArray(maybeBatch.deposits)) {
      return maybeBatch.deposits.map((entry) => validateDeposit(entry));
    }
  }
  return [validateDeposit(fixture)];
}

export function bridgeReplayKey(deposit: BridgeDeposit): `0x${string}` {
  return stableId("flowmemory.bridge_replay_key.v0", {
    sourceChainId: deposit.sourceChainId,
    sourceContract: deposit.sourceContract,
    txHash: deposit.txHash,
    logIndex: deposit.logIndex,
    depositId: deposit.depositId,
  });
}

export function makeObservation(
  deposit: BridgeDeposit,
  mode: BridgeObservation["mode"],
  maxUsd?: number,
): BridgeObservation {
  const replayKey = bridgeReplayKey(deposit);
  return {
    schema: "flowmemory.bridge_deposit_observation.v0",
    observationId: stableId("flowmemory.bridge_observation.v0", {
      mode,
      replayKey,
      depositId: deposit.depositId,
    }),
    replayKey,
    observedAt: FIXED_TEST_OBSERVED_AT,
    mode,
    productionReady: false,
    deposit,
    guardrails: {
      explicitChainId: true,
      explicitContract: true,
      explicitBlockRange: mode !== "mock",
      noSecrets: true,
      ...(maxUsd === undefined ? {} : { maxUsd }),
    },
  };
}

export function makeObservationSet(observations: BridgeObservation[], mode: BridgeMode): BridgeObservationSet {
  return {
    schema: "flowmemory.bridge_observation_set.v0",
    observationSetId: stableId("flowmemory.bridge_observation_set.v0", {
      mode,
      observationIds: observations.map((observation) => observation.observationId),
    }),
    observedAt: FIXED_TEST_OBSERVED_AT,
    mode,
    productionReady: false,
    count: observations.length,
    observations,
  };
}

export function makeBridgeCredit(
  observation: BridgeObservation,
  status: BridgeCredit["status"] = "pending",
  rejectionReason?: string,
): BridgeCredit {
  const deposit = observation.deposit;
  return {
    schema: "flowmemory.bridge_credit.v0",
    creditId: stableId("flowmemory.bridge_credit.v0", {
      observationId: observation.observationId,
      depositId: deposit.depositId,
      replayKey: observation.replayKey,
      sourceChainId: deposit.sourceChainId,
      sourceContract: deposit.sourceContract,
      txHash: deposit.txHash,
      logIndex: deposit.logIndex,
    }),
    observationId: observation.observationId,
    depositId: deposit.depositId,
    replayKey: observation.replayKey,
    source: {
      chainId: deposit.sourceChainId,
      contract: deposit.sourceContract,
      txHash: deposit.txHash,
      logIndex: deposit.logIndex,
    },
    token: deposit.token,
    amount: deposit.amount,
    flowchainRecipient: deposit.flowchainRecipient,
    status,
    pendingReason: status === "pending" ? "runtime_intake_pending_handoff_file" : undefined,
    appliedAt: status === "applied" ? FIXED_TEST_OBSERVED_AT : undefined,
    rejectionReason,
    localOnly: true,
    productionReady: false,
  };
}

export function makeCreditSet(credits: BridgeCredit[]): BridgeCreditSet {
  return {
    schema: "flowmemory.bridge_credit_set.v0",
    creditSetId: stableId("flowmemory.bridge_credit_set.v0", {
      creditIds: credits.map((credit) => credit.creditId),
    }),
    generatedAt: FIXED_TEST_OBSERVED_AT,
    count: credits.length,
    credits,
    productionReady: false,
  };
}

function makeCredits(observations: BridgeObservation[], applyCredit: boolean): BridgeCredit[] {
  const seen = new Set<`0x${string}`>();
  return observations.map((observation) => {
    if (seen.has(observation.replayKey)) {
      return makeBridgeCredit(observation, "rejected", "duplicate_replay_key");
    }
    seen.add(observation.replayKey);
    return makeBridgeCredit(observation, applyCredit ? "applied" : "pending");
  });
}

export function makeWithdrawalIntent(
  credit: BridgeCredit,
  deposit: BridgeDeposit,
  baseRecipient: `0x${string}` = deposit.sender,
): BridgeWithdrawalIntent {
  return {
    schema: "flowmemory.bridge_withdrawal_intent.v0",
    withdrawalIntentId: stableId("flowmemory.bridge_withdrawal_intent.v0", {
      creditId: credit.creditId,
      depositId: credit.depositId,
      destinationChainId: deposit.sourceChainId,
      token: credit.token,
      amount: credit.amount,
      flowchainAccount: credit.flowchainRecipient,
      baseRecipient,
      testMode: true,
    }),
    creditId: credit.creditId,
    depositId: credit.depositId,
    sourceChainId: deposit.sourceChainId,
    destinationChainId: deposit.sourceChainId,
    token: credit.token,
    amount: credit.amount,
    flowchainAccount: credit.flowchainRecipient,
    baseRecipient,
    status: "requested",
    requestedAt: FIXED_TEST_OBSERVED_AT,
    testMode: true,
    broadcast: false,
    releasePolicy: "test_record_only",
    productionReady: false,
  };
}

export function makeWithdrawalIntentSet(withdrawalIntents: BridgeWithdrawalIntent[]): BridgeWithdrawalIntentSet {
  return {
    schema: "flowmemory.bridge_withdrawal_intent_set.v0",
    withdrawalIntentSetId: stableId("flowmemory.bridge_withdrawal_intent_set.v0", {
      withdrawalIntentIds: withdrawalIntents.map((intent) => intent.withdrawalIntentId),
    }),
    generatedAt: FIXED_TEST_OBSERVED_AT,
    count: withdrawalIntents.length,
    withdrawalIntents,
    productionReady: false,
  };
}

function duplicateReplayKeys(observations: BridgeObservation[]): `0x${string}`[] {
  const seen = new Set<`0x${string}`>();
  const duplicates = new Set<`0x${string}`>();
  for (const observation of observations) {
    if (seen.has(observation.replayKey)) {
      duplicates.add(observation.replayKey);
    }
    seen.add(observation.replayKey);
  }
  return [...duplicates].sort();
}

export function makeRuntimeHandoff(
  mode: BridgeMode,
  observations: BridgeObservation[],
  credits: BridgeCredit[],
  withdrawalIntents: BridgeWithdrawalIntent[],
  expectedPath = "fixtures/bridge/local-runtime-bridge-handoff.json",
): BridgeRuntimeHandoff {
  const normalizedExpectedPath = normalizeHandoffExpectedPath(expectedPath);
  const replayKeys = [...new Set(observations.map((observation) => observation.replayKey))].sort() as `0x${string}`[];
  const firstObservation = observations[0];
  const firstCredit = credits[0];
  const firstAppliedCredit = credits.find((credit) => credit.status === "applied");
  const firstWithdrawal = withdrawalIntents[0];

  const workbenchTimeline: BridgeRuntimeHandoff["workbenchTimeline"] = [];
  if (firstObservation !== undefined) {
    workbenchTimeline.push({
      phase: "deposit_observed",
      status: "observed",
      objectId: firstObservation.observationId,
      title: "Deposit observed",
      summary: `Observed lockbox deposit ${firstObservation.deposit.depositId} on chain ${firstObservation.deposit.sourceChainId}.`,
    });
  }
  if (firstCredit !== undefined) {
    workbenchTimeline.push({
      phase: "credit_pending",
      status: "pending",
      objectId: firstCredit.creditId,
      title: "Credit pending",
      summary: `${firstCredit.amount} test units queued for ${firstCredit.flowchainRecipient}.`,
    });
  }
  if (firstAppliedCredit !== undefined) {
    workbenchTimeline.push({
      phase: "credit_applied",
      status: "applied",
      objectId: firstAppliedCredit.creditId,
      title: "Credit applied",
      summary: `${firstAppliedCredit.amount} test units applied in local bridge smoke state.`,
    });
  }
  if (firstWithdrawal !== undefined) {
    workbenchTimeline.push({
      phase: "withdrawal_requested",
      status: "requested",
      objectId: firstWithdrawal.withdrawalIntentId,
      title: "Withdrawal requested",
      summary: "Test-mode local-to-Base withdrawal intent recorded with no broadcast or real release.",
    });
  }

  const workbenchRecords: BridgeRuntimeHandoff["workbenchRecords"] = [
    ...observations.map((observation) => ({
      sectionKey: "transactions" as const,
      id: observation.observationId,
      kind: "Bridge deposit observation",
      title: observation.deposit.txHash,
      summary: `Deposit ${observation.deposit.depositId} observed from ${observation.mode}.`,
      status: "observed" as const,
      facts: [
        { label: "chain", value: String(observation.deposit.sourceChainId) },
        { label: "lockbox", value: observation.deposit.sourceContract },
        { label: "log index", value: String(observation.deposit.logIndex) },
        { label: "amount", value: observation.deposit.amount },
      ],
      rawRef: observation.observationId,
    })),
    ...credits.map((credit) => ({
      sectionKey: "receipts" as const,
      id: credit.creditId,
      kind: "Bridge credit",
      title: credit.creditId,
      summary: `Credit ${credit.status} for deposit ${credit.depositId}.`,
      status: credit.status === "applied" ? "verified" as const : credit.status === "pending" ? "pending" as const : "observed" as const,
      facts: [
        { label: "recipient", value: credit.flowchainRecipient },
        { label: "amount", value: credit.amount },
        { label: "token", value: credit.token },
        { label: "replay key", value: credit.replayKey },
      ],
      rawRef: credit.creditId,
    })),
    ...withdrawalIntents.map((intent) => ({
      sectionKey: "transactions" as const,
      id: intent.withdrawalIntentId,
      kind: "Bridge withdrawal intent",
      title: intent.withdrawalIntentId,
      summary: "Test-mode withdrawal intent recorded; no mainnet or real-funds release is broadcast.",
      status: "pending" as const,
      facts: [
        { label: "base recipient", value: intent.baseRecipient },
        { label: "amount", value: intent.amount },
        { label: "broadcast", value: String(intent.broadcast) },
        { label: "policy", value: intent.releasePolicy },
      ],
      rawRef: intent.withdrawalIntentId,
    })),
  ];

  return {
    schema: "flowmemory.bridge_runtime_handoff.v0",
    handoffId: stableId("flowmemory.bridge_runtime_handoff.v0", {
      mode,
      observationIds: observations.map((observation) => observation.observationId),
      creditIds: credits.map((credit) => credit.creditId),
      withdrawalIntentIds: withdrawalIntents.map((intent) => intent.withdrawalIntentId),
    }),
    generatedAt: FIXED_TEST_OBSERVED_AT,
    mode,
    productionReady: false,
    localOnly: true,
    observations,
    credits,
    withdrawalIntents,
    replayProtection: {
      strategy: "source-chain-contract-tx-log-deposit",
      replayKeys,
      duplicateReplayKeys: duplicateReplayKeys(observations),
    },
    runtimeIntake: {
      status: "handoff_file",
      consumer: "flowchain-runtime-agent",
      expectedPath: normalizedExpectedPath,
      note: "Runtime/control-plane bridge intake is not merged in this scope. Consume this file as the deterministic bridge credit handoff.",
    },
    workbenchTimeline,
    workbenchRecords,
    limitations: [
      "Bridge objects are for mock, local Anvil, and Base Sepolia test validation by default.",
      "No production bridge readiness, audited security, or trustless finality is claimed.",
      "Withdrawal intents are test-mode records only and do not broadcast releases.",
      "RPC URLs and private keys are never written to bridge artifacts.",
    ],
  };
}

function normalizeHandoffExpectedPath(path: string): string {
  const normalized = path.replace(/\\/g, "/");
  const marker = "fixtures/bridge/";
  const markerIndex = normalized.lastIndexOf(marker);
  return markerIndex >= 0 ? normalized.slice(markerIndex) : normalized;
}

function hexQuantityToBigInt(value: string, name: string): bigint {
  if (!/^0x[0-9a-fA-F]+$/.test(value)) {
    throw new Error(`${name} must be an RPC hex quantity`);
  }
  return BigInt(value);
}

function hexQuantityToDecimalString(value: string | undefined, name: string): string | undefined {
  if (value === undefined) {
    return undefined;
  }
  return hexQuantityToBigInt(value, name).toString();
}

function hexQuantityToNumber(value: string | undefined, name: string): number | undefined {
  if (value === undefined) {
    return undefined;
  }
  const parsed = Number(hexQuantityToBigInt(value, name));
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    throw new Error(`${name} exceeds safe integer range`);
  }
  return parsed;
}

function addressFromAbiWord(word: `0x${string}`, name: string): `0x${string}` {
  return asAddress(`0x${word.slice(-40)}`, name);
}

export function parseBridgeDepositLog(log: RpcLog, expectedChainId: BridgeSourceChainId): BridgeDeposit {
  if (log.removed) {
    throw new Error("removed bridge logs must be handled by a reorg-aware reader");
  }
  if (log.topics[0]?.toLowerCase() !== BRIDGE_DEPOSIT_TOPIC0) {
    throw new Error("log is not a BaseBridgeLockbox BridgeDeposit event");
  }
  const data = hexToBytes(log.data);
  if (data.length !== 5 * 32) {
    throw new Error(`BridgeDeposit log data must contain 5 ABI words, got ${data.length / 32}`);
  }

  const eventChainId = asSourceChainId(Number(BigInt(asHash(log.topics[2] ?? "", "sourceChainId"))), "sourceChainId");
  if (eventChainId !== expectedChainId) {
    throw new Error(`BridgeDeposit event chain id mismatch: expected ${expectedChainId}, got ${eventChainId}`);
  }

  return {
    schema: "flowmemory.bridge_deposit.v0",
    depositId: asHash(log.topics[1] ?? "", "depositId"),
    sourceChainId: eventChainId,
    sourceContract: asAddress(log.address, "sourceContract"),
    txHash: asHash(log.transactionHash, "txHash"),
    logIndex: Number(hexQuantityToBigInt(log.logIndex, "logIndex")),
    sourceBlockNumber: hexQuantityToDecimalString(log.blockNumber, "blockNumber"),
    sourceBlockHash: log.blockHash === undefined ? undefined : asHash(log.blockHash, "blockHash"),
    transactionIndex: hexQuantityToNumber(log.transactionIndex, "transactionIndex"),
    token: addressFromAbiWord(decodeBytes32Word(data, 0), "token"),
    amount: decodeUint256Word(data, 1).toString(),
    sender: asAddress(decodeAddressTopic(log.topics[3] ?? ""), "sender"),
    flowchainRecipient: decodeBytes32Word(data, 2),
    nonce: decodeUint256Word(data, 3).toString(),
    metadataHash: decodeBytes32Word(data, 4),
    status: "observed",
  };
}

async function rpcCall<T>(rpcUrl: string, method: string, params: JsonValue[]): Promise<T> {
  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const payload = await response.json() as { result?: T; error?: { message?: string } };
  if (!response.ok || payload.error !== undefined || payload.result === undefined) {
    throw new Error(`RPC ${method} failed: ${payload.error?.message ?? response.statusText}`);
  }
  return payload.result;
}

function blockTag(value: string): string {
  return `0x${BigInt(value).toString(16)}`;
}

async function readChainId(rpcUrl: string): Promise<number> {
  const result = await rpcCall<string>(rpcUrl, "eth_chainId", []);
  return Number(BigInt(result));
}

async function readBridgeDepositLogs(options: CliOptions): Promise<BridgeDeposit[]> {
  const expectedChainId = expectedChainIdForMode(options.mode, options.expectedChainId);
  const actualChainId = await readChainId(options.rpcUrl ?? "");
  if (actualChainId !== expectedChainId) {
    throw new Error(`wrong chain id: expected ${expectedChainId}, got ${actualChainId}`);
  }

  const logs = await rpcCall<RpcLog[]>(options.rpcUrl ?? "", "eth_getLogs", [{
    address: options.lockboxAddress,
    fromBlock: blockTag(options.fromBlock ?? "0"),
    toBlock: blockTag(options.toBlock ?? "0"),
    topics: [BRIDGE_DEPOSIT_TOPIC0],
  }]);

  return logs
    .filter((log) => !log.removed)
    .map((log) => parseBridgeDepositLog(log, expectedChainId));
}

export async function runBridgePipeline(options: CliOptions): Promise<BridgePipelineResult> {
  const deposits = options.mode === "mock"
    ? fixtureDeposits(JSON.parse(readFileSync(resolve(options.fixturePath ?? ""), "utf8")) as unknown)
    : await readBridgeDepositLogs(options);

  const observations = deposits.map((deposit) => makeObservation(deposit, options.mode, options.maxUsd));
  const credits = makeCredits(observations, options.applyCredit);
  const withdrawalIntents = options.withdrawalIntent
    ? credits
      .filter((credit) => credit.status === "applied")
      .map((credit) => {
        const deposit = observations.find((observation) => observation.deposit.depositId === credit.depositId)?.deposit;
        if (deposit === undefined) {
          throw new Error(`missing deposit for credit ${credit.creditId}`);
        }
        return makeWithdrawalIntent(credit, deposit, options.withdrawalBaseRecipient);
      })
    : [];
  const handoff = makeRuntimeHandoff(options.mode, observations, credits, withdrawalIntents, options.handoffOutPath);

  return {
    observations,
    credits,
    withdrawalIntents,
    handoff,
  };
}

export async function runBridgeObserver(options: CliOptions): Promise<BridgeObservation> {
  const result = await runBridgePipeline(options);
  const observation = result.observations[0];
  if (observation === undefined) {
    throw new Error("no BridgeDeposit events observed");
  }
  return observation;
}

function writeJson(path: string, value: unknown): void {
  const outPath = resolve(path);
  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(outPath, `${JSON.stringify(value, null, 2)}\n`);
  console.log(`Wrote ${outPath}`);
}

function artifactForSingleOrSet<TSingle, TSet>(values: TSingle[], setValue: TSet): TSingle | TSet {
  return values.length === 1 ? values[0] as TSingle : setValue;
}

function printRunBoundary(options: CliOptions): void {
  if (options.mode === "mock") {
    console.log("Bridge mode: mock fixture; no chain RPC or private key is used.");
    return;
  }

  const expectedChainId = expectedChainIdForMode(options.mode, options.expectedChainId);
  console.log(`Bridge mode: ${options.mode}`);
  console.log(`Chain id: ${expectedChainId}`);
  console.log(`Lockbox: ${options.lockboxAddress}`);
  console.log(`Block range: ${options.fromBlock}-${options.toBlock}`);
  console.log("Broadcast: false; this observer never sends transactions.");
  if (options.mode === "base-sepolia") {
    console.log("Asset boundary: Base Sepolia test assets only.");
  }
  if (options.mode === "base-mainnet-canary") {
    console.log(`Real-funds guardrail acknowledged for read-only canary. Max USD: ${options.maxUsd}`);
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const options = parseBridgeArgs(process.argv.slice(2));
  printRunBoundary(options);
  const result = await runBridgePipeline(options);

  writeJson(
    options.outPath,
    artifactForSingleOrSet(result.observations, makeObservationSet(result.observations, options.mode)),
  );
  if (options.creditOutPath !== undefined) {
    writeJson(
      options.creditOutPath,
      artifactForSingleOrSet(result.credits, makeCreditSet(result.credits)),
    );
  }
  if (options.handoffOutPath !== undefined) {
    writeJson(options.handoffOutPath, result.handoff);
  }
  if (options.withdrawalOutPath !== undefined) {
    writeJson(
      options.withdrawalOutPath,
      artifactForSingleOrSet(result.withdrawalIntents, makeWithdrawalIntentSet(result.withdrawalIntents)),
    );
  }

  console.log(
    `Bridge run complete: observed=${result.observations.length}, credits=${result.credits.length}, withdrawals=${result.withdrawalIntents.length}`,
  );
}
