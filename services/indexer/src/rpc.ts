import { FLOWPULSE_EVENT_TOPIC0, type RawFlowPulseLogFixture } from "../../shared/src/index.ts";

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
  if (payload.error !== undefined) {
    throw new Error(`JSON-RPC error ${payload.error.code}: ${payload.error.message}`);
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
  options: LocalRpcReadOptions,
  chainId: string,
  fetchImpl: typeof fetch,
): Promise<RpcFlowPulseReadResult> {
  const logs = await rpc<RpcLog[]>(fetchImpl, options.rpcUrl, "eth_getLogs", [{
    address: options.addresses,
    fromBlock: options.fromBlock,
    toBlock: options.toBlock,
    topics: [FLOWPULSE_EVENT_TOPIC0],
  }]);

  const rawLogs: RawFlowPulseLogFixture[] = [];
  for (const log of logs) {
    const receipt = await rpc<RpcReceipt>(fetchImpl, options.rpcUrl, "eth_getTransactionReceipt", [log.transactionHash]);
    rawLogs.push({
      chainId,
      address: log.address,
      topics: log.topics,
      data: log.data,
      blockNumber: quantityToDecimalString(log.blockNumber),
      blockHash: log.blockHash,
      transactionHash: log.transactionHash,
      transactionIndex: quantityToDecimalString(log.transactionIndex),
      logIndex: quantityToDecimalString(log.logIndex),
      receiptStatus: receipt.status === "0x1" ? "success" : "reverted",
      removed: log.removed,
    });
  }

  return {
    chainId,
    logs: rawLogs,
  };
}

export async function readLocalRpcFlowPulseLogs(options: LocalRpcReadOptions): Promise<RawFlowPulseLogFixture[]> {
  return (await readRpcFlowPulseLogSet(options)).logs;
}

export async function readRpcFlowPulseLogSet(options: LocalRpcReadOptions): Promise<RpcFlowPulseReadResult> {
  const fetchImpl = options.fetchImpl ?? fetch;
  const chainId = await readRpcChainId(fetchImpl, options.rpcUrl);
  return readRpcFlowPulseLogSetWithChainId(options, chainId, fetchImpl);
}

export async function readBaseSepoliaFlowPulseLogs(options: LocalRpcReadOptions): Promise<RpcFlowPulseReadResult> {
  const fetchImpl = options.fetchImpl ?? fetch;
  const chainId = await readRpcChainId(fetchImpl, options.rpcUrl);
  if (chainId !== BASE_SEPOLIA_CHAIN_ID) {
    throw new Error(`expected Base Sepolia chainId ${BASE_SEPOLIA_CHAIN_ID}, received ${chainId}`);
  }
  return readRpcFlowPulseLogSetWithChainId(options, chainId, fetchImpl);
}

export async function readBaseMainnetCanaryFlowPulseLogs(options: LocalRpcReadOptions): Promise<RpcFlowPulseReadResult> {
  const fetchImpl = options.fetchImpl ?? fetch;
  const chainId = await readRpcChainId(fetchImpl, options.rpcUrl);
  if (chainId !== BASE_MAINNET_CHAIN_ID) {
    throw new Error(`expected Base mainnet chainId ${BASE_MAINNET_CHAIN_ID}, received ${chainId}`);
  }
  return readRpcFlowPulseLogSetWithChainId(options, chainId, fetchImpl);
}
