import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { bytesToHex, canonicalJson, encodeAddress, encodeBytes32, encodeStringTail, encodeUint256, keccak256Hex, keccak256Utf8 } from "../../shared/src/index.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const GENERATED_AT = "2026-05-21T00:00:00.000Z";
const ZERO_ROOT = "0x0000000000000000000000000000000000000000000000000000000000000000";
const OWNER = "0x1000000000000000000000000000000000000001";
const AGENT_CONTRACT = "0x2000000000000000000000000000000000000002";
const TASK_CONTRACT = "0x3000000000000000000000000000000000000003";
const FLOWPULSE_CONTRACT = AGENT_CONTRACT;
const CHAIN_ID = "84532";
const ROOTFIELD_ID = keccak256Utf8("flowmemory.rootfield.base-agent-memory.task-scout.v1");
const DOCS_REVIEW_TASK_KIND = keccak256Utf8("flowmemory.task_kind.docs_review.v1");
const PUBLIC_EVIDENCE_REQUIREMENT = keccak256Utf8("flowmemory.evidence.public.v1");
const ACCEPT_TASK_TOOL_ID = keccak256Utf8("flowmemory.tool.accept_task.v1");
const TASK_SCOUT_KERNEL_CLASS = keccak256Utf8("flowmemory.kernel.task_scout.rule_scoring.v1");
const ACCEPT_TASK_SELECTOR = `0x${keccak256Utf8("acceptTask(bytes32,string)").slice(2, 10)}`;
const FLOWPULSE_TOPIC0 = keccak256Utf8("FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)");

export const DEFAULT_TASK_SCOUT_FIXTURE_PATH = "fixtures/base-agent-memory/task-scout-v0.json";
export const DEFAULT_TASK_SCOUT_VIEW_PATH = "fixtures/base-agent-memory/task-scout-agent-memory-view.json";
export const DEFAULT_TASK_SCOUT_REPLAY_PATH = "fixtures/base-agent-memory/task-scout-replay-report.json";

export type TaskScoutStatus = "pending" | "verified" | "failed" | "unresolved" | "unsupported" | "reorged";
export type TaskScoutAction = "NOOP" | "ESCALATE" | "ACCEPT_TASK" | "REJECT_TASK" | "COMMIT_EVIDENCE" | "UPDATE_MEMORY_ONLY" | "PAUSE_SELF";

type JsonObject = Record<string, unknown>;

function concatBytes(parts: Uint8Array[]): Uint8Array {
  const output = new Uint8Array(parts.reduce((sum, part) => sum + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

export interface TaskScoutAgentConfig {
  schema: "flowmemory.base_agent_memory.agent_config.v1";
  agentId: string;
  owner: string;
  rootfieldId: string;
  kernelAddress: string;
  kernelClass: string;
  policyRoot: string;
  toolAllowlistRoot: string;
  latestMemoryRoot: string;
  sequence: string;
  autonomyLevel: number;
  status: "active" | "paused" | "finalized" | "failed";
}

export interface TaskScoutHotMemory {
  schema: "flowmemory.base_agent_memory.hot_memory.v1";
  agentId: string;
  latestMemoryRoot: string;
  activeGoal: string;
  lastActionReceiptId: string;
  lastVerifierReportId: string;
  sequence: string;
  failureCount: number;
  spendUsedThisEpoch: string;
}

export interface TaskScoutObservation {
  schema: "flowmemory.base_agent_memory.task_observation.v1";
  observationRoot: string;
  observationId: string;
  agentId: string;
  taskContract: string;
  taskId: string;
  taskKind: string;
  taskKindName: "docs-review";
  evidenceRequirement: string;
  evidenceRequirementName: "public";
  rewardToken: string;
  rewardAmount: string;
  deadlineBlock: string;
  taskStatus: "open";
  recentFailureCount: number;
  humanReviewRequired: boolean;
}

export interface TaskScoutStepPreview {
  schema: "flowmemory.base_agent_memory.step_preview.v1";
  previewHash: string;
  agentId: string;
  sequence: string;
  observationRoot: string;
  action: TaskScoutAction;
  toolId: string;
  target: string;
  selector: string;
  callDataHash: string;
  memoryDeltaRoot: string;
  reasonCode: "TASK_KIND_ALLOWED";
  maxValue: string;
}

export interface TaskScoutActionReceipt {
  schema: "flowmemory.base_agent_memory.action_receipt.v1";
  actionReceiptId: string;
  agentId: string;
  sequence: string;
  previewHash: string;
  observationRoot: string;
  action: TaskScoutAction;
  target: string;
  selector: string;
  success: boolean;
  valueSpent: string;
  reasonCode: string;
}

export interface TaskScoutMemoryCell {
  schema: "flowmemory.base_agent_memory.memory_cell.v1";
  memoryCellId: string;
  agentId: string;
  memoryType: "episodic" | "semantic" | "procedural" | "goal" | "scar_tissue" | "self_model";
  subject: string;
  contentMode: "PUBLIC_SHORT" | "COMMITMENT_ONLY" | "POINTER_COMMITMENT" | "CONTRACT_PAGE" | "EVENT_ONLY";
  contentCommitment: string;
  shortPublicSummary: string;
  sourceObservationId: string;
  sourceReceiptId: string;
  parentMemoryRoot: string;
  newMemoryRoot: string;
  status: TaskScoutStatus;
}

export interface TaskScoutMemoryDelta {
  schema: "flowmemory.base_agent_memory.memory_delta.v1";
  memoryDeltaId: string;
  agentId: string;
  sequence: string;
  parentMemoryRoot: string;
  deltaRoot: string;
  newMemoryRoot: string;
  readSetRoot: string;
  writeSetRoot: string;
  actionReceiptId: string;
  sourceObservationId: string;
  memoryCellIds: string[];
  status: TaskScoutStatus;
}

export interface TaskScoutFlowPulse {
  schema: "flowmemory.base_agent_memory.flowpulse_observation.v1";
  pulseId: string;
  rootfieldId: string;
  actor: string;
  pulseType: "AGENT_STEP_COMMITTED" | "AGENT_MEMORY_COMMITTED";
  pulseTypeId: string;
  subject: string;
  commitment: string;
  parentPulseId: string;
  sequence: string;
  occurredAt: string;
  uri: string;
  receiptLocator: {
    chainId: string;
    blockNumber: string;
    blockHash: string;
    txHash: string;
    logIndex: string;
    eventTopic0: string;
    sourceContract: string;
  };
}

export interface TaskScoutVerifierReport {
  schema: "flowmemory.base_agent_memory.replay_report.v1";
  verifierReportId: string;
  agentId: string;
  observationId: string;
  actionReceiptId: string;
  memoryDeltaId: string;
  parentMemoryRoot: string;
  newMemoryRoot: string;
  status: TaskScoutStatus;
  checks: Array<{ name: string; status: "pass" | "fail"; detail: string }>;
  reasonCodes: string[];
  createdAt: string;
}

export interface TaskScoutRootflowTransition {
  schema: "flowmemory.base_agent_memory.rootflow_transition.v1";
  transitionId: string;
  agentId: string;
  rootfieldId: string;
  sourceObservationId: string;
  parentRoot: string;
  newRoot: string;
  actionReceiptId: string;
  verifierReportId: string;
  status: TaskScoutStatus;
  sequence: string;
  pulseId: string;
  contractEventRef: {
    eventName: "FlowPulse";
    eventTopic0: string;
    sourceContract: string;
    pulseTypeId: string;
    pulseTypeName: string;
    txHash: string;
    logIndex: string;
  };
}

export interface TaskScoutAgentMemoryView {
  schema: "flowmemory.base_agent_memory.agent_memory_view.v1";
  viewId: string;
  agentId: string;
  rootfieldId: string;
  status: TaskScoutStatus;
  latestMemoryRoot: string;
  sequence: string;
  activeGoal: string;
  hotMemory: TaskScoutHotMemory;
  verifiedMemory: string[];
  pendingMemory: string[];
  failedOrCorrectedMemory: string[];
  recentActions: string[];
  nextActionPreview: string;
  replayWarnings: string[];
  localOnly: true;
}

export interface TaskScoutFixtureEnvelope {
  schema: "flowmemory.base_agent_memory.task_scout.fixture.v1";
  generatedAt: string;
  mode: "fixture";
  chainId: string;
  contracts: {
    agentMemory: string;
    taskTarget: string;
    flowPulse: string;
  };
  agentConfig: TaskScoutAgentConfig;
  hotMemory: TaskScoutHotMemory;
  taskObservation: TaskScoutObservation;
  stepPreview: TaskScoutStepPreview;
  actionReceipt: TaskScoutActionReceipt;
  memoryCell: TaskScoutMemoryCell;
  memoryDelta: TaskScoutMemoryDelta;
  flowPulses: TaskScoutFlowPulse[];
  verifierReport: TaskScoutVerifierReport;
  rootflowTransition: TaskScoutRootflowTransition;
  agentMemoryView: TaskScoutAgentMemoryView;
}

function stableId(schema: string, value: unknown): string {
  return keccak256Hex(new TextEncoder().encode(canonicalJson({ schema, value } as JsonObject)));
}

function writeJson(path: string, value: unknown): void {
  const resolved = resolve(REPO_ROOT, path);
  mkdirSync(dirname(resolved), { recursive: true });
  writeFileSync(resolved, `${JSON.stringify(value, null, 2)}\n`);
}

function withId<T extends JsonObject>(schema: string, idField: string, core: T): T & { schema: string } & Record<string, string> {
  return {
    schema,
    [idField]: stableId(schema, core),
    ...core,
  } as T & { schema: string } & Record<string, string>;
}

function pass(name: string, condition: boolean, detail: string): { name: string; status: "pass" | "fail"; detail: string } {
  return { name, status: condition ? "pass" : "fail", detail };
}

function recomputeObservationRoot(observation: TaskScoutObservation): string {
  return stableId("flowmemory.base_agent_memory.task_observation.root.v1", {
    taskContract: observation.taskContract,
    taskId: observation.taskId,
    taskKind: observation.taskKind,
    evidenceRequirement: observation.evidenceRequirement,
    rewardAmount: observation.rewardAmount,
    deadlineBlock: observation.deadlineBlock,
    taskStatus: observation.taskStatus,
    recentFailureCount: observation.recentFailureCount,
    humanReviewRequired: observation.humanReviewRequired,
  });
}

function recomputePreviewHash(preview: TaskScoutStepPreview): string {
  return stableId("flowmemory.base_agent_memory.step_preview.hash.v1", {
    agentId: preview.agentId,
    sequence: preview.sequence,
    observationRoot: preview.observationRoot,
    action: preview.action,
    toolId: preview.toolId,
    target: preview.target,
    selector: preview.selector,
    callDataHash: preview.callDataHash,
    memoryDeltaRoot: preview.memoryDeltaRoot,
    reasonCode: preview.reasonCode,
    maxValue: preview.maxValue,
  });
}

function recomputeNewRoot(delta: TaskScoutMemoryDelta): string {
  return stableId("flowmemory.base_agent_memory.memory_root.v1", {
    parentMemoryRoot: delta.parentMemoryRoot,
    deltaRoot: delta.deltaRoot,
    actionReceiptId: delta.actionReceiptId,
    sequence: delta.sequence,
  });
}

function encodeFlowPulseData(
  pulseTypeId: string,
  subject: string,
  commitment: string,
  parentPulseId: string,
  sequence: string,
  occurredAt: string,
  uri: string,
): string {
  const headLength = 7n * 32n;
  return bytesToHex(concatBytes([
    encodeUint256(pulseTypeId),
    encodeBytes32(subject),
    encodeBytes32(commitment),
    encodeBytes32(parentPulseId),
    encodeUint256(sequence),
    encodeUint256(occurredAt),
    encodeUint256(headLength),
    encodeStringTail(uri),
  ]));
}

function agentMemoryEventCommitment(
  parentRoot: string,
  deltaRoot: string,
  newRoot: string,
  actionReceiptId: string,
  actionSucceeded: boolean,
): string {
  return keccak256Hex(concatBytes([
    encodeBytes32(parentRoot),
    encodeBytes32(deltaRoot),
    encodeBytes32(newRoot),
    encodeBytes32(actionReceiptId),
    encodeUint256(actionSucceeded ? 1 : 0),
  ]));
}

export function replayTaskScoutFixture(fixture: TaskScoutFixtureEnvelope): TaskScoutVerifierReport {
  const checks = [
    pass("agent-active", fixture.agentConfig.status === "active", "agent config is active"),
    pass("observation-root", fixture.taskObservation.observationRoot === recomputeObservationRoot(fixture.taskObservation), "observation root matches canonical task fields"),
    pass("preview-action", fixture.stepPreview.action === "ACCEPT_TASK", "task scout accepts low-risk public docs-review task"),
    pass("preview-hash", fixture.stepPreview.previewHash === recomputePreviewHash(fixture.stepPreview), "preview hash binds action, tool, observation, and memory delta"),
    pass("receipt-preview", fixture.actionReceipt.previewHash === fixture.stepPreview.previewHash, "action receipt references preview hash"),
    pass("receipt-action", fixture.actionReceipt.action === fixture.stepPreview.action, "action receipt action matches preview"),
    pass("memory-parent", fixture.memoryDelta.parentMemoryRoot === fixture.hotMemory.latestMemoryRoot, "memory delta starts from current hot memory root"),
    pass("memory-root", fixture.memoryDelta.newMemoryRoot === recomputeNewRoot(fixture.memoryDelta), "new memory root recomputes from parent, delta, receipt, and sequence"),
    pass("transition-root", fixture.rootflowTransition.newRoot === fixture.memoryDelta.newMemoryRoot, "Rootflow transition points to memory delta output"),
    pass("view-root", fixture.agentMemoryView.latestMemoryRoot === fixture.rootflowTransition.newRoot, "AgentMemoryView uses latest transition root"),
  ];
  const status: TaskScoutStatus = checks.every((check) => check.status === "pass") ? "verified" : "failed";
  return {
    ...fixture.verifierReport,
    status,
    checks,
    reasonCodes: checks.filter((check) => check.status === "fail").map((check) => check.name),
  };
}

export function assertTaskScoutFixtureReplay(fixture: TaskScoutFixtureEnvelope): void {
  const report = replayTaskScoutFixture(fixture);
  if (report.status !== "verified") {
    throw new Error(`Task scout replay failed: ${report.checks.filter((check) => check.status === "fail").map((check) => check.name).join(", ")}`);
  }
}

export function buildTaskScoutFixture(): TaskScoutFixtureEnvelope {
  const initialMemoryRoot = stableId("flowmemory.base_agent_memory.initial_memory_root.v1", {
    agentClass: "task-scout",
    activeGoal: "accept-low-risk-public-docs-review-tasks",
  });
  const policyRoot = stableId("flowmemory.base_agent_memory.policy.v1", {
    taskKinds: ["docs-review"],
    publicEvidenceRequired: true,
    maxTaskReward: "5000000000000000000",
    failureThreshold: 3,
  });
  const toolAllowlistRoot = stableId("flowmemory.base_agent_memory.tool_allowlist.v1", {
    tools: [{ toolId: ACCEPT_TASK_TOOL_ID, target: TASK_CONTRACT, selector: ACCEPT_TASK_SELECTOR, maxValue: "0" }],
  });
  const agentId = stableId("flowmemory.base_agent_memory.agent_id.v1", {
    chainId: CHAIN_ID,
    owner: OWNER,
    rootfieldId: ROOTFIELD_ID,
    policyRoot,
    toolAllowlistRoot,
    initialMemoryRoot,
    kernelClass: TASK_SCOUT_KERNEL_CLASS,
  });
  const activeGoal = stableId("flowmemory.base_agent_memory.goal.v1", "accept-low-risk-public-docs-review-tasks");

  const agentConfig: TaskScoutAgentConfig = {
    schema: "flowmemory.base_agent_memory.agent_config.v1",
    agentId,
    owner: OWNER,
    rootfieldId: ROOTFIELD_ID,
    kernelAddress: AGENT_CONTRACT,
    kernelClass: TASK_SCOUT_KERNEL_CLASS,
    policyRoot,
    toolAllowlistRoot,
    latestMemoryRoot: initialMemoryRoot,
    sequence: "0",
    autonomyLevel: 2,
    status: "active",
  };
  const hotMemory: TaskScoutHotMemory = {
    schema: "flowmemory.base_agent_memory.hot_memory.v1",
    agentId,
    latestMemoryRoot: initialMemoryRoot,
    activeGoal,
    lastActionReceiptId: ZERO_ROOT,
    lastVerifierReportId: ZERO_ROOT,
    sequence: "0",
    failureCount: 0,
    spendUsedThisEpoch: "0",
  };

  const taskId = stableId("flowmemory.base_agent_memory.task_id.v1", {
    taskContract: TASK_CONTRACT,
    taskKind: "docs-review",
    nonce: "1",
  });
  const taskObservationCore = {
    agentId,
    taskContract: TASK_CONTRACT,
    taskId,
    taskKind: DOCS_REVIEW_TASK_KIND,
    taskKindName: "docs-review" as const,
    evidenceRequirement: PUBLIC_EVIDENCE_REQUIREMENT,
    evidenceRequirementName: "public" as const,
    rewardToken: "0x0000000000000000000000000000000000000000",
    rewardAmount: "1000000000000000000",
    deadlineBlock: "18000000",
    taskStatus: "open" as const,
    recentFailureCount: 0,
    humanReviewRequired: false,
  };
  const observationRoot = recomputeObservationRoot({
    schema: "flowmemory.base_agent_memory.task_observation.v1",
    observationRoot: ZERO_ROOT,
    observationId: ZERO_ROOT,
    ...taskObservationCore,
  });
  const taskObservation: TaskScoutObservation = {
    schema: "flowmemory.base_agent_memory.task_observation.v1",
    observationRoot,
    observationId: stableId("flowmemory.base_agent_memory.observation_id.v1", { chainId: CHAIN_ID, observationRoot, blockNumber: "17000001", logIndex: "0" }),
    ...taskObservationCore,
  };

  const callDataHash = stableId("flowmemory.base_agent_memory.calldata_hash.v1", { selector: ACCEPT_TASK_SELECTOR, taskId });
  const memoryDeltaRoot = stableId("flowmemory.base_agent_memory.delta_root.v1", {
    agentId,
    parentMemoryRoot: initialMemoryRoot,
    observationRoot,
    action: "ACCEPT_TASK",
    reasonCode: "TASK_KIND_ALLOWED",
    sequence: "1",
  });
  const previewCore = {
    agentId,
    sequence: "0",
    observationRoot,
    action: "ACCEPT_TASK" as const,
    toolId: ACCEPT_TASK_TOOL_ID,
    target: TASK_CONTRACT,
    selector: ACCEPT_TASK_SELECTOR,
    callDataHash,
    memoryDeltaRoot,
    reasonCode: "TASK_KIND_ALLOWED" as const,
    maxValue: "0",
  };
  const stepPreview: TaskScoutStepPreview = {
    schema: "flowmemory.base_agent_memory.step_preview.v1",
    previewHash: recomputePreviewHash({ schema: "flowmemory.base_agent_memory.step_preview.v1", previewHash: ZERO_ROOT, ...previewCore }),
    ...previewCore,
  };

  const actionReceipt: TaskScoutActionReceipt = withId("flowmemory.base_agent_memory.action_receipt.v1", "actionReceiptId", {
    agentId,
    sequence: "1",
    previewHash: stepPreview.previewHash,
    observationRoot,
    action: stepPreview.action,
    target: TASK_CONTRACT,
    selector: ACCEPT_TASK_SELECTOR,
    success: true,
    valueSpent: "0",
    reasonCode: stepPreview.reasonCode,
  });
  const memoryCell: TaskScoutMemoryCell = withId("flowmemory.base_agent_memory.memory_cell.v1", "memoryCellId", {
    agentId,
    memoryType: "episodic" as const,
    subject: taskId,
    contentMode: "PUBLIC_SHORT" as const,
    contentCommitment: stableId("flowmemory.base_agent_memory.memory_content.v1", {
      taskId,
      action: "ACCEPT_TASK",
      reason: "public docs-review task matched conservative policy",
    }),
    shortPublicSummary: "Accepted low-risk public docs-review task because policy and memory allowed it.",
    sourceObservationId: taskObservation.observationId,
    sourceReceiptId: actionReceipt.actionReceiptId,
    parentMemoryRoot: initialMemoryRoot,
    newMemoryRoot: ZERO_ROOT,
    status: "verified" as const,
  });
  const writeSetRoot = stableId("flowmemory.base_agent_memory.write_set.v1", { memoryCellIds: [memoryCell.memoryCellId] });
  const memoryDeltaCore = {
    agentId,
    sequence: "1",
    parentMemoryRoot: initialMemoryRoot,
    deltaRoot: memoryDeltaRoot,
    newMemoryRoot: ZERO_ROOT,
    readSetRoot: stableId("flowmemory.base_agent_memory.read_set.v1", { agentId, observationRoot, policyRoot, toolAllowlistRoot, latestMemoryRoot: initialMemoryRoot }),
    writeSetRoot,
    actionReceiptId: actionReceipt.actionReceiptId,
    sourceObservationId: taskObservation.observationId,
    memoryCellIds: [memoryCell.memoryCellId],
    status: "verified" as const,
  };
  const newMemoryRoot = recomputeNewRoot(memoryDeltaCore as TaskScoutMemoryDelta);
  memoryCell.newMemoryRoot = newMemoryRoot;
  const memoryDelta: TaskScoutMemoryDelta = {
    schema: "flowmemory.base_agent_memory.memory_delta.v1",
    memoryDeltaId: stableId("flowmemory.base_agent_memory.memory_delta.v1", { ...memoryDeltaCore, newMemoryRoot }),
    ...memoryDeltaCore,
    newMemoryRoot,
  };

  const stepPulse: TaskScoutFlowPulse = {
    schema: "flowmemory.base_agent_memory.flowpulse_observation.v1",
    pulseId: stableId("flowmemory.base_agent_memory.flowpulse.v1", { agentId, type: "AGENT_STEP_COMMITTED", actionReceiptId: actionReceipt.actionReceiptId }),
    rootfieldId: ROOTFIELD_ID,
    actor: OWNER,
    pulseType: "AGENT_STEP_COMMITTED",
    pulseTypeId: "16",
    subject: agentId,
    commitment: actionReceipt.actionReceiptId,
    parentPulseId: ZERO_ROOT,
    sequence: "1",
    occurredAt: "1780000000",
    uri: "fixture://base-agent-memory/task-scout/step",
    receiptLocator: {
      chainId: CHAIN_ID,
      blockNumber: "17000001",
      blockHash: stableId("flowmemory.base_agent_memory.block_hash.v1", "17000001"),
      txHash: stableId("flowmemory.base_agent_memory.tx.v1", { agentId, actionReceiptId: actionReceipt.actionReceiptId }),
      logIndex: "0",
      eventTopic0: FLOWPULSE_TOPIC0,
      sourceContract: FLOWPULSE_CONTRACT,
    },
  };
  const memoryPulse: TaskScoutFlowPulse = {
    schema: "flowmemory.base_agent_memory.flowpulse_observation.v1",
    pulseId: stableId("flowmemory.base_agent_memory.flowpulse.v1", { agentId, type: "AGENT_MEMORY_COMMITTED", newMemoryRoot }),
    rootfieldId: ROOTFIELD_ID,
    actor: OWNER,
    pulseType: "AGENT_MEMORY_COMMITTED",
    pulseTypeId: "18",
    subject: newMemoryRoot,
    commitment: agentMemoryEventCommitment(initialMemoryRoot, memoryDeltaRoot, newMemoryRoot, actionReceipt.actionReceiptId, true),
    parentPulseId: stepPulse.pulseId,
    sequence: "2",
    occurredAt: "1780000000",
    uri: "fixture://base-agent-memory/task-scout/memory",
    receiptLocator: {
      ...stepPulse.receiptLocator,
      logIndex: "1",
    },
  };

  const transitionCore = {
    agentId,
    rootfieldId: ROOTFIELD_ID,
    sourceObservationId: taskObservation.observationId,
    parentRoot: initialMemoryRoot,
    newRoot: memoryDelta.newMemoryRoot,
    actionReceiptId: actionReceipt.actionReceiptId,
    status: "verified" as const,
    sequence: "1",
    pulseId: memoryPulse.pulseId,
  };
  const rootflowTransition: TaskScoutRootflowTransition = {
    schema: "flowmemory.base_agent_memory.rootflow_transition.v1",
    transitionId: stableId("flowmemory.base_agent_memory.rootflow_transition.v1", transitionCore),
    ...transitionCore,
    verifierReportId: ZERO_ROOT,
    contractEventRef: {
      eventName: "FlowPulse",
      eventTopic0: FLOWPULSE_TOPIC0,
      sourceContract: FLOWPULSE_CONTRACT,
      pulseTypeId: memoryPulse.pulseTypeId,
      pulseTypeName: memoryPulse.pulseType,
      txHash: memoryPulse.receiptLocator.txHash,
      logIndex: memoryPulse.receiptLocator.logIndex,
    },
  };

  const verifierReportSeed: TaskScoutVerifierReport = {
    schema: "flowmemory.base_agent_memory.replay_report.v1",
    verifierReportId: ZERO_ROOT,
    agentId,
    observationId: taskObservation.observationId,
    actionReceiptId: actionReceipt.actionReceiptId,
    memoryDeltaId: memoryDelta.memoryDeltaId,
    parentMemoryRoot: initialMemoryRoot,
    newMemoryRoot: memoryDelta.newMemoryRoot,
    status: "pending",
    checks: [],
    reasonCodes: [],
    createdAt: GENERATED_AT,
  };

  const viewCore = {
    agentId,
    rootfieldId: ROOTFIELD_ID,
    status: "verified" as const,
    latestMemoryRoot: memoryDelta.newMemoryRoot,
    sequence: "1",
    activeGoal,
    hotMemory: { ...hotMemory, latestMemoryRoot: memoryDelta.newMemoryRoot, lastActionReceiptId: actionReceipt.actionReceiptId, sequence: "1" },
    verifiedMemory: [memoryCell.memoryCellId],
    pendingMemory: [],
    failedOrCorrectedMemory: [],
    recentActions: [actionReceipt.actionReceiptId],
    nextActionPreview: stepPreview.previewHash,
    replayWarnings: [],
    localOnly: true as const,
  };
  const agentMemoryView: TaskScoutAgentMemoryView = {
    schema: "flowmemory.base_agent_memory.agent_memory_view.v1",
    viewId: stableId("flowmemory.base_agent_memory.agent_memory_view.v1", viewCore),
    ...viewCore,
  };

  const fixture: TaskScoutFixtureEnvelope = {
    schema: "flowmemory.base_agent_memory.task_scout.fixture.v1",
    generatedAt: GENERATED_AT,
    mode: "fixture",
    chainId: CHAIN_ID,
    contracts: {
      agentMemory: AGENT_CONTRACT,
      taskTarget: TASK_CONTRACT,
      flowPulse: FLOWPULSE_CONTRACT,
    },
    agentConfig,
    hotMemory,
    taskObservation,
    stepPreview,
    actionReceipt,
    memoryCell,
    memoryDelta,
    flowPulses: [stepPulse, memoryPulse],
    verifierReport: verifierReportSeed,
    rootflowTransition,
    agentMemoryView,
  };

  const verifierReport = replayTaskScoutFixture(fixture);
  verifierReport.verifierReportId = stableId("flowmemory.base_agent_memory.replay_report.v1", {
    agentId,
    observationId: taskObservation.observationId,
    actionReceiptId: actionReceipt.actionReceiptId,
    checks: verifierReport.checks,
    status: verifierReport.status,
  });
  fixture.verifierReport = verifierReport;
  fixture.rootflowTransition.verifierReportId = verifierReport.verifierReportId;
  fixture.agentMemoryView.hotMemory.lastVerifierReportId = verifierReport.verifierReportId;
  fixture.agentMemoryView.viewId = stableId("flowmemory.base_agent_memory.agent_memory_view.v1", fixture.agentMemoryView);

  assertTaskScoutFixtureReplay(fixture);
  return fixture;
}


export function buildTaskScoutReceiptFixtures(fixture: TaskScoutFixtureEnvelope = buildTaskScoutFixture()): Array<{
  name: string;
  chainId: string;
  blockNumber: string;
  blockHash: string;
  transactionHash: string;
  transactionIndex: string;
  status: "success" | "reverted";
  logs: Array<{ address: string; topics: string[]; data: string; logIndex: string; removed?: boolean }>;
}> {
  const byTx = new Map<string, TaskScoutFlowPulse[]>();
  for (const pulse of fixture.flowPulses) {
    const txHash = pulse.receiptLocator.txHash;
    const group = byTx.get(txHash) ?? [];
    group.push(pulse);
    byTx.set(txHash, group);
  }
  return [...byTx.entries()].map(([txHash, pulses]) => {
    const first = pulses[0];
    if (first === undefined) {
      throw new Error("task scout pulse group missing first log");
    }
    return {
      name: "base-agent-memory-task-scout",
      chainId: first.receiptLocator.chainId,
      blockNumber: first.receiptLocator.blockNumber,
      blockHash: first.receiptLocator.blockHash,
      transactionHash: txHash,
      transactionIndex: "0",
      status: "success" as const,
      logs: pulses.map((pulse) => ({
        address: pulse.receiptLocator.sourceContract,
        topics: [
          pulse.receiptLocator.eventTopic0,
          pulse.pulseId,
          pulse.rootfieldId,
          bytesToHex(encodeAddress(pulse.actor)),
        ],
        data: encodeFlowPulseData(
          pulse.pulseTypeId,
          pulse.subject,
          pulse.commitment,
          pulse.parentPulseId,
          pulse.sequence,
          pulse.occurredAt,
          pulse.uri,
        ),
        logIndex: pulse.receiptLocator.logIndex,
      })),
    };
  });
}

export function buildTaskScoutVerifierArtifacts(fixture: TaskScoutFixtureEnvelope = buildTaskScoutFixture()): Record<string, JsonObject> {
  const stepPulse = fixture.flowPulses.find((pulse) => pulse.pulseTypeId === "16");
  const memoryPulse = fixture.flowPulses.find((pulse) => pulse.pulseTypeId === "18");
  if (stepPulse === undefined || memoryPulse === undefined) {
    throw new Error("task scout fixture is missing required pulses");
  }
  return {
    [stepPulse.uri]: {
      kind: "agent-step-commitment",
      actionReceiptId: fixture.actionReceipt.actionReceiptId,
    },
    [memoryPulse.uri]: {
      kind: "agent-memory-commitment",
      parentRoot: fixture.memoryDelta.parentMemoryRoot,
      deltaRoot: fixture.memoryDelta.deltaRoot,
      newRoot: fixture.memoryDelta.newMemoryRoot,
      actionReceiptId: fixture.actionReceipt.actionReceiptId,
      actionSucceeded: fixture.actionReceipt.success,
    },
  };
}

export function writeTaskScoutFixture(paths = {
  fixturePath: DEFAULT_TASK_SCOUT_FIXTURE_PATH,
  viewPath: DEFAULT_TASK_SCOUT_VIEW_PATH,
  replayPath: DEFAULT_TASK_SCOUT_REPLAY_PATH,
}): TaskScoutFixtureEnvelope {
  const fixture = buildTaskScoutFixture();
  writeJson(paths.fixturePath, fixture);
  writeJson(paths.viewPath, fixture.agentMemoryView);
  writeJson(paths.replayPath, fixture.verifierReport);
  return fixture;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const fixture = writeTaskScoutFixture();
  console.log(JSON.stringify({
    service: "base-onchain-agent-memory-task-scout",
    fixture: DEFAULT_TASK_SCOUT_FIXTURE_PATH,
    view: DEFAULT_TASK_SCOUT_VIEW_PATH,
    replay: DEFAULT_TASK_SCOUT_REPLAY_PATH,
    status: fixture.verifierReport.status,
    checks: fixture.verifierReport.checks.length,
  }, null, 2));
}
