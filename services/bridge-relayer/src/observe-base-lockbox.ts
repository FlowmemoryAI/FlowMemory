import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { canonicalJson, keccak256Utf8 } from "../../shared/src/index.ts";

export const BASE_MAINNET_CHAIN_ID = 8453;
export const BASE_SEPOLIA_CHAIN_ID = 84532;
export const MAX_CANARY_USD = 25;
export const MAX_BLOCK_RANGE = 5_000n;

export interface BridgeDeposit {
  schema: "flowmemory.bridge_deposit.v0";
  depositId: `0x${string}`;
  sourceChainId: 84532 | 8453;
  sourceContract: `0x${string}`;
  txHash: `0x${string}`;
  logIndex: number;
  token: `0x${string}`;
  amount: string;
  sender: `0x${string}`;
  flowchainRecipient: `0x${string}`;
  nonce: string;
  metadataHash?: `0x${string}`;
  status: "observed" | "accepted_local" | "rejected" | "released" | "failed";
}

export interface BridgeObservation {
  schema: "flowmemory.bridge_deposit_observation.v0";
  observationId: `0x${string}`;
  observedAt: string;
  mode: "mock" | "base-sepolia" | "base-mainnet-canary";
  productionReady: false;
  deposit: BridgeDeposit;
  guardrails: {
    explicitChainId: boolean;
    explicitContract: boolean;
    explicitBlockRange: boolean;
    noSecrets: boolean;
    maxUsd?: number;
  };
}

interface CliOptions {
  mode: "mock" | "base-sepolia" | "base-mainnet-canary";
  fixturePath?: string;
  outPath: string;
  rpcUrl?: string;
  lockboxAddress?: `0x${string}`;
  fromBlock?: string;
  toBlock?: string;
  acknowledgeRealFunds: boolean;
  maxUsd?: number;
}

function argValue(args: string[], index: number, name: string): string {
  const value = args[index + 1];
  if (!value || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function asAddress(value: string, name: string): `0x${string}` {
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) {
    throw new Error(`${name} must be a 20-byte hex address`);
  }
  return value.toLowerCase() as `0x${string}`;
}

function asHash(value: string, name: string): `0x${string}` {
  if (!/^0x[0-9a-fA-F]{64}$/.test(value)) {
    throw new Error(`${name} must be a 32-byte hex value`);
  }
  return value.toLowerCase() as `0x${string}`;
}

function asBlock(value: string, name: string): bigint {
  if (!/^[0-9]+$/.test(value)) {
    throw new Error(`${name} must be a decimal block number`);
  }
  return BigInt(value);
}

export function parseBridgeArgs(args: string[]): CliOptions {
  let mode: CliOptions["mode"] = "mock";
  let fixturePath: string | undefined;
  let outPath = "out/bridge-observation.json";
  let rpcUrl: string | undefined;
  let lockboxAddress: `0x${string}` | undefined;
  let fromBlock: string | undefined;
  let toBlock: string | undefined;
  let acknowledgeRealFunds = false;
  let maxUsd: number | undefined;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--mode") {
      const value = argValue(args, index, arg);
      if (value !== "mock" && value !== "base-sepolia" && value !== "base-mainnet-canary") {
        throw new Error("--mode must be mock, base-sepolia, or base-mainnet-canary");
      }
      mode = value;
      index += 1;
    } else if (arg === "--fixture") {
      fixturePath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--out") {
      outPath = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--rpc-url") {
      rpcUrl = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--lockbox-address") {
      lockboxAddress = asAddress(argValue(args, index, arg), arg);
      index += 1;
    } else if (arg === "--from-block") {
      fromBlock = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--to-block") {
      toBlock = argValue(args, index, arg);
      index += 1;
    } else if (arg === "--acknowledge-real-funds") {
      acknowledgeRealFunds = true;
    } else if (arg === "--max-usd") {
      maxUsd = Number(argValue(args, index, arg));
      index += 1;
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }

  if (mode === "mock" && !fixturePath) {
    throw new Error("--fixture is required in mock mode");
  }

  if (mode !== "mock") {
    if (!rpcUrl || !lockboxAddress || !fromBlock || !toBlock) {
      throw new Error("--rpc-url, --lockbox-address, --from-block, and --to-block are required for Base reads");
    }
    const from = asBlock(fromBlock, "--from-block");
    const to = asBlock(toBlock, "--to-block");
    if (to < from) {
      throw new Error("--to-block must be greater than or equal to --from-block");
    }
    if ((to - from) > MAX_BLOCK_RANGE) {
      throw new Error(`block range is too wide; max is ${MAX_BLOCK_RANGE.toString()} blocks`);
    }
  }

  if (mode === "base-mainnet-canary") {
    if (!acknowledgeRealFunds) {
      throw new Error("Base mainnet canary requires --acknowledge-real-funds");
    }
    if (maxUsd === undefined || !Number.isFinite(maxUsd) || maxUsd <= 0 || maxUsd > MAX_CANARY_USD) {
      throw new Error(`Base mainnet canary requires --max-usd <= ${MAX_CANARY_USD}`);
    }
  }

  return {
    mode,
    fixturePath,
    outPath,
    rpcUrl,
    lockboxAddress,
    fromBlock,
    toBlock,
    acknowledgeRealFunds,
    maxUsd,
  };
}

export function validateDeposit(value: unknown): BridgeDeposit {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("bridge deposit fixture must be an object");
  }
  const deposit = value as Record<string, unknown>;
  if (deposit.schema !== "flowmemory.bridge_deposit.v0") {
    throw new Error("unsupported bridge deposit schema");
  }
  return {
    schema: "flowmemory.bridge_deposit.v0",
    depositId: asHash(String(deposit.depositId), "depositId"),
    sourceChainId: deposit.sourceChainId === 8453 ? 8453 : deposit.sourceChainId === 84532 ? 84532 : (() => {
      throw new Error("sourceChainId must be 84532 or 8453");
    })(),
    sourceContract: asAddress(String(deposit.sourceContract), "sourceContract"),
    txHash: asHash(String(deposit.txHash), "txHash"),
    logIndex: Number(deposit.logIndex),
    token: asAddress(String(deposit.token), "token"),
    amount: String(deposit.amount),
    sender: asAddress(String(deposit.sender), "sender"),
    flowchainRecipient: asHash(String(deposit.flowchainRecipient), "flowchainRecipient"),
    nonce: String(deposit.nonce),
    metadataHash: deposit.metadataHash === undefined ? undefined : asHash(String(deposit.metadataHash), "metadataHash"),
    status: deposit.status === "observed" ? "observed" : (() => {
      throw new Error("fixture status must be observed");
    })(),
  };
}

export function makeObservation(
  deposit: BridgeDeposit,
  mode: BridgeObservation["mode"],
  maxUsd?: number,
): BridgeObservation {
  return {
    schema: "flowmemory.bridge_deposit_observation.v0",
    observationId: keccak256Utf8(canonicalJson({ deposit, mode })) as `0x${string}`,
    observedAt: "2026-05-13T00:00:00.000Z",
    mode,
    productionReady: false,
    deposit,
    guardrails: {
      explicitChainId: true,
      explicitContract: true,
      explicitBlockRange: mode !== "mock",
      noSecrets: true,
      ...(maxUsd === undefined ? {} : { maxUsd }),
    },
  };
}

async function readChainId(rpcUrl: string): Promise<number> {
  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_chainId", params: [] }),
  });
  const payload = await response.json() as { result?: string; error?: unknown };
  if (!response.ok || !payload.result) {
    throw new Error("failed to read chain id from explicit RPC URL");
  }
  return Number(BigInt(payload.result));
}

export async function runBridgeObserver(options: CliOptions): Promise<BridgeObservation> {
  if (options.mode === "mock") {
    const fixture = JSON.parse(readFileSync(resolve(options.fixturePath ?? ""), "utf8")) as unknown;
    return makeObservation(validateDeposit(fixture), "mock");
  }

  const expectedChainId = options.mode === "base-sepolia" ? BASE_SEPOLIA_CHAIN_ID : BASE_MAINNET_CHAIN_ID;
  const actualChainId = await readChainId(options.rpcUrl ?? "");
  if (actualChainId !== expectedChainId) {
    throw new Error(`wrong chain id: expected ${expectedChainId}, got ${actualChainId}`);
  }

  const syntheticDeposit: BridgeDeposit = {
    schema: "flowmemory.bridge_deposit.v0",
    depositId: keccak256Utf8(canonicalJson({
      chainId: expectedChainId,
      lockbox: options.lockboxAddress,
      fromBlock: options.fromBlock,
      toBlock: options.toBlock,
    })) as `0x${string}`,
    sourceChainId: expectedChainId,
    sourceContract: options.lockboxAddress ?? "0x0000000000000000000000000000000000000000",
    txHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
    logIndex: 0,
    token: "0x0000000000000000000000000000000000000000",
    amount: "0",
    sender: "0x0000000000000000000000000000000000000000",
    flowchainRecipient: "0x0000000000000000000000000000000000000000000000000000000000000000",
    nonce: "0",
    metadataHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
    status: "observed",
  };

  return makeObservation(syntheticDeposit, options.mode, options.maxUsd);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const options = parseBridgeArgs(process.argv.slice(2));
  const observation = await runBridgeObserver(options);
  const outPath = resolve(options.outPath);
  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(outPath, `${JSON.stringify(observation, null, 2)}\n`);
  console.log(`Wrote ${outPath}`);
}
