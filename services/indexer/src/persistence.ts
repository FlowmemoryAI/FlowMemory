import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

import { canonicalJson } from "../../shared/src/index.ts";
import type { IndexerState } from "./indexer.ts";

export interface PersistedIndexerState {
  schema: "flowmemory.indexer.persistence.v0";
  state: IndexerState;
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
  generatedAt: string;
}

export function persistedIndexerState(state: IndexerState): PersistedIndexerState {
  return {
    schema: "flowmemory.indexer.persistence.v0",
    state,
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
  const lastIndexedBlock = input.state.cursors.reduce((latest, cursor) => {
    return BigInt(cursor.blockNumber) > BigInt(latest) ? cursor.blockNumber : latest;
  }, input.fromBlock);

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
    generatedAt: input.generatedAt ?? new Date().toISOString(),
  };
}

export function writeIndexerState(path: string, state: IndexerState): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${canonicalJson(persistedIndexerState(state))}\n`, "utf8");
}

export function readIndexerState(path: string): PersistedIndexerState {
  return JSON.parse(readFileSync(path, "utf8")) as PersistedIndexerState;
}

export function writeBaseSepoliaIndexerCheckpoint(path: string, checkpoint: BaseSepoliaIndexerCheckpoint): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${canonicalJson(checkpoint)}\n`, "utf8");
}

export function readBaseSepoliaIndexerCheckpoint(path: string): BaseSepoliaIndexerCheckpoint {
  return JSON.parse(readFileSync(path, "utf8")) as BaseSepoliaIndexerCheckpoint;
}
