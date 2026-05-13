import { encodeAddress, encodeBytes32, encodeUint256, abiEncodeCursorIdentity } from "./abi.ts";
import { CURSOR_ID_DOMAIN, SOURCE_SET_ID_DOMAIN } from "./constants.ts";
import { normalizeAddress, normalizeBytes32 } from "./hex.ts";
import { keccak256Hex, keccak256Utf8 } from "./keccak.ts";

export type ObservationLifecycleState = "observed" | "pending" | "finalized" | "removed" | "superseded" | "reorged";

export interface ObservationIdentityInput {
  chainId: string | number | bigint;
  emittingContract: string;
  blockNumber: string | number | bigint;
  blockHash: string;
  txHash: string;
  transactionIndex: string | number | bigint;
  logIndex: string | number | bigint;
  eventSignature: string;
  pulseId: string;
  rootfieldId: string;
}

const FLOWPULSE_OBSERVATION_TYPE =
  "FlowPulseObservationV0(uint256 chainId,address emittingContract,uint64 blockNumber,bytes32 blockHash,bytes32 txHash,uint32 transactionIndex,uint32 logIndex,bytes32 eventSignature,bytes32 pulseId,bytes32 rootfieldId)";

function concatBytes(parts: Uint8Array[]): Uint8Array {
  const length = parts.reduce((sum, part) => sum + part.length, 0);
  const output = new Uint8Array(length);
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

export function normalizeObservationIdentityInput(input: ObservationIdentityInput): Required<ObservationIdentityInput> {
  return {
    chainId: input.chainId,
    emittingContract: normalizeAddress(input.emittingContract),
    blockNumber: input.blockNumber,
    blockHash: normalizeBytes32(input.blockHash),
    txHash: normalizeBytes32(input.txHash),
    transactionIndex: input.transactionIndex,
    logIndex: input.logIndex,
    eventSignature: normalizeBytes32(input.eventSignature),
    pulseId: normalizeBytes32(input.pulseId),
    rootfieldId: normalizeBytes32(input.rootfieldId),
  };
}

export function encodeObservationIdentity(input: ObservationIdentityInput): Uint8Array {
  const normalized = normalizeObservationIdentityInput(input);
  return concatBytes([
    encodeBytes32(keccak256Utf8(FLOWPULSE_OBSERVATION_TYPE)),
    encodeUint256(normalized.chainId),
    encodeAddress(normalized.emittingContract),
    encodeUint256(normalized.blockNumber),
    encodeBytes32(normalized.blockHash),
    encodeBytes32(normalized.txHash),
    encodeUint256(normalized.transactionIndex),
    encodeUint256(normalized.logIndex),
    encodeBytes32(normalized.eventSignature),
    encodeBytes32(normalized.pulseId),
    encodeBytes32(normalized.rootfieldId),
  ]);
}

export function deriveObservationId(input: ObservationIdentityInput): `0x${string}` {
  return keccak256Hex(encodeObservationIdentity(input));
}

export interface CursorIdentityInput {
  chainId: string | number | bigint;
  sourceSetId: string;
  blockNumber: string | number | bigint;
  blockHash: string;
  transactionIndex: string | number | bigint;
  logIndex: string | number | bigint;
}

export function deriveSourceSetId(chainId: string | number | bigint, addresses: string[]): `0x${string}` {
  const normalizedAddresses = [...new Set(addresses.map((address) => normalizeAddress(address)))].sort();
  const payload = `${SOURCE_SET_ID_DOMAIN}|${BigInt(chainId).toString()}|${normalizedAddresses.join(",")}`;
  return keccak256Hex(new TextEncoder().encode(payload));
}

export function deriveCursorId(input: CursorIdentityInput): `0x${string}` {
  return keccak256Hex(abiEncodeCursorIdentity({
    domain: CURSOR_ID_DOMAIN,
    chainId: input.chainId,
    sourceSetId: normalizeBytes32(input.sourceSetId),
    blockNumber: input.blockNumber,
    blockHash: normalizeBytes32(input.blockHash),
    transactionIndex: input.transactionIndex,
    logIndex: input.logIndex,
  }));
}
