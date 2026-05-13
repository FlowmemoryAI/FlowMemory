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
  | "chain_status"
  | "devnet_state"
  | "node_status"
  | "peer_list"
  | "mempool_list"
  | "block_get"
  | "block_list"
  | "account_get"
  | "account_list"
  | "balance_get"
  | "balance_list"
  | "faucet_event_get"
  | "faucet_event_list"
  | "wallet_metadata_get"
  | "wallet_metadata_list"
  | "transaction_get"
  | "transaction_list"
  | "transaction_submit"
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
  | "agent_account_get"
  | "agent_account_list"
  | "model_get"
  | "model_list"
  | "model_passport_get"
  | "model_passport_list"
  | "challenge_get"
  | "challenge_list"
  | "finality_get"
  | "finality_list"
  | "bridge_observation_submit"
  | "bridge_observation_get"
  | "bridge_observation_list"
  | "bridge_deposit_get"
  | "bridge_deposit_list"
  | "bridge_credit_get"
  | "bridge_credit_list"
  | "withdrawal_get"
  | "withdrawal_list"
  | "provenance_get"
  | "raw_json_get";

export interface ControlPlanePaths {
  launchCorePath: string;
  indexerPath: string;
  verifierPath: string;
  artifactsPath: string;
  devnetLocalStatePath: string;
  devnetLocalLaunchStatePath: string;
  devnetLocalIndexerHandoffPath: string;
  devnetLocalVerifierHandoffPath: string;
  devnetLocalControlPlaneHandoffPath: string;
  devnetPath: string;
  devnetIndexerHandoffPath: string;
  devnetVerifierHandoffPath: string;
  devnetControlPlaneHandoffPath: string;
  txFixturesPath: string;
  runtimeStatePath: string;
  runtimeIntakeDir: string;
  bridgeObservationPath: string;
  bridgeObservationIntakePath: string;
  bridgeDepositFixturePath: string;
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
  bridgeObservation: JsonObject | null;
  bridgeObservationIntake: JsonObject | null;
  bridgeDepositFixture: JsonObject | null;
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
