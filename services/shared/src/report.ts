import { canonicalJson } from "./canonical-json.ts";
import { VERIFIER_REPORT_SCHEMA, VERIFIER_STATUSES, type VerifierStatus } from "./constants.ts";
import { normalizeAddress, normalizeBytes32 } from "./hex.ts";
import { keccak256Hex } from "./keccak.ts";

export interface VerifierReportCore {
  schema: typeof VERIFIER_REPORT_SCHEMA;
  verifierSpecVersion: string;
  resolverPolicyId: string;
  status: VerifierStatus;
  observationId: string;
  observation: {
    chainId: string;
    emittingContract: string;
    eventSignature: string;
    blockNumber: string;
    blockHash: string;
    txHash: string;
    transactionIndex: string;
    logIndex: string;
    pulseId: string;
    rootfieldId: string;
  };
  flowPulse: {
    actor: string;
    pulseType: string;
    subject: string;
    commitment: string;
    parentPulseId: string;
    sequence: string;
    occurredAt: string;
    uri: string;
  };
  checks: Array<Record<string, string | boolean>>;
  evidenceRefs: Array<Record<string, string>>;
  reasonCodes: string[];
}

export function isVerifierStatus(value: string): value is VerifierStatus {
  return VERIFIER_STATUSES.includes(value as VerifierStatus);
}

export function normalizeReportCore(report: VerifierReportCore): VerifierReportCore {
  if (report.schema !== VERIFIER_REPORT_SCHEMA) {
    throw new Error(`unsupported report schema: ${report.schema}`);
  }
  if (!isVerifierStatus(report.status)) {
    throw new Error(`unsupported verifier status: ${report.status}`);
  }

  return {
    ...report,
    observationId: normalizeBytes32(report.observationId),
    observation: {
      ...report.observation,
      emittingContract: normalizeAddress(report.observation.emittingContract),
      eventSignature: normalizeBytes32(report.observation.eventSignature),
      blockHash: normalizeBytes32(report.observation.blockHash),
      txHash: normalizeBytes32(report.observation.txHash),
      pulseId: normalizeBytes32(report.observation.pulseId),
      rootfieldId: normalizeBytes32(report.observation.rootfieldId),
    },
    flowPulse: {
      ...report.flowPulse,
      actor: normalizeAddress(report.flowPulse.actor),
      subject: normalizeBytes32(report.flowPulse.subject),
      commitment: normalizeBytes32(report.flowPulse.commitment),
      parentPulseId: normalizeBytes32(report.flowPulse.parentPulseId),
    },
    reasonCodes: [...report.reasonCodes].sort(),
  };
}

export function canonicalReportJson(report: VerifierReportCore): string {
  return canonicalJson(normalizeReportCore(report));
}

export function deriveReportId(report: VerifierReportCore): `0x${string}` {
  return keccak256Hex(new TextEncoder().encode(canonicalReportJson(report)));
}
