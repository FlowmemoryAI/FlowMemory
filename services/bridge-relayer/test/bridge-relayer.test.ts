import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import {
  makeObservation,
  parseBridgeArgs,
  validateDeposit,
} from "../src/observe-base-lockbox.ts";

test("validates the committed mock bridge deposit fixture", () => {
  const fixture = JSON.parse(readFileSync(new URL("../../../fixtures/bridge/base-sepolia-mock-deposit.json", import.meta.url), "utf8"));
  const deposit = validateDeposit(fixture);

  assert.equal(deposit.schema, "flowmemory.bridge_deposit.v0");
  assert.equal(deposit.sourceChainId, 84532);
  assert.equal(deposit.status, "observed");
});

test("builds a non-production bridge observation", () => {
  const fixture = JSON.parse(readFileSync(new URL("../../../fixtures/bridge/base-sepolia-mock-deposit.json", import.meta.url), "utf8"));
  const observation = makeObservation(validateDeposit(fixture), "mock");

  assert.equal(observation.schema, "flowmemory.bridge_deposit_observation.v0");
  assert.equal(observation.productionReady, false);
  assert.equal(observation.guardrails.noSecrets, true);
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
