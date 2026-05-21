#!/usr/bin/env node
import { readJson } from "../../services/flowmemory/src/agent-bonds-phase2-shared.ts";
import { validateA2AAgentBondsExtension, extractBondedTaskEnvelopeFromA2AMetadata } from "../../services/flowmemory/src/a2a-agent-bonds.ts";
const extension = validateA2AAgentBondsExtension(readJson("fixtures/agent-bonds/a2a/a2a-agent-bonds-extension.json"));
const message = readJson("fixtures/agent-bonds/a2a/a2a-message.bonded-task.json");
const envelope = extractBondedTaskEnvelopeFromA2AMetadata(message);
console.log(JSON.stringify({ service: "flowmemory-agent-bonds-a2a-validate", extensionUri: extension.uri, envelopeId: envelope?.envelopeId ?? null, ok: envelope !== null }, null, 2));
