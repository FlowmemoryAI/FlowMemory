import { DEFAULT_CONTROL_PLANE_URL } from "./workbench";

const REQUEST_TIMEOUT_MS = 1200;

export const PLACEHOLDER_FLOWCHAIN_RECIPIENT = /^0x5{64}$/i;
export const FLOWCHAIN_ACCOUNT_PATTERN = /^0x[0-9a-fA-F]{64}$/;
export const ZERO_METADATA_HASH = `0x${"0".repeat(64)}`;

type JsonObject = Record<string, unknown>;

function isRecord(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export interface BridgeControlPlaneHealth {
  status?: string;
  localOnly?: boolean;
  routes?: string[];
  capabilities?: string[];
  [key: string]: unknown;
}

export interface BridgeCredit {
  creditId?: string;
  depositId?: string;
  accountId?: string;
  txHash?: string;
  baseTxHash?: string;
  status?: string;
  token?: string;
  amount?: string;
  sourceChainId?: string;
  appliedAt?: string;
  placeholderRecipient?: boolean;
  valueBearingPilot?: boolean;
  [key: string]: unknown;
}

export interface BridgeDeposit {
  depositId?: string;
  observationId?: string;
  txHash?: string;
  flowchainRecipient?: string;
  status?: string;
  token?: string;
  amount?: string;
  sourceChainId?: string;
  observedAt?: string;
  [key: string]: unknown;
}

export interface BridgeCreditStatus {
  schema?: string;
  readinessLabel?: "LIVE PILOT" | "LOCAL ONLY" | "NOT READY" | string;
  exposureLabel?: "LOCAL ONLY" | string;
  livePilot?: boolean;
  localOnly?: boolean;
  usingFixtureFallback?: boolean;
  source?: JsonObject;
  baseTxHash?: string | null;
  confirmationStatus?: string;
  lifecycleStatus?: {
    observed?: string;
    queued?: string;
    applied?: string;
    idempotent?: string;
    [key: string]: unknown;
  };
  creditedAccount?: string | null;
  tokenId?: string | null;
  amount?: string | null;
  spendableBalance?: string | null;
  balanceBreakdown?: {
    localAmount?: string;
    bridgeCreditAmount?: string;
    pendingAcceptedDelta?: string;
    [key: string]: unknown;
  } | null;
  transferActionStatus?: string;
  latestTransferReceipt?: unknown;
  firstUsableAt?: string | null;
  latencyMs?: number | null;
  placeholderRecipient?: boolean;
  matchedCounts?: {
    credits?: number;
    deposits?: number;
  };
  credit?: BridgeCredit | null;
  deposit?: BridgeDeposit | null;
  noBaseReleaseBroadcast?: boolean;
  cappedOwnerTesting?: boolean;
  [key: string]: unknown;
}

export interface BridgeLiveSnapshot {
  baseUrl: string;
  fetchedAt: string;
  health: BridgeControlPlaneHealth;
  status: BridgeCreditStatus;
  credits: BridgeCredit[];
  deposits: BridgeDeposit[];
  txLookup: BridgeCredit | null;
}

export interface LockNativeDraft {
  schema: "flowmemory.dashboard.lock_native_draft.v1";
  functionName: "lockNative";
  signature: "lockNative(bytes32 flowchainRecipient, bytes32 metadataHash)";
  args: {
    flowchainRecipient: string;
    metadataHash: string;
  };
  operatorConfirmedRecipient: true;
  noBroadcast: true;
  localOnly: true;
}

export interface TransferSendParams {
  from: string;
  to: string;
  amount: string;
  tokenId?: string | null;
  memo?: string;
}

export interface TransferSendResult {
  schema?: string;
  accepted?: boolean;
  txId?: string;
  status?: string;
  from?: string;
  to?: string;
  tokenId?: string;
  amount?: string;
  receipt?: unknown;
  noBaseReleaseBroadcast?: boolean;
  localOnly?: boolean;
  [key: string]: unknown;
}

function bridgeControlPlaneUrl(): string {
  const env = (import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env;
  const configured = env?.VITE_FLOWCHAIN_CONTROL_PLANE_URL?.trim();
  return configured && configured.length > 0 ? configured.replace(/\/+$/, "") : DEFAULT_CONTROL_PLANE_URL;
}

async function fetchJson<T>(url: string, init?: RequestInit): Promise<T> {
  const controller = new AbortController();
  const timeout = globalThis.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      cache: "no-store",
      ...init,
      headers: {
        Accept: "application/json",
        ...init?.headers,
      },
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(`${response.status} ${response.statusText}`.trim());
    }
    return (await response.json()) as T;
  } finally {
    globalThis.clearTimeout(timeout);
  }
}

async function rpc<T>(baseUrl: string, method: string, params?: JsonObject): Promise<T> {
  const response = await fetchJson<{ result?: T; error?: { message?: string; data?: unknown } }>(`${baseUrl}/rpc`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: method, method, params }),
  });

  if (response.error !== undefined) {
    throw new Error(response.error.message ?? `Control-plane RPC failed: ${method}`);
  }
  if (response.result === undefined) {
    throw new Error(`Control-plane RPC returned no result: ${method}`);
  }
  return response.result;
}

function listCredits(payload: unknown): BridgeCredit[] {
  const record = payload as { credits?: unknown };
  return Array.isArray(record.credits) ? (record.credits as BridgeCredit[]) : [];
}

function listDeposits(payload: unknown): BridgeDeposit[] {
  const record = payload as { deposits?: unknown };
  return Array.isArray(record.deposits) ? (record.deposits as BridgeDeposit[]) : [];
}

export function getBridgeControlPlaneUrl(): string {
  return bridgeControlPlaneUrl();
}

export function isPlaceholderFlowchainRecipient(value: string | null | undefined): boolean {
  return typeof value === "string" && PLACEHOLDER_FLOWCHAIN_RECIPIENT.test(value);
}

export function isUsableFlowchainRecipient(value: string | null | undefined): value is string {
  return typeof value === "string" && FLOWCHAIN_ACCOUNT_PATTERN.test(value) && !isPlaceholderFlowchainRecipient(value);
}

export function flowchainAccountFromBytes(bytes: Uint8Array): string {
  if (bytes.length !== 32) {
    throw new Error("FlowChain account bytes must be exactly 32 bytes.");
  }
  return `0x${Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")}`;
}

export function generateFlowchainAccount(): string {
  const bytes = new Uint8Array(32);
  globalThis.crypto.getRandomValues(bytes);
  return flowchainAccountFromBytes(bytes);
}

export function buildLockNativeDraft(flowchainRecipient: string, metadataHash = ZERO_METADATA_HASH): LockNativeDraft {
  if (!isUsableFlowchainRecipient(flowchainRecipient)) {
    throw new Error("A real 32-byte FlowChain recipient is required before preparing lockNative.");
  }
  if (!FLOWCHAIN_ACCOUNT_PATTERN.test(metadataHash)) {
    throw new Error("metadataHash must be a 32-byte hex value.");
  }
  return {
    schema: "flowmemory.dashboard.lock_native_draft.v1",
    functionName: "lockNative",
    signature: "lockNative(bytes32 flowchainRecipient, bytes32 metadataHash)",
    args: {
      flowchainRecipient,
      metadataHash,
    },
    operatorConfirmedRecipient: true,
    noBroadcast: true,
    localOnly: true,
  };
}

export function candidateBridgeAccounts(status: BridgeCreditStatus | null, credits: BridgeCredit[]): string[] {
  const accounts = [
    status?.creditedAccount,
    status?.credit?.accountId,
    status?.deposit?.flowchainRecipient,
    ...credits.map((credit) => credit.accountId),
  ];
  return [...new Set(accounts.filter(isUsableFlowchainRecipient))];
}

export async function lookupBridgeCreditByTxHash(baseUrl: string, txHash: string): Promise<BridgeCredit> {
  const result = await rpc<{ credit?: BridgeCredit }>(baseUrl, "bridge_credit_get", { txHash });
  if (result.credit === undefined) {
    throw new Error("Bridge credit lookup returned no credit.");
  }
  return result.credit;
}

export async function sendBridgeCreditTransfer(baseUrl: string, params: TransferSendParams): Promise<TransferSendResult> {
  const payload = await fetchJson<unknown>(`${baseUrl}/transfer/send`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(params),
  });

  if (isRecord(payload) && isRecord(payload.error)) {
    throw new Error(typeof payload.error.message === "string" ? payload.error.message : "transfer_send failed");
  }
  if (isRecord(payload) && isRecord(payload.result)) {
    return payload.result as TransferSendResult;
  }
  if (!isRecord(payload)) {
    throw new Error("transfer_send returned an invalid response.");
  }
  return payload as TransferSendResult;
}

export async function fetchBridgeLiveSnapshot(baseUrl = bridgeControlPlaneUrl()): Promise<BridgeLiveSnapshot> {
  const [health, status, creditPayload, depositPayload] = await Promise.all([
    fetchJson<BridgeControlPlaneHealth>(`${baseUrl}/health`),
    fetchJson<BridgeCreditStatus>(`${baseUrl}/bridge/credit-status`),
    fetchJson<unknown>(`${baseUrl}/bridge/credits?limit=20`),
    fetchJson<unknown>(`${baseUrl}/bridge/deposits?limit=20`),
  ]);
  const credits = listCredits(creditPayload);
  const deposits = listDeposits(depositPayload);
  const txHash = status.baseTxHash ?? credits.find((credit) => credit.txHash ?? credit.baseTxHash)?.txHash ?? credits.find((credit) => credit.baseTxHash)?.baseTxHash;
  const txLookup = txHash === undefined || txHash === null ? null : await lookupBridgeCreditByTxHash(baseUrl, txHash).catch(() => null);

  return {
    baseUrl,
    fetchedAt: new Date().toISOString(),
    health,
    status,
    credits,
    deposits,
    txLookup,
  };
}
