export type JsonValue =
  | null
  | boolean
  | number
  | string
  | JsonValue[]
  | { [key: string]: JsonValue | undefined };

export type JsonObject = { [key: string]: JsonValue | undefined };

export type FlowChainRpcId = string | number | null;

export type FlowChainRpcMethod =
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
  | "bridge_deposit_get"
  | "bridge_deposit_list"
  | "bridge_credit_get"
  | "bridge_credit_list"
  | "bridge_credit_status"
  | "withdrawal_get"
  | "withdrawal_list"
  | "provenance_get"
  | "raw_json_get";

export interface FlowChainRpcRequest {
  jsonrpc: "2.0";
  id: FlowChainRpcId;
  method: FlowChainRpcMethod | string;
  params?: JsonValue;
}

export interface FlowChainRpcErrorObject {
  code: number;
  message: string;
  data?: {
    schema?: string;
    reasonCode?: string;
    details?: JsonValue;
    localOnly?: boolean;
  };
}

export interface FlowChainRpcSuccessResponse<T = JsonValue> {
  jsonrpc: "2.0";
  id: FlowChainRpcId;
  result: T;
}

export interface FlowChainRpcErrorResponse {
  jsonrpc: "2.0";
  id: FlowChainRpcId;
  error: FlowChainRpcErrorObject;
}

export type FlowChainRpcResponse<T = JsonValue> =
  | FlowChainRpcSuccessResponse<T>
  | FlowChainRpcErrorResponse;

export interface FlowChainLocalTransaction extends JsonObject {
  type?: string;
  schema?: string;
}

export interface FlowChainSignedEnvelope extends JsonObject {
  schema: string;
  tx: FlowChainLocalTransaction;
  signature: JsonValue;
}

export interface FlowChainTransactionReceipt extends JsonObject {
  schema?: string;
  accepted?: boolean;
  intakeId?: string;
  txId?: string;
  status?: string;
  forwardedTo?: string;
  runtimeSubmission?: JsonValue;
  localOnly?: boolean;
}

export interface FlowChainReadiness extends JsonObject {
  schema: "flowchain.rpc.readiness.v0";
  status?: string;
  localRuntimeReadable?: boolean;
  publicRpcReady?: boolean;
  walletUsableAgainstRpc?: boolean;
  explorerUsableAgainstRpc?: boolean;
  bridgeRelayerUsableAgainstRpc?: boolean;
  missingProductionEnvNames?: string[];
  issues?: JsonObject[];
  envValuesPrinted?: boolean;
  noSecrets?: boolean;
  localOnly?: boolean;
  productionReady?: boolean;
}

export interface FlowChainBridgeReadiness extends JsonObject {
  schema?: string;
  failClosedStatus?: "BLOCKED" | "FAILED" | "READY_FOR_OPERATOR_LIVE_PILOT" | string;
  readyForOperatorLivePilot?: boolean;
  missingEnvNames?: string[];
  envValuesPrinted?: boolean;
}

export interface FlowChainDiscovery extends JsonObject {
  schema: "flowchain.rpc.discovery.v0";
  protocol?: string;
  service?: string;
  rpcPath?: string;
  chainId?: string;
  methodCount?: number;
  methods?: JsonObject[];
  compatibility?: JsonObject;
  localOnly?: boolean;
  productionReady?: boolean;
}

export interface SubmitSignedTransactionOptions {
  submittedBy?: string;
  runtimeSubmit?: boolean;
  runtimeSubmitMode?: "direct" | "local-file";
}

export interface FlowChainClientOptions {
  rpcUrl?: string;
  fetch?: typeof fetch;
  requestTimeoutMs?: number;
  headers?: Record<string, string>;
}
