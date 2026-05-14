import { findSecret } from "../../shared/src/index.ts";
import type { JsonValue, RpcErrorObject } from "./types.ts";

export const JSON_RPC_ERROR_CODES = {
  parseError: -32700,
  invalidRequest: -32600,
  methodNotFound: -32601,
  invalidParams: -32602,
  internalError: -32603,
  objectNotFound: -32004,
  secretRejected: -32040,
  transactionRejected: -32041,
  runtimeUnavailable: -32042,
  storageUnavailable: -32043,
} as const;

export type ControlPlaneErrorCode =
  | "MALFORMED_REQUEST"
  | "UNSIGNED_TRANSACTION"
  | "BAD_SIGNATURE"
  | "WRONG_CHAIN_ID"
  | "STALE_NONCE"
  | "DUPLICATE_TX"
  | "UNKNOWN_BLOCK"
  | "UNKNOWN_TX"
  | "UNKNOWN_ACCOUNT"
  | "UNKNOWN_TOKEN"
  | "UNKNOWN_POOL"
  | "BRIDGE_REPLAY"
  | "LIVE_RUNTIME_UNAVAILABLE"
  | "STORAGE_UNAVAILABLE"
  | "UNSAFE_SECRET_DETECTED"
  | "METHOD_NOT_FOUND"
  | "INTERNAL_ERROR";

export class ControlPlaneError extends Error {
  readonly code: number;
  readonly reasonCode: string;
  readonly errorCode: ControlPlaneErrorCode;
  readonly details?: JsonValue;
  readonly recoverable: boolean;
  readonly retryable: boolean;
  readonly sourceComponent: string;

  constructor(
    code: number,
    message: string,
    reasonCode: string,
    details?: JsonValue,
    errorCode: ControlPlaneErrorCode = "MALFORMED_REQUEST",
    recoverable = true,
    retryable = false,
    sourceComponent = "control-plane",
  ) {
    super(message);
    this.name = "ControlPlaneError";
    this.code = code;
    this.reasonCode = reasonCode;
    this.errorCode = errorCode;
    this.details = details;
    this.recoverable = recoverable;
    this.retryable = retryable;
    this.sourceComponent = sourceComponent;
  }
}

export function invalidParams(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.invalidParams, message, "params.invalid", details, "MALFORMED_REQUEST");
}

export function objectNotFound(
  message: string,
  details?: JsonValue,
  errorCode: ControlPlaneErrorCode = "MALFORMED_REQUEST",
): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.objectNotFound, message, "object.not_found", details, errorCode, true, false);
}

export function methodNotFound(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.methodNotFound, message, "method.not_found", details, "METHOD_NOT_FOUND");
}

export function secretRejected(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.secretRejected, message, "secret.rejected", details, "UNSAFE_SECRET_DETECTED", false, false);
}

export function unsignedTransaction(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.transactionRejected, message, "transaction.unsigned", details, "UNSIGNED_TRANSACTION");
}

export function badSignature(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.transactionRejected, message, "transaction.bad_signature", details, "BAD_SIGNATURE");
}

export function wrongChainId(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.transactionRejected, message, "transaction.wrong_chain_id", details, "WRONG_CHAIN_ID");
}

export function staleNonce(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.transactionRejected, message, "transaction.stale_nonce", details, "STALE_NONCE");
}

export function duplicateTx(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.transactionRejected, message, "transaction.duplicate", details, "DUPLICATE_TX");
}

export function bridgeReplay(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.transactionRejected, message, "bridge.replay", details, "BRIDGE_REPLAY");
}

export function liveRuntimeUnavailable(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.runtimeUnavailable, message, "runtime.unavailable", details, "LIVE_RUNTIME_UNAVAILABLE", true, true, "runtime");
}

export function storageUnavailable(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.storageUnavailable, message, "storage.unavailable", details, "STORAGE_UNAVAILABLE", true, true, "storage");
}

function safeErrorMessage(error: unknown): string {
  if (!(error instanceof Error)) {
    return "internal control-plane error";
  }
  return findSecret(error.message) === null ? error.message : "internal control-plane error";
}

function safeDetails(details: JsonValue | undefined): JsonValue | undefined {
  if (details === undefined) {
    return undefined;
  }
  return findSecret(details) === null ? details : { redacted: true, reason: "secret-shaped error details" };
}

export function rpcError(error: unknown, correlationId = "control-plane-local"): RpcErrorObject {
  if (error instanceof ControlPlaneError) {
    return {
      code: error.code,
      message: error.message,
      data: {
        schema: "flowmemory.control_plane.error.v1",
        reasonCode: error.reasonCode,
        errorCode: error.errorCode,
        message: error.message,
        correlationId,
        recoverable: error.recoverable,
        retryable: error.retryable,
        sourceComponent: error.sourceComponent,
        details: safeDetails(error.details),
        localOnly: true,
      },
    };
  }

  return {
    code: JSON_RPC_ERROR_CODES.internalError,
    message: safeErrorMessage(error),
    data: {
      schema: "flowmemory.control_plane.error.v1",
      reasonCode: "internal.error",
      errorCode: "INTERNAL_ERROR",
      message: "internal control-plane error",
      correlationId,
      recoverable: false,
      retryable: false,
      sourceComponent: "control-plane",
      localOnly: true,
    },
  };
}
