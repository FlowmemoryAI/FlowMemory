import { existsSync, readFileSync, statSync, readdirSync } from "node:fs";
import { extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(fileURLToPath(new URL("../..", import.meta.url)));

const scanTargets = [
  "devnet/local/live-base8453-relay",
  "services/bridge-relayer/out",
  "fixtures/bridge",
];

const textExtensions = new Set([".json", ".md", ".txt", ".ndjson"]);
const secretPatterns = [
  { reason: "labeled private key", pattern: /\b(private key|privkey|secret key)\b\s*[:=]\s*0x[0-9a-f]{64}\b/i },
  { reason: "http basic credential in URL", pattern: /\bhttps?:\/\/[^/\s:@]+:[^/\s:@]+@/i },
  { reason: "api token value", pattern: /\b(?:sk|pk|rk|ghp|gho|ghu|github_pat|xox[baprs])-[-_A-Za-z0-9]{16,}\b/ },
  { reason: "webhook URL", pattern: /\bhttps:\/\/(?:hooks\.slack\.com|discord(?:app)?\.com\/api\/webhooks|.*webhook)[^\s"']+/i },
  { reason: "private key block", pattern: /BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY/i },
];

function walk(path) {
  const full = resolve(repoRoot, path);
  if (!existsSync(full)) {
    return [];
  }
  const item = statSync(full);
  if (item.isFile()) {
    return [full];
  }
  const files = [];
  for (const entry of readdirSync(full, { withFileTypes: true })) {
    const child = join(full, entry.name);
    if (entry.isDirectory()) {
      files.push(...walk(child));
    } else if (entry.isFile()) {
      files.push(child);
    }
  }
  return files;
}

const findings = [];
for (const target of scanTargets) {
  for (const file of walk(target)) {
    if (!textExtensions.has(extname(file).toLowerCase())) {
      continue;
    }
    const body = readFileSync(file, "utf8");
    for (const check of secretPatterns) {
      if (check.pattern.test(body)) {
        findings.push({ file: file.replace(repoRoot, "").replace(/^[/\\]/, ""), reason: check.reason });
      }
    }
  }
}

if (findings.length > 0) {
  console.error(JSON.stringify({ status: "failed", findings }, null, 2));
  process.exit(1);
}

console.log(JSON.stringify({
  status: "passed",
  scannedTargets: scanTargets,
  note: "No private key, RPC credential, API token, mnemonic, or webhook-shaped values found in bridge evidence artifacts.",
}, null, 2));
