import { resolve } from "node:path";

import { indexFlowPulseLogs, type IndexerState } from "./indexer.ts";
import {
  baseSepoliaIndexerCheckpoint,
  type BaseSepoliaIndexerCheckpoint,
  writeBaseSepoliaIndexerCheckpoint,
  writeIndexerState,
} from "./persistence.ts";
import { BASE_SEPOLIA_CHAIN_ID, readBaseSepoliaFlowPulseLogs } from "./rpc.ts";

export interface BaseSepoliaReaderOptions {
  rpcUrl: string;
  addresses: string[];
  fromBlock: string;
  toBlock: string;
  outPath?: string;
  checkpointPath?: string;
  finalizedBlockNumber?: string;
  generatedAt?: string;
  fetchImpl?: typeof fetch;
}

export interface BaseSepoliaReaderResult {
  state: IndexerState;
  checkpoint: BaseSepoliaIndexerCheckpoint;
  statePath: string;
  checkpointPath: string;
}

interface CliOptions extends BaseSepoliaReaderOptions {
  outPath: string;
  checkpointPath: string;
}

function normalizeAddress(address: string): string {
  const normalized = address.trim().toLowerCase();
  if (!/^0x[0-9a-f]{40}$/.test(normalized)) {
    throw new Error(`invalid EVM address: ${address}`);
  }
  return normalized;
}

function normalizeAddresses(addresses: string[]): string[] {
  const normalized = addresses.flatMap((entry) => entry.split(",")).map(normalizeAddress);
  const unique = [...new Set(normalized)].sort((left, right) => left.localeCompare(right));
  if (unique.length === 0) {
    throw new Error("at least one FlowPulse contract address is required");
  }
  return unique;
}

export function blockArgumentToDecimalString(value: string): string {
  const trimmed = value.trim().toLowerCase();
  if (/^0x[0-9a-f]+$/.test(trimmed)) {
    return BigInt(trimmed).toString();
  }
  if (/^[0-9]+$/.test(trimmed)) {
    return BigInt(trimmed).toString();
  }
  throw new Error(`block value must be a decimal or 0x quantity, received: ${value}`);
}

export function blockArgumentToRpcQuantity(value: string): string {
  return `0x${BigInt(blockArgumentToDecimalString(value)).toString(16)}`;
}

function readArgValue(args: string[], index: number, name: string): string {
  const value = args[index + 1];
  if (value === undefined || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

export function parseBaseSepoliaReaderArgs(args: string[]): CliOptions {
  let rpcUrl = "";
  let fromBlock = "";
  let toBlock = "";
  let finalizedBlockNumber: string | undefined;
  const addresses: string[] = [];
  let outPath = "out/base-sepolia-indexer-state.json";
  let checkpointPath = "out/base-sepolia-indexer-checkpoint.json";

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--rpc-url") {
      rpcUrl = readArgValue(args, index, arg);
      index += 1;
    } else if (arg === "--address" || arg === "--addresses") {
      addresses.push(readArgValue(args, index, arg));
      index += 1;
    } else if (arg === "--from-block") {
      fromBlock = readArgValue(args, index, arg);
      index += 1;
    } else if (arg === "--to-block") {
      toBlock = readArgValue(args, index, arg);
      index += 1;
    } else if (arg === "--finalized-block") {
      finalizedBlockNumber = blockArgumentToDecimalString(readArgValue(args, index, arg));
      index += 1;
    } else if (arg === "--out") {
      outPath = readArgValue(args, index, arg);
      index += 1;
    } else if (arg === "--checkpoint-out") {
      checkpointPath = readArgValue(args, index, arg);
      index += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  if (rpcUrl.trim() === "") {
    throw new Error("--rpc-url is required; FlowMemory does not ship a default RPC endpoint");
  }
  if (fromBlock.trim() === "") {
    throw new Error("--from-block is required");
  }
  if (toBlock.trim() === "") {
    throw new Error("--to-block is required");
  }

  return {
    rpcUrl,
    addresses: normalizeAddresses(addresses),
    fromBlock: blockArgumentToDecimalString(fromBlock),
    toBlock: blockArgumentToDecimalString(toBlock),
    finalizedBlockNumber,
    outPath,
    checkpointPath,
  };
}

export async function runBaseSepoliaReader(options: BaseSepoliaReaderOptions): Promise<BaseSepoliaReaderResult> {
  const addresses = normalizeAddresses(options.addresses);
  const fromBlock = blockArgumentToDecimalString(options.fromBlock);
  const toBlock = blockArgumentToDecimalString(options.toBlock);
  const outPath = resolve(options.outPath ?? "out/base-sepolia-indexer-state.json");
  const checkpointPath = resolve(options.checkpointPath ?? "out/base-sepolia-indexer-checkpoint.json");

  if (BigInt(toBlock) < BigInt(fromBlock)) {
    throw new Error("--to-block must be greater than or equal to --from-block");
  }

  const readResult = await readBaseSepoliaFlowPulseLogs({
    rpcUrl: options.rpcUrl,
    addresses,
    fromBlock: blockArgumentToRpcQuantity(fromBlock),
    toBlock: blockArgumentToRpcQuantity(toBlock),
    fetchImpl: options.fetchImpl,
  });

  const finalizedBlockNumber = options.finalizedBlockNumber === undefined
    ? undefined
    : blockArgumentToDecimalString(options.finalizedBlockNumber);

  const state = indexFlowPulseLogs(readResult.logs, {
    chainId: BASE_SEPOLIA_CHAIN_ID,
    finalizedBlockNumber,
    source: "base-sepolia-rpc",
    sourceAddresses: addresses,
  });
  const checkpoint = baseSepoliaIndexerCheckpoint({
    addresses,
    fromBlock,
    toBlock,
    finalizedBlockNumber,
    statePath: outPath,
    state,
    generatedAt: options.generatedAt,
  });

  writeIndexerState(outPath, state);
  writeBaseSepoliaIndexerCheckpoint(checkpointPath, checkpoint);

  return {
    state,
    checkpoint,
    statePath: outPath,
    checkpointPath,
  };
}

function usage(): string {
  return [
    "Usage:",
    "  node src/base-sepolia.ts --rpc-url <url> --address <0x...> --from-block <n> --to-block <n> [--finalized-block <n>] [--out <path>] [--checkpoint-out <path>]",
    "",
    "Boundary:",
    `  This reader only accepts Base Sepolia chainId ${BASE_SEPOLIA_CHAIN_ID}. It does not read Base mainnet.`,
  ].join("\n");
}

if (process.argv[1]?.replaceAll("\\", "/").endsWith("/base-sepolia.ts")) {
  runBaseSepoliaReader(parseBaseSepoliaReaderArgs(process.argv.slice(2)))
    .then((result) => {
      console.log(JSON.stringify({
        schema: "flowmemory.indexer.base_sepolia_reader_summary.v0",
        network: result.checkpoint.network,
        chainId: result.checkpoint.chainId,
        statePath: result.statePath,
        checkpointPath: result.checkpointPath,
        observationCount: result.checkpoint.observationCount,
        rejectedLogCount: result.checkpoint.rejectedLogCount,
        lastIndexedBlock: result.checkpoint.lastIndexedBlock,
      }, null, 2));
    })
    .catch((error) => {
      console.error(error instanceof Error ? error.message : error);
      console.error(usage());
      process.exitCode = 1;
    });
}
