import {
  decodeAddressTopic,
  decodeBytes32Word,
  decodeString,
  decodeUint256Word,
} from "./abi.ts";
import { FLOWPULSE_EVENT_TOPIC0 } from "./constants.ts";
import { normalizeAddress, normalizeBytes32, normalizeHex, hexToBytes } from "./hex.ts";
import {
  deriveCursorId,
  deriveObservationId,
  deriveSourceSetId,
  type ObservationLifecycleState,
} from "./observation.ts";

export interface RawFlowPulseLogFixture {
  chainId: string;
  address: string;
  topics: string[];
  data: string;
  blockNumber: string;
  blockHash: string;
  transactionHash: string;
  transactionIndex: string;
  logIndex: string;
  receiptStatus: "success" | "reverted";
  removed?: boolean;
}

export interface FlowPulseReceiptFixtureLog {
  address: string;
  topics: string[];
  data: string;
  logIndex: string;
  removed?: boolean;
}

export interface FlowPulseReceiptFixture {
  chainId: string;
  blockNumber: string;
  blockHash: string;
  transactionHash: string;
  transactionIndex: string;
  status: "success" | "reverted";
  logs: FlowPulseReceiptFixtureLog[];
}

export interface ParsedFlowPulseObservation {
  observationId: `0x${string}`;
  cursorId: `0x${string}`;
  lifecycleState: ObservationLifecycleState;
  chainId: string;
  emittingContract: `0x${string}`;
  eventSignature: `0x${string}`;
  blockNumber: string;
  blockHash: `0x${string}`;
  txHash: `0x${string}`;
  transactionIndex: string;
  logIndex: string;
  receiptStatus: "success" | "reverted";
  pulseId: `0x${string}`;
  rootfieldId: `0x${string}`;
  actor: `0x${string}`;
  pulseType: string;
  subject: `0x${string}`;
  commitment: `0x${string}`;
  parentPulseId: `0x${string}`;
  sequence: string;
  occurredAt: string;
  uri: string;
}

export interface FlowPulseLogParseOptions {
  sourceSetId?: string;
  sourceAddresses?: string[];
}

export function parseFlowPulseLogFixture(
  log: RawFlowPulseLogFixture,
  options: FlowPulseLogParseOptions = {},
): ParsedFlowPulseObservation {
  if (log.topics.length !== 4) {
    throw new Error(`FlowPulse log must have 4 topics, got ${log.topics.length}`);
  }

  const eventSignature = normalizeBytes32(log.topics[0]);
  if (eventSignature !== FLOWPULSE_EVENT_TOPIC0) {
    throw new Error(`unsupported event signature: ${eventSignature}`);
  }

  const data = hexToBytes(normalizeHex(log.data));
  const emittingContract = normalizeAddress(log.address);
  const blockHash = normalizeBytes32(log.blockHash);
  const txHash = normalizeBytes32(log.transactionHash);
  const pulseId = normalizeBytes32(log.topics[1]);
  const rootfieldId = normalizeBytes32(log.topics[2]);
  const actor = decodeAddressTopic(log.topics[3]);

  const observationId = deriveObservationId({
    chainId: log.chainId,
    emittingContract,
    txHash,
    logIndex: log.logIndex,
  });
  const sourceSetId = options.sourceSetId ?? deriveSourceSetId(log.chainId, options.sourceAddresses ?? [emittingContract]);
  const cursorId = deriveCursorId({
    chainId: log.chainId,
    sourceSetId,
    blockNumber: log.blockNumber,
    blockHash,
    transactionIndex: log.transactionIndex,
    logIndex: log.logIndex,
  });

  return {
    observationId,
    cursorId,
    lifecycleState: log.removed ? "removed" : "observed",
    chainId: log.chainId,
    emittingContract,
    eventSignature,
    blockNumber: log.blockNumber,
    blockHash,
    txHash,
    transactionIndex: log.transactionIndex,
    logIndex: log.logIndex,
    receiptStatus: log.receiptStatus,
    pulseId,
    rootfieldId,
    actor,
    pulseType: decodeUint256Word(data, 0).toString(),
    subject: decodeBytes32Word(data, 1),
    commitment: decodeBytes32Word(data, 2),
    parentPulseId: decodeBytes32Word(data, 3),
    sequence: decodeUint256Word(data, 4).toString(),
    occurredAt: decodeUint256Word(data, 5).toString(),
    uri: decodeString(data, decodeUint256Word(data, 6)),
  };
}

export function logsFromReceiptFixture(receipt: FlowPulseReceiptFixture): RawFlowPulseLogFixture[] {
  return receipt.logs.map((log) => ({
    chainId: receipt.chainId,
    address: log.address,
    topics: log.topics,
    data: log.data,
    blockNumber: receipt.blockNumber,
    blockHash: receipt.blockHash,
    transactionHash: receipt.transactionHash,
    transactionIndex: receipt.transactionIndex,
    logIndex: log.logIndex,
    receiptStatus: receipt.status,
    removed: log.removed,
  }));
}
