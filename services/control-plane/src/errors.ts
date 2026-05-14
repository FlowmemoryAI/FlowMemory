import type { JsonValue, RpcErrorObject } from "./types.ts";

export const JSON_RPC_ERROR_CODES = {
  invalidRequest: -32600,
  methodNotFound: -32601,
  invalidParams: -32602,
  internalError: -32603,
  objectNotFound: -32004,
  secretRejected: -32040,
  cryptoRejected: -32041,
} as const;

export class ControlPlaneError extends Error {
  readonly code: number;
  readonly reasonCode: string;
  readonly details?: JsonValue;

  constructor(code: number, message: string, reasonCode: string, details?: JsonValue) {
    super(message);
    this.name = "ControlPlaneError";
    this.code = code;
    this.reasonCode = reasonCode;
    this.details = details;
  }
}

export function invalidParams(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.invalidParams, message, "params.invalid", details);
}

export function objectNotFound(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.objectNotFound, message, "object.not_found", details);
}

export function methodNotFound(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.methodNotFound, message, "method.not_found", details);
}

export function secretRejected(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.secretRejected, message, "secret.rejected", details);
}

export function cryptoRejected(message: string, details?: JsonValue): ControlPlaneError {
  return new ControlPlaneError(JSON_RPC_ERROR_CODES.cryptoRejected, message, "crypto.rejected", details);
}

export function rpcError(error: unknown): RpcErrorObject {
  if (error instanceof ControlPlaneError) {
    return {
      code: error.code,
      message: error.message,
      data: {
        schema: "flowmemory.control_plane.error.v0",
        reasonCode: error.reasonCode,
        details: error.details,
        localOnly: true,
      },
    };
  }

  return {
    code: JSON_RPC_ERROR_CODES.internalError,
    message: error instanceof Error ? error.message : "internal control-plane error",
    data: {
      schema: "flowmemory.control_plane.error.v0",
      reasonCode: "internal.error",
      localOnly: true,
    },
  };
}
