import { createServer, type ServerResponse } from "node:http";
import { fileURLToPath } from "node:url";

import { dispatchJsonRpc } from "./json-rpc.ts";
import { loadControlPlaneState } from "./fixture-state.ts";

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

const getRoutes: Record<string, string> = {
  "/health": "health",
  "/state": "devnet_state",
  "/node/status": "node_status",
  "/peers": "peer_list",
  "/mempool": "mempool_list",
  "/blocks": "block_list",
  "/transactions": "transaction_list",
  "/accounts": "account_list",
  "/balances": "balance_list",
  "/faucet/events": "faucet_event_list",
  "/wallets": "wallet_metadata_list",
  "/agents": "agent_account_list",
  "/models": "model_passport_list",
  "/work-receipts": "work_receipt_list",
  "/artifacts/availability": "artifact_availability_list",
  "/verifier-modules": "verifier_module_list",
  "/verifier-reports": "verifier_report_list",
  "/memory-cells": "memory_cell_list",
  "/challenges": "challenge_list",
  "/finality": "finality_list",
  "/bridge/observations": "bridge_observation_list",
  "/bridge/deposits": "bridge_deposit_list",
  "/bridge/credits": "bridge_credit_list",
  "/withdrawals": "withdrawal_list",
};

function paramsFromSearch(searchParams: URLSearchParams): Record<string, string | number | boolean> {
  const params: Record<string, string | number | boolean> = {};
  for (const [key, value] of searchParams.entries()) {
    if (/^\d+$/.test(value) && key === "limit") {
      params[key] = Number(value);
    } else if (value === "true" || value === "false") {
      params[key] = value === "true";
    } else {
      params[key] = value;
    }
  }
  return params;
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
    if (req.method === "OPTIONS") {
      res.writeHead(204, jsonHeaders);
      res.end();
      return;
    }

    const url = new URL(req.url ?? "/", `http://${req.headers.host ?? `${options.host}:${options.port}`}`);
    if (req.method === "GET" && getRoutes[url.pathname] !== undefined) {
      const state = loadControlPlaneState();
      const method = getRoutes[url.pathname];
      const response = dispatchJsonRpc({
        jsonrpc: "2.0",
        id: method,
        method,
        params: paramsFromSearch(url.searchParams),
      }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    if (req.method !== "POST" || (url.pathname !== "/rpc" && url.pathname !== "/transactions" && url.pathname !== "/bridge/observations")) {
      writeJson(res, 404, { error: "not found" });
      return;
    }

    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("end", () => {
      try {
        const payload = JSON.parse(body) as unknown;
        const state = loadControlPlaneState();
        const rpcPayload = url.pathname === "/transactions"
          ? { jsonrpc: "2.0", id: "transaction_submit", method: "transaction_submit", params: payload }
          : url.pathname === "/bridge/observations"
            ? { jsonrpc: "2.0", id: "bridge_observation_submit", method: "bridge_observation_submit", params: payload }
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
