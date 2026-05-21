import type { LaunchCoreOutput } from "../../flowmemory/src/types.ts";
import type { PersistedIndexerState } from "../../indexer/src/index.ts";
import type { PersistedVerifierReports, ArtifactResolverFixture } from "../../verifier/src/index.ts";

export type JsonValue =
  | null
  | boolean
  | number
  | string
  | JsonValue[]
  | { [key: string]: JsonValue | undefined };

export type JsonObject = { [key: string]: JsonValue | undefined };

export type ControlPlaneMethod =
  | "rpc_discover"
  | "rpc_readiness"
  | "health"
  | "node_status"
  | "peer_list"
  | "chain_status"
  | "pilot_status"
  | "pilot_deposit_observation_list"
  | "pilot_credit_list"
  | "pilot_withdrawal_intent_list"
  | "pilot_release_evidence_list"
  | "pilot_cap_status"
  | "pilot_pause_status"
  | "pilot_retry_status"
  | "pilot_emergency_status"
  | "bridge_live_readiness"
  | "bridge_status"
  | "pilot_lifecycle_record_list"
  | "wallet_balance_list"
  | "wallet_transfer_history"
  | "devnet_state"
  | "block_get"
  | "block_list"
  | "mempool_list"
  | "transaction_get"
  | "transaction_list"
  | "transaction_submit"
  | "account_get"
  | "account_list"
  | "balance_get"
  | "token_get"
  | "token_list"
  | "token_balance_get"
  | "token_balance_list"
  | "token_transfer_get"
  | "token_transfer_list"
  | "pool_get"
  | "pool_list"
  | "lp_position_get"
  | "lp_position_list"
  | "swap_get"
  | "swap_list"
  | "product_flow_status"
  | "faucet_event_list"
  | "wallet_metadata_get"
  | "wallet_metadata_list"
  | "rootfield_get"
  | "rootfield_list"
  | "artifact_get"
  | "artifact_availability_get"
  | "artifact_availability_list"
  | "receipt_get"
  | "receipt_list"
  | "work_receipt_get"
  | "work_receipt_list"
  | "verifier_module_get"
  | "verifier_module_list"
  | "verifier_report_get"
  | "verifier_report_list"
  | "memory_cell_get"
  | "memory_cell_list"
  | "agent_bond_task_get"
  | "agent_bond_task_list"
  | "agent_bond_readiness_get"
  | "agent_bond_replay_report_get"
  | "agent_bond_public_launch_status_get"
  | "agent_bond_economic_report_get"
  | "agent_bond_passport_get"
  | "agent_bond_passport_list"
  | "agent_bond_passport_validate"
  | "agent_bond_passport_capacity_get"
  | "agent_bond_envelope_quote"
  | "agent_bond_envelope_validate"
  | "agent_bond_envelope_hash"
  | "agent_bond_envelope_create_task_args"
  | "agent_bond_receipt_get"
  | "agent_bond_receipt_list"
  | "agent_bond_receipt_validate"
  | "agent_bond_receipt_reputation_delta_get"
  | "agent_bond_phase2_gate_get"
  | "agent_bond_a2a_agent_card_get"
  | "agent_bond_a2a_extension_get"
  | "agent_bond_a2a_message_validate"
  | "agent_bond_a2a_envelope_extract"
  | "agent_bond_mcp_tools_get"
  | "agent_bond_mcp_resource_get"
  | "agent_bond_mcp_prompt_get"
  | "agent_bond_x402_payment_intent_create"
  | "agent_bond_x402_payment_required_get"
  | "agent_bond_x402_payment_receipt_validate"
  | "agent_bond_x402_envelope_link_get"
  | "agent_bond_credit_score_get"
  | "agent_bond_credit_score_simulation_get"
  | "agent_bond_credit_score_attestation_validate"
  | "agent_bond_underwriter_pool_get"
  | "agent_bond_underwriter_pool_list"
  | "agent_bond_underwriter_capacity_quote"
  | "agent_bond_underwriter_loss_simulate"
  | "agent_bond_public_claim_get"
  | "agent_bond_public_claim_validate"
  | "agent_bond_public_claim_status_get"
  | "agent_bond_recourse_policy_get"
  | "agent_bond_recourse_decision_quote"
  | "agent_bond_failure_waterfall_get"
  | "public_agent_network_classes_list"
  | "public_agent_network_class_get"
  | "public_agent_network_tools_list"
  | "public_agent_network_tool_set_get"
  | "public_agent_launch_preview"
  | "public_agent_launch_intent_get"
  | "public_agent_launch_get"
  | "public_agent_discover"
  | "public_swarm_classes_list"
  | "public_swarm_class_get"
  | "public_swarm_launch_preview"
  | "public_swarm_get"
  | "public_swarm_replay_get"
  | "agent_get"
  | "agent_list"
  | "base_agent_memory_task_scout_get"
  | "base_agent_memory_task_scout_list"
  | "base_agent_memory_replay_get"
  | "model_get"
  | "model_list"
  | "challenge_get"
  | "challenge_list"
  | "finality_get"
  | "finality_list"
  | "bridge_observation_get"
  | "bridge_observation_list"
  | "bridge_observation_submit"
  | "bridge_deposit_get"
  | "bridge_deposit_list"
  | "bridge_credit_get"
  | "bridge_credit_list"
  | "bridge_credit_status"
  | "withdrawal_get"
  | "withdrawal_list"
  | "explorer_search"
  | "provenance_get"
  | "raw_json_get";

export interface ControlPlanePaths {
  launchCorePath: string;
  indexerPath: string;
  verifierPath: string;
  artifactsPath: string;
  localDevnetPath: string;
  localDevnetLaunchPath: string;
  devnetPath: string;
  devnetIndexerHandoffPath: string;
  devnetVerifierHandoffPath: string;
  devnetControlPlaneHandoffPath: string;
  explorerFallbackPath: string;
  txFixturesPath: string;
  txIntakePath: string;
  bridgeObservationPath: string;
  bridgeRuntimeHandoffPath: string;
  bridgeObservationIntakePath: string;
  walletTransferProofPath: string;
  walletPublicMetadataPath: string;
  agentBondFixturePath: string;
  agentBondReplayReportPath: string;
  agentBondEconomicReportPath: string;
  agentBondReadinessReportPath: string;
  agentBondLaunchApprovalPath: string;
  agentBondPassportDir: string;
  agentBondEnvelopeDir: string;
  agentBondReceiptDir: string;
  agentBondClaimDir: string;
  taskScoutFixturePath: string;
  taskScoutViewPath: string;
  taskScoutReplayPath: string;
}

export interface DataSourceRecord {
  schema: "flowmemory.control_plane.data_source.v0";
  name: string;
  path: string;
  status: "loaded" | "missing" | "recovered" | "degraded";
  recovery?: string;
}

export interface LoadedControlPlaneState {
  schema: "flowmemory.control_plane.state.v0";
  launchCore: LaunchCoreOutput;
  indexer: PersistedIndexerState;
  verifier: PersistedVerifierReports;
  artifacts: ArtifactResolverFixture;
  devnet: JsonObject | null;
  devnetIndexerHandoff: JsonObject | null;
  devnetVerifierHandoff: JsonObject | null;
  devnetControlPlaneHandoff: JsonObject | null;
  explorerFallback: JsonObject | null;
  txFixtures: JsonObject | null;
  txIntake: JsonObject[];
  bridgeObservations: JsonObject[];
  bridgeRuntimeHandoff: JsonObject | null;
  walletTransferProof: JsonObject | null;
  walletPublicMetadata: JsonObject | null;
  agentBondReplayReport: JsonObject | null;
  agentBondEconomicReport: JsonObject | null;
  agentBondReadinessReport: JsonObject | null;
  taskScoutFixture: JsonObject | null;
  taskScoutReplayReport: JsonObject | null;
  paths: ControlPlanePaths;
  sources: Record<string, DataSourceRecord>;
}

export interface ControlPlaneContext {
  state?: LoadedControlPlaneState;
  paths?: Partial<ControlPlanePaths>;
}

export interface RpcRequest {
  jsonrpc: "2.0";
  id?: string | number | null;
  method: string;
  params?: JsonValue;
}

export interface RpcErrorObject {
  code: number;
  message: string;
  data: {
    schema: "flowmemory.control_plane.error.v0";
    reasonCode: string;
    details?: JsonValue;
    localOnly: true;
  };
}

export interface RpcSuccessResponse {
  jsonrpc: "2.0";
  id: string | number | null;
  result: JsonValue;
}

export interface RpcErrorResponse {
  jsonrpc: "2.0";
  id: string | number | null;
  error: RpcErrorObject;
}

export type RpcResponse = RpcSuccessResponse | RpcErrorResponse;
