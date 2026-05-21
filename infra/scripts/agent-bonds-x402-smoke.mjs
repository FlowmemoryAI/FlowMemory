#!/usr/bin/env node
import { readJson } from "../../services/flowmemory/src/agent-bonds-phase2-shared.ts";
import { createX402EscrowBridgeIntent, buildX402PaymentRequiredPayload, linkX402PaymentToEnvelope } from "../../services/flowmemory/src/x402-agent-bonds.ts";
const envelope = readJson("fixtures/agent-bonds/envelopes/bonded-task-envelope.x402-funded.template.json");
const intent = createX402EscrowBridgeIntent(envelope);
const payload = buildX402PaymentRequiredPayload(intent);
const link = linkX402PaymentToEnvelope(intent, envelope);
console.log(JSON.stringify({ service: "flowmemory-agent-bonds-x402-smoke", intentId: intent.paymentIntentId, payloadMode: payload.flowmemoryAgentBonds.mode, linkHash: link.linkHash }, null, 2));
