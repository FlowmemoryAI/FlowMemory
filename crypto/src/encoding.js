export function strip0x(value) {
  if (typeof value !== "string") {
    throw new TypeError("hex value must be a string");
  }
  return value.startsWith("0x") ? value.slice(2) : value;
}

export function bytesToHex(bytes) {
  return `0x${Buffer.from(bytes).toString("hex")}`;
}

export function hexToBytes(value, expectedLength) {
  const raw = strip0x(value);
  if (raw.length % 2 !== 0) {
    throw new Error(`invalid hex length for ${value}`);
  }
  if (!/^[0-9a-fA-F]*$/.test(raw)) {
    throw new Error(`invalid hex characters for ${value}`);
  }
  const bytes = Uint8Array.from(Buffer.from(raw, "hex"));
  if (expectedLength !== undefined && bytes.length !== expectedLength) {
    throw new Error(`expected ${expectedLength} bytes, got ${bytes.length}: ${value}`);
  }
  return bytes;
}

export function normalizeHex(value, expectedLength) {
  return bytesToHex(hexToBytes(value, expectedLength));
}

export function utf8Bytes(value) {
  return Uint8Array.from(Buffer.from(String(value), "utf8"));
}

export function concatBytes(...parts) {
  const length = parts.reduce((total, part) => total + part.length, 0);
  const out = new Uint8Array(length);
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

export function uintToWord(value) {
  const n = BigInt(value);
  if (n < 0n) {
    throw new Error(`uint cannot be negative: ${value}`);
  }
  const out = new Uint8Array(32);
  let remaining = n;
  for (let i = 31; i >= 0; i -= 1) {
    out[i] = Number(remaining & 0xffn);
    remaining >>= 8n;
  }
  if (remaining !== 0n) {
    throw new Error(`uint does not fit in 256 bits: ${value}`);
  }
  return out;
}

export function uintBe(value, byteLength) {
  const n = BigInt(value);
  if (n < 0n) {
    throw new Error(`uint cannot be negative: ${value}`);
  }
  const out = new Uint8Array(byteLength);
  let remaining = n;
  for (let i = byteLength - 1; i >= 0; i -= 1) {
    out[i] = Number(remaining & 0xffn);
    remaining >>= 8n;
  }
  if (remaining !== 0n) {
    throw new Error(`uint does not fit in ${byteLength} bytes: ${value}`);
  }
  return out;
}

export function addressToWord(value) {
  const address = hexToBytes(value, 20);
  return concatBytes(new Uint8Array(12), address);
}

export function bytes32ToWord(value) {
  return hexToBytes(value, 32);
}

export function abiEncodeStatic(fields) {
  const encoded = fields.map(([type, value]) => {
    if (type.startsWith("uint")) {
      return uintToWord(value);
    }
    if (type === "address") {
      return addressToWord(value);
    }
    if (type === "bytes32") {
      return bytes32ToWord(value);
    }
    throw new Error(`unsupported static ABI field type: ${type}`);
  });
  return concatBytes(...encoded);
}

export function canonicalJson(value) {
  return JSON.stringify(sortCanonical(value));
}

function sortCanonical(value) {
  if (value === null || typeof value !== "object") {
    if (typeof value === "number" && !Number.isFinite(value)) {
      throw new Error("canonical JSON cannot encode non-finite numbers");
    }
    if (typeof value === "string" && /^0x[0-9a-fA-F]*$/.test(value)) {
      return value.toLowerCase();
    }
    return value;
  }
  if (Array.isArray(value)) {
    return value.map(sortCanonical);
  }
  return Object.fromEntries(
    Object.keys(value)
      .sort()
      .map((key) => [key, sortCanonical(value[key])])
  );
}
