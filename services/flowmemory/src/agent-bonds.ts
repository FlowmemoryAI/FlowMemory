import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { canonicalJson, keccak256Hex } from "../../shared/src/index.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const GENERATED_AT = "2026-05-20T12:00:00.000Z";
const CHAIN_ID = "8453";
const SOURCE_CONTRACT = "0x0000000000000000000000000000000000000b0d";
const REQUESTER = "0x0000000000000000000000000000000000000101";
const AGENT = "0x0000000000000000000000000000000000000a91";
const VERIFIER = "0x0000000000000000000000000000000000000f11";
const CONFIRMING_VERIFIER = "0x0000000000000000000000000000000000000f22";
const SETTLEMENT_TOKEN = "0x0000000000000000000000000000000000000c01";
const ZERO = "0x0000000000000000000000000000000000000000000000000000000000000000";
const FLOWPULSE_TOPIC0 = keccak256Utf8("FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)");
const PULSE_TYPES = {
  TASK_OPENED: "5",
  TASK_ACCEPTED: "6",
  TASK_STARTED: "7",
  TASK_EVIDENCE_COMMITTED: "8",
  TASK_VERIFIED: "9",
  TASK_SETTLED: "12",
} as const;

export const DEFAULT_AGENT_BOND_FIXTURE_PATH = "fixtures/agent-bonds/agent-bonds-v1.json";

type JsonObject = Record<string, unknown>;

export interface AgentBondFixture {
  schema: "flowmemory.agent_bonds.fixture.v1";
  generatedAt: string;
  mode: "fixture";
  task: JsonObject;
  evidence: JsonObject;
  availabilityProof: JsonObject;
  verifierReport: JsonObject;
  resolution: JsonObject;
  settlement: JsonObject;
  flowPulses: JsonObject[];
  memoryReceipt: JsonObject;
  rootflowTransition: JsonObject;
  rootfieldBundle: JsonObject;
  agentMemoryView: JsonObject;
  accounting: JsonObject;
}

function utf8(value: string): Uint8Array {
  return new TextEncoder().encode(value);
}

function keccak256Utf8(value: string): `0x${string}` {
  return keccak256Hex(utf8(value));
}

function stableId(schema: string, value: unknown): `0x${string}` {
  return keccak256Hex(utf8(canonicalJson({ schema, value } as JsonObject)));
}

function iso(offsetSeconds: number): string {
  return new Date(Date.parse(GENERATED_AT) + offsetSeconds * 1000).toISOString();
}

function writeJson(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function money(value: bigint): string {
  return value.toString();
}

function add(values: bigint[]): bigint {
  return values.reduce((total, value) => total + value, 0n);
}

function flowPulse(input: {
  rootfieldId: string;
  actor: string;
  pulseType: string;
  pulseTypeName: string;
  subject: string;
  commitment: string;
  parentPulseId: string;
  sequence: string;
  occurredAt: string;
  uri: string;
}): JsonObject {
  const pulseId = stableId("flowmemory.agent_bond.flowpulse.v1", input);
  return {
    schema: "flowmemory.flowpulse_contract_event.v0",
    pulseId,
    interfaceName: "IFlowPulse",
    eventName: "FlowPulse",
    eventSignatureText: "FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)",
    eventTopic0: FLOWPULSE_TOPIC0,
    expectedTopic0: FLOWPULSE_TOPIC0,
    topicMatchesContract: true,
    sourceContract: SOURCE_CONTRACT,
    pulseTypeId: input.pulseType,
    pulseTypeName: input.pulseTypeName,
    indexed: {
      pulseId,
      rootfieldId: input.rootfieldId,
      actor: input.actor,
    },
    payload: {
      subject: input.subject,
      commitment: input.commitment,
      parentPulseId: input.parentPulseId,
      sequence: input.sequence,
      occurredAt: input.occurredAt,
      uri: input.uri,
    },
    receiptLocator: {
      chainId: CHAIN_ID,
      blockNumber: String(900_000 + Number(input.sequence)),
      blockHash: stableId("flowmemory.agent_bond.block_hash.v1", input.sequence),
      txHash: stableId("flowmemory.agent_bond.tx_hash.v1", { pulseId, sequence: input.sequence }),
      transactionIndex: "0",
      logIndex: input.sequence,
      receiptStatus: "1",
    },
    receiptDerivedFields: ["blockHash", "txHash", "transactionIndex", "logIndex", "receiptStatus"],
  };
}

export function buildAgentBondFixture(): AgentBondFixture {
  const usdc = 1_000_000n;
  const payout = 100n * usdc;
  const agentBond = 25n * usdc;
  const verifierFee = 10n * usdc;
  const requesterCancelBond = 25n * usdc;
  const disputeBond = 50n * usdc;
  const requesterEscrow = payout + verifierFee + requesterCancelBond;
  const totalEscrowed = requesterEscrow + agentBond;

  const rootfieldId = stableId("flowmemory.rootfield.agent_bonds.v1", "agent-bonds.objective-code");
  const policyId = stableId("flowmemory.task_policy.v1", "objective-code-low-risk-confirmed");
  const termsHash = stableId("flowmemory.task_terms.v1", {
    class: "deterministic_code_patch",
    verifier: "npm test --prefix services/flowmemory",
    evidence: "content-addressed patch manifest",
    confirmationsRequired: 1,
  });
  const taskId = stableId("flowmemory.task_bond.task_id.v1", {
    chainId: CHAIN_ID,
    sourceContract: SOURCE_CONTRACT,
    requester: REQUESTER,
    rootfieldId,
    policyId,
    termsHash,
  });
  const evidenceCommitment = stableId("flowmemory.task_bond.evidence.v1", {
    taskId,
    patch: "deterministic local fixture patch manifest",
    command: "npm test --prefix services/flowmemory",
  });
  const artifactCommitment = stableId("flowmemory.task_bond.artifact.v1", {
    taskId,
    output: "passing deterministic verifier fixture",
  });
  const providerId = stableId("flowmemory.task_bond.provider.v1", "ipfs-cluster-evidence-provider");
  const retentionPolicyHash = stableId("flowmemory.task_bond.retention_policy.v1", {
    minAvailabilityWindowSeconds: 172800,
    replication: 3,
  });
  const availabilitySampleRoot = stableId("flowmemory.task_bond.availability_sample.v1", {
    taskId,
    sample: ["cid-a", "cid-b", "cid-c"],
  });
  const availabilityCommitment = stableId("flowmemory.task_bond.availability_commitment.v1", {
    taskId,
    providerId,
    retentionPolicyHash,
    availabilitySampleRoot,
  });
  const reportDigest = stableId("flowmemory.task_bond.report_digest.v1", {
    taskId,
    evidenceCommitment,
    availabilityCommitment,
    status: "valid",
  });
  const reportId = stableId("flowmemory.task_bond.report_id.v1", { taskId, reportDigest, verifier: VERIFIER });

  const opened = flowPulse({
    rootfieldId,
    actor: REQUESTER,
    pulseType: PULSE_TYPES.TASK_OPENED,
    pulseTypeName: "TASK_OPENED",
    subject: taskId,
    commitment: stableId("flowmemory.task_bond.opened.v1", { termsHash, payout: money(payout), verifierFee: money(verifierFee), requesterCancelBond: money(requesterCancelBond) }),
    parentPulseId: ZERO,
    sequence: "1",
    occurredAt: GENERATED_AT,
    uri: "fixture://agent-bonds/task-opened",
  });
  const accepted = flowPulse({
    rootfieldId,
    actor: AGENT,
    pulseType: PULSE_TYPES.TASK_ACCEPTED,
    pulseTypeName: "TASK_ACCEPTED",
    subject: taskId,
    commitment: stableId("flowmemory.task_bond.accepted.v1", { taskId, agent: AGENT, agentBond: money(agentBond) }),
    parentPulseId: String(opened.pulseId),
    sequence: "2",
    occurredAt: iso(60),
    uri: "fixture://agent-bonds/task-accepted",
  });
  const started = flowPulse({
    rootfieldId,
    actor: AGENT,
    pulseType: PULSE_TYPES.TASK_STARTED,
    pulseTypeName: "TASK_STARTED",
    subject: taskId,
    commitment: stableId("flowmemory.task_bond.started.v1", { taskId, agent: AGENT }),
    parentPulseId: String(accepted.pulseId),
    sequence: "3",
    occurredAt: iso(90),
    uri: "fixture://agent-bonds/task-started",
  });
  const evidencePulse = flowPulse({
    rootfieldId,
    actor: AGENT,
    pulseType: PULSE_TYPES.TASK_EVIDENCE_COMMITTED,
    pulseTypeName: "TASK_EVIDENCE_COMMITTED",
    subject: taskId,
    commitment: stableId("flowmemory.task_bond.evidence_commitment.v1", { evidenceCommitment, availabilityCommitment }),
    parentPulseId: String(started.pulseId),
    sequence: "4",
    occurredAt: iso(180),
    uri: "fixture://agent-bonds/evidence",
  });
  const verified = flowPulse({
    rootfieldId,
    actor: VERIFIER,
    pulseType: PULSE_TYPES.TASK_VERIFIED,
    pulseTypeName: "TASK_VERIFIED",
    subject: taskId,
    commitment: reportDigest,
    parentPulseId: String(evidencePulse.pulseId),
    sequence: "5",
    occurredAt: iso(240),
    uri: "fixture://agent-bonds/verifier-report",
  });
  const settled = flowPulse({
    rootfieldId,
    actor: REQUESTER,
    pulseType: PULSE_TYPES.TASK_SETTLED,
    pulseTypeName: "TASK_SETTLED",
    subject: taskId,
    commitment: stableId("flowmemory.task_bond.settled.v1", { taskId, totalEscrowed: money(totalEscrowed) }),
    parentPulseId: String(verified.pulseId),
    sequence: "6",
    occurredAt: iso(49 * 60 * 60),
    uri: "fixture://agent-bonds/settlement",
  });
  const flowPulses = [opened, accepted, started, evidencePulse, verified, settled];

  const availabilityUntil = iso(72 * 60 * 60);
  const task = {
    schema: "flowmemory.task_bond_task.v1",
    taskId,
    rootfieldId,
    policyId,
    requester: REQUESTER,
    agent: AGENT,
    verifier: VERIFIER,
    termsHash,
    payout: money(payout),
    agentBond: money(agentBond),
    verifierFee: money(verifierFee),
    requesterCancelBond: money(requesterCancelBond),
    disputeBond: money(disputeBond),
    requiredConfirmations: 1,
    confirmedVerifierCount: 1,
    status: "settled",
    openedAt: GENERATED_AT,
    acceptedAt: iso(60),
    submissionDeadline: iso(24 * 60 * 60 + 60),
    challengeDeadline: iso(48 * 60 * 60 + 240),
    flowPulseIds: flowPulses.map((pulse) => String(pulse.pulseId)),
  };
  const evidence = {
    schema: "flowmemory.task_bond_evidence.v1",
    taskId,
    submittedBy: AGENT,
    evidenceCommitment,
    artifactCommitment,
    availabilityCommitment,
    availabilityUntil,
    evidenceURI: "fixture://agent-bonds/evidence/objective-code-patch.json",
    submittedAt: iso(180),
    checks: [
      { name: "artifact commitment is nonzero", passed: true },
      { name: "availability commitment is present", passed: true },
      { name: "declared verifier command passed", passed: true, detail: "npm test --prefix services/flowmemory" },
    ],
  };
  const availabilityProof = {
    schema: "flowmemory.task_bond_availability_proof.v1",
    taskId,
    availabilityCommitment,
    providerId,
    retentionPolicyHash,
    availabilitySampleRoot,
    availableUntil: availabilityUntil,
    evidenceURI: evidence.evidenceURI,
    status: "available",
    checks: [
      { name: "retention policy exceeds challenge window", passed: true },
      { name: "availability sample root matches commitment payload", passed: true },
    ],
  };
  const verifierReport = {
    schema: "flowmemory.task_bond_verifier_report.v1",
    reportId,
    taskId,
    verifier: VERIFIER,
    status: "valid",
    reportDigest,
    evidenceCommitment,
    policyId,
    confirmationsRequired: 1,
    confirmedBy: [CONFIRMING_VERIFIER],
    submittedAt: iso(240),
    reasonCodes: ["OBJECTIVE_TASK_VERIFIED", "INDEPENDENT_CONFIRMATION_RECORDED"],
    checks: [
      { name: "evidence commitment matches task", passed: true },
      { name: "availability commitment valid through challenge window", passed: true },
      { name: "deterministic command passed", passed: true },
    ],
  };
  const resolution = {
    schema: "flowmemory.task_bond_resolution.v1",
    resolutionId: stableId("flowmemory.task_bond.resolution.v1", { taskId, reportId, status: "verified" }),
    taskId,
    reportId,
    resolvedStatus: "verified",
    challenged: false,
    challengeBond: "0",
    resolver: VERIFIER,
    resolvedAt: iso(49 * 60 * 60),
    reasonCodes: ["CHALLENGE_WINDOW_EXPIRED", "INDEPENDENT_CONFIRMATION_SATISFIED"],
  };
  const transfers = [
    { to: AGENT, amount: money(payout), reason: "agent_payout" },
    { to: AGENT, amount: money(agentBond), reason: "agent_bond_return" },
    { to: REQUESTER, amount: money(requesterCancelBond), reason: "requester_cancel_bond_return" },
    { to: VERIFIER, amount: money(verifierFee), reason: "verifier_fee" },
  ];
  const settlement = {
    schema: "flowmemory.task_bond_settlement.v1",
    settlementId: stableId("flowmemory.task_bond.settlement.v1", { taskId, transfers }),
    taskId,
    status: "settled",
    settledAt: iso(49 * 60 * 60),
    settlementToken: SETTLEMENT_TOKEN,
    totalEscrowed: money(totalEscrowed),
    totalReleased: money(add([payout, agentBond, requesterCancelBond, verifierFee])),
    reserveAmount: "0",
    transfers,
  };
  const observationId = stableId("flowmemory.task_bond.observation.v1", { taskId, pulseId: verified.pulseId });
  const memoryReceipt = {
    schema: "flowmemory.memory_receipt.v0",
    receiptId: stableId("flowmemory.memory_receipt.v0", { taskId, reportId, status: "valid" }),
    reportId,
    reportDigest,
    observationId,
    rootfieldId,
    verifierStatus: "valid",
    flowMemoryStatus: "verified",
    resolverPolicyId: "agent-bonds.objective-code.v1",
    verifierSpecVersion: "agent-bonds-verifier.v2",
    checksPassed: 3,
    checksTotal: 3,
    reasonCodes: ["OBJECTIVE_TASK_VERIFIED", "INDEPENDENT_CONFIRMATION_RECORDED"],
    evidenceRefs: [
      {
        taskId,
        evidenceCommitment,
        artifactCommitment,
        availabilityCommitment,
        availableUntil: availabilityUntil,
        uri: evidence.evidenceURI,
      },
    ],
  };
  const rootflowTransition = {
    schema: "flowmemory.rootflow_transition.v0",
    transitionId: stableId("flowmemory.rootflow_transition.v0", { taskId, receiptId: memoryReceipt.receiptId, status: "verified" }),
    rootfieldId,
    observationId,
    pulseId: verified.pulseId,
    parentPulseId: evidencePulse.pulseId,
    parentTransitionId: null,
    memorySignalId: stableId("flowmemory.memory_signal.v0", { taskId, pulseId: verified.pulseId }),
    memoryReceiptId: memoryReceipt.receiptId,
    reportId,
    previousRoot: ZERO,
    attemptedRoot: stableId("flowmemory.task_bond.root.v1", { taskId, settlementId: settlement.settlementId }),
    nextRoot: stableId("flowmemory.task_bond.root.v1", { taskId, settlementId: settlement.settlementId }),
    status: "verified",
    blockNumber: String((verified.receiptLocator as JsonObject).blockNumber),
    txHash: String((verified.receiptLocator as JsonObject).txHash),
    sequence: "5",
    reasonCodes: ["OBJECTIVE_TASK_VERIFIED", "INDEPENDENT_CONFIRMATION_RECORDED"],
    contractEventRef: {
      signalId: stableId("flowmemory.memory_signal.v0", { taskId, pulseId: verified.pulseId }),
      eventName: "FlowPulse",
      eventTopic0: FLOWPULSE_TOPIC0,
      sourceContract: SOURCE_CONTRACT,
      pulseTypeId: PULSE_TYPES.TASK_VERIFIED,
      pulseTypeName: "TASK_VERIFIED",
      txHash: String((verified.receiptLocator as JsonObject).txHash),
      logIndex: String((verified.receiptLocator as JsonObject).logIndex),
    },
  };
  const rootfieldBundle = {
    schema: "flowmemory.rootfield_bundle.v0",
    bundleId: stableId("flowmemory.rootfield_bundle.v0", { rootfieldId, latestTransitionId: rootflowTransition.transitionId }),
    rootfieldId,
    latestRoot: rootflowTransition.nextRoot,
    latestTransitionId: rootflowTransition.transitionId,
    status: "verified",
    transitionIds: [rootflowTransition.transitionId],
    memorySignalIds: [rootflowTransition.memorySignalId],
    memoryReceiptIds: [memoryReceipt.receiptId],
    verifierReportIds: [reportId],
    counts: {
      observations: flowPulses.length,
      transitions: 1,
      receipts: 1,
      verified: 1,
      failed: 0,
      unresolved: 0,
      unsupported: 0,
      reorged: 0,
    },
  };
  const agentMemoryView = {
    schema: "flowmemory.task_bond_agent_memory_view.v1",
    viewId: stableId("flowmemory.task_bond_agent_memory_view.v1", { agent: AGENT, taskId }),
    agent: AGENT,
    rootfieldId,
    latestTaskId: taskId,
    taskIds: [taskId],
    verifiedTaskCount: 1,
    failedTaskCount: 0,
    slashedTaskCount: 0,
    totalPayoutEarned: money(payout),
    totalBondAtRisk: money(agentBond),
    reputationScore: Math.log1p(Number(agentBond) / Number(100n * usdc)),
    limitations: [
      "Heavy task artifacts are off-chain and represented by commitments.",
      "This fixture demonstrates local/test accountability plumbing, not an open verifier market.",
    ],
  };

  return {
    schema: "flowmemory.agent_bonds.fixture.v1",
    generatedAt: GENERATED_AT,
    mode: "fixture",
    task,
    evidence,
    availabilityProof,
    verifierReport,
    resolution,
    settlement,
    flowPulses,
    memoryReceipt,
    rootflowTransition,
    rootfieldBundle,
    agentMemoryView,
    accounting: {
      requesterEscrow: money(requesterEscrow),
      agentBond: money(agentBond),
      totalEscrowed: money(totalEscrowed),
      totalReleased: settlement.totalReleased,
      reserveAmount: settlement.reserveAmount,
      balances: {
        agent: money(payout + agentBond),
        requester: money(requesterCancelBond),
        verifier: money(verifierFee),
      },
    },
  };
}

export function writeAgentBondFixture(path = DEFAULT_AGENT_BOND_FIXTURE_PATH): AgentBondFixture {
  const fixture = buildAgentBondFixture();
  writeJson(resolve(REPO_ROOT, path), fixture);
  return fixture;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.chdir(REPO_ROOT);
  const outPath = process.argv[2] ?? DEFAULT_AGENT_BOND_FIXTURE_PATH;
  const fixture = writeAgentBondFixture(outPath);
  console.log(JSON.stringify({
    service: "flowmemory-agent-bonds-v1",
    outPath: resolve(outPath),
    taskId: fixture.task.taskId,
    flowPulses: fixture.flowPulses.length,
    settlementStatus: fixture.settlement.status,
    totalEscrowed: fixture.accounting.totalEscrowed,
  }, null, 2));
}
