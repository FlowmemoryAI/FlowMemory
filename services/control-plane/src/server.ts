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
  const state = loadControlPlaneState();
  const server = createServer((req, res) => {
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

    if (req.method === "GET" && req.url === "/product-flow/status") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "product-flow-status", method: "product_flow_status" }, { state });
      writeJson(res, 200, jsonResult(response));
      return;
    }

    const requestUrl = req.url === undefined ? null : new URL(req.url, "http://127.0.0.1");
    const pilotRoutes: Record<string, { method: string; list: boolean }> = {
      "/pilot/status": { method: "pilot_status", list: false },
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
      const limit = requestUrl?.searchParams.get("limit");
      const response = dispatchJsonRpc({
        jsonrpc: "2.0",
        id: `pilot:${requestUrl?.pathname}`,
        method: pilotRoute.method,
        params: pilotRoute.list && limit !== null ? { limit: Number(limit) } : undefined,
      }, { state });
      writeJson(res, 200, jsonResult(response));
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

    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("end", () => {
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
