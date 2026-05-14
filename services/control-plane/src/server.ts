import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { createEncryptedTestVault, exportLocalWalletPublicMetadata } from "../../../crypto/src/wallet.js";
import { dispatchJsonRpc } from "./json-rpc.ts";
import { loadControlPlaneState, resolveControlPlanePath } from "./fixture-state.ts";
import type { JsonObject } from "./types.ts";

interface ServerOptions {
  host: string;
  port: number;
}

const jsonHeaders = {
  "access-control-allow-headers": "content-type",
  "access-control-allow-methods": "GET,POST,OPTIONS",
  "access-control-allow-origin": "*",
  "content-type": "application/json",
};

function jsonResult(response: ReturnType<typeof dispatchJsonRpc>): unknown {
  return Array.isArray(response) ? response : response?.result ?? response;
}

function writeJson(res: ServerResponse, statusCode: number, body: unknown): void {
  res.writeHead(statusCode, jsonHeaders);
  res.end(`${JSON.stringify(body)}\n`);
}

function readRequestBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("error", reject);
    req.on("end", () => resolve(body));
  });
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

function parseWalletCreatePayload(payload: unknown): { label: string; password: string; chainId: string; replace: boolean } {
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
  };
}

function createLocalWallet(state: ReturnType<typeof loadControlPlaneState>, payload: unknown): JsonObject {
  const request = parseWalletCreatePayload(payload);
  const metadataPath = resolveControlPlanePath(state.paths.walletPublicMetadataPath);
  const walletDir = dirname(metadataPath);
  const metadataBase = basename(metadataPath).replace(/-public-metadata\.json$/i, "").replace(/\.json$/i, "");
  const vaultPath = join(walletDir, `${metadataBase}-vault.local.json`);
  mkdirSync(walletDir, { recursive: true });

  if (!request.replace && existsSync(vaultPath) && existsSync(metadataPath)) {
    return {
      ...publicWalletResult(state),
      schema: "flowmemory.control_plane.local_wallet_create_result.v0",
      created: false,
      alreadyExists: true,
      vaultPath,
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
      readRequestBody(req)
        .then((body) => {
          const payload = body.length > 0 ? JSON.parse(body) as unknown : {};
          writeJson(res, 200, createLocalWallet(state, payload));
        })
        .catch((error) => {
          writeJson(res, 400, {
            schema: "flowmemory.control_plane.local_wallet_create_error.v0",
            message: error instanceof Error ? error.message : "wallet creation failed",
            secretMaterialReturned: false,
            localOnly: true,
          });
        });
      return;
    }

    if (req.method === "GET" && req.url === "/bridge/observations") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "bridge-observations", method: "bridge_observation_list" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method !== "POST" || (req.url !== "/rpc" && req.url !== "/bridge/observations")) {
      writeJson(res, 404, { error: "not found" });
      return;
    }

    readRequestBody(req).then((body) => {
      try {
        const payload = JSON.parse(body) as unknown;
        const rpcPayload = req.url === "/bridge/observations"
          ? { jsonrpc: "2.0", id: "bridge-observation-submit", method: "bridge_observation_submit", params: { observation: payload } }
          : payload;
        const response = dispatchJsonRpc(rpcPayload, { state });
        if (response === undefined) {
          res.writeHead(204, jsonHeaders);
          res.end();
          return;
        }
        writeJson(res, 200, response);
      } catch (error) {
        writeJson(res, 400, {
          jsonrpc: "2.0",
          id: null,
          error: {
            code: -32700,
            message: error instanceof Error ? error.message : "parse error",
            data: {
              schema: "flowmemory.control_plane.error.v0",
              reasonCode: "parse.error",
              localOnly: true,
            },
          },
        });
      }
    }).catch((error) => {
      writeJson(res, 400, {
        jsonrpc: "2.0",
        id: null,
        error: {
          code: -32700,
          message: error instanceof Error ? error.message : "request read error",
          data: {
            schema: "flowmemory.control_plane.error.v0",
            reasonCode: "request.read_error",
            localOnly: true,
          },
        },
      });
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
