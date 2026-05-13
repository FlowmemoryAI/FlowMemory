import { resolve } from "node:path";

import { indexFlowPulseLogs, type IndexerState } from "./indexer.ts";
import {
  baseSepoliaIndexerCheckpoint,
  readBaseSepoliaIndexerCheckpoint,
  type BaseSepoliaIndexerCheckpoint,
  writeBaseSepoliaIndexerCheckpoint,
  writeIndexerState,
} from "./persistence.ts";
import {
  blockArgumentToDecimalString,
  blockArgumentToRpcQuantity,
  normalizeEvmAddresses,
  normalizeRpcUrl,
  readArgValue,
} from "./reader-utils.ts";
import { BASE_SEPOLIA_CHAIN_ID, readBaseSepoliaFlowPulseLogs } from "./rpc.ts";

export { blockArgumentToDecimalString, blockArgumentToRpcQuantity } from "./reader-utils.ts";

export const BASE_SEPOLIA_MAX_BLOCK_SPAN = 10_000n;

export interface BaseSepoliaReaderOptions {
  rpcUrl: string;
  addresses: string[];
  fromBlock?: string;
  toBlock: string;
  outPath?: string;
  checkpointPath?: string;
  finalizedBlockNumber?: string;
  resumeFromCheckpoint?: boolean;
  maxBlockSpan?: string | bigint;
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
  fromBlock: string;
  outPath: string;
  checkpointPath: string;
  maxBlockSpan: string;
}

function normalizeMaxBlockSpan(value?: string | bigint): bigint {
  if (value === undefined) return BASE_SEPOLIA_MAX_BLOCK_SPAN;
  const normalized = typeof value === "bigint" ? value : BigInt(blockArgumentToDecimalString(value));
  if (normalized < 0n) {
    throw new Error("--max-block-span must be non-negative");
  }
  return normalized;
}

function assertBaseSepoliaBlockRange(fromBlock: string, toBlock: string, maxBlockSpan?: string | bigint): void {
  if (BigInt(toBlock) < BigInt(fromBlock)) {
    throw new Error("--to-block must be greater than or equal to --from-block");
  }

  const span = BigInt(toBlock) - BigInt(fromBlock);
  const limit = normalizeMaxBlockSpan(maxBlockSpan);
  if (span > limit) {
    throw new Error(`Base Sepolia reader refuses broad scans; block span ${span.toString()} exceeds ${limit.toString()}`);
  }
}

function resolveFromBlock(input: {
  explicitFromBlock?: string;
  checkpointPath: string;
  resumeFromCheckpoint?: boolean;
}): string {
  if (input.explicitFromBlock !== undefined && input.explicitFromBlock.trim() !== "") {
    return blockArgumentToDecimalString(input.explicitFromBlock);
  }
  if (input.resumeFromCheckpoint === true) {
    try {
      const checkpoint = readBaseSepoliaIndexerCheckpoint(input.checkpointPath);
      return checkpoint.nextFromBlock;
    } catch (error) {
      throw new Error(
        `--resume-from-checkpoint requires an existing Base Sepolia checkpoint or explicit --from-block (${input.checkpointPath})`,
      );
    }
  }
  throw new Error("--from-block is required");
}

export function parseBaseSepoliaReaderArgs(args: string[]): CliOptions {
  let rpcUrl = "";
  let fromBlock = "";
  let toBlock = "";
  let finalizedBlockNumber: string | undefined;
  let resumeFromCheckpoint = false;
  let maxBlockSpan = BASE_SEPOLIA_MAX_BLOCK_SPAN.toString();
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
    } else if (arg === "--resume-from-checkpoint") {
      resumeFromCheckpoint = true;
    } else if (arg === "--max-block-span") {
      maxBlockSpan = blockArgumentToDecimalString(readArgValue(args, index, arg));
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

  if (toBlock.trim() === "") {
    throw new Error("--to-block is required");
  }
  const normalizedRpcUrl = normalizeRpcUrl(rpcUrl);

  const normalizedFromBlock = resolveFromBlock({
    explicitFromBlock: fromBlock,
    checkpointPath: resolve(checkpointPath),
    resumeFromCheckpoint,
  });
  const normalizedToBlock = blockArgumentToDecimalString(toBlock);
  assertBaseSepoliaBlockRange(normalizedFromBlock, normalizedToBlock, maxBlockSpan);
  if (finalizedBlockNumber !== undefined && BigInt(finalizedBlockNumber) > BigInt(normalizedToBlock)) {
    throw new Error("--finalized-block must be less than or equal to --to-block");
  }

  return {
    rpcUrl: normalizedRpcUrl,
    addresses: normalizeEvmAddresses(addresses),
    fromBlock: normalizedFromBlock,
    toBlock: normalizedToBlock,
    finalizedBlockNumber,
    resumeFromCheckpoint,
    maxBlockSpan,
    outPath,
    checkpointPath,
  };
}

export async function runBaseSepoliaReader(options: BaseSepoliaReaderOptions): Promise<BaseSepoliaReaderResult> {
  const rpcUrl = normalizeRpcUrl(options.rpcUrl);
  const addresses = normalizeEvmAddresses(options.addresses);
  const toBlock = blockArgumentToDecimalString(options.toBlock);
  const outPath = resolve(options.outPath ?? "out/base-sepolia-indexer-state.json");
  const checkpointPath = resolve(options.checkpointPath ?? "out/base-sepolia-indexer-checkpoint.json");
  const fromBlock = resolveFromBlock({
    explicitFromBlock: options.fromBlock,
    checkpointPath,
    resumeFromCheckpoint: options.resumeFromCheckpoint,
  });

  assertBaseSepoliaBlockRange(fromBlock, toBlock, options.maxBlockSpan);
  if (options.finalizedBlockNumber !== undefined && BigInt(blockArgumentToDecimalString(options.finalizedBlockNumber)) > BigInt(toBlock)) {
    throw new Error("--finalized-block must be less than or equal to --to-block");
  }

  const readResult = await readBaseSepoliaFlowPulseLogs({
    rpcUrl,
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
    preRejectedLogs: readResult.rejectedLogs,
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
        duplicateCount: result.checkpoint.duplicateCount,
        dashboardCanonicalObservationCount: result.checkpoint.dashboardFeed.dashboardCanonicalObservationCount,
        lastIndexedBlock: result.checkpoint.lastIndexedBlock,
        lastScannedBlock: result.checkpoint.lastScannedBlock,
        nextFromBlock: result.checkpoint.nextFromBlock,
        emptyRange: result.checkpoint.emptyRange,
        hasIntegrityWarnings: result.checkpoint.dashboardFeed.hasIntegrityWarnings,
      }, null, 2));
    })
    .catch((error) => {
      console.error(error instanceof Error ? error.message : error);
      console.error(usage());
      process.exitCode = 1;
    });
}
