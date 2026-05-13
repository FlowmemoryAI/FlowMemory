export type Hex = `0x${string}`;

export function normalizeHex(value: string, bytes?: number): Hex {
  if (typeof value !== "string") {
    throw new TypeError("hex value must be a string");
  }

  const prefixed = value.startsWith("0x") || value.startsWith("0X") ? value.slice(2) : value;
  if (!/^[0-9a-fA-F]*$/.test(prefixed)) {
    throw new Error(`invalid hex value: ${value}`);
  }

  if (bytes !== undefined && prefixed.length !== bytes * 2) {
    throw new Error(`expected ${bytes} bytes, got ${prefixed.length / 2}`);
  }

  if (prefixed.length % 2 !== 0) {
    throw new Error("hex value must have an even number of nibbles");
  }

  return `0x${prefixed.toLowerCase()}`;
}

export function hexToBytes(value: string, bytes?: number): Uint8Array {
  const normalized = normalizeHex(value, bytes).slice(2);
  const output = new Uint8Array(normalized.length / 2);
  for (let index = 0; index < output.length; index += 1) {
    output[index] = Number.parseInt(normalized.slice(index * 2, index * 2 + 2), 16);
  }
  return output;
}

export function bytesToHex(bytes: Uint8Array): Hex {
  return `0x${Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")}`;
}

export function normalizeAddress(value: string): Hex {
  return normalizeHex(value, 20);
}

export function normalizeBytes32(value: string): Hex {
  return normalizeHex(value, 32);
}

