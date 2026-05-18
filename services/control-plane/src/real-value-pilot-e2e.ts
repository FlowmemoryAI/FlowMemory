import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { findSecret } from "../../shared/src/index.ts";
import { dispatchJsonRpc } from "./json-rpc.ts";
import { loadControlPlaneState, repoRoot } from "./fixture-state.ts";
import type { JsonObject, RpcErrorResponse, RpcSuccessResponse } from "./types.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function success(response: ReturnType<typeof dispatchJsonRpc>, method: string): RpcSuccessResponse {
  assert(response !== undefined && !Array.isArray(response), `${method} returned an invalid response`);
  assert(!("error" in response), `${method} failed: ${JSON.stringify((response as RpcErrorResponse).error, null, 2)}`);
  return response as RpcSuccessResponse;
}

function responseFor(method: string, params?: JsonObject): RpcSuccessResponse {
  const state = loadControlPlaneState();
  return success(dispatchJsonRpc({ jsonrpc: "2.0", id: method, method, params }, { state }), method);
}

function assertNoSecretPayload(value: unknown, label: string): void {
  const finding = findSecret(value);
  assert(finding === null, `${label} exposed secret-shaped material at ${finding?.path}: ${finding?.reasonCode}`);
}

function readRepoText(path: string): string {
  return readFileSync(resolve(repoRoot(), path), "utf8");
}

export function runRealValuePilotE2e(): JsonObject {
  const methods = [
    "pilot_status",
    "pilot_deposit_observation_list",
    "pilot_credit_list",
    "pilot_withdrawal_intent_list",
    "pilot_release_evidence_list",
    "pilot_cap_status",
    "pilot_pause_status",
    "pilot_retry_status",
    "pilot_emergency_status",
    "bridge_live_readiness",
    "pilot_lifecycle_record_list",
    "wallet_balance_list",
    "wallet_transfer_history",
  ];
  const responses = Object.fromEntries(methods.map((method) => [method, responseFor(method, method.endsWith("_list") ? { limit: 20 } : undefined).result])) as Record<string, JsonObject>;
  const status = responses.pilot_status;

  assert(status.schema === "flowmemory.control_plane.real_value_pilot_status.v0", "pilot_status schema mismatch");
  assert(["live", "degraded", "error"].includes(String(status.state)), "pilot_status state must be live/degraded/error");
  assert(status.cappedOwnerTesting === true, "pilot_status must label capped owner testing");
  assert(status.broadPublicReadiness === false, "pilot_status must reject broad public readiness");
  assert(status.browserStoresSecrets === false, "pilot_status must state browser stores no secrets");
  assert(typeof (status.nextOperatorStep as JsonObject)?.command === "string", "pilot_status must expose next operator command");
  assert(String((status.nextOperatorStep as JsonObject).command).startsWith("npm run "), "next operator command must be concrete");
  assert((responses.pilot_deposit_observation_list.depositObservations as unknown[]).length > 0, "pilot deposits must be exposed");
  assert((responses.pilot_credit_list.credits as unknown[]).length > 0, "pilot credits must be exposed");
  assert((responses.pilot_withdrawal_intent_list.withdrawalIntents as unknown[]).length > 0, "pilot withdrawal intents must be exposed");
  assert((responses.pilot_release_evidence_list.releaseEvidence as unknown[]).length > 0, "pilot release evidence must be exposed");
  assert((responses.pilot_cap_status as JsonObject).schema === "flowmemory.control_plane.real_value_pilot_cap_status.v0", "cap status schema mismatch");
  assert((responses.pilot_pause_status as JsonObject).schema === "flowmemory.control_plane.real_value_pilot_pause_status.v0", "pause status schema mismatch");
  assert((responses.pilot_retry_status as JsonObject).schema === "flowmemory.control_plane.real_value_pilot_retry_status.v0", "retry status schema mismatch");
  assert((responses.pilot_emergency_status as JsonObject).schema === "flowmemory.control_plane.real_value_pilot_emergency_status.v0", "emergency status schema mismatch");
  assert((responses.bridge_live_readiness as JsonObject).schema === "flowmemory.control_plane.bridge_live_readiness.v0", "bridge readiness schema mismatch");
  assert(["BLOCKED", "FAILED", "READY_FOR_OPERATOR_LIVE_PILOT"].includes(String((responses.bridge_live_readiness as JsonObject).failClosedStatus)), "bridge readiness must fail closed with a machine status");
  assert((responses.bridge_live_readiness as JsonObject).envValuesPrinted === false, "bridge readiness must not print env values");
  assert((responses.pilot_lifecycle_record_list as JsonObject).schema === "flowmemory.control_plane.bridge_lifecycle_record_list.v0", "lifecycle record schema mismatch");
  assert((responses.wallet_balance_list as JsonObject).schema === "flowmemory.control_plane.wallet_balance_list.v0", "wallet balance schema mismatch");
  assert((responses.wallet_transfer_history as JsonObject).schema === "flowmemory.control_plane.wallet_transfer_history.v0", "wallet transfer history schema mismatch");

  assertNoSecretPayload(responses, "pilot API responses");

  const workbenchSource = readRepoText("apps/dashboard/src/data/workbench.ts");
  const workbenchView = readRepoText("apps/dashboard/src/views/WorkbenchView.tsx");
  assert(workbenchSource.includes("realValuePilot"), "dashboard workbench source must define the real-value pilot section");
  assert(workbenchSource.includes("/pilot/status"), "dashboard workbench source must probe /pilot/status");
  assert(workbenchSource.includes("/bridge/live-readiness"), "dashboard workbench source must probe bridge live readiness");
  assert(workbenchSource.includes("/pilot/lifecycle"), "dashboard workbench source must probe lifecycle records");
  assert(workbenchSource.includes("capped owner testing"), "dashboard workbench source must label capped owner testing");
  assert(workbenchView.includes("Real-value pilot"), "dashboard view must render a real-value pilot panel");
  assert(workbenchView.includes("Bridge live readiness"), "dashboard view must render bridge live readiness");
  assert(workbenchView.includes("pilotNextCommand"), "dashboard view must render the next operator command");
  assert(workbenchView.includes("browser secrets"), "dashboard view must render browser secret boundary");
  assert(
    !/\b(?:localStorage|sessionStorage)\.setItem\b/.test(workbenchSource + workbenchView),
    "dashboard must not write private keys or RPC secrets to browser storage",
  );

  return {
    schema: "flowmemory.control_plane.real_value_pilot_e2e.v0",
    ok: true,
    pilotState: status.state,
    nextOperatorCommand: (status.nextOperatorStep as JsonObject).command,
    apiMethods: methods,
    dashboardEvidence: [
      "apps/dashboard/src/data/workbench.ts realValuePilot section",
      "apps/dashboard/src/data/workbench.ts /pilot/status probe",
      "apps/dashboard/src/views/WorkbenchView.tsx Real-value pilot panel",
    ],
    localOnly: true,
    productionReady: false,
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  console.log(JSON.stringify(runRealValuePilotE2e(), null, 2));
}
