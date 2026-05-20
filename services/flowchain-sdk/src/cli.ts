import { existsSync, readFileSync } from "node:fs";
import { isAbsolute, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { FlowChainClient, FlowChainRpcError, type JsonValue, type SignedTransactionSubmitRequest } from "./client.ts";
import { redactJsonValue } from "./redact.ts";

interface CliOptions {
  command: string;
  rpcUrl: string;
  json: boolean;
  limit: number;
  id?: string;
  accountId?: string;
  blockNumber?: string;
  blockHash?: string;
  txId?: string;
  txHash?: string;
  walletId?: string;
  creditId?: string;
  depositId?: string;
  withdrawalId?: string;
  objectId?: string;
  status?: string;
  seconds: number;
  fromAccountId?: string;
  toAccountId?: string;
  amountUnits?: string;
  memo?: string;
  pollMs: number;
  signedEnvelopeInput?: string;
  runtimeTransactionInput?: string;
  submittedBy?: string;
  expectedNonce?: string;
  runtimeSubmit: boolean;
  runtimeSubmitMode?: "off" | "direct" | "node-inbox";
}

const COMMANDS = new Set([
  "discover",
  "readiness",
  "health",
  "node-status",
  "peers",
  "status",
  "watch-height",
  "blocks",
  "block",
  "transactions",
  "transaction",
  "mempool",
  "accounts",
  "account",
  "balance",
  "wallet-metadata",
  "wallet-metadata-get",
  "wallet-balances",
  "wallet-transfers",
  "faucet-events",
  "finality",
  "finality-get",
  "bridge-readiness",
  "bridge-status",
  "bridge-deposits",
  "bridge-deposit",
  "bridge-credits",
  "bridge-credit",
  "bridge-credit-status",
  "withdrawals",
  "withdrawal",
  "wallet-send",
  "submit-signed-transaction",
  "wait-transaction",
  "diagnostics",
  "help",
]);

function parseArgs(argv: string[]): CliOptions {
  const args = [...argv];
  const command = args.shift() ?? "help";
  let rpcUrl = process.env.FLOWCHAIN_RPC_URL ?? "http://127.0.0.1:8787/rpc";
  let json = false;
  let limit = 10;
  let seconds = 20;
  let pollMs = 1000;
  let runtimeSubmit = false;
  const options: Partial<CliOptions> = {};
  while (args.length > 0) {
    const arg = args.shift();
    if (arg === "--json") {
      json = true;
    } else if (arg === "--rpc") {
      rpcUrl = args.shift() ?? rpcUrl;
    } else if (arg === "--limit") {
      limit = Number.parseInt(args.shift() ?? "10", 10);
    } else if (arg === "--seconds") {
      seconds = Number.parseInt(args.shift() ?? "20", 10);
    } else if (arg === "--poll-ms") {
      pollMs = Number.parseInt(args.shift() ?? "1000", 10);
    } else if (arg === "--id") {
      options.id = args.shift();
    } else if (arg === "--account") {
      options.accountId = args.shift();
    } else if (arg === "--block") {
      const value = args.shift();
      if (value?.startsWith("0x")) options.blockHash = value;
      else options.blockNumber = value;
    } else if (arg === "--block-number") {
      options.blockNumber = args.shift();
    } else if (arg === "--block-hash") {
      options.blockHash = args.shift();
    } else if (arg === "--tx") {
      const value = args.shift();
      if (value?.startsWith("0x")) options.txHash = value;
      else options.txId = value;
    } else if (arg === "--tx-id") {
      options.txId = args.shift();
    } else if (arg === "--tx-hash") {
      options.txHash = args.shift();
    } else if (arg === "--wallet") {
      options.walletId = args.shift();
    } else if (arg === "--credit") {
      options.creditId = args.shift();
    } else if (arg === "--deposit") {
      options.depositId = args.shift();
    } else if (arg === "--withdrawal") {
      options.withdrawalId = args.shift();
    } else if (arg === "--object") {
      options.objectId = args.shift();
    } else if (arg === "--status") {
      options.status = args.shift();
    } else if (arg === "--from") {
      options.fromAccountId = args.shift();
    } else if (arg === "--to") {
      options.toAccountId = args.shift();
    } else if (arg === "--amount-units") {
      options.amountUnits = args.shift();
    } else if (arg === "--memo") {
      options.memo = args.shift();
    } else if (arg === "--signed-envelope" || arg === "--signed-transaction") {
      options.signedEnvelopeInput = args.shift();
    } else if (arg === "--runtime-transaction" || arg === "--runtime-tx") {
      options.runtimeTransactionInput = args.shift();
    } else if (arg === "--submitted-by") {
      options.submittedBy = args.shift();
    } else if (arg === "--expected-nonce") {
      options.expectedNonce = args.shift();
    } else if (arg === "--runtime-submit") {
      runtimeSubmit = true;
    } else if (arg === "--runtime-submit-mode") {
      const mode = args.shift();
      if (mode !== "off" && mode !== "direct" && mode !== "node-inbox") {
        throw new Error("--runtime-submit-mode must be off, direct, or node-inbox");
      }
      options.runtimeSubmitMode = mode;
    } else if (arg !== undefined) {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!COMMANDS.has(command)) throw new Error(`unknown command: ${command}`);
  return { command, rpcUrl, json, limit, seconds, pollMs, runtimeSubmit, ...options };
}

function printHelp() {
  console.log(`FlowChain devkit

Usage:
  npm run flowchain:devkit -- <command> [--rpc <url>] [--json]

Commands:
  discover          Print RPC discovery
  readiness         Print public/live readiness
  health            Print control-plane health
  node-status       Print node status
  peers             List peers
  status            Print chain status
  watch-height      Wait for block height to advance
  blocks            List blocks
  block             Get a block by --block, --block-number, or --block-hash
  transactions      List transactions
  transaction       Get a transaction by --tx, --tx-id, or --tx-hash
  mempool           List queued transactions
  accounts          List accounts
  account           Get account by --account or --id
  balance           Get balance by --account or --id
  wallet-metadata   List wallet public metadata
  wallet-metadata-get Get wallet metadata by --wallet, --account, or --id
  wallet-balances   Print wallet balance rows
  wallet-transfers  Print wallet transfer history
  faucet-events     List local no-value faucet/test allocation metadata
  finality          List finality rows
  finality-get      Get finality by --object or --id
  wallet-send       Submit a local wallet send through the real control-plane wallet path
  submit-signed-transaction Submit a signed local envelope from --signed-envelope <path-or-json>
  wait-transaction  Wait for transaction/activity inclusion by --tx, --tx-id, --tx-hash, or --id
  bridge-readiness  Print bridge live readiness
  bridge-status     Print bridge status
  bridge-deposits   List bridge deposits
  bridge-deposit    Get bridge deposit by --deposit, --tx, or --id
  bridge-credits    List bridge credits
  bridge-credit     Get bridge credit by --credit, --deposit, --account, --tx, or --id
  bridge-credit-status Print bridge credit lifecycle status by lookup key
  withdrawals       List withdrawal intents
  withdrawal        Get withdrawal by --withdrawal, --credit, --deposit, --account, or --id
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

function listParams(options: CliOptions): JsonValue {
  const params: Record<string, JsonValue> = { limit: options.limit };
  if (options.status !== undefined) params.status = options.status;
  return params;
}

function requiredValue(options: CliOptions, names: Array<keyof CliOptions>, label: string): string {
  for (const name of names) {
    const value = options[name];
    if (typeof value === "string" && value.length > 0) return value;
  }
  throw new Error(`${options.command} requires ${label}`);
}

function blockParams(options: CliOptions): JsonValue {
  const value = requiredValue(options, ["blockHash", "blockNumber", "id"], "--block, --block-number, --block-hash, or --id");
  return value.startsWith("0x") ? { blockHash: value } : { blockNumber: value };
}

function transactionParams(options: CliOptions): JsonValue {
  const value = requiredValue(options, ["txHash", "txId", "id"], "--tx, --tx-id, --tx-hash, or --id");
  return value.startsWith("0x") ? { txHash: value } : { txId: value };
}

function accountParams(options: CliOptions): JsonValue {
  return { accountId: requiredValue(options, ["accountId", "id"], "--account or --id") };
}

function walletMetadataParams(options: CliOptions): JsonValue {
  const value = requiredValue(options, ["walletId", "accountId", "id"], "--wallet, --account, or --id");
  return { walletId: value };
}

function bridgeCreditLookupParams(options: CliOptions): JsonValue {
  const value = requiredValue(options, ["creditId", "depositId", "accountId", "txHash", "txId", "id"], "--credit, --deposit, --account, --tx, or --id");
  if (options.creditId !== undefined) return { creditId: value };
  if (options.depositId !== undefined) return { depositId: value };
  if (options.accountId !== undefined) return { accountId: value };
  if (options.txHash !== undefined || value.startsWith("0x")) return { txHash: value };
  return { creditId: value };
}

function bridgeDepositParams(options: CliOptions): JsonValue {
  const value = requiredValue(options, ["depositId", "txHash", "txId", "id"], "--deposit, --tx, or --id");
  if (options.depositId !== undefined) return { depositId: value };
  if (options.txHash !== undefined || value.startsWith("0x")) return { txHash: value };
  return { depositId: value };
}

function withdrawalParams(options: CliOptions): JsonValue {
  const value = requiredValue(options, ["withdrawalId", "creditId", "depositId", "accountId", "id"], "--withdrawal, --credit, --deposit, --account, or --id");
  if (options.withdrawalId !== undefined) return { withdrawalId: value };
  if (options.creditId !== undefined) return { creditId: value };
  if (options.depositId !== undefined) return { depositId: value };
  if (options.accountId !== undefined) return { accountId: value };
  return { withdrawalId: value };
}

function parseJsonInput(input: string, label: string): JsonValue {
  const trimmed = input.trim();
  const pathCandidates = isAbsolute(input)
    ? [input]
    : [
        resolve(process.cwd(), input),
        ...(process.env.INIT_CWD === undefined ? [] : [resolve(process.env.INIT_CWD, input)]),
      ];
  const resolvedPath = pathCandidates.find((candidate) => existsSync(candidate));
  const source = trimmed.startsWith("{") || trimmed.startsWith("[")
    ? trimmed
    : readFileSync(resolvedPath ?? pathCandidates[0] ?? input, "utf8");
  try {
    return JSON.parse(source) as JsonValue;
  } catch (error) {
    const origin = resolvedPath ?? label;
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`${label} must be a JSON object or a path to JSON: ${origin}: ${message}`);
  }
}

function signedTransactionSubmitParams(options: CliOptions): SignedTransactionSubmitRequest {
  if (options.signedEnvelopeInput === undefined || options.signedEnvelopeInput.trim().length === 0) {
    throw new Error("submit-signed-transaction requires --signed-envelope <path-or-json>");
  }
  const params: SignedTransactionSubmitRequest = {
    signedEnvelope: parseJsonInput(options.signedEnvelopeInput, "--signed-envelope"),
    submittedBy: options.submittedBy ?? "flowchain-devkit-cli",
  };
  if (options.expectedNonce !== undefined) params.expectedNonce = options.expectedNonce;
  if (options.runtimeSubmit) params.runtimeSubmit = true;
  if (options.runtimeSubmitMode !== undefined) params.runtimeSubmitMode = options.runtimeSubmitMode;
  if (options.runtimeTransactionInput !== undefined) {
    params.runtimeTransaction = parseJsonInput(options.runtimeTransactionInput, "--runtime-transaction");
  }
  return params;
}

function heightFromStatus(status: JsonValue): bigint | null {
  if (status === null || typeof status !== "object" || Array.isArray(status)) return null;
  const record = status as Record<string, JsonValue>;
  const value = record.currentBlock ?? record.blockHeight ?? record.latestHeight ?? record.height;
  if (typeof value === "string" && /^\d+$/.test(value)) return BigInt(value);
  if (typeof value === "number" && Number.isInteger(value)) return BigInt(value);
  return null;
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function watchHeight(client: FlowChainClient, seconds: number): Promise<JsonValue> {
  const first = await client.chainStatus();
  const firstHeight = heightFromStatus(first);
  const deadline = Date.now() + seconds * 1000;
  let latest = first;
  let latestHeight = firstHeight;
  while (Date.now() < deadline) {
    await sleep(1000);
    latest = await client.chainStatus();
    latestHeight = heightFromStatus(latest);
    if (firstHeight !== null && latestHeight !== null && latestHeight > firstHeight) break;
  }
  return {
    schema: "flowchain.sdk.watch_height.v0",
    status: firstHeight !== null && latestHeight !== null && latestHeight > firstHeight ? "passed" : "failed",
    firstHeight: firstHeight?.toString() ?? null,
    latestHeight: latestHeight?.toString() ?? null,
    latest,
  };
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
      case "health":
        return client.health();
      case "node-status":
        return client.nodeStatus();
      case "peers":
        return client.peerList(listParams(options));
      case "status":
        return client.chainStatus();
      case "watch-height":
        return watchHeight(client, options.seconds);
      case "blocks":
        return client.blockList(listParams(options));
      case "block":
        return client.blockGet(blockParams(options));
      case "transactions":
        return client.transactionList(listParams(options));
      case "transaction":
        return client.transactionGet(transactionParams(options));
      case "mempool":
        return client.mempoolList(listParams(options));
      case "accounts":
        return client.accountList(listParams(options));
      case "account":
        return client.accountGet(accountParams(options));
      case "balance":
        return client.balanceGet(accountParams(options));
      case "wallet-metadata":
        return client.walletMetadataList(listParams(options));
      case "wallet-metadata-get":
        return client.walletMetadataGet(walletMetadataParams(options));
      case "wallet-balances":
        return client.walletBalances(params);
      case "wallet-transfers":
        return client.walletTransfers(params);
      case "faucet-events":
        return client.faucetEventList(listParams(options));
      case "finality":
        return client.finalityList(listParams(options));
      case "finality-get":
        return client.finalityGet({ objectId: requiredValue(options, ["objectId", "id"], "--object or --id") });
      case "bridge-readiness":
        return client.bridgeReadiness();
      case "bridge-status":
        return client.bridgeStatus();
      case "bridge-deposits":
        return client.bridgeDepositList(listParams(options));
      case "bridge-deposit":
        return client.bridgeDepositGet(bridgeDepositParams(options));
      case "bridge-credits":
        return client.bridgeCreditList(listParams(options));
      case "bridge-credit":
        return client.bridgeCreditGet(bridgeCreditLookupParams(options));
      case "bridge-credit-status":
        return client.bridgeCreditStatus(bridgeCreditLookupParams(options));
      case "withdrawals":
        return client.withdrawalList(listParams(options));
      case "withdrawal":
        return client.withdrawalGet(withdrawalParams(options));
      case "wallet-send":
        if (options.fromAccountId === undefined || options.toAccountId === undefined || options.amountUnits === undefined) {
          throw new Error("wallet-send requires --from, --to, and --amount-units");
        }
        return client.walletSend({
          fromAccountId: options.fromAccountId,
          toAccountId: options.toAccountId,
          amountUnits: options.amountUnits,
          memo: options.memo ?? "flowchain-devkit-wallet-send",
          applyBlock: true,
          createRecipient: true,
        });
      case "submit-signed-transaction":
        return client.submitSignedTransaction(signedTransactionSubmitParams(options));
      case "wait-transaction": {
        const waited = await client.waitForTransaction({
          ...(transactionParams(options) as Record<string, string>),
          timeoutMs: options.seconds * 1000,
          pollMs: options.pollMs,
        });
        const waitedRecord = waited as Record<string, JsonValue>;
        if (waitedRecord.status !== "included") {
          process.exitCode = 1;
        }
        return waited;
      }
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
