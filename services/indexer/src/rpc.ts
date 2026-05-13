import { FLOWPULSE_EVENT_TOPIC0, type RawFlowPulseLogFixture } from "../../shared/src/index.ts";

export interface LocalRpcReadOptions {
  rpcUrl: string;
  addresses: string[];
  fromBlock: string;
  toBlock: string;
  fetchImpl?: typeof fetch;
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

export async function readLocalRpcFlowPulseLogs(options: LocalRpcReadOptions): Promise<RawFlowPulseLogFixture[]> {
  const fetchImpl = options.fetchImpl ?? fetch;
  const chainIdQuantity = await rpc<string>(fetchImpl, options.rpcUrl, "eth_chainId", []);
  const chainId = quantityToDecimalString(chainIdQuantity);
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

  return rawLogs;
}
