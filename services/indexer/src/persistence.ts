import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

import { canonicalJson } from "../../shared/src/index.ts";
import type { IndexerState } from "./indexer.ts";

export interface PersistedIndexerState {
  schema: "flowmemory.indexer.persistence.v0";
  state: IndexerState;
}

export function persistedIndexerState(state: IndexerState): PersistedIndexerState {
  return {
    schema: "flowmemory.indexer.persistence.v0",
    state,
  };
}

export function writeIndexerState(path: string, state: IndexerState): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${canonicalJson(persistedIndexerState(state))}\n`, "utf8");
}

export function readIndexerState(path: string): PersistedIndexerState {
  return JSON.parse(readFileSync(path, "utf8")) as PersistedIndexerState;
}
