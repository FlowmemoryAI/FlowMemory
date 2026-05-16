import { inspect } from "node:util";

import type { JsonValue } from "./client.ts";

const SECRET_PATTERNS: RegExp[] = [
  /\b(private[_ -]?key|seed[_ -]?phrase|mnemonic|api[_ -]?key|webhook|bearer|auth[_ -]?token|access[_ -]?token|refresh[_ -]?token|password|passphrase|vault[_ -]?ciphertext)\b\s*[:=]\s*["']?[^"'\s,}]+/gi,
  /\bhttps?:\/\/[^\s"'<>]*?(?:apikey|api_key|token|secret|key)=[^\s"'<>]+/gi,
];

export function redactFlowChainText(value: unknown): string {
  let text = typeof value === "string" ? value : inspect(value, { depth: 8, breakLength: 120 });
  for (const pattern of SECRET_PATTERNS) {
    text = text.replace(pattern, (match) => {
      if (/^https?:\/\//i.test(match)) return "[REDACTED_URL_WITH_SECRET_QUERY]";
      const separatorIndex = match.search(/[:=]/);
      if (separatorIndex >= 0) return `${match.slice(0, separatorIndex + 1)}[REDACTED]`;
      return "[REDACTED_SECRET_SHAPED_VALUE]";
    });
  }
  return text;
}

export function redactJsonValue(value: JsonValue): JsonValue {
  if (typeof value === "string") return redactFlowChainText(value);
  if (Array.isArray(value)) return value.map((entry) => redactJsonValue(entry));
  if (value !== null && typeof value === "object") {
    const redacted: Record<string, JsonValue> = {};
    for (const [key, entry] of Object.entries(value)) {
      if (key !== "noSecrets" && /private|secret|seed|mnemonic|password|passphrase|apiKey|api_key|authToken|accessToken|refreshToken|webhook|vault/i.test(key)) {
        redacted[key] = "[REDACTED]";
      } else {
        redacted[key] = redactJsonValue(entry as JsonValue);
      }
    }
    return redacted;
  }
  return value;
}
