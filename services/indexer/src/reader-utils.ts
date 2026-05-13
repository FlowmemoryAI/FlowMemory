export function normalizeEvmAddress(address: string): string {
  const normalized = address.trim().toLowerCase();
  if (!/^0x[0-9a-f]{40}$/.test(normalized)) {
    throw new Error(`invalid EVM address: ${address}`);
  }
  return normalized;
}

export function normalizeEvmAddresses(addresses: string[]): string[] {
  const normalized = addresses.flatMap((entry) => entry.split(",")).map(normalizeEvmAddress);
  const unique = [...new Set(normalized)].sort((left, right) => left.localeCompare(right));
  if (unique.length === 0) {
    throw new Error("at least one FlowPulse contract address is required");
  }
  return unique;
}

export function blockArgumentToDecimalString(value: string): string {
  const trimmed = value.trim().toLowerCase();
  if (/^0x[0-9a-f]+$/.test(trimmed)) {
    return BigInt(trimmed).toString();
  }
  if (/^[0-9]+$/.test(trimmed)) {
    return BigInt(trimmed).toString();
  }
  throw new Error(`block value must be a decimal or 0x quantity, received: ${value}`);
}

export function blockArgumentToRpcQuantity(value: string): string {
  return `0x${BigInt(blockArgumentToDecimalString(value)).toString(16)}`;
}

export function readArgValue(args: string[], index: number, name: string): string {
  const value = args[index + 1];
  if (value === undefined || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}
