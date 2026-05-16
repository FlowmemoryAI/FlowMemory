import { closeSync, existsSync, mkdirSync, openSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
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
export const MAX_CANARY_USD = "25";
export const MAX_PILOT_USD = "25";
export const MAX_BLOCK_RANGE = 5_000n;
export const ZERO_BYTES32 = "0x0000000000000000000000000000000000000000000000000000000000000000";
export const PLACEHOLDER_FLOWCHAIN_RECIPIENT_PATTERN = /^0x5{64}$/i;
export const NATIVE_TOKEN_ADDRESS = "0x0000000000000000000000000000000000000000";
export const DEFAULT_ASSET_DECIMALS = 18;
export const BRIDGE_DEPOSIT_EVENT_SIGNATURE_TEXT =
  "BridgeDeposit(bytes32,uint256,address,address,address,uint256,bytes32,uint256,bytes32,bytes32)";
export const BRIDGE_DEPOSIT_LEGACY_EVENT_SIGNATURE_TEXT =
  "BridgeDeposit(bytes32,uint256,address,address,uint256,bytes32,uint256,bytes32)";
export const BRIDGE_DEPOSIT_TOPIC0 = keccak256Utf8(BRIDGE_DEPOSIT_EVENT_SIGNATURE_TEXT);
export const BRIDGE_DEPOSIT_LEGACY_TOPIC0 = keccak256Utf8(BRIDGE_DEPOSIT_LEGACY_EVENT_SIGNATURE_TEXT);
export const PILOT_MODE_TAG = keccak256Utf8("flowchain.base8453.owner-pilot.v0");
export const FIXED_TEST_OBSERVED_AT = "2026-05-13T00:00:00.000Z";
const APPLICATION_STATE_LOCK_TIMEOUT_MS = 10_000;
const APPLICATION_STATE_LOCK_RETRY_MS = 25;

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

export interface BridgeAssetIdentity {
  sourceChainId: BridgeSourceChainId;
  sourceToken: `0x${string}`;
  destinationAssetId: `0x${string}`;
  decimals: number;
}

export interface BridgeObservation {
  schema: "flowmemory.bridge_deposit_observation.v0";
  observationId: `0x${string}`;
  replayKey: `0x${string}`;
  observedAt: string;
  mode: BridgeMode;
  productionReady: boolean;
  asset: BridgeAssetIdentity;
  deposit: BridgeDeposit;
  guardrails: {
    explicitChainId: boolean;
    explicitContract: boolean;
    explicitBlockRange: boolean;
    noSecrets: boolean;
    maxUsd?: string;
    maxDepositAmount?: string;
    totalCapAmount?: string;
    pilotModeTag?: `0x${string}`;
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
  productionReady: boolean;
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
  asset: BridgeAssetIdentity;
  amount: string;
  flowchainRecipient: `0x${string}`;
  status: "pending" | "applied" | "rejected";
  pendingReason?: string;
  appliedAt?: string;
  rejectionReason?: string;
  localOnly: boolean;
  productionReady: boolean;
}

export interface BridgeCreditSet {
  schema: "flowmemory.bridge_credit_set.v0";
  creditSetId: `0x${string}`;
  generatedAt: string;
  count: number;
  credits: BridgeCredit[];
  productionReady: boolean;
}

export interface BridgeWithdrawalIntent {
  schema: "flowmemory.bridge_withdrawal_intent.v0";
  withdrawalIntentId: `0x${string}`;
  creditId: `0x${string}`;
  depositId: `0x${string}`;
  sourceChainId: BridgeSourceChainId;
  destinationChainId: BridgeSourceChainId;
  token: `0x${string}`;
  asset: BridgeAssetIdentity;
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
  asset: BridgeAssetIdentity;
  amount: string;
  status: "applied" | "idempotent_replay" | "rejected";
  appliedAt?: string;
  previousApplicationId?: `0x${string}`;
  rejectionReason?: string;
  applyCount: 0 | 1;
  localOnly: boolean;
  productionReady: boolean;
}

export interface BridgePilotEvidence {
  schema: "flowmemory.bridge_pilot_evidence.v0";
  evidenceId: `0x${string}`;
  generatedAt: string;
  mode: BridgeMode;
  productionReady: boolean;
  localOnly: boolean;
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
  asset: BridgeAssetIdentity;
  guardrails: {
    approvedContract: boolean;
    confirmation: BridgeConfirmationEvidence;
    maxUsd?: string;
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
  asset: BridgeAssetIdentity;
  releaseCall: {
    method: "releaseERC20" | "releaseNative";
    recipient: `0x${string}`;
    token: `0x${string}`;
    amount: string;
    evidenceHash: `0x${string}`;
    broadcast: false;
  };
  operatorNote: string;
  productionReady: boolean;
  localOnly: boolean;
}

export interface BridgeRuntimeHandoff {
  schema: "flowmemory.bridge_runtime_handoff.v0";
  handoffId: `0x${string}`;
  generatedAt: string;
  mode: BridgeMode;
  productionReady: boolean;
  localOnly: boolean;
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
  assetDecimals: number;
  confirmationDepth: number;
  acknowledgeRealFunds: boolean;
  acknowledgePilot: boolean;
  maxUsd?: string;
  maxDepositAmount?: string;
  totalCapAmount?: string;
  applyCredit: boolean;
  withdrawalIntent: boolean;
  withdrawalBaseRecipient?: `0x${string}`;
  runtimeStatePath?: string;
  cursorStatePath?: string;
  evidenceOutPath?: string;
  releaseEvidenceOutPath?: string;
}

interface BridgeLockboxCursorState {
  schema: "flowmemory.bridge_lockbox_cursor_state.v0";
  stateId: `0x${string}`;
  updatedAt: string;
  mode: BridgeMode;
  sourceChainId: BridgeSourceChainId;
  lockboxAddress: `0x${string}`;
  lastScannedBlock: string;
  lastConfirmedHead: string;
  lastFromBlock: string;
  lastToBlock: string;
  lastLogCount: number;
  localOnly: boolean;
  productionReady: boolean;
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

interface RpcBlock {
  number?: string;
  hash?: string | null;
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

function asAssetDecimals(value: unknown, name: string): number {
  const decimals = asNonNegativeInteger(value, name);
  if (decimals > 255) {
    throw new Error(`${name} must be between 0 and 255`);
  }
  return decimals;
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

function isBasePublicNetworkMode(mode: BridgeMode): boolean {
  return mode === "base-mainnet-canary" || mode === "base-mainnet-pilot";
}

export function isPlaceholderFlowchainRecipient(value: `0x${string}`): boolean {
  return PLACEHOLDER_FLOWCHAIN_RECIPIENT_PATTERN.test(value);
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
  let assetDecimals: number | undefined;
  let confirmationDepth: number | undefined;
  let acknowledgeRealFunds = false;
  let acknowledgePilot = false;
  let maxUsd: string | undefined;
  let maxDepositAmount: string | undefined;
  let totalCapAmount: string | undefined;
  let applyCredit = false;
  let withdrawalIntent = false;
  let withdrawalBaseRecipient: `0x${string}` | undefined;
  let runtimeStatePath: string | undefined;
  let cursorStatePath: string | undefined;
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
    } else if (arg === "--asset-decimals") {
      assetDecimals = asAssetDecimals(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--confirmations" || arg === "--confirmation-depth") {
      confirmationDepth = asNonNegativeInteger(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--acknowledge-real-funds") {
      acknowledgeRealFunds = true;
    } else if (arg === "--acknowledge-pilot") {
      acknowledgePilot = true;
    } else if (arg === "--max-usd") {
      maxUsd = asPositiveDecimalString(argValue(args, index, arg), arg);
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
    } else if (arg === "--cursor-state") {
      cursorStatePath = argValue(args, index, arg);
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

  if (cursorStatePath !== undefined && mode !== "base-mainnet-pilot") {
    throw new Error("--cursor-state is only supported for base-mainnet-pilot");
  }

  if (!isMockMode(mode)) {
    const cursorEnabled = cursorStatePath !== undefined;
    if (!rpcUrl || !lockboxAddress || !fromBlock || (!toBlock && !cursorEnabled)) {
      throw new Error("--rpc-url, --lockbox-address, --from-block, and --to-block are required for RPC reads unless base-mainnet-pilot uses --cursor-state");
    }
    const from = asBlock(fromBlock, "--from-block");
    if (toBlock !== undefined) {
      const to = asBlock(toBlock, "--to-block");
      if (to < from) {
        throw new Error("--to-block must be greater than or equal to --from-block");
      }
      if (!cursorEnabled && (to - from) > MAX_BLOCK_RANGE) {
        throw new Error(`block range is too wide; max is ${MAX_BLOCK_RANGE.toString()} blocks`);
      }
    }
  }

  if (mode === "base-mainnet-canary") {
    if (!acknowledgeRealFunds) {
      throw new Error("Base mainnet canary requires --acknowledge-real-funds");
    }
    if (maxUsd === undefined || BigInt(maxUsd) > BigInt(MAX_CANARY_USD)) {
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
    if (maxUsd === undefined || BigInt(maxUsd) > BigInt(MAX_PILOT_USD)) {
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
    if (assetDecimals === undefined) {
      throw new Error("Base pilot modes require --asset-decimals");
    }
    if (confirmationDepth === undefined) {
      throw new Error("Base pilot modes require --confirmations");
    }
  }

  const resolvedConfirmationDepth = confirmationDepth ?? 0;
  if (isBasePublicNetworkMode(mode) && resolvedConfirmationDepth <= 0) {
    throw new Error("Base mainnet bridge modes require --confirmations greater than zero");
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
    approvedLockboxAddresses: [...new Set(approvedLockboxAddresses)].sort() as `0x${string}`[],
    supportedTokens: [...new Set(supportedTokens)].sort() as `0x${string}`[],
    assetDecimals: assetDecimals ?? DEFAULT_ASSET_DECIMALS,
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
    cursorStatePath,
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

interface BridgeGuardrailOptions {
  maxUsd?: string;
  maxDepositAmount?: string;
  totalCapAmount?: string;
  supportedTokens?: `0x${string}`[];
  assetDecimals?: number;
  confirmation?: BridgeConfirmationEvidence;
  approvedContract?: boolean;
}

function normalizeGuardrailOptions(value?: string | BridgeGuardrailOptions): BridgeGuardrailOptions {
  if (typeof value === "string") {
    return { maxUsd: value };
  }
  return value ?? {};
}

function isLivePilotMode(mode: BridgeMode): boolean {
  return mode === "base-mainnet-pilot";
}

function makeDestinationAssetId(
  sourceChainId: BridgeSourceChainId,
  token: `0x${string}`,
  decimals: number,
): `0x${string}` {
  return stableId("flowmemory.bridge_destination_asset.v0", {
    sourceChainId,
    token,
    decimals,
  });
}

function makeAssetIdentity(deposit: BridgeDeposit, decimals: number): BridgeAssetIdentity {
  return {
    sourceChainId: deposit.sourceChainId,
    sourceToken: deposit.token,
    destinationAssetId: makeDestinationAssetId(deposit.sourceChainId, deposit.token, decimals),
    decimals,
  };
}

export function makeObservation(
  deposit: BridgeDeposit,
  mode: BridgeObservation["mode"],
  guardrailOptions?: string | BridgeGuardrailOptions,
): BridgeObservation {
  const guardrails = normalizeGuardrailOptions(guardrailOptions);
  const replayKey = bridgeReplayKey(deposit);
  const asset = makeAssetIdentity(deposit, guardrails.assetDecimals ?? DEFAULT_ASSET_DECIMALS);
  const livePilot = isLivePilotMode(mode);
  const tokenAllowed = guardrails.supportedTokens === undefined
    || guardrails.supportedTokens.map((token) => token.toLowerCase()).includes(deposit.token.toLowerCase());
  const amountAllowed = guardrails.maxDepositAmount === undefined
    || BigInt(deposit.amount) <= BigInt(guardrails.maxDepositAmount);
  const recipientAllowed = deposit.flowchainRecipient !== ZERO_BYTES32
    && !isPlaceholderFlowchainRecipient(deposit.flowchainRecipient);
  const productionReady = livePilot
    && deposit.sourceChainId === BASE_MAINNET_CHAIN_ID
    && recipientAllowed
    && tokenAllowed
    && amountAllowed
    && guardrails.approvedContract !== false;
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
    productionReady,
    asset,
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
      ...(guardrails.assetDecimals === undefined ? {} : { assetDecimals: guardrails.assetDecimals }),
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
    productionReady: observations.length > 0 && observations.every((observation) => observation.productionReady),
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
  const livePilot = isLivePilotMode(observation.mode);
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
    asset: observation.asset,
    amount: deposit.amount,
    flowchainRecipient: deposit.flowchainRecipient,
    status,
    pendingReason: status === "pending" ? "runtime_intake_pending_handoff_file" : undefined,
    appliedAt: status === "applied" ? FIXED_TEST_OBSERVED_AT : undefined,
    rejectionReason,
    localOnly: !livePilot || status === "rejected",
    productionReady: livePilot && status !== "rejected",
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
    productionReady: credits.length > 0 && credits.every((credit) => credit.productionReady),
  };
}

function makeCredits(observations: BridgeObservation[], applyCredit: boolean, options?: CliOptions): BridgeCredit[] {
  const seen = new Set<`0x${string}`>();
  return observations.map((observation) => {
    const pilotRejectionReason = options === undefined
      ? undefined
      : pilotDepositRejectionReason(observation.deposit, options);
    if (pilotRejectionReason !== undefined) {
      return makeBridgeCredit(observation, "rejected", pilotRejectionReason);
    }
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
      asset: credit.asset,
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
    asset: credit.asset,
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

function sleepSync(ms: number): void {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function acquireApplicationStateLock(statePath: string): { fd: number; lockPath: string } {
  const resolvedStatePath = resolve(statePath);
  const lockPath = `${resolvedStatePath}.lock`;
  mkdirSync(dirname(resolvedStatePath), { recursive: true });
  const deadline = Date.now() + APPLICATION_STATE_LOCK_TIMEOUT_MS;

  for (;;) {
    try {
      const fd = openSync(lockPath, "wx", 0o600);
      try {
        writeFileSync(fd, `${JSON.stringify({
          pid: process.pid,
          statePath: resolvedStatePath,
          acquiredAt: new Date().toISOString(),
        }, null, 2)}\n`);
        return { fd, lockPath };
      } catch (error) {
        closeSync(fd);
        rmSync(lockPath, { force: true });
        throw error;
      }
    } catch (error) {
      const code = typeof error === "object" && error !== null && "code" in error
        ? String((error as { code?: unknown }).code)
        : "";
      if (code !== "EEXIST") {
        throw error;
      }
      if (Date.now() >= deadline) {
        throw new Error(`timed out waiting for bridge runtime credit state lock: ${lockPath}`);
      }
      sleepSync(APPLICATION_STATE_LOCK_RETRY_MS);
    }
  }
}

function releaseApplicationStateLock(lock: { fd: number; lockPath: string }): void {
  try {
    closeSync(lock.fd);
  } finally {
    rmSync(lock.lockPath, { force: true });
  }
}

function withApplicationStateLock<T>(statePath: string | undefined, operation: () => T): T {
  if (statePath === undefined) {
    return operation();
  }
  const lock = acquireApplicationStateLock(statePath);
  try {
    const testHoldMs = Number(process.env.FLOWCHAIN_BRIDGE_STATE_LOCK_TEST_HOLD_MS ?? "0");
    if (Number.isFinite(testHoldMs) && testHoldMs > 0) {
      sleepSync(Math.min(testHoldMs, 1_000));
    }
    return operation();
  } finally {
    releaseApplicationStateLock(lock);
  }
}

function makeRuntimeApplication(
  credit: BridgeCredit,
  status: BridgeRuntimeCreditApplication["status"],
  previousApplicationId?: `0x${string}`,
  rejectionReason?: string,
): BridgeRuntimeCreditApplication {
  const applyCount = status === "applied" ? 1 : 0;
  const productionReady = credit.productionReady;
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
    asset: credit.asset,
    amount: credit.amount,
    status,
    appliedAt: status === "applied" ? FIXED_TEST_OBSERVED_AT : undefined,
    previousApplicationId,
    rejectionReason,
    applyCount,
    localOnly: !productionReady,
    productionReady,
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
  const tmpPath = `${outPath}.${process.pid}.${Date.now()}.tmp`;
  try {
    writeFileSync(tmpPath, `${JSON.stringify(normalized, null, 2)}\n`, { flag: "wx" });
    renameSync(tmpPath, outPath);
  } catch (error) {
    rmSync(tmpPath, { force: true });
    throw error;
  }
}

async function withBridgeStateFileLock<T>(statePath: string, operation: () => Promise<T>): Promise<T> {
  const lock = acquireApplicationStateLock(statePath);
  try {
    return await operation();
  } finally {
    releaseApplicationStateLock(lock);
  }
}

function loadBridgeCursorState(path: string, options: CliOptions, expectedChainId: BridgeSourceChainId): BridgeLockboxCursorState | undefined {
  const resolvedPath = resolve(path);
  if (!existsSync(resolvedPath)) {
    return undefined;
  }
  const parsed = JSON.parse(readFileSync(resolvedPath, "utf8")) as Partial<BridgeLockboxCursorState>;
  if (parsed.schema !== "flowmemory.bridge_lockbox_cursor_state.v0") {
    throw new Error("unsupported bridge lockbox cursor state schema");
  }
  if (parsed.mode !== options.mode) {
    throw new Error(`bridge cursor mode mismatch: expected ${options.mode}, got ${String(parsed.mode)}`);
  }
  if (parsed.sourceChainId !== expectedChainId) {
    throw new Error(`bridge cursor chain mismatch: expected ${expectedChainId}, got ${String(parsed.sourceChainId)}`);
  }
  const lockboxAddress = asAddress(String(parsed.lockboxAddress ?? ""), "cursor.lockboxAddress");
  if (options.lockboxAddress !== undefined && lockboxAddress.toLowerCase() !== options.lockboxAddress.toLowerCase()) {
    throw new Error("bridge cursor lockbox mismatch");
  }
  const lastScannedBlock = asBlock(String(parsed.lastScannedBlock ?? ""), "cursor.lastScannedBlock");
  const lastConfirmedHead = asBlock(String(parsed.lastConfirmedHead ?? "0"), "cursor.lastConfirmedHead");
  const lastFromBlock = asBlock(String(parsed.lastFromBlock ?? "0"), "cursor.lastFromBlock");
  const lastToBlock = asBlock(String(parsed.lastToBlock ?? "0"), "cursor.lastToBlock");
  return {
    schema: "flowmemory.bridge_lockbox_cursor_state.v0",
    stateId: asHash(String(parsed.stateId), "cursor.stateId"),
    updatedAt: String(parsed.updatedAt ?? FIXED_TEST_OBSERVED_AT),
    mode: parsed.mode,
    sourceChainId: parsed.sourceChainId,
    lockboxAddress,
    lastScannedBlock: lastScannedBlock.toString(),
    lastConfirmedHead: lastConfirmedHead.toString(),
    lastFromBlock: lastFromBlock.toString(),
    lastToBlock: lastToBlock.toString(),
    lastLogCount: Number(parsed.lastLogCount ?? 0),
    localOnly: false,
    productionReady: true,
  };
}

function saveBridgeCursorState(
  path: string,
  options: CliOptions,
  expectedChainId: BridgeSourceChainId,
  fromBlock: bigint,
  toBlock: bigint,
  confirmedHead: bigint,
  logCount: number,
): void {
  if (options.lockboxAddress === undefined) {
    throw new Error("bridge cursor save requires lockbox address");
  }
  const stateId = stableId("flowmemory.bridge_lockbox_cursor_state.v0", {
    mode: options.mode,
    sourceChainId: expectedChainId,
    lockboxAddress: options.lockboxAddress.toLowerCase(),
    lastScannedBlock: toBlock.toString(),
    lastConfirmedHead: confirmedHead < 0n ? "0" : confirmedHead.toString(),
  });
  const state: BridgeLockboxCursorState = {
    schema: "flowmemory.bridge_lockbox_cursor_state.v0",
    stateId,
    updatedAt: FIXED_TEST_OBSERVED_AT,
    mode: options.mode,
    sourceChainId: expectedChainId,
    lockboxAddress: options.lockboxAddress,
    lastScannedBlock: toBlock.toString(),
    lastConfirmedHead: confirmedHead < 0n ? "0" : confirmedHead.toString(),
    lastFromBlock: fromBlock.toString(),
    lastToBlock: toBlock.toString(),
    lastLogCount: logCount,
    localOnly: false,
    productionReady: true,
  };
  const outPath = resolve(path);
  mkdirSync(dirname(outPath), { recursive: true });
  assertNoSecrets(state);
  const tmpPath = `${outPath}.${process.pid}.${Date.now()}.tmp`;
  try {
    writeFileSync(tmpPath, `${JSON.stringify(state, null, 2)}\n`, { flag: "wx" });
    renameSync(tmpPath, outPath);
  } catch (error) {
    rmSync(tmpPath, { force: true });
    throw error;
  }
}

function applyCreditsExactlyOnce(
  credits: BridgeCredit[],
  runtimeStatePath?: string,
): BridgeRuntimeCreditApplication[] {
  return withApplicationStateLock(runtimeStatePath, () => {
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
  });
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
  const firstCredit = credits.find((credit) => credit.status !== "rejected");
  const firstAppliedCredit = credits.find((credit) => credit.status === "applied");
  const firstWithdrawal = withdrawalIntents[0];
  const livePilot = isLivePilotMode(mode);
  const appliedRuntimeApplications = runtimeApplications.filter((application) => application.status === "applied");
  const productionReady = livePilot
    && observations.length > 0
    && firstAppliedCredit !== undefined
    && firstAppliedCredit.productionReady
    && appliedRuntimeApplications.every((application) => application.productionReady);
  const amountUnit = livePilot ? "smallest units" : "test units";

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
      summary: `${firstCredit.amount} ${amountUnit} queued for ${firstCredit.flowchainRecipient}.`,
    });
  }
  if (firstAppliedCredit !== undefined) {
    workbenchTimeline.push({
      phase: "credit_applied",
      status: "applied",
      objectId: firstAppliedCredit.creditId,
      title: "Credit applied",
      summary: livePilot
        ? `${firstAppliedCredit.amount} smallest units applied to the configured FlowChain recipient.`
        : `${firstAppliedCredit.amount} test units applied in local bridge smoke state.`,
    });
  }
  if (firstWithdrawal !== undefined) {
    workbenchTimeline.push({
      phase: "withdrawal_requested",
      status: "requested",
      objectId: firstWithdrawal.withdrawalIntentId,
      title: "Withdrawal requested",
      summary: livePilot
        ? "Withdrawal intent recorded with no release transaction broadcast."
        : "Test-mode local-to-Base withdrawal intent recorded with no broadcast or real release.",
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
      summary: livePilot
        ? "Withdrawal intent recorded; no release transaction is broadcast by this command."
        : "Test-mode withdrawal intent recorded; no mainnet or real-funds release is broadcast.",
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
    productionReady,
    localOnly: !productionReady,
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
      note: productionReady
        ? "Confirmed Base 8453 pilot deposit handoff is ready for explicit FlowChain runtime intake."
        : "Runtime/control-plane bridge intake is not merged in this scope. Consume this file as the deterministic bridge credit handoff.",
    },
    workbenchTimeline,
    workbenchRecords,
    limitations: livePilot
      ? [
        "Base 8453 pilot artifacts do not broadcast release transactions.",
        "No audited security, public bridge readiness, or trustless finality is claimed.",
        "RPC URLs and private keys are never written to bridge artifacts.",
      ]
      : [
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
    "npm run flowchain:bridge:local-credit:smoke",
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
  const productionReady = isLivePilotMode(options.mode);
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
    productionReady,
    localOnly: !productionReady,
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
    asset: observation.asset,
    guardrails: {
      approvedContract,
      confirmation: confirmationEvidence,
      maxUsd: options.maxUsd,
      maxDepositAmount: options.maxDepositAmount,
      totalCapAmount: options.totalCapAmount,
      pilotModeTag: PILOT_MODE_TAG,
      supportedTokens: options.supportedTokens,
      assetDecimals: options.assetDecimals,
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
  const productionReady = intent.sourceChainId === BASE_MAINNET_CHAIN_ID && intent.destinationChainId === BASE_MAINNET_CHAIN_ID;
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
    asset: intent.asset,
    releaseCall: {
      method: deposit.token === "0x0000000000000000000000000000000000000000" ? "releaseNative" : "releaseERC20",
      recipient: intent.baseRecipient,
      token: intent.token,
      amount: intent.amount,
      evidenceHash,
      broadcast: false,
    },
    operatorNote: "Pilot release evidence only. Review before any separate release-authority transaction; this relayer does not broadcast.",
    productionReady,
    localOnly: !productionReady,
  };
}

export function validateReleaseEvidenceMatchesWithdrawal(
  intent: BridgeWithdrawalIntent,
  evidence: BridgeReleaseEvidence,
): void {
  if (evidence.withdrawalIntentId !== intent.withdrawalIntentId) {
    throw new Error("release evidence withdrawalIntentId mismatch");
  }
  if (evidence.creditId !== intent.creditId) {
    throw new Error("release evidence creditId mismatch");
  }
  if (evidence.depositId !== intent.depositId) {
    throw new Error("release evidence depositId mismatch");
  }
  if (evidence.sourceChainId !== intent.sourceChainId || evidence.destinationChainId !== intent.destinationChainId) {
    throw new Error("release evidence chain id mismatch");
  }
  if (evidence.releaseCall.token !== intent.token) {
    throw new Error("release evidence token mismatch");
  }
  if (evidence.releaseCall.amount !== intent.amount) {
    throw new Error("release evidence amount mismatch");
  }
  if (evidence.releaseCall.recipient !== intent.baseRecipient) {
    throw new Error("release evidence recipient mismatch");
  }
  if (evidence.asset.destinationAssetId !== intent.asset.destinationAssetId
    || evidence.asset.sourceToken !== intent.asset.sourceToken
    || evidence.asset.decimals !== intent.asset.decimals
    || evidence.asset.sourceChainId !== intent.asset.sourceChainId) {
    throw new Error("release evidence asset identity mismatch");
  }
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

function pilotDepositRejectionReason(deposit: BridgeDeposit, options: CliOptions): string | undefined {
  if (!isPilotMode(options.mode)) {
    return undefined;
  }
  if (deposit.sourceChainId !== BASE_MAINNET_CHAIN_ID) {
    return "wrong_source_chain";
  }
  if (deposit.flowchainRecipient === ZERO_BYTES32) {
    return "missing_flowchain_recipient";
  }
  if (isPlaceholderFlowchainRecipient(deposit.flowchainRecipient)) {
    return "blocked_placeholder_flowchain_recipient";
  }
  try {
    assertApprovedLockbox(deposit.sourceContract, options);
  } catch {
    return "unapproved_lockbox";
  }
  try {
    assertSupportedToken(deposit.token, options);
  } catch {
    return "unsupported_token";
  }
  const amount = BigInt(deposit.amount);
  const maxDeposit = BigInt(options.maxDepositAmount ?? "0");
  if (amount > maxDeposit) {
    return "deposit_amount_exceeds_pilot_cap";
  }
  return undefined;
}

function enforcePilotDepositGuardrails(deposits: BridgeDeposit[], options: CliOptions): void {
  if (!isPilotMode(options.mode)) {
    return;
  }
  const totalCap = BigInt(options.totalCapAmount ?? "0");
  let total = 0n;
  const countedReplayKeys = new Set<`0x${string}`>();
  for (const deposit of deposits) {
    if (pilotDepositRejectionReason(deposit, options) !== undefined) {
      continue;
    }
    const replayKey = bridgeReplayKey(deposit);
    if (!countedReplayKeys.has(replayKey)) {
      countedReplayKeys.add(replayKey);
      total += BigInt(deposit.amount);
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
    logIndex: hexQuantityToNumber(log.logIndex, "logIndex") ?? 0,
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

function blockTagFromBigInt(value: bigint): string {
  return `0x${value.toString(16)}`;
}

async function readChainId(rpcUrl: string): Promise<number> {
  const result = await rpcCall<string>(rpcUrl, "eth_chainId", []);
  return Number(BigInt(result));
}

async function readLatestBlockNumber(rpcUrl: string): Promise<bigint> {
  const result = await rpcCall<string>(rpcUrl, "eth_blockNumber", []);
  return hexQuantityToBigInt(result, "eth_blockNumber");
}

async function readCanonicalBlockHash(rpcUrl: string, blockNumber: string): Promise<`0x${string}`> {
  const block = await rpcCall<RpcBlock | null>(rpcUrl, "eth_getBlockByNumber", [blockNumber, false]);
  if (block === null) {
    throw new Error(`canonical block ${blockNumber} was not returned by RPC`);
  }
  if (block.number !== undefined && hexQuantityToBigInt(block.number, "canonical block number") !== hexQuantityToBigInt(blockNumber, "log blockNumber")) {
    throw new Error(`canonical block number mismatch: requested ${blockNumber}, got ${block.number}`);
  }
  if (block.hash === undefined || block.hash === null) {
    throw new Error(`canonical block ${blockNumber} is missing hash`);
  }
  return asHash(block.hash, "canonical block hash");
}

async function assertCanonicalBasePublicLogs(options: CliOptions, logs: RpcLog[]): Promise<void> {
  if (!isBasePublicNetworkMode(options.mode)) {
    return;
  }
  const canonicalBlockHashes = new Map<string, `0x${string}`>();
  for (const log of logs) {
    if (log.removed) {
      throw new Error("removed bridge logs must be handled by a reorg-aware reader");
    }
    if (log.blockNumber === undefined) {
      throw new Error("BridgeDeposit RPC log is missing blockNumber");
    }
    if (log.blockHash === undefined) {
      throw new Error("BridgeDeposit RPC log is missing blockHash");
    }
    const logBlockHash = asHash(log.blockHash, "blockHash");
    const blockNumberKey = log.blockNumber.toLowerCase();
    let canonicalBlockHash = canonicalBlockHashes.get(blockNumberKey);
    if (canonicalBlockHash === undefined) {
      canonicalBlockHash = await readCanonicalBlockHash(options.rpcUrl ?? "", log.blockNumber);
      canonicalBlockHashes.set(blockNumberKey, canonicalBlockHash);
    }
    if (canonicalBlockHash.toLowerCase() !== logBlockHash.toLowerCase()) {
      const decimalBlockNumber = hexQuantityToBigInt(log.blockNumber, "blockNumber").toString();
      throw new Error(`non-canonical BridgeDeposit log: block ${decimalBlockNumber} hash mismatch`);
    }
  }
}

interface BridgeLogReadResult {
  deposits: BridgeDeposit[];
  confirmation?: BridgeConfirmationEvidence;
}

async function readBridgeDepositLogs(options: CliOptions): Promise<BridgeLogReadResult> {
  if (options.cursorStatePath !== undefined) {
    return withBridgeStateFileLock(options.cursorStatePath, () => readBridgeDepositLogsLocked(options));
  }
  return readBridgeDepositLogsLocked(options);
}

async function readBridgeDepositLogsLocked(options: CliOptions): Promise<BridgeLogReadResult> {
  const expectedChainId = expectedChainIdForMode(options.mode, options.expectedChainId);
  if (options.lockboxAddress !== undefined) {
    assertApprovedLockbox(options.lockboxAddress, options);
  }
  const actualChainId = await readChainId(options.rpcUrl ?? "");
  if (actualChainId !== expectedChainId) {
    throw new Error(`wrong chain id: expected ${expectedChainId} (${chainIdHex(expectedChainId)}), got ${actualChainId} (${chainIdHex(actualChainId as BridgeSourceChainId)})`);
  }

  let confirmation: BridgeConfirmationEvidence | undefined;
  let effectiveFromBlock = asBlock(options.fromBlock ?? "0", "--from-block");
  let effectiveToBlock = asBlock(options.toBlock ?? "0", "--to-block");
  let latestBlock: bigint | undefined;
  let requiredConfirmedBlock: bigint | undefined;

  if (options.cursorStatePath !== undefined) {
    const cursor = loadBridgeCursorState(options.cursorStatePath, options, expectedChainId);
    if (cursor !== undefined) {
      effectiveFromBlock = asBlock(cursor.lastScannedBlock, "cursor.lastScannedBlock") + 1n;
    }
    latestBlock = await readLatestBlockNumber(options.rpcUrl ?? "");
    const depth = BigInt(options.confirmationDepth);
    requiredConfirmedBlock = latestBlock >= depth ? latestBlock - depth : -1n;
    const upperBound = options.toBlock === undefined ? undefined : asBlock(options.toBlock, "--to-block");
    const windowUpperBound = effectiveFromBlock + MAX_BLOCK_RANGE;
    effectiveToBlock = [requiredConfirmedBlock, windowUpperBound, upperBound]
      .filter((value): value is bigint => value !== undefined)
      .reduce((lowest, value) => value < lowest ? value : lowest);
    confirmation = {
      depth: options.confirmationDepth,
      latestBlockNumber: latestBlock.toString(),
      requiredConfirmedBlockNumber: requiredConfirmedBlock < 0n ? "0" : requiredConfirmedBlock.toString(),
      requestedToBlock: effectiveToBlock < effectiveFromBlock ? effectiveFromBlock.toString() : effectiveToBlock.toString(),
      satisfied: effectiveToBlock >= effectiveFromBlock,
    };
    if (effectiveToBlock < effectiveFromBlock) {
      return { deposits: [], confirmation };
    }
  } else if (options.confirmationDepth > 0) {
    const latestBlock = await readLatestBlockNumber(options.rpcUrl ?? "");
    const requestedToBlock = effectiveToBlock;
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
    fromBlock: blockTagFromBigInt(effectiveFromBlock),
    toBlock: blockTagFromBigInt(effectiveToBlock),
    topics: [[BRIDGE_DEPOSIT_TOPIC0, BRIDGE_DEPOSIT_LEGACY_TOPIC0]],
  }]);

  await assertCanonicalBasePublicLogs(options, logs);

  const deposits = logs
    .map((log) => parseBridgeDepositLog(log, expectedChainId));
  for (const deposit of deposits) {
    assertApprovedLockbox(deposit.sourceContract, options);
    assertSupportedToken(deposit.token, options);
  }
  if (options.cursorStatePath !== undefined) {
    saveBridgeCursorState(
      options.cursorStatePath,
      options,
      expectedChainId,
      effectiveFromBlock,
      effectiveToBlock,
      requiredConfirmedBlock ?? effectiveToBlock,
      deposits.length,
    );
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
    assetDecimals: options.assetDecimals,
    confirmation: isPilotMode(options.mode) || options.confirmationDepth > 0 ? confirmation : undefined,
    approvedContract: options.approvedLockboxAddresses.length === 0
      ? undefined
      : approvedContracts.has(deposit.sourceContract.toLowerCase()),
  }));
  const credits = makeCredits(observations, options.applyCredit, options);
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
    const evidence = makeReleaseEvidence(intent, deposit);
    validateReleaseEvidenceMatchesWithdrawal(intent, evidence);
    return evidence;
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
  console.log(`Block range: ${options.fromBlock}-${options.toBlock ?? "cursor-confirmed-head"}`);
  if (options.cursorStatePath !== undefined) {
    console.log(`Cursor state: ${resolve(options.cursorStatePath)}`);
  }
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
