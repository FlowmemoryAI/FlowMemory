import { hexToBytes, normalizeAddress, normalizeBytes32 } from "./hex.ts";

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

export function encodeUint256(value: string | number | bigint): Uint8Array {
  const bigintValue = BigInt(value);
  if (bigintValue < 0n) {
    throw new Error("uint256 cannot be negative");
  }
  const output = new Uint8Array(32);
  let remaining = bigintValue;
  for (let index = 31; index >= 0; index -= 1) {
    output[index] = Number(remaining & 0xffn);
    remaining >>= 8n;
  }
  if (remaining !== 0n) {
    throw new Error("uint256 overflow");
  }
  return output;
}

export function encodeAddress(value: string): Uint8Array {
  const output = new Uint8Array(32);
  output.set(hexToBytes(normalizeAddress(value)), 12);
  return output;
}

export function encodeBytes32(value: string): Uint8Array {
  return hexToBytes(normalizeBytes32(value));
}

export function encodeStringTail(value: string): Uint8Array {
  const bytes = new TextEncoder().encode(value);
  const paddedLength = Math.ceil(bytes.length / 32) * 32;
  const padded = new Uint8Array(paddedLength);
  padded.set(bytes);
  return concatBytes([encodeUint256(bytes.length), padded]);
}

export function abiEncodeObservationIdentity(fields: {
  domain: string;
  chainId: string | number | bigint;
  emittingContract: string;
  txHash: string;
  logIndex: string | number | bigint;
}): Uint8Array {
  const headLength = 5 * 32;
  const head = [
    encodeUint256(headLength),
    encodeUint256(fields.chainId),
    encodeAddress(fields.emittingContract),
    encodeBytes32(fields.txHash),
    encodeUint256(fields.logIndex),
  ];
  return concatBytes([...head, encodeStringTail(fields.domain)]);
}

export function abiEncodeCursorIdentity(fields: {
  domain: string;
  chainId: string | number | bigint;
  sourceSetId: string;
  blockNumber: string | number | bigint;
  blockHash: string;
  transactionIndex: string | number | bigint;
  logIndex: string | number | bigint;
}): Uint8Array {
  const headLength = 7 * 32;
  const head = [
    encodeUint256(headLength),
    encodeUint256(fields.chainId),
    encodeBytes32(fields.sourceSetId),
    encodeUint256(fields.blockNumber),
    encodeBytes32(fields.blockHash),
    encodeUint256(fields.transactionIndex),
    encodeUint256(fields.logIndex),
  ];
  return concatBytes([...head, encodeStringTail(fields.domain)]);
}

function wordAt(data: Uint8Array, wordIndex: number): Uint8Array {
  const start = wordIndex * 32;
  const end = start + 32;
  if (end > data.length) {
    throw new Error(`missing ABI word ${wordIndex}`);
  }
  return data.subarray(start, end);
}

export function decodeUint256Word(data: Uint8Array, wordIndex: number): bigint {
  let value = 0n;
  for (const byte of wordAt(data, wordIndex)) {
    value = (value << 8n) | BigInt(byte);
  }
  return value;
}

export function decodeBytes32Word(data: Uint8Array, wordIndex: number): `0x${string}` {
  const bytes = wordAt(data, wordIndex);
  return `0x${Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")}`;
}

export function decodeAddressTopic(topic: string): `0x${string}` {
  const bytes = hexToBytes(topic, 32);
  return `0x${Array.from(bytes.subarray(12), (byte) => byte.toString(16).padStart(2, "0")).join("")}`;
}

export function decodeString(data: Uint8Array, offset: bigint): string {
  if (offset % 32n !== 0n) {
    throw new Error("dynamic string offset must be word-aligned");
  }
  const wordIndex = Number(offset / 32n);
  const length = Number(decodeUint256Word(data, wordIndex));
  const start = Number(offset) + 32;
  const end = start + length;
  if (end > data.length) {
    throw new Error("dynamic string exceeds ABI data length");
  }
  return new TextDecoder().decode(data.subarray(start, end));
}
