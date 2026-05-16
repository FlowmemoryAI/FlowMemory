import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { createEncryptedTestVault, exportLocalWalletPublicMetadata } from "../../../crypto/src/wallet.js";
import { dispatchJsonRpc } from "./json-rpc.ts";
import { loadControlPlaneState, resolveControlPlanePath } from "./fixture-state.ts";
import { isPublicRpcMethod } from "./methods.ts";
import { executeWalletSend } from "./wallet-runtime.ts";
import type { ControlPlaneContext, JsonObject, RpcResponse } from "./types.ts";

interface ServerOptions {
  host: string;
  port: number;
}

const jsonHeaders = {
  "access-control-allow-headers": "content-type",
  "access-control-allow-methods": "GET,POST,OPTIONS",
  "content-type": "application/json",
};
const RATE_LIMIT_WINDOW_MS = 60_000;
const MAX_REQUEST_BODY_BYTES = 256 * 1024;
const MAX_JSON_RPC_BATCH_REQUESTS = 50;
const rateLimitBuckets = new Map<string, { windowStartedAtMs: number; count: number }>();

class HttpRequestError extends Error {
  readonly statusCode: number;
  readonly schema: string;
  readonly reasonCode: string;

  constructor(statusCode: number, schema: string, reasonCode: string, message: string) {
    super(message);
    this.statusCode = statusCode;
    this.schema = schema;
    this.reasonCode = reasonCode;
  }
}

function jsonResult(response: ReturnType<typeof dispatchJsonRpc>): unknown {
  return Array.isArray(response) ? response : response?.result ?? response;
}

function writeJson(res: ServerResponse, statusCode: number, body: unknown): void {
  res.writeHead(statusCode, jsonHeaders);
  res.end(`${JSON.stringify(body)}\n`);
}

function writeRequestError(res: ServerResponse, error: unknown, fallbackMessage: string): void {
  if (error instanceof HttpRequestError) {
    writeJson(res, error.statusCode, {
      schema: error.schema,
      message: error.message,
      reasonCode: error.reasonCode,
      localOnly: true,
      envValuesPrinted: false,
      noSecrets: true,
    });
    return;
  }

  writeJson(res, 400, {
    schema: "flowmemory.control_plane.request_error.v0",
    message: error instanceof Error ? error.message : fallbackMessage,
    reasonCode: "request.read_error",
    localOnly: true,
    envValuesPrinted: false,
    noSecrets: true,
  });
}

function jsonRpcHttpError(
  code: number,
  message: string,
  reasonCode: string,
  data: JsonObject = {},
  id: string | number | null = null,
): JsonObject {
  return {
    jsonrpc: "2.0",
    id,
    error: {
      code,
      message,
      data: {
        schema: "flowmemory.control_plane.error.v0",
        reasonCode,
        localOnly: true,
        envValuesPrinted: false,
        noSecrets: true,
        ...data,
      },
    },
  };
}

function isJsonObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function jsonRpcRequestId(value: Record<string, unknown>): string | number | null {
  const id = value.id;
  return typeof id === "string" || typeof id === "number" || id === null ? id : null;
}

function publicRpcMethodNotFound(request: Record<string, unknown>): RpcResponse | undefined {
  if (!("id" in request)) {
    return undefined;
  }
  const method = typeof request.method === "string" ? request.method : "";
  return jsonRpcHttpError(
    -32601,
    `control-plane method not found: ${method}`,
    "method.not_found",
    { method },
    jsonRpcRequestId(request),
  ) as RpcResponse;
}

function dispatchPublicJsonRpc(request: unknown, context: ControlPlaneContext): RpcResponse | RpcResponse[] | undefined {
  if (Array.isArray(request)) {
    const responses = request
      .map((entry) => dispatchPublicJsonRpc(entry, context))
      .filter((entry): entry is RpcResponse => entry !== undefined && !Array.isArray(entry));
    return responses.length === 0 ? undefined : responses;
  }

  if (isJsonObject(request) && request.jsonrpc === "2.0" && typeof request.method === "string" && !isPublicRpcMethod(request.method)) {
    return publicRpcMethodNotFound(request);
  }

  return dispatchJsonRpc(request, context);
}

function isJsonContentType(req: IncomingMessage): boolean {
  const raw = req.headers["content-type"];
  const contentType = Array.isArray(raw) ? raw[0] : raw;
  if (typeof contentType !== "string") {
    return false;
  }
  const mediaType = contentType.split(";")[0]?.trim().toLowerCase();
  return mediaType === "application/json" || (mediaType?.endsWith("+json") ?? false);
}

function requireJsonContentType(req: IncomingMessage, res: ServerResponse): boolean {
  if (isJsonContentType(req)) {
    return true;
  }
  writeJson(res, 415, {
    schema: "flowmemory.control_plane.unsupported_media_type.v0",
    message: "POST requests must use application/json",
    reasonCode: "request.unsupported_media_type",
    localOnly: true,
    envValuesPrinted: false,
    noSecrets: true,
  });
  return false;
}

function configuredAllowedOrigins(): string[] {
  return (process.env.FLOWCHAIN_RPC_ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

function applyCorsHeaders(req: IncomingMessage, res: ServerResponse): boolean {
  const allowedOrigins = configuredAllowedOrigins();
  const requestOrigin = req.headers.origin;
  if (allowedOrigins.length === 0 || allowedOrigins.includes("*")) {
    res.setHeader("access-control-allow-origin", "*");
    return true;
  }
  if (typeof requestOrigin === "string" && allowedOrigins.includes(requestOrigin)) {
    res.setHeader("access-control-allow-origin", requestOrigin);
    res.setHeader("vary", "Origin");
    return true;
  }
  return requestOrigin === undefined;
}

function configuredRateLimitPerMinute(): number | null {
  const raw = process.env.FLOWCHAIN_RPC_RATE_LIMIT_PER_MINUTE;
  if (raw === undefined || raw.trim().length === 0 || !/^[1-9][0-9]*$/.test(raw.trim())) {
    return null;
  }
  return Number(raw.trim());
}

function rateLimitClientKey(req: IncomingMessage): string {
  const forwardedFor = req.headers["x-forwarded-for"];
  const forwarded = Array.isArray(forwardedFor) ? forwardedFor[0] : forwardedFor;
  const forwardedChain = typeof forwarded === "string"
    ? forwarded.split(",").map((entry) => entry.trim()).filter((entry) => entry.length > 0)
    : [];
  const candidate = forwardedChain.length > 0
    ? forwardedChain[forwardedChain.length - 1]
    : req.socket.remoteAddress;
  return candidate && candidate.length > 0 ? candidate : "unknown";
}

function applyRateLimit(req: IncomingMessage, res: ServerResponse): boolean {
  const limit = configuredRateLimitPerMinute();
  if (limit === null) {
    return true;
  }
  const now = Date.now();
  const key = rateLimitClientKey(req);
  const bucket = rateLimitBuckets.get(key);
  if (bucket === undefined || now - bucket.windowStartedAtMs >= RATE_LIMIT_WINDOW_MS) {
    rateLimitBuckets.set(key, { windowStartedAtMs: now, count: 1 });
    return true;
  }
  if (bucket.count >= limit) {
    const retryAfterSeconds = Math.max(1, Math.ceil((RATE_LIMIT_WINDOW_MS - (now - bucket.windowStartedAtMs)) / 1000));
    res.setHeader("retry-after", String(retryAfterSeconds));
    writeJson(res, 429, {
      schema: "flowmemory.control_plane.rate_limited.v0",
      message: "rate limit exceeded",
      retryAfterSeconds,
      envValuesPrinted: false,
      noSecrets: true,
    });
    return false;
  }
  bucket.count += 1;
  return true;
}

function readRequestBody(req: IncomingMessage, maxBytes = MAX_REQUEST_BODY_BYTES): Promise<string> {
  return new Promise((resolve, reject) => {
    let body = "";
    let receivedBytes = 0;
    let exceededLimit = false;
    const declaredLength = req.headers["content-length"];
    const contentLength = Array.isArray(declaredLength) ? declaredLength[0] : declaredLength;
    if (typeof contentLength === "string" && /^\d+$/.test(contentLength) && Number(contentLength) > maxBytes) {
      exceededLimit = true;
    }
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      receivedBytes += Buffer.byteLength(chunk, "utf8");
      if (receivedBytes > maxBytes) {
        exceededLimit = true;
        return;
      }
      if (!exceededLimit) {
        body += chunk;
      }
    });
    req.on("error", reject);
    req.on("end", () => {
      if (exceededLimit) {
        reject(new HttpRequestError(
          413,
          "flowmemory.control_plane.payload_too_large.v0",
          "request.payload_too_large",
          `request body exceeded ${maxBytes} bytes`,
        ));
        return;
      }
      resolve(body);
    });
  });
}

function validateJsonRpcHttpPayload(payload: unknown, res: ServerResponse): boolean {
  if (!Array.isArray(payload)) {
    return true;
  }
  if (payload.length === 0) {
    writeJson(res, 400, jsonRpcHttpError(
      -32600,
      "JSON-RPC batch request must not be empty",
      "request.batch_empty",
    ));
    return false;
  }
  if (payload.length > MAX_JSON_RPC_BATCH_REQUESTS) {
    writeJson(res, 413, jsonRpcHttpError(
      -32000,
      `JSON-RPC batch request exceeds ${MAX_JSON_RPC_BATCH_REQUESTS} entries`,
      "request.batch_too_large",
      { maxBatchRequests: MAX_JSON_RPC_BATCH_REQUESTS },
    ));
    return false;
  }
  return true;
}

function publicWalletResult(state: ReturnType<typeof loadControlPlaneState>): JsonObject {
  const metadata = state.walletPublicMetadata;
  const accounts = Array.isArray(metadata?.accounts) ? metadata.accounts : [];
  const primaryAccount = accounts.find((entry): entry is JsonObject =>
    entry !== null && typeof entry === "object" && !Array.isArray(entry),
  ) ?? null;
  return {
    schema: "flowmemory.control_plane.local_wallet_public_status.v0",
    exists: metadata !== null,
    metadataPath: resolveControlPlanePath(state.paths.walletPublicMetadataPath),
    account: primaryAccount,
    accounts: accounts as JsonObject[],
    secretMaterialReturned: false,
    localOnly: true,
  };
}

function labelSlug(value: unknown): string {
  const label = typeof value === "string" && value.trim().length > 0 ? value.trim() : "flowchain-operator";
  const slug = label.toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^-+|-+$/g, "");
  return slug.length > 0 ? slug.slice(0, 64) : "flowchain-operator";
}

function parseWalletCreatePayload(payload: unknown): { label: string; password: string; chainId: string; replace: boolean; isolated: boolean } {
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("wallet creation payload must be an object");
  }
  const record = payload as Record<string, unknown>;
  const password = typeof record.password === "string" ? record.password : "";
  if (password.length < 8) {
    throw new Error("wallet vault passphrase must be at least 8 characters");
  }
  const chainId = typeof record.chainId === "string" && /^\d+$/.test(record.chainId) ? record.chainId : "31337";
  return {
    label: labelSlug(record.label),
    password,
    chainId,
    replace: record.replace === true,
    isolated: record.isolated === true || record.localTester === true,
  };
}

function createLocalWallet(state: ReturnType<typeof loadControlPlaneState>, payload: unknown): JsonObject {
  const request = parseWalletCreatePayload(payload);
  const operatorMetadataPath = resolveControlPlanePath(state.paths.walletPublicMetadataPath);
  const walletDir = dirname(operatorMetadataPath);
  const metadataBase = request.isolated
    ? request.label
    : basename(operatorMetadataPath).replace(/-public-metadata\.json$/i, "").replace(/\.json$/i, "");
  const walletTargetDir = request.isolated ? join(walletDir, "local-testers") : walletDir;
  const metadataPath = request.isolated
    ? join(walletTargetDir, `${metadataBase}-public-metadata.json`)
    : operatorMetadataPath;
  const vaultPath = join(walletTargetDir, `${metadataBase}-vault.local.json`);
  mkdirSync(walletTargetDir, { recursive: true });

  if (!request.replace && existsSync(vaultPath) && existsSync(metadataPath)) {
    const existingMetadata = request.isolated
      ? JSON.parse(readFileSync(metadataPath, "utf8")) as JsonObject
      : null;
    const existingAccounts = Array.isArray(existingMetadata?.accounts) ? existingMetadata.accounts as JsonObject[] : [];
    const existingResult = request.isolated
      ? {
          schema: "flowmemory.control_plane.local_wallet_public_status.v0",
          exists: true,
          metadataPath,
          account: existingAccounts[0] ?? null,
          accounts: existingAccounts,
          secretMaterialReturned: false,
          localOnly: true,
        }
      : publicWalletResult(state);
    return {
      ...existingResult,
      schema: "flowmemory.control_plane.local_wallet_create_result.v0",
      created: false,
      alreadyExists: true,
      vaultPath,
      metadataPath,
      walletLabel: request.label,
      isolated: request.isolated,
      note: "Existing encrypted local wallet vault was left unchanged. Set replace=true to rotate to a new wallet.",
    };
  }

  const vault = createEncryptedTestVault({
    password: request.password,
    label: request.label,
    signerRole: "operator",
    chainId: request.chainId,
  });
  const metadata = exportLocalWalletPublicMetadata(vault);
  writeFileSync(vaultPath, `${JSON.stringify(vault, null, 2)}\n`);
  writeFileSync(metadataPath, `${JSON.stringify(metadata, null, 2)}\n`);

  const account = Array.isArray(metadata.accounts) ? metadata.accounts[0] as JsonObject : null;
  return {
    schema: "flowmemory.control_plane.local_wallet_create_result.v0",
    created: true,
    alreadyExists: false,
    walletLabel: request.label,
    isolated: request.isolated,
    account,
    accounts: metadata.accounts as JsonObject[],
    vaultPath,
    metadataPath,
    chainId: request.chainId,
    keyScheme: account?.keyScheme ?? "secp256k1",
    secretMaterialReturned: false,
    credentialStored: false,
    localOnly: true,
  };
}

function listParamsFromUrl(requestUrl: URL | null): Record<string, string | number> | undefined {
  if (requestUrl === null) {
    return undefined;
  }

  const params: Record<string, string | number> = {};
  const limit = requestUrl.searchParams.get("limit");
  if (limit !== null) {
    params.limit = Number(limit);
  }

  for (const name of ["baseTxHash", "txHash", "creditId", "walletAddress", "wallet", "accountId", "recipientWallet", "status", "query"]) {
    const value = requestUrl.searchParams.get(name);
    if (value !== null && value.length > 0) {
      params[name] = value;
    }
  }

  return Object.keys(params).length > 0 ? params : undefined;
}

function parseArgs(args: string[]): ServerOptions {
  const options: ServerOptions = {
    host: "127.0.0.1",
    port: 8787,
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--host") {
      const value = args[index + 1];
      if (value === undefined) {
        throw new Error("--host requires a value");
      }
      options.host = value;
      index += 1;
      continue;
    }
    if (arg === "--port") {
      const value = args[index + 1];
      if (value === undefined || !/^\d+$/.test(value)) {
        throw new Error("--port requires a numeric value");
      }
      options.port = Number(value);
      index += 1;
      continue;
    }
    throw new Error(`unknown option: ${arg}`);
  }

  return options;
}

export function startControlPlaneServer(options: ServerOptions): ReturnType<typeof createServer> {
  const server = createServer((req, res) => {
    const state = loadControlPlaneState();
    const corsAllowed = applyCorsHeaders(req, res);
    if (!corsAllowed) {
      writeJson(res, 403, {
        schema: "flowmemory.control_plane.cors_rejected.v0",
        message: "origin is not allowed",
        localOnly: true,
      });
      return;
    }
    if (!applyRateLimit(req, res)) {
      return;
    }

    if (req.method === "OPTIONS") {
      res.writeHead(204, jsonHeaders);
      res.end();
      return;
    }

    if (req.method === "GET" && req.url === "/health") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "health", method: "health" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && req.url === "/rpc/discover") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "rpc-discover", method: "rpc_discover" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && req.url === "/rpc/readiness") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "rpc-readiness", method: "rpc_readiness" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && req.url === "/state") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "state", method: "devnet_state" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && req.url === "/explorer/summary") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "explorer-summary", method: "chain_status" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && req.url === "/chain/status") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "chain-status", method: "chain_status" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && req.url === "/product-flow/status") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "product-flow-status", method: "product_flow_status" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    const requestUrl = req.url === undefined ? null : new URL(req.url, "http://127.0.0.1");
    const pilotRoutes: Record<string, { method: string; list: boolean }> = {
      "/pilot/status": { method: "pilot_status", list: false },
      "/pilot/lifecycle": { method: "pilot_lifecycle_record_list", list: true },
      "/pilot/deposits": { method: "pilot_deposit_observation_list", list: true },
      "/pilot/credits": { method: "pilot_credit_list", list: true },
      "/pilot/withdrawal-intents": { method: "pilot_withdrawal_intent_list", list: true },
      "/pilot/release-evidence": { method: "pilot_release_evidence_list", list: true },
      "/pilot/cap-status": { method: "pilot_cap_status", list: false },
      "/pilot/pause-status": { method: "pilot_pause_status", list: false },
      "/pilot/retry-status": { method: "pilot_retry_status", list: false },
      "/pilot/emergency-status": { method: "pilot_emergency_status", list: false },
    };
    const pilotRoute = requestUrl === null ? undefined : pilotRoutes[requestUrl.pathname];
    if (req.method === "GET" && pilotRoute !== undefined) {
      const response = dispatchJsonRpc({
        jsonrpc: "2.0",
        id: `pilot:${requestUrl?.pathname}`,
        method: pilotRoute.method,
        params: pilotRoute.list ? listParamsFromUrl(requestUrl) : undefined,
      }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && requestUrl?.pathname === "/bridge/live-readiness") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "bridge-live-readiness", method: "bridge_live_readiness" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && requestUrl?.pathname === "/bridge/status") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "bridge-status", method: "bridge_status" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && requestUrl?.pathname === "/bridge/credits") {
      const response = dispatchJsonRpc({
        jsonrpc: "2.0",
        id: "bridge-credits",
        method: "bridge_credit_list",
        params: listParamsFromUrl(requestUrl),
      }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && requestUrl?.pathname === "/bridge/credit-status") {
      const response = dispatchJsonRpc({
        jsonrpc: "2.0",
        id: "bridge-credit-status",
        method: "bridge_credit_status",
        params: listParamsFromUrl(requestUrl),
      }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && requestUrl?.pathname === "/wallets/balances") {
      const response = dispatchJsonRpc({
        jsonrpc: "2.0",
        id: "wallet-balances",
        method: "wallet_balance_list",
        params: listParamsFromUrl(requestUrl),
      }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && requestUrl?.pathname === "/wallets/transfers") {
      const response = dispatchJsonRpc({
        jsonrpc: "2.0",
        id: "wallet-transfers",
        method: "wallet_transfer_history",
        params: listParamsFromUrl(requestUrl),
      }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "GET" && requestUrl?.pathname === "/wallets/operator") {
      writeJson(res, 200, publicWalletResult(state));
      return;
    }

    if (req.method === "POST" && requestUrl?.pathname === "/wallets/create") {
      if (!requireJsonContentType(req, res)) {
        return;
      }
      readRequestBody(req)
        .then((body) => {
          const payload = body.length > 0 ? JSON.parse(body) as unknown : {};
          writeJson(res, 200, createLocalWallet(state, payload));
        })
        .catch((error) => {
          if (error instanceof HttpRequestError) {
            writeRequestError(res, error, "wallet creation failed");
            return;
          }
          writeJson(res, 400, {
            schema: "flowmemory.control_plane.local_wallet_create_error.v0",
            message: error instanceof Error ? error.message : "wallet creation failed",
            secretMaterialReturned: false,
            localOnly: true,
          });
        });
      return;
    }

    if (req.method === "POST" && requestUrl?.pathname === "/wallets/send") {
      if (!requireJsonContentType(req, res)) {
        return;
      }
      readRequestBody(req)
        .then((body) => {
          const payload = body.length > 0 ? JSON.parse(body) as unknown : {};
          writeJson(res, 200, executeWalletSend(state, payload));
        })
        .catch((error) => {
          if (error instanceof HttpRequestError) {
            writeRequestError(res, error, "wallet send failed");
            return;
          }
          writeJson(res, 400, {
            schema: "flowmemory.control_plane.wallet_send_error.v0",
            accepted: false,
            message: error instanceof Error ? error.message : "wallet send failed",
            localOnly: true,
            productionReady: false,
          });
        });
      return;
    }

    if (req.method === "GET" && req.url === "/bridge/observations") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "bridge-observations", method: "bridge_observation_list" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method === "POST" && requestUrl?.pathname === "/bridge/observations") {
      writeJson(res, 200, jsonRpcHttpError(
        -32601,
        "control-plane method not found: bridge_observation_submit",
        "method.not_found",
        { method: "bridge_observation_submit" },
      ));
      return;
    }

    if (req.method !== "POST" || req.url !== "/rpc") {
      writeJson(res, 404, { error: "not found" });
      return;
    }

    if (!requireJsonContentType(req, res)) {
      return;
    }

    readRequestBody(req).then((body) => {
      try {
        const payload = JSON.parse(body) as unknown;
        if (req.url === "/rpc" && !validateJsonRpcHttpPayload(payload, res)) {
          return;
        }
        const response = dispatchPublicJsonRpc(payload, { state });
        if (response === undefined) {
          res.writeHead(204, jsonHeaders);
          res.end();
          return;
        }
        writeJson(res, 200, response);
      } catch (error) {
        writeJson(res, 400, jsonRpcHttpError(
          -32700,
          error instanceof Error ? error.message : "parse error",
          "parse.error",
        ));
      }
    }).catch((error) => {
      if (error instanceof HttpRequestError) {
        writeRequestError(res, error, "request read error");
        return;
      }
      writeJson(res, 400, jsonRpcHttpError(
        -32700,
        error instanceof Error ? error.message : "request read error",
        "request.read_error",
      ));
    });
  });

  server.listen(options.port, options.host, () => {
    const address = server.address();
    const port = typeof address === "object" && address !== null ? address.port : options.port;
    const host = typeof address === "object" && address !== null ? address.address : options.host;
    console.log(JSON.stringify({
      service: "flowmemory-control-plane-v0",
      url: `http://${host}:${port}/rpc`,
      localOnly: true,
    }, null, 2));
  });
  return server;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  startControlPlaneServer(parseArgs(process.argv.slice(2)));
}
