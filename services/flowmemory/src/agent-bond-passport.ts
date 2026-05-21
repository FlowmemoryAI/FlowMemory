import { decimal, listJson, readJson, validateWithSchema, type JsonObject } from "./agent-bonds-phase2-shared.ts";

export type AgentBondPassport = JsonObject;
export type PassportFilter = { status?: string; taskClass?: string };
export type PassportCapacityView = JsonObject;

const SCHEMA_PATH = "schemas/flowmemory/agent-bond-passport.schema.json";
const PASSPORT_DIR = "fixtures/agent-bonds/passports";

export function validateAgentBondPassport(input: unknown): AgentBondPassport {
  return validateWithSchema<AgentBondPassport>(SCHEMA_PATH, input);
}

function passports(): AgentBondPassport[] {
  return listJson<AgentBondPassport>(PASSPORT_DIR)
    .filter((passport) => passport.schemaVersion === "agent-bond-passport/v1")
    .flatMap((passport) => {
      try {
        return [validateAgentBondPassport(passport)];
      } catch {
        return [];
      }
    });
}

export function getAgentBondPassport(agentId: string): AgentBondPassport | null {
  return passports().find((passport) => passport.agentId === agentId || passport.passportId === agentId) ?? null;
}

export function listAgentBondPassports(filter: PassportFilter = {}): AgentBondPassport[] {
  return passports().filter((passport) => {
    if (filter.status !== undefined && passport.status !== filter.status) return false;
    if (filter.taskClass !== undefined) {
      const capabilities = Array.isArray(passport.capabilities) ? passport.capabilities : [];
      return capabilities.some((capability) => typeof capability === "object" && capability !== null && (capability as JsonObject).taskClass === filter.taskClass);
    }
    return true;
  });
}

export function computePassportCapacityView(agentId: string): PassportCapacityView {
  const passport = getAgentBondPassport(agentId);
  if (passport === null) {
    return { schema: "flowmemory.agent_bond_passport_capacity.v1", agentId, found: false, blockers: ["passport not found"] };
  }
  const capacity = (passport.capacity ?? {}) as JsonObject;
  const stake = (passport.stake ?? {}) as JsonObject;
  const maxOpenExposureUSDC = decimal(capacity.maxOpenExposureUSDC);
  const currentOpenExposureUSDC = decimal(capacity.currentOpenExposureUSDC);
  const availableOpenExposureUSDC = (BigInt(maxOpenExposureUSDC) - BigInt(currentOpenExposureUSDC)).toString();
  return {
    schema: "flowmemory.agent_bond_passport_capacity.v1",
    agentId: passport.agentId,
    passportId: passport.passportId,
    status: passport.status,
    riskBand: capacity.riskBand ?? "UNRATED",
    maxTaskPayoutUSDC: decimal(capacity.maxTaskPayoutUSDC),
    maxOpenExposureUSDC,
    currentOpenExposureUSDC,
    availableOpenExposureUSDC,
    maxOpenTasks: capacity.maxOpenTasks,
    currentOpenTasks: capacity.currentOpenTasks,
    stakeCapacityUSDC: decimal(stake.stakeCapacityUSDC),
    canAcceptNewTask: passport.status === "active" && BigInt(availableOpenExposureUSDC) > 0n,
  };
}

export function buildPassportFromTaskHistory(agentId: string): AgentBondPassport {
  const existing = getAgentBondPassport(agentId);
  if (existing !== null) return existing;
  const fixture = readJson<JsonObject>("fixtures/agent-bonds/agent-bonds-v1.json");
  const view = (fixture.agentMemoryView ?? {}) as JsonObject;
  const task = (fixture.task ?? {}) as JsonObject;
  const now = new Date().toISOString();
  return validateAgentBondPassport({
    schemaVersion: "agent-bond-passport/v1",
    passportId: `passport_${agentId}`,
    agentId,
    operatorId: "operator_from_task_history",
    displayName: "Task History Agent",
    status: "active",
    chain: { chainId: 8453, caip2: "eip155:8453", name: "Base" },
    wallets: { taskWallet: String(task.agent ?? "0x1000000000000000000000000000000000000a91") },
    contracts: {},
    stake: {},
    capacity: { maxTaskPayoutUSDC: decimal(task.payout), maxOpenExposureUSDC: decimal(task.payout), currentOpenExposureUSDC: "0", maxOpenTasks: 1, currentOpenTasks: 0, riskBand: "UNRATED" },
    capabilities: [{ taskClass: "code.patch", title: "Derived capability", description: "Derived from fixture task history.", objectiveOnly: true, supportedEvidenceSchemas: ["flowmemory.task_bond_evidence.v1"], supportedPolicyIds: [String(task.policyId ?? "fixture-policy")], maxPayoutUSDC: decimal(task.payout), maxBondUSDC: decimal(task.agentBond) }],
    reputation: { completedTasks: Number(view.verifiedTaskCount ?? 0), settledTasks: Number(view.verifiedTaskCount ?? 0), challengedTasks: 0, upheldChallenges: 0, slashedTasks: Number(view.slashedTaskCount ?? 0), unsupportedTasks: 0, timeoutTasks: 0, totalSettledUSDC: decimal(view.totalPayoutEarned), totalSlashedUSDC: "0", latestReceiptIds: [] },
    verification: { verifierIds: [String(task.verifier ?? "fixture-verifier")], confirmingVerifierRequired: true },
    integrations: {},
    timestamps: { createdAt: now, updatedAt: now },
  });
}
