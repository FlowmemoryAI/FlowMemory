import {
  FlowChainBridgeNotReadyError,
  FlowChainMissingLiveConfigError,
  FlowChainRpcUnreachableError,
  mapRpcError,
} from "./errors.ts";
import { safeJson } from "./redaction.ts";
import { validateSignedEnvelope } from "./envelope.ts";
import type {
  FlowChainBridgeReadiness,
  FlowChainClientOptions,
  FlowChainDiscovery,
  FlowChainReadiness,
  FlowChainRpcMethod,
  FlowChainRpcResponse,
  FlowChainTransactionReceipt,
  JsonObject,
  JsonValue,
  SubmitSignedTransactionOptions,
} from "./types.ts";

export const DEFAULT_FLOWCHAIN_RPC_URL = "http://127.0.0.1:8787/rpc";

function browserEndpoint(rpcUrl: string, path: string): string {
  const base = new URL(rpcUrl);
  base.pathname = path;
  base.search = "";
  base.hash = "";
  return base.toString();
}

function jsonObject(value: JsonValue | undefined): JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : {};
}

async function fetchWithOptionalTimeout(fetchImpl: typeof fetch, url: string, init: RequestInit, timeoutMs: number): Promise<Response> {
  if (timeoutMs <= 0 || typeof AbortController === "undefined") {
    return fetchImpl(url, init);
  }
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetchImpl(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

export class FlowChainClient {
  readonly rpcUrl: string;
  readonly requestTimeoutMs: number;
  readonly headers: Record<string, string>;
  readonly fetchImpl: typeof fetch;
  #nextId = 1;

  constructor(options: FlowChainClientOptions = {}) {
    this.rpcUrl = options.rpcUrl ?? DEFAULT_FLOWCHAIN_RPC_URL;
    this.requestTimeoutMs = options.requestTimeoutMs ?? 15000;
    this.headers = options.headers ?? {};
    const fetchImpl = options.fetch ?? globalThis.fetch;
    if (typeof fetchImpl !== "function") {
      throw new FlowChainRpcUnreachableError(this.rpcUrl, "fetch is unavailable");
    }
    this.fetchImpl = fetchImpl.bind(globalThis) as typeof fetch;
  }

  async rpc<T extends JsonValue = JsonValue>(method: FlowChainRpcMethod | string, params?: JsonValue): Promise<T> {
    const body = {
      jsonrpc: "2.0",
      id: this.#nextId++,
      method,
      params: params ?? {},
    };
    let response: Response;
    try {
      response = await fetchWithOptionalTimeout(this.fetchImpl, this.rpcUrl, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          ...this.headers,
        },
        body: safeJson(body),
      }, this.requestTimeoutMs);
    } catch (error) {
      throw new FlowChainRpcUnreachableError(this.rpcUrl, error);
    }

    if (!response.ok) {
      throw new FlowChainRpcUnreachableError(this.rpcUrl, `HTTP ${response.status}`);
    }

    let envelope: FlowChainRpcResponse<T>;
    try {
      envelope = await response.json() as FlowChainRpcResponse<T>;
    } catch (error) {
      throw new FlowChainRpcUnreachableError(this.rpcUrl, error);
    }

    if ("error" in envelope) {
      throw mapRpcError(method, params, envelope.error);
    }
    return envelope.result;
  }

  async getJson<T extends JsonValue = JsonValue>(path: string): Promise<T> {
    const url = browserEndpoint(this.rpcUrl, path);
    let response: Response;
    try {
      response = await fetchWithOptionalTimeout(this.fetchImpl, url, {
        method: "GET",
        headers: this.headers,
      }, this.requestTimeoutMs);
    } catch (error) {
      throw new FlowChainRpcUnreachableError(url, error);
    }
    if (!response.ok) {
      throw new FlowChainRpcUnreachableError(url, `HTTP ${response.status}`);
    }
    return await response.json() as T;
  }

  discover(): Promise<FlowChainDiscovery> {
    return this.rpc("rpc_discover") as Promise<FlowChainDiscovery>;
  }

  readiness(): Promise<FlowChainReadiness> {
    return this.rpc("rpc_readiness") as Promise<FlowChainReadiness>;
  }

  discoverHttp(): Promise<FlowChainDiscovery> {
    return this.getJson("/rpc/discover") as Promise<FlowChainDiscovery>;
  }

  readinessHttp(): Promise<FlowChainReadiness> {
    return this.getJson("/rpc/readiness") as Promise<FlowChainReadiness>;
  }

  health(): Promise<JsonObject> {
    return this.rpc("health") as Promise<JsonObject>;
  }

  nodeStatus(): Promise<JsonObject> {
    return this.rpc("node_status") as Promise<JsonObject>;
  }

  peerList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("peer_list", params) as Promise<JsonObject>;
  }

  chainStatus(): Promise<JsonObject> {
    return this.rpc("chain_status") as Promise<JsonObject>;
  }

  blockList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("block_list", params) as Promise<JsonObject>;
  }

  blockGet(params: JsonObject): Promise<JsonObject> {
    return this.rpc("block_get", params) as Promise<JsonObject>;
  }

  transactionList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("transaction_list", params) as Promise<JsonObject>;
  }

  transactionGet(params: JsonObject): Promise<JsonObject> {
    return this.rpc("transaction_get", params) as Promise<JsonObject>;
  }

  mempoolList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("mempool_list", params) as Promise<JsonObject>;
  }

  accountList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("account_list", params) as Promise<JsonObject>;
  }

  accountGet(accountId: string): Promise<JsonObject> {
    return this.rpc("account_get", { accountId }) as Promise<JsonObject>;
  }

  balanceGet(accountId: string): Promise<JsonObject> {
    return this.rpc("balance_get", { accountId }) as Promise<JsonObject>;
  }

  walletMetadataList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("wallet_metadata_list", params) as Promise<JsonObject>;
  }

  walletMetadataGet(walletId: string): Promise<JsonObject> {
    return this.rpc("wallet_metadata_get", { walletId }) as Promise<JsonObject>;
  }

  walletBalances(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("wallet_balance_list", params) as Promise<JsonObject>;
  }

  transferHistory(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("wallet_transfer_history", params) as Promise<JsonObject>;
  }

  tokenList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("token_list", params) as Promise<JsonObject>;
  }

  tokenGet(params: JsonObject): Promise<JsonObject> {
    return this.rpc("token_get", params) as Promise<JsonObject>;
  }

  tokenBalanceList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("token_balance_list", params) as Promise<JsonObject>;
  }

  tokenBalanceGet(params: JsonObject): Promise<JsonObject> {
    return this.rpc("token_balance_get", params) as Promise<JsonObject>;
  }

  poolList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("pool_list", params) as Promise<JsonObject>;
  }

  poolGet(poolId: string): Promise<JsonObject> {
    return this.rpc("pool_get", { poolId }) as Promise<JsonObject>;
  }

  swapList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("swap_list", params) as Promise<JsonObject>;
  }

  swapGet(params: JsonObject): Promise<JsonObject> {
    return this.rpc("swap_get", params) as Promise<JsonObject>;
  }

  lpPositionList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("lp_position_list", params) as Promise<JsonObject>;
  }

  lpPositionGet(positionId: string): Promise<JsonObject> {
    return this.rpc("lp_position_get", { positionId }) as Promise<JsonObject>;
  }

  productFlowStatus(): Promise<JsonObject> {
    return this.rpc("product_flow_status") as Promise<JsonObject>;
  }

  bridgeReadiness(): Promise<FlowChainBridgeReadiness> {
    return this.rpc("bridge_live_readiness") as Promise<FlowChainBridgeReadiness>;
  }

  bridgeStatus(): Promise<JsonObject> {
    return this.rpc("bridge_status") as Promise<JsonObject>;
  }

  bridgeDepositList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("bridge_deposit_list", params) as Promise<JsonObject>;
  }

  bridgeDepositGet(params: JsonObject): Promise<JsonObject> {
    return this.rpc("bridge_deposit_get", params) as Promise<JsonObject>;
  }

  bridgeCreditList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("bridge_credit_list", params) as Promise<JsonObject>;
  }

  bridgeCreditGet(params: JsonObject): Promise<JsonObject> {
    return this.rpc("bridge_credit_get", params) as Promise<JsonObject>;
  }

  bridgeCreditStatus(params: JsonObject): Promise<JsonObject> {
    return this.rpc("bridge_credit_status", params) as Promise<JsonObject>;
  }

  withdrawalList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("withdrawal_list", params) as Promise<JsonObject>;
  }

  withdrawalGet(params: JsonObject): Promise<JsonObject> {
    return this.rpc("withdrawal_get", params) as Promise<JsonObject>;
  }

  pilotStatus(): Promise<JsonObject> {
    return this.rpc("pilot_status") as Promise<JsonObject>;
  }

  pilotDeposits(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("pilot_deposit_observation_list", params) as Promise<JsonObject>;
  }

  pilotCredits(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("pilot_credit_list", params) as Promise<JsonObject>;
  }

  pilotWithdrawals(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("pilot_withdrawal_intent_list", params) as Promise<JsonObject>;
  }

  pilotReleaseEvidence(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("pilot_release_evidence_list", params) as Promise<JsonObject>;
  }

  pilotLifecycle(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("pilot_lifecycle_record_list", params) as Promise<JsonObject>;
  }

  finalityList(params: JsonObject = {}): Promise<JsonObject> {
    return this.rpc("finality_list", params) as Promise<JsonObject>;
  }

  finalityGet(params: JsonObject): Promise<JsonObject> {
    return this.rpc("finality_get", params) as Promise<JsonObject>;
  }

  provenanceGet(params: JsonObject): Promise<JsonObject> {
    return this.rpc("provenance_get", params) as Promise<JsonObject>;
  }

  async submitSignedTransaction(envelope: unknown, options: SubmitSignedTransactionOptions = {}): Promise<FlowChainTransactionReceipt> {
    const signedEnvelope = validateSignedEnvelope(envelope);
    const params: JsonObject = {
      signedEnvelope,
      submittedBy: options.submittedBy ?? "flowchain-sdk",
    };
    if (options.runtimeSubmit !== undefined) {
      params.runtimeSubmit = options.runtimeSubmit;
    }
    if (options.runtimeSubmitMode !== undefined) {
      params.runtimeSubmitMode = options.runtimeSubmitMode;
    }
    return this.rpc("transaction_submit", params) as Promise<FlowChainTransactionReceipt>;
  }

  async assertPublicRpcReady(readiness?: FlowChainReadiness): Promise<FlowChainReadiness> {
    readiness ??= await this.readiness();
    const missing = Array.isArray(readiness.missingProductionEnvNames)
      ? readiness.missingProductionEnvNames
      : [];
    if (readiness.publicRpcReady !== true || missing.length > 0) {
      throw new FlowChainMissingLiveConfigError(missing);
    }
    return readiness;
  }

  async assertBridgeReady(readiness?: FlowChainBridgeReadiness): Promise<FlowChainBridgeReadiness> {
    readiness ??= await this.bridgeReadiness();
    const missing = Array.isArray(readiness.missingEnvNames) ? readiness.missingEnvNames : [];
    if (readiness.readyForOperatorLivePilot !== true || readiness.failClosedStatus !== "READY_FOR_OPERATOR_LIVE_PILOT") {
      throw new FlowChainBridgeNotReadyError(missing);
    }
    return readiness;
  }
}

export function createFlowChainClient(options: FlowChainClientOptions = {}): FlowChainClient {
  return new FlowChainClient(options);
}

export function resultArray(value: JsonObject, name: string): JsonObject[] {
  const rows = jsonObject(value)[name];
  return Array.isArray(rows)
    ? rows.filter((entry): entry is JsonObject => entry !== null && typeof entry === "object" && !Array.isArray(entry))
    : [];
}
