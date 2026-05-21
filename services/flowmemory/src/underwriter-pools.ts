import { readJson, validateWithSchema, type JsonObject } from "./agent-bonds-phase2-shared.ts";
import type { BondedTaskEnvelope } from "./bonded-task-envelope.ts";
import type { AgentBondPassport } from "./agent-bond-passport.ts";

export type UnderwriterPool = JsonObject;
export type UnderwriterAllocation = JsonObject;
export type UnderwriterLossEvent = JsonObject;
export type AllocationInput = { pool: UnderwriterPool; agentId: string; taskClass?: string; allocatedCapacityUSDC: string };
export type LossWaterfallInput = { pool: UnderwriterPool; allocation: UnderwriterAllocation; taskId: string; receiptId: string; reason: string; amountSlashed: string };

export function validateUnderwriterPool(input: unknown): UnderwriterPool { return validateWithSchema<UnderwriterPool>("schemas/flowmemory/underwriter-pool.schema.json", input); }
export function validateUnderwriterAllocation(input: unknown): UnderwriterAllocation { return validateWithSchema<UnderwriterAllocation>("schemas/flowmemory/underwriter-allocation.schema.json", input); }
export function validateUnderwriterLossEvent(input: unknown): UnderwriterLossEvent { return validateWithSchema<UnderwriterLossEvent>("schemas/flowmemory/underwriter-loss-event.schema.json", input); }

export function computePoolAvailableCapacity(pool: UnderwriterPool): string {
  const capacity = (pool.capacity ?? {}) as JsonObject;
  return String(capacity.totalAvailable ?? "0");
}

export function canPoolBackEnvelope(pool: UnderwriterPool, envelope: BondedTaskEnvelope): boolean {
  if (pool.status !== "active") return false;
  const scope = (pool.scope ?? {}) as JsonObject;
  const taskClasses = Array.isArray(scope.taskClasses) ? scope.taskClasses.map(String) : [];
  const envelopeTaskClass = String(((envelope.task as JsonObject).taskClass) ?? "");
  const riskTier = Number(((envelope.policy as JsonObject).riskTier) ?? 0);
  const maxRiskTier = Number(scope.maxRiskTier ?? riskTier);
  return (taskClasses.length === 0 || taskClasses.includes(envelopeTaskClass)) && riskTier <= maxRiskTier;
}

export function allocatePoolCapacity(input: AllocationInput): UnderwriterAllocation {
  if (String(input.pool.status) !== "active") throw new Error("pool is not active");
  if (String(input.agentId).includes("revoked")) throw new Error("cannot allocate to revoked agent");
  const totalAvailable = BigInt(computePoolAvailableCapacity(input.pool));
  const requested = BigInt(input.allocatedCapacityUSDC);
  if (requested > totalAvailable) throw new Error("cannot allocate above pool cap");
  return validateUnderwriterAllocation({
    schemaVersion: "underwriter-allocation/v1",
    allocationId: `allocation_${input.agentId}_${input.taskClass ?? 'default'}`,
    poolId: input.pool.poolId,
    agentId: input.agentId,
    taskClass: input.taskClass,
    allocatedCapacityUSDC: input.allocatedCapacityUSDC,
    lockedCapacityUSDC: "0",
    availableCapacityUSDC: input.allocatedCapacityUSDC,
    validFrom: new Date().toISOString(),
    validUntil: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    status: "active",
  });
}

export function simulateLossWaterfall(input: LossWaterfallInput): UnderwriterLossEvent {
  return validateUnderwriterLossEvent({
    schemaVersion: "underwriter-loss-event/v1",
    lossEventId: `loss_${input.taskId}`,
    poolId: input.pool.poolId,
    allocationId: input.allocation.allocationId,
    taskId: input.taskId,
    receiptId: input.receiptId,
    reason: input.reason,
    amountSlashed: input.amountSlashed,
    asset: ((input.pool.asset as JsonObject).tokenAddress ?? "unknown"),
    waterfall: [
      { source: "agent_bond", amount: input.amountSlashed },
      { source: "underwriter_pool", amount: "0" },
    ],
    createdAt: new Date().toISOString(),
  });
}

export function applyUnderwriterCapacityToPassport(passport: AgentBondPassport, allocations: UnderwriterAllocation[]): AgentBondPassport {
  const clone = structuredClone(passport);
  const added = allocations
    .filter((allocation) => allocation.agentId === passport.agentId && allocation.status === "active")
    .reduce((sum, allocation) => sum + BigInt(String(allocation.availableCapacityUSDC ?? "0")), 0n);
  const capacity = (clone.capacity ?? {}) as JsonObject;
  capacity.maxOpenExposureUSDC = (BigInt(String(capacity.maxOpenExposureUSDC ?? "0")) + added).toString();
  clone.capacity = capacity;
  return clone;
}

export function sampleUnderwriterPool(): UnderwriterPool { return readJson<UnderwriterPool>("fixtures/agent-bonds/underwriters/pool.stake-capacity.template.json"); }
