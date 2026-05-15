import { redactFlowChainSecrets } from "./redaction.ts";
import type { FlowChainRpcErrorObject, JsonValue } from "./types.ts";

export type FlowChainErrorTag =
  | "missing_live_config"
  | "rpc_unreachable"
  | "rpc_method_unavailable"
  | "malformed_envelope"
  | "unsigned_envelope"
  | "replay_rejection"
  | "not_final_transaction"
  | "bridge_not_ready"
  | "account_not_found"
  | "insufficient_balance"
  | "rpc_error";

export class FlowChainSdkError extends Error {
  readonly tag: FlowChainErrorTag;
  readonly details?: JsonValue;

  constructor(tag: FlowChainErrorTag, message: string, details?: JsonValue) {
    super(message);
    this.name = "FlowChainSdkError";
    this.tag = tag;
    this.details = details;
  }

  toJSON(): JsonValue {
    return redactFlowChainSecrets({
      name: this.name,
      tag: this.tag,
      message: this.message,
      details: this.details,
    }) as JsonValue;
  }
}

export class FlowChainMissingLiveConfigError extends FlowChainSdkError {
  readonly missingNames: string[];

  constructor(missingNames: string[], message = "FlowChain live configuration is missing.") {
    super("missing_live_config", message, { missingNames });
    this.name = "FlowChainMissingLiveConfigError";
    this.missingNames = missingNames;
  }
}

export class FlowChainRpcUnreachableError extends FlowChainSdkError {
  constructor(rpcUrl: string, cause: unknown) {
    super("rpc_unreachable", "FlowChain RPC is unreachable.", {
      endpoint: rpcUrl,
      cause: cause instanceof Error ? cause.message : String(cause),
    });
    this.name = "FlowChainRpcUnreachableError";
  }
}

export class FlowChainRpcMethodUnavailableError extends FlowChainSdkError {
  constructor(method: string, error?: FlowChainRpcErrorObject) {
    super("rpc_method_unavailable", `FlowChain RPC method is unavailable: ${method}.`, {
      method,
      rpcError: error,
    });
    this.name = "FlowChainRpcMethodUnavailableError";
  }
}

export class FlowChainMalformedEnvelopeError extends FlowChainSdkError {
  constructor(message: string, details?: JsonValue) {
    super("malformed_envelope", message, details);
    this.name = "FlowChainMalformedEnvelopeError";
  }
}

export class FlowChainUnsignedEnvelopeError extends FlowChainSdkError {
  constructor(message = "FlowChain transaction envelope is unsigned.") {
    super("unsigned_envelope", message);
    this.name = "FlowChainUnsignedEnvelopeError";
  }
}

export class FlowChainReplayRejectionError extends FlowChainSdkError {
  constructor(message: string, details?: JsonValue) {
    super("replay_rejection", message, details);
    this.name = "FlowChainReplayRejectionError";
  }
}

export class FlowChainNotFinalTransactionError extends FlowChainSdkError {
  constructor(message: string, details?: JsonValue) {
    super("not_final_transaction", message, details);
    this.name = "FlowChainNotFinalTransactionError";
  }
}

export class FlowChainBridgeNotReadyError extends FlowChainSdkError {
  constructor(missingNames: string[], message = "FlowChain bridge is not ready.") {
    super("bridge_not_ready", message, { missingNames });
    this.name = "FlowChainBridgeNotReadyError";
  }
}

export class FlowChainAccountNotFoundError extends FlowChainSdkError {
  constructor(accountId: string, error?: FlowChainRpcErrorObject) {
    super("account_not_found", `FlowChain account was not found: ${accountId}.`, { accountId, rpcError: error });
    this.name = "FlowChainAccountNotFoundError";
  }
}

export class FlowChainInsufficientBalanceError extends FlowChainSdkError {
  constructor(message: string, details?: JsonValue) {
    super("insufficient_balance", message, details);
    this.name = "FlowChainInsufficientBalanceError";
  }
}

export class FlowChainRpcError extends FlowChainSdkError {
  readonly code: number;
  readonly reasonCode?: string;

  constructor(method: string, error: FlowChainRpcErrorObject) {
    super("rpc_error", error.message, { method, rpcError: error });
    this.name = "FlowChainRpcError";
    this.code = error.code;
    this.reasonCode = error.data?.reasonCode;
  }
}

export function mapRpcError(method: string, params: JsonValue | undefined, error: FlowChainRpcErrorObject): FlowChainSdkError {
  const reasonCode = error.data?.reasonCode;
  const message = error.message.toLowerCase();

  if (error.code === -32601 || reasonCode === "method.not_found") {
    return new FlowChainRpcMethodUnavailableError(method, error);
  }
  if (reasonCode === "object.not_found" && method === "account_get") {
    const accountId = typeof params === "object" && params !== null && !Array.isArray(params) && typeof params.accountId === "string"
      ? params.accountId
      : "unknown";
    return new FlowChainAccountNotFoundError(accountId, error);
  }
  if (message.includes("unsigned")) {
    return new FlowChainUnsignedEnvelopeError(error.message);
  }
  if (message.includes("envelope") || message.includes("malformed")) {
    return new FlowChainMalformedEnvelopeError(error.message, { rpcError: error });
  }
  if (message.includes("replay")) {
    return new FlowChainReplayRejectionError(error.message, { rpcError: error });
  }
  if (message.includes("not final") || message.includes("not_final")) {
    return new FlowChainNotFinalTransactionError(error.message, { rpcError: error });
  }
  if (message.includes("insufficient")) {
    return new FlowChainInsufficientBalanceError(error.message, { rpcError: error });
  }
  return new FlowChainRpcError(method, error);
}
