import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";

import { assertNoSecrets, canonicalJson } from "../../shared/src/index.ts";
import {
  LOCK_NATIVE_SELECTOR,
  diagnoseBase8453Tx,
} from "../src/diagnose-base8453-tx.ts";
import {
  BASE_MAINNET_CHAIN_ID,
  BASE_SEPOLIA_CHAIN_ID,
  BRIDGE_DEPOSIT_TOPIC0,
  FIXED_TEST_OBSERVED_AT,
  makeBridgeCredit,
  makeObservation,
  makeRuntimeHandoff,
  makeWithdrawalIntent,
  parseBridgeDepositLog,
  parseBridgeArgs,
  runBridgePipeline,
  validateReleaseEvidenceMatchesWithdrawal,
  validateDeposit,
} from "../src/observe-base-lockbox.ts";

const fixtureUrl = new URL("../../../fixtures/bridge/base-sepolia-mock-deposit.json", import.meta.url);
const pilotFixtureUrl = new URL("../../../fixtures/bridge/base8453-pilot-mock-deposit.json", import.meta.url);
const pilotDuplicateFixtureUrl = new URL("../../../fixtures/bridge/base8453-pilot-duplicate-mock-deposits.json", import.meta.url);

function readSchema(name: string) {
  return JSON.parse(readFileSync(new URL(`../../../schemas/flowmemory/${name}`, import.meta.url), "utf8")) as object;
}

function bridgeAjv(): Ajv2020 {
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  [
    "bridge-deposit.schema.json",
    "bridge-observation.schema.json",
    "bridge-observation-set.schema.json",
    "bridge-credit.schema.json",
    "bridge-credit-set.schema.json",
    "bridge-runtime-credit-application.schema.json",
    "bridge-runtime-credit-application-state.schema.json",
    "bridge-withdrawal-intent.schema.json",
    "bridge-withdrawal-intent-set.schema.json",
    "bridge-withdrawal-authorization.schema.json",
    "bridge-pilot-evidence.schema.json",
    "bridge-release-evidence.schema.json",
    "bridge-local-usage-proof.schema.json",
    "bridge-runtime-handoff.schema.json",
  ].forEach((name) => ajv.addSchema(readSchema(name), name));
  return ajv;
}

function validateSchema(name: string, value: unknown): void {
  const ajv = bridgeAjv();
  const validate = ajv.getSchema(`https://flowmemory.local/schemas/flowmemory/${name}`) ?? ajv.getSchema(name);
  assert.ok(validate, `missing schema ${name}`);
  assert.equal(validate(value), true, canonicalJson({ errors: validate.errors ?? [] }));
}

function topic(value: bigint): `0x${string}` {
  return `0x${value.toString(16).padStart(64, "0")}`;
}

function addressTopic(address: string): `0x${string}` {
  return `0x${address.slice(2).padStart(64, "0")}`;
}

function dataWord(value: string | bigint): string {
  if (typeof value === "bigint") {
    return value.toString(16).padStart(64, "0");
  }
  return value.slice(2).padStart(64, "0");
}

function sampleBridgeDepositLog(
  chainId = BASE_SEPOLIA_CHAIN_ID,
  address = "0x1111111111111111111111111111111111111111",
  overrides: {
    depositId?: `0x${string}`;
    recipient?: `0x${string}`;
    txHash?: `0x${string}`;
    logIndex?: string;
    amount?: bigint;
  } = {},
) {
  const sender = "0x4444444444444444444444444444444444444444";
  const token = "0x3333333333333333333333333333333333333333";
  const recipient = overrides.recipient ?? "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
  const metadataHash = "0x0000000000000000000000000000000000000000000000000000000000000000";
  const pilotModeTag = "0x8edc10ba20d09d2f920c2135ea53baaa72ec90df339d57248f096ca150771a6e";

  return {
    address,
    topics: [
      BRIDGE_DEPOSIT_TOPIC0,
      overrides.depositId ?? "0x7777777777777777777777777777777777777777777777777777777777777777",
      topic(BigInt(chainId)),
      addressTopic(sender),
    ],
    data: `0x${[
      dataWord(address),
      dataWord(token),
      dataWord(overrides.amount ?? 20_000_000n),
      dataWord(recipient),
      dataWord(7n),
      dataWord(metadataHash),
      dataWord(pilotModeTag),
    ].join("")}`,
    blockNumber: "0x64",
    blockHash: "0x9999999999999999999999999999999999999999999999999999999999999999",
    transactionHash: overrides.txHash ?? "0x2222222222222222222222222222222222222222222222222222222222222222",
    transactionIndex: "0x2",
    logIndex: overrides.logIndex ?? "0x5",
  };
}

function pilotFixtureWithAmount(path: string, amount: string, overrides: Record<string, unknown> = {}): void {
  const fixture = JSON.parse(readFileSync(pilotFixtureUrl, "utf8")) as Record<string, unknown>;
  writeFileSync(path, `${JSON.stringify({ ...fixture, amount, ...overrides }, null, 2)}\n`);
}

function pilotArgs(fixturePath: string, extra: string[] = []): string[] {
  return [
    "--mode",
    "mock-pilot",
    "--fixture",
    fixturePath,
    "--approved-lockbox",
    "0x1111111111111111111111111111111111111111",
    "--confirmations",
    "2",
    "--acknowledge-pilot",
    "--max-usd",
    "1",
    "--max-deposit-amount",
    "20000000",
    "--total-cap-amount",
    "20000000",
    "--supported-token",
    "0x3333333333333333333333333333333333333333",
    "--asset-decimals",
    "6",
    "--apply-credit",
    "--withdrawal-intent",
    ...extra,
  ];
}

test("validates the committed mock bridge deposit fixture", () => {
  const fixture = JSON.parse(readFileSync(fixtureUrl, "utf8"));
  const deposit = validateDeposit(fixture);

  assert.equal(deposit.schema, "flowmemory.bridge_deposit.v0");
  assert.equal(deposit.sourceChainId, 84532);
  assert.equal(deposit.status, "observed");
  validateSchema("bridge-deposit.schema.json", deposit);
});

test("builds a non-production bridge observation", () => {
  const fixture = JSON.parse(readFileSync(fixtureUrl, "utf8"));
  const observation = makeObservation(validateDeposit(fixture), "mock");

  assert.equal(observation.schema, "flowmemory.bridge_deposit_observation.v0");
  assert.equal(observation.productionReady, false);
  assert.equal(observation.guardrails.noSecrets, true);
  assert.match(observation.replayKey, /^0x[0-9a-f]{64}$/);
  validateSchema("bridge-observation.schema.json", observation);
});

test("builds deterministic bridge credit, withdrawal intent, and runtime handoff objects", () => {
  const fixture = JSON.parse(readFileSync(fixtureUrl, "utf8"));
  const deposit = validateDeposit(fixture);
  const observation = makeObservation(deposit, "mock");
  const credit = makeBridgeCredit(observation, "applied");
  const withdrawal = makeWithdrawalIntent(credit, deposit);
  const handoff = makeRuntimeHandoff("mock", [observation], [credit], [withdrawal]);

  assert.equal(credit.status, "applied");
  assert.equal(credit.productionReady, false);
  assert.equal(withdrawal.status, "requested");
  assert.equal(withdrawal.broadcast, false);
  assert.deepEqual(
    handoff.workbenchTimeline.map((entry) => entry.phase),
    ["deposit_observed", "credit_pending", "credit_applied", "withdrawal_requested"],
  );
  assert.equal(handoff.workbenchTimeline[1]?.status, "pending");
  validateSchema("bridge-credit.schema.json", credit);
  validateSchema("bridge-withdrawal-intent.schema.json", withdrawal);
  validateSchema("bridge-runtime-handoff.schema.json", handoff);
});

test("local credit smoke pipeline applies a mock credit and records test withdrawal intent", async () => {
  const result = await runBridgePipeline(parseBridgeArgs([
    "--mode",
    "mock",
    "--fixture",
    fileURLToPath(fixtureUrl),
    "--apply-credit",
    "--withdrawal-intent",
  ]));

  assert.equal(result.observations.length, 1);
  assert.equal(result.credits[0]?.status, "applied");
  assert.equal(result.withdrawalIntents[0]?.status, "requested");
  assert.equal(result.handoff.generatedAt, FIXED_TEST_OBSERVED_AT);
  validateSchema("bridge-runtime-handoff.schema.json", result.handoff);
});

test("mock pilot E2E path applies a Base 8453 credit exactly once across replay", async () => {
  const stateDir = mkdtempSync(join(tmpdir(), "flowmemory-bridge-pilot-"));
  const statePath = join(stateDir, "credit-state.json");
  try {
    const args = [
      "--mode",
      "mock-pilot",
      "--fixture",
      fileURLToPath(pilotFixtureUrl),
      "--approved-lockbox",
      "0x1111111111111111111111111111111111111111",
      "--confirmations",
      "2",
      "--acknowledge-pilot",
      "--max-usd",
      "1",
      "--max-deposit-amount",
      "20000000",
      "--total-cap-amount",
      "20000000",
      "--supported-token",
      "0x3333333333333333333333333333333333333333",
      "--asset-decimals",
      "6",
      "--apply-credit",
      "--withdrawal-intent",
      "--runtime-state",
      statePath,
    ];
    const firstRun = await runBridgePipeline(parseBridgeArgs(args));
    const replayRun = await runBridgePipeline(parseBridgeArgs(args));

    assert.equal(firstRun.observations[0]?.deposit.sourceChainId, BASE_MAINNET_CHAIN_ID);
    assert.equal(firstRun.credits[0]?.status, "applied");
    assert.equal(firstRun.runtimeApplications[0]?.status, "applied");
    assert.equal(firstRun.runtimeApplications[0]?.applyCount, 1);
    assert.equal(firstRun.pilotEvidence[0]?.source.chainIdHex, "0x2105");
    assert.equal(firstRun.pilotEvidence[0]?.creditApplication.appliedExactlyOnce, true);
    assert.equal(firstRun.releaseEvidences[0]?.releaseCall.broadcast, false);
    assert.equal(replayRun.credits[0]?.status, "rejected");
    assert.equal(replayRun.credits[0]?.rejectionReason, "already_applied_replay_key");
    assert.equal(replayRun.runtimeApplications[0]?.status, "idempotent_replay");
    assert.equal(replayRun.runtimeApplications[0]?.applyCount, 0);
    assert.equal(replayRun.withdrawalIntents.length, 0);
    validateSchema("bridge-runtime-credit-application.schema.json", firstRun.runtimeApplications[0]);
    validateSchema("bridge-pilot-evidence.schema.json", firstRun.pilotEvidence[0]);
    validateSchema("bridge-release-evidence.schema.json", firstRun.releaseEvidences[0]);
  } finally {
    rmSync(stateDir, { recursive: true, force: true });
  }
});

test("mock pilot duplicate deposits reject replay with explicit evidence", async () => {
  const result = await runBridgePipeline(parseBridgeArgs([
    "--mode",
    "mock-pilot",
    "--fixture",
    fileURLToPath(pilotDuplicateFixtureUrl),
    "--approved-lockbox",
    "0x1111111111111111111111111111111111111111",
    "--confirmations",
    "2",
    "--acknowledge-pilot",
    "--max-usd",
    "1",
    "--max-deposit-amount",
    "20000000",
    "--total-cap-amount",
    "40000000",
    "--supported-token",
    "0x3333333333333333333333333333333333333333",
    "--asset-decimals",
    "6",
    "--apply-credit",
    "--withdrawal-intent",
  ]));

  assert.equal(result.observations.length, 2);
  assert.equal(result.credits[0]?.status, "applied");
  assert.equal(result.credits[1]?.status, "rejected");
  assert.equal(result.credits[1]?.rejectionReason, "duplicate_replay_key");
  assert.equal(result.handoff.replayProtection.duplicateReplayKeys.length, 1);
  assert.equal(result.pilotEvidence[1]?.replay.decision, "duplicate_replay_key_rejected");
  assert.equal(result.withdrawalIntents.length, 1);
});

test("mock pilot preserves exact tiny, small, u64 boundary, and above-u64 amounts as decimal strings", async () => {
  const stateDir = mkdtempSync(join(tmpdir(), "flowmemory-bridge-amounts-"));
  const cases = [
    { name: "tiny", amount: "1", cap: "1" },
    { name: "small", amount: "2500000", cap: "2500000" },
    { name: "u64", amount: "18446744073709551615", cap: "18446744073709551615" },
    { name: "above-u64", amount: "18446744073709551616", cap: "18446744073709551616" },
  ];
  try {
    for (const entry of cases) {
      const fixturePath = join(stateDir, `${entry.name}.json`);
      pilotFixtureWithAmount(fixturePath, entry.amount);
      const result = await runBridgePipeline(parseBridgeArgs(pilotArgs(fixturePath, [
        "--max-deposit-amount",
        entry.cap,
        "--total-cap-amount",
        entry.cap,
        "--runtime-state",
        join(stateDir, `${entry.name}-state.json`),
      ])));
      const observation = result.observations[0];
      const credit = result.credits[0];
      const application = result.runtimeApplications[0];
      const withdrawal = result.withdrawalIntents[0];
      const releaseEvidence = result.releaseEvidences[0];

      assert.equal(observation?.deposit.amount, entry.amount);
      assert.equal(credit?.amount, entry.amount);
      assert.equal(application?.amount, entry.amount);
      assert.equal(withdrawal?.amount, entry.amount);
      assert.equal(releaseEvidence?.releaseCall.amount, entry.amount);
      assert.equal(credit?.asset.decimals, 6);
      assert.equal(credit?.asset.sourceToken, observation?.deposit.token);
      assert.equal(withdrawal?.asset.destinationAssetId, credit?.asset.destinationAssetId);
      assert.equal(releaseEvidence?.asset.destinationAssetId, credit?.asset.destinationAssetId);
    }
  } finally {
    rmSync(stateDir, { recursive: true, force: true });
  }
});

test("mock pilot rejects per-deposit and total pilot cap excess before credit application", async () => {
  const stateDir = mkdtempSync(join(tmpdir(), "flowmemory-bridge-caps-"));
  try {
    const fixturePath = join(stateDir, "cap.json");
    pilotFixtureWithAmount(fixturePath, "20000001");

    const capResult = await runBridgePipeline(parseBridgeArgs(pilotArgs(fixturePath)));
    assert.equal(capResult.credits[0]?.status, "rejected");
    assert.equal(capResult.credits[0]?.rejectionReason, "deposit_amount_exceeds_pilot_cap");
    assert.equal(capResult.runtimeApplications.filter((entry) => entry.status === "applied").length, 0);

    const batchPath = join(stateDir, "batch.json");
    const deposit = JSON.parse(readFileSync(pilotFixtureUrl, "utf8")) as Record<string, unknown>;
    writeFileSync(batchPath, `${JSON.stringify({
      schema: "flowmemory.bridge_deposit_batch.v0",
      deposits: [
        { ...deposit, depositId: "0x8453000000000000000000000000000000000000000000000000000000000101", txHash: "0x8453000000000000000000000000000000000000000000000000000000000102", logIndex: 1, amount: "15000000" },
        { ...deposit, depositId: "0x8453000000000000000000000000000000000000000000000000000000000201", txHash: "0x8453000000000000000000000000000000000000000000000000000000000202", logIndex: 2, amount: "15000000" },
      ],
    }, null, 2)}\n`);

    await assert.rejects(
      () => runBridgePipeline(parseBridgeArgs(pilotArgs(batchPath, [
        "--max-deposit-amount",
        "20000000",
        "--total-cap-amount",
        "20000000",
      ]))),
      /pilot deposit batch exceeds --total-cap-amount/,
    );
  } finally {
    rmSync(stateDir, { recursive: true, force: true });
  }
});

test("release evidence amount mismatches are rejected explicitly", async () => {
  const result = await runBridgePipeline(parseBridgeArgs(pilotArgs(fileURLToPath(pilotFixtureUrl))));
  const withdrawal = result.withdrawalIntents[0];
  const releaseEvidence = result.releaseEvidences[0];
  assert.ok(withdrawal);
  assert.ok(releaseEvidence);

  validateReleaseEvidenceMatchesWithdrawal(withdrawal, releaseEvidence);
  assert.throws(
    () => validateReleaseEvidenceMatchesWithdrawal(withdrawal, {
      ...releaseEvidence,
      releaseCall: {
        ...releaseEvidence.releaseCall,
        amount: "1",
      },
    }),
    /release evidence amount mismatch/,
  );
});

test("bridge pipeline reports and artifacts do not contain secrets", async () => {
  const result = await runBridgePipeline(parseBridgeArgs(pilotArgs(fileURLToPath(pilotFixtureUrl))));
  assertNoSecrets(result.handoff);
  assertNoSecrets(result.pilotEvidence[0]);
  assertNoSecrets(result.releaseEvidences[0]);
});

test("mock pilot rejects wrong source chains and unapproved contracts", async () => {
  const wrongChain = await runBridgePipeline(parseBridgeArgs([
      "--mode",
      "mock-pilot",
      "--fixture",
      fileURLToPath(fixtureUrl),
      "--approved-lockbox",
      "0x1111111111111111111111111111111111111111",
      "--confirmations",
      "2",
      "--acknowledge-pilot",
      "--max-usd",
      "1",
      "--max-deposit-amount",
      "20000000",
      "--total-cap-amount",
      "20000000",
      "--supported-token",
      "0x3333333333333333333333333333333333333333",
      "--asset-decimals",
      "6",
      "--apply-credit",
    ]));
  assert.equal(wrongChain.credits[0]?.status, "rejected");
  assert.equal(wrongChain.credits[0]?.rejectionReason, "wrong_source_chain");

  const unapproved = await runBridgePipeline(parseBridgeArgs([
      "--mode",
      "mock-pilot",
      "--fixture",
      fileURLToPath(pilotFixtureUrl),
      "--approved-lockbox",
      "0x9999999999999999999999999999999999999999",
      "--confirmations",
      "2",
      "--acknowledge-pilot",
      "--max-usd",
      "1",
      "--max-deposit-amount",
      "20000000",
      "--total-cap-amount",
      "20000000",
      "--supported-token",
      "0x3333333333333333333333333333333333333333",
      "--asset-decimals",
      "6",
      "--apply-credit",
    ]));
  assert.equal(unapproved.credits[0]?.status, "rejected");
  assert.equal(unapproved.credits[0]?.rejectionReason, "unapproved_lockbox");
});

test("mock pilot rejects unsupported tokens", async () => {
  const result = await runBridgePipeline(parseBridgeArgs([
      "--mode",
      "mock-pilot",
      "--fixture",
      fileURLToPath(pilotFixtureUrl),
      "--approved-lockbox",
      "0x1111111111111111111111111111111111111111",
      "--confirmations",
      "2",
      "--acknowledge-pilot",
      "--max-usd",
      "1",
      "--max-deposit-amount",
      "20000000",
      "--total-cap-amount",
      "20000000",
      "--supported-token",
      "0x9999999999999999999999999999999999999999",
      "--asset-decimals",
      "6",
      "--apply-credit",
    ]));
  assert.equal(result.credits[0]?.status, "rejected");
  assert.equal(result.credits[0]?.rejectionReason, "unsupported_token");
});

test("decodes BaseBridgeLockbox BridgeDeposit logs from RPC log payloads", () => {
  const log = sampleBridgeDepositLog();
  const deposit = parseBridgeDepositLog(log, BASE_SEPOLIA_CHAIN_ID);

  assert.equal(deposit.depositId, log.topics[1]);
  assert.equal(deposit.sourceChainId, BASE_SEPOLIA_CHAIN_ID);
  assert.equal(deposit.sender, "0x4444444444444444444444444444444444444444");
  assert.equal(deposit.token, "0x3333333333333333333333333333333333333333");
  assert.equal(deposit.amount, "20000000");
  assert.equal(deposit.nonce, "7");
  assert.equal(deposit.logIndex, 5);
  assert.equal(deposit.sourceBlockNumber, "100");
});

test("observes Base Sepolia deposit logs through read-only RPC calls", async () => {
  const calls: string[] = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body ?? "{}")) as { method: string };
    calls.push(body.method);
    if (body.method === "eth_chainId") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x14a34" }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_getLogs") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: [sampleBridgeDepositLog()] }), {
        headers: { "content-type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, error: { message: "unexpected method" } }), {
      status: 400,
      headers: { "content-type": "application/json" },
    });
  };

  try {
    const result = await runBridgePipeline(parseBridgeArgs([
      "--mode",
      "base-sepolia",
      "--rpc-url",
      "https://example.invalid/base-sepolia",
      "--lockbox-address",
      "0x1111111111111111111111111111111111111111",
      "--from-block",
      "100",
      "--to-block",
      "100",
    ]));

    assert.deepEqual(calls, ["eth_chainId", "eth_getLogs"]);
    assert.equal(result.observations.length, 1);
    assert.equal(result.credits[0]?.status, "pending");
    assert.equal(result.handoff.productionReady, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("observes Base public-network pilot only after eth_chainId 0x2105 and confirmation depth", async () => {
  const calls: string[] = [];
  const stateDir = mkdtempSync(join(tmpdir(), "flowmemory-bridge-pilot-rpc-"));
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body ?? "{}")) as { method: string };
    calls.push(body.method);
    if (body.method === "eth_chainId") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x2105" }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_blockNumber") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x70" }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_getLogs") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: [sampleBridgeDepositLog(BASE_MAINNET_CHAIN_ID)] }), {
        headers: { "content-type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, error: { message: "unexpected method" } }), {
      status: 400,
      headers: { "content-type": "application/json" },
    });
  };

  try {
    const result = await runBridgePipeline(parseBridgeArgs([
      "--mode",
      "base-mainnet-pilot",
      "--rpc-url",
      "https://example.invalid/base-mainnet",
      "--lockbox-address",
      "0x1111111111111111111111111111111111111111",
      "--approved-lockbox",
      "0x1111111111111111111111111111111111111111",
      "--from-block",
      "100",
      "--to-block",
      "100",
      "--confirmations",
      "5",
      "--acknowledge-pilot",
      "--acknowledge-real-funds",
      "--max-usd",
      "1",
      "--max-deposit-amount",
      "20000000",
      "--total-cap-amount",
      "20000000",
      "--supported-token",
      "0x3333333333333333333333333333333333333333",
      "--asset-decimals",
      "6",
      "--apply-credit",
      "--withdrawal-intent",
      "--runtime-state",
      join(stateDir, "credit-state.json"),
    ]));

    assert.deepEqual(calls, ["eth_chainId", "eth_blockNumber", "eth_getLogs"]);
    assert.equal(result.observations.length, 1);
    assert.equal(result.observations[0]?.deposit.sourceChainId, BASE_MAINNET_CHAIN_ID);
    assert.equal(result.observations[0]?.guardrails.confirmation?.depth, 5);
    assert.equal(result.observations[0]?.guardrails.confirmation?.satisfied, true);
    assert.equal(result.credits[0]?.status, "applied");
    assert.equal(result.pilotEvidence[0]?.source.chainIdHex, "0x2105");
  } finally {
    globalThis.fetch = originalFetch;
    rmSync(stateDir, { recursive: true, force: true });
  }
});

test("Base public-network pilot rejects placeholder recipients without blocking valid deposits", async () => {
  const stateDir = mkdtempSync(join(tmpdir(), "flowmemory-bridge-placeholder-rpc-"));
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body ?? "{}")) as { method: string };
    if (body.method === "eth_chainId") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x2105" }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_blockNumber") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x70" }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_getLogs") {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        result: [
          sampleBridgeDepositLog(BASE_MAINNET_CHAIN_ID, "0x1111111111111111111111111111111111111111", {
            depositId: `0x${"a".repeat(64)}`,
            recipient: `0x${"5".repeat(64)}`,
            txHash: `0x${"a".repeat(64)}`,
            logIndex: "0x1",
          }),
          sampleBridgeDepositLog(BASE_MAINNET_CHAIN_ID, "0x1111111111111111111111111111111111111111", {
            depositId: `0x${"b".repeat(64)}`,
            txHash: `0x${"b".repeat(64)}`,
            logIndex: "0x2",
          }),
        ],
      }), {
        headers: { "content-type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, error: { message: "unexpected method" } }), {
      status: 400,
      headers: { "content-type": "application/json" },
    });
  };

  try {
    const result = await runBridgePipeline(parseBridgeArgs([
      "--mode",
      "base-mainnet-pilot",
      "--rpc-url",
      "https://example.invalid/base-mainnet",
      "--lockbox-address",
      "0x1111111111111111111111111111111111111111",
      "--approved-lockbox",
      "0x1111111111111111111111111111111111111111",
      "--from-block",
      "100",
      "--to-block",
      "100",
      "--confirmations",
      "5",
      "--acknowledge-pilot",
      "--acknowledge-real-funds",
      "--max-usd",
      "1",
      "--max-deposit-amount",
      "20000000",
      "--total-cap-amount",
      "40000000",
      "--supported-token",
      "0x3333333333333333333333333333333333333333",
      "--asset-decimals",
      "6",
      "--apply-credit",
      "--runtime-state",
      join(stateDir, "credit-state.json"),
    ]));

    assert.equal(result.observations.length, 2);
    assert.equal(result.credits.length, 2);
    assert.equal(result.credits[0]?.status, "rejected");
    assert.equal(result.credits[0]?.rejectionReason, "blocked_placeholder_flowchain_recipient");
    assert.equal(result.credits[0]?.productionReady, false);
    assert.equal(result.credits[0]?.localOnly, true);
    assert.equal(result.credits[1]?.status, "applied");
    assert.equal(result.credits[1]?.productionReady, true);
    assert.equal(result.credits[1]?.localOnly, false);
    assert.equal(result.runtimeApplications.filter((entry) => entry.status === "applied").length, 1);
    assert.equal(result.handoff.productionReady, true);
  } finally {
    globalThis.fetch = originalFetch;
    rmSync(stateDir, { recursive: true, force: true });
  }
});

test("Base public-network pilot rejects wrong chain IDs before log reads", async () => {
  const calls: string[] = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body ?? "{}")) as { method: string };
    calls.push(body.method);
    return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x14a34" }), {
      headers: { "content-type": "application/json" },
    });
  };

  try {
    await assert.rejects(
      () => runBridgePipeline(parseBridgeArgs([
        "--mode",
        "base-mainnet-pilot",
        "--rpc-url",
        "https://example.invalid/base-mainnet",
        "--lockbox-address",
        "0x1111111111111111111111111111111111111111",
        "--approved-lockbox",
        "0x1111111111111111111111111111111111111111",
        "--confirmations",
        "2",
        "--from-block",
        "100",
        "--to-block",
        "100",
        "--acknowledge-pilot",
        "--acknowledge-real-funds",
        "--max-usd",
        "1",
        "--max-deposit-amount",
        "20000000",
        "--total-cap-amount",
        "20000000",
        "--supported-token",
        "0x3333333333333333333333333333333333333333",
        "--asset-decimals",
        "6",
      ])),
      /wrong chain id: expected 8453 \(0x2105\)/,
    );
    assert.deepEqual(calls, ["eth_chainId"]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("diagnoses a valid Base 8453 bridge deposit transaction by tx hash", async () => {
  const calls: string[] = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body ?? "{}")) as { method: string; params: unknown[] };
    calls.push(body.method);
    if (body.method === "eth_chainId") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x2105" }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_getTransactionByHash") {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        result: {
          hash: body.params[0],
          to: "0x1111111111111111111111111111111111111111",
          input: `${LOCK_NATIVE_SELECTOR}${"0".repeat(128)}`,
        },
      }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_getTransactionReceipt") {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        result: {
          status: "0x1",
          blockNumber: "0x64",
          transactionHash: body.params[0],
          logs: [sampleBridgeDepositLog(BASE_MAINNET_CHAIN_ID)],
        },
      }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_blockNumber") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x71" }), {
        headers: { "content-type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, error: { message: "unexpected method" } }), {
      status: 400,
      headers: { "content-type": "application/json" },
    });
  };

  try {
    const report = await diagnoseBase8453Tx({
      rpcUrl: "https://example.invalid/base",
      txHash: "0x2222222222222222222222222222222222222222222222222222222222222222",
      lockboxAddress: "0x1111111111111111111111111111111111111111",
      supportedTokens: ["0x3333333333333333333333333333333333333333"],
      maxDepositAmount: "20000000",
      totalCapAmount: "20000000",
      confirmations: 12,
      outPath: "unused.json",
    });

    assert.deepEqual(calls, ["eth_chainId", "eth_getTransactionByHash", "eth_getTransactionReceipt", "eth_blockNumber"]);
    assert.equal(report.status, "valid");
    assert.equal(report.safeReasonCode, "valid");
    assert.equal((report.checks as Record<string, unknown>).bridgeDepositLogParsed, true);
    assert.equal(report.confirmationBlocksObserved, "13");
    assert.equal(report.printsEnvValues, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("diagnostic reports placeholder FlowChain recipients as invalid", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body ?? "{}")) as { method: string; params: unknown[] };
    if (body.method === "eth_chainId") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x2105" }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_getTransactionByHash") {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        result: {
          hash: body.params[0],
          to: "0x1111111111111111111111111111111111111111",
          input: `${LOCK_NATIVE_SELECTOR}${"5".repeat(64)}${"0".repeat(64)}`,
        },
      }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_getTransactionReceipt") {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        result: {
          status: "0x1",
          blockNumber: "0x64",
          transactionHash: body.params[0],
          logs: [sampleBridgeDepositLog(BASE_MAINNET_CHAIN_ID, "0x1111111111111111111111111111111111111111", {
            recipient: `0x${"5".repeat(64)}`,
          })],
        },
      }), {
        headers: { "content-type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x71" }), {
      headers: { "content-type": "application/json" },
    });
  };

  try {
    const report = await diagnoseBase8453Tx({
      rpcUrl: "https://example.invalid/base",
      txHash: "0x2222222222222222222222222222222222222222222222222222222222222222",
      lockboxAddress: "0x1111111111111111111111111111111111111111",
      supportedTokens: ["0x3333333333333333333333333333333333333333"],
      maxDepositAmount: "20000000",
      totalCapAmount: "20000000",
      confirmations: 12,
      outPath: "unused.json",
    });

    assert.equal(report.status, "invalid");
    assert.equal(report.safeReasonCode, "recipient-placeholder");
    assert.equal((report.checks as Record<string, unknown>).flowchainRecipientNotPlaceholder, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("diagnostic reports only a safe reason code for wrong selectors", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body ?? "{}")) as { method: string; params: unknown[] };
    if (body.method === "eth_chainId") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x2105" }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_getTransactionByHash") {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        result: {
          hash: body.params[0],
          to: "0x1111111111111111111111111111111111111111",
          input: `0xdeadbeef${"0".repeat(128)}`,
        },
      }), {
        headers: { "content-type": "application/json" },
      });
    }
    if (body.method === "eth_getTransactionReceipt") {
      return new Response(JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        result: {
          status: "0x1",
          blockNumber: "0x64",
          transactionHash: body.params[0],
          logs: [sampleBridgeDepositLog(BASE_MAINNET_CHAIN_ID)],
        },
      }), {
        headers: { "content-type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x71" }), {
      headers: { "content-type": "application/json" },
    });
  };

  try {
    const report = await diagnoseBase8453Tx({
      rpcUrl: "https://example.invalid/base",
      txHash: "0x2222222222222222222222222222222222222222222222222222222222222222",
      lockboxAddress: "0x1111111111111111111111111111111111111111",
      supportedTokens: ["0x3333333333333333333333333333333333333333"],
      maxDepositAmount: "20000000",
      totalCapAmount: "20000000",
      confirmations: 12,
      outPath: "unused.json",
    });

    assert.equal(report.status, "invalid");
    assert.equal(report.safeReasonCode, "wrong-selector");
    assert.equal(Object.prototype.hasOwnProperty.call(report, "rpcUrl"), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("Base public-network pilot rejects unapproved lockbox and insufficient confirmations", async () => {
  await assert.rejects(
    () => runBridgePipeline(parseBridgeArgs([
      "--mode",
      "base-mainnet-pilot",
      "--rpc-url",
      "https://example.invalid/base-mainnet",
      "--lockbox-address",
      "0x1111111111111111111111111111111111111111",
      "--approved-lockbox",
      "0x9999999999999999999999999999999999999999",
      "--confirmations",
      "2",
      "--from-block",
      "100",
      "--to-block",
      "100",
      "--acknowledge-pilot",
      "--acknowledge-real-funds",
      "--max-usd",
      "1",
      "--max-deposit-amount",
      "20000000",
      "--total-cap-amount",
      "20000000",
      "--supported-token",
      "0x3333333333333333333333333333333333333333",
      "--asset-decimals",
      "6",
    ])),
    /unapproved bridge lockbox address/,
  );

  const calls: string[] = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body ?? "{}")) as { method: string };
    calls.push(body.method);
    if (body.method === "eth_chainId") {
      return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x2105" }), {
        headers: { "content-type": "application/json" },
      });
    }
    return new Response(JSON.stringify({ jsonrpc: "2.0", id: 1, result: "0x65" }), {
      headers: { "content-type": "application/json" },
    });
  };

  try {
    await assert.rejects(
      () => runBridgePipeline(parseBridgeArgs([
        "--mode",
        "base-mainnet-pilot",
        "--rpc-url",
        "https://example.invalid/base-mainnet",
        "--lockbox-address",
        "0x1111111111111111111111111111111111111111",
        "--approved-lockbox",
        "0x1111111111111111111111111111111111111111",
        "--from-block",
        "100",
        "--to-block",
        "100",
        "--confirmations",
        "5",
        "--acknowledge-pilot",
        "--acknowledge-real-funds",
        "--max-usd",
        "1",
        "--max-deposit-amount",
        "20000000",
        "--total-cap-amount",
        "20000000",
        "--supported-token",
        "0x3333333333333333333333333333333333333333",
        "--asset-decimals",
        "6",
      ])),
      /insufficient confirmations/,
    );
    assert.deepEqual(calls, ["eth_chainId", "eth_blockNumber"]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("requires explicit Base mainnet real-funds guardrails", () => {
  assert.throws(
    () => parseBridgeArgs([
      "--mode",
      "base-mainnet-canary",
      "--rpc-url",
      "https://example.invalid",
      "--lockbox-address",
      "0x1111111111111111111111111111111111111111",
      "--from-block",
      "1",
      "--to-block",
      "2",
      "--max-usd",
      "20",
    ]),
    /acknowledge-real-funds/,
  );

  assert.throws(
    () => parseBridgeArgs([
      "--mode",
      "base-mainnet-canary",
      "--rpc-url",
      "https://example.invalid",
      "--lockbox-address",
      "0x1111111111111111111111111111111111111111",
      "--from-block",
      "1",
      "--to-block",
      "2",
      "--acknowledge-real-funds",
      "--max-usd",
      "30",
    ]),
    /max-usd/,
  );
});

test("rejects broad Base block ranges", () => {
  assert.throws(
    () => parseBridgeArgs([
      "--mode",
      "base-sepolia",
      "--rpc-url",
      "https://example.invalid",
      "--lockbox-address",
      "0x1111111111111111111111111111111111111111",
      "--from-block",
      "1",
      "--to-block",
      "9000",
    ]),
    /block range is too wide/,
  );
});
