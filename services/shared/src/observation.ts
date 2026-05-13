import { abiEncodeCursorIdentity, abiEncodeObservationIdentity } from "./abi.ts";
import { CURSOR_ID_DOMAIN, OBSERVATION_ID_DOMAIN, SOURCE_SET_ID_DOMAIN } from "./constants.ts";
import { normalizeAddress, normalizeBytes32 } from "./hex.ts";
import { keccak256Hex } from "./keccak.ts";

export type ObservationLifecycleState = "observed" | "pending" | "finalized" | "removed" | "superseded" | "reorged";

export interface ObservationIdentityInput {
  chainId: string | number | bigint;
  emittingContract: string;
  txHash: string;
  logIndex: string | number | bigint;
}

export function normalizeObservationIdentityInput(input: ObservationIdentityInput): Required<ObservationIdentityInput> {
  return {
    chainId: input.chainId,
    emittingContract: normalizeAddress(input.emittingContract),
    txHash: normalizeBytes32(input.txHash),
    logIndex: input.logIndex,
  };
}

export function encodeObservationIdentity(input: ObservationIdentityInput): Uint8Array {
  const normalized = normalizeObservationIdentityInput(input);
  return abiEncodeObservationIdentity({
    domain: OBSERVATION_ID_DOMAIN,
    chainId: normalized.chainId,
    emittingContract: normalized.emittingContract,
    txHash: normalized.txHash,
    logIndex: normalized.logIndex,
  });
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
