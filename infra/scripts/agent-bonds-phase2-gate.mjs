#!/usr/bin/env node
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { getAgentBondsFoundationReadiness, getAgentBondsPhase2Gate } from "../../services/flowmemory/src/agent-bonds-phase2-gate.ts";
const outPath = resolve("devnet/local/agent-bonds-readiness/agent-bonds-phase2-gate.json");
const output = { schema: "flowmemory.agent_bonds.phase2_gate_report.v1", foundation: getAgentBondsFoundationReadiness(), gate: getAgentBondsPhase2Gate() };
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, `${JSON.stringify(output, null, 2)}
`);
console.log(JSON.stringify({ service: "flowmemory-agent-bonds-phase2-gate", outPath, foundationReady: output.gate.foundationReady }, null, 2));
