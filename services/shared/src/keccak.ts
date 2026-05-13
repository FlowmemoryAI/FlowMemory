import { bytesToHex } from "./hex.ts";

const MASK_64 = (1n << 64n) - 1n;

const ROUND_CONSTANTS = [
  0x0000000000000001n,
  0x0000000000008082n,
  0x800000000000808an,
  0x8000000080008000n,
  0x000000000000808bn,
  0x0000000080000001n,
  0x8000000080008081n,
  0x8000000000008009n,
  0x000000000000008an,
  0x0000000000000088n,
  0x0000000080008009n,
  0x000000008000000an,
  0x000000008000808bn,
  0x800000000000008bn,
  0x8000000000008089n,
  0x8000000000008003n,
  0x8000000000008002n,
  0x8000000000000080n,
  0x000000000000800an,
  0x800000008000000an,
  0x8000000080008081n,
  0x8000000000008080n,
  0x0000000080000001n,
  0x8000000080008008n,
];

const ROTATION_OFFSETS = [
  [0, 36, 3, 41, 18],
  [1, 44, 10, 45, 2],
  [62, 6, 43, 15, 61],
  [28, 55, 25, 21, 56],
  [27, 20, 39, 8, 14],
];

function rotateLeft64(value: bigint, shift: number): bigint {
  if (shift === 0) {
    return value & MASK_64;
  }
  const amount = BigInt(shift);
  return ((value << amount) | (value >> (64n - amount))) & MASK_64;
}

function keccakF1600(state: bigint[]): void {
  for (const roundConstant of ROUND_CONSTANTS) {
    const c = new Array<bigint>(5);
    const d = new Array<bigint>(5);

    for (let x = 0; x < 5; x += 1) {
      c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20];
    }

    for (let x = 0; x < 5; x += 1) {
      d[x] = c[(x + 4) % 5] ^ rotateLeft64(c[(x + 1) % 5], 1);
    }

    for (let x = 0; x < 5; x += 1) {
      for (let y = 0; y < 5; y += 1) {
        state[x + 5 * y] = (state[x + 5 * y] ^ d[x]) & MASK_64;
      }
    }

    const b = new Array<bigint>(25).fill(0n);
    for (let x = 0; x < 5; x += 1) {
      for (let y = 0; y < 5; y += 1) {
        b[y + 5 * ((2 * x + 3 * y) % 5)] = rotateLeft64(state[x + 5 * y], ROTATION_OFFSETS[x][y]);
      }
    }

    for (let x = 0; x < 5; x += 1) {
      for (let y = 0; y < 5; y += 1) {
        state[x + 5 * y] = (b[x + 5 * y] ^ ((~b[((x + 1) % 5) + 5 * y]) & b[((x + 2) % 5) + 5 * y])) & MASK_64;
      }
    }

    state[0] = (state[0] ^ roundConstant) & MASK_64;
  }
}

function xorBlock(state: bigint[], block: Uint8Array): void {
  for (let index = 0; index < block.length; index += 1) {
    const lane = Math.floor(index / 8);
    const shift = BigInt((index % 8) * 8);
    state[lane] = (state[lane] ^ (BigInt(block[index]) << shift)) & MASK_64;
  }
}

export function keccak256(bytes: Uint8Array): Uint8Array {
  const rateBytes = 136;
  const state = new Array<bigint>(25).fill(0n);
  let offset = 0;

  while (offset + rateBytes <= bytes.length) {
    xorBlock(state, bytes.subarray(offset, offset + rateBytes));
    keccakF1600(state);
    offset += rateBytes;
  }

  const finalBlock = new Uint8Array(rateBytes);
  finalBlock.set(bytes.subarray(offset));
  finalBlock[bytes.length - offset] ^= 0x01;
  finalBlock[rateBytes - 1] ^= 0x80;
  xorBlock(state, finalBlock);
  keccakF1600(state);

  const output = new Uint8Array(32);
  for (let index = 0; index < output.length; index += 1) {
    const lane = Math.floor(index / 8);
    const shift = BigInt((index % 8) * 8);
    output[index] = Number((state[lane] >> shift) & 0xffn);
  }

  return output;
}

export function keccak256Hex(bytes: Uint8Array): `0x${string}` {
  return bytesToHex(keccak256(bytes));
}

export function keccak256Utf8(value: string): `0x${string}` {
  return keccak256Hex(new TextEncoder().encode(value));
}

