import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { cargoDisplayCommand, spawnCargoSync } from "./cargo.ts";
import { repoRoot } from "./fixture-state.ts";
import type { ControlPlanePaths, JsonObject, JsonValue } from "./types.ts";

export interface RuntimeSubmission {
  schema: "flowmemory.control_plane.transaction_submission.v0";
  txs: JsonObject[];
  intakePath: string;
  runtimeStatePath: string;
  queued: string[];
  runtime: {
    command: string;
    status: number | null;
    stderr: string;
  };
  localOnly: true;
}

function asObject(value: JsonValue | undefined, label: string): JsonObject {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object`);
  }
  return value as JsonObject;
}

function txFromSignedEnvelope(value: JsonObject): JsonObject {
  const tx = value.tx ?? value.transaction;
  if (tx === null || typeof tx !== "object" || Array.isArray(tx)) {
    throw new Error("signed transaction envelope must contain tx or transaction object");
  }
  return tx as JsonObject;
}

export function extractSubmittedTransactions(params: JsonObject): JsonObject[] {
  if (Array.isArray(params.txs)) {
    return params.txs.map((entry, index) => asObject(entry, `txs[${index}]`));
  }

  if (params.tx !== undefined) {
    return [asObject(params.tx, "tx")];
  }

  if (Array.isArray(params.signedTransactions)) {
    return params.signedTransactions.map((entry, index) => txFromSignedEnvelope(asObject(entry, `signedTransactions[${index}]`)));
  }

  if (params.signedTransaction !== undefined) {
    return [txFromSignedEnvelope(asObject(params.signedTransaction, "signedTransaction"))];
  }

  throw new Error("transaction_submit requires tx, txs, signedTransaction, or signedTransactions");
}

function resolveRepoPath(path: string): string {
  return resolve(repoRoot(), path);
}

export function submitTransactionsToRuntime(paths: ControlPlanePaths, txs: JsonObject[]): RuntimeSubmission {
  const intakeDir = resolveRepoPath(paths.runtimeIntakeDir);
  mkdirSync(intakeDir, { recursive: true });

  const fixture = {
    schema: "flowmemory.control_plane.transaction_intake_fixture.v0",
    txs,
  };
  const intakePath = resolve(intakeDir, `${Date.now()}-${process.pid}.json`);
  writeFileSync(intakePath, `${JSON.stringify(fixture, null, 2)}\n`);

  const runtimeStatePath = resolveRepoPath(paths.runtimeStatePath);
  mkdirSync(dirname(runtimeStatePath), { recursive: true });

  const args = [
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    runtimeStatePath,
    "submit-fixture",
    "--fixture",
    intakePath,
  ];
  const result = spawnCargoSync(args, {
    cwd: repoRoot(),
    encoding: "utf8",
  });

  if (result.error !== undefined) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`runtime transaction intake failed: ${result.stderr || result.stdout}`);
  }

  const stdout = JSON.parse(result.stdout) as { queued?: unknown };
  const queued = Array.isArray(stdout.queued) ? stdout.queued.map(String) : [];
  return {
    schema: "flowmemory.control_plane.transaction_submission.v0",
    txs,
    intakePath,
    runtimeStatePath,
    queued,
    runtime: {
      command: cargoDisplayCommand(args),
      status: result.status,
      stderr: result.stderr,
    },
    localOnly: true,
  };
}
