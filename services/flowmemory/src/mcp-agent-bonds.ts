import { getAgentBondsPhase2Gate } from "./agent-bonds-phase2-gate.ts";
import { getAgentBondPassport } from "./agent-bond-passport.ts";
import { quoteBondedTaskEnvelope } from "./bonded-task-envelope.ts";
import { listReceiptsForAgent } from "./bonded-execution-receipt.ts";
import { readJson, type JsonObject } from "./agent-bonds-phase2-shared.ts";

export type MCPAgentBondToolResult<T> = {
  schemaVersion: "mcp-agent-bonds-tool-result/v1";
  ok: boolean;
  result?: T;
  error?: { code: string; message: string; blockers?: string[] };
  receiptPreview?: JsonObject;
  chainCallPreview?: unknown;
};

export function listAgentBondMcpTools(): JsonObject {
  return readJson<JsonObject>("fixtures/agent-bonds/mcp/tools-list.agent-bonds.json");
}

export function getAgentBondMcpResource(uri: string): JsonObject | null {
  if (uri.includes("passports/")) {
    const agentId = uri.split("/").pop() ?? "";
    return getAgentBondPassport(agentId);
  }
  if (uri.includes("receipts/")) {
    const receiptId = uri.split("/").pop() ?? "";
    return listReceiptsForAgent("agent_code_001").find((receipt) => receipt.receiptId === receiptId) ?? null;
  }
  if (uri.endsWith("phase2-gate")) {
    return getAgentBondsPhase2Gate();
  }
  return null;
}

export function getAgentBondMcpPrompt(name: string): JsonObject {
  return {
    schemaVersion: "mcp-agent-bonds-prompt/v1",
    name,
    description: `FlowMemory Agent Bonds prompt scaffold for ${name}`,
    phase2Gate: getAgentBondsPhase2Gate(),
  };
}

export function runAgentBondMcpTool(name: string, args: JsonObject = {}): MCPAgentBondToolResult<JsonObject> {
  const gate = getAgentBondsPhase2Gate();
  if (["agent_bond_task_create", "agent_bond_task_accept", "agent_bond_evidence_submit", "agent_bond_verifier_report_submit", "agent_bond_task_challenge"].includes(name) && args.dryRun !== false) {
    return { schemaVersion: "mcp-agent-bonds-tool-result/v1", ok: false, error: { code: "dryRunRequired", message: "Mutating Agent Bonds MCP tools require dryRun: false to proceed.", blockers: ["explicit dryRun flag required"] } };
  }
  switch (name) {
    case "agent_bond_passport_get":
      return { schemaVersion: "mcp-agent-bonds-tool-result/v1", ok: true, result: getAgentBondPassport(String(args.agentId ?? "agent_code_001")) ?? {} };
    case "agent_bond_envelope_quote":
      return { schemaVersion: "mcp-agent-bonds-tool-result/v1", ok: true, result: quoteBondedTaskEnvelope({ taskClass: typeof args.taskClass === "string" ? args.taskClass : undefined, payoutUSDC: typeof args.payoutUSDC === "string" ? args.payoutUSDC : undefined }) };
    case "agent_bond_receipt_get":
      return { schemaVersion: "mcp-agent-bonds-tool-result/v1", ok: true, result: listReceiptsForAgent(String(args.agentId ?? "agent_code_001"))[0] ?? {} };
    default:
      return { schemaVersion: "mcp-agent-bonds-tool-result/v1", ok: true, result: { name, args, gate } };
  }
}
