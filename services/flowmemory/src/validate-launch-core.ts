import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import Ajv2020, { type ValidateFunction } from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

import type { LaunchCoreOutput } from "./types.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");

const schemaFiles = {
  memorySignals: "schemas/flowmemory/memory-signal.schema.json",
  memoryReceipts: "schemas/flowmemory/memory-receipt.schema.json",
  rootflowTransitions: "schemas/flowmemory/rootflow-transition.schema.json",
  rootfieldBundles: "schemas/flowmemory/rootfield-bundle.schema.json",
  agentMemoryViews: "schemas/flowmemory/agent-memory-view.schema.json",
} as const;

type LaunchCollectionName = keyof typeof schemaFiles;

function readJson<T>(path: string): T {
  return JSON.parse(readFileSync(resolve(REPO_ROOT, path), "utf8")) as T;
}

function compileValidators(): Record<LaunchCollectionName, ValidateFunction> {
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats(ajv);

  return Object.fromEntries(
    Object.entries(schemaFiles).map(([name, path]) => [name, ajv.compile(readJson(path))]),
  ) as Record<LaunchCollectionName, ValidateFunction>;
}

function validateCollection(
  validators: Record<LaunchCollectionName, ValidateFunction>,
  launchCore: LaunchCoreOutput,
): string[] {
  const failures: string[] = [];
  const collections: Record<LaunchCollectionName, unknown[]> = {
    memorySignals: launchCore.memorySignals,
    memoryReceipts: launchCore.memoryReceipts,
    rootflowTransitions: launchCore.rootflowTransitions,
    rootfieldBundles: launchCore.rootfieldBundles,
    agentMemoryViews: launchCore.agentMemoryViews,
  };

  for (const [name, records] of Object.entries(collections) as Array<[LaunchCollectionName, unknown[]]>) {
    const validate = validators[name];
    records.forEach((record, index) => {
      if (!validate(record)) {
        failures.push(`${name}[${index}] ${ajvErrorText(validate)}`);
      }
    });
  }

  return failures;
}

function ajvErrorText(validate: ValidateFunction): string {
  return (validate.errors ?? [])
    .map((error) => `${error.instancePath || "/"} ${error.message ?? "failed validation"}`)
    .join("; ");
}

function assertLaunchCandidateInvariants(launchCore: LaunchCoreOutput): string[] {
  const failures: string[] = [];
  const signalIds = new Set(launchCore.memorySignals.map((signal) => signal.signalId));
  const receiptIds = new Set(launchCore.memoryReceipts.map((receipt) => receipt.receiptId));
  const reportIds = new Set(launchCore.memoryReceipts.map((receipt) => receipt.reportId));

  if (!launchCore.memorySignals.some((signal) => signal.signalType === "swap_memory_signal")) {
    failures.push("launch core must include at least one swap_memory_signal");
  }

  for (const signal of launchCore.memorySignals) {
    if (!signal.contractEvent.topicMatchesContract) {
      failures.push(`signal ${signal.signalId} has a non-matching FlowPulse topic0`);
    }
  }

  for (const transition of launchCore.rootflowTransitions) {
    if (!signalIds.has(transition.memorySignalId)) {
      failures.push(`transition ${transition.transitionId} references missing signal ${transition.memorySignalId}`);
    }
    if (transition.contractEventRef.signalId !== transition.memorySignalId) {
      failures.push(`transition ${transition.transitionId} contractEventRef does not match memorySignalId`);
    }
    if (transition.memoryReceiptId !== null && !receiptIds.has(transition.memoryReceiptId)) {
      failures.push(`transition ${transition.transitionId} references missing receipt ${transition.memoryReceiptId}`);
    }
    if (transition.reportId !== null && !reportIds.has(transition.reportId)) {
      failures.push(`transition ${transition.transitionId} references missing report ${transition.reportId}`);
    }
  }

  for (const receipt of launchCore.memoryReceipts) {
    if (!launchCore.memorySignals.some((signal) => signal.observationId === receipt.observationId)) {
      failures.push(`receipt ${receipt.receiptId} references missing observation ${receipt.observationId}`);
    }
  }

  const transitionIds = new Set(launchCore.rootflowTransitions.map((transition) => transition.transitionId));
  for (const view of launchCore.agentMemoryViews) {
    for (const signalId of view.signalIds) {
      if (!signalIds.has(signalId)) {
        failures.push(`agent view ${view.viewId} references missing signal ${signalId}`);
      }
    }
    for (const receiptId of view.receiptIds) {
      if (!receiptIds.has(receiptId)) {
        failures.push(`agent view ${view.viewId} references missing receipt ${receiptId}`);
      }
    }
    for (const transitionId of view.transitionIds) {
      if (!transitionIds.has(transitionId)) {
        failures.push(`agent view ${view.viewId} references missing transition ${transitionId}`);
      }
    }
  }

  return failures;
}

export function validateLaunchCore(path = "fixtures/launch-core/flowmemory-launch-v0.json"): void {
  const launchCore = readJson<LaunchCoreOutput>(path);
  const failures = [
    ...validateCollection(compileValidators(), launchCore),
    ...assertLaunchCandidateInvariants(launchCore),
  ];

  if (failures.length > 0) {
    throw new Error(`FlowMemory launch-core validation failed:\n${failures.map((failure) => `- ${failure}`).join("\n")}`);
  }

  console.log(JSON.stringify({
    service: "flowmemory-launch-core-validator",
    path,
    memorySignals: launchCore.memorySignals.length,
    memoryReceipts: launchCore.memoryReceipts.length,
    rootflowTransitions: launchCore.rootflowTransitions.length,
    rootfieldBundles: launchCore.rootfieldBundles.length,
    agentMemoryViews: launchCore.agentMemoryViews.length,
    swapMemorySignals: launchCore.memorySignals.filter((signal) => signal.signalType === "swap_memory_signal").length,
  }, null, 2));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  validateLaunchCore(process.argv[2]);
}
