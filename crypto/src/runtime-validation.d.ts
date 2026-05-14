export interface FlowchainRuntimeVerifyInput {
  document: Record<string, unknown>;
  envelope: Record<string, unknown>;
  context?: Record<string, unknown>;
}

export interface FlowchainRuntimeVerifyResult {
  schema: "flowchain.runtime_verify_result.v0";
  ok: boolean;
  failureCodes: string[];
  signerAddress?: string;
  signerAccountId?: string;
  signerPublicIdentity?: Record<string, unknown>;
  payloadHash?: string;
  transactionId?: string;
  envelopeId?: string;
  signingDigest?: string;
  nonce?: string | number;
  chainId?: string | number;
  networkProfile?: string;
  payloadType?: string;
  signerRole?: string;
  signerKeyId?: string;
  envelopePayload?: Record<string, unknown> | null;
}

export function verifyFlowchainEnvelope(input: FlowchainRuntimeVerifyInput): FlowchainRuntimeVerifyResult;
