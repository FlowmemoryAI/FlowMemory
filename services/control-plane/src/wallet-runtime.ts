import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { canonicalJson, findSecret, keccak256Hex } from "../../shared/src/index.ts";
import { spawnCargoSync } from "./cargo.ts";
import { repoRoot, resolveControlPlanePath } from "./fixture-state.ts";
import type { JsonObject, JsonValue, LoadedControlPlaneState } from "./types.ts";

const U64_MAX = (1n << 64n) - 1n;
const WEI_PER_ETH = 1_000_000_000_000_000_000n;
const LOCAL_TEST_UNIT_ASSET_ID = "local-test-unit";

type AccountResolution = {
  requestedAccountId: string;
  runtimeAccountId: string;
  resolution: "direct" | "bridge-account-mapping" | "unmapped";
};

type ParsedWalletSend = {
  fromAccountId: string;
  toAccountId: string;
  amountUnits: string;
  memo: string;
  applyBlock: boolean;
  createRecipient: boolean;
};

type ParsedLocalFaucet = {
  accountId: string;
  amountUnits: string;
  reason: string;
  applyBlock: boolean;
};

function asObject(value: JsonValue | unknown): JsonObject | null {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : null;
}

function stringValue(value: JsonValue | unknown): string | null {
  if (typeof value === "string" && value.length > 0) {
    return value;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return null;
}

function numberValue(value: JsonValue | unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && /^\d+$/.test(value)) {
    return Number.parseInt(value, 10);
  }
  return null;
}

function processIsRunning(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function runningNodeDirForState(statePath: string): string | null {
  const nodeDir = resolve(dirname(statePath), "node");
  const statusPath = resolve(nodeDir, "status.json");
  if (!existsSync(statusPath)) {
    return null;
  }
  const status = asObject(JSON.parse(readFileSync(statusPath, "utf8")));
  if (status === null || stringValue(status.status) !== "running") {
    return null;
  }
  const statusStatePath = stringValue(status.statePath);
  const pid = numberValue(status.pid);
  if (statusStatePath !== statePath || pid === null || !processIsRunning(pid)) {
    return null;
  }
  return nodeDir;
}

function transferExists(runtimeState: JsonObject, transferId: string): boolean {
  for (const key of ["balanceTransfers", "transfers", "tokenTransfers", "tokenTransferEvents"]) {
    const map = asObject(runtimeState[key]);
    if (map === null) {
      continue;
    }
    if (Object.prototype.hasOwnProperty.call(map, transferId)) {
      return true;
    }
    if (Object.values(map).some((entry) => stringValue(asObject(entry)?.transferId) === transferId)) {
      return true;
    }
  }
  return false;
}

function waitForTransfer(state: LoadedControlPlaneState, transferId: string, timeoutMs: number): JsonObject {
  const deadline = Date.now() + timeoutMs;
  let latest = readRuntimeState(state);
  while (Date.now() <= deadline) {
    if (transferExists(latest, transferId)) {
      return latest;
    }
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 250);
    latest = readRuntimeState(state);
  }
  throw new Error(`wallet send did not settle in local runtime before timeout: ${transferId}`);
}

function requiredText(record: Record<string, unknown>, names: string[], label: string): string {
  for (const name of names) {
    const value = record[name];
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }
  throw new Error(`wallet send requires ${label}`);
}

function decimalEthToWei(value: string): bigint {
  const trimmed = value.trim();
  if (!/^\d+(\.\d{1,18})?$/.test(trimmed)) {
    throw new Error("amount must be a positive ETH decimal with at most 18 decimal places");
  }
  const [whole, fraction = ""] = trimmed.split(".");
  return (BigInt(whole) * WEI_PER_ETH) + BigInt(fraction.padEnd(18, "0"));
}

function amountUnitsFromPayload(record: Record<string, unknown>): string {
  const rawUnits = record.amountUnits ?? record.amount_units;
  if (typeof rawUnits === "string" || typeof rawUnits === "number") {
    const text = String(rawUnits).trim();
    if (!/^\d+$/.test(text)) {
      throw new Error("amountUnits must be an unsigned integer string");
    }
    return assertTransferAmount(BigInt(text)).toString();
  }

  const rawAmount = record.amountEth ?? record.amount;
  if (typeof rawAmount !== "string" && typeof rawAmount !== "number") {
    throw new Error("wallet send requires amountEth or amountUnits");
  }
  return assertTransferAmount(decimalEthToWei(String(rawAmount))).toString();
}

function assertTransferAmount(value: bigint): bigint {
  if (value <= 0n) {
    throw new Error("wallet send amount must be greater than zero");
  }
  if (value > U64_MAX) {
    throw new Error("wallet send amount exceeds current runtime u64 transfer limit");
  }
  return value;
}

function stableId(schema: string, value: JsonValue): string {
  return keccak256Hex(new TextEncoder().encode(canonicalJson({ schema, value })));
}

function parseWalletSendPayload(payload: unknown): ParsedWalletSend {
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("wallet send payload must be an object");
  }
  const secret = findSecret(payload as JsonValue);
  if (secret !== null) {
    throw new Error(`wallet send payload contained secret-shaped material at ${secret.path}`);
  }
  const record = payload as Record<string, unknown>;
  const memo = typeof record.memo === "string" && record.memo.trim().length > 0
    ? record.memo.trim().slice(0, 160)
    : "flowchain-wallet-send";
  return {
    fromAccountId: requiredText(record, ["fromAccountId", "from", "sender"], "fromAccountId"),
    toAccountId: requiredText(record, ["toAccountId", "to", "recipient"], "toAccountId"),
    amountUnits: amountUnitsFromPayload(record),
    memo,
    applyBlock: record.applyBlock !== false,
    createRecipient: record.createRecipient !== false,
  };
}

function parseLocalFaucetPayload(payload: unknown): ParsedLocalFaucet {
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("local faucet payload must be an object");
  }
  const secret = findSecret(payload as JsonValue);
  if (secret !== null) {
    throw new Error(`local faucet payload contained secret-shaped material at ${secret.path}`);
  }
  const record = payload as Record<string, unknown>;
  const reason = typeof record.reason === "string" && record.reason.trim().length > 0
    ? record.reason.trim().slice(0, 160)
    : "flowchain-local-tester-faucet";
  return {
    accountId: requiredText(record, ["accountId", "toAccountId", "walletAddress", "recipient"], "accountId"),
    amountUnits: amountUnitsFromPayload(record),
    reason,
    applyBlock: record.applyBlock !== false,
  };
}

function readRuntimeState(state: LoadedControlPlaneState): JsonObject {
  const path = resolveControlPlanePath(state.paths.localDevnetPath);
  if (!existsSync(path)) {
    throw new Error(`local FlowChain runtime state is missing: ${state.paths.localDevnetPath}`);
  }
  return JSON.parse(readFileSync(path, "utf8")) as JsonObject;
}

function objectMap(value: JsonValue | undefined): Record<string, JsonObject> {
  const object = asObject(value);
  if (object === null) {
    return {};
  }
  const rows: Record<string, JsonObject> = {};
  for (const [key, entry] of Object.entries(object)) {
    rows[key] = asObject(entry) ?? {};
  }
  return rows;
}

function bridgeMappingRows(runtimeState: JsonObject): JsonObject[] {
  return Object.values(objectMap(runtimeState.bridgeAccountMappings));
}

function resolveRuntimeAccount(runtimeState: JsonObject, accountId: string): AccountResolution {
  const balances = objectMap(runtimeState.localTestUnitBalances);
  if (balances[accountId] !== undefined) {
    return {
      requestedAccountId: accountId,
      runtimeAccountId: accountId,
      resolution: "direct",
    };
  }

  const mapping = bridgeMappingRows(runtimeState).find((row) => {
    return stringValue(row.flowchainRecipient) === accountId || stringValue(row.accountId) === accountId;
  });
  const mappedAccountId = stringValue(mapping?.accountId);
  if (mappedAccountId !== null) {
    return {
      requestedAccountId: accountId,
      runtimeAccountId: mappedAccountId,
      resolution: "bridge-account-mapping",
    };
  }

  return {
    requestedAccountId: accountId,
    runtimeAccountId: accountId,
    resolution: "unmapped",
  };
}

function balanceUnits(runtimeState: JsonObject, accountId: string): bigint | null {
  const balance = objectMap(runtimeState.localTestUnitBalances)[accountId];
  if (balance === undefined) {
    return null;
  }
  const units = stringValue(balance.units);
  return units !== null && /^\d+$/.test(units) ? BigInt(units) : null;
}

function writeTransferFixture(path: string, txs: JsonObject[], amountUnits: string): void {
  const fixture = {
    schema: "flowmemory.control_plane.wallet_send_runtime_fixture.v0",
    txs,
  };
  const encoded = JSON.stringify(fixture, null, 2).replace(/"__FLOWCHAIN_AMOUNT_UNITS__"/g, amountUnits);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${encoded}\n`);
}

function runCargoJson(args: string[]): JsonObject {
  const result = spawnCargoSync(args, {
    cwd: repoRoot(),
    encoding: "utf8",
    windowsHide: true,
  });
  if (result.error !== undefined) {
    throw result.error;
  }
  if (result.status !== 0) {
    const output = [result.stderr, result.stdout].filter((entry) => entry.trim().length > 0).join("\n");
    throw new Error(output || `cargo ${args.join(" ")} failed`);
  }
  return JSON.parse(result.stdout) as JsonObject;
}

export function executeWalletSend(state: LoadedControlPlaneState, payload: unknown): JsonObject {
  const request = parseWalletSendPayload(payload);
  const runtimeState = readRuntimeState(state);
  const from = resolveRuntimeAccount(runtimeState, request.fromAccountId);
  const to = resolveRuntimeAccount(runtimeState, request.toAccountId);
  const fromBalanceBefore = balanceUnits(runtimeState, from.runtimeAccountId);
  if (fromBalanceBefore === null) {
    throw new Error(`sender has no local runtime balance: ${request.fromAccountId}`);
  }
  const amountUnits = BigInt(request.amountUnits);
  if (fromBalanceBefore < amountUnits) {
    throw new Error(`sender balance is insufficient: balance=${fromBalanceBefore.toString()} amount=${request.amountUnits}`);
  }

  const toBalanceBefore = balanceUnits(runtimeState, to.runtimeAccountId);
  if (toBalanceBefore === null && !request.createRecipient) {
    throw new Error(`recipient has no local runtime balance: ${request.toAccountId}`);
  }

  const transferId = stableId("flowmemory.control_plane.wallet_send.transfer_id.v0", {
    from: from.runtimeAccountId,
    to: to.runtimeAccountId,
    amountUnits: request.amountUnits,
    memo: request.memo,
    nextBlockNumber: runtimeState.nextBlockNumber ?? null,
  });
  const txs: JsonObject[] = [];
  if (toBalanceBefore === null) {
    txs.push({
      type: "CreateLocalTestUnitBalance",
      accountId: to.runtimeAccountId,
      owner: `wallet:${to.requestedAccountId}`,
    });
  }
  txs.push({
    type: "TransferLocalTestUnits",
    transferId,
    fromAccountId: from.runtimeAccountId,
    toAccountId: to.runtimeAccountId,
    amountUnits: "__FLOWCHAIN_AMOUNT_UNITS__",
    memo: request.memo,
  });

  const intakeDir = resolve(repoRoot(), "devnet", "local", "wallet-runtime-intake");
  const fixturePath = resolve(intakeDir, `${Date.now()}-${process.pid}-${transferId.slice(2, 12)}.json`);
  const statePath = resolveControlPlanePath(state.paths.localDevnetPath);
  const liveNodeDir = request.applyBlock ? runningNodeDirForState(statePath) : null;
  const nodeDir = liveNodeDir ?? (request.applyBlock
    ? resolve(dirname(statePath), "wallet-runtime-node")
    : resolve(dirname(statePath), "node"));
  writeTransferFixture(fixturePath, txs, request.amountUnits);

  const submitArgs = [
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    statePath,
    "--node-dir",
    nodeDir,
    "submit-tx",
    "--tx-file",
    fixturePath,
    "--authorized-by",
    `wallet:${from.runtimeAccountId}`,
  ];
  if (request.applyBlock && liveNodeDir === null) {
    submitArgs.push("--direct");
  }
  const submit = runCargoJson(submitArgs);
  const block = request.applyBlock && liveNodeDir === null
    ? runCargoJson([
        "run",
        "--manifest-path",
        "crates/flowmemory-devnet/Cargo.toml",
        "--",
        "--state",
        statePath,
        "run",
        "--blocks",
        "1",
      ])
    : liveNodeDir === null ? null : {
        schema: "flowmemory.control_plane.live_node_settlement.v0",
        status: "submitted_to_running_node",
        nodeDir: liveNodeDir,
      };
  const summary = runCargoJson([
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    statePath,
    "inspect-state",
    "--summary",
  ]);
  const after = request.applyBlock && liveNodeDir !== null ? waitForTransfer(state, transferId, 20000) : readRuntimeState(state);
  state.devnet = after;
  const fromBalanceAfter = balanceUnits(after, from.runtimeAccountId);
  const toBalanceAfter = balanceUnits(after, to.runtimeAccountId);

  return {
    schema: "flowmemory.control_plane.wallet_send_result.v0",
    accepted: true,
    applied: request.applyBlock,
    status: request.applyBlock ? "applied_local_runtime" : "queued_local_runtime",
    transferId,
    txIds: Array.isArray(submit.queued) ? submit.queued : [],
    assetId: LOCAL_TEST_UNIT_ASSET_ID,
    amountUnits: request.amountUnits,
    from,
    to,
    balancesBefore: {
      from: fromBalanceBefore.toString(),
      to: toBalanceBefore?.toString() ?? "0",
    },
    balancesAfter: {
      from: fromBalanceAfter?.toString() ?? null,
      to: toBalanceAfter?.toString() ?? null,
    },
    fixturePath,
    statePath,
    block,
    summary,
    localOnly: true,
    productionReady: false,
  };
}

export function executeLocalFaucet(state: LoadedControlPlaneState, payload: unknown): JsonObject {
  const request = parseLocalFaucetPayload(payload);
  const statePath = resolveControlPlanePath(state.paths.localDevnetPath);
  const nodeDir = request.applyBlock
    ? resolve(dirname(statePath), "wallet-runtime-node")
    : resolve(dirname(statePath), "node");
  const before = readRuntimeState(state);
  const balanceBefore = balanceUnits(before, request.accountId);
  const submitArgs = [
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    statePath,
    "--node-dir",
    nodeDir,
    "faucet",
    "--account",
    request.accountId,
    "--amount",
    request.amountUnits,
    "--reason",
    request.reason,
    "--authorized-by",
    `wallet-faucet:${request.accountId}`,
  ];
  if (request.applyBlock) {
    submitArgs.push("--direct");
  }

  const submit = runCargoJson(submitArgs);
  const block = request.applyBlock
    ? runCargoJson([
        "run",
        "--manifest-path",
        "crates/flowmemory-devnet/Cargo.toml",
        "--",
        "--state",
        statePath,
        "run",
        "--blocks",
        "1",
      ])
    : null;
  const summary = runCargoJson([
    "run",
    "--manifest-path",
    "crates/flowmemory-devnet/Cargo.toml",
    "--",
    "--state",
    statePath,
    "inspect-state",
    "--summary",
  ]);
  const after = readRuntimeState(state);
  state.devnet = after;
  const balanceAfter = balanceUnits(after, request.accountId);

  return {
    schema: "flowmemory.control_plane.local_faucet_result.v0",
    accepted: true,
    applied: request.applyBlock,
    status: request.applyBlock ? "applied_local_runtime" : "queued_local_runtime",
    txIds: Array.isArray(submit.queued) ? submit.queued : [],
    accountId: request.accountId,
    assetId: LOCAL_TEST_UNIT_ASSET_ID,
    amountUnits: request.amountUnits,
    reason: request.reason,
    balancesBefore: {
      account: balanceBefore?.toString() ?? "0",
    },
    balancesAfter: {
      account: balanceAfter?.toString() ?? null,
    },
    statePath,
    block,
    summary,
    localOnly: true,
    productionReady: false,
  };
}

