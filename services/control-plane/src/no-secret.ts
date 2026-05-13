import type { JsonValue } from "./types.ts";

const FORBIDDEN_KEY_PATTERN = /^(privateKey|mnemonic|seedPhrase|rpcUrl|apiKey|webhookUrl|secretKey|accessToken|bearerToken|rpcSecret)$/i;
const FORBIDDEN_VALUE_PATTERNS = [
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
  /\bseed phrase\b/i,
  /\bmnemonic phrase\b/i,
  /\brpc secret\b/i,
  /\bapi key\b/i,
];

export interface SecretScanFinding {
  path: string;
  reason: string;
}

function scan(value: JsonValue | undefined, path: string, findings: SecretScanFinding[]): void {
  if (value === null || value === undefined) {
    return;
  }

  if (typeof value === "string") {
    for (const pattern of FORBIDDEN_VALUE_PATTERNS) {
      if (pattern.test(value)) {
        findings.push({ path, reason: "forbidden secret marker in string value" });
      }
    }
    return;
  }

  if (typeof value !== "object") {
    return;
  }

  if (Array.isArray(value)) {
    value.forEach((entry, index) => scan(entry, `${path}[${index}]`, findings));
    return;
  }

  for (const [key, entry] of Object.entries(value)) {
    const childPath = `${path}.${key}`;
    if (FORBIDDEN_KEY_PATTERN.test(key)) {
      findings.push({ path: childPath, reason: "forbidden secret-bearing key" });
    }
    scan(entry, childPath, findings);
  }
}

export function scanJsonForSecrets(value: JsonValue): SecretScanFinding[] {
  const findings: SecretScanFinding[] = [];
  scan(value, "$", findings);
  return findings;
}

export function assertNoSecrets(value: JsonValue): void {
  const findings = scanJsonForSecrets(value);
  if (findings.length > 0) {
    throw new Error(`control-plane response secret scan failed: ${JSON.stringify(findings, null, 2)}`);
  }
}
