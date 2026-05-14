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
  | "health"
  | "node_status"
  | "peer_list"
  | "sync_status"
  | "chain_status"
  | "finality_status"
  | "pilot_status"
  | "pilot_deposit_observation_list"
  | "pilot_credit_list"
  | "pilot_withdrawal_intent_list"
  | "pilot_release_evidence_list"
  | "pilot_cap_status"
  | "pilot_pause_status"
  | "pilot_retry_status"
  | "pilot_emergency_status"
  | "devnet_state"
  | "block_get"
  | "block_list"
  | "mempool_list"
  | "transaction_get"
  | "transaction_list"
  | "transaction_submit"
  | "transfer_send"
  | "event_get"
  | "event_list"
  | "account_get"
  | "account_list"
  | "balance_get"
  | "token_get"
  | "token_list"
  | "token_balance_get"
  | "token_balance_list"
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
  | "agent_get"
  | "agent_list"
  | "model_get"
  | "model_list"
  | "challenge_get"
  | "challenge_list"
  | "finality_get"
  | "finality_list"
  | "bridge_observation_get"
  | "bridge_observation_list"
  | "bridge_observation_submit"
  | "bridge_config_get"
  | "bridge_status"
  | "bridge_credit_status"
  | "bridge_deposit_get"
  | "bridge_deposit_list"
  | "bridge_credit_get"
  | "bridge_credit_list"
  | "withdrawal_intent_get"
  | "withdrawal_intent_list"
  | "release_evidence_get"
  | "release_evidence_list"
  | "replay_rejection_get"
  | "replay_rejection_list"
  | "withdrawal_get"
  | "withdrawal_list"
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
  txFixturesPath: string;
  txIntakePath: string;
  bridgeObservationPath: string;
  bridgeRuntimeHandoffPath: string;
  bridgeObservationIntakePath: string;
}

export interface DataSourceRecord {
  schema: "flowmemory.control_plane.data_source.v0";
  name: string;
  path: string;
  status: "loaded" | "missing" | "recovered";
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
  txFixtures: JsonObject | null;
  txIntake: JsonObject[];
  bridgeObservations: JsonObject[];
  bridgeRuntimeHandoff: JsonObject | null;
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
    schema: "flowmemory.control_plane.error.v1";
    reasonCode: string;
    errorCode: string;
    message: string;
    correlationId: string;
    recoverable: boolean;
    retryable: boolean;
    sourceComponent: string;
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
