import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  encodeAddress,
  encodeBytes32,
  encodeStringTail,
  encodeUint256,
  FLOWPULSE_EVENT_TOPIC0,
  keccak256Hex,
  type RawFlowPulseLogFixture,
} from "../../shared/src/index.ts";
import { indexFlowPulseLogs } from "../../indexer/src/indexer.ts";
import {
  swapMemorySignalCommitment,
  verifyObservations,
  type ArtifactResolverFixture,
  type SwapMemorySignalArtifact,
} from "../../verifier/src/verifier.ts";
import { buildLaunchCore, DEFAULT_LAUNCH_CORE_PATHS, type LaunchCorePaths } from "./generate-launch-core.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const DEFAULT_OUT = "fixtures/launch-core/swap-memory-stress-report.json";
const ROOTFIELD_ID = hashBytes32("flowmemory.stress.rootfield");
const CONTRACT_ADDRESS = "0x179df6d52e9def5d02704583a2e4e5a9ff427245";
const ACTOR_ADDRESS = "0x3a6fba5a78216ba3a8da8d8f501dee2c8186aff9";
const ZERO_BYTES32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

interface StressOptions {
  swaps: number;
  duplicateEvery: number;
  reorgEvery: number;
  invalidEvery: number;
  unresolvedEvery: number;
  malformedLogs: number;
  outPath: string;
}

interface StressRunResult {
  schema: "flowmemory.swap_memory_stress_report.v0";
  generatedAt: string;
  options: StressOptions;
  inputs: {
    generatedLogs: number;
    validSwapCandidates: number;
    exactDuplicateLogs: number;
    reorgReplacementLogs: number;
    intentionallyInvalidLogs: number;
    intentionallyUnresolvedLogs: number;
    malformedLogs: number;
  };
  indexer: {
    observations: number;
    dashboardCanonicalObservations: number;
    cursors: number;
    rejectedLogs: number;
    duplicates: number;
    duplicateKindCounts: Record<string, number>;
    warningCodes: string[];
  };
  verifier: {
    reports: number;
    statuses: Record<string, number>;
    reasonCodeCounts: Record<string, number>;
  };
  flowMemory: {
    memorySignals: number;
    swapMemorySignals: number;
    memoryReceipts: number;
    rootflowTransitions: number;
    rootfieldBundles: number;
    agentMemoryViews: number;
    statuses: Record<string, number>;
  };
  invariants: Record<string, boolean>;
  boundaries: string[];
}

function concatBytes(parts: Uint8Array[]): Uint8Array {
  const output = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

function hashBytes32(value: string): `0x${string}` {
  return keccak256Hex(new TextEncoder().encode(value));
}

function flowPulseData(input: {
  pulseType: number;
  subject: string;
  commitment: string;
  parentPulseId: string;
  sequence: number;
  occurredAt: number;
  uri: string;
}): `0x${string}` {
  const head = concatBytes([
    encodeUint256(input.pulseType),
    encodeBytes32(input.subject),
    encodeBytes32(input.commitment),
    encodeBytes32(input.parentPulseId),
    encodeUint256(input.sequence),
    encodeUint256(input.occurredAt),
    encodeUint256(7 * 32),
  ]);
  return `0x${Buffer.from(concatBytes([head, encodeStringTail(input.uri)])).toString("hex")}`;
}

function topicAddress(address: string): `0x${string}` {
  return `0x${Buffer.from(encodeAddress(address)).toString("hex")}`;
}

function countBy<T extends string>(values: T[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const value of values) {
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return counts;
}

function buildSwapLog(index: number, overrides: Partial<RawFlowPulseLogFixture> = {}): {
  artifact?: SwapMemorySignalArtifact;
  log: RawFlowPulseLogFixture;
  uri: string;
  validCandidate: boolean;
} {
  const sequence = index + 1;
  const poolId = hashBytes32(`flowmemory.stress.pool.${index % 8}`);
  const hookDataHash = hashBytes32(`flowmemory.stress.hook_data.${index}`);
  const memoryRoot = hashBytes32(`flowmemory.stress.memory_root.${index}`);
  const artifact: SwapMemorySignalArtifact = {
    kind: "swap-memory-signal",
    poolId,
    hookDataHash,
    memoryRoot,
  };
  const uri = `fixture://stress/swap/${index}`;
  const commitment = swapMemorySignalCommitment(artifact);
  const pulseId = hashBytes32(`flowmemory.stress.pulse.${index}`);
  const blockNumber = 9_000_000 + index;
  const transactionIndex = index % 4;
  const logIndex = index % 12;

  const log: RawFlowPulseLogFixture = {
    chainId: "8453",
    address: CONTRACT_ADDRESS,
    topics: [
      FLOWPULSE_EVENT_TOPIC0,
      pulseId,
      ROOTFIELD_ID,
      topicAddress(ACTOR_ADDRESS),
    ],
    data: flowPulseData({
      pulseType: 4,
      subject: poolId,
      commitment,
      parentPulseId: index === 0 ? ZERO_BYTES32 : hashBytes32(`flowmemory.stress.pulse.${index - 1}`),
      sequence,
      occurredAt: 1_778_000_000 + index * 2,
      uri,
    }),
    blockNumber: blockNumber.toString(),
    blockHash: hashBytes32(`flowmemory.stress.block.${blockNumber}`),
    transactionHash: hashBytes32(`flowmemory.stress.tx.${index}`),
    transactionIndex: transactionIndex.toString(),
    logIndex: logIndex.toString(),
    receiptStatus: "success",
    ...overrides,
  };

  return { artifact, log, uri, validCandidate: true };
}

function parseArgs(argv: string[]): StressOptions {
  const options: StressOptions = {
    swaps: 1024,
    duplicateEvery: 128,
    reorgEvery: 257,
    invalidEvery: 211,
    unresolvedEvery: 307,
    malformedLogs: 3,
    outPath: DEFAULT_OUT,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const value = argv[index + 1];
    if (arg === "--swaps" && value !== undefined) {
      options.swaps = Number(value);
      index += 1;
    } else if (arg === "--duplicate-every" && value !== undefined) {
      options.duplicateEvery = Number(value);
      index += 1;
    } else if (arg === "--reorg-every" && value !== undefined) {
      options.reorgEvery = Number(value);
      index += 1;
    } else if (arg === "--invalid-every" && value !== undefined) {
      options.invalidEvery = Number(value);
      index += 1;
    } else if (arg === "--unresolved-every" && value !== undefined) {
      options.unresolvedEvery = Number(value);
      index += 1;
    } else if (arg === "--malformed-logs" && value !== undefined) {
      options.malformedLogs = Number(value);
      index += 1;
    } else if (arg === "--out" && value !== undefined) {
      options.outPath = value;
      index += 1;
    }
  }

  if (!Number.isInteger(options.swaps) || options.swaps <= 0) {
    throw new Error("--swaps must be a positive integer");
  }
  return options;
}

export function runSwapMemoryStress(options: StressOptions): StressRunResult {
  const logs: RawFlowPulseLogFixture[] = [];
  const resolver: ArtifactResolverFixture = {
    resolverPolicyId: "flowmemory.resolver.policy.v0.swap_stress",
    artifactsByUri: {},
  };
  let exactDuplicateLogs = 0;
  let reorgReplacementLogs = 0;
  let intentionallyInvalidLogs = 0;
  let intentionallyUnresolvedLogs = 0;

  for (let index = 0; index < options.swaps; index += 1) {
    const built = buildSwapLog(index);
    let artifact = built.artifact;
    if (options.invalidEvery > 0 && index > 0 && index % options.invalidEvery === 0) {
      intentionallyInvalidLogs += 1;
      artifact = { ...artifact, poolId: hashBytes32(`flowmemory.stress.invalid_pool.${index}`) };
    }
    if (!(options.unresolvedEvery > 0 && index > 0 && index % options.unresolvedEvery === 0)) {
      resolver.artifactsByUri[built.uri] = artifact;
    } else {
      intentionallyUnresolvedLogs += 1;
    }
    logs.push(built.log);

    if (options.duplicateEvery > 0 && index > 0 && index % options.duplicateEvery === 0) {
      exactDuplicateLogs += 1;
      logs.push({ ...built.log });
    }

    if (options.reorgEvery > 0 && index > 0 && index % options.reorgEvery === 0) {
      reorgReplacementLogs += 1;
      logs.push({
        ...built.log,
        blockHash: hashBytes32(`flowmemory.stress.reorg_block.${index}`),
        transactionHash: hashBytes32(`flowmemory.stress.reorg_tx.${index}`),
        logIndex: (Number(built.log.logIndex) + 1).toString(),
      });
    }
  }

  for (let index = 0; index < options.malformedLogs; index += 1) {
    const malformed = buildSwapLog(options.swaps + index).log;
    logs.push({
      ...malformed,
      topics: [FLOWPULSE_EVENT_TOPIC0],
    });
  }

  const state = indexFlowPulseLogs(logs, {
    finalizedBlockNumber: (9_000_000 + options.swaps + 100).toString(),
    source: "fixture",
    sourceAddresses: [CONTRACT_ADDRESS],
  });
  const reports = verifyObservations(state.observations, resolver);
  const paths: LaunchCorePaths = {
    ...DEFAULT_LAUNCH_CORE_PATHS,
    indexerPath: "synthetic:swap-memory-stress/indexer",
    verifierPath: "synthetic:swap-memory-stress/verifier",
  };
  const { memorySignals, memoryReceipts, rootflowTransitions, rootfieldBundles, agentMemoryViews } =
    buildLaunchCore({ schema: "flowmemory.indexer.persistence.v0", state }, { schema: "flowmemory.verifier.persistence.v0", reports }, paths);

  const reportStatuses = countBy(reports.map((report) => report.reportCore.status));
  const reasonCodes = reports.flatMap((report) => report.reportCore.reasonCodes);
  const flowMemoryStatuses = countBy(rootflowTransitions.map((transition) => transition.status));
  const duplicateKindCounts = countBy(state.duplicates.map((duplicate) => duplicate.kind));

  const result: StressRunResult = {
    schema: "flowmemory.swap_memory_stress_report.v0",
    generatedAt: new Date().toISOString(),
    options,
    inputs: {
      generatedLogs: logs.length,
      validSwapCandidates: options.swaps - intentionallyInvalidLogs - intentionallyUnresolvedLogs,
      exactDuplicateLogs,
      reorgReplacementLogs,
      intentionallyInvalidLogs,
      intentionallyUnresolvedLogs,
      malformedLogs: options.malformedLogs,
    },
    indexer: {
      observations: state.observations.length,
      dashboardCanonicalObservations: state.dashboardFeed.dashboardCanonicalObservationCount,
      cursors: state.cursors.length,
      rejectedLogs: state.rejectedLogs.length,
      duplicates: state.duplicates.length,
      duplicateKindCounts,
      warningCodes: state.dashboardFeed.warningCodes,
    },
    verifier: {
      reports: reports.length,
      statuses: reportStatuses,
      reasonCodeCounts: countBy(reasonCodes),
    },
    flowMemory: {
      memorySignals: memorySignals.length,
      swapMemorySignals: memorySignals.filter((signal) => signal.signalType === "swap_memory_signal").length,
      memoryReceipts: memoryReceipts.length,
      rootflowTransitions: rootflowTransitions.length,
      rootfieldBundles: rootfieldBundles.length,
      agentMemoryViews: agentMemoryViews.length,
      statuses: flowMemoryStatuses,
    },
    invariants: {
      oneReportPerObservation: reports.length === state.observations.length,
      oneSignalPerObservation: memorySignals.length === state.observations.length,
      allSignalsAreSwapMemorySignals: memorySignals.every((signal) => signal.signalType === "swap_memory_signal"),
      malformedLogsRejected: state.rejectedLogs.length === options.malformedLogs,
      duplicateLogsDetected: state.duplicates.length === exactDuplicateLogs + reorgReplacementLogs,
      hasValidSignals: (reportStatuses.valid ?? 0) > 0,
      hasFailedSignals: (reportStatuses.invalid ?? 0) === intentionallyInvalidLogs,
      hasUnresolvedSignals: (reportStatuses.unresolved ?? 0) === intentionallyUnresolvedLogs,
    },
    boundaries: [
      "This is deterministic synthetic FlowPulse data, not live Uniswap swap traffic.",
      "The test exercises the FlowPulse/indexer/verifier/Flow Memory architecture at launch-like volume.",
      "txHash, transactionIndex, and logIndex are modeled as receipt-derived fields, not hook-known fields.",
      "Heavy memory artifacts stay out of the event payload; each swap carries compact commitments only.",
    ],
  };

  return result;
}

function writeReport(path: string, result: StressRunResult): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(result, null, 2)}\n`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.chdir(REPO_ROOT);
  const options = parseArgs(process.argv.slice(2));
  const result = runSwapMemoryStress(options);
  writeReport(options.outPath, result);
  console.log(JSON.stringify({
    service: "flowmemory-swap-memory-stress",
    outPath: resolve(options.outPath),
    inputs: result.inputs,
    indexer: result.indexer,
    verifier: result.verifier,
    flowMemory: result.flowMemory,
    invariants: result.invariants,
  }, null, 2));
}
