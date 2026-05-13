import {
  VERIFIER_REPORT_SCHEMA,
  deriveReportId,
  encodeBytes32,
  keccak256Hex,
  normalizeBytes32,
  type VerifierReportCore,
  type VerifierStatus,
} from "../../shared/src/index.ts";

export interface VerifiableObservation {
  observationId: string;
  lifecycleState?: string;
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
  actor: string;
  pulseType: string;
  subject: string;
  commitment: string;
  parentPulseId: string;
  sequence: string;
  occurredAt: string;
  uri: string;
}

export interface RootfieldRegistrationArtifact {
  kind: "rootfield-registration";
  schemaHash: string;
  metadataHash: string;
}

export interface RootCommitmentArtifact {
  kind: "root-commitment";
  root: string;
  artifactCommitment: string;
}

export interface SwapMemorySignalArtifact {
  kind: "swap-memory-signal";
  poolId: string;
  hookDataHash: string;
  memoryRoot: string;
}

export type VerifierArtifact = RootfieldRegistrationArtifact | RootCommitmentArtifact | SwapMemorySignalArtifact;

export interface ArtifactResolverFixture {
  resolverPolicyId: string;
  maxArtifactBytes?: number;
  artifactsByUri: Record<string, VerifierArtifact>;
}

export interface VerifierReport {
  reportId: string;
  reportDigest: string;
  reportCore: VerifierReportCore;
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

export function rootfieldRegistrationCommitment(artifact: RootfieldRegistrationArtifact): `0x${string}` {
  return keccak256Hex(concatBytes([
    encodeBytes32(artifact.schemaHash),
    encodeBytes32(artifact.metadataHash),
  ]));
}

export function rootCommitment(artifact: RootCommitmentArtifact): `0x${string}` {
  return keccak256Hex(concatBytes([
    encodeBytes32(artifact.root),
    encodeBytes32(artifact.artifactCommitment),
  ]));
}

export function swapMemorySignalCommitment(artifact: SwapMemorySignalArtifact): `0x${string}` {
  return keccak256Hex(concatBytes([
    encodeBytes32(artifact.poolId),
    encodeBytes32(artifact.hookDataHash),
    encodeBytes32(artifact.memoryRoot),
  ]));
}

function baseReportCore(
  observation: VerifiableObservation,
  resolverPolicyId: string,
  status: VerifierStatus,
  checks: Array<Record<string, string | boolean>>,
  evidenceRefs: Array<Record<string, string>>,
  reasonCodes: string[],
): VerifierReportCore {
  return {
    schema: VERIFIER_REPORT_SCHEMA,
    verifierSpecVersion: "0",
    resolverPolicyId,
    status,
    observationId: observation.observationId,
    observation: {
      chainId: observation.chainId,
      emittingContract: observation.emittingContract,
      eventSignature: observation.eventSignature,
      blockNumber: observation.blockNumber,
      blockHash: observation.blockHash,
      txHash: observation.txHash,
      transactionIndex: observation.transactionIndex,
      logIndex: observation.logIndex,
      pulseId: observation.pulseId,
      rootfieldId: observation.rootfieldId,
    },
    flowPulse: {
      actor: observation.actor,
      pulseType: observation.pulseType,
      subject: observation.subject,
      commitment: observation.commitment,
      parentPulseId: observation.parentPulseId,
      sequence: observation.sequence,
      occurredAt: observation.occurredAt,
      uri: observation.uri,
    },
    checks,
    evidenceRefs,
    reasonCodes,
  };
}

function finalizeReport(reportCore: VerifierReportCore): VerifierReport {
  const reportDigest = deriveReportId(reportCore);
  return {
    reportId: reportDigest,
    reportDigest,
    reportCore,
  };
}

function artifactSize(artifact: VerifierArtifact): number {
  return new TextEncoder().encode(JSON.stringify(artifact)).byteLength;
}

export function verifyObservation(
  observation: VerifiableObservation,
  resolver: ArtifactResolverFixture,
): VerifierReport {
  const checks: Array<Record<string, string | boolean>> = [
    { id: "observation.decoded", passed: true },
  ];
  const evidenceRefs: Array<Record<string, string>> = [];
  const reasonCodes: string[] = [];

  if (observation.lifecycleState === "reorged" || observation.lifecycleState === "removed") {
    reasonCodes.push("observation.reorged");
    return finalizeReport(baseReportCore(observation, resolver.resolverPolicyId, "reorged", checks, evidenceRefs, reasonCodes));
  }

  if (observation.pulseType !== "1" && observation.pulseType !== "2" && observation.pulseType !== "4") {
    reasonCodes.push("pulse.type.unsupported");
    return finalizeReport(baseReportCore(observation, resolver.resolverPolicyId, "unsupported", checks, evidenceRefs, reasonCodes));
  }

  const artifact = resolver.artifactsByUri[observation.uri];
  if (artifact === undefined) {
    reasonCodes.push("artifact.unavailable");
    return finalizeReport(baseReportCore(observation, resolver.resolverPolicyId, "unresolved", checks, evidenceRefs, reasonCodes));
  }

  evidenceRefs.push({ uri: observation.uri, kind: artifact.kind });
  if (resolver.maxArtifactBytes !== undefined && artifactSize(artifact) > resolver.maxArtifactBytes) {
    reasonCodes.push("artifact.too_large");
    return finalizeReport(baseReportCore(observation, resolver.resolverPolicyId, "unresolved", checks, evidenceRefs, reasonCodes));
  }

  if (observation.pulseType === "1") {
    if (artifact.kind !== "rootfield-registration") {
      reasonCodes.push("artifact.schema_mismatch");
      return finalizeReport(baseReportCore(observation, resolver.resolverPolicyId, "invalid", checks, evidenceRefs, reasonCodes));
    }

    const expectedCommitment = rootfieldRegistrationCommitment(artifact);
    const subjectMatches = normalizeBytes32(observation.subject) === normalizeBytes32(observation.rootfieldId);
    const commitmentMatches = normalizeBytes32(observation.commitment) === expectedCommitment;
    checks.push({ id: "subject.rootfield_matches", passed: subjectMatches });
    checks.push({ id: "commitment.rootfield_registration", passed: commitmentMatches });

    if (!subjectMatches) {
      reasonCodes.push("subject.mismatch");
    }
    if (!commitmentMatches) {
      reasonCodes.push("commitment.mismatch");
    }

    return finalizeReport(baseReportCore(
      observation,
      resolver.resolverPolicyId,
      reasonCodes.length === 0 ? "valid" : "invalid",
      checks,
      evidenceRefs,
      reasonCodes,
    ));
  }

  if (observation.pulseType === "2") {
    if (artifact.kind !== "root-commitment") {
      reasonCodes.push("artifact.schema_mismatch");
      return finalizeReport(baseReportCore(observation, resolver.resolverPolicyId, "invalid", checks, evidenceRefs, reasonCodes));
    }

    const expectedCommitment = rootCommitment(artifact);
    const subjectMatches = normalizeBytes32(observation.subject) === normalizeBytes32(artifact.root);
    const commitmentMatches = normalizeBytes32(observation.commitment) === expectedCommitment;
    checks.push({ id: "subject.root_matches", passed: subjectMatches });
    checks.push({ id: "commitment.root", passed: commitmentMatches });

    if (!subjectMatches) {
      reasonCodes.push("subject.mismatch");
    }
    if (!commitmentMatches) {
      reasonCodes.push("commitment.mismatch");
    }

    return finalizeReport(baseReportCore(
      observation,
      resolver.resolverPolicyId,
      reasonCodes.length === 0 ? "valid" : "invalid",
      checks,
      evidenceRefs,
      reasonCodes,
    ));
  }

  if (observation.pulseType === "4") {
    if (artifact.kind !== "swap-memory-signal") {
      reasonCodes.push("artifact.schema_mismatch");
      return finalizeReport(baseReportCore(observation, resolver.resolverPolicyId, "invalid", checks, evidenceRefs, reasonCodes));
    }

    const expectedCommitment = swapMemorySignalCommitment(artifact);
    const subjectMatches = normalizeBytes32(observation.subject) === normalizeBytes32(artifact.poolId);
    const commitmentMatches = normalizeBytes32(observation.commitment) === expectedCommitment;
    checks.push({ id: "subject.pool_matches", passed: subjectMatches });
    checks.push({ id: "commitment.swap_memory_signal", passed: commitmentMatches });

    if (!subjectMatches) {
      reasonCodes.push("subject.mismatch");
    }
    if (!commitmentMatches) {
      reasonCodes.push("commitment.mismatch");
    }

    return finalizeReport(baseReportCore(
      observation,
      resolver.resolverPolicyId,
      reasonCodes.length === 0 ? "valid" : "invalid",
      checks,
      evidenceRefs,
      reasonCodes,
    ));
  }

  reasonCodes.push("pulse.type.unsupported");
  return finalizeReport(baseReportCore(observation, resolver.resolverPolicyId, "unsupported", checks, evidenceRefs, reasonCodes));
}

export function verifyObservations(
  observations: VerifiableObservation[],
  resolver: ArtifactResolverFixture,
): VerifierReport[] {
  return observations.map((observation) => verifyObservation(observation, resolver));
}
