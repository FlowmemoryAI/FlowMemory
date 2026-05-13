import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import {
  FLOWPULSE_EVENT_SIGNATURE,
  FLOWPULSE_EVENT_TOPIC0,
  VERIFIER_STATUSES,
  canonicalJson,
  deriveObservationId,
  deriveReportId,
  findSecret,
  isVerifierStatus,
  keccak256Utf8,
  normalizeAddress,
  parseFlowPulseLogFixture,
  type ObservationIdentityInput,
  type RawFlowPulseLogFixture,
  type VerifierReportCore,
} from "../src/index.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));
const fixture = JSON.parse(
  readFileSync(join(__dirname, "../fixtures/flowpulse-observation.json"), "utf8"),
) as {
  identityInput: ObservationIdentityInput;
  rawLog: RawFlowPulseLogFixture;
  expected: {
    flowPulseTopic0: string;
    observationId: string;
    reportId: string;
  };
  reportCore: VerifierReportCore;
};

test("computes EVM Keccak-256 test vectors", () => {
  assert.equal(
    keccak256Utf8(""),
    "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
  );
  assert.equal(keccak256Utf8(FLOWPULSE_EVENT_SIGNATURE), FLOWPULSE_EVENT_TOPIC0);
  assert.equal(FLOWPULSE_EVENT_TOPIC0, fixture.expected.flowPulseTopic0);
});

test("derives canonical FlowPulse observation id from receipt/log metadata", () => {
  assert.equal(deriveObservationId(fixture.identityInput), fixture.expected.observationId);
});

test("parses a fixture-only FlowPulse log without live RPC", () => {
  const parsed = parseFlowPulseLogFixture(fixture.rawLog);
  assert.equal(parsed.observationId, fixture.expected.observationId);
  assert.equal(parsed.lifecycleState, "observed");
  assert.equal(parsed.pulseId, fixture.reportCore.observation.pulseId);
  assert.equal(parsed.rootfieldId, fixture.reportCore.observation.rootfieldId);
  assert.equal(parsed.actor, fixture.reportCore.flowPulse.actor);
  assert.equal(parsed.pulseType, fixture.reportCore.flowPulse.pulseType);
  assert.equal(parsed.subject, fixture.reportCore.flowPulse.subject);
  assert.equal(parsed.commitment, fixture.reportCore.flowPulse.commitment);
  assert.equal(parsed.sequence, fixture.reportCore.flowPulse.sequence);
  assert.equal(parsed.occurredAt, fixture.reportCore.flowPulse.occurredAt);
  assert.equal(parsed.uri, fixture.reportCore.flowPulse.uri);
});

test("rejects non-FlowPulse fixture logs", () => {
  const badLog = structuredClone(fixture.rawLog);
  badLog.topics[0] = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
  assert.throws(() => parseFlowPulseLogFixture(badLog), /expected 32 bytes|unsupported event signature/);
});

test("normalizes EVM addresses and rejects malformed addresses", () => {
  assert.equal(
    normalizeAddress("0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
    "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  );
  assert.throws(() => normalizeAddress("0x1234"), /expected 20 bytes/);
});

test("exposes the v0 verifier status vocabulary", () => {
  assert.deepEqual(VERIFIER_STATUSES, [
    "valid",
    "invalid",
    "unresolved",
    "unsupported",
    "reorged",
  ]);
  assert.equal(isVerifierStatus("valid"), true);
  assert.equal(isVerifierStatus("verified"), false);
});

test("canonical JSON sorts object keys while preserving array order", () => {
  assert.equal(canonicalJson({ b: "2", a: { d: "4", c: "3" } }), '{"a":{"c":"3","d":"4"},"b":"2"}');
  assert.equal(canonicalJson(["b", "a"]), '["b","a"]');
});

test("derives deterministic verifier report id from canonical report core", () => {
  assert.equal(deriveReportId(fixture.reportCore), fixture.expected.reportId);
});

test("detects secret-shaped response material without rejecting ordinary hashes", () => {
  assert.equal(findSecret({ stateRoot: `0x${"1".repeat(64)}` }), null);
  assert.equal(findSecret({ privateKey: `0x${"1".repeat(64)}` })?.reasonCode, "secret.key_name");
  assert.equal(findSecret({ rpc: "https://user:pass@example.invalid" })?.reasonCode, "secret.rpc_credential");
  assert.equal(findSecret({ token: "sk-test_1234567890abcdefghijklmnop" })?.reasonCode, "secret.api_key");
  assert.equal(findSecret({ url: "https://hooks.slack.com/services/T000/B000/XXXX" })?.reasonCode, "secret.webhook_url");
  assert.equal(
    findSecret({ phrase: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about" })?.reasonCode,
    "secret.mnemonic",
  );
});
