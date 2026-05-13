import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

import { canonicalJson } from "../../shared/src/index.ts";
import type { VerifierReport } from "./verifier.ts";

export interface PersistedVerifierReports {
  schema: "flowmemory.verifier.persistence.v0";
  reports: VerifierReport[];
}

export function persistedVerifierReports(reports: VerifierReport[]): PersistedVerifierReports {
  return {
    schema: "flowmemory.verifier.persistence.v0",
    reports,
  };
}

export function writeVerifierReports(path: string, reports: VerifierReport[]): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${canonicalJson(persistedVerifierReports(reports))}\n`, "utf8");
}

export function readVerifierReports(path: string): PersistedVerifierReports {
  return JSON.parse(readFileSync(path, "utf8")) as PersistedVerifierReports;
}
