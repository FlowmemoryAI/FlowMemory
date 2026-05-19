import { redactFlowChainText } from "./redact.ts";

export type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue };

export interface JsonRpcResponse<T extends JsonValue = JsonValue> {
  jsonrpc: "2.0";
  id: string | number | null;
  result?: T;
  error?: {
    code: number;
    message: string;
    data?: JsonValue;
  };
}

export interface FlowChainClientOptions {
  rpcUrl?: string;
  fetchImpl?: typeof fetch;
  timeoutMs?: number;
}

export interface WalletSendRequest {
  fromAccountId: string;
  toAccountId: string;
  amountUnits: string | number;
  memo?: string;
  applyBlock?: boolean;
  createRecipient?: boolean;
}

export interface WaitForTransactionRequest {
  txId?: string;
  txHash?: string;
  transactionId?: string;
  timeoutMs?: number;
  pollMs?: number;
}

export class FlowChainRpcError extends Error {
  readonly code: number;
  readonly data?: JsonValue;

  constructor(message: string, code: number, data?: JsonValue) {
    super(redactFlowChainText(message));
    this.name = "FlowChainRpcError";
    this.code = code;
    this.data = data;
  }
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function transactionLookupParams(request: WaitForTransactionRequest): Record<string, JsonValue> {
  const key = request.txHash ?? request.txId ?? request.transactionId;
  if (key === undefined || key.trim().length === 0) {
    throw new FlowChainRpcError("waitForTransaction requires txId, txHash, or transactionId", -32602);
  }
  return request.txHash !== undefined || key.startsWith("0x") ? { txHash: key } : { txId: key };
}

export class FlowChainClient {
  readonly rpcUrl: string;
  private readonly fetchImpl: typeof fetch;
  private readonly timeoutMs: number;

  constructor(options: FlowChainClientOptions = {}) {
    this.rpcUrl = options.rpcUrl ?? process.env.FLOWCHAIN_RPC_URL ?? "http://127.0.0.1:8787/rpc";
    this.fetchImpl = options.fetchImpl ?? fetch;
    this.timeoutMs = options.timeoutMs ?? 10000;
  }

  async call<T extends JsonValue = JsonValue>(method: string, params: JsonValue = {}): Promise<T> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const response = await this.fetchImpl(this.rpcUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          jsonrpc: "2.0",
          id: `flowchain-sdk:${method}`,
          method,
          params,
        }),
        signal: controller.signal,
      });
      const text = await response.text();
      let payload: JsonRpcResponse<T>;
      try {
        payload = JSON.parse(text) as JsonRpcResponse<T>;
      } catch {
        throw new FlowChainRpcError(`FlowChain RPC returned non-JSON response: ${redactFlowChainText(text)}`, -32700);
      }
      if (!response.ok) {
        throw new FlowChainRpcError(`FlowChain RPC HTTP ${response.status}: ${redactFlowChainText(text)}`, response.status);
      }
      if (payload.error !== undefined) {
        throw new FlowChainRpcError(payload.error.message, payload.error.code, payload.error.data);
      }
      if (payload.result === undefined) {
        throw new FlowChainRpcError(`FlowChain RPC ${method} returned no result`, -32603);
      }
      return payload.result;
    } catch (error) {
      if (error instanceof FlowChainRpcError) throw error;
      if (error instanceof Error && error.name === "AbortError") {
        throw new FlowChainRpcError(`FlowChain RPC timed out after ${this.timeoutMs}ms`, -32001);
      }
      const message = error instanceof Error ? error.message : String(error);
      throw new FlowChainRpcError(`FlowChain RPC unreachable: ${message}`, -32000);
    } finally {
      clearTimeout(timeout);
    }
  }

  async postControlPlane<T extends JsonValue = JsonValue>(path: string, payload: JsonValue): Promise<T> {
    const endpoint = new URL(this.rpcUrl);
    endpoint.pathname = path;
    endpoint.search = "";
    endpoint.hash = "";
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const response = await this.fetchImpl(endpoint, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      const text = await response.text();
      let body: JsonValue;
      try {
        body = JSON.parse(text) as JsonValue;
      } catch {
        throw new FlowChainRpcError(`FlowChain control-plane returned non-JSON response: ${redactFlowChainText(text)}`, -32700);
      }
      if (!response.ok) {
        throw new FlowChainRpcError(`FlowChain control-plane HTTP ${response.status}: ${redactFlowChainText(text)}`, response.status, body);
      }
      return body as T;
    } catch (error) {
      if (error instanceof FlowChainRpcError) throw error;
      if (error instanceof Error && error.name === "AbortError") {
        throw new FlowChainRpcError(`FlowChain control-plane timed out after ${this.timeoutMs}ms`, -32001);
      }
      const message = error instanceof Error ? error.message : String(error);
      throw new FlowChainRpcError(`FlowChain control-plane unreachable: ${message}`, -32000);
    } finally {
      clearTimeout(timeout);
    }
  }

  rpcDiscover() {
    return this.call("rpc_discover");
  }

  rpcReadiness() {
    return this.call("rpc_readiness");
  }

  health() {
    return this.call("health");
  }

  nodeStatus() {
    return this.call("node_status");
  }

  peerList(params: JsonValue = { limit: 10 }) {
    return this.call("peer_list", params);
  }

  chainStatus() {
    return this.call("chain_status");
  }

  blockList(params: JsonValue = { limit: 10 }) {
    return this.call("block_list", params);
  }

  blockGet(params: JsonValue) {
    return this.call("block_get", params);
  }

  transactionList(params: JsonValue = { limit: 10 }) {
    return this.call("transaction_list", params);
  }

  transactionGet(params: JsonValue) {
    return this.call("transaction_get", params);
  }

  async waitForTransaction(request: WaitForTransactionRequest) {
    const params = transactionLookupParams(request);
    const txId = typeof params.txId === "string" ? params.txId : null;
    const txHash = typeof params.txHash === "string" ? params.txHash : null;
    const timeoutMs = request.timeoutMs ?? 30000;
    const pollMs = Math.max(100, request.pollMs ?? 1000);
    const startedAt = Date.now();
    let attempts = 0;
    let lastNotFound: FlowChainRpcError | null = null;

    while (Date.now() - startedAt <= timeoutMs) {
      attempts += 1;
      try {
        const transaction = await this.transactionGet(params);
        return {
          schema: "flowchain.sdk.wait_transaction.v0",
          status: "included",
          txId,
          txHash,
          attempts,
          elapsedMs: Date.now() - startedAt,
          transaction,
        } satisfies JsonValue;
      } catch (error) {
        if (!(error instanceof FlowChainRpcError) || error.code !== -32004) {
          throw error;
        }
        lastNotFound = error;
      }

      const elapsedMs = Date.now() - startedAt;
      if (elapsedMs >= timeoutMs) break;
      await sleep(Math.min(pollMs, timeoutMs - elapsedMs));
    }

    return {
      schema: "flowchain.sdk.wait_transaction.v0",
      status: "timeout",
      txId,
      txHash,
      attempts,
      elapsedMs: Date.now() - startedAt,
      transaction: null,
      lastError: lastNotFound === null
        ? null
        : {
            code: lastNotFound.code,
            message: lastNotFound.message,
          },
    } satisfies JsonValue;
  }

  mempoolList(params: JsonValue = { limit: 10 }) {
    return this.call("mempool_list", params);
  }

  accountList(params: JsonValue = { limit: 10 }) {
    return this.call("account_list", params);
  }

  accountGet(params: JsonValue) {
    return this.call("account_get", params);
  }

  balanceGet(params: JsonValue) {
    return this.call("balance_get", params);
  }

  walletMetadataList(params: JsonValue = { limit: 10 }) {
    return this.call("wallet_metadata_list", params);
  }

  walletMetadataGet(params: JsonValue) {
    return this.call("wallet_metadata_get", params);
  }

  walletBalances(params: JsonValue = { limit: 10 }) {
    return this.call("wallet_balance_list", params);
  }

  walletTransfers(params: JsonValue = { limit: 10 }) {
    return this.call("wallet_transfer_history", params);
  }

  faucetEventList(params: JsonValue = { limit: 10 }) {
    return this.call("faucet_event_list", params);
  }

  finalityList(params: JsonValue = { limit: 10 }) {
    return this.call("finality_list", params);
  }

  finalityGet(params: JsonValue) {
    return this.call("finality_get", params);
  }

  bridgeReadiness() {
    return this.call("bridge_live_readiness");
  }

  bridgeStatus() {
    return this.call("bridge_status");
  }

  bridgeDepositList(params: JsonValue = { limit: 10 }) {
    return this.call("bridge_deposit_list", params);
  }

  bridgeDepositGet(params: JsonValue) {
    return this.call("bridge_deposit_get", params);
  }

  bridgeCreditList(params: JsonValue = { limit: 10 }) {
    return this.call("bridge_credit_list", params);
  }

  bridgeCreditGet(params: JsonValue) {
    return this.call("bridge_credit_get", params);
  }

  bridgeCreditStatus(params: JsonValue) {
    return this.call("bridge_credit_status", params);
  }

  withdrawalList(params: JsonValue = { limit: 10 }) {
    return this.call("withdrawal_list", params);
  }

  withdrawalGet(params: JsonValue) {
    return this.call("withdrawal_get", params);
  }

  walletSend(request: WalletSendRequest) {
    return this.postControlPlane("/wallets/send", request as unknown as JsonValue);
  }
}
