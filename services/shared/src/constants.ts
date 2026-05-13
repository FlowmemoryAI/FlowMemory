export const FLOWPULSE_EVENT_SIGNATURE =
  "FlowPulse(bytes32,bytes32,address,uint8,bytes32,bytes32,bytes32,uint64,uint64,string)";

export const FLOWPULSE_EVENT_TOPIC0 =
  "0x5d07190b9ae441b4d7b16259a48424acd451492b12f5f99a29f5bfd992c13e43";

export const OBSERVATION_ID_DOMAIN = "flowmemory.flowpulse.observation.v0";

export const CURSOR_ID_DOMAIN = "flowmemory.indexer.cursor.v0";

export const SOURCE_SET_ID_DOMAIN = "flowmemory.indexer.source_set.v0";

export const VERIFIER_REPORT_SCHEMA = "flowmemory.verifier.report.v0";

export const VERIFIER_STATUSES = Object.freeze([
  "valid",
  "invalid",
  "unresolved",
  "unsupported",
  "reorged",
]);

export type VerifierStatus =
  | "valid"
  | "invalid"
  | "unresolved"
  | "unsupported"
  | "reorged";
