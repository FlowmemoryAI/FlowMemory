import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { assertNoSecrets } from "../../shared/src/index.ts";
import {
  BASE_MAINNET_CHAIN_ID,
  BASE_MAINNET_CHAIN_ID_HEX,
  BRIDGE_DEPOSIT_TOPIC0,
  ZERO_ADDRESS,
  parseBridgeDepositLog,
  readChainId,
  rpcCall,
  type BridgeDeposit,
} from "./observe-base-lockbox.ts";
import { LIVE_BASE8453_LOCKBOX, PILOT_ACK_VALUE } from "./base8453-relay-monitor.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
export const LOCK_NATIVE_SELECTOR = "0x1326d1ec";

type DiagnosticClassification =
  | "valid_bridge_deposit"
  | "pending_or_missing_receipt"
  | "reverted_transaction"
  | "wrong_contract"
  | "wrong_method_or_direct_transfer"
  | "missing_bridge_deposit_event"
  | "cap_failure"
  | "wrong_chain";

interface RpcReceipt {
  status?: string;
  to?: string;
  transactionHash: string;
  blockNumber?: string;
  logs?: {
    address: string;
    topics: string[];
    data: string;
    blockNumber?: string;
    blockHash?: string;
    transactionHash: string;
    transactionIndex?: string;
    logIndex: string;
    removed?: boolean;
  }[];
}

interface RpcTransaction {
  to?: string | null;
  input?: string;
  value?: string;
  hash?: string;
}

interface DiagnosticOptions {
  rpcUrl: string;
  txHash: `0x${string}`;
  approvedLockbox: `0x${string}`;
  supportedTokens: `0x${string}`[];
  maxDepositAmount?: string;
  totalCapAmount?: string;
  outPath: string;
  acknowledgePilot: boolean;
}

export interface TxDiagnosticReport {
  schema: "flowmemory.base8453_tx_diagnostic.v0";
  generatedAt: string;
  sourceChain: {
    chainId: typeof BASE_MAINNET_CHAIN_ID;
    chainIdHex: typeof BASE_MAINNET_CHAIN_ID_HEX;
  };
  txHash: `0x${string}`;
  approvedLockbox: `0x${string}`;
  receipt: {
    exists: boolean;
    status: "success" | "reverted" | "missing";
  };
  checks: {
    chainIsBase8453: boolean;
    recipientIsApprovedLockbox: boolean;
    methodSelectorIsLockNative: boolean;
    bridgeDepositEventExists: boolean;
    capOk: boolean;
    tokenSupported: boolean;
  };
  classification: DiagnosticClassification;
  explanation: string;
  deposit?: Pick<BridgeDeposit, "depositId" | "txHash" | "logIndex" | "sourceBlockNumber" | "token" | "amount" | "flowchainRecipient">;
  noSecrets: true;
}

function nowIso(): string {
  return new Date().toISOString();
}

function env(name: string): string | undefined {
  const value = process.env[name];
  return value === undefined || value.trim() === "" ? undefined : value;
}

function argValue(args: string[], index: number, name: string): string {
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function asHash(value: string, name: string): `0x${string}` {
  if (!/^0x[0-9a-fA-F]{64}$/.test(value)) {
    throw new Error(`${name} must be a 32-byte hex value`);
  }
  return value.toLowerCase() as `0x${string}`;
}

function asAddress(value: string, name: string): `0x${string}` {
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) {
    throw new Error(`${name} must be a 20-byte hex address`);
  }
  return value.toLowerCase() as `0x${string}`;
}

function parseAddressList(value: string, name: string): `0x${string}`[] {
  return value
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0)
    .map((entry) => asAddress(entry, name));
}

function writeJson(path: string, value: unknown): void {
  const outPath = resolve(REPO_ROOT, path);
  mkdirSync(dirname(outPath), { recursive: true });
  assertNoSecrets(value);
  writeFileSync(outPath, `${JSON.stringify(value, null, 2)}\n`);
}

function selector(input: string | undefined): string {
  if (input === undefined || input === "0x" || input.length < 10) {
    return "0x";
  }
  return input.slice(0, 10).toLowerCase();
}

function txRecipient(tx: RpcTransaction | null, receipt: RpcReceipt | null): string | null {
  return (tx?.to ?? receipt?.to ?? null)?.toLowerCase() ?? null;
}

function capOk(deposit: BridgeDeposit | undefined, options: DiagnosticOptions): boolean {
  if (deposit === undefined) {
    return true;
  }
  if (options.maxDepositAmount !== undefined && BigInt(deposit.amount) > BigInt(options.maxDepositAmount)) {
    return false;
  }
  if (options.totalCapAmount !== undefined && BigInt(deposit.amount) > BigInt(options.totalCapAmount)) {
    return false;
  }
  return true;
}

function tokenSupported(deposit: BridgeDeposit | undefined, options: DiagnosticOptions): boolean {
  if (deposit === undefined || options.supportedTokens.length === 0) {
    return true;
  }
  const supported = new Set(options.supportedTokens.map((token) => token.toLowerCase()));
  return supported.has(deposit.token.toLowerCase());
}

function classify(
  chainOk: boolean,
  receipt: RpcReceipt | null,
  recipientOk: boolean,
  selectorOk: boolean,
  eventExists: boolean,
  capAllowed: boolean,
): { classification: DiagnosticClassification; explanation: string } {
  if (!chainOk) {
    return {
      classification: "wrong_chain",
      explanation: "RPC endpoint is not Base 8453; no bridge credit should be derived from this diagnostic.",
    };
  }
  if (receipt === null) {
    return {
      classification: "pending_or_missing_receipt",
      explanation: "Receipt is missing; the transaction is pending, unknown, or pruned by the endpoint.",
    };
  }
  if (receipt.status !== "0x1") {
    return {
      classification: "reverted_transaction",
      explanation: "Receipt status is not successful; reverted transactions do not create bridge credits.",
    };
  }
  if (!recipientOk) {
    return {
      classification: "wrong_contract",
      explanation: "Transaction recipient is not the approved lockbox.",
    };
  }
  if (!selectorOk) {
    return {
      classification: "wrong_method_or_direct_transfer",
      explanation: "Transaction did not call lockNative(bytes32,bytes32); direct ETH sends or wrong selectors are not bridge deposits.",
    };
  }
  if (!eventExists) {
    return {
      classification: "missing_bridge_deposit_event",
      explanation: "Transaction reached the lockbox selector but did not emit BridgeDeposit.",
    };
  }
  if (!capAllowed) {
    return {
      classification: "cap_failure",
      explanation: "BridgeDeposit exists, but amount or token is outside configured pilot caps.",
    };
  }
  return {
    classification: "valid_bridge_deposit",
    explanation: "Receipt succeeded, recipient is the approved lockbox, selector is lockNative, and BridgeDeposit exists.",
  };
}

export async function diagnoseTx(options: DiagnosticOptions): Promise<TxDiagnosticReport> {
  if (!options.acknowledgePilot) {
    throw new Error(`Base 8453 transaction diagnostics require operator acknowledgement ${PILOT_ACK_VALUE}`);
  }

  const chainId = await readChainId(options.rpcUrl);
  const chainOk = chainId === BASE_MAINNET_CHAIN_ID;
  const receipt = await rpcCall<RpcReceipt | null>(options.rpcUrl, "eth_getTransactionReceipt", [options.txHash]);
  const tx = await rpcCall<RpcTransaction | null>(options.rpcUrl, "eth_getTransactionByHash", [options.txHash]);
  const recipient = txRecipient(tx, receipt);
  const recipientOk = recipient === options.approvedLockbox.toLowerCase();
  const selectorOk = selector(tx?.input) === LOCK_NATIVE_SELECTOR;
  const bridgeLogs = (receipt?.logs ?? []).filter((log) => {
    return log.address.toLowerCase() === options.approvedLockbox.toLowerCase()
      && log.topics[0]?.toLowerCase() === BRIDGE_DEPOSIT_TOPIC0.toLowerCase();
  });
  const deposits = bridgeLogs.map((log) => parseBridgeDepositLog(log, BASE_MAINNET_CHAIN_ID));
  const deposit = deposits[0];
  const capAllowed = capOk(deposit, options) && tokenSupported(deposit, options);
  const decision = classify(chainOk, receipt, recipientOk, selectorOk, deposits.length > 0, capAllowed);

  return {
    schema: "flowmemory.base8453_tx_diagnostic.v0",
    generatedAt: nowIso(),
    sourceChain: {
      chainId: BASE_MAINNET_CHAIN_ID,
      chainIdHex: BASE_MAINNET_CHAIN_ID_HEX,
    },
    txHash: options.txHash,
    approvedLockbox: options.approvedLockbox,
    receipt: {
      exists: receipt !== null,
      status: receipt === null ? "missing" : receipt.status === "0x1" ? "success" : "reverted",
    },
    checks: {
      chainIsBase8453: chainOk,
      recipientIsApprovedLockbox: recipientOk,
      methodSelectorIsLockNative: selectorOk,
      bridgeDepositEventExists: deposits.length > 0,
      capOk: capAllowed,
      tokenSupported: tokenSupported(deposit, options),
    },
    classification: decision.classification,
    explanation: decision.explanation,
    deposit: deposit === undefined ? undefined : {
      depositId: deposit.depositId,
      txHash: deposit.txHash,
      logIndex: deposit.logIndex,
      sourceBlockNumber: deposit.sourceBlockNumber,
      token: deposit.token,
      amount: deposit.amount,
      flowchainRecipient: deposit.flowchainRecipient,
    },
    noSecrets: true,
  };
}

export function parseDiagnosticArgs(args: string[]): DiagnosticOptions {
  let rpcUrl = env("FLOWCHAIN_BASE8453_RPC_URL") ?? "";
  let txHash: `0x${string}` | undefined;
  let approvedLockbox = asAddress(env("FLOWCHAIN_BASE8453_APPROVED_LOCKBOX_ADDRESS") ?? env("FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS") ?? LIVE_BASE8453_LOCKBOX, "--approved-lockbox");
  let supportedTokens = parseAddressList(env("FLOWCHAIN_BASE8453_SUPPORTED_TOKEN") ?? ZERO_ADDRESS, "--supported-token");
  let supportedTokensExplicit = env("FLOWCHAIN_BASE8453_SUPPORTED_TOKEN") !== undefined;
  let maxDepositAmount = env("FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI");
  let totalCapAmount = env("FLOWCHAIN_PILOT_TOTAL_CAP_WEI");
  let outPath = "devnet/local/live-base8453-relay/tx-diagnostic.json";
  let acknowledgePilot = env("FLOWCHAIN_PILOT_OPERATOR_ACK") === PILOT_ACK_VALUE;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--rpc-url") {
      rpcUrl = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--tx" || arg === "--tx-hash") {
      txHash = asHash(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--approved-lockbox" || arg === "--lockbox-address") {
      approvedLockbox = asAddress(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--supported-token") {
      if (!supportedTokensExplicit) {
        supportedTokens = [];
        supportedTokensExplicit = true;
      }
      supportedTokens.push(asAddress(argValue(args, index, arg), arg));
      index += 1;
    } else if (arg === "--supported-tokens") {
      supportedTokens = parseAddressList(argValue(args, index, arg), arg);
      supportedTokensExplicit = true;
      index += 1;
    } else if (arg === "--max-deposit-amount") {
      maxDepositAmount = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--total-cap-amount") {
      totalCapAmount = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--out") {
      outPath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--acknowledge-pilot") {
      acknowledgePilot = true;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  if (rpcUrl.trim() === "") {
    throw new Error("FLOWCHAIN_BASE8453_RPC_URL or --rpc-url is required for tx diagnostics");
  }
  if (txHash === undefined) {
    throw new Error("--tx-hash is required for tx diagnostics");
  }

  return {
    rpcUrl,
    txHash,
    approvedLockbox,
    supportedTokens: [...new Set(supportedTokens)].sort() as `0x${string}`[],
    maxDepositAmount,
    totalCapAmount,
    outPath,
    acknowledgePilot,
  };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const options = parseDiagnosticArgs(process.argv.slice(2));
  const report = await diagnoseTx(options);
  writeJson(options.outPath, report);
  console.log(`Base 8453 tx diagnostic: ${report.classification}`);
  console.log(report.explanation);
}
