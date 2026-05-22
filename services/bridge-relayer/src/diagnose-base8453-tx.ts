import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { mkdirSync, writeFileSync } from "node:fs";

import {
  assertNoSecrets,
  keccak256Utf8,
  normalizeAddress,
  normalizeBytes32,
} from "../../shared/src/index.ts";
import {
  BASE_MAINNET_CHAIN_ID,
  BASE_MAINNET_CHAIN_ID_HEX,
  BRIDGE_DEPOSIT_LEGACY_TOPIC0,
  BRIDGE_DEPOSIT_TOPIC0,
  parseBridgeDepositLog,
  isPlaceholderFlowMemoryRecipient,
  ZERO_BYTES32,
  type BridgeDeposit,
} from "./observe-base-lockbox.ts";

type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue | undefined };

interface RpcReceipt {
  status?: string;
  blockNumber?: string;
  blockHash?: string;
  transactionHash: string;
  transactionIndex?: string;
  logs?: RpcLog[];
}

interface RpcTransaction {
  hash: string;
  to?: string | null;
  input?: string;
}

interface RpcLog {
  address: string;
  topics: string[];
  data: string;
  blockNumber?: string;
  blockHash?: string;
  transactionHash: string;
  transactionIndex?: string;
  logIndex: string;
  removed?: boolean;
}

export interface DiagnoseBase8453TxOptions {
  rpcUrl: string;
  txHash: `0x${string}`;
  lockboxAddress: `0x${string}`;
  supportedTokens: `0x${string}`[];
  maxDepositAmount: string;
  totalCapAmount: string;
  confirmations: number;
  targetSettlementSeconds?: number;
  estimatedBaseBlockSeconds?: number;
  pollSeconds?: number;
  outPath: string;
}

export const LOCK_NATIVE_SELECTOR = selectorFor("lockNative(bytes32,bytes32)");
export const LOCK_ERC20_SELECTOR = selectorFor("lockERC20(address,uint256,bytes32,bytes32)");

function selectorFor(signature: string): `0x${string}` {
  return keccak256Utf8(signature).slice(0, 10) as `0x${string}`;
}

function normalizeTxHash(value: string): `0x${string}` {
  return normalizeBytes32(value) as `0x${string}`;
}

function normalizeAddressList(values: string[]): `0x${string}`[] {
  return values
    .flatMap((value) => value.split(","))
    .map((value) => value.trim())
    .filter((value) => value.length > 0)
    .map((value) => normalizeAddress(value) as `0x${string}`);
}

function env(name: string): string | undefined {
  const value = process.env[name];
  return value === undefined || value.trim().length === 0 ? undefined : value;
}

function argValue(args: string[], index: number, name: string): string {
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function parsePositiveDecimal(value: string, name: string): string {
  if (!/^(0|[1-9][0-9]*)$/.test(value)) {
    throw new Error(`${name} must be a decimal uint string`);
  }
  if (BigInt(value) <= 0n) {
    throw new Error(`${name} must be greater than zero`);
  }
  return value;
}

function parseConfirmations(value: string | undefined): number {
  if (value === undefined) {
    return 2;
  }
  if (!/^(0|[1-9][0-9]*)$/.test(value)) {
    throw new Error("--confirmations must be a non-negative integer");
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    throw new Error("--confirmations must be a safe non-negative integer");
  }
  return parsed;
}

function parsePositiveFiniteNumber(value: string | undefined, name: string, fallback: number): number {
  if (value === undefined) {
    return fallback;
  }
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive finite number`);
  }
  return parsed;
}

export function parseDiagnosticArgs(args: string[]): DiagnoseBase8453TxOptions | { missingEnvNames: string[]; outPath: string } {
  let rpcUrl = env("FLOWMEMORY_BASE8453_RPC_URL");
  let txHash = env("FLOWMEMORY_BASE8453_TX_HASH") ?? env("FLOWMEMORY_BASE8453_OPERATOR_TX_HASH");
  let lockboxAddress = env("FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS");
  const supportedTokenArgs: string[] = [];
  if (env("FLOWMEMORY_BASE8453_SUPPORTED_TOKEN") !== undefined) {
    supportedTokenArgs.push(env("FLOWMEMORY_BASE8453_SUPPORTED_TOKEN") ?? "");
  }
  let maxDepositAmount = env("FLOWMEMORY_PILOT_MAX_DEPOSIT_WEI");
  let totalCapAmount = env("FLOWMEMORY_PILOT_TOTAL_CAP_WEI");
  let confirmations = env("FLOWMEMORY_PILOT_CONFIRMATIONS") ?? env("FLOWMEMORY_BASE8453_CONFIRMATION_DEPTH") ?? env("FLOWMEMORY_BASE8453_CONFIRMATIONS");
  let targetSettlementSeconds = env("FLOWMEMORY_BRIDGE_TARGET_SETTLEMENT_SECONDS");
  let estimatedBaseBlockSeconds = env("FLOWMEMORY_BASE8453_ESTIMATED_BLOCK_SECONDS");
  let pollSeconds = env("FLOWMEMORY_BRIDGE_POLL_SECONDS");
  let outPath = "local-runtime/local/live-network-bridge-e2e/base-tx-diagnostic.json";

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--rpc-url") {
      rpcUrl = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--tx-hash") {
      txHash = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--lockbox-address") {
      lockboxAddress = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--supported-token" || arg === "--supported-tokens") {
      supportedTokenArgs.push(argValue(args, index, arg));
      index += 1;
    } else if (arg === "--max-deposit-amount") {
      maxDepositAmount = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--total-cap-amount") {
      totalCapAmount = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--confirmations") {
      confirmations = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--target-settlement-seconds") {
      targetSettlementSeconds = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--estimated-base-block-seconds") {
      estimatedBaseBlockSeconds = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--poll-seconds") {
      pollSeconds = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--out") {
      outPath = argValue(args, index, arg);
      index += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  const missingEnvNames = [
    ["FLOWMEMORY_BASE8453_RPC_URL", rpcUrl],
    ["FLOWMEMORY_BASE8453_TX_HASH", txHash],
    ["FLOWMEMORY_BASE8453_LOCKBOX_ADDRESS", lockboxAddress],
    ["FLOWMEMORY_BASE8453_SUPPORTED_TOKEN", supportedTokenArgs.join(",")],
    ["FLOWMEMORY_PILOT_MAX_DEPOSIT_WEI", maxDepositAmount],
    ["FLOWMEMORY_PILOT_TOTAL_CAP_WEI", totalCapAmount],
  ].filter(([, value]) => value === undefined || String(value).trim().length === 0).map(([name]) => name);

  if (missingEnvNames.length > 0) {
    return { missingEnvNames, outPath };
  }

  return {
    rpcUrl: rpcUrl ?? "",
    txHash: normalizeTxHash(txHash ?? ""),
    lockboxAddress: normalizeAddress(lockboxAddress ?? "") as `0x${string}`,
    supportedTokens: normalizeAddressList(supportedTokenArgs),
    maxDepositAmount: parsePositiveDecimal(maxDepositAmount ?? "", "FLOWMEMORY_PILOT_MAX_DEPOSIT_WEI"),
    totalCapAmount: parsePositiveDecimal(totalCapAmount ?? "", "FLOWMEMORY_PILOT_TOTAL_CAP_WEI"),
    confirmations: parseConfirmations(confirmations),
    targetSettlementSeconds: parsePositiveFiniteNumber(targetSettlementSeconds, "FLOWMEMORY_BRIDGE_TARGET_SETTLEMENT_SECONDS", 30),
    estimatedBaseBlockSeconds: parsePositiveFiniteNumber(estimatedBaseBlockSeconds, "FLOWMEMORY_BASE8453_ESTIMATED_BLOCK_SECONDS", 2),
    pollSeconds: parsePositiveFiniteNumber(pollSeconds, "FLOWMEMORY_BRIDGE_POLL_SECONDS", 1),
    outPath,
  };
}

async function rpcCall<T>(rpcUrl: string, method: string, params: JsonValue[]): Promise<T> {
  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const payload = await response.json() as { result?: T; error?: { message?: string } };
  if (!response.ok || payload.error !== undefined) {
    throw new Error(`rpc-${method}-failed`);
  }
  return payload.result as T;
}

function hexQuantityToBigInt(value: string | undefined): bigint | null {
  if (value === undefined || !/^0x[0-9a-fA-F]+$/.test(value)) {
    return null;
  }
  return BigInt(value);
}

function safeReason(checks: Record<string, boolean | string | number | null | undefined>): string {
  if (checks.chainIdBase8453 !== true) return "wrong-chain";
  if (checks.transactionFound !== true) return "transaction-not-found";
  if (checks.receiptFound !== true) return "receipt-not-found";
  if (checks.receiptSuccess !== true) return "receipt-not-success";
  if (checks.correctLockbox !== true) return "wrong-lockbox";
  if (checks.correctSelector !== true) return "wrong-selector";
  if (checks.bridgeDepositLogExists !== true) return "bridge-deposit-log-missing";
  if (checks.bridgeDepositLogParsed !== true) return "bridge-deposit-log-invalid";
  if (checks.flowmemoryRecipientPresent !== true) return "recipient-missing";
  if (checks.flowmemoryRecipientNotPlaceholder !== true) return "recipient-placeholder";
  if (checks.tokenMatches !== true) return "unsupported-token";
  if (checks.capMatches !== true) return "cap-mismatch";
  if (checks.confirmationsSatisfied !== true) return "insufficient-confirmations";
  if (checks.fastSettlementTargetFeasible !== true) return "settlement-target-infeasible";
  return "valid";
}

function writeJson(path: string, value: unknown): void {
  const resolved = resolve(path);
  mkdirSync(dirname(resolved), { recursive: true });
  assertNoSecrets(value);
  writeFileSync(resolved, `${JSON.stringify(value, null, 2)}\n`);
}

export async function diagnoseBase8453Tx(options: DiagnoseBase8453TxOptions): Promise<Record<string, JsonValue>> {
  const checks: Record<string, boolean | string | number | null> = {
    chainIdBase8453: false,
    transactionFound: false,
    receiptFound: false,
    receiptSuccess: false,
    correctLockbox: false,
    correctSelector: false,
    bridgeDepositLogExists: false,
    bridgeDepositLogParsed: false,
    flowmemoryRecipientPresent: false,
    flowmemoryRecipientNotPlaceholder: false,
    tokenMatches: false,
    capMatches: false,
    confirmationsSatisfied: false,
    fastSettlementTargetFeasible: false,
  };

  const chainId = await rpcCall<string>(options.rpcUrl, "eth_chainId", []);
  checks.chainIdBase8453 = chainId === BASE_MAINNET_CHAIN_ID_HEX;

  const tx = await rpcCall<RpcTransaction | null>(options.rpcUrl, "eth_getTransactionByHash", [options.txHash]);
  checks.transactionFound = tx !== null;
  const receipt = await rpcCall<RpcReceipt | null>(options.rpcUrl, "eth_getTransactionReceipt", [options.txHash]);
  checks.receiptFound = receipt !== null;

  if (tx !== null) {
    checks.correctLockbox = typeof tx.to === "string" && tx.to.toLowerCase() === options.lockboxAddress.toLowerCase();
    const input = tx.input ?? "0x";
    const selector = input.length >= 10 ? input.slice(0, 10).toLowerCase() : "";
    checks.correctSelector = selector === LOCK_NATIVE_SELECTOR || selector === LOCK_ERC20_SELECTOR;
  }

  let parsedDeposits: BridgeDeposit[] = [];
  if (receipt !== null) {
    checks.receiptSuccess = receipt.status === "0x1" || receipt.status === "0x01";
    const bridgeLogs = (receipt.logs ?? []).filter((log) => {
      const topic0 = log.topics[0]?.toLowerCase();
      return topic0 === BRIDGE_DEPOSIT_TOPIC0 || topic0 === BRIDGE_DEPOSIT_LEGACY_TOPIC0;
    });
    checks.bridgeDepositLogExists = bridgeLogs.length > 0;
    for (const log of bridgeLogs) {
      try {
        const parsed = parseBridgeDepositLog(log, BASE_MAINNET_CHAIN_ID);
        if (parsed.sourceContract.toLowerCase() === options.lockboxAddress.toLowerCase()) {
          parsedDeposits.push(parsed);
        }
      } catch {
        // The report emits only a safe reason code. The malformed log details stay out of stdout and JSON.
      }
    }
    checks.bridgeDepositLogParsed = parsedDeposits.length > 0;
  }

  if (parsedDeposits.length > 0) {
    checks.flowmemoryRecipientPresent = parsedDeposits.every((deposit) => deposit.flowmemoryRecipient !== ZERO_BYTES32);
    checks.flowmemoryRecipientNotPlaceholder = parsedDeposits.every((deposit) => !isPlaceholderFlowMemoryRecipient(deposit.flowmemoryRecipient));
    const supported = new Set(options.supportedTokens.map((token) => token.toLowerCase()));
    checks.tokenMatches = parsedDeposits.every((deposit) => supported.has(deposit.token.toLowerCase()));
    const maxDeposit = BigInt(options.maxDepositAmount);
    const totalCap = BigInt(options.totalCapAmount);
    const total = parsedDeposits.reduce((sum, deposit) => sum + BigInt(deposit.amount), 0n);
    checks.capMatches = parsedDeposits.every((deposit) => BigInt(deposit.amount) <= maxDeposit) && total <= totalCap;
  }

  let latestBlock: bigint | null = null;
  let receiptBlock: bigint | null = null;
  if (receipt !== null) {
    receiptBlock = hexQuantityToBigInt(receipt.blockNumber);
    latestBlock = hexQuantityToBigInt(await rpcCall<string>(options.rpcUrl, "eth_blockNumber", []));
    if (latestBlock !== null && receiptBlock !== null) {
      checks.confirmationsSatisfied = latestBlock >= receiptBlock + BigInt(options.confirmations);
    }
  }
  const targetSettlementSeconds = options.targetSettlementSeconds ?? 30;
  const estimatedBaseBlockSeconds = options.estimatedBaseBlockSeconds ?? 2;
  const pollSeconds = options.pollSeconds ?? 1;
  const estimatedConfirmationSeconds = options.confirmations * estimatedBaseBlockSeconds;
  const estimatedDetectionSeconds = estimatedConfirmationSeconds + pollSeconds;
  checks.fastSettlementTargetFeasible = estimatedDetectionSeconds <= targetSettlementSeconds;

  const reason = safeReason(checks);
  const status = reason === "valid" ? "valid" : "invalid";
  const report = {
    schema: "flowmemory.bridge_base8453_tx_diagnostic.v0",
    generatedAt: new Date().toISOString(),
    status,
    safeReasonCode: reason,
    txHash: options.txHash,
    baseChainId: BASE_MAINNET_CHAIN_ID,
    confirmationDepthRequired: options.confirmations,
    confirmationBlocksObserved: latestBlock !== null && receiptBlock !== null
      ? (latestBlock - receiptBlock).toString()
      : null,
    settlementPolicy: {
      targetSettlementSeconds,
      estimatedBaseBlockSeconds,
      confirmationDepth: options.confirmations,
      pollSeconds,
      estimatedConfirmationSeconds,
      estimatedDetectionSeconds,
      targetFeasible: estimatedDetectionSeconds <= targetSettlementSeconds,
    },
    checks,
    counts: {
      parsedBridgeDepositLogs: parsedDeposits.length,
    },
    broadcasts: false,
    printsEnvValues: false,
    noSecrets: true,
  };
  assertNoSecrets(report);
  return report;
}

async function main(): Promise<void> {
  const parsed = parseDiagnosticArgs(process.argv.slice(2));
  if ("missingEnvNames" in parsed) {
    const report = {
      schema: "flowmemory.bridge_base8453_tx_diagnostic.v0",
      generatedAt: new Date().toISOString(),
      status: "blocked",
      safeReasonCode: "missing-env",
      missingEnvNames: parsed.missingEnvNames,
      broadcasts: false,
      printsEnvValues: false,
      noSecrets: true,
    };
    writeJson(parsed.outPath, report);
    console.log("FlowMemory bridge tx diagnostic status: blocked (missing-env)");
    console.log(`Report: ${resolve(parsed.outPath)}`);
    process.exitCode = 1;
    return;
  }

  const report = await diagnoseBase8453Tx(parsed);
  writeJson(parsed.outPath, report);
  console.log(`FlowMemory bridge tx diagnostic status: ${report.status}${report.status === "valid" ? "" : ` (${report.safeReasonCode})`}`);
  console.log(`Report: ${resolve(parsed.outPath)}`);
  if (report.status !== "valid") {
    process.exitCode = 1;
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  await main();
}
