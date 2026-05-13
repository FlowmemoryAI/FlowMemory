import { createServer } from "node:http";
import { fileURLToPath } from "node:url";

import { dispatchJsonRpc } from "./json-rpc.ts";
import { loadControlPlaneState } from "./fixture-state.ts";

interface ServerOptions {
  host: string;
  port: number;
}

function parseArgs(args: string[]): ServerOptions {
  const options: ServerOptions = {
    host: "127.0.0.1",
    port: 8675,
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
    if (req.method === "GET" && req.url === "/health") {
      const response = dispatchJsonRpc({ jsonrpc: "2.0", id: "health", method: "health" }, { state });
      res.writeHead(200, { "content-type": "application/json" });
      res.end(`${JSON.stringify(Array.isArray(response) ? response : response?.result ?? response)}\n`);
      return;
    }

    if (req.method !== "POST" || req.url !== "/rpc") {
      res.writeHead(404, { "content-type": "application/json" });
      res.end(JSON.stringify({ error: "not found" }));
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
        const response = dispatchJsonRpc(payload, { state });
        if (response === undefined) {
          res.writeHead(204);
          res.end();
          return;
        }
        res.writeHead(200, { "content-type": "application/json" });
        res.end(`${JSON.stringify(response)}\n`);
      } catch (error) {
        res.writeHead(400, { "content-type": "application/json" });
        res.end(JSON.stringify({
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
        }));
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
