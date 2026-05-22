import { fileURLToPath } from "node:url";

import { FlowMemoryClient, FlowMemoryRpcError, type JsonValue } from "./client.ts";
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
  "diagnostics",
  "base-agent-scouts",
  "base-agent-scout",
  "base-agent-replay",
  "public-agent-classes",
  "public-agent-class",
  "public-agent-tools",
  "public-agent-toolset",
  "public-agent-launch-preview",
  "public-agent-launch-intent",
  "public-agent-launch",
  "public-agent-discover",
  "public-swarm-classes",
  "public-swarm-class",
  "public-swarm-launch-preview",
  "public-swarm",
  "public-swarm-replay",
  "help",
]);

function parseArgs(argv: string[]): CliOptions {
  const args = [...argv];
  const command = args.shift() ?? "help";
  let rpcUrl = process.env.FLOWMEMORY_RPC_URL ?? "http://127.0.0.1:8787/rpc";
  let json = false;
  let limit = 10;
  let seconds = 20;
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
    } else if (arg !== undefined) {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!COMMANDS.has(command)) throw new Error(`unknown command: ${command}`);
  return { command, rpcUrl, json, limit, seconds, ...options };
}

function printHelp() {
  console.log(`FlowMemory public CLI

Usage:
  npm run public:test:cli -- <command> [--rpc <url>] [--json]

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
  base-agent-scouts  List Base agent-memory task-scout records
  base-agent-scout   Get Base agent-memory task-scout by --account, --object, or --id
  base-agent-replay  Get Base agent-memory replay report by --account, --object, or --id
  public-agent-classes List public agent classes
  public-agent-class  Get public agent class by --id
  public-agent-tools  List public agent tools
  public-agent-toolset Get public agent tool set by --id
  public-agent-launch-preview Preview roots and warnings using --account, --status (classId), and --object (toolSetRoot)
  public-agent-launch-intent Build public launch typed intent roots using --account, --status (classId), and --object (toolSetRoot)
  public-agent-launch Get the prototype/latest public launch projection
  public-agent-discover Discover public launch projections
  public-swarm-classes List public swarm classes
  public-swarm-class  Get public swarm class by --id
  public-swarm-launch-preview Preview a public swarm launch using --account, --status (swarmClass), and --memo
  public-swarm       Get the prototype/latest public swarm projection
  public-swarm-replay Get deterministic public swarm replay projection
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

async function watchHeight(client: FlowMemoryClient, seconds: number): Promise<JsonValue> {
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
    schema: "flowmemory.sdk.watch_height.v0",
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
  const client = new FlowMemoryClient({ rpcUrl: options.rpcUrl });
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
      case "base-agent-scouts":
        return client.baseAgentMemoryScoutList(listParams(options));
      case "base-agent-scout":
        return client.baseAgentMemoryScoutGet({ agentId: requiredValue(options, ["accountId", "objectId", "id"], "--account, --object, or --id") });
      case "base-agent-replay":
        return client.baseAgentMemoryReplayGet({ agentId: requiredValue(options, ["accountId", "objectId", "id"], "--account, --object, or --id") });
      case "public-agent-classes":
        return client.publicAgentNetworkClassesList(listParams(options));
      case "public-agent-class":
        return client.publicAgentNetworkClassGet({ classId: requiredValue(options, ["id"], "--id") });
      case "public-agent-tools":
        return client.publicAgentNetworkToolsList(listParams(options));
      case "public-agent-toolset":
        return client.publicAgentNetworkToolSetGet({ toolSetRoot: requiredValue(options, ["id"], "--id") });
      case "public-agent-launch-preview":
        return client.publicAgentLaunchPreview({
          owner: requiredValue(options, ["accountId", "id"], "--account or --id"),
          classId: requiredValue(options, ["status"], "--status used as classId"),
          objectiveText: options.memo ?? "public launch objective",
          profileText: options.memo ?? "public launch profile",
          toolSetRoot: requiredValue(options, ["objectId"], "--object used as toolSetRoot"),
          autonomyLevel: 2,
          riskLevel: 1,
          bondToken: "0x0000000000000000000000000000000000000000",
          bondAmount: "0",
          fuelToken: "0x0000000000000000000000000000000000000000",
          initialFuelAmount: "0",
          discoverable: true,
        });
      case "public-agent-launch-intent":
        return client.publicAgentLaunchIntentGet({
          owner: requiredValue(options, ["accountId", "id"], "--account or --id"),
          classId: requiredValue(options, ["status"], "--status used as classId"),
          objectiveText: options.memo ?? "public launch objective",
          profileText: options.memo ?? "public launch profile",
          toolSetRoot: requiredValue(options, ["objectId"], "--object used as toolSetRoot"),
          autonomyLevel: 2,
          riskLevel: 1,
          bondToken: "0x2000000000000000000000000000000000000001",
          bondAmount: "10000000000000000000",
          fuelToken: "0x2000000000000000000000000000000000000001",
          initialFuelAmount: "5000000000000000000",
          discoverable: true,
          rootfieldId: "0x1111111111111111111111111111111111111111111111111111111111111111",
          validAfter: "1",
          validUntil: "2",
          nonce: "0",
          salt: "0x2222222222222222222222222222222222222222222222222222222222222222",
        });
      case "public-agent-launch":
        return client.publicAgentLaunchGet(options.id === undefined ? {} : { launchId: options.id });
      case "public-agent-discover":
        return client.publicAgentDiscover(listParams(options));
      case "public-swarm-classes":
        return client.publicSwarmClassesList(listParams(options));
      case "public-swarm-class":
        return client.publicSwarmClassGet({ swarmClass: requiredValue(options, ["id"], "--id") });
      case "public-swarm-launch-preview":
        return client.publicSwarmLaunchPreview({
          creator: requiredValue(options, ["accountId", "id"], "--account or --id"),
          swarmClass: requiredValue(options, ["status"], "--status used as swarmClass"),
          missionText: options.memo ?? "public swarm mission",
          profileText: options.memo ?? "public swarm profile",
          budgetAsset: requiredValue(options, ["objectId"], "--object used as budgetAsset"),
          initialBudget: options.amountUnits ?? "0",
        });
      case "public-swarm":
        return client.publicSwarmGet(options.id === undefined ? {} : { swarmId: options.id });
      case "public-swarm-replay":
        return client.publicSwarmReplayGet(options.id === undefined ? {} : { swarmId: options.id });
      case "wallet-send":
        if (options.fromAccountId === undefined || options.toAccountId === undefined || options.amountUnits === undefined) {
          throw new Error("wallet-send requires --from, --to, and --amount-units");
        }
        return client.walletSend({
          fromAccountId: options.fromAccountId,
          toAccountId: options.toAccountId,
          amountUnits: options.amountUnits,
          memo: options.memo ?? "flowmemory-cli-wallet-send",
          applyBlock: true,
          createRecipient: true,
        });
      case "diagnostics":
        return {
          schema: "flowmemory.sdk.diagnostics.v0",
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
    if (error instanceof FlowMemoryRpcError) {
      printResult({
        schema: "flowmemory.sdk.error.v0",
        status: "failed",
        code: error.code,
        message: error.message,
        data: error.data ?? null,
      }, true);
    } else {
      printResult({
        schema: "flowmemory.sdk.error.v0",
        status: "failed",
        message: error instanceof Error ? error.message : String(error),
      }, true);
    }
    process.exitCode = 1;
  });
}

export { run };
