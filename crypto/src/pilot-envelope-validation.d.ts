export interface PilotEnvelopeValidationInput {
  document: Record<string, unknown>;
  envelope: Record<string, unknown>;
  context?: {
    chainId?: number | bigint | string;
    expectedChainId?: number | bigint | string;
    expectedDestinationChainId?: number | bigint | string;
    expectedContractAddress?: string;
    expectedOperatorId?: string;
    expectedNonce?: number | bigint | string;
    expectedSignerId?: string;
    seenNonces?: Set<string>;
    nowUnixMs?: number | bigint | string;
  };
}

export interface PilotEnvelopeValidationResult {
  valid: boolean;
  errors: string[];
}

export const PILOT_MESSAGE_SCHEMAS: readonly string[];
export function validatePilotOperatorEnvelope(input: PilotEnvelopeValidationInput): PilotEnvelopeValidationResult;
export function pilotEnvelopeReplayKey(envelope: Record<string, unknown>): string;
export function assertPublicPilotMetadataContainsNoSecrets(value: unknown): void;
