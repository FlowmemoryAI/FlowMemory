import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";

import { canonicalJson } from "../../shared/src/index.ts";
import {
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
  validateDeposit,
} from "../src/observe-base-lockbox.ts";

const fixtureUrl = new URL("../../../fixtures/bridge/base-sepolia-mock-deposit.json", import.meta.url);

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
    "bridge-withdrawal-intent.schema.json",
    "bridge-withdrawal-intent-set.schema.json",
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

function sampleBridgeDepositLog() {
  const sender = "0x4444444444444444444444444444444444444444";
  const token = "0x3333333333333333333333333333333333333333";
  const recipient = "0x5555555555555555555555555555555555555555555555555555555555555555";
  const metadataHash = "0x6666666666666666666666666666666666666666666666666666666666666666";

  return {
    address: "0x1111111111111111111111111111111111111111",
    topics: [
      BRIDGE_DEPOSIT_TOPIC0,
      "0x7777777777777777777777777777777777777777777777777777777777777777",
      topic(BigInt(BASE_SEPOLIA_CHAIN_ID)),
      addressTopic(sender),
    ],
    data: `0x${[
      dataWord(token),
      dataWord(20_000_000n),
      dataWord(recipient),
      dataWord(7n),
      dataWord(metadataHash),
    ].join("")}`,
    blockNumber: "0x64",
    blockHash: "0x9999999999999999999999999999999999999999999999999999999999999999",
    transactionHash: "0x2222222222222222222222222222222222222222222222222222222222222222",
    transactionIndex: "0x2",
    logIndex: "0x5",
  };
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
