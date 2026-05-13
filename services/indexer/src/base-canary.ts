import { resolve } from "node:path";

import { indexFlowPulseLogs, type IndexerState } from "./indexer.ts";
import {
  baseCanaryIndexerCheckpoint,
  type BaseCanaryIndexerCheckpoint,
  writeBaseCanaryIndexerCheckpoint,
  writeIndexerState,
} from "./persistence.ts";
import {
  blockArgumentToDecimalString,
  blockArgumentToRpcQuantity,
  normalizeEvmAddresses,
  normalizeRpcUrl,
  readArgValue,
} from "./reader-utils.ts";
import { BASE_MAINNET_CHAIN_ID, readBaseMainnetCanaryFlowPulseLogs } from "./rpc.ts";

export const BASE_CANARY_MAX_BLOCK_SPAN = 5_000n;

export interface BaseCanaryReaderOptions {
  rpcUrl: string;
  addresses: string[];
  fromBlock: string;
  toBlock: string;
  outPath?: string;
  checkpointPath?: string;
  finalizedBlockNumber?: string;
  generatedAt?: string;
  acknowledgeMainnetCanary?: boolean;
  fetchImpl?: typeof fetch;
}

export interface BaseCanaryReaderResult {
  state: IndexerState;
  checkpoint: BaseCanaryIndexerCheckpoint;
  statePath: string;
  checkpointPath: string;
}

interface CliOptions extends BaseCanaryReaderOptions {
  outPath: string;
  checkpointPath: string;
  acknowledgeMainnetCanary: true;
}

function assertCanaryAcknowledged(acknowledgeMainnetCanary?: boolean): void {
  if (acknowledgeMainnetCanary !== true) {
    throw new Error("--acknowledge-mainnet-canary is required for the Base mainnet canary reader");
  }
}

function assertCanaryBlockRange(fromBlock: string, toBlock: string): void {
  if (BigInt(toBlock) < BigInt(fromBlock)) {
    throw new Error("--to-block must be greater than or equal to --from-block");
  }

  const span = BigInt(toBlock) - BigInt(fromBlock);
  if (span > BASE_CANARY_MAX_BLOCK_SPAN) {
    throw new Error(
      `Base canary reader refuses broad scans; block span ${span.toString()} exceeds ${BASE_CANARY_MAX_BLOCK_SPAN.toString()}`,
    );
  }
}

export function parseBaseCanaryReaderArgs(args: string[]): CliOptions {
  let rpcUrl = "";
  let fromBlock = "";
  let toBlock = "";
  let finalizedBlockNumber: string | undefined;
  let acknowledgeMainnetCanary = false;
  const addresses: string[] = [];
  let outPath = "out/base-canary-indexer-state.json";
  let checkpointPath = "out/base-canary-indexer-checkpoint.json";

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--acknowledge-mainnet-canary") {
      acknowledgeMainnetCanary = true;
    } else if (arg === "--rpc-url") {
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

  if (fromBlock.trim() === "") {
    throw new Error("--from-block is required");
  }
  if (toBlock.trim() === "") {
    throw new Error("--to-block is required");
  }
  const normalizedRpcUrl = normalizeRpcUrl(rpcUrl);

  assertCanaryAcknowledged(acknowledgeMainnetCanary);

  const normalizedFromBlock = blockArgumentToDecimalString(fromBlock);
  const normalizedToBlock = blockArgumentToDecimalString(toBlock);
  assertCanaryBlockRange(normalizedFromBlock, normalizedToBlock);

  return {
    rpcUrl: normalizedRpcUrl,
    addresses: normalizeEvmAddresses(addresses),
    fromBlock: normalizedFromBlock,
    toBlock: normalizedToBlock,
    finalizedBlockNumber,
    outPath,
    checkpointPath,
    acknowledgeMainnetCanary: true,
  };
}

export async function runBaseCanaryReader(options: BaseCanaryReaderOptions): Promise<BaseCanaryReaderResult> {
  assertCanaryAcknowledged(options.acknowledgeMainnetCanary);

  const rpcUrl = normalizeRpcUrl(options.rpcUrl);
  const addresses = normalizeEvmAddresses(options.addresses);
  const fromBlock = blockArgumentToDecimalString(options.fromBlock);
  const toBlock = blockArgumentToDecimalString(options.toBlock);
  const outPath = resolve(options.outPath ?? "out/base-canary-indexer-state.json");
  const checkpointPath = resolve(options.checkpointPath ?? "out/base-canary-indexer-checkpoint.json");

  assertCanaryBlockRange(fromBlock, toBlock);

  const readResult = await readBaseMainnetCanaryFlowPulseLogs({
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
    chainId: BASE_MAINNET_CHAIN_ID,
    finalizedBlockNumber,
    source: "base-mainnet-canary-rpc",
    sourceAddresses: addresses,
    preRejectedLogs: readResult.rejectedLogs,
  });
  const checkpoint = baseCanaryIndexerCheckpoint({
    addresses,
    fromBlock,
    toBlock,
    finalizedBlockNumber,
    statePath: outPath,
    state,
    generatedAt: options.generatedAt,
  });

  writeIndexerState(outPath, state);
  writeBaseCanaryIndexerCheckpoint(checkpointPath, checkpoint);

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
    "  node src/base-canary.ts --acknowledge-mainnet-canary --rpc-url <url> --address <0x...> --from-block <n> --to-block <n> [--finalized-block <n>] [--out <path>] [--checkpoint-out <path>]",
    "",
    "Boundary:",
    `  This reader only accepts Base mainnet chainId ${BASE_MAINNET_CHAIN_ID} and is canary-only.`,
    `  It refuses scans wider than ${BASE_CANARY_MAX_BLOCK_SPAN.toString()} blocks and stores no RPC URLs or keys.`,
  ].join("\n");
}

if (process.argv[1]?.replaceAll("\\", "/").endsWith("/base-canary.ts")) {
  runBaseCanaryReader(parseBaseCanaryReaderArgs(process.argv.slice(2)))
    .then((result) => {
      console.log(JSON.stringify({
        schema: "flowmemory.indexer.base_canary_reader_summary.v0",
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
        hasIntegrityWarnings: result.checkpoint.dashboardFeed.hasIntegrityWarnings,
        productionReady: result.checkpoint.safety.productionReady,
      }, null, 2));
    })
    .catch((error) => {
      console.error(error instanceof Error ? error.message : error);
      console.error(usage());
      process.exitCode = 1;
    });
}
