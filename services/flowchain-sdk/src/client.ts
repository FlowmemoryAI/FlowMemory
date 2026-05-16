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

  rpcDiscover() {
    return this.call("rpc_discover");
  }

  rpcReadiness() {
    return this.call("rpc_readiness");
  }

  chainStatus() {
    return this.call("chain_status");
  }

  walletBalances(params: JsonValue = { limit: 10 }) {
    return this.call("wallet_balance_list", params);
  }

  walletTransfers(params: JsonValue = { limit: 10 }) {
    return this.call("wallet_transfer_history", params);
  }

  bridgeReadiness() {
    return this.call("bridge_live_readiness");
  }

  bridgeStatus() {
    return this.call("bridge_status");
  }
}
