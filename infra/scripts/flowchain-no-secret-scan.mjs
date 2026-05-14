#!/usr/bin/env node
import { existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, extname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const reportDir = resolve(repoRoot, "devnet/local/live-l1-protocol");
const reportPath = resolve(reportDir, "no-secret-scan-report.json");

const skipDirs = new Set([
  ".git",
  "node_modules",
  "dist",
  "cache",
  "out",
  "broadcast",
  "target",
  "target-local"
]);

const textExtensions = new Set([
  "",
  ".cjs",
  ".css",
  ".html",
  ".js",
  ".json",
  ".jsx",
  ".lock",
  ".md",
  ".mjs",
  ".ps1",
  ".rs",
  ".sol",
  ".toml",
  ".ts",
  ".tsx",
  ".txt",
  ".yaml",
  ".yml"
]);

const secretPatterns = [
  {
    name: "named credential literal",
    regex: /\b(?:private[_-]?key|secret(?:[_-]?key)?|api[_-]?key|webhook(?:[_-]?url)?|mnemonic|seed[_-]?phrase|rpc[_-]?url)\b\s*[:=]\s*["']([^"'\s]{16,})["']/gi,
    capture: 1
  },
  {
    name: "json credential field",
    regex: /"(?:privateKey|private_key|secret|secretKey|secret_key|apiKey|api_key|webhookUrl|webhook_url|mnemonic|seedPhrase|seed_phrase|rpcUrl|rpc_url)"\s*:\s*"([^"]{16,})"/gi,
    capture: 1
  },
  {
    name: "provider token",
    regex: /\b(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,})\b/g,
    capture: 1
  },
  {
    name: "private key hex literal",
    regex: /\bprivate[_ -]?key\b.*\b(0x[0-9a-fA-F]{64})\b/gi,
    capture: 1
  }
];

function relative(path) {
  return path.slice(repoRoot.length + 1).replaceAll("\\", "/");
}

function isAllowedPlaceholder(value) {
  const normalized = value.trim().toLowerCase();
  return (
    normalized.startsWith("$") ||
    normalized.startsWith("%") ||
    normalized.startsWith("<") ||
    normalized.includes("process.env") ||
    normalized.includes("redacted") ||
    normalized.includes("placeholder") ||
    normalized.includes("example") ||
    normalized.includes("not-set") ||
    normalized === "none" ||
    normalized === "null"
  );
}

function walk(dir, files) {
  const entries = readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const path = resolve(dir, entry.name);
    if (entry.isDirectory()) {
      if (skipDirs.has(entry.name)) continue;
      if (relative(path).startsWith("devnet/local/")) continue;
      walk(path, files);
      continue;
    }
    if (!entry.isFile()) continue;
    const ext = extname(entry.name).toLowerCase();
    if (!textExtensions.has(ext)) continue;
    const stat = lstatSync(path);
    if (stat.size > 5_000_000) continue;
    files.push(path);
  }
}

function addScanPath(path, files) {
  if (!existsSync(path)) return;
  const stat = lstatSync(path);
  if (stat.isDirectory()) {
    walk(path, files);
    return;
  }
  if (!stat.isFile()) return;
  const ext = extname(path).toLowerCase();
  if (!textExtensions.has(ext) || stat.size > 5_000_000) return;
  files.push(path);
}

function scanFile(path) {
  const content = readFileSync(path, "utf8");
  const findings = [];
  const lines = content.split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    for (const pattern of secretPatterns) {
      pattern.regex.lastIndex = 0;
      let match;
      while ((match = pattern.regex.exec(line)) !== null) {
        const value = match[pattern.capture] ?? "";
        if (isAllowedPlaceholder(value)) continue;
        findings.push({
          file: relative(path),
          line: index + 1,
          pattern: pattern.name,
          excerpt: line.replace(value, "<redacted>")
        });
      }
    }
  }
  return findings;
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

const files = [];
for (const scanPath of [
  "package.json",
  "crates/flowmemory-devnet/src",
  "crates/flowmemory-devnet/tests",
  "docs/agent-runs/production-l1-protocol",
  "fixtures/production-l1",
  "schemas/flowmemory",
  "infra/scripts/flowchain-live-l1-protocol-verify.mjs",
  "infra/scripts/flowchain-bridge-mock-e2e.mjs",
  "infra/scripts/flowchain-no-secret-scan.mjs"
]) {
  addScanPath(resolve(repoRoot, scanPath), files);
}
for (const extraPath of [
  resolve(reportDir, "protocol-conformance-report.json"),
  resolve(reportDir, "bridge-mock-e2e-report.json")
]) {
  if (existsSync(extraPath) && !files.includes(extraPath)) files.push(extraPath);
}

const findings = files.flatMap((path) => scanFile(path));
const report = {
  schema: "flowchain.no_secret_scan.report.v0",
  generatedAt: new Date().toISOString(),
  finalStatus: findings.length === 0 ? "PASS" : "CODE-BLOCKED",
  scannedFiles: files.length,
  findings
};
writeJson(reportPath, report);

if (findings.length > 0) {
  console.error(`FLOWCHAIN_NO_SECRET_SCAN_FAIL report=${reportPath}`);
  for (const finding of findings.slice(0, 20)) {
    console.error(`${finding.file}:${finding.line} ${finding.pattern}`);
  }
  process.exit(1);
}

console.log(`FLOWCHAIN_NO_SECRET_SCAN_PASS report=${reportPath} scannedFiles=${files.length}`);
