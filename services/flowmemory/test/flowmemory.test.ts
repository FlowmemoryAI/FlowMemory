import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
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
  FLOW_MEMORY_STATUSES,
  verifierStatusToFlowMemoryStatus,
} from "../src/status.ts";

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
    assert.equal(launchCore.memorySignals.length, 7);
    assert.equal(launchCore.memoryReceipts.length, 7);
    assert.equal(launchCore.rootflowTransitions.length, 6);
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
