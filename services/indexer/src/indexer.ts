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
  source: "fixture" | "local-rpc-placeholder";
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

export interface IndexerState {
  schema: "flowmemory.indexer.state.v0";
  source: "fixture" | "local-rpc-placeholder";
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
}

export interface IndexerStateOptions {
  finalizedBlockNumber?: string | number | bigint;
  canonicalBlockHashes?: Record<string, string>;
  sourceAddresses?: string[];
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

export function indexFlowPulseLogs(logs: RawFlowPulseLogFixture[], options: IndexerStateOptions = {}): IndexerState {
  const seenByObservationId = new Map<string, string>();
  const seenByPulseId = new Map<string, ParsedFlowPulseObservation>();
  const rootfields = new Map<string, IndexedRootfield>();
  const observations: IndexedObservation[] = [];
  const cursors = new Map<string, IndexedCursor>();
  const rejectedLogs: IndexRejectedLog[] = [];
  const duplicates: IndexerState["duplicates"] = [];
  const sourceAddresses = options.sourceAddresses ?? logs.map((log) => log.address);
  const sourceSetId = deriveSourceSetId(logs[0]?.chainId ?? "0", sourceAddresses);

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

  return {
    schema: "flowmemory.indexer.state.v0",
    source: "fixture",
    batches: [{
      schema: "flowmemory.indexer.batch.v0",
      source: "fixture",
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
  };
}

export function indexFlowPulseReceipts(
  receipts: FlowPulseReceiptFixture[],
  options: IndexerStateOptions = {},
): IndexerState {
  return indexFlowPulseLogs(receipts.flatMap((receipt) => logsFromReceiptFixture(receipt)), options);
}
