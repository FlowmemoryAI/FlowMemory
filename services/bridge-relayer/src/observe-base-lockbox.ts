import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  canonicalJson,
  assertNoSecrets,
  decodeAddressTopic,
  decodeBytes32Word,
  decodeUint256Word,
  hexToBytes,
  keccak256Utf8,
  normalizeAddress,
  normalizeBytes32,
} from "../../shared/src/index.ts";

export const BASE_MAINNET_CHAIN_ID = 8453;
export const BASE_MAINNET_CHAIN_ID_HEX = "0x2105";
export const BASE_SEPOLIA_CHAIN_ID = 84532;
export const LOCAL_ANVIL_CHAIN_ID = 31337;
export const MAX_CANARY_USD = 25;
export const MAX_PILOT_USD = 25;
export const MAX_BLOCK_RANGE = 5_000n;
export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
export const ZERO_BYTES32 = "0x0000000000000000000000000000000000000000000000000000000000000000";
export const BRIDGE_DEPOSIT_EVENT_SIGNATURE_TEXT =
  "BridgeDeposit(bytes32,uint256,address,address,address,uint256,bytes32,uint256,bytes32,bytes32)";
export const BRIDGE_DEPOSIT_LEGACY_EVENT_SIGNATURE_TEXT =
  "BridgeDeposit(bytes32,uint256,address,address,uint256,bytes32,uint256,bytes32)";
export const BRIDGE_DEPOSIT_TOPIC0 = keccak256Utf8(BRIDGE_DEPOSIT_EVENT_SIGNATURE_TEXT);
export const BRIDGE_DEPOSIT_LEGACY_TOPIC0 = keccak256Utf8(BRIDGE_DEPOSIT_LEGACY_EVENT_SIGNATURE_TEXT);
export const PILOT_MODE_TAG = keccak256Utf8("flowchain.base8453.owner-pilot.v0");
export const FIXED_TEST_OBSERVED_AT = "2026-05-13T00:00:00.000Z";

type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue | undefined };

export type BridgeSourceChainId =
  | typeof LOCAL_ANVIL_CHAIN_ID
  | typeof BASE_SEPOLIA_CHAIN_ID
  | typeof BASE_MAINNET_CHAIN_ID;

export type BridgeMode =
  | "mock"
  | "mock-pilot"
  | "local-anvil"
  | "base-sepolia"
  | "base-mainnet-canary"
  | "base-mainnet-pilot";

export interface BridgeConfirmationEvidence {
  depth: number;
  latestBlockNumber?: string;
  requiredConfirmedBlockNumber?: string;
  requestedToBlock?: string;
  satisfied: boolean;
}

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
    maxDepositAmount?: string;
    totalCapAmount?: string;
    pilotModeTag: `0x${string}`;
    supportedTokens?: `0x${string}`[];
    confirmation?: BridgeConfirmationEvidence;
    approvedContract?: boolean;
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

export interface BridgeRuntimeCreditApplication {
  schema: "flowmemory.bridge_runtime_credit_application.v0";
  applicationId: `0x${string}`;
  creditId: `0x${string}`;
  depositId: `0x${string}`;
  replayKey: `0x${string}`;
  flowchainRecipient: `0x${string}`;
  amount: string;
  status: "applied" | "idempotent_replay" | "rejected";
  appliedAt?: string;
  previousApplicationId?: `0x${string}`;
  rejectionReason?: string;
  applyCount: 0 | 1;
  localOnly: true;
  productionReady: false;
}

export interface BridgePilotEvidence {
  schema: "flowmemory.bridge_pilot_evidence.v0";
  evidenceId: `0x${string}`;
  generatedAt: string;
  mode: BridgeMode;
  productionReady: false;
  localOnly: true;
  observationId: `0x${string}`;
  creditId: `0x${string}`;
  depositId: `0x${string}`;
  replayKey: `0x${string}`;
  source: {
    chainId: BridgeSourceChainId;
    chainIdHex: `0x${string}`;
    contract: `0x${string}`;
    txHash: `0x${string}`;
    logIndex: number;
    blockNumber?: string;
  };
  guardrails: {
    approvedContract: boolean;
    confirmation: BridgeConfirmationEvidence;
    maxUsd?: number;
    maxDepositAmount?: string;
    totalCapAmount?: string;
    supportedTokens?: `0x${string}`[];
    operatorAcknowledged: boolean;
    noSecrets: true;
  };
  creditApplication: {
    applicationId?: `0x${string}`;
    status: BridgeRuntimeCreditApplication["status"] | BridgeCredit["status"];
    appliedExactlyOnce: boolean;
    rejectionReason?: string;
  };
  replay: {
    decision: "accepted_once" | "duplicate_replay_key_rejected" | "already_applied_idempotent";
    duplicateReplayKeys: `0x${string}`[];
  };
  nextOperatorCommands: string[];
}

export interface BridgeReleaseEvidence {
  schema: "flowmemory.bridge_release_evidence.v0";
  releaseEvidenceId: `0x${string}`;
  generatedAt: string;
  withdrawalIntentId: `0x${string}`;
  creditId: `0x${string}`;
  depositId: `0x${string}`;
  sourceChainId: BridgeSourceChainId;
  destinationChainId: BridgeSourceChainId;
  lockbox: `0x${string}`;
  releaseCall: {
    method: "releaseERC20" | "releaseNative";
    recipient: `0x${string}`;
    token: `0x${string}`;
    amount: string;
    evidenceHash: `0x${string}`;
    broadcast: false;
  };
  operatorNote: string;
  productionReady: false;
  localOnly: true;
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
  runtimeApplications: BridgeRuntimeCreditApplication[];
  pilotEvidence: BridgePilotEvidence[];
  releaseEvidences: BridgeReleaseEvidence[];
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
  approvedLockboxAddresses: `0x${string}`[];
  supportedTokens: `0x${string}`[];
  confirmationDepth: number;
  acknowledgeRealFunds: boolean;
  acknowledgePilot: boolean;
  maxUsd?: number;
  maxDepositAmount?: string;
  totalCapAmount?: string;
  applyCredit: boolean;
  withdrawalIntent: boolean;
  withdrawalBaseRecipient?: `0x${string}`;
  runtimeStatePath?: string;
  evidenceOutPath?: string;
  releaseEvidenceOutPath?: string;
}

export interface BridgePipelineResult {
  observations: BridgeObservation[];
  credits: BridgeCredit[];
  withdrawalIntents: BridgeWithdrawalIntent[];
  runtimeApplications: BridgeRuntimeCreditApplication[];
  pilotEvidence: BridgePilotEvidence[];
  releaseEvidences: BridgeReleaseEvidence[];
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

function asPositiveDecimalString(value: unknown, name: string): string {
  const text = asDecimalString(value, name);
  if (BigInt(text) <= 0n) {
    throw new Error(`${name} must be greater than zero`);
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

function isMockMode(mode: BridgeMode): boolean {
  return mode === "mock" || mode === "mock-pilot";
}

function isPilotMode(mode: BridgeMode): boolean {
  return mode === "mock-pilot" || mode === "base-mainnet-pilot";
}

function chainIdHex(chainId: BridgeSourceChainId): `0x${string}` {
  return `0x${chainId.toString(16)}`;
}

function parseApprovedLockboxes(value: string, name: string): `0x${string}`[] {
  return value
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0)
    .map((entry) => asAddress(entry, name));
}

function parseAddressList(value: string, name: string): `0x${string}`[] {
  return value
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0)
    .map((entry) => asAddress(entry, name));
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
  if (mode === "mock") {
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
  let approvedLockboxAddresses: `0x${string}`[] = [];
  let supportedTokens: `0x${string}`[] = [];
  let confirmationDepth: number | undefined;
  let acknowledgeRealFunds = false;
  let acknowledgePilot = false;
  let maxUsd: number | undefined;
  let maxDepositAmount: string | undefined;
  let totalCapAmount: string | undefined;
  let applyCredit = false;
  let withdrawalIntent = false;
  let withdrawalBaseRecipient: `0x${string}` | undefined;
  let runtimeStatePath: string | undefined;
  let evidenceOutPath: string | undefined;
  let releaseEvidenceOutPath: string | undefined;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--mode") {
      const value = argValue(args, index, arg);
      if (
        value !== "mock"
        && value !== "mock-pilot"
        && value !== "local-anvil"
        && value !== "base-sepolia"
        && value !== "base-mainnet-canary"
        && value !== "base-mainnet-pilot"
      ) {
        throw new Error("--mode must be mock, mock-pilot, local-anvil, base-sepolia, base-mainnet-canary, or base-mainnet-pilot");
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
    } else if (arg === "--approved-lockbox" || arg === "--approved-lockbox-address") {
      approvedLockboxAddresses.push(asAddress(argValue(args, index, arg), arg));
      index += 1;
    } else if (arg === "--approved-lockboxes" || arg === "--approved-lockbox-addresses") {
      approvedLockboxAddresses = [
        ...approvedLockboxAddresses,
        ...parseApprovedLockboxes(argValue(args, index, arg), arg),
      ];
      index += 1;
    } else if (arg === "--supported-token") {
      supportedTokens.push(asAddress(argValue(args, index, arg), arg));
      index += 1;
    } else if (arg === "--supported-tokens") {
      supportedTokens = [
        ...supportedTokens,
        ...parseAddressList(argValue(args, index, arg), arg),
      ];
      index += 1;
    } else if (arg === "--confirmations" || arg === "--confirmation-depth") {
      confirmationDepth = asNonNegativeInteger(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--acknowledge-real-funds") {
      acknowledgeRealFunds = true;
    } else if (arg === "--acknowledge-pilot") {
      acknowledgePilot = true;
    } else if (arg === "--max-usd") {
      maxUsd = Number(argValue(args, index, arg));
      index += 1;
    } else if (arg === "--max-deposit-amount") {
      maxDepositAmount = asPositiveDecimalString(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--total-cap-amount") {
      totalCapAmount = asPositiveDecimalString(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--apply-credit") {
      applyCredit = true;
    } else if (arg === "--withdrawal-intent") {
      withdrawalIntent = true;
    } else if (arg === "--withdrawal-base-recipient") {
      withdrawalBaseRecipient = asAddress(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--runtime-state") {
      runtimeStatePath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--evidence-out") {
      evidenceOutPath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--release-evidence-out") {
      releaseEvidenceOutPath = argValue(args, index, arg);
      index += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  if (isMockMode(mode) && !fixturePath) {
    throw new Error("--fixture is required in mock modes");
  }

  if (!isMockMode(mode)) {
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
    if (applyCredit) {
      throw new Error("Base mainnet canary is read-only; --apply-credit requires the explicit pilot mode");
    }
    if (withdrawalIntent) {
      throw new Error("Base mainnet canary is read-only; withdrawal intents require the explicit pilot mode");
    }
  }

  if (isPilotMode(mode)) {
    if (!acknowledgePilot) {
      throw new Error("Base pilot modes require --acknowledge-pilot");
    }
    if (mode === "base-mainnet-pilot" && !acknowledgeRealFunds) {
      throw new Error("Base mainnet pilot requires --acknowledge-real-funds");
    }
    if (maxUsd === undefined || !Number.isFinite(maxUsd) || maxUsd <= 0 || maxUsd > MAX_PILOT_USD) {
      throw new Error(`Base pilot modes require --max-usd <= ${MAX_PILOT_USD}`);
    }
    if (maxDepositAmount === undefined) {
      throw new Error("Base pilot modes require --max-deposit-amount");
    }
    if (totalCapAmount === undefined) {
      throw new Error("Base pilot modes require --total-cap-amount");
    }
    if (BigInt(totalCapAmount) < BigInt(maxDepositAmount)) {
      throw new Error("--total-cap-amount must be greater than or equal to --max-deposit-amount");
    }
    if (approvedLockboxAddresses.length === 0) {
      throw new Error("Base pilot modes require at least one --approved-lockbox");
    }
    if (supportedTokens.length === 0) {
      throw new Error("Base pilot modes require at least one --supported-token");
    }
    if (confirmationDepth === undefined) {
      throw new Error("Base pilot modes require --confirmations");
    }
  }

  const resolvedConfirmationDepth = confirmationDepth ?? 0;

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
    approvedLockboxAddresses: [...new Set(approvedLockboxAddresses)].sort() as `0x${string}`[],
    supportedTokens: [...new Set(supportedTokens)].sort() as `0x${string}`[],
    confirmationDepth: resolvedConfirmationDepth,
    acknowledgeRealFunds,
    acknowledgePilot,
    maxUsd,
    maxDepositAmount,
    totalCapAmount,
    applyCredit,
    withdrawalIntent,
    withdrawalBaseRecipient,
    runtimeStatePath,
    evidenceOutPath,
    releaseEvidenceOutPath,
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

export function fixtureDeposits(fixture: unknown): BridgeDeposit[] {
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

interface BridgeGuardrailOptions {
  maxUsd?: number;
  maxDepositAmount?: string;
  totalCapAmount?: string;
  supportedTokens?: `0x${string}`[];
  confirmation?: BridgeConfirmationEvidence;
  approvedContract?: boolean;
}

function normalizeGuardrailOptions(value?: number | BridgeGuardrailOptions): BridgeGuardrailOptions {
  if (typeof value === "number") {
    return { maxUsd: value };
  }
  return value ?? {};
}

export function makeObservation(
  deposit: BridgeDeposit,
  mode: BridgeObservation["mode"],
  guardrailOptions?: number | BridgeGuardrailOptions,
): BridgeObservation {
  const guardrails = normalizeGuardrailOptions(guardrailOptions);
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
      explicitBlockRange: !isMockMode(mode),
      noSecrets: true,
      ...(guardrails.maxUsd === undefined ? {} : { maxUsd: guardrails.maxUsd }),
      ...(guardrails.maxDepositAmount === undefined ? {} : { maxDepositAmount: guardrails.maxDepositAmount }),
      ...(guardrails.totalCapAmount === undefined ? {} : { totalCapAmount: guardrails.totalCapAmount }),
      ...(guardrails.supportedTokens === undefined ? {} : { supportedTokens: guardrails.supportedTokens }),
      ...(guardrails.confirmation === undefined ? {} : { confirmation: guardrails.confirmation }),
      ...(guardrails.approvedContract === undefined ? {} : { approvedContract: guardrails.approvedContract }),
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
    if (observation.mode === "base-mainnet-canary") {
      return makeBridgeCredit(observation, "rejected", "base_mainnet_canary_read_only");
    }
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

interface BridgeRuntimeCreditApplicationState {
  schema: "flowmemory.bridge_runtime_credit_application_state.v0";
  stateId: `0x${string}`;
  updatedAt: string;
  appliedReplayKeys: Record<string, `0x${string}`>;
  applications: BridgeRuntimeCreditApplication[];
  localOnly: true;
  productionReady: false;
}

function emptyApplicationState(): BridgeRuntimeCreditApplicationState {
  return {
    schema: "flowmemory.bridge_runtime_credit_application_state.v0",
    stateId: stableId("flowmemory.bridge_runtime_credit_application_state.v0", { applications: [] }),
    updatedAt: FIXED_TEST_OBSERVED_AT,
    appliedReplayKeys: {},
    applications: [],
    localOnly: true,
    productionReady: false,
  };
}

function loadApplicationState(path?: string): BridgeRuntimeCreditApplicationState {
  if (path === undefined || !existsSync(resolve(path))) {
    return emptyApplicationState();
  }
  const parsed = JSON.parse(readFileSync(resolve(path), "utf8")) as Partial<BridgeRuntimeCreditApplicationState>;
  if (parsed.schema !== "flowmemory.bridge_runtime_credit_application_state.v0") {
    throw new Error("unsupported bridge runtime credit application state schema");
  }
  return {
    schema: "flowmemory.bridge_runtime_credit_application_state.v0",
    stateId: asHash(String(parsed.stateId), "stateId"),
    updatedAt: String(parsed.updatedAt ?? FIXED_TEST_OBSERVED_AT),
    appliedReplayKeys: Object.fromEntries(
      Object.entries(parsed.appliedReplayKeys ?? {}).map(([key, value]) => [
        asHash(key, "appliedReplayKeys key"),
        asHash(String(value), "appliedReplayKeys value"),
      ]),
    ),
    applications: Array.isArray(parsed.applications) ? parsed.applications as BridgeRuntimeCreditApplication[] : [],
    localOnly: true,
    productionReady: false,
  };
}

function makeRuntimeApplication(
  credit: BridgeCredit,
  status: BridgeRuntimeCreditApplication["status"],
  previousApplicationId?: `0x${string}`,
  rejectionReason?: string,
): BridgeRuntimeCreditApplication {
  const applyCount = status === "applied" ? 1 : 0;
  return {
    schema: "flowmemory.bridge_runtime_credit_application.v0",
    applicationId: stableId("flowmemory.bridge_runtime_credit_application.v0", {
      creditId: credit.creditId,
      replayKey: credit.replayKey,
      status,
      previousApplicationId: previousApplicationId ?? null,
    }),
    creditId: credit.creditId,
    depositId: credit.depositId,
    replayKey: credit.replayKey,
    flowchainRecipient: credit.flowchainRecipient,
    amount: credit.amount,
    status,
    appliedAt: status === "applied" ? FIXED_TEST_OBSERVED_AT : undefined,
    previousApplicationId,
    rejectionReason,
    applyCount,
    localOnly: true,
    productionReady: false,
  };
}

function saveApplicationState(path: string, state: BridgeRuntimeCreditApplicationState): void {
  const stateId = stableId("flowmemory.bridge_runtime_credit_application_state.v0", {
    applications: state.applications.map((application) => application.applicationId),
    appliedReplayKeys: state.appliedReplayKeys,
  });
  const normalized: BridgeRuntimeCreditApplicationState = {
    ...state,
    stateId,
    updatedAt: FIXED_TEST_OBSERVED_AT,
  };
  const outPath = resolve(path);
  mkdirSync(dirname(outPath), { recursive: true });
  assertNoSecrets(normalized);
  writeFileSync(outPath, `${JSON.stringify(normalized, null, 2)}\n`);
}

function applyCreditsExactlyOnce(
  credits: BridgeCredit[],
  runtimeStatePath?: string,
): BridgeRuntimeCreditApplication[] {
  const state = loadApplicationState(runtimeStatePath);
  const applications: BridgeRuntimeCreditApplication[] = [];
  let changed = false;

  for (const credit of credits) {
    if (credit.status !== "applied") {
      if (credit.status === "rejected") {
        applications.push(makeRuntimeApplication(credit, "rejected", undefined, credit.rejectionReason));
      }
      continue;
    }

    const previousApplicationId = state.appliedReplayKeys[credit.replayKey];
    if (previousApplicationId !== undefined) {
      credit.status = "rejected";
      credit.appliedAt = undefined;
      credit.rejectionReason = "already_applied_replay_key";
      applications.push(makeRuntimeApplication(credit, "idempotent_replay", previousApplicationId, credit.rejectionReason));
      continue;
    }

    const application = makeRuntimeApplication(credit, "applied");
    state.appliedReplayKeys[credit.replayKey] = application.applicationId;
    state.applications.push(application);
    applications.push(application);
    changed = true;
  }

  if (runtimeStatePath !== undefined && changed) {
    saveApplicationState(runtimeStatePath, state);
  }

  return applications;
}

export function makeRuntimeHandoff(
  mode: BridgeMode,
  observations: BridgeObservation[],
  credits: BridgeCredit[],
  withdrawalIntents: BridgeWithdrawalIntent[],
  runtimeApplications: BridgeRuntimeCreditApplication[] = [],
  pilotEvidence: BridgePilotEvidence[] = [],
  releaseEvidences: BridgeReleaseEvidence[] = [],
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
      runtimeApplicationIds: runtimeApplications.map((application) => application.applicationId),
      pilotEvidenceIds: pilotEvidence.map((evidence) => evidence.evidenceId),
      releaseEvidenceIds: releaseEvidences.map((evidence) => evidence.releaseEvidenceId),
    }),
    generatedAt: FIXED_TEST_OBSERVED_AT,
    mode,
    productionReady: false,
    localOnly: true,
    observations,
    credits,
    withdrawalIntents,
    runtimeApplications,
    pilotEvidence,
    releaseEvidences,
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

function confirmationForEvidence(options: CliOptions, confirmation?: BridgeConfirmationEvidence): BridgeConfirmationEvidence {
  return confirmation ?? {
    depth: options.confirmationDepth,
    satisfied: true,
  };
}

function nextOperatorCommands(options: CliOptions): string[] {
  if (isPilotMode(options.mode)) {
    return [
      "Get-Content services/bridge-relayer/out/base8453-pilot-evidence.json",
      "Get-Content services/bridge-relayer/out/base8453-pilot-release-evidence.json",
      "npm run flowchain:product-e2e",
    ];
  }
  return [
    "npm run bridge:local-credit:smoke",
    "npm run flowchain:product-e2e",
  ];
}

function replayDecision(
  credit: BridgeCredit,
  duplicateReplayKeys: `0x${string}`[],
  application?: BridgeRuntimeCreditApplication,
): BridgePilotEvidence["replay"]["decision"] {
  if (application?.status === "idempotent_replay") {
    return "already_applied_idempotent";
  }
  if (credit.status === "rejected" && duplicateReplayKeys.includes(credit.replayKey)) {
    return "duplicate_replay_key_rejected";
  }
  return "accepted_once";
}

function makePilotEvidence(
  options: CliOptions,
  observation: BridgeObservation,
  credit: BridgeCredit,
  duplicateKeys: `0x${string}`[],
  application: BridgeRuntimeCreditApplication | undefined,
  confirmation?: BridgeConfirmationEvidence,
): BridgePilotEvidence {
  const confirmationEvidence = confirmationForEvidence(options, confirmation ?? observation.guardrails.confirmation);
  const appliedExactlyOnce = application?.status === "applied" && application.applyCount === 1;
  const approvedContract = observation.guardrails.approvedContract ?? true;
  return {
    schema: "flowmemory.bridge_pilot_evidence.v0",
    evidenceId: stableId("flowmemory.bridge_pilot_evidence.v0", {
      observationId: observation.observationId,
      creditId: credit.creditId,
      applicationId: application?.applicationId ?? null,
      replayDecision: replayDecision(credit, duplicateKeys, application),
    }),
    generatedAt: FIXED_TEST_OBSERVED_AT,
    mode: options.mode,
    productionReady: false,
    localOnly: true,
    observationId: observation.observationId,
    creditId: credit.creditId,
    depositId: observation.deposit.depositId,
    replayKey: observation.replayKey,
    source: {
      chainId: observation.deposit.sourceChainId,
      chainIdHex: chainIdHex(observation.deposit.sourceChainId),
      contract: observation.deposit.sourceContract,
      txHash: observation.deposit.txHash,
      logIndex: observation.deposit.logIndex,
      blockNumber: observation.deposit.sourceBlockNumber,
    },
    guardrails: {
      approvedContract,
      confirmation: confirmationEvidence,
      maxUsd: options.maxUsd,
      maxDepositAmount: options.maxDepositAmount,
      totalCapAmount: options.totalCapAmount,
      pilotModeTag: PILOT_MODE_TAG,
      supportedTokens: options.supportedTokens,
      operatorAcknowledged: options.acknowledgePilot,
      noSecrets: true,
    },
    creditApplication: {
      applicationId: application?.applicationId,
      status: application?.status ?? credit.status,
      appliedExactlyOnce,
      rejectionReason: application?.rejectionReason ?? credit.rejectionReason,
    },
    replay: {
      decision: replayDecision(credit, duplicateKeys, application),
      duplicateReplayKeys: duplicateKeys,
    },
    nextOperatorCommands: nextOperatorCommands(options),
  };
}

function makeReleaseEvidence(intent: BridgeWithdrawalIntent, deposit: BridgeDeposit): BridgeReleaseEvidence {
  const evidenceHash = stableId("flowmemory.bridge_release_evidence_hash.v0", {
    withdrawalIntentId: intent.withdrawalIntentId,
    creditId: intent.creditId,
    depositId: intent.depositId,
    amount: intent.amount,
    baseRecipient: intent.baseRecipient,
  });
  return {
    schema: "flowmemory.bridge_release_evidence.v0",
    releaseEvidenceId: stableId("flowmemory.bridge_release_evidence.v0", {
      withdrawalIntentId: intent.withdrawalIntentId,
      evidenceHash,
    }),
    generatedAt: FIXED_TEST_OBSERVED_AT,
    withdrawalIntentId: intent.withdrawalIntentId,
    creditId: intent.creditId,
    depositId: intent.depositId,
    sourceChainId: intent.sourceChainId,
    destinationChainId: intent.destinationChainId,
    lockbox: deposit.sourceContract,
    releaseCall: {
      method: deposit.token === "0x0000000000000000000000000000000000000000" ? "releaseNative" : "releaseERC20",
      recipient: intent.baseRecipient,
      token: intent.token,
      amount: intent.amount,
      evidenceHash,
      broadcast: false,
    },
    operatorNote: "Pilot release evidence only. Review before any separate release-authority transaction; this relayer does not broadcast.",
    productionReady: false,
    localOnly: true,
  };
}

function addressFromAbiWord(word: `0x${string}`, name: string): `0x${string}` {
  return asAddress(`0x${word.slice(-40)}`, name);
}

function assertApprovedLockbox(address: `0x${string}`, options: CliOptions): void {
  if (options.approvedLockboxAddresses.length === 0) {
    return;
  }
  const approved = new Set(options.approvedLockboxAddresses.map((entry) => entry.toLowerCase()));
  if (!approved.has(address.toLowerCase())) {
    throw new Error(`unapproved bridge lockbox address: ${address}`);
  }
}

function assertSupportedToken(address: `0x${string}`, options: CliOptions): void {
  if (options.supportedTokens.length === 0) {
    return;
  }
  const supported = new Set(options.supportedTokens.map((entry) => entry.toLowerCase()));
  if (!supported.has(address.toLowerCase())) {
    throw new Error(`unsupported bridge token for pilot: ${address}`);
  }
}

function enforcePilotDepositGuardrails(deposits: BridgeDeposit[], options: CliOptions): void {
  if (!isPilotMode(options.mode)) {
    return;
  }
  const maxDeposit = BigInt(options.maxDepositAmount ?? "0");
  const totalCap = BigInt(options.totalCapAmount ?? "0");
  let total = 0n;
  const countedReplayKeys = new Set<`0x${string}`>();
  for (const deposit of deposits) {
    if (deposit.sourceChainId !== BASE_MAINNET_CHAIN_ID) {
      throw new Error(`pilot deposit must be from Base chain ${BASE_MAINNET_CHAIN_ID} (${BASE_MAINNET_CHAIN_ID_HEX})`);
    }
    if (deposit.flowchainRecipient === ZERO_BYTES32) {
      throw new Error("pilot deposit is missing a local FlowChain recipient");
    }
    assertApprovedLockbox(deposit.sourceContract, options);
    assertSupportedToken(deposit.token, options);
    const amount = BigInt(deposit.amount);
    if (amount > maxDeposit) {
      throw new Error(`pilot deposit amount exceeds --max-deposit-amount: ${deposit.amount}`);
    }
    const replayKey = bridgeReplayKey(deposit);
    if (!countedReplayKeys.has(replayKey)) {
      countedReplayKeys.add(replayKey);
      total += amount;
    }
  }
  if (total > totalCap) {
    throw new Error(`pilot deposit batch exceeds --total-cap-amount: ${total.toString()}`);
  }
}

export function parseBridgeDepositLog(log: RpcLog, expectedChainId: BridgeSourceChainId): BridgeDeposit {
  if (log.removed) {
    throw new Error("removed bridge logs must be handled by a reorg-aware reader");
  }
  const topic0 = log.topics[0]?.toLowerCase();
  if (topic0 !== BRIDGE_DEPOSIT_TOPIC0 && topic0 !== BRIDGE_DEPOSIT_LEGACY_TOPIC0) {
    throw new Error("log is not a BaseBridgeLockbox BridgeDeposit event");
  }
  const data = hexToBytes(log.data);
  if (data.length !== 5 * 32 && data.length !== 7 * 32) {
    throw new Error(`BridgeDeposit log data must contain 5 or 7 ABI words, got ${data.length / 32}`);
  }

  const eventChainId = asSourceChainId(Number(BigInt(asHash(log.topics[2] ?? "", "sourceChainId"))), "sourceChainId");
  if (eventChainId !== expectedChainId) {
    throw new Error(`BridgeDeposit event chain id mismatch: expected ${expectedChainId}, got ${eventChainId}`);
  }

  const hasExtendedEventFields = data.length === 7 * 32;
  const eventLockbox = hasExtendedEventFields
    ? addressFromAbiWord(decodeBytes32Word(data, 0), "lockbox")
    : asAddress(log.address, "sourceContract");
  if (eventLockbox.toLowerCase() !== log.address.toLowerCase()) {
    throw new Error(`BridgeDeposit lockbox mismatch: emitter ${log.address}, event ${eventLockbox}`);
  }
  const tokenOffset = hasExtendedEventFields ? 1 : 0;
  if (hasExtendedEventFields && decodeBytes32Word(data, 6) !== PILOT_MODE_TAG) {
    throw new Error("BridgeDeposit pilot mode tag mismatch");
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
    token: addressFromAbiWord(decodeBytes32Word(data, tokenOffset), "token"),
    amount: decodeUint256Word(data, tokenOffset + 1).toString(),
    sender: asAddress(decodeAddressTopic(log.topics[3] ?? ""), "sender"),
    flowchainRecipient: decodeBytes32Word(data, tokenOffset + 2),
    nonce: decodeUint256Word(data, tokenOffset + 3).toString(),
    metadataHash: decodeBytes32Word(data, tokenOffset + 4),
    status: "observed",
  };
}

export async function rpcCall<T>(rpcUrl: string, method: string, params: JsonValue[]): Promise<T> {
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

export async function readChainId(rpcUrl: string): Promise<number> {
  const result = await rpcCall<string>(rpcUrl, "eth_chainId", []);
  return Number(BigInt(result));
}

export async function readLatestBlockNumber(rpcUrl: string): Promise<bigint> {
  const result = await rpcCall<string>(rpcUrl, "eth_blockNumber", []);
  return hexQuantityToBigInt(result, "eth_blockNumber");
}

interface BridgeLogReadResult {
  deposits: BridgeDeposit[];
  confirmation?: BridgeConfirmationEvidence;
}

async function readBridgeDepositLogs(options: CliOptions): Promise<BridgeLogReadResult> {
  const expectedChainId = expectedChainIdForMode(options.mode, options.expectedChainId);
  if (options.lockboxAddress !== undefined) {
    assertApprovedLockbox(options.lockboxAddress, options);
  }
  const actualChainId = await readChainId(options.rpcUrl ?? "");
  if (actualChainId !== expectedChainId) {
    throw new Error(`wrong chain id: expected ${expectedChainId} (${chainIdHex(expectedChainId)}), got ${actualChainId} (${chainIdHex(actualChainId as BridgeSourceChainId)})`);
  }

  let confirmation: BridgeConfirmationEvidence | undefined;
  if (options.confirmationDepth > 0) {
    const latestBlock = await readLatestBlockNumber(options.rpcUrl ?? "");
    const requestedToBlock = asBlock(options.toBlock ?? "0", "--to-block");
    const depth = BigInt(options.confirmationDepth);
    const requiredConfirmedBlock = latestBlock >= depth ? latestBlock - depth : -1n;
    const satisfied = requiredConfirmedBlock >= requestedToBlock;
    confirmation = {
      depth: options.confirmationDepth,
      latestBlockNumber: latestBlock.toString(),
      requiredConfirmedBlockNumber: requiredConfirmedBlock < 0n ? "0" : requiredConfirmedBlock.toString(),
      requestedToBlock: requestedToBlock.toString(),
      satisfied,
    };
    if (!satisfied) {
      throw new Error(`insufficient confirmations: toBlock ${requestedToBlock.toString()} requires depth ${options.confirmationDepth}, latest block ${latestBlock.toString()}`);
    }
  }

  const logs = await rpcCall<RpcLog[]>(options.rpcUrl ?? "", "eth_getLogs", [{
    address: options.lockboxAddress,
    fromBlock: blockTag(options.fromBlock ?? "0"),
    toBlock: blockTag(options.toBlock ?? "0"),
    topics: [[BRIDGE_DEPOSIT_TOPIC0, BRIDGE_DEPOSIT_LEGACY_TOPIC0]],
  }]);

  const deposits = logs
    .filter((log) => !log.removed)
    .map((log) => parseBridgeDepositLog(log, expectedChainId));
  for (const deposit of deposits) {
    assertApprovedLockbox(deposit.sourceContract, options);
    assertSupportedToken(deposit.token, options);
  }
  return { deposits, confirmation };
}

export async function runBridgePipeline(options: CliOptions): Promise<BridgePipelineResult> {
  const readResult = isMockMode(options.mode)
    ? {
      deposits: fixtureDeposits(JSON.parse(readFileSync(resolve(options.fixturePath ?? ""), "utf8")) as unknown),
      confirmation: undefined,
    }
    : await readBridgeDepositLogs(options);
  const deposits = readResult.deposits;
  enforcePilotDepositGuardrails(deposits, options);
  if (options.mode === "base-mainnet-canary" && (options.applyCredit || options.withdrawalIntent)) {
    throw new Error("Base mainnet canary is read-only; use base-mainnet-pilot only after explicit pilot approval");
  }

  const confirmation = confirmationForEvidence(options, readResult.confirmation);
  const approvedContracts = new Set(options.approvedLockboxAddresses.map((address) => address.toLowerCase()));
  const observations = deposits.map((deposit) => makeObservation(deposit, options.mode, {
    maxUsd: options.maxUsd,
    maxDepositAmount: options.maxDepositAmount,
    totalCapAmount: options.totalCapAmount,
    supportedTokens: options.supportedTokens.length === 0 ? undefined : options.supportedTokens,
    confirmation: isPilotMode(options.mode) || options.confirmationDepth > 0 ? confirmation : undefined,
    approvedContract: options.approvedLockboxAddresses.length === 0
      ? undefined
      : approvedContracts.has(deposit.sourceContract.toLowerCase()),
  }));
  const credits = makeCredits(observations, options.applyCredit);
  const runtimeApplications = applyCreditsExactlyOnce(credits, options.runtimeStatePath);
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
  const releaseEvidences = withdrawalIntents.map((intent) => {
    const deposit = observations.find((observation) => observation.deposit.depositId === intent.depositId)?.deposit;
    if (deposit === undefined) {
      throw new Error(`missing deposit for withdrawal intent ${intent.withdrawalIntentId}`);
    }
    return makeReleaseEvidence(intent, deposit);
  });
  const duplicateKeys = duplicateReplayKeys(observations);
  const pilotEvidence = isPilotMode(options.mode)
    ? observations.map((observation, index) => {
      const credit = credits[index];
      if (credit === undefined) {
        throw new Error(`missing credit for observation ${observation.observationId}`);
      }
      const application = runtimeApplications[index] ?? runtimeApplications.find((candidate) => candidate.creditId === credit.creditId);
      return makePilotEvidence(options, observation, credit, duplicateKeys, application, confirmation);
    })
    : [];
  const handoff = makeRuntimeHandoff(
    options.mode,
    observations,
    credits,
    withdrawalIntents,
    runtimeApplications,
    pilotEvidence,
    releaseEvidences,
    options.handoffOutPath,
  );

  return {
    observations,
    credits,
    withdrawalIntents,
    runtimeApplications,
    pilotEvidence,
    releaseEvidences,
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
  assertNoSecrets(value);
  writeFileSync(outPath, `${JSON.stringify(value, null, 2)}\n`);
  console.log(`Wrote ${outPath}`);
}

function artifactForSingleOrSet<TSingle, TSet>(values: TSingle[], setValue: TSet): TSingle | TSet {
  return values.length === 1 ? values[0] as TSingle : setValue;
}

function printRunBoundary(options: CliOptions): void {
  if (isMockMode(options.mode)) {
    console.log("Bridge mode: mock fixture; no chain RPC or private key is used.");
    if (options.mode === "mock-pilot") {
      console.log(`Pilot source chain: Base mainnet ${BASE_MAINNET_CHAIN_ID} (${BASE_MAINNET_CHAIN_ID_HEX}).`);
      console.log(`Approved lockboxes: ${options.approvedLockboxAddresses.join(", ")}`);
      console.log(`Supported tokens: ${options.supportedTokens.join(", ")}`);
      console.log(`Pilot max USD: ${options.maxUsd}; max deposit amount: ${options.maxDepositAmount}; total cap amount: ${options.totalCapAmount}.`);
    }
    return;
  }

  const expectedChainId = expectedChainIdForMode(options.mode, options.expectedChainId);
  console.log(`Bridge mode: ${options.mode}`);
  console.log(`Chain id: ${expectedChainId} (${chainIdHex(expectedChainId)})`);
  console.log(`Lockbox: ${options.lockboxAddress}`);
  console.log(`Block range: ${options.fromBlock}-${options.toBlock}`);
  console.log(`Confirmation depth: ${options.confirmationDepth}`);
  console.log("Broadcast: false; this observer never sends transactions.");
  if (options.mode === "base-sepolia") {
    console.log("Asset boundary: Base Sepolia test assets only.");
  }
  if (options.mode === "base-mainnet-canary") {
    console.log(`Real-funds guardrail acknowledged for read-only canary. Max USD: ${options.maxUsd}`);
  }
  if (options.mode === "base-mainnet-pilot") {
    console.log(`Base pilot acknowledged. Approved lockboxes: ${options.approvedLockboxAddresses.join(", ")}`);
    console.log(`Supported tokens: ${options.supportedTokens.join(", ")}`);
    console.log(`Pilot max USD: ${options.maxUsd}; max deposit amount: ${options.maxDepositAmount}; total cap amount: ${options.totalCapAmount}.`);
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
  if (options.evidenceOutPath !== undefined) {
    writeJson(
      options.evidenceOutPath,
      artifactForSingleOrSet(result.pilotEvidence, {
        schema: "flowmemory.bridge_pilot_evidence_set.v0",
        generatedAt: FIXED_TEST_OBSERVED_AT,
        count: result.pilotEvidence.length,
        evidence: result.pilotEvidence,
        productionReady: false,
      }),
    );
  }
  if (options.withdrawalOutPath !== undefined) {
    writeJson(
      options.withdrawalOutPath,
      artifactForSingleOrSet(result.withdrawalIntents, makeWithdrawalIntentSet(result.withdrawalIntents)),
    );
  }
  if (options.releaseEvidenceOutPath !== undefined) {
    writeJson(
      options.releaseEvidenceOutPath,
      artifactForSingleOrSet(result.releaseEvidences, {
        schema: "flowmemory.bridge_release_evidence_set.v0",
        generatedAt: FIXED_TEST_OBSERVED_AT,
        count: result.releaseEvidences.length,
        releaseEvidences: result.releaseEvidences,
        productionReady: false,
      }),
    );
  }

  console.log(
    `Bridge run complete: observed=${result.observations.length}, credits=${result.credits.length}, applications=${result.runtimeApplications.length}, withdrawals=${result.withdrawalIntents.length}, evidence=${result.pilotEvidence.length}`,
  );
  for (const command of nextOperatorCommands(options)) {
    console.log(`Next operator command: ${command}`);
  }
}
