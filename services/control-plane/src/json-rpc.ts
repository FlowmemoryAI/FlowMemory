import { findSecret } from "../../shared/src/index.ts";
import { CONTROL_PLANE_METHODS, callControlPlaneMethod } from "./methods.ts";
import { JSON_RPC_ERROR_CODES, ControlPlaneError, methodNotFound, rpcError, secretRejected } from "./errors.ts";
import type {
  ControlPlaneContext,
  JsonValue,
  RpcRequest,
  RpcResponse,
} from "./types.ts";

function isObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function invalidRequest(id: string | number | null, message: string): RpcResponse {
  return {
    jsonrpc: "2.0",
    id,
    error: rpcError(new ControlPlaneError(
      JSON_RPC_ERROR_CODES.invalidRequest,
      message,
      "request.invalid",
    )),
  };
}

function requestId(value: Record<string, unknown>): string | number | null {
  const id = value.id;
  return typeof id === "string" || typeof id === "number" || id === null ? id : null;
}

export function dispatchJsonRpc(
  request: unknown,
  context: ControlPlaneContext = {},
): RpcResponse | RpcResponse[] | undefined {
  if (Array.isArray(request)) {
    const responses = request
      .map((entry) => dispatchJsonRpc(entry, context))
      .filter((entry): entry is RpcResponse => entry !== undefined && !Array.isArray(entry));
    return responses.length === 0 ? undefined : responses;
  }

  if (!isObject(request)) {
    return invalidRequest(null, "JSON-RPC request must be an object");
  }

  const id = requestId(request);
  if (request.jsonrpc !== "2.0" || typeof request.method !== "string") {
    return invalidRequest(id, "JSON-RPC request requires jsonrpc \"2.0\" and a string method");
  }

  if (!(request.method in CONTROL_PLANE_METHODS)) {
    return {
      jsonrpc: "2.0",
      id,
      error: rpcError(methodNotFound(`control-plane method not found: ${request.method}`, { method: request.method })),
    };
  }

  try {
    const result = callControlPlaneMethod(request.method, request.params as JsonValue | undefined, context);
    const finding = findSecret(result);
    if (finding !== null) {
      throw secretRejected("control-plane response contained secret-shaped material", finding);
    }
    if (!("id" in request)) {
      return undefined;
    }
    return {
      jsonrpc: "2.0",
      id,
      result,
    };
  } catch (error) {
    if (!("id" in request)) {
      return undefined;
    }
    return {
      jsonrpc: "2.0",
      id,
      error: rpcError(error),
    };
  }
}

export function parseJsonRpcPayload(payload: string): unknown {
  return JSON.parse(payload) as unknown;
}

export function dispatchJsonRpcString(payload: string, context: ControlPlaneContext = {}): string | undefined {
  const response = dispatchJsonRpc(parseJsonRpcPayload(payload), context);
  return response === undefined ? undefined : `${JSON.stringify(response)}\n`;
}
