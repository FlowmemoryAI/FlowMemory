import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { canonicalJson, keccak256Hex } from "../../shared/src/index.ts";
import type { TaskScoutFixtureEnvelope } from "../../flowmemory/src/agent-memory.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const DEFAULT_FIXTURE_PATH = resolve(REPO_ROOT, "fixtures/base-agent-memory/task-scout-v0.json");
const DEFAULT_AGENT_BONDS_ENVELOPE_PATH = resolve(REPO_ROOT, "fixtures/agent-bonds/envelopes/bonded-task-envelope.api-data-recourse.template.json");
const DEFAULT_AGENT_BONDS_POLICY_PATH = resolve(REPO_ROOT, "fixtures/agent-bonds/recourse/recourse-policy.api-data.low-risk.json");
const DEFAULT_AGENT_BONDS_DECISION_PATH = resolve(REPO_ROOT, "fixtures/agent-bonds/recourse/recourse-decision.api-data.approved.json");

export interface AgentMemoryClientOptions {
  chainId?: number;
  fixturePath?: string;
}

export interface AgentMemoryRpcClientOptions {
  chainId?: number;
  rpcUrl: string;
  fetchImpl?: typeof fetch;
}

export interface AgentConfig {
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
  status: string;
}

export interface HotMemory {
  agentId: string;
  latestMemoryRoot: string;
  activeGoal: string;
  lastActionReceiptId: string;
  lastVerifierReportId: string;
  sequence: string;
  failureCount: number;
  spendUsedThisEpoch: string;
}

export interface TaskObservationInput {
  taskContract: string;
  taskId: string;
  taskKind: string;
  taskKindName: string;
  evidenceRequirement: string;
  evidenceRequirementName: string;
  rewardToken: string;
  rewardAmount: bigint;
  deadlineBlock: bigint;
  taskStatus: "open";
  recentFailureCount: number;
  humanReviewRequired: boolean;
}

export interface EncodedTaskObservation {
  kind: "task";
  root: string;
  fields: TaskObservationInput;
}

export interface StepPreview {
  previewHash: string;
  agentId: string;
  sequence: string;
  observationRoot: string;
  action: string;
  toolId: string;
  target: string;
  selector: string;
  callDataHash: string;
  memoryDeltaRoot: string;
  reasonCode: string;
  maxValue: bigint;
}

export interface SubmittedStep {
  hash: string;
  agentId: string;
  expectedSequence: string;
  previewHash: string;
}

export interface ReplayCheck {
  name: string;
  status: "pass" | "fail";
  detail: string;
}

export interface ReplayTrace {
  agentId: string;
  transactionHash: string;
  logIndex: number;
  parentMemoryRoot: string;
  newMemoryRoot: string;
  observationRoot: string;
  actionReceiptId: string;
  verifierReportId: string;
  status: string;
  checks: ReplayCheck[];
}

export interface AgentMemoryView {
  viewId: string;
  agentId: string;
  rootfieldId: string;
  status: string;
  latestMemoryRoot: string;
  sequence: string;
  activeGoal: string;
  verifiedMemory: string[];
  pendingMemory: string[];
  failedOrCorrectedMemory: string[];
  recentActions: string[];
  nextActionPreview: string;
  replayWarnings: string[];
  localOnly: boolean;
}

export interface AgentBondRecourseQuote {
  schema: string;
  decision: Record<string, unknown>;
  localOnly: boolean;
}

export interface AgentBondTaskCreateRequest {
  schema: string;
  requestId: string;
  method: "openTaskWithRecourse";
  envelope: Record<string, unknown>;
  recourseDecision: Record<string, unknown>;
  policy: Record<string, unknown>;
  localOnly: boolean;
}

export class AgentMemoryError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = "AgentMemoryError";
    this.code = code;
  }
}

type TaskScoutRpcEnvelope = {
  schema: string;
  scout: Record<string, unknown>;
  fixture: TaskScoutFixtureEnvelope;
  replayReport: Record<string, unknown> | null;
  localOnly: boolean;
};

function stableId(schema: string, value: unknown): string {
  return keccak256Hex(new TextEncoder().encode(canonicalJson({ schema, value } as Record<string, unknown>)));
}

function readJsonFile<T = Record<string, unknown>>(path: string): T {
  return JSON.parse(readFileSync(path, "utf8")) as T;
}

function readFixture(path: string): TaskScoutFixtureEnvelope {
  return readJsonFile<TaskScoutFixtureEnvelope>(path);
}

function encodeObservationRoot(input: TaskObservationInput): string {
  return stableId("flowmemory.base_agent_memory.task_observation.root.v1", {
    taskContract: input.taskContract,
    taskId: input.taskId,
    taskKind: input.taskKind,
    evidenceRequirement: input.evidenceRequirement,
    rewardAmount: input.rewardAmount.toString(),
    deadlineBlock: input.deadlineBlock.toString(),
    taskStatus: input.taskStatus,
    recentFailureCount: input.recentFailureCount,
    humanReviewRequired: input.humanReviewRequired,
  });
}

export class AgentMemoryClient {
  readonly chainId: number;
  readonly fixturePath: string;
  private readonly fixture: TaskScoutFixtureEnvelope;

  constructor(options: AgentMemoryClientOptions = {}) {
    this.fixturePath = options.fixturePath ?? DEFAULT_FIXTURE_PATH;
    this.fixture = readFixture(this.fixturePath);
    this.chainId = options.chainId ?? Number(this.fixture.chainId);
    if (String(this.chainId) !== this.fixture.chainId) {
      throw new AgentMemoryError("CHAIN_ID_MISMATCH", `Expected chain ${this.chainId}, fixture is ${this.fixture.chainId}.`);
    }
  }

  getAgent(agentId: string): AgentConfig {
    if (agentId !== this.fixture.agentConfig.agentId) {
      throw new AgentMemoryError("AGENT_NOT_FOUND", `Unknown agent ${agentId}.`);
    }
    return { ...this.fixture.agentConfig };
  }

  getHotMemory(agentId: string): HotMemory {
    if (agentId !== this.fixture.hotMemory.agentId) {
      throw new AgentMemoryError("AGENT_NOT_FOUND", `Unknown hot memory agent ${agentId}.`);
    }
    return { ...this.fixture.hotMemory };
  }

  encodeTaskObservation(input: TaskObservationInput): EncodedTaskObservation {
    return {
      kind: "task",
      root: encodeObservationRoot(input),
      fields: input,
    };
  }

  previewStep(input: { agentId: string; observation: EncodedTaskObservation }): StepPreview {
    if (input.agentId !== this.fixture.stepPreview.agentId) {
      throw new AgentMemoryError("AGENT_NOT_FOUND", `Unknown agent ${input.agentId}.`);
    }
    if (input.observation.root !== this.fixture.stepPreview.observationRoot) {
      throw new AgentMemoryError("OBSERVATION_MISMATCH", "Observation root does not match the task-scout fixture.");
    }
    return {
      ...this.fixture.stepPreview,
      maxValue: BigInt(this.fixture.stepPreview.maxValue),
    };
  }

  step(input: { agentId: string; observation: EncodedTaskObservation; expectedPreview: StepPreview; expectedSequence: string; maxValue: bigint }): SubmittedStep {
    if (input.agentId !== this.fixture.agentConfig.agentId) {
      throw new AgentMemoryError("AGENT_NOT_FOUND", `Unknown agent ${input.agentId}.`);
    }
    if (input.expectedSequence !== this.fixture.stepPreview.sequence) {
      throw new AgentMemoryError("SEQUENCE_STALE", `Expected sequence ${input.expectedSequence} does not match fixture sequence ${this.fixture.stepPreview.sequence}.`);
    }
    if (input.expectedPreview.previewHash !== this.fixture.stepPreview.previewHash) {
      throw new AgentMemoryError("PREVIEW_MISMATCH", "Submitted preview hash does not match fixture preview hash.");
    }
    if (input.maxValue !== BigInt(this.fixture.stepPreview.maxValue)) {
      throw new AgentMemoryError("CAP_EXCEEDED", `Submitted maxValue ${input.maxValue} does not match fixture maxValue ${this.fixture.stepPreview.maxValue}.`);
    }
    return {
      hash: this.fixture.flowPulses[0].receiptLocator.txHash,
      agentId: input.agentId,
      expectedSequence: input.expectedSequence,
      previewHash: input.expectedPreview.previewHash,
    };
  }

  waitForStepReceipt(hash: string): TaskScoutFixtureEnvelope["actionReceipt"] {
    if (hash !== this.fixture.flowPulses[0].receiptLocator.txHash) {
      throw new AgentMemoryError("RECEIPT_NOT_FOUND", `Unknown receipt hash ${hash}.`);
    }
    return this.fixture.actionReceipt;
  }

  replayStep(receipt: { actionReceiptId: string } | string): ReplayTrace {
    const actionReceiptId = typeof receipt === "string" ? receipt : receipt.actionReceiptId;
    if (actionReceiptId !== this.fixture.actionReceipt.actionReceiptId) {
      throw new AgentMemoryError("REPLAY_NOT_FOUND", `Unknown action receipt ${actionReceiptId}.`);
    }
    return {
      agentId: this.fixture.agentConfig.agentId,
      transactionHash: this.fixture.flowPulses[0].receiptLocator.txHash,
      logIndex: Number(this.fixture.flowPulses[1].receiptLocator.logIndex),
      parentMemoryRoot: this.fixture.memoryDelta.parentMemoryRoot,
      newMemoryRoot: this.fixture.memoryDelta.newMemoryRoot,
      observationRoot: this.fixture.taskObservation.observationRoot,
      actionReceiptId: this.fixture.actionReceipt.actionReceiptId,
      verifierReportId: this.fixture.verifierReport.verifierReportId,
      status: this.fixture.verifierReport.status,
      checks: [...this.fixture.verifierReport.checks],
    };
  }

  getAgentMemoryView(agentId: string): AgentMemoryView {
    if (agentId !== this.fixture.agentMemoryView.agentId) {
      throw new AgentMemoryError("AGENT_NOT_FOUND", `Unknown agent ${agentId}.`);
    }
    return { ...this.fixture.agentMemoryView };
  }

  getApiDataBondTemplate(): { envelope: Record<string, unknown>; policy: Record<string, unknown> } {
    return {
      envelope: readJsonFile(DEFAULT_AGENT_BONDS_ENVELOPE_PATH),
      policy: readJsonFile(DEFAULT_AGENT_BONDS_POLICY_PATH),
    };
  }

  quoteApiDataBond(): AgentBondRecourseQuote {
    return {
      schema: "flowmemory.agent_memory_sdk.agent_bond_recourse_quote.v1",
      decision: readJsonFile(DEFAULT_AGENT_BONDS_DECISION_PATH),
      localOnly: true,
    };
  }

  createApiDataBondedTask(): AgentBondTaskCreateRequest {
    const { envelope, policy } = this.getApiDataBondTemplate();
    const quote = this.quoteApiDataBond();
    return {
      schema: "flowmemory.agent_memory_sdk.agent_bond_task_create_request.v1",
      requestId: stableId("flowmemory.agent_memory_sdk.agent_bond_task_create_request.v1", {
        envelopeId: envelope.envelopeId,
        decisionId: quote.decision.decisionId,
      }),
      method: "openTaskWithRecourse",
      envelope,
      recourseDecision: quote.decision,
      policy,
      localOnly: true,
    };
  }
}

async function rpcCall<T>(rpcUrl: string, fetchImpl: typeof fetch, method: string, params: Record<string, unknown>): Promise<T> {
  const response = await fetchImpl(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: `agent-memory-sdk:${method}`,
      method,
      params,
    }),
  });
  const payload = await response.json() as { result?: T; error?: { message?: string } };
  if (!response.ok || payload.error !== undefined || payload.result === undefined) {
    throw new AgentMemoryError("RPC_FAILED", payload.error?.message ?? `Agent memory RPC failed for ${method}.`);
  }
  return payload.result;
}

export class AgentMemoryRpcClient {
  readonly rpcUrl: string;
  readonly chainId: number;
  private readonly fetchImpl: typeof fetch;

  constructor(options: AgentMemoryRpcClientOptions) {
    this.rpcUrl = options.rpcUrl;
    this.fetchImpl = options.fetchImpl ?? fetch;
    this.chainId = options.chainId ?? 84532;
  }

  private async loadEnvelope(key: string): Promise<TaskScoutRpcEnvelope> {
    const envelope = await rpcCall<TaskScoutRpcEnvelope>(
      this.rpcUrl,
      this.fetchImpl,
      "base_agent_memory_task_scout_get",
      { agentId: key },
    );
    if (String(envelope.fixture.chainId) !== String(this.chainId)) {
      throw new AgentMemoryError("CHAIN_ID_MISMATCH", `Expected chain ${this.chainId}, control-plane fixture is ${envelope.fixture.chainId}.`);
    }
    return envelope;
  }

  async getAgent(agentId: string): Promise<AgentConfig> {
    return { ...((await this.loadEnvelope(agentId)).fixture.agentConfig) };
  }

  async getHotMemory(agentId: string): Promise<HotMemory> {
    return { ...((await this.loadEnvelope(agentId)).fixture.agentMemoryView.hotMemory) };
  }

  encodeTaskObservation(input: TaskObservationInput): EncodedTaskObservation {
    return {
      kind: "task",
      root: encodeObservationRoot(input),
      fields: input,
    };
  }

  async previewStep(input: { agentId: string; observation: EncodedTaskObservation }): Promise<StepPreview> {
    const envelope = await this.loadEnvelope(input.agentId);
    if (input.observation.root !== envelope.fixture.stepPreview.observationRoot) {
      throw new AgentMemoryError("OBSERVATION_MISMATCH", "Observation root does not match the control-plane task-scout fixture.");
    }
    return {
      ...envelope.fixture.stepPreview,
      maxValue: BigInt(envelope.fixture.stepPreview.maxValue),
    };
  }

  async step(input: { agentId: string; observation: EncodedTaskObservation; expectedPreview: StepPreview; expectedSequence: string; maxValue: bigint }): Promise<SubmittedStep> {
    const envelope = await this.loadEnvelope(input.agentId);
    if (input.expectedSequence !== envelope.fixture.stepPreview.sequence) {
      throw new AgentMemoryError("SEQUENCE_STALE", `Expected sequence ${input.expectedSequence} does not match control-plane sequence ${envelope.fixture.stepPreview.sequence}.`);
    }
    if (input.expectedPreview.previewHash !== envelope.fixture.stepPreview.previewHash) {
      throw new AgentMemoryError("PREVIEW_MISMATCH", "Submitted preview hash does not match control-plane fixture preview hash.");
    }
    if (input.maxValue !== BigInt(envelope.fixture.stepPreview.maxValue)) {
      throw new AgentMemoryError("CAP_EXCEEDED", `Submitted maxValue ${input.maxValue} does not match control-plane fixture maxValue ${envelope.fixture.stepPreview.maxValue}.`);
    }
    return {
      hash: envelope.fixture.flowPulses[0].receiptLocator.txHash,
      agentId: input.agentId,
      expectedSequence: input.expectedSequence,
      previewHash: input.expectedPreview.previewHash,
    };
  }

  async waitForStepReceipt(hash: string, agentId: string): Promise<TaskScoutFixtureEnvelope["actionReceipt"]> {
    const envelope = await this.loadEnvelope(agentId);
    if (hash !== envelope.fixture.flowPulses[0].receiptLocator.txHash) {
      throw new AgentMemoryError("RECEIPT_NOT_FOUND", `Unknown receipt hash ${hash}.`);
    }
    return envelope.fixture.actionReceipt;
  }

  async replayStep(receipt: { actionReceiptId: string } | string, agentId: string): Promise<ReplayTrace> {
    const envelope = await this.loadEnvelope(agentId);
    const actionReceiptId = typeof receipt === "string" ? receipt : receipt.actionReceiptId;
    if (actionReceiptId !== envelope.fixture.actionReceipt.actionReceiptId) {
      throw new AgentMemoryError("REPLAY_NOT_FOUND", `Unknown action receipt ${actionReceiptId}.`);
    }
    const replay = await rpcCall<{ report: { checks: ReplayCheck[]; status: string } }>(
      this.rpcUrl,
      this.fetchImpl,
      "base_agent_memory_replay_get",
      { agentId },
    );
    return {
      agentId: envelope.fixture.agentConfig.agentId,
      transactionHash: envelope.fixture.flowPulses[0].receiptLocator.txHash,
      logIndex: Number(envelope.fixture.flowPulses[1].receiptLocator.logIndex),
      parentMemoryRoot: envelope.fixture.memoryDelta.parentMemoryRoot,
      newMemoryRoot: envelope.fixture.memoryDelta.newMemoryRoot,
      observationRoot: envelope.fixture.taskObservation.observationRoot,
      actionReceiptId: envelope.fixture.actionReceipt.actionReceiptId,
      verifierReportId: envelope.fixture.verifierReport.verifierReportId,
      status: replay.report.status,
      checks: replay.report.checks,
    };
  }

  async getAgentMemoryView(agentId: string): Promise<AgentMemoryView> {
    return { ...((await this.loadEnvelope(agentId)).fixture.agentMemoryView) };
  }

  async quoteAgentBondRecourse(input: { agentId?: string; envelope?: Record<string, unknown> } = {}): Promise<AgentBondRecourseQuote> {
    return rpcCall<AgentBondRecourseQuote>(
      this.rpcUrl,
      this.fetchImpl,
      "agent_bond_recourse_decision_quote",
      input,
    );
  }

  async createApiDataBondedTask(input: { agentId?: string; envelope?: Record<string, unknown> } = {}): Promise<AgentBondTaskCreateRequest> {
    const quote = await this.quoteAgentBondRecourse(input);
    const envelope = input.envelope ?? readJsonFile<Record<string, unknown>>(DEFAULT_AGENT_BONDS_ENVELOPE_PATH);
    const policy = readJsonFile<Record<string, unknown>>(DEFAULT_AGENT_BONDS_POLICY_PATH);
    return {
      schema: "flowmemory.agent_memory_sdk.agent_bond_task_create_request.v1",
      requestId: stableId("flowmemory.agent_memory_sdk.agent_bond_task_create_request.v1", {
        envelopeId: envelope.envelopeId,
        decisionId: quote.decision.decisionId,
      }),
      method: "openTaskWithRecourse",
      envelope,
      recourseDecision: quote.decision,
      policy,
      localOnly: quote.localOnly,
    };
  }
}
