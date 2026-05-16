import { fileURLToPath } from "node:url";

import { FlowChainClient, FlowChainRpcError, type JsonValue } from "./client.ts";
import { redactJsonValue } from "./redact.ts";

interface CliOptions {
  command: string;
  rpcUrl: string;
  json: boolean;
  limit: number;
}

const COMMANDS = new Set([
  "discover",
  "readiness",
  "status",
  "wallet-balances",
  "wallet-transfers",
  "bridge-readiness",
  "bridge-status",
  "diagnostics",
  "help",
]);

function parseArgs(argv: string[]): CliOptions {
  const args = [...argv];
  const command = args.shift() ?? "help";
  let rpcUrl = process.env.FLOWCHAIN_RPC_URL ?? "http://127.0.0.1:8787/rpc";
  let json = false;
  let limit = 10;
  while (args.length > 0) {
    const arg = args.shift();
    if (arg === "--json") {
      json = true;
    } else if (arg === "--rpc") {
      rpcUrl = args.shift() ?? rpcUrl;
    } else if (arg === "--limit") {
      limit = Number.parseInt(args.shift() ?? "10", 10);
    } else if (arg !== undefined) {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!COMMANDS.has(command)) throw new Error(`unknown command: ${command}`);
  return { command, rpcUrl, json, limit };
}

function printHelp() {
  console.log(`FlowChain devkit

Usage:
  npm run flowchain:devkit -- <command> [--rpc <url>] [--json]

Commands:
  discover          Print RPC discovery
  readiness         Print public/live readiness
  status            Print chain status
  wallet-balances   Print wallet balance rows
  wallet-transfers  Print wallet transfer history
  bridge-readiness  Print bridge live readiness
  bridge-status     Print bridge status
  diagnostics       Print public-safe SDK diagnostics
`);
}

function printResult(value: JsonValue, json: boolean) {
  const redacted = redactJsonValue(value);
  if (json) {
    console.log(JSON.stringify(redacted, null, 2));
    return;
  }
  console.log(JSON.stringify(redacted, null, 2));
}

async function run(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  if (options.command === "help") {
    printHelp();
    return;
  }
  const client = new FlowChainClient({ rpcUrl: options.rpcUrl });
  const params = { limit: options.limit } as JsonValue;
  const result = await (async () => {
    switch (options.command) {
      case "discover":
        return client.rpcDiscover();
      case "readiness":
        return client.rpcReadiness();
      case "status":
        return client.chainStatus();
      case "wallet-balances":
        return client.walletBalances(params);
      case "wallet-transfers":
        return client.walletTransfers(params);
      case "bridge-readiness":
        return client.bridgeReadiness();
      case "bridge-status":
        return client.bridgeStatus();
      case "diagnostics":
        return {
          schema: "flowchain.sdk.diagnostics.v0",
          rpcUrl: options.rpcUrl.replace(/^(https?:\/\/)([^/@]+@)?/i, "$1"),
          discover: await client.rpcDiscover(),
          readiness: await client.rpcReadiness(),
        } satisfies JsonValue;
      default:
        throw new Error(`unsupported command: ${options.command}`);
    }
  })();
  printResult(result, options.json);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  run().catch((error) => {
    if (error instanceof FlowChainRpcError) {
      printResult({
        schema: "flowchain.sdk.error.v0",
        status: "failed",
        code: error.code,
        message: error.message,
        data: error.data ?? null,
      }, true);
    } else {
      printResult({
        schema: "flowchain.sdk.error.v0",
        status: "failed",
        message: error instanceof Error ? error.message : String(error),
      }, true);
    }
    process.exitCode = 1;
  });
}

export { run };
