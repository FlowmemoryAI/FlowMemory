import {
  canonicalJson,
  deriveSourceSetId,
  logsFromReceiptFixture,
  parseFlowPulseLogFixture,
  type FlowPulseReceiptFixture,
  type ParsedFlowPulseObservation,
  type RawFlowPulseLogFixture,
} from "../../shared/src/index.ts";

export type DuplicateKind =
  | "unique"
  | "exactDuplicate"
  | "conflictingDuplicate"
  | "pulseDuplicate"
  | "reorgReplacement";

export interface IndexedObservation extends ParsedFlowPulseObservation {
  duplicateKind: DuplicateKind;
  canonicalObservationJson: string;
}

export interface IndexRejectedLog {
  chainId: string;
  blockNumber: string;
  blockHash: string;
  txHash: string;
  transactionIndex: string;
  logIndex: string;
  reasonCode: string;
  message: string;
  source?: "indexer" | "rpc";
  rawLogIndex?: number;
  address?: string;
}

export interface IndexedCursor {
  cursorId: string;
  chainId: string;
  sourceSetId: string;
  blockNumber: string;
  blockHash: string;
  transactionIndex: string;
  logIndex: string;
}

export interface IndexedBatch {
  schema: "flowmemory.indexer.batch.v0";
  source: IndexerStateSource;
  sourceSetId: string;
  observationCount: number;
  cursorCount: number;
  rejectedLogCount: number;
}

export interface IndexedPulse {
  observationId: string;
  pulseId: string;
  rootfieldId: string;
  pulseType: string;
  subject: string;
  commitment: string;
  parentPulseId: string;
  sequence: string;
  occurredAt: string;
  actor: string;
  uri: string;
}

export interface IndexedRootfield {
  rootfieldId: string;
  firstObservationId: string;
  latestObservationId: string;
  pulseCount: number;
}

export type IndexerStateSource = "fixture" | "local-rpc-placeholder" | "base-sepolia-rpc" | "base-mainnet-canary-rpc";

export interface IndexerDashboardFeedObservation {
  observationId: string;
  pulseId: string;
  rootfieldId: string;
  lifecycleState: ParsedFlowPulseObservation["lifecycleState"];
  duplicateKind: DuplicateKind;
  dashboardCanonical: boolean;
  chainId: string;
  emittingContract: string;
  blockNumber: string;
  blockHash: string;
  txHash: string;
  transactionIndex: string;
  logIndex: string;
  pulseType: string;
  sequence: string;
  occurredAt: string;
  uri: string;
}

export interface IndexerDashboardFeed {
  schema: "flowmemory.indexer.dashboard_feed.v0";
  source: IndexerStateSource;
  chainId: string;
  sourceSetId: string;
  observationCount: number;
  dashboardCanonicalObservationCount: number;
  rejectedLogCount: number;
  duplicateCount: number;
  duplicateKindCounts: Record<string, number>;
  rejectedReasonCounts: Record<string, number>;
  warningCodes: string[];
  hasIntegrityWarnings: boolean;
  observations: IndexerDashboardFeedObservation[];
}

export interface IndexerExplorerBlock {
  height: string;
  hash: string;
  parentHash: string | null;
  stateRoot: string | null;
  receiptRoot: string | null;
  finalized: boolean;
  transactionCount: number;
  eventCount: number;
  provenance: IndexerStateSource;
}

export interface IndexerExplorerTransaction {
  txId: string;
  payloadType: string;
  signer: string | null;
  nonce: string | null;
  status: string;
  blockNumber: string;
  blockHash: string;
  receiptId: string;
  errorCode: string | null;
  accountIds: string[];
  tokenIds: string[];
  poolIds: string[];
  bridgeEventIds: string[];
  provenance: IndexerStateSource;
}

export interface IndexerExplorerReceipt {
  receiptId: string;
  txId: string;
  status: string;
  blockNumber: string;
  blockHash: string;
  eventIds: string[];
  errorCode: string | null;
  errorMessage: string | null;
  provenance: IndexerStateSource;
}

export interface IndexerExplorerEvent {
  eventId: string;
  eventName: string;
  blockNumber: string;
  blockHash: string;
  txId: string;
  accountIds: string[];
  tokenIds: string[];
  poolIds: string[];
  bridgeEventIds: string[];
  status: string;
  provenance: IndexerStateSource;
}

export interface IndexerExplorerAccount {
  address: string;
  nativeBalance: string | null;
  tokenBalances: Record<string, string>;
  nonce: string | null;
  recentTransactions: string[];
  lpPositions: string[];
  provenance: IndexerStateSource;
}

export interface IndexerExplorerToken {
  tokenId: string;
  symbol: string | null;
  name: string | null;
  supply: string | null;
  owner: string | null;
  launchTx: string | null;
  transferHistory: string[];
  provenance: IndexerStateSource;
}

export interface IndexerExplorerPool {
  poolId: string;
  tokenPair: [string | null, string | null];
  reserves: [string | null, string | null];
  lpSupply: string | null;
  liquidityEvents: string[];
  swapEvents: string[];
  lpPositionsByAccount: Record<string, string[]>;
  provenance: IndexerStateSource;
}

export interface IndexerExplorerBridgeEvent {
  observationId: string;
  sourceChainId: string | null;
  baseTxHash: string | null;
  logIndex: string | null;
  lockboxAddress: string | null;
  depositor: string | null;
  localRecipient: string | null;
  asset: string | null;
  amount: string | null;
  creditId: string | null;
  withdrawalIntentId: string | null;
  releaseEvidenceId: string | null;
  replayStatus: "accepted" | "duplicate" | "not_applicable";
  provenance: IndexerStateSource;
}

export interface IndexerExplorerIndex {
  schema: "flowmemory.indexer.explorer_index.v0";
  source: IndexerStateSource;
  provenance: {
    origin: "live-runtime" | "fixture-fallback" | "base-observation" | "local-import";
    sourceSetId: string;
  };
  counts: {
    blocks: number;
    transactions: number;
    receipts: number;
    events: number;
    accounts: number;
    tokens: number;
    pools: number;
    bridgeEvents: number;
    failedTransactions: number;
    duplicateOrReplayEvents: number;
  };
  blocks: IndexerExplorerBlock[];
  transactions: IndexerExplorerTransaction[];
  receipts: IndexerExplorerReceipt[];
  events: IndexerExplorerEvent[];
  accounts: IndexerExplorerAccount[];
  tokens: IndexerExplorerToken[];
  pools: IndexerExplorerPool[];
  bridgeEvents: IndexerExplorerBridgeEvent[];
  searchKeys: Record<string, string[]>;
}

export interface IndexerState {
  schema: "flowmemory.indexer.state.v0";
  source: IndexerStateSource;
  observations: IndexedObservation[];
  pulses: IndexedPulse[];
  rootfields: IndexedRootfield[];
  cursors: IndexedCursor[];
  batches: IndexedBatch[];
  rejectedLogs: IndexRejectedLog[];
  duplicates: Array<{
    kind: DuplicateKind;
    observationId: string;
    pulseId: string;
  }>;
  dashboardFeed: IndexerDashboardFeed;
  explorer: IndexerExplorerIndex;
}

export interface IndexerStateOptions {
  finalizedBlockNumber?: string | number | bigint;
  canonicalBlockHashes?: Record<string, string>;
  chainId?: string;
  source?: IndexerStateSource;
  sourceAddresses?: string[];
  preRejectedLogs?: IndexRejectedLog[];
  explorerFallback?: unknown;
}

function canonicalObservationJson(observation: ParsedFlowPulseObservation): string {
  return canonicalJson({
    actor: observation.actor,
    blockHash: observation.blockHash,
    blockNumber: observation.blockNumber,
    chainId: observation.chainId,
    commitment: observation.commitment,
    cursorId: observation.cursorId,
    emittingContract: observation.emittingContract,
    eventSignature: observation.eventSignature,
    lifecycleState: observation.lifecycleState,
    logIndex: observation.logIndex,
    observationId: observation.observationId,
    occurredAt: observation.occurredAt,
    parentPulseId: observation.parentPulseId,
    pulseId: observation.pulseId,
    pulseType: observation.pulseType,
    receiptStatus: observation.receiptStatus,
    rootfieldId: observation.rootfieldId,
    sequence: observation.sequence,
    subject: observation.subject,
    transactionIndex: observation.transactionIndex,
    txHash: observation.txHash,
    uri: observation.uri,
  });
}

function observationStatus(
  observation: ParsedFlowPulseObservation,
  options: IndexerStateOptions,
): ParsedFlowPulseObservation["lifecycleState"] {
  if (observation.lifecycleState === "removed") {
    return "removed";
  }

  const canonicalBlockHash = options.canonicalBlockHashes?.[observation.blockNumber];
  if (canonicalBlockHash !== undefined && canonicalBlockHash.toLowerCase() !== observation.blockHash.toLowerCase()) {
    return "reorged";
  }

  if (options.finalizedBlockNumber !== undefined) {
    return BigInt(observation.blockNumber) <= BigInt(options.finalizedBlockNumber) ? "finalized" : "pending";
  }

  return "observed";
}

function duplicateKindFor(
  observation: ParsedFlowPulseObservation,
  canonicalJsonValue: string,
  seenByObservationId: Map<string, string>,
  seenByPulseId: Map<string, ParsedFlowPulseObservation>,
): DuplicateKind {
  const existingObservation = seenByObservationId.get(observation.observationId);
  if (existingObservation !== undefined) {
    return existingObservation === canonicalJsonValue ? "exactDuplicate" : "conflictingDuplicate";
  }

  const existingPulse = seenByPulseId.get(observation.pulseId);
  if (existingPulse !== undefined && existingPulse.observationId !== observation.observationId) {
    if (existingPulse.blockHash !== observation.blockHash || existingPulse.logIndex !== observation.logIndex) {
      return "reorgReplacement";
    }
    return "pulseDuplicate";
  }

  return "unique";
}

function sortedObservationsForFeed(observations: IndexedObservation[]): IndexedObservation[] {
  return [...observations].sort((left, right) => {
    const block = BigInt(left.blockNumber) - BigInt(right.blockNumber);
    if (block !== 0n) return block < 0n ? -1 : 1;
    const transaction = BigInt(left.transactionIndex) - BigInt(right.transactionIndex);
    if (transaction !== 0n) return transaction < 0n ? -1 : 1;
    const log = BigInt(left.logIndex) - BigInt(right.logIndex);
    if (log !== 0n) return log < 0n ? -1 : 1;
    return left.observationId.localeCompare(right.observationId);
  });
}

function incrementCount(counts: Record<string, number>, key: string): void {
  counts[key] = (counts[key] ?? 0) + 1;
}

function compareStringNumbers(left: string, right: string): number {
  if (/^\d+$/.test(left) && /^\d+$/.test(right)) {
    const diff = BigInt(left) - BigInt(right);
    return diff < 0n ? -1 : diff > 0n ? 1 : 0;
  }
  return left.localeCompare(right);
}

function buildDashboardFeed(input: {
  source: IndexerStateSource;
  chainId: string;
  sourceSetId: string;
  observations: IndexedObservation[];
  rejectedLogs: IndexRejectedLog[];
  duplicates: IndexerState["duplicates"];
}): IndexerDashboardFeed {
  const duplicateKindCounts: Record<string, number> = {};
  const rejectedReasonCounts: Record<string, number> = {};

  for (const duplicate of input.duplicates) {
    incrementCount(duplicateKindCounts, duplicate.kind);
  }
  for (const rejected of input.rejectedLogs) {
    incrementCount(rejectedReasonCounts, rejected.reasonCode);
  }

  const warningCodes = new Set<string>();
  for (const rejected of input.rejectedLogs) {
    warningCodes.add(`rejected.${rejected.reasonCode}`);
  }
  for (const duplicate of input.duplicates) {
    warningCodes.add(`duplicate.${duplicate.kind}`);
  }
  for (const observation of input.observations) {
    if (observation.lifecycleState === "removed" || observation.lifecycleState === "reorged") {
      warningCodes.add(`lifecycle.${observation.lifecycleState}`);
    }
  }

  const observations = sortedObservationsForFeed(input.observations).map((observation) => ({
    observationId: observation.observationId,
    pulseId: observation.pulseId,
    rootfieldId: observation.rootfieldId,
    lifecycleState: observation.lifecycleState,
    duplicateKind: observation.duplicateKind,
    dashboardCanonical:
      observation.duplicateKind !== "exactDuplicate" &&
      observation.lifecycleState !== "removed" &&
      observation.lifecycleState !== "reorged" &&
      observation.lifecycleState !== "superseded",
    chainId: observation.chainId,
    emittingContract: observation.emittingContract,
    blockNumber: observation.blockNumber,
    blockHash: observation.blockHash,
    txHash: observation.txHash,
    transactionIndex: observation.transactionIndex,
    logIndex: observation.logIndex,
    pulseType: observation.pulseType,
    sequence: observation.sequence,
    occurredAt: observation.occurredAt,
    uri: observation.uri,
  }));

  return {
    schema: "flowmemory.indexer.dashboard_feed.v0",
    source: input.source,
    chainId: input.chainId,
    sourceSetId: input.sourceSetId,
    observationCount: input.observations.length,
    dashboardCanonicalObservationCount: observations.filter((observation) => observation.dashboardCanonical).length,
    rejectedLogCount: input.rejectedLogs.length,
    duplicateCount: input.duplicates.length,
    duplicateKindCounts,
    rejectedReasonCounts,
    warningCodes: [...warningCodes].sort(),
    hasIntegrityWarnings: warningCodes.size > 0,
    observations,
  };
}

function sourceOrigin(source: IndexerStateSource): IndexerExplorerIndex["provenance"]["origin"] {
  if (source === "base-mainnet-canary-rpc" || source === "base-sepolia-rpc") {
    return "base-observation";
  }
  if (source === "local-rpc-placeholder") {
    return "live-runtime";
  }
  return "fixture-fallback";
}

function pushUnique(target: string[], value: string | null | undefined): void {
  if (value !== undefined && value !== null && value.length > 0 && !target.includes(value)) {
    target.push(value);
  }
}

function pulseTypeName(pulseType: string): string {
  if (pulseType === "1") return "ROOTFIELD_REGISTERED";
  if (pulseType === "2") return "ROOT_COMMITTED";
  if (pulseType === "3") return "ROOTFIELD_STATUS_CHANGED";
  if (pulseType === "4") return "SWAP_MEMORY_SIGNAL";
  if (pulseType === "5") return "TASK_OPENED";
  if (pulseType === "6") return "TASK_ACCEPTED";
  if (pulseType === "7") return "TASK_STARTED";
  if (pulseType === "8") return "TASK_EVIDENCE_COMMITTED";
  if (pulseType === "9") return "TASK_VERIFIED";
  if (pulseType === "10") return "TASK_FAILED";
  if (pulseType === "11") return "TASK_CHALLENGED";
  if (pulseType === "12") return "TASK_SETTLED";
  if (pulseType === "13") return "TASK_SLASHED";
  return `FLOWPULSE_${pulseType}`;
}

function poolIdsForObservation(observation: IndexedObservation): string[] {
  return observation.pulseType === "4" ? [observation.subject] : [];
}

type JsonObject = Record<string, unknown>;

function asObject(value: unknown): JsonObject | null {
  return typeof value === "object" && value !== null && !Array.isArray(value) ? value as JsonObject : null;
}

function rowsFrom(value: unknown): JsonObject[] {
  if (Array.isArray(value)) {
    return value.map(asObject).filter((row): row is JsonObject => row !== null);
  }

  const object = asObject(value);
  if (object === null) {
    return [];
  }

  return Object.values(object).map(asObject).filter((row): row is JsonObject => row !== null);
}

function fallbackObjectRows(fallback: unknown, key: string): JsonObject[] {
  const root = asObject(fallback);
  const objects = asObject(root?.objects);
  return rowsFrom(objects?.[key]);
}

function fallbackBridgeRows(fallback: unknown, key: string): JsonObject[] {
  const root = asObject(fallback);
  const bridge = asObject(root?.bridge);
  return rowsFrom(bridge?.[key]);
}

function stringValue(value: unknown): string | null {
  if (typeof value === "string" && value.length > 0) {
    return value;
  }
  if (typeof value === "number" || typeof value === "bigint" || typeof value === "boolean") {
    return String(value);
  }
  return null;
}

function firstString(row: JsonObject | null | undefined, fields: string[]): string | null {
  if (row === null || row === undefined) {
    return null;
  }

  for (const field of fields) {
    const value = stringValue(row[field]);
    if (value !== null) {
      return value;
    }
  }

  return null;
}

function buildExplorerIndex(input: {
  source: IndexerStateSource;
  sourceSetId: string;
  observations: IndexedObservation[];
  rejectedLogs: IndexRejectedLog[];
  duplicates: IndexerState["duplicates"];
  explorerFallback?: unknown;
}): IndexerExplorerIndex {
  const blocks = new Map<string, IndexerExplorerBlock>();
  const transactions = new Map<string, IndexerExplorerTransaction>();
  const receipts = new Map<string, IndexerExplorerReceipt>();
  const events: IndexerExplorerEvent[] = [];
  const accounts = new Map<string, IndexerExplorerAccount>();
  const tokens = new Map<string, IndexerExplorerToken>();
  const pools = new Map<string, IndexerExplorerPool>();
  const bridgeEvents = new Map<string, IndexerExplorerBridgeEvent>();
  const searchKeys: Record<string, string[]> = {};

  const addSearch = (type: string, value: string | null | undefined) => {
    if (value === undefined || value === null || value.length === 0) {
      return;
    }
    const list = searchKeys[type] ?? [];
    pushUnique(list, value);
    searchKeys[type] = list;
  };

  const ensureAccount = (address: string): IndexerExplorerAccount => {
    const account = accounts.get(address) ?? {
      address,
      nativeBalance: null,
      tokenBalances: {},
      nonce: null,
      recentTransactions: [],
      lpPositions: [],
      provenance: input.source,
    };
    accounts.set(address, account);
    addSearch("account", address);
    return account;
  };

  const ensurePool = (poolId: string): IndexerExplorerPool => {
    const pool = pools.get(poolId) ?? {
      poolId,
      tokenPair: [null, null],
      reserves: [null, null],
      lpSupply: null,
      liquidityEvents: [],
      swapEvents: [],
      lpPositionsByAccount: {},
      provenance: input.source,
    };
    pools.set(poolId, pool);
    addSearch("pool", poolId);
    return pool;
  };

  for (const observation of input.observations) {
    const blockKey = `${observation.chainId}:${observation.blockNumber}:${observation.blockHash}`;
    const block = blocks.get(blockKey) ?? {
      height: observation.blockNumber,
      hash: observation.blockHash,
      parentHash: null,
      stateRoot: null,
      receiptRoot: null,
      finalized: observation.lifecycleState === "finalized",
      transactionCount: 0,
      eventCount: 0,
      provenance: input.source,
    };
    block.eventCount += 1;
    block.finalized = block.finalized || observation.lifecycleState === "finalized";
    blocks.set(blockKey, block);

    const poolIds = poolIdsForObservation(observation);
    const eventId = observation.observationId;
    events.push({
      eventId,
      eventName: "FlowPulse",
      blockNumber: observation.blockNumber,
      blockHash: observation.blockHash,
      txId: observation.txHash,
      accountIds: [observation.actor],
      tokenIds: [],
      poolIds,
      bridgeEventIds: [],
      status: observation.lifecycleState,
      provenance: input.source,
    });

    const receipt = receipts.get(observation.txHash) ?? {
      receiptId: observation.txHash,
      txId: observation.txHash,
      status: observation.receiptStatus,
      blockNumber: observation.blockNumber,
      blockHash: observation.blockHash,
      eventIds: [],
      errorCode: null,
      errorMessage: null,
      provenance: input.source,
    };
    pushUnique(receipt.eventIds, eventId);
    receipt.status = observation.lifecycleState;
    receipts.set(observation.txHash, receipt);

    const tx = transactions.get(observation.txHash) ?? {
      txId: observation.txHash,
      payloadType: pulseTypeName(observation.pulseType),
      signer: observation.actor,
      nonce: observation.sequence,
      status: observation.lifecycleState,
      blockNumber: observation.blockNumber,
      blockHash: observation.blockHash,
      receiptId: observation.txHash,
      errorCode: null,
      accountIds: [],
      tokenIds: [],
      poolIds: [],
      bridgeEventIds: [],
      provenance: input.source,
    };
    pushUnique(tx.accountIds, observation.actor);
    for (const poolId of poolIds) {
      pushUnique(tx.poolIds, poolId);
    }
    tx.status = observation.lifecycleState;
    transactions.set(observation.txHash, tx);

    const account = ensureAccount(observation.actor);
    pushUnique(account.recentTransactions, observation.txHash);
    account.nonce = observation.sequence;

    for (const poolId of poolIds) {
      const pool = ensurePool(poolId);
      pushUnique(pool.swapEvents, observation.observationId);
    }

    addSearch("blockHeight", observation.blockNumber);
    addSearch("blockHash", observation.blockHash);
    addSearch("transactionId", observation.txHash);
    addSearch("account", observation.actor);
    addSearch("pool", poolIds[0]);
    addSearch("event", eventId);
    addSearch("receipt", observation.txHash);
  }

  for (const rejected of input.rejectedLogs) {
    const blockKey = `${rejected.chainId}:${rejected.blockNumber}:${rejected.blockHash}`;
    const block = blocks.get(blockKey) ?? {
      height: rejected.blockNumber,
      hash: rejected.blockHash,
      parentHash: null,
      stateRoot: null,
      receiptRoot: null,
      finalized: false,
      transactionCount: 0,
      eventCount: 0,
      provenance: input.source,
    };
    block.eventCount += 1;
    blocks.set(blockKey, block);

    const receipt = receipts.get(rejected.txHash) ?? {
      receiptId: rejected.txHash,
      txId: rejected.txHash,
      status: "failed",
      blockNumber: rejected.blockNumber,
      blockHash: rejected.blockHash,
      eventIds: [],
      errorCode: rejected.reasonCode,
      errorMessage: rejected.message,
      provenance: input.source,
    };
    receipt.status = "failed";
    receipt.errorCode = rejected.reasonCode;
    receipt.errorMessage = rejected.message;
    receipts.set(rejected.txHash, receipt);

    transactions.set(rejected.txHash, {
      txId: rejected.txHash,
      payloadType: "FlowPulseRejectedLog",
      signer: null,
      nonce: null,
      status: "failed",
      blockNumber: rejected.blockNumber,
      blockHash: rejected.blockHash,
      receiptId: rejected.txHash,
      errorCode: rejected.reasonCode,
      accountIds: [],
      tokenIds: [],
      poolIds: [],
      bridgeEventIds: [],
      provenance: input.source,
    });

    events.push({
      eventId: `${rejected.txHash}:${rejected.logIndex}`,
      eventName: "RejectedLog",
      blockNumber: rejected.blockNumber,
      blockHash: rejected.blockHash,
      txId: rejected.txHash,
      accountIds: [],
      tokenIds: [],
      poolIds: [],
      bridgeEventIds: [],
      status: "failed",
      provenance: input.source,
    });

    addSearch("blockHeight", rejected.blockNumber);
    addSearch("blockHash", rejected.blockHash);
    addSearch("transactionId", rejected.txHash);
    addSearch("receipt", rejected.txHash);
  }

  for (const token of fallbackObjectRows(input.explorerFallback, "tokens")) {
    const tokenId = firstString(token, ["tokenId", "id"]);
    if (tokenId === null) {
      continue;
    }
    const launchTx = firstString(token, ["launchTx", "launchTxId", "txId"]);
    tokens.set(tokenId, {
      tokenId,
      symbol: firstString(token, ["symbol"]),
      name: firstString(token, ["name"]),
      supply: firstString(token, ["supply", "totalSupply"]),
      owner: firstString(token, ["owner", "issuer"]),
      launchTx,
      transferHistory: [],
      provenance: input.source,
    });
    addSearch("token", tokenId);
    addSearch("token", firstString(token, ["symbol"]));
    addSearch("transactionId", launchTx);
  }

  for (const balance of fallbackObjectRows(input.explorerFallback, "tokenBalances")) {
    const accountId = firstString(balance, ["accountId", "address", "owner"]);
    const tokenId = firstString(balance, ["tokenId", "token"]);
    if (accountId === null || tokenId === null) {
      continue;
    }
    ensureAccount(accountId).tokenBalances[tokenId] = firstString(balance, ["amount", "balance"]) ?? "0";
    addSearch("token", tokenId);
  }

  for (const transfer of fallbackObjectRows(input.explorerFallback, "tokenTransfers")) {
    const tokenId = firstString(transfer, ["tokenId", "token"]);
    const txId = firstString(transfer, ["txId", "transactionId", "transferId"]);
    const fromAccount = firstString(transfer, ["fromAccount", "from"]);
    const toAccount = firstString(transfer, ["toAccount", "to", "accountId"]);
    if (tokenId !== null) {
      const token = tokens.get(tokenId);
      if (token !== undefined) {
        pushUnique(token.transferHistory, txId);
      }
      addSearch("token", tokenId);
    }
    for (const accountId of [fromAccount, toAccount]) {
      if (accountId !== null) {
        pushUnique(ensureAccount(accountId).recentTransactions, txId);
      }
    }
    addSearch("transactionId", txId);
    addSearch("tokenTransfer", firstString(transfer, ["transferId"]));
  }

  for (const poolRow of fallbackObjectRows(input.explorerFallback, "pools")) {
    const poolId = firstString(poolRow, ["poolId", "id"]);
    if (poolId === null) {
      continue;
    }
    const pool = ensurePool(poolId);
    pool.tokenPair = [firstString(poolRow, ["token0"]), firstString(poolRow, ["token1"])];
    pool.reserves = [firstString(poolRow, ["reserve0"]), firstString(poolRow, ["reserve1"])];
    pool.lpSupply = firstString(poolRow, ["lpSupply"]);
    addSearch("transactionId", firstString(poolRow, ["createdTxId", "txId"]));
    addSearch("token", pool.tokenPair[0]);
    addSearch("token", pool.tokenPair[1]);
  }

  for (const liquidity of fallbackObjectRows(input.explorerFallback, "liquidityEvents")) {
    const poolId = firstString(liquidity, ["poolId"]);
    if (poolId === null) {
      continue;
    }
    pushUnique(ensurePool(poolId).liquidityEvents, firstString(liquidity, ["liquidityEventId", "eventId", "txId"]));
    addSearch("transactionId", firstString(liquidity, ["txId"]));
    addSearch("account", firstString(liquidity, ["accountId"]));
  }

  for (const position of fallbackObjectRows(input.explorerFallback, "lpPositions")) {
    const poolId = firstString(position, ["poolId"]);
    const accountId = firstString(position, ["accountId", "owner"]);
    const positionId = firstString(position, ["positionId", "lpPositionId"]);
    if (poolId === null || accountId === null || positionId === null) {
      continue;
    }
    const pool = ensurePool(poolId);
    const accountPositions = pool.lpPositionsByAccount[accountId] ?? [];
    pushUnique(accountPositions, positionId);
    pool.lpPositionsByAccount[accountId] = accountPositions;
    pushUnique(ensureAccount(accountId).lpPositions, positionId);
    addSearch("lpPosition", positionId);
  }

  for (const swap of fallbackObjectRows(input.explorerFallback, "swaps")) {
    const poolId = firstString(swap, ["poolId"]);
    const swapId = firstString(swap, ["swapId"]);
    const txId = firstString(swap, ["txId", "transactionId"]);
    const accountId = firstString(swap, ["accountId", "trader"]);
    if (poolId !== null) {
      pushUnique(ensurePool(poolId).swapEvents, swapId ?? txId);
    }
    if (accountId !== null) {
      pushUnique(ensureAccount(accountId).recentTransactions, txId);
    }
    addSearch("swap", swapId);
    addSearch("transactionId", txId);
    addSearch("token", firstString(swap, ["tokenIn"]));
    addSearch("token", firstString(swap, ["tokenOut"]));
  }

  const fallbackCredits = fallbackBridgeRows(input.explorerFallback, "credits");
  const fallbackWithdrawals = fallbackBridgeRows(input.explorerFallback, "withdrawalIntents");
  const fallbackReleases = fallbackBridgeRows(input.explorerFallback, "releaseEvidence");

  for (const observation of fallbackBridgeRows(input.explorerFallback, "observations")) {
    const deposit = asObject(observation.deposit) ?? observation;
    const observationId = firstString(observation, ["observationId"]) ?? firstString(deposit, ["observationId", "depositId"]);
    if (observationId === null) {
      continue;
    }
    const depositId = firstString(deposit, ["depositId"]);
    const replayKey = firstString(observation, ["replayKey"]) ?? firstString(deposit, ["replayKey"]);
    const credit = fallbackCredits.find((row) =>
      firstString(row, ["observationId"]) === observationId ||
      firstString(row, ["depositId"]) === depositId ||
      firstString(row, ["replayKey"]) === replayKey
    );
    const creditId = firstString(credit, ["creditId"]);
    const withdrawal = fallbackWithdrawals.find((row) =>
      firstString(row, ["creditId"]) === creditId ||
      firstString(row, ["depositId"]) === depositId
    );
    const withdrawalIntentId = firstString(withdrawal, ["withdrawalIntentId", "withdrawalId"]);
    const release = fallbackReleases.find((row) =>
      firstString(row, ["withdrawalIntentId", "withdrawalId"]) === withdrawalIntentId ||
      firstString(row, ["creditId"]) === creditId ||
      firstString(row, ["depositId"]) === depositId
    );
    const creditSource = asObject(credit?.source);
    const statusText = [
      firstString(deposit, ["status"]),
      firstString(observation, ["status"]),
      firstString(credit, ["status"]),
      firstString(credit, ["rejectionReason"]),
    ].filter((value): value is string => value !== null).join(" ").toLowerCase();
    const event: IndexerExplorerBridgeEvent = {
      observationId,
      sourceChainId: firstString(deposit, ["sourceChainId"]) ?? firstString(creditSource, ["chainId"]),
      baseTxHash: firstString(deposit, ["txHash"]) ?? firstString(creditSource, ["txHash"]),
      logIndex: firstString(deposit, ["logIndex"]) ?? firstString(creditSource, ["logIndex"]),
      lockboxAddress: firstString(deposit, ["lockboxAddress", "sourceContract"]) ?? firstString(creditSource, ["contract"]),
      depositor: firstString(deposit, ["sender", "depositor"]),
      localRecipient: firstString(deposit, ["flowchainRecipient", "localRecipient"]) ?? firstString(credit, ["flowchainRecipient", "accountId"]),
      asset: firstString(deposit, ["token", "asset"]) ?? firstString(credit, ["token", "asset"]),
      amount: firstString(deposit, ["amount"]) ?? firstString(credit, ["amount"]),
      creditId,
      withdrawalIntentId,
      releaseEvidenceId: firstString(release, ["releaseEvidenceId"]),
      replayStatus: statusText.includes("duplicate") || statusText.includes("replay") || statusText.includes("rejected") ? "duplicate" : "accepted",
      provenance: input.source,
    };
    bridgeEvents.set(observationId, event);
    addSearch("bridgeObservation", observationId);
    addSearch("bridgeCredit", event.creditId);
    addSearch("withdrawalIntent", event.withdrawalIntentId);
    addSearch("releaseEvidence", event.releaseEvidenceId);
    addSearch("baseTxHash", event.baseTxHash);
    addSearch("account", event.localRecipient);
    addSearch("token", event.asset);
  }

  for (const block of blocks.values()) {
    block.transactionCount = [...transactions.values()]
      .filter((transaction) => transaction.blockNumber === block.height && transaction.blockHash === block.hash)
      .length;
  }

  const sortedBlocks = [...blocks.values()].sort((left, right) => compareStringNumbers(left.height, right.height));
  const sortedTransactions = [...transactions.values()].sort((left, right) => compareStringNumbers(left.blockNumber, right.blockNumber));
  const sortedReceipts = [...receipts.values()].sort((left, right) => compareStringNumbers(left.blockNumber, right.blockNumber));
  const sortedEvents = events.sort((left, right) => compareStringNumbers(left.blockNumber, right.blockNumber));
  const sortedTokens = [...tokens.values()].sort((left, right) => left.tokenId.localeCompare(right.tokenId));
  const sortedPools = [...pools.values()].sort((left, right) => left.poolId.localeCompare(right.poolId));
  const sortedBridgeEvents = [...bridgeEvents.values()].sort((left, right) => left.observationId.localeCompare(right.observationId));

  return {
    schema: "flowmemory.indexer.explorer_index.v0",
    source: input.source,
    provenance: {
      origin: sourceOrigin(input.source),
      sourceSetId: input.sourceSetId,
    },
    counts: {
      blocks: sortedBlocks.length,
      transactions: sortedTransactions.length,
      receipts: sortedReceipts.length,
      events: sortedEvents.length,
      accounts: accounts.size,
      tokens: sortedTokens.length,
      pools: pools.size,
      bridgeEvents: sortedBridgeEvents.length,
      failedTransactions: sortedTransactions.filter((transaction) => transaction.status === "failed").length,
      duplicateOrReplayEvents: input.duplicates.length + sortedBridgeEvents.filter((event) => event.replayStatus === "duplicate").length,
    },
    blocks: sortedBlocks,
    transactions: sortedTransactions,
    receipts: sortedReceipts,
    events: sortedEvents,
    accounts: [...accounts.values()].sort((left, right) => left.address.localeCompare(right.address)),
    tokens: sortedTokens,
    pools: sortedPools,
    bridgeEvents: sortedBridgeEvents,
    searchKeys,
  };
}

export function indexFlowPulseLogs(logs: RawFlowPulseLogFixture[], options: IndexerStateOptions = {}): IndexerState {
  const seenByObservationId = new Map<string, string>();
  const seenByPulseId = new Map<string, ParsedFlowPulseObservation>();
  const rootfields = new Map<string, IndexedRootfield>();
  const observations: IndexedObservation[] = [];
  const cursors = new Map<string, IndexedCursor>();
  const rejectedLogs: IndexRejectedLog[] = [...(options.preRejectedLogs ?? [])];
  const duplicates: IndexerState["duplicates"] = [];
  const source = options.source ?? "fixture";
  const sourceAddresses = options.sourceAddresses ?? logs.map((log) => log.address);
  const sourceSetId = deriveSourceSetId(logs[0]?.chainId ?? options.chainId ?? "0", sourceAddresses);
  const chainId = logs[0]?.chainId ?? options.chainId ?? "0";

  for (const log of logs) {
    if (log.receiptStatus !== "success") {
      rejectedLogs.push({
        chainId: log.chainId,
        blockNumber: log.blockNumber,
        blockHash: log.blockHash,
        txHash: log.transactionHash,
        transactionIndex: log.transactionIndex,
        logIndex: log.logIndex,
        reasonCode: "receipt.reverted",
        message: "receipt status is reverted",
        source: "indexer",
      });
      continue;
    }

    let observation: ParsedFlowPulseObservation;
    try {
      observation = parseFlowPulseLogFixture(log, { sourceSetId });
      observation.lifecycleState = observationStatus(observation, options);
    } catch (error) {
      rejectedLogs.push({
        chainId: log.chainId,
        blockNumber: log.blockNumber,
        blockHash: log.blockHash,
        txHash: log.transactionHash,
        transactionIndex: log.transactionIndex,
        logIndex: log.logIndex,
        reasonCode: "log.malformed",
        message: error instanceof Error ? error.message : "unknown parse error",
        source: "indexer",
      });
      continue;
    }

    const canonicalObservation = canonicalObservationJson(observation);
    const duplicateKind = duplicateKindFor(observation, canonicalObservation, seenByObservationId, seenByPulseId);
    const indexedObservation: IndexedObservation = {
      ...observation,
      duplicateKind,
      canonicalObservationJson: canonicalObservation,
    };

    observations.push(indexedObservation);

    if (duplicateKind === "unique") {
      seenByObservationId.set(observation.observationId, canonicalObservation);
      seenByPulseId.set(observation.pulseId, observation);
    } else {
      duplicates.push({
        kind: duplicateKind,
        observationId: observation.observationId,
        pulseId: observation.pulseId,
      });
      if (duplicateKind === "pulseDuplicate" || duplicateKind === "reorgReplacement") {
        const previous = observations.find((candidate) => candidate.pulseId === observation.pulseId);
        if (previous !== undefined && previous.lifecycleState !== "removed" && previous.lifecycleState !== "reorged") {
          previous.lifecycleState = "superseded";
        }
      }
    }

    cursors.set(observation.cursorId, {
      cursorId: observation.cursorId,
      chainId: observation.chainId,
      sourceSetId,
      blockNumber: observation.blockNumber,
      blockHash: observation.blockHash,
      transactionIndex: observation.transactionIndex,
      logIndex: observation.logIndex,
    });

    const existingRootfield = rootfields.get(observation.rootfieldId);
    if (existingRootfield === undefined) {
      rootfields.set(observation.rootfieldId, {
        rootfieldId: observation.rootfieldId,
        firstObservationId: observation.observationId,
        latestObservationId: observation.observationId,
        pulseCount: 1,
      });
    } else if (duplicateKind !== "exactDuplicate") {
      existingRootfield.latestObservationId = observation.observationId;
      existingRootfield.pulseCount += 1;
    }
  }

  const dashboardFeed = buildDashboardFeed({
    source,
    chainId,
    sourceSetId,
    observations,
    rejectedLogs,
    duplicates,
  });
  const explorer = buildExplorerIndex({
    source,
    sourceSetId,
    observations,
    rejectedLogs,
    duplicates,
    explorerFallback: options.explorerFallback,
  });

  return {
    schema: "flowmemory.indexer.state.v0",
    source,
    batches: [{
      schema: "flowmemory.indexer.batch.v0",
      source,
      sourceSetId,
      observationCount: observations.length,
      cursorCount: cursors.size,
      rejectedLogCount: rejectedLogs.length,
    }],
    observations,
    cursors: [...cursors.values()].sort((left, right) => left.cursorId.localeCompare(right.cursorId)),
    pulses: observations.map((observation) => ({
      observationId: observation.observationId,
      pulseId: observation.pulseId,
      rootfieldId: observation.rootfieldId,
      pulseType: observation.pulseType,
      subject: observation.subject,
      commitment: observation.commitment,
      parentPulseId: observation.parentPulseId,
      sequence: observation.sequence,
      occurredAt: observation.occurredAt,
      actor: observation.actor,
      uri: observation.uri,
    })),
    rootfields: [...rootfields.values()].sort((left, right) => left.rootfieldId.localeCompare(right.rootfieldId)),
    rejectedLogs,
    duplicates,
    dashboardFeed,
    explorer,
  };
}

export function indexFlowPulseReceipts(
  receipts: FlowPulseReceiptFixture[],
  options: IndexerStateOptions = {},
): IndexerState {
  return indexFlowPulseLogs(receipts.flatMap((receipt) => logsFromReceiptFixture(receipt)), options);
}
