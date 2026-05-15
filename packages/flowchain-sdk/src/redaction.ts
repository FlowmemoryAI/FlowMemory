import type { JsonObject, JsonValue } from "./types.ts";

export interface FlowChainSecretFinding {
  path: string;
  reasonCode:
    | "secret.key_name"
    | "secret.private_key"
    | "secret.mnemonic"
    | "secret.rpc_credential"
    | "secret.api_key"
    | "secret.webhook_url"
    | "secret.vault_ciphertext";
}

const REDACTED = "[REDACTED]";
const SENSITIVE_KEY_RE = /(^|[_-])(private[_-]?key|mnemonic|seed[_-]?phrase|rpc[_-]?(url|credential|password|token)|api[_-]?key|webhook[_-]?url|secret[_-]?key|vault[_-]?ciphertext|ciphertext)([_-]|$)/i;
const LABELED_PRIVATE_KEY_RE = /\b(private key|privkey|secret key)\b\s*[:=]\s*0x[0-9a-f]{64}\b/i;
const RPC_CREDENTIAL_RE = /\bhttps?:\/\/[^/\s:@]+:[^/\s:@]+@/i;
const API_KEY_VALUE_RE = /\b(?:sk|pk|rk|ghp|gho|ghu|github_pat|xox[baprs])-[-_A-Za-z0-9]{16,}\b/;
const WEBHOOK_URL_RE = /\bhttps:\/\/(?:hooks\.slack\.com|discord(?:app)?\.com\/api\/webhooks|.*webhook)[^\s"']+/i;
const VAULT_CIPHERTEXT_RE = /\b(?:vault ciphertext|ciphertext)\b\s*[:=]\s*["']?[-_A-Za-z0-9+/=]{24,}/i;

const MNEMONIC_WORDS = new Set([
  "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
  "absurd", "abuse", "access", "accident", "account", "accuse", "achieve",
  "acid", "acoustic", "acquire", "across", "act", "action", "actor", "actress",
  "actual", "adapt", "add", "addict", "address", "adjust", "admit", "adult",
  "advance", "advice", "aerobic", "affair", "afford", "afraid", "again", "age",
  "agent", "agree", "ahead", "aim", "air", "airport", "aisle", "alarm",
  "album", "alcohol", "alert", "alien", "all", "alley", "allow", "almost",
  "alone", "alpha", "already", "also", "alter", "always", "amateur", "amazing",
  "among", "amount", "amused", "analyst", "anchor", "ancient", "anger", "angle",
  "angry", "ankle", "announce", "annual", "another", "answer", "antenna",
  "antique", "anxiety", "any", "apart", "apology", "appear", "apple", "approve",
  "april", "arch", "arctic", "area", "arena", "argue", "arm", "armed",
  "armor", "army", "around", "arrange", "arrest", "arrive", "arrow", "art",
  "artefact", "artist", "artwork", "ask", "aspect", "assault", "asset", "assist",
  "assume", "asthma", "athlete", "atom", "attack", "attend", "attitude", "attract",
  "auction", "audit", "august", "aunt", "author", "auto", "autumn", "average",
  "avocado", "avoid", "awake", "aware", "away", "awesome", "awful", "awkward",
  "axis", "baby", "bachelor", "bacon", "badge", "bag", "balance", "balcony",
  "ball", "bamboo", "banana", "banner", "bar", "barely", "bargain", "barrel",
  "base", "basic", "basket", "battle", "beach", "bean", "beauty", "because",
  "become", "beef", "before", "begin", "behave", "behind", "believe", "below",
  "belt", "bench", "benefit", "best", "betray", "better", "between", "beyond",
  "bicycle", "bid", "bike", "bind", "biology", "bird", "birth", "bitter",
  "black", "blade", "blame", "blanket", "blast", "bleak", "bless", "blind",
  "blood", "blossom", "blouse", "blue", "blur", "blush", "board", "boat",
  "body", "boil", "bomb", "bone", "bonus", "book", "boost", "border",
  "boring", "borrow", "boss", "bottom", "bounce", "box", "boy", "bracket",
  "brain", "brand", "brass", "brave", "bread", "breeze", "brick", "bridge",
  "brief", "bright", "bring", "brisk", "broccoli", "broken", "bronze", "broom",
  "brother", "brown", "brush", "bubble", "buddy", "budget", "buffalo", "build",
  "bulb", "bulk", "bullet", "bundle", "bunker", "burden", "burger", "burst",
  "bus", "business", "busy", "butter", "buyer", "buzz",
]);

function isMnemonic(value: string): boolean {
  const words = value.toLowerCase().trim().split(/\s+/);
  if (![12, 15, 18, 21, 24].includes(words.length)) {
    return false;
  }
  return words.every((word) => MNEMONIC_WORDS.has(word));
}

function scanString(value: string, path: string): FlowChainSecretFinding | null {
  if (RPC_CREDENTIAL_RE.test(value)) {
    return { path, reasonCode: "secret.rpc_credential" };
  }
  if (API_KEY_VALUE_RE.test(value)) {
    return { path, reasonCode: "secret.api_key" };
  }
  if (WEBHOOK_URL_RE.test(value)) {
    return { path, reasonCode: "secret.webhook_url" };
  }
  if (LABELED_PRIVATE_KEY_RE.test(value)) {
    return { path, reasonCode: "secret.private_key" };
  }
  if (VAULT_CIPHERTEXT_RE.test(value)) {
    return { path, reasonCode: "secret.vault_ciphertext" };
  }
  if (isMnemonic(value)) {
    return { path, reasonCode: "secret.mnemonic" };
  }
  return null;
}

export function findFlowChainSecret(value: unknown, path = "$"): FlowChainSecretFinding | null {
  if (typeof value === "string") {
    return scanString(value, path);
  }
  if (value === null || typeof value !== "object") {
    return null;
  }
  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index += 1) {
      const finding = findFlowChainSecret(value[index], `${path}[${index}]`);
      if (finding !== null) {
        return finding;
      }
    }
    return null;
  }
  for (const [key, child] of Object.entries(value)) {
    if (SENSITIVE_KEY_RE.test(key)) {
      return { path: `${path}.${key}`, reasonCode: "secret.key_name" };
    }
    const finding = findFlowChainSecret(child, `${path}.${key}`);
    if (finding !== null) {
      return finding;
    }
  }
  return null;
}

export function assertNoFlowChainSecrets(value: unknown): void {
  const finding = findFlowChainSecret(value);
  if (finding !== null) {
    throw new Error(`secret-shaped material rejected at ${finding.path}: ${finding.reasonCode}`);
  }
}

function redactString(value: string): string {
  return scanString(value, "$") === null ? value : REDACTED;
}

export function redactFlowChainSecrets<T extends JsonValue | unknown>(value: T): T | JsonValue {
  if (typeof value === "string") {
    return redactString(value);
  }
  if (value === null || typeof value !== "object") {
    return value as JsonValue;
  }
  if (Array.isArray(value)) {
    return value.map((entry) => redactFlowChainSecrets(entry)) as JsonValue;
  }

  const redacted: JsonObject = {};
  for (const [key, child] of Object.entries(value as Record<string, unknown>)) {
    redacted[key] = SENSITIVE_KEY_RE.test(key) ? REDACTED : redactFlowChainSecrets(child) as JsonValue;
  }
  return redacted;
}

export function safeJson(value: unknown): string {
  return JSON.stringify(redactFlowChainSecrets(value));
}
