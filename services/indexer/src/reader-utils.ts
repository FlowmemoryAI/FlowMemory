import { findSecret } from "../../shared/src/index.ts";

export function normalizeRpcUrl(rpcUrl: string): string {
  const trimmed = rpcUrl.trim();
  if (trimmed === "") {
    throw new Error("--rpc-url is required; FlowMemory does not ship a default RPC endpoint");
  }
  if (/[\s\x00-\x1f\x7f]/.test(trimmed)) {
    throw new Error("--rpc-url must be a single explicit URL without whitespace or control characters");
  }
  if (/^(\$|\$\{|%).+/.test(trimmed)) {
    throw new Error("--rpc-url must be a resolved URL, not an environment variable placeholder");
  }

  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    throw new Error("--rpc-url must be an absolute http(s) URL");
  }

  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    throw new Error("--rpc-url must use http or https");
  }
  if (parsed.username !== "" || parsed.password !== "") {
    throw new Error("--rpc-url must not include username/password credentials");
  }

  const secret = findSecret(trimmed);
  if (secret !== null) {
    throw new Error(`--rpc-url contains secret-shaped material: ${secret.reasonCode}`);
  }

  return trimmed;
}

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

export function assertRpcQuantity(value: string, name: string): void {
  if (!/^0x(?:0|[1-9a-f][0-9a-f]*)$/i.test(value)) {
    throw new Error(`${name} must be a normalized JSON-RPC quantity`);
  }
}

export function assertBlockRange(fromBlock: string, toBlock: string, maxSpan?: bigint): void {
  if (BigInt(toBlock) < BigInt(fromBlock)) {
    throw new Error("--to-block must be greater than or equal to --from-block");
  }

  if (maxSpan !== undefined) {
    const span = BigInt(toBlock) - BigInt(fromBlock);
    if (span > maxSpan) {
      throw new Error(`reader refuses broad scans; block span ${span.toString()} exceeds ${maxSpan.toString()}`);
    }
  }
}

export function readArgValue(args: string[], index: number, name: string): string {
  const value = args[index + 1];
  if (value === undefined || value.startsWith("--")) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}
