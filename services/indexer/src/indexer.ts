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
}

export interface IndexerStateOptions {
  finalizedBlockNumber?: string | number | bigint;
  canonicalBlockHashes?: Record<string, string>;
  chainId?: string;
  source?: IndexerStateSource;
  sourceAddresses?: string[];
  preRejectedLogs?: IndexRejectedLog[];
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
  };
}

export function indexFlowPulseReceipts(
  receipts: FlowPulseReceiptFixture[],
  options: IndexerStateOptions = {},
): IndexerState {
  return indexFlowPulseLogs(receipts.flatMap((receipt) => logsFromReceiptFixture(receipt)), options);
}
