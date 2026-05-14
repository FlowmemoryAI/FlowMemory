import { FLOWPULSE_EVENT_TOPIC0, type RawFlowPulseLogFixture } from "../../shared/src/index.ts";
import type { IndexRejectedLog } from "./indexer.ts";
import {
  assertBlockRange,
  assertRpcQuantity,
  normalizeEvmAddresses,
  normalizeRpcUrl,
} from "./reader-utils.ts";

export const BASE_MAINNET_CHAIN_ID = "8453";
export const BASE_SEPOLIA_CHAIN_ID = "84532";

export interface LocalRpcReadOptions {
  rpcUrl: string;
  addresses: string[];
  fromBlock: string;
  toBlock: string;
  fetchImpl?: typeof fetch;
}

export interface RpcFlowPulseReadResult {
  chainId: string;
  logs: RawFlowPulseLogFixture[];
  rejectedLogs: IndexRejectedLog[];
}

interface JsonRpcResponse<T> {
  jsonrpc: "2.0";
  id: number;
  result?: T;
  error?: {
    code: number;
    message: string;
  };
}

interface RpcLog {
  address: string;
  topics: string[];
  data: string;
  blockNumber: string;
  blockHash: string;
  transactionHash: string;
  transactionIndex: string;
  logIndex: string;
  removed?: boolean;
}

interface RpcReceipt {
  status: string;
}

interface NormalizedRpcReadOptions extends LocalRpcReadOptions {
  rpcUrl: string;
  addresses: string[];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function stringField(value: Record<string, unknown>, key: string): string | null {
  const field = value[key];
  return typeof field === "string" ? field : null;
}

function optionalBooleanField(value: Record<string, unknown>, key: string): boolean | undefined {
  const field = value[key];
  if (field === undefined) return undefined;
  return typeof field === "boolean" ? field : undefined;
}

function safeString(value: unknown, fallback = "unknown"): string {
  return typeof value === "string" && value.trim() !== "" ? value : fallback;
}

function rejectedRpcLog(input: {
  chainId: string;
  rawLog: unknown;
  rawLogIndex: number;
  reasonCode: string;
  message: string;
}): IndexRejectedLog {
  const rawLog = isRecord(input.rawLog) ? input.rawLog : {};
  return {
    chainId: input.chainId,
    blockNumber: safeString(rawLog.blockNumber),
    blockHash: safeString(rawLog.blockHash),
    txHash: safeString(rawLog.transactionHash),
    transactionIndex: safeString(rawLog.transactionIndex),
    logIndex: safeString(rawLog.logIndex),
    reasonCode: input.reasonCode,
    message: input.message,
    source: "rpc",
    rawLogIndex: input.rawLogIndex,
    address: safeString(rawLog.address),
  };
}

function normalizeRpcReadOptions(options: LocalRpcReadOptions): NormalizedRpcReadOptions {
  const rpcUrl = normalizeRpcUrl(options.rpcUrl);
  const addresses = normalizeEvmAddresses(options.addresses);
  assertRpcQuantity(options.fromBlock, "fromBlock");
  assertRpcQuantity(options.toBlock, "toBlock");
  assertBlockRange(quantityToDecimalString(options.fromBlock), quantityToDecimalString(options.toBlock));

  return {
    ...options,
    rpcUrl,
    addresses,
  };
}

function quantityToDecimalString(quantity: string): string {
  if (!/^0x[0-9a-fA-F]+$/.test(quantity)) {
    throw new Error(`invalid JSON-RPC quantity: ${quantity}`);
  }
  return BigInt(quantity).toString();
}

async function rpc<T>(fetchImpl: typeof fetch, rpcUrl: string, method: string, params: unknown[]): Promise<T> {
  const response = await fetchImpl(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method,
      params,
    }),
  });

  if (!response.ok) {
    throw new Error(`JSON-RPC HTTP error ${response.status}`);
  }

  const payload = await response.json() as JsonRpcResponse<T>;
  if (!isRecord(payload) || payload.jsonrpc !== "2.0") {
    throw new Error(`JSON-RPC ${method} returned a malformed envelope`);
  }
  if (payload.error !== undefined) {
    const error = payload.error;
    if (!isRecord(error) || typeof error.code !== "number" || typeof error.message !== "string") {
      throw new Error(`JSON-RPC ${method} returned a malformed error`);
    }
    throw new Error(`JSON-RPC error ${error.code}: ${error.message}`);
  }
  if (payload.result === undefined) {
    throw new Error(`JSON-RPC ${method} returned no result`);
  }
  return payload.result;
}

async function readRpcChainId(fetchImpl: typeof fetch, rpcUrl: string): Promise<string> {
  const chainIdQuantity = await rpc<string>(fetchImpl, rpcUrl, "eth_chainId", []);
  return quantityToDecimalString(chainIdQuantity);
}

async function readRpcFlowPulseLogSetWithChainId(
  options: NormalizedRpcReadOptions,
  chainId: string,
  fetchImpl: typeof fetch,
): Promise<RpcFlowPulseReadResult> {
  const logs = await rpc<unknown>(fetchImpl, options.rpcUrl, "eth_getLogs", [{
    address: options.addresses,
    fromBlock: options.fromBlock,
    toBlock: options.toBlock,
    topics: [FLOWPULSE_EVENT_TOPIC0],
  }]);
  if (!Array.isArray(logs)) {
    throw new Error("JSON-RPC eth_getLogs result must be an array");
  }

  const rawLogs: RawFlowPulseLogFixture[] = [];
  const rejectedLogs: IndexRejectedLog[] = [];
  for (let rawLogIndex = 0; rawLogIndex < logs.length; rawLogIndex += 1) {
    const log = logs[rawLogIndex];
    if (!isRecord(log)) {
      rejectedLogs.push(rejectedRpcLog({
        chainId,
        rawLog: log,
        rawLogIndex,
        reasonCode: "rpc.log.malformed",
        message: "eth_getLogs result item is not an object",
      }));
      continue;
    }

    const address = stringField(log, "address");
    const topics = log.topics;
    const data = stringField(log, "data");
    const blockNumber = stringField(log, "blockNumber");
    const blockHash = stringField(log, "blockHash");
    const transactionHash = stringField(log, "transactionHash");
    const transactionIndex = stringField(log, "transactionIndex");
    const logIndex = stringField(log, "logIndex");
    const removed = optionalBooleanField(log, "removed");

    if (!Array.isArray(topics) || !topics.every((topic) => typeof topic === "string")) {
      rejectedLogs.push(rejectedRpcLog({
        chainId,
        rawLog: log,
        rawLogIndex,
        reasonCode: "rpc.log.malformed",
        message: "eth_getLogs log topics must be an array of strings",
      }));
      continue;
    }

    const requiredFields = { address, data, blockNumber, blockHash, transactionHash, transactionIndex, logIndex };
    const missingField = Object.entries(requiredFields).find(([, value]) => value === null)?.[0];
    if (missingField !== undefined) {
      rejectedLogs.push(rejectedRpcLog({
        chainId,
        rawLog: log,
        rawLogIndex,
        reasonCode: "rpc.log.malformed",
        message: `eth_getLogs log is missing string field ${missingField}`,
      }));
      continue;
    }

    let normalizedBlockNumber: string;
    let normalizedTransactionIndex: string;
    let normalizedLogIndex: string;
    try {
      normalizedBlockNumber = quantityToDecimalString(blockNumber);
      normalizedTransactionIndex = quantityToDecimalString(transactionIndex);
      normalizedLogIndex = quantityToDecimalString(logIndex);
    } catch (error) {
      rejectedLogs.push(rejectedRpcLog({
        chainId,
        rawLog: log,
        rawLogIndex,
        reasonCode: "rpc.log.malformed",
        message: error instanceof Error ? error.message : "invalid RPC log quantity",
      }));
      continue;
    }

    let receipt: RpcReceipt;
    try {
      receipt = await rpc<RpcReceipt>(fetchImpl, options.rpcUrl, "eth_getTransactionReceipt", [transactionHash]);
    } catch (error) {
      rejectedLogs.push(rejectedRpcLog({
        chainId,
        rawLog: log,
        rawLogIndex,
        reasonCode: "rpc.receipt.unavailable",
        message: error instanceof Error ? error.message : "transaction receipt unavailable",
      }));
      continue;
    }
    if (!isRecord(receipt) || (receipt.status !== "0x1" && receipt.status !== "0x0")) {
      rejectedLogs.push(rejectedRpcLog({
        chainId,
        rawLog: log,
        rawLogIndex,
        reasonCode: "rpc.receipt.malformed",
        message: "transaction receipt status must be 0x1 or 0x0",
      }));
      continue;
    }

    rawLogs.push({
      chainId,
      address,
      topics,
      data,
      blockNumber: normalizedBlockNumber,
      blockHash,
      transactionHash,
      transactionIndex: normalizedTransactionIndex,
      logIndex: normalizedLogIndex,
      receiptStatus: receipt.status === "0x1" ? "success" : "reverted",
      removed,
    });
  }

  return {
    chainId,
    logs: rawLogs,
    rejectedLogs,
  };
}

export async function readLocalRpcFlowPulseLogs(options: LocalRpcReadOptions): Promise<RawFlowPulseLogFixture[]> {
  return (await readRpcFlowPulseLogSet(options)).logs;
}

export async function readRpcFlowPulseLogSet(options: LocalRpcReadOptions): Promise<RpcFlowPulseReadResult> {
  const fetchImpl = options.fetchImpl ?? fetch;
  const normalizedOptions = normalizeRpcReadOptions(options);
  const chainId = await readRpcChainId(fetchImpl, normalizedOptions.rpcUrl);
  return readRpcFlowPulseLogSetWithChainId(normalizedOptions, chainId, fetchImpl);
}

export async function readBaseSepoliaFlowPulseLogs(options: LocalRpcReadOptions): Promise<RpcFlowPulseReadResult> {
  const fetchImpl = options.fetchImpl ?? fetch;
  const normalizedOptions = normalizeRpcReadOptions(options);
  const chainId = await readRpcChainId(fetchImpl, normalizedOptions.rpcUrl);
  if (chainId !== BASE_SEPOLIA_CHAIN_ID) {
    throw new Error(`expected Base Sepolia chainId ${BASE_SEPOLIA_CHAIN_ID}, received ${chainId}`);
  }
  return readRpcFlowPulseLogSetWithChainId(normalizedOptions, chainId, fetchImpl);
}

export async function readBaseMainnetCanaryFlowPulseLogs(options: LocalRpcReadOptions): Promise<RpcFlowPulseReadResult> {
  const fetchImpl = options.fetchImpl ?? fetch;
  const normalizedOptions = normalizeRpcReadOptions(options);
  const chainId = await readRpcChainId(fetchImpl, normalizedOptions.rpcUrl);
  if (chainId !== BASE_MAINNET_CHAIN_ID) {
    throw new Error(`expected Base mainnet chainId ${BASE_MAINNET_CHAIN_ID}, received ${chainId}`);
  }
  return readRpcFlowPulseLogSetWithChainId(normalizedOptions, chainId, fetchImpl);
}
