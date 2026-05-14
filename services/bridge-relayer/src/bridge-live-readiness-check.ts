import assert from "node:assert/strict";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

import { assertNoSecrets } from "../../shared/src/index.ts";
import { parseBridgeArgs, runBridgePipeline } from "./observe-base-lockbox.ts";

const REQUIRED_ENV = [
  "FLOWCHAIN_BASE8453_RPC_URL",
  "FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS",
  "FLOWCHAIN_BASE8453_SUPPORTED_TOKEN",
  "FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI",
  "FLOWCHAIN_PILOT_TOTAL_CAP_WEI",
  "FLOWCHAIN_PILOT_CONFIRMATIONS",
  "FLOWCHAIN_BASE8453_ASSET_DECIMALS",
  "FLOWCHAIN_PILOT_OPERATOR_ACK",
] as const;

const OPTIONAL_LIVE_ENV = [
  "FLOWCHAIN_BASE8453_FROM_BLOCK",
  "FLOWCHAIN_BASE8453_TO_BLOCK",
  "FLOWCHAIN_PILOT_MAX_USD",
] as const;

const REQUIRED_ACK = "I_UNDERSTAND_THIS_IS_CAPPED_BASE8453_OWNER_PILOT";
const DEFAULT_OUT = "services/bridge-relayer/out/base8453-live-readiness-check.json";

function env(name: string): string | undefined {
  const value = process.env[name];
  return value === undefined || value.trim() === "" ? undefined : value;
}

function baseLiveArgs(): string[] {
  return [
    "--mode",
    "base-mainnet-pilot",
    "--rpc-url",
    env("FLOWCHAIN_BASE8453_RPC_URL") ?? "",
    "--lockbox-address",
    env("FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS") ?? "",
    "--approved-lockbox",
    env("FLOWCHAIN_BASE8453_LOCKBOX_ADDRESS") ?? "",
    "--supported-token",
    env("FLOWCHAIN_BASE8453_SUPPORTED_TOKEN") ?? "",
    "--from-block",
    env("FLOWCHAIN_BASE8453_FROM_BLOCK") ?? "",
    "--to-block",
    env("FLOWCHAIN_BASE8453_TO_BLOCK") ?? "",
    "--confirmations",
    env("FLOWCHAIN_PILOT_CONFIRMATIONS") ?? env("FLOWCHAIN_BASE8453_CONFIRMATION_DEPTH") ?? "",
    "--acknowledge-pilot",
    "--acknowledge-real-funds",
    "--max-usd",
    env("FLOWCHAIN_PILOT_MAX_USD") ?? "1",
    "--max-deposit-amount",
    env("FLOWCHAIN_PILOT_MAX_DEPOSIT_WEI") ?? "",
    "--total-cap-amount",
    env("FLOWCHAIN_PILOT_TOTAL_CAP_WEI") ?? "",
    "--asset-decimals",
    env("FLOWCHAIN_BASE8453_ASSET_DECIMALS") ?? "",
  ];
}

function writeJson(path: string, value: unknown): void {
  const outPath = resolve(path);
  mkdirSync(dirname(outPath), { recursive: true });
  assertNoSecrets(value);
  writeFileSync(outPath, `${JSON.stringify(value, null, 2)}\n`);
  console.log(`Wrote ${outPath}`);
}

async function expectRejects(name: string, fn: () => unknown | Promise<unknown>, pattern: RegExp): Promise<string> {
  try {
    await Promise.resolve(fn());
  } catch (error) {
    assert.match(error instanceof Error ? error.message : String(error), pattern);
    return name;
  }
  assert.fail(`Expected rejection for ${name}`);
  return name;
}

async function selfTest(): Promise<Record<string, unknown>> {
  const missingEnv = REQUIRED_ENV.filter((name) => env(name) === undefined);
  const simulatedMissingEnv = [...REQUIRED_ENV];

  const common = [
    "--mode",
    "base-mainnet-pilot",
    "--rpc-url",
    "https://example.invalid/base",
    "--lockbox-address",
    "0x1111111111111111111111111111111111111111",
    "--approved-lockbox",
    "0x1111111111111111111111111111111111111111",
    "--supported-token",
    "0x3333333333333333333333333333333333333333",
    "--from-block",
    "100",
    "--to-block",
    "100",
    "--confirmations",
    "2",
    "--acknowledge-pilot",
    "--acknowledge-real-funds",
    "--max-usd",
    "1",
    "--max-deposit-amount",
    "20000000",
    "--total-cap-amount",
    "20000000",
    "--asset-decimals",
    "6",
  ];

  const missingAck = await expectRejects(
    "missing operator acknowledgement rejected",
    () => parseBridgeArgs(common.filter((arg) => arg !== "--acknowledge-pilot" && arg !== "--acknowledge-real-funds")),
    /acknowledge-pilot/,
  );

  const missingConfirmation = await expectRejects(
    "missing confirmation depth rejected",
    () => parseBridgeArgs(common.filter((_, index, values) => values[index - 1] !== "--confirmations" && values[index] !== "--confirmations")),
    /confirmations/,
  );

  const missingSupportedToken = await expectRejects(
    "missing supported token rejected",
    () => parseBridgeArgs(common.filter((_, index, values) => values[index - 1] !== "--supported-token" && values[index] !== "--supported-token")),
    /supported-token/,
  );

  const broadScan = await expectRejects(
    "broad block scan rejected",
    () => parseBridgeArgs([...common.slice(0, common.indexOf("--to-block") + 1), "10000", ...common.slice(common.indexOf("--confirmations"))]),
    /block range is too wide/,
  );

  const unapprovedLockbox = await expectRejects(
    "unapproved lockbox rejected",
    () => runBridgePipeline(parseBridgeArgs(common.map((arg, index, values) => values[index - 1] === "--approved-lockbox" ? "0x9999999999999999999999999999999999999999" : arg))),
    /unapproved bridge lockbox/,
  );

  const originalFetch = globalThis.fetch;
  const calls: string[] = [];
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body ?? "{}")) as { method: string };
    calls.push(body.method);
    return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x14a34" }), {
      headers: { "content-type": "application/json" },
    });
  };
  let wrongChain = "";
  try {
    wrongChain = await expectRejects(
      "wrong chain rejected before log scan",
      () => runBridgePipeline(parseBridgeArgs(common)),
      /wrong chain id: expected 8453 \(0x2105\)/,
    );
    assert.deepEqual(calls, ["eth_chainId"]);
  } finally {
    globalThis.fetch = originalFetch;
  }

  return {
    schema: "flowmemory.bridge_live_readiness_self_test.v0",
    generatedAt: new Date().toISOString(),
    status: "passed",
    liveMode: false,
    checks: [
      "missing env names are listed without printing values",
      missingAck,
      missingConfirmation,
      missingSupportedToken,
      broadScan,
      unapprovedLockbox,
      wrongChain,
    ],
    missingEnv,
    simulatedMissingEnv,
    requiredEnvNames: REQUIRED_ENV,
    optionalLiveEnvNames: OPTIONAL_LIVE_ENV,
    operatorAckRequiredValue: REQUIRED_ACK,
    noSecrets: true,
  };
}

async function liveCheck(): Promise<Record<string, unknown>> {
  const missing = [
    ...REQUIRED_ENV,
    "FLOWCHAIN_BASE8453_FROM_BLOCK",
    "FLOWCHAIN_BASE8453_TO_BLOCK",
  ].filter((name) => env(name) === undefined);
  if (missing.length > 0) {
    throw new Error(`Live readiness missing required env names: ${missing.join(", ")}`);
  }
  if (env("FLOWCHAIN_PILOT_OPERATOR_ACK") !== REQUIRED_ACK) {
    throw new Error(`FLOWCHAIN_PILOT_OPERATOR_ACK must equal ${REQUIRED_ACK}`);
  }

  const result = await runBridgePipeline(parseBridgeArgs(baseLiveArgs()));
  return {
    schema: "flowmemory.bridge_live_readiness_check.v0",
    generatedAt: new Date().toISOString(),
    status: "passed",
    liveMode: true,
    observedCount: result.observations.length,
    creditStatuses: result.credits.map((credit) => credit.status),
    requiredEnvNames: REQUIRED_ENV,
    optionalLiveEnvNames: OPTIONAL_LIVE_ENV,
    noSecrets: true,
  };
}

const args = process.argv.slice(2);
const live = args.includes("--live");
const outIndex = args.indexOf("--out");
const outPath = outIndex >= 0 ? args[outIndex + 1] ?? DEFAULT_OUT : DEFAULT_OUT;

const report = live ? await liveCheck() : await selfTest();
writeJson(outPath, report);
console.log(live ? "Base 8453 live readiness check passed." : "Base 8453 live readiness self-test passed.");
