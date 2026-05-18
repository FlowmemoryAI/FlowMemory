import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import {
  DEFAULT_LAUNCH_CORE_PATHS,
  generateLaunchCore,
  type DashboardData,
} from "../src/generate-launch-core.ts";
import {
  DEFAULT_CANARY_DASHBOARD_PATHS,
  generateCanaryDashboard,
} from "../src/generate-canary-dashboard.ts";
import {
  DEFAULT_BASE_SEPOLIA_HOOK_DASHBOARD_PATHS,
  generateBaseSepoliaHookDashboard,
} from "../src/generate-base-sepolia-hook-dashboard.ts";
import {
  FLOW_MEMORY_STATUSES,
  verifierStatusToFlowMemoryStatus,
} from "../src/status.ts";
import { runSwapMemoryStress } from "../src/swap-stress.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
process.chdir(REPO_ROOT);

test("maps verifier statuses to Flow Memory launch vocabulary", () => {
  assert.equal(verifierStatusToFlowMemoryStatus("valid"), "verified");
  assert.equal(verifierStatusToFlowMemoryStatus("invalid"), "failed");
  assert.equal(verifierStatusToFlowMemoryStatus("unresolved"), "unresolved");
  assert.equal(verifierStatusToFlowMemoryStatus("unsupported"), "unsupported");
  assert.equal(verifierStatusToFlowMemoryStatus("reorged"), "reorged");
  assert.throws(() => verifierStatusToFlowMemoryStatus("mystery"));
});

test("published schemas exist for every launch-core object", () => {
  const schemas = [
    ["schemas/flowmemory/memory-signal.schema.json", "flowmemory.memory_signal.v0"],
    ["schemas/flowmemory/memory-receipt.schema.json", "flowmemory.memory_receipt.v0"],
    ["schemas/flowmemory/rootflow-transition.schema.json", "flowmemory.rootflow_transition.v0"],
    ["schemas/flowmemory/rootfield-bundle.schema.json", "flowmemory.rootfield_bundle.v0"],
    ["schemas/flowmemory/agent-memory-view.schema.json", "flowmemory.agent_memory_view.v0"],
  ];

  for (const [path, id] of schemas) {
    const schema = JSON.parse(readFileSync(path, "utf8")) as { $id: string; required: string[] };
    assert.equal(schema.$id, id);
    assert.ok(schema.required.length > 0);
  }
});

test("generates concrete Rootflow and Flow Memory V0 outputs", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-launch-core-"));
  const paths = {
    ...DEFAULT_LAUNCH_CORE_PATHS,
    launchOutPath: join(dir, "flowmemory-launch-v0.json"),
    transitionsOutPath: join(dir, "rootflow-transitions.json"),
    dashboardOutPath: join(dir, "flowmemory-dashboard-v0.json"),
    dashboardRuntimePath: join(dir, "runtime-flowmemory-dashboard-v0.json"),
  };
  try {
    const { launchCore, dashboard } = generateLaunchCore(paths);

    assert.equal(launchCore.schema, "flowmemory.launch_core.v0");
    assert.equal(launchCore.statusAdapter.valid, "verified");
    assert.equal(launchCore.statusAdapter.invalid, "failed");
    assert.equal(launchCore.memorySignals.length, 8);
    assert.equal(launchCore.memoryReceipts.length, 8);
    assert.equal(launchCore.rootflowTransitions.length, 7);
    assert.equal(launchCore.rootfieldBundles.length, 1);
    assert.equal(launchCore.agentMemoryViews.length, 1);

    const firstSignal = launchCore.memorySignals[0];
    assert.equal(firstSignal.contractEvent.interfaceName, "IFlowPulse");
    assert.equal(firstSignal.contractEvent.eventName, "FlowPulse");
    assert.equal(firstSignal.contractEvent.indexed.pulseId, firstSignal.pulseId);
    assert.equal(firstSignal.contractEvent.indexed.rootfieldId, firstSignal.rootfieldId);
    assert.equal(firstSignal.contractEvent.payload.commitment, firstSignal.commitment);
    assert.equal(firstSignal.contractEvent.receiptLocator.txHash, firstSignal.txHash);
    assert.equal(firstSignal.contractEvent.topicMatchesContract, true);

    const unsupportedSignal = launchCore.memorySignals.find((signal) => signal.contractEvent.pulseTypeId === "99");
    assert.equal(unsupportedSignal?.contractEvent.pulseTypeName, "UNKNOWN_FLOWPULSE_TYPE");
    const swapSignal = launchCore.memorySignals.find((signal) => signal.signalType === "swap_memory_signal");
    assert.equal(swapSignal?.contractEvent.pulseTypeName, "SWAP_MEMORY_SIGNAL");

    const firstTransition = launchCore.rootflowTransitions[0];
    assert.equal(firstTransition.contractEventRef.signalId, firstTransition.memorySignalId);
    assert.equal(firstTransition.contractEventRef.eventName, "FlowPulse");
    assert.equal(firstTransition.contractEventRef.txHash, firstTransition.txHash);

    const transitionStatuses = new Set(launchCore.rootflowTransitions.map((transition) => transition.status));
    assert.ok(transitionStatuses.has("verified"));
    assert.ok(transitionStatuses.has("failed"));
    assert.ok(transitionStatuses.has("unresolved"));
    assert.ok(transitionStatuses.has("unsupported"));
    assert.ok(transitionStatuses.has("reorged"));

    assertDashboardCoversStatuses(dashboard);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("generates Base canary dashboard output from committed deployment artifacts", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-canary-dashboard-"));
  const paths = {
    ...DEFAULT_CANARY_DASHBOARD_PATHS,
    dashboardOutPath: join(dir, "flowmemory-dashboard-base-canary-v0.json"),
    dashboardRuntimePath: join(dir, "runtime-flowmemory-dashboard-base-canary-v0.json"),
  };

  try {
    const dashboard = generateCanaryDashboard(paths);

    assert.equal(dashboard.metadata.schema, "flowmemory.dashboard.fixture.v0");
    assert.equal(dashboard.metadata.mode, "canary");
    assert.equal(dashboard.chain.chainId, "8453");
    assert.equal(dashboard.chain.source, "live");
    assert.equal(dashboard.flowPulseObservations.length, 4);
    assert.equal(dashboard.memorySignals.length, 4);
    assert.equal(dashboard.rootflowTransitions.length, 4);
    assert.equal(dashboard.verifierReports.length, 0);
    assert.equal(dashboard.alerts[0].severity, "info");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("refuses incomplete Base Sepolia v4 hook Flow Memory evidence by default", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-sepolia-hook-incomplete-"));
  const paths = writeBaseSepoliaHookFixtureSet(dir, { complete: false, observations: 0 });

  try {
    assert.throws(
      () => generateBaseSepoliaHookDashboard(paths),
      /Base Sepolia v4 hook Flow Memory evidence is incomplete/,
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("generates diagnostic Base Sepolia hook dashboard output when incomplete evidence is allowed", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-sepolia-hook-diagnostic-"));
  const paths = writeBaseSepoliaHookFixtureSet(dir, { complete: false, observations: 0 });

  try {
    const { flowMemory, dashboard } = generateBaseSepoliaHookDashboard(paths, { allowIncomplete: true });

    assert.equal(flowMemory.liveProofComplete, false);
    assert.equal(dashboard.metadata.mode, "base-sepolia-v4-hook-proof");
    assert.equal(dashboard.flowPulseObservations.length, 0);
    assert.equal(dashboard.memorySignals.length, 0);
    assert.equal(dashboard.alerts[0].severity, "warning");
    assert.equal(dashboard.chain.source, "diagnostic-empty-readback");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("generates Flow Memory and Rootflow evidence from a complete Base Sepolia hook readback", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-sepolia-hook-complete-"));
  const paths = writeBaseSepoliaHookFixtureSet(dir, { complete: true, observations: 1 });

  try {
    const { flowMemory, dashboard } = generateBaseSepoliaHookDashboard(paths);

    assert.equal(flowMemory.liveProofComplete, true);
    assert.equal(flowMemory.acceptance.livePoolManagerSwapObserved, true);
    assert.equal(flowMemory.memorySignals.length, 1);
    assert.equal(flowMemory.memoryReceipts.length, 1);
    assert.equal(flowMemory.rootflowTransitions.length, 1);
    assert.equal(dashboard.flowPulseObservations.length, 1);
    assert.equal(dashboard.memorySignals[0].signalType, "swap_memory_signal");
    assert.equal(dashboard.memorySignals[0].contractEvent.receiptLocator.txHash, SAMPLE_TX_HASH);
    assert.equal(dashboard.memorySignals[0].contractEvent.receiptLocator.logIndex, "4");
    assert.equal(dashboard.rootflowTransitions[0].status, "verified");
    assert.equal(dashboard.rootflowTransitions[0].nextRoot, SAMPLE_COMMITMENT);
    assert.equal(dashboard.alerts[0].severity, "info");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("rejects complete Base Sepolia hook evidence without a swap memory signal", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-sepolia-hook-no-swap-"));
  const paths = writeBaseSepoliaHookFixtureSet(dir, {
    complete: true,
    observations: 1,
    observationOverrides: { pulseType: "2" },
  });

  try {
    assert.throws(
      () => generateBaseSepoliaHookDashboard(paths),
      /requires at least one unique successful SWAP_MEMORY_SIGNAL observation/,
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("rejects Base Sepolia hook readback observations that are not FlowPulse events", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-sepolia-hook-bad-topic-"));
  const paths = writeBaseSepoliaHookFixtureSet(dir, {
    complete: true,
    observations: 1,
    observationOverrides: {
      eventSignature: "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    },
  });

  try {
    assert.throws(
      () => generateBaseSepoliaHookDashboard(paths),
      /is not an IFlowPulse\.FlowPulse event/,
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("rejects Base Sepolia hook evidence when readback counts disagree", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-base-sepolia-hook-count-mismatch-"));
  const paths = writeBaseSepoliaHookFixtureSet(dir, { complete: true, observations: 1 });
  const evidence = JSON.parse(readFileSync(paths.evidencePath, "utf8")) as {
    evidence: { readbackObservationCount: number };
  };
  evidence.evidence.readbackObservationCount = 2;
  writeJson(paths.evidencePath, evidence);

  try {
    assert.throws(
      () => generateBaseSepoliaHookDashboard(paths),
      /evidence readback observation count mismatch/,
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("stress-tests swap-derived memory signal data path", () => {
  const result = runSwapMemoryStress({
    swaps: 256,
    duplicateEvery: 64,
    reorgEvery: 97,
    invalidEvery: 53,
    unresolvedEvery: 71,
    malformedLogs: 2,
    outPath: "unused-test-output.json",
  });

  assert.equal(result.inputs.generatedLogs, 263);
  assert.equal(result.indexer.observations, 261);
  assert.equal(result.indexer.rejectedLogs, 2);
  assert.equal(result.indexer.duplicates, 5);
  assert.equal(result.verifier.reports, result.indexer.observations);
  assert.equal(result.flowMemory.memorySignals, result.indexer.observations);
  assert.equal(result.flowMemory.swapMemorySignals, result.flowMemory.memorySignals);
  assert.equal(result.verifier.statuses.invalid, result.inputs.intentionallyInvalidLogs);
  assert.equal(result.verifier.statuses.unresolved, result.inputs.intentionallyUnresolvedLogs);
  assert.equal(result.invariants.oneReportPerObservation, true);
  assert.equal(result.invariants.oneSignalPerObservation, true);
  assert.equal(result.invariants.allSignalsAreSwapMemorySignals, true);
  assert.equal(result.invariants.malformedLogsRejected, true);
  assert.equal(result.invariants.duplicateLogsDetected, true);
});

function assertDashboardCoversStatuses(dashboard: DashboardData): void {
  const records = [
    ...dashboard.flowPulseObservations,
    ...dashboard.rootfields,
    ...dashboard.workLanes,
    ...dashboard.workReceipts,
    ...dashboard.verifierReports,
    ...dashboard.rootflowTransitions,
    ...dashboard.memorySignals,
    ...dashboard.memoryReceipts,
    ...dashboard.rootfieldBundles,
    ...dashboard.agentMemoryViews,
    ...dashboard.devnetBlocks,
    ...dashboard.hardwareNodes,
    ...dashboard.alerts,
  ] as Array<{ status?: string }>;
  const statuses = new Set(records.map((record) => record.status));

  for (const status of FLOW_MEMORY_STATUSES) {
    assert.ok(statuses.has(status), `${status} should appear in generated dashboard fixture`);
  }
}

const SAMPLE_HOOK_ADDRESS = "0xD24d7f807cb00D28DdF675E55879547d4F7B0040";
const SAMPLE_HOOK_SALT = "0x0000000000000000000000000000000000000000000000004915000000000000";
const SAMPLE_EVENT_TOPIC = "0x5d07190b9ae441b4d7b16259a48424acd451492b12f5f99a29f5bfd992c13e43";
const SAMPLE_TX_HASH = "0x4444444444444444444444444444444444444444444444444444444444444444";
const SAMPLE_ROOTFIELD = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const SAMPLE_COMMITMENT = "0x8fabbad2f4aae2b67e5dcacc7cd425b7860d4d4453488c6c9770196b5009d795";

function writeBaseSepoliaHookFixtureSet(
  dir: string,
  options: { complete: boolean; observations: number; observationOverrides?: Record<string, string> },
): typeof DEFAULT_BASE_SEPOLIA_HOOK_DASHBOARD_PATHS {
  mkdirSync(dir, { recursive: true });
  const paths = {
    planPath: join(dir, "plan.json"),
    evidencePath: join(dir, "evidence.json"),
    readbackArtifactPath: join(dir, "readback.json"),
    indexerPath: join(dir, "indexer.json"),
    checkpointPath: join(dir, "checkpoint.json"),
    flowMemoryOutPath: join(dir, "flowmemory.json"),
    dashboardOutPath: join(dir, "dashboard.json"),
    dashboardRuntimePath: join(dir, "runtime-dashboard.json"),
  };
  const generatedAt = "2026-05-17T12:00:00.000Z";
  const hook = {
    contract: "FlowMemoryAfterSwapHook",
    create2Deployer: "0x4e59b44847b379578588920cA78FbF26c0B4956C",
    constructorArgs: {
      poolManager: "0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408",
    },
    initCodeHash: "0x2734b4f6b4f6932249d4d98240147f02cf2ba548fe1ade4a7d63d9dd0a8b9fef",
    salt: SAMPLE_HOOK_SALT,
    hookAddress: SAMPLE_HOOK_ADDRESS,
    miningMode: "mined-after-swap-suffix-0040",
    requiredLowBits: "0x0040",
    hasAfterSwapOnlyFlag: true,
    permissions: {
      afterSwap: true,
      beforeSwap: false,
      afterSwapReturnDelta: false,
      dynamicFeeOverride: false,
      custody: false,
    },
  };
  const observations = options.observations > 0 ? [sampleBaseSepoliaObservation(options.observationOverrides)] : [];
  const rootfields = observations.length > 0
    ? [{
      rootfieldId: SAMPLE_ROOTFIELD,
      firstObservationId: observations[0].observationId,
      latestObservationId: observations[0].observationId,
      pulseCount: observations.length,
    }]
    : [];

  writeJson(paths.planPath, {
    schema: "flowmemory.base_sepolia.v4_hook_proof_plan.v0",
    generatedAt,
    productionReady: false,
    network: {
      name: "Base Sepolia",
      chainId: "84532",
      explorer: "https://sepolia.basescan.org",
    },
    uniswapV4: {},
    hook,
    commands: {},
    proofSequence: [],
    boundaries: ["Base Sepolia proof is public testnet evidence, not production mainnet readiness."],
  });
  writeJson(paths.evidencePath, {
    schema: "flowmemory.base_sepolia.v4_hook_evidence.v0",
    generatedAt,
    productionReady: false,
    liveProofComplete: options.complete,
    stage: options.complete ? "live-proof-complete" : "dry-run-proof-ready",
    hook,
    evidence: {
      officialContractsCodePresent: true,
      plannedHookCodePresent: options.complete,
      envBroadcastReady: options.complete,
      dryRunProofReady: true,
      broadcastProofReady: options.complete,
      readbackProofReady: options.complete,
      readbackObservationCount: observations.length,
      readbackProofComplete: options.complete,
      dryRunTransactionCount: 12,
      broadcastReceiptCount: options.complete ? 12 : 0,
    },
    missing: options.complete ? [] : ["broadcast swap-proof artifact with receipts"],
    nextSteps: options.complete ? [] : ["Broadcast and read back the real Base Sepolia swap."],
    boundaries: ["A deployed hook alone is not enough; a PoolManager swap readback is required."],
  });
  writeJson(paths.readbackArtifactPath, {
    schema: "flowmemory.base_sepolia.v4_hook_readback_artifact.v0",
    generatedAt,
    productionReady: false,
    proofComplete: options.complete,
    hook,
    indexer: {
      observationCount: observations.length,
      rejectedLogCount: 0,
      duplicateCount: 0,
      dashboardCanonicalObservationCount: observations.length,
      fromBlock: "500",
      toBlock: "501",
      finalizedBlock: "501",
      emptyRange: observations.length === 0,
      hasIntegrityWarnings: false,
    },
    boundaries: ["txHash and logIndex are read by the indexer after receipts/logs exist."],
  });
  writeJson(paths.indexerPath, {
    schema: "flowmemory.indexer.persistence.v0",
    state: {
      source: "base-sepolia-rpc",
      observations,
      rootfields,
      rejectedLogs: [],
      duplicates: [],
      dashboardFeed: {
        hasIntegrityWarnings: false,
        warningCodes: [],
        dashboardCanonicalObservationCount: observations.length,
      },
    },
  });
  writeJson(paths.checkpointPath, {
    schema: "flowmemory.indexer.base_sepolia_checkpoint.v0",
    network: "base-sepolia",
    chainId: "84532",
    addresses: [SAMPLE_HOOK_ADDRESS.toLowerCase()],
    fromBlock: "500",
    toBlock: "501",
    observationCount: observations.length,
    rejectedLogCount: 0,
    duplicateCount: 0,
    emptyRange: observations.length === 0,
    generatedAt,
    highestObservedBlock: observations.length > 0 ? "501" : null,
    lastIndexedBlock: "501",
    nextFromBlock: "502",
    finalizedBlockNumber: "501",
    dashboardFeed: {
      hasIntegrityWarnings: false,
    },
    safety: {
      networkBoundary: "base-sepolia-testnet-only",
      productionReady: false,
      storesPrivateKeys: false,
      storesRpcUrl: false,
    },
  });

  return paths;
}

function sampleBaseSepoliaObservation(overrides: Record<string, string> = {}): Record<string, string> {
  return {
    observationId: "0x9999999999999999999999999999999999999999999999999999999999999999",
    cursorId: "0x8888888888888888888888888888888888888888888888888888888888888888",
    lifecycleState: "finalized",
    duplicateKind: "unique",
    chainId: "84532",
    emittingContract: SAMPLE_HOOK_ADDRESS,
    eventSignature: SAMPLE_EVENT_TOPIC,
    blockNumber: "501",
    blockHash: "0x7777777777777777777777777777777777777777777777777777777777777777",
    txHash: SAMPLE_TX_HASH,
    transactionIndex: "2",
    logIndex: "4",
    receiptStatus: "success",
    pulseId: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    rootfieldId: SAMPLE_ROOTFIELD,
    actor: "0x5555555555555555555555555555555555555555",
    pulseType: "4",
    subject: "0x1212121212121212121212121212121212121212121212121212121212121212",
    commitment: SAMPLE_COMMITMENT,
    parentPulseId: "0x0000000000000000000000000000000000000000000000000000000000000000",
    sequence: "1",
    occurredAt: "1779000000",
    uri: "base-sepolia://flowmemory/v4-hook-proof",
    ...overrides,
  };
}

function writeJson(path: string, value: unknown): void {
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}
