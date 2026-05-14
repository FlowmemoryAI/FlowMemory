#!/usr/bin/env node
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..", "..");
const scanRoots = [
  "crypto/fixtures",
  "crypto/test",
  "schemas/flowmemory",
  "fixtures/crypto"
];

const patterns = [
  {
    name: "private-key-field",
    pattern: /["']?privateKey["']?\s*[:=]\s*["']0x[0-9a-fA-F]{64}["']/i
  },
  {
    name: "seed-or-mnemonic-field",
    pattern: /["']?(seedPhrase|seed phrase|mnemonic)["']?\s*[:=]\s*["'][^"']{8,}["']/i
  },
  {
    name: "rpc-url-with-secret-token",
    pattern: /https?:\/\/[^\s"']*(rpc|alchemy|infura|quicknode|token|secret|key)[^\s"']*/i
  },
  {
    name: "api-key-field",
    pattern: /["']?(apiKey|api_key|API_KEY)["']?\s*[:=]\s*["'][A-Za-z0-9_\-]{16,}["']/i
  },
  {
    name: "webhook-url",
    pattern: /https:\/\/(hooks\.slack\.com|discord\.com\/api\/webhooks)\/[^\s"']+/i
  }
];

const findings = [];
for (const scanRoot of scanRoots) {
  const absolute = resolve(root, scanRoot);
  if (!existsSync(absolute)) {
    continue;
  }
  for (const path of files(absolute)) {
    const text = readFileSync(path, "utf8");
    for (const { name, pattern } of patterns) {
      if (pattern.test(text)) {
        findings.push({ path, name });
      }
    }
  }
}

if (findings.length > 0) {
  console.error(JSON.stringify({ schema: "flowmemory.crypto.no_secret_scan.v0", ok: false, findings }, null, 2));
  process.exitCode = 1;
} else {
  console.log(JSON.stringify({ schema: "flowmemory.crypto.no_secret_scan.v0", ok: true, scannedRoots: scanRoots }, null, 2));
}

function* files(dir) {
  for (const entry of readdirSync(dir)) {
    const path = resolve(dir, entry);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      yield* files(path);
    } else if (/\.(json|js|ts|md)$/.test(path)) {
      yield path;
    }
  }
}
