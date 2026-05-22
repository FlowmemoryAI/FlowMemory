import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { buildAgentBondFixture } from "../src/agent-bonds.ts";
import { buildTaskScoutFixture, replayTaskScoutFixture } from "../src/agent-memory.ts";
import { indexFlowPulseReceipts, loadIndexerFixtureReceipts, writeIndexerState } from "../../indexer/src/index.ts";
import {
  DEFAULT_LAUNCH_CORE_PATHS,
  generateLaunchCore,
  type DashboardData,
} from "../src/generate-launch-core.ts";
import {
  DEFAULT_CANARY_DASHBOARD_PATHS,
  generateCanaryDashboard,
} from "../src/generate-canary-dashboard.ts";
import { loadVerifierArtifactFixture, verifyObservations, writeVerifierReports } from "../../verifier/src/index.ts";
import {
  FLOW_MEMORY_STATUSES,
  verifierStatusToFlowMemoryStatus,
} from "../src/status.ts";

function loadExplorerFallback(): unknown {
  return JSON.parse(readFileSync("fixtures/dashboard/flowmemory-network-explorer-fallback.json", "utf8")) as unknown;
}

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
    ["schemas/flowmemory/task-bond-task.schema.json", "flowmemory.task_bond_task.v1"],
    ["schemas/flowmemory/task-bond-evidence.schema.json", "flowmemory.task_bond_evidence.v1"],
    ["schemas/flowmemory/task-bond-availability-proof.schema.json", "flowmemory.task_bond_availability_proof.v1"],
    ["schemas/flowmemory/task-bond-verifier-report.schema.json", "flowmemory.task_bond_verifier_report.v1"],
    ["schemas/flowmemory/task-bond-resolution.schema.json", "flowmemory.task_bond_resolution.v1"],
    ["schemas/flowmemory/task-bond-settlement.schema.json", "flowmemory.task_bond_settlement.v1"],
    ["schemas/flowmemory/task-bond-agent-memory-view.schema.json", "flowmemory.task_bond_agent_memory_view.v1"],
    ["schemas/flowmemory/agent-bonds-launch-approval.schema.json", "flowmemory.agent_bonds_launch_approval.v1"],
    ["schemas/flowmemory/agent-bonds-external-review-attestation.schema.json", "flowmemory.agent_bonds_external_review_attestation.v1"],
    ["schemas/flowmemory/agent-bonds-operator-separation-attestation.schema.json", "flowmemory.agent_bonds_operator_separation_attestation.v1"],
    ["schemas/flowmemory/agent-bonds-runtime-evidence-attestation.schema.json", "flowmemory.agent_bonds_runtime_evidence_attestation.v1"],
    ["schemas/flowmemory/agent-bonds-go-no-go-attestation.schema.json", "flowmemory.agent_bonds_go_no_go_attestation.v1"],
    ["schemas/flowmemory/agent-bonds-owner-inputs.schema.json", "flowmemory.agent_bonds_owner_inputs.v1"],
    ["schemas/base-agent-memory/agent-config.schema.json", "flowmemory.base_agent_memory.agent_config.v1"],
    ["schemas/base-agent-memory/hot-memory.schema.json", "flowmemory.base_agent_memory.hot_memory.v1"],
    ["schemas/base-agent-memory/task-observation.schema.json", "flowmemory.base_agent_memory.task_observation.v1"],
    ["schemas/base-agent-memory/step-preview.schema.json", "flowmemory.base_agent_memory.step_preview.v1"],
    ["schemas/base-agent-memory/action-receipt.schema.json", "flowmemory.base_agent_memory.action_receipt.v1"],
    ["schemas/base-agent-memory/memory-cell.schema.json", "flowmemory.base_agent_memory.memory_cell.v1"],
    ["schemas/base-agent-memory/memory-delta.schema.json", "flowmemory.base_agent_memory.memory_delta.v1"],
    ["schemas/base-agent-memory/replay-report.schema.json", "flowmemory.base_agent_memory.replay_report.v1"],
    ["schemas/base-agent-memory/rootflow-transition.schema.json", "flowmemory.base_agent_memory.rootflow_transition.v1"],
    ["schemas/base-agent-memory/agent-memory-view.schema.json", "flowmemory.base_agent_memory.agent_memory_view.v1"],
    ["schemas/base-agent-memory/task-scout-fixture.schema.json", "flowmemory.base_agent_memory.task_scout.fixture.v1"],
  ];

  for (const [path, id] of schemas) {
    const schema = JSON.parse(readFileSync(path, "utf8")) as { $id: string; required: string[] };
    assert.equal(schema.$id, id);
    assert.ok(schema.required.length > 0);
  }
});

test("generates concrete Rootflow and Flow Memory V0 outputs", () => {
  const dir = mkdtempSync(join(tmpdir(), "flowmemory-launch-core-"));
  const indexerOutPath = join(dir, "indexer-state.json");
  const verifierOutPath = join(dir, "verifier-reports.json");
  const indexerState = indexFlowPulseReceipts(loadIndexerFixtureReceipts(), {
    finalizedBlockNumber: "123458",
    explorerFallback: loadExplorerFallback(),
  });
  const verifierReports = verifyObservations(indexerState.observations, loadVerifierArtifactFixture());
  writeIndexerState(indexerOutPath, indexerState);
  writeVerifierReports(verifierOutPath, verifierReports);
  const paths = {
    ...DEFAULT_LAUNCH_CORE_PATHS,
    indexerPath: indexerOutPath,
    verifierPath: verifierOutPath,
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
    assert.equal(launchCore.memorySignals.length, 10);
    assert.equal(launchCore.memoryReceipts.length, 10);
    assert.equal(launchCore.rootflowTransitions.length, 9);
    assert.equal(launchCore.rootfieldBundles.length, 2);
    assert.equal(launchCore.agentMemoryViews.length, 2);
    assert.equal(launchCore.agentBondFixture?.schema, "flowmemory.agent_bonds.fixture.v1");

    assert.equal(launchCore.taskScoutFixture?.schema, "flowmemory.base_agent_memory.task_scout.fixture.v1");
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
    assert.equal(dashboard.agentBondTasks.length, 1);
    assert.equal(dashboard.agentBondSettlements.length, 1);
    assert.equal(dashboard.agentBondPassportViews.length, 1);
    assert.ok(dashboard.agentBondPassports.length > 0);
    assert.ok(dashboard.bondedTaskEnvelopes.length > 0);
    assert.ok(dashboard.bondedExecutionReceipts.length > 0);
    assert.equal(dashboard.agentBondPhase2Gate.foundationReady, true);
    assert.ok(dashboard.agentBondA2A.agentCards.length > 0);
    assert.ok(dashboard.agentBondX402.paymentIntents.length > 0);
    assert.ok(dashboard.agentBondCredit.scores.length > 0);
    assert.ok(dashboard.agentBondUnderwriters.pools.length > 0);
    assert.equal(dashboard.baseAgentMemoryScouts.length, 1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("generates deterministic Agent Bonds v1 accountability fixture", () => {
  const fixture = buildAgentBondFixture();
  const schemaPairs: Array<[string, Record<string, unknown>]> = [
    ["schemas/flowmemory/task-bond-task.schema.json", fixture.task],
    ["schemas/flowmemory/task-bond-evidence.schema.json", fixture.evidence],
    ["schemas/flowmemory/task-bond-availability-proof.schema.json", fixture.availabilityProof],
    ["schemas/flowmemory/task-bond-verifier-report.schema.json", fixture.verifierReport],
    ["schemas/flowmemory/task-bond-resolution.schema.json", fixture.resolution],
    ["schemas/flowmemory/task-bond-settlement.schema.json", fixture.settlement],
    ["schemas/flowmemory/task-bond-agent-memory-view.schema.json", fixture.agentMemoryView],
    ["schemas/flowmemory/memory-receipt.schema.json", fixture.memoryReceipt],
    ["schemas/flowmemory/rootflow-transition.schema.json", fixture.rootflowTransition],
    ["schemas/flowmemory/rootfield-bundle.schema.json", fixture.rootfieldBundle],
  ];

  for (const [path, record] of schemaPairs) {
    assertRequiredSchemaFields(path, record);
  }

  assert.equal(fixture.flowPulses.length, 6);
  assert.equal(fixture.task.status, "settled");
  assert.equal(fixture.verifierReport.status, "valid");
  assert.equal(fixture.memoryReceipt.flowMemoryStatus, "verified");
  assert.equal(fixture.rootflowTransition.status, "verified");
  assert.equal(fixture.settlement.totalEscrowed, fixture.settlement.totalReleased);
  assert.equal(fixture.settlement.reserveAmount, "0");
  assert.equal(fixture.agentMemoryView.verifiedTaskCount, 1);
  assert.equal(fixture.agentMemoryView.slashedTaskCount, 0);
  assert.equal(fixture.task.requiredConfirmations, 1);
  assert.equal(fixture.task.confirmedVerifierCount, 1);
  assert.equal(fixture.evidence.availabilityCommitment, fixture.availabilityProof.availabilityCommitment);
  assert.equal(fixture.verifierReport.confirmationsRequired, 1);
});


test("generates deterministic Base On-Chain Task Scout replay fixture", () => {
  const fixture = buildTaskScoutFixture();
  const schemaPairs: Array<[string, Record<string, unknown>]> = [
    ["schemas/base-agent-memory/agent-config.schema.json", fixture.agentConfig],
    ["schemas/base-agent-memory/hot-memory.schema.json", fixture.hotMemory],
    ["schemas/base-agent-memory/task-observation.schema.json", fixture.taskObservation],
    ["schemas/base-agent-memory/step-preview.schema.json", fixture.stepPreview],
    ["schemas/base-agent-memory/action-receipt.schema.json", fixture.actionReceipt],
    ["schemas/base-agent-memory/memory-cell.schema.json", fixture.memoryCell],
    ["schemas/base-agent-memory/memory-delta.schema.json", fixture.memoryDelta],
    ["schemas/base-agent-memory/replay-report.schema.json", fixture.verifierReport],
    ["schemas/base-agent-memory/rootflow-transition.schema.json", fixture.rootflowTransition],
    ["schemas/base-agent-memory/agent-memory-view.schema.json", fixture.agentMemoryView],
    ["schemas/base-agent-memory/task-scout-fixture.schema.json", fixture],
  ];

  for (const [path, record] of schemaPairs) {
    assertRequiredSchemaFields(path, record);
  }

  assert.equal(fixture.stepPreview.action, "ACCEPT_TASK");
  assert.equal(fixture.verifierReport.status, "verified");
  assert.equal(fixture.verifierReport.checks.every((check) => check.status === "pass"), true);
  assert.equal(fixture.agentMemoryView.verifiedMemory.length, 1);

  const poisoned = structuredClone(fixture);
  poisoned.stepPreview.action = "REJECT_TASK";
  assert.equal(replayTaskScoutFixture(poisoned).status, "failed");
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
    assert.equal(dashboard.agentBondPassports.length, 0);
    assert.equal(dashboard.bondedTaskEnvelopes.length, 0);
    assert.equal(dashboard.bondedExecutionReceipts.length, 0);
    assert.equal(dashboard.agentBondPhase2Gate.foundationReady, false);
    assert.equal(dashboard.alerts[0].severity, "info");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

function assertRequiredSchemaFields(path: string, record: Record<string, unknown>): void {
  const schema = JSON.parse(readFileSync(path, "utf8")) as { $id: string; required: string[]; properties: Record<string, { const?: string }> };
  assert.equal(record.schema, schema.properties.schema.const);
  for (const field of schema.required) {
    assert.ok(Object.hasOwn(record, field), `${path} requires ${field}`);
  }
}

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
    ...dashboard.agentBondTasks,
    ...dashboard.agentBondSettlements,
    ...dashboard.agentBondPassportViews,
    ...dashboard.agentBondPassports,
    ...dashboard.bondedTaskEnvelopes,
    ...dashboard.bondedExecutionReceipts,
    dashboard.agentBondPhase2Gate,
    ...dashboard.localRuntimeBlocks,
    ...dashboard.hardwareNodes,
    ...dashboard.alerts,
  ] as Array<{ status?: string }>;
  const statuses = new Set(records.map((record) => record.status));

  for (const status of FLOW_MEMORY_STATUSES) {
    assert.ok(statuses.has(status), `${status} should appear in generated dashboard fixture`);
  }
}
