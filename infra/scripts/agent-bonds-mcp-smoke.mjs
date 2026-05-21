#!/usr/bin/env node
import { getAgentBondMcpPrompt, getAgentBondMcpResource, listAgentBondMcpTools, runAgentBondMcpTool } from "../../services/flowmemory/src/mcp-agent-bonds.ts";
const tools = listAgentBondMcpTools();
const quote = runAgentBondMcpTool("agent_bond_envelope_quote", { taskClass: "code.patch", payoutUSDC: "50000000" });
const resource = getAgentBondMcpResource("flowmemory://agent-bonds/phase2-gate");
const prompt = getAgentBondMcpPrompt("agent_bonds_create_objective_task");
console.log(JSON.stringify({ service: "flowmemory-agent-bonds-mcp-smoke", toolCount: Array.isArray(tools.tools) ? tools.tools.length : 0, quoteOk: quote.ok, resourceFound: resource !== null, promptName: prompt.name }, null, 2));
