import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";

import { assertNoSecrets, canonicalJson, keccak256Hex } from "../../shared/src/index.ts";
import type { IndexerDashboardFeed, IndexerState } from "./indexer.ts";

export interface PersistedIndexerState {
  schema: "flowmemory.indexer.persistence.v0";
  state: IndexerState;
}

export interface CheckpointDashboardFeed {
  schema: "flowmemory.indexer.checkpoint_dashboard_feed.v0";
  feedSchema: IndexerDashboardFeed["schema"];
  sourceSetId: string;
  observationCount: number;
  dashboardCanonicalObservationCount: number;
  rejectedLogCount: number;
  duplicateCount: number;
  rejectedReasonCounts: Record<string, number>;
  duplicateKindCounts: Record<string, number>;
  warningCodes: string[];
  hasIntegrityWarnings: boolean;
}

export interface BaseSepoliaIndexerCheckpoint {
  schema: "flowmemory.indexer.base_sepolia_checkpoint.v0";
  network: "base-sepolia";
  chainId: "84532";
  source: "base-sepolia-rpc";
  addresses: string[];
  fromBlock: string;
  toBlock: string;
  finalizedBlockNumber?: string;
  statePath: string;
  observationCount: number;
  cursorCount: number;
  rejectedLogCount: number;
  duplicateCount: number;
  lastIndexedBlock: string;
  lastScannedBlock: string;
  highestObservedBlock: string | null;
  nextFromBlock: string;
  emptyRange: boolean;
  stateDigest: `0x${string}`;
  generatedAt: string;
  dashboardFeed: CheckpointDashboardFeed;
  safety: {
    networkBoundary: "base-sepolia-testnet-only";
    productionReady: false;
    storesRpcUrl: false;
    storesPrivateKeys: false;
  };
}

export interface BaseCanaryIndexerCheckpoint {
  schema: "flowmemory.indexer.base_canary_checkpoint.v0";
  network: "base-mainnet-canary";
  chainId: "8453";
  source: "base-mainnet-canary-rpc";
  addresses: string[];
  fromBlock: string;
  toBlock: string;
  finalizedBlockNumber?: string;
  statePath: string;
  observationCount: number;
  cursorCount: number;
  rejectedLogCount: number;
  duplicateCount: number;
  lastIndexedBlock: string;
  lastScannedBlock: string;
  highestObservedBlock: string | null;
  nextFromBlock: string;
  emptyRange: boolean;
  stateDigest: `0x${string}`;
  generatedAt: string;
  dashboardFeed: CheckpointDashboardFeed;
  safety: {
    acknowledgement: "base-mainnet-canary-only";
    productionReady: false;
    storesRpcUrl: false;
    storesPrivateKeys: false;
  };
}

export function persistedIndexerState(state: IndexerState): PersistedIndexerState {
  return {
    schema: "flowmemory.indexer.persistence.v0",
    state,
  };
}

export function indexerStateDigest(state: IndexerState): `0x${string}` {
  return keccak256Hex(new TextEncoder().encode(canonicalJson(persistedIndexerState(state))));
}

function checkpointDashboardFeed(state: IndexerState): CheckpointDashboardFeed {
  return {
    schema: "flowmemory.indexer.checkpoint_dashboard_feed.v0",
    feedSchema: state.dashboardFeed.schema,
    sourceSetId: state.dashboardFeed.sourceSetId,
    observationCount: state.dashboardFeed.observationCount,
    dashboardCanonicalObservationCount: state.dashboardFeed.dashboardCanonicalObservationCount,
    rejectedLogCount: state.dashboardFeed.rejectedLogCount,
    duplicateCount: state.dashboardFeed.duplicateCount,
    rejectedReasonCounts: state.dashboardFeed.rejectedReasonCounts,
    duplicateKindCounts: state.dashboardFeed.duplicateKindCounts,
    warningCodes: state.dashboardFeed.warningCodes,
    hasIntegrityWarnings: state.dashboardFeed.hasIntegrityWarnings,
  };
}

export function baseSepoliaIndexerCheckpoint(input: {
  addresses: string[];
  fromBlock: string;
  toBlock: string;
  finalizedBlockNumber?: string;
  statePath: string;
  state: IndexerState;
  generatedAt?: string;
}): BaseSepoliaIndexerCheckpoint {
  const highestObservedBlock = input.state.cursors.reduce<string | null>((latest, cursor) => {
    if (latest === null) return cursor.blockNumber;
    return BigInt(cursor.blockNumber) > BigInt(latest) ? cursor.blockNumber : latest;
  }, null);
  const lastIndexedBlock = input.toBlock;

  return {
    schema: "flowmemory.indexer.base_sepolia_checkpoint.v0",
    network: "base-sepolia",
    chainId: "84532",
    source: "base-sepolia-rpc",
    addresses: [...input.addresses].sort((left, right) => left.localeCompare(right)),
    fromBlock: input.fromBlock,
    toBlock: input.toBlock,
    finalizedBlockNumber: input.finalizedBlockNumber,
    statePath: input.statePath,
    observationCount: input.state.observations.length,
    cursorCount: input.state.cursors.length,
    rejectedLogCount: input.state.rejectedLogs.length,
    duplicateCount: input.state.duplicates.length,
    lastIndexedBlock,
    lastScannedBlock: input.toBlock,
    highestObservedBlock,
    nextFromBlock: (BigInt(lastIndexedBlock) + 1n).toString(),
    emptyRange: input.state.observations.length === 0 && input.state.rejectedLogs.length === 0,
    stateDigest: indexerStateDigest(input.state),
    generatedAt: input.generatedAt ?? new Date().toISOString(),
    dashboardFeed: checkpointDashboardFeed(input.state),
    safety: {
      networkBoundary: "base-sepolia-testnet-only",
      productionReady: false,
      storesRpcUrl: false,
      storesPrivateKeys: false,
    },
  };
}

export function baseCanaryIndexerCheckpoint(input: {
  addresses: string[];
  fromBlock: string;
  toBlock: string;
  finalizedBlockNumber?: string;
  statePath: string;
  state: IndexerState;
  generatedAt?: string;
}): BaseCanaryIndexerCheckpoint {
  const highestObservedBlock = input.state.cursors.reduce<string | null>((latest, cursor) => {
    if (latest === null) return cursor.blockNumber;
    return BigInt(cursor.blockNumber) > BigInt(latest) ? cursor.blockNumber : latest;
  }, null);
  const lastIndexedBlock = input.toBlock;

  return {
    schema: "flowmemory.indexer.base_canary_checkpoint.v0",
    network: "base-mainnet-canary",
    chainId: "8453",
    source: "base-mainnet-canary-rpc",
    addresses: [...input.addresses].sort((left, right) => left.localeCompare(right)),
    fromBlock: input.fromBlock,
    toBlock: input.toBlock,
    finalizedBlockNumber: input.finalizedBlockNumber,
    statePath: input.statePath,
    observationCount: input.state.observations.length,
    cursorCount: input.state.cursors.length,
    rejectedLogCount: input.state.rejectedLogs.length,
    duplicateCount: input.state.duplicates.length,
    lastIndexedBlock,
    lastScannedBlock: input.toBlock,
    highestObservedBlock,
    nextFromBlock: (BigInt(lastIndexedBlock) + 1n).toString(),
    emptyRange: input.state.observations.length === 0 && input.state.rejectedLogs.length === 0,
    stateDigest: indexerStateDigest(input.state),
    generatedAt: input.generatedAt ?? new Date().toISOString(),
    dashboardFeed: checkpointDashboardFeed(input.state),
    safety: {
      acknowledgement: "base-mainnet-canary-only",
      productionReady: false,
      storesRpcUrl: false,
      storesPrivateKeys: false,
    },
  };
}

function writeCanonicalJsonFile(path: string, value: unknown, scanForSecrets = false): void {
  if (scanForSecrets) {
    assertNoSecrets(value);
  }
  mkdirSync(dirname(path), { recursive: true });
  const tempPath = join(dirname(path), `.${basename(path)}.${process.pid}.${Date.now()}.tmp`);
  writeFileSync(tempPath, `${canonicalJson(value)}\n`, "utf8");
  renameSync(tempPath, path);
}

export function writeIndexerState(path: string, state: IndexerState): void {
  writeCanonicalJsonFile(path, persistedIndexerState(state));
}

export function readIndexerState(path: string): PersistedIndexerState {
  return JSON.parse(readFileSync(path, "utf8")) as PersistedIndexerState;
}

export function writeBaseSepoliaIndexerCheckpoint(path: string, checkpoint: BaseSepoliaIndexerCheckpoint): void {
  writeCanonicalJsonFile(path, checkpoint, true);
}

export function readBaseSepoliaIndexerCheckpoint(path: string): BaseSepoliaIndexerCheckpoint {
  return JSON.parse(readFileSync(path, "utf8")) as BaseSepoliaIndexerCheckpoint;
}

export function writeBaseCanaryIndexerCheckpoint(path: string, checkpoint: BaseCanaryIndexerCheckpoint): void {
  writeCanonicalJsonFile(path, checkpoint, true);
}

export function readBaseCanaryIndexerCheckpoint(path: string): BaseCanaryIndexerCheckpoint {
  return JSON.parse(readFileSync(path, "utf8")) as BaseCanaryIndexerCheckpoint;
}
